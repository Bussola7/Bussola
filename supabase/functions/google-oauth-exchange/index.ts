// supabase/functions/google-oauth-exchange/index.ts
//
// Edge Function do Supabase — roda no servidor (Deno), nunca no app.
// É o ÚNICO lugar de todo o sistema que conhece o Client Secret do Google.
//
// Fluxo de segurança (por que isso existe):
// 1. O app Flutter usa `google_sign_in` para autenticar a pessoa e pedir
//    um `serverAuthCode` (não um token de acesso direto).
// 2. O app manda esse código para ESTA função (com o JWT do Supabase Auth
//    da pessoa, para sabermos de quem é).
// 3. Só AQUI, no servidor, o código é trocado por um `access_token` +
//    `refresh_token` junto ao Google, usando o Client Secret — que fica
//    configurado como variável de ambiente da função (`GOOGLE_CLIENT_SECRET`),
//    nunca embutido no app, nunca no banco de dados.
// 4. O `refresh_token` fica guardado aqui (ou em um cofre de segredos),
//    nunca é devolvido ao app. O app só recebe de volta o `access_token`
//    de curta duração (para as chamadas seguintes) e um status de sucesso.
//
// IMPORTANTE: este arquivo é o CÓDIGO desta função, mas não foi implantado
// nem testado contra o Google de verdade neste ambiente (sem acesso de
// rede ao Google nem às credenciais reais do projeto). Antes de usar em
// produção: `supabase functions deploy google-oauth-exchange` e configurar
// os segredos com `supabase secrets set`.

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

    const { serverAuthCode } = await req.json();
    if (!serverAuthCode) {
      return new Response(JSON.stringify({ error: 'serverAuthCode ausente' }), { status: 400 });
    }

    // Troca o código pelo access_token + refresh_token — só isso conhece o Client Secret.
    const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code: serverAuthCode,
        client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
        client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
        redirect_uri: '', // vazio para o fluxo de servidor do google_sign_in
        grant_type: 'authorization_code',
      }),
    });

    if (!tokenResponse.ok) {
      const erro = await tokenResponse.text();
      return new Response(JSON.stringify({ error: 'Falha ao trocar o código com o Google', detalhe: erro }), { status: 502 });
    }

    const tokens = await tokenResponse.json();

    // Guarda o access_token (curta duração) e o refresh_token na tabela
    // `integrations` — o refresh_token nunca volta na resposta HTTP.
    await supabase.from('integrations').upsert({
      user_id: userData.user.id,
      provider: 'google_calendar',
      status: 'conectado',
      token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      scopes: tokens.scope,
      updated_at: new Date().toISOString(),
    });

    return new Response(JSON.stringify({ success: true, accessTokenExpiresIn: tokens.expires_in }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Erro interno', detalhe: `${e}` }), { status: 500 });
  }
});
