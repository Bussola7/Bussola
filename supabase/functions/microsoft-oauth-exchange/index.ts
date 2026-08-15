// supabase/functions/microsoft-oauth-exchange/index.ts
//
// Equivalente Microsoft da `google-oauth-exchange`: troca um `code` de
// autorização por `access_token`+`refresh_token`, usando o Client Secret
// da Microsoft — que só existe aqui, nunca no app Flutter.
//
// Fluxo de segurança (Authorization Code + PKCE, decisão aprovada):
// 1. O app Flutter usa `flutter_appauth` (método `authorize()`, NÃO
//    `authorizeAndExchangeCode()`) para abrir o navegador do sistema,
//    autenticar a pessoa, e obter só um `authorization code` + o
//    `code_verifier` do PKCE que ele mesmo gerou — nenhum token ainda.
// 2. O app manda os dois, mais o `redirectUri` usado, para ESTA função
//    (com o JWT do Supabase Auth da pessoa, para sabermos de quem é).
// 3. Só AQUI, no servidor, o código é trocado por `access_token` +
//    `refresh_token` junto à Microsoft — usando TANTO o Client Secret
//    (variável de ambiente `MICROSOFT_CLIENT_SECRET`, nunca no app) QUANTO
//    o `code_verifier` do PKCE que o app mandou (a Microsoft exige os
//    dois quando o app registrado tem Client Secret; PKCE sozinho, sem
//    secret, também seria aceito se o App Registration fosse do tipo
//    "público" — usamos os dois por já termos o padrão de Client Secret
//    do Google).
// 4. O `refresh_token` fica guardado aqui, nunca é devolvido ao app.
//
// Endpoints e escopos usados (reais, documentação pública da Microsoft
// identity platform — nada inventado):
// - Token endpoint: https://login.microsoftonline.com/common/oauth2/v2.0/token
//   ("common" = aceita tanto contas pessoais quanto corporativas/escolares)
// - Escopos (aprovados): "openid profile offline_access Calendars.ReadWrite"
//   ("offline_access" é obrigatório para ganhar um refresh_token;
//   "Calendars.ReadWrite" é o escopo da Microsoft Graph para eventos;
//   "openid"/"profile" são os escopos padrão OIDC para identificar a pessoa)
//
// IMPORTANTE (transparência): este código segue a documentação pública da
// Microsoft, mas NÃO foi implantado nem testado contra a Microsoft real
// neste ambiente — requer um App Registration configurado no Azure Portal
// (Client ID + Client Secret + redirect URI) e a função implantada de
// verdade.

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

    const { authorizationCode, codeVerifier, redirectUri } = await req.json();
    if (!authorizationCode || !codeVerifier || !redirectUri) {
      return new Response(
        JSON.stringify({ error: 'authorizationCode, codeVerifier ou redirectUri ausente' }),
        { status: 400 },
      );
    }

    // Troca o código pelo access_token + refresh_token — só isso conhece
    // o Client Secret. `code_verifier` é o outro lado do PKCE: prova que
    // quem está trocando o código é o MESMO app que iniciou o login
    // (protege contra interceptação do `authorization code` no meio do
    // caminho, ex: por outro app malicioso no aparelho).
    const tokenResponse = await fetch(MICROSOFT_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code: authorizationCode,
        code_verifier: codeVerifier,
        client_id: Deno.env.get('MICROSOFT_CLIENT_ID')!,
        client_secret: Deno.env.get('MICROSOFT_CLIENT_SECRET')!,
        redirect_uri: redirectUri,
        grant_type: 'authorization_code',
        scope: MICROSOFT_SCOPES,
      }),
    });

    if (!tokenResponse.ok) {
      // Erro específico da Microsoft (ex: "invalid_grant") fica só aqui —
      // o app nunca vê o corpo cru da resposta da Microsoft.
      const erro = await tokenResponse.text();
      return new Response(JSON.stringify({ error: 'Falha ao trocar o código com a Microsoft', detalhe: erro }), { status: 502 });
    }

    const tokens = await tokenResponse.json();

    // Guarda o access_token (curta duração) e o refresh_token na mesma
    // tabela `integrations` que o Google já usa — só muda o `provider`.
    await supabase.from('integrations').upsert({
      user_id: userData.user.id,
      provider: 'outlook',
      status: 'conectado',
      token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      scopes: tokens.scope,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id,provider' });

    return new Response(JSON.stringify({ success: true, accessTokenExpiresIn: tokens.expires_in }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Erro interno', detalhe: `${e}` }), { status: 500 });
  }
});
