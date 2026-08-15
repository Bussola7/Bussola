// supabase/functions/microsoft-oauth-refresh/index.ts
//
// Equivalente Microsoft da `google-oauth-refresh`: troca o `refresh_token`
// (guardado só aqui, nunca no app) por um `access_token` novo, quando o
// antigo expira (~1h, mesma duração típica do Google).
//
// Chamada pelo app via `supabase.functions.invoke('microsoft-oauth-refresh')`,
// autenticado — sem nenhum parâmetro extra: o `refresh_token` é lido
// daqui de dentro, da tabela `integrations`, nunca enviado pelo app.
//
// IMPORTANTE (transparência): mesma ressalva da função anterior — código
// segue a documentação pública da Microsoft, não foi implantado nem
// testado contra a Microsoft real neste ambiente.

import { serve } from 'https://deno.land/std@0.192.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const MICROSOFT_TOKEN_URL = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
const MICROSOFT_SCOPES = 'openid profile offline_access Calendars.ReadWrite';

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
      .eq('provider', 'outlook')
      .maybeSingle();

    if (integrationError || !integration?.refresh_token) {
      return new Response(JSON.stringify({ error: 'refresh_token_missing' }), { status: 404 });
    }

    const tokenResponse = await fetch(MICROSOFT_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        refresh_token: integration.refresh_token,
        client_id: Deno.env.get('MICROSOFT_CLIENT_ID')!,
        client_secret: Deno.env.get('MICROSOFT_CLIENT_SECRET')!,
        grant_type: 'refresh_token',
        scope: MICROSOFT_SCOPES,
      }),
    });

    if (!tokenResponse.ok) {
      // A Microsoft devolve 400 com error="invalid_grant" quando o
      // refresh_token foi revogado (ex: a pessoa removeu o acesso do
      // Bússola em account.microsoft.com) ou expirou. Mesma estratégia do
      // Google: marcamos a integração como desconectada aqui mesmo — não
      // adianta o app tentar de novo, o token não vai voltar a funcionar
      // sozinho.
      await supabase
        .from('integrations')
        .update({ status: 'desconectado', token: null, refresh_token: null })
        .eq('user_id', userData.user.id)
        .eq('provider', 'outlook');

      return new Response(JSON.stringify({ error: 'refresh_invalid', reconnectRequired: true }), { status: 401 });
    }

    const tokens = await tokenResponse.json();

    await supabase
      .from('integrations')
      .update({
        token: tokens.access_token,
        // A Microsoft pode devolver um refresh_token novo a cada renovação
        // (rotação de token) — se vier, atualiza; se não vier, mantém o antigo.
        ...(tokens.refresh_token ? { refresh_token: tokens.refresh_token } : {}),
        status: 'conectado',
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userData.user.id)
      .eq('provider', 'outlook');

    return new Response(JSON.stringify({ success: true, accessTokenExpiresIn: tokens.expires_in }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Erro interno', detalhe: `${e}` }), { status: 500 });
  }
});
