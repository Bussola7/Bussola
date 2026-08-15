// supabase/functions/google-oauth-refresh/index.ts
//
// Segunda Edge Function do fluxo Google: troca o `refresh_token` (guardado
// só aqui no servidor, nunca no app) por um `access_token` novo, quando o
// antigo expira. Mesmo motivo da `google-oauth-exchange`: só o servidor
// conhece o Client Secret, então só o servidor pode fazer essa troca.
//
// Chamada pelo app via `supabase.functions.invoke('google-oauth-refresh')`,
// autenticado (o JWT do Supabase Auth da pessoa) — sem nenhum parâmetro
// extra: o `refresh_token` é lido daqui de dentro, da tabela
// `integrations`, nunca enviado pelo app (o app não tem acesso a ele).
//
// IMPORTANTE (transparência): mesma ressalva da função anterior — este
// código segue a documentação pública do Google, mas não foi implantado
// nem testado contra o Google real neste ambiente.

import { serve } from 'https://deno.land/std@0.192.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: 'Usuário não autenticado' }), { status: 401 });
    }

    // O refresh_token nunca vem do app — é lido direto da tabela, usando
    // a service role key (a única credencial com permissão de ler essa coluna).
    const { data: integration, error: integrationError } = await supabase
      .from('integrations')
      .select('refresh_token')
      .eq('user_id', userData.user.id)
      .eq('provider', 'google_calendar')
      .maybeSingle();

    if (integrationError || !integration?.refresh_token) {
      return new Response(JSON.stringify({ error: 'refresh_token_missing' }), { status: 404 });
    }

    const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        refresh_token: integration.refresh_token,
        client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
        client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
        grant_type: 'refresh_token',
      }),
    });

    if (!tokenResponse.ok) {
      // O Google devolve 400 com error="invalid_grant" quando o
      // refresh_token foi revogado (ex: a pessoa removeu o acesso do
      // Bússola nas configurações da conta Google) ou expirou. Nesse
      // caso, marcamos a integração como desconectada aqui mesmo — não
      // adianta o app tentar de novo, o token não vai voltar a funcionar
      // sozinho.
      await supabase
        .from('integrations')
        .update({ status: 'desconectado', token: null, refresh_token: null })
        .eq('user_id', userData.user.id)
        .eq('provider', 'google_calendar');

      return new Response(JSON.stringify({ error: 'refresh_invalid', reconnectRequired: true }), { status: 401 });
    }

    const tokens = await tokenResponse.json();

    await supabase
      .from('integrations')
      .update({
        token: tokens.access_token,
        status: 'conectado',
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userData.user.id)
      .eq('provider', 'google_calendar');

    return new Response(JSON.stringify({ success: true, accessTokenExpiresIn: tokens.expires_in }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Erro interno', detalhe: `${e}` }), { status: 500 });
  }
});
