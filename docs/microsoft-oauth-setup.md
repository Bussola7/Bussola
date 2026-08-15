# Configuração do Microsoft OAuth (Outlook Calendar)

## Checklist objetivo para validação real

### Microsoft Entra (Azure Portal)
- [ ] App Registration criado
- [ ] Client ID obtido
- [ ] Client Secret gerado
- [ ] Redirect URI cadastrado (formato `<applicationId ou Bundle ID>://outlookauth`)
- [ ] Permissões Delegated concedidas: `openid`, `profile`, `offline_access`, `Calendars.ReadWrite`

### Supabase
- [ ] `MICROSOFT_CLIENT_ID` configurado via `supabase secrets set`
- [ ] `MICROSOFT_CLIENT_SECRET` configurado via `supabase secrets set`

### Aplicativo (`.env`, nunca o Client Secret)
- [ ] `MICROSOFT_CLIENT_ID` preenchido
- [ ] `MICROSOFT_REDIRECT_URI` preenchido (idêntico ao cadastrado no Azure)
- [ ] Escopos conferidos no código (`openid profile offline_access Calendars.ReadWrite`) — já corretos, não precisam de configuração

### Android (só quando o projeto nativo existir)
- [ ] `applicationId` real identificado (`android/app/build.gradle`)
- [ ] Intent-filter com o redirect scheme adicionado ao `AndroidManifest.xml`
- [ ] Redirect URI final validado (`<applicationId>://outlookauth`, igual nos 3 lugares: Manifest, `.env`, Azure)

### iOS (só quando o projeto nativo existir)
- [ ] Bundle ID real identificado (Xcode → target Runner → General)
- [ ] `CFBundleURLTypes` com o esquema adicionado ao `Info.plist`
- [ ] Redirect URI final validado (`<Bundle ID>://outlookauth`, igual nos 3 lugares: Info.plist, `.env`, Azure)

---

Este documento reúne tudo que falta para a integração com o Outlook Calendar funcionar de verdade — nenhum dos valores abaixo existe ainda neste projeto; todos precisam ser obtidos/configurados por quem tem acesso ao Azure Portal e ao projeto Flutter nativo completo.

## 1. Dados necessários do Microsoft Entra (Azure Portal)

Criar um **App Registration** em [entra.microsoft.com](https://entra.microsoft.com) (ou portal.azure.com → Microsoft Entra ID → App registrations → New registration) e anotar:

| Dado | Onde encontrar | Já decidido pelo código? |
|---|---|---|
| **Tenant** | Tipo de conta suportada, na criação do App Registration | Sim — `common` (aceita contas pessoais e corporativas/escolares), já hardcoded nos endpoints |
| **Client ID** | "Application (client) ID", na página Overview do App Registration | Não — só existe depois de criar o registro |
| **Client Secret** | Certificates & secrets → New client secret | Não — gerado no Azure, **nunca vai para o app** |
| **Redirect URI** | Authentication → Add a platform → Mobile and desktop applications | Não — depende do `applicationId`/Bundle ID reais (ver seções 3 e 4) |
| **Permissões Graph** | API permissions → Add a permission → Microsoft Graph → Delegated | Sim — `openid`, `profile`, `offline_access`, `Calendars.ReadWrite`, já em uso no código |

## 2. Configuração no Supabase (Edge Functions)

```bash
supabase secrets set MICROSOFT_CLIENT_ID=<Client ID do Azure>
supabase secrets set MICROSOFT_CLIENT_SECRET=<Client Secret do Azure>
```

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` já são fornecidas automaticamente pelo Supabase a qualquer Edge Function — não precisam ser configuradas manualmente.

## 3. Android

**Onde configurar o redirect scheme**: `android/app/src/main/AndroidManifest.xml`, dentro da `<activity>` principal — adicionar um `<intent-filter>` com o esquema do Redirect URI:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="SEU_APPLICATION_ID_AQUI" android:host="outlookauth" />
</intent-filter>
```

**Como descobrir o `applicationId` real**: abrir `android/app/build.gradle` e procurar por `applicationId "..."` dentro do bloco `defaultConfig`.

**Como validar o Redirect URI**: o valor final deve ser `<applicationId>://outlookauth` — precisa ser **exatamente igual** em três lugares: neste `AndroidManifest.xml`, no `.env` do app (`MICROSOFT_REDIRECT_URI`), e cadastrado no App Registration do Azure (seção 1).

## 4. iOS

**Onde configurar o URL Scheme**: `ios/Runner/Info.plist`, dentro de `CFBundleURLTypes`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>SEU_BUNDLE_ID_AQUI</string></array>
  </dict>
</array>
```

**Como descobrir o Bundle ID real**: abrir `ios/Runner.xcodeproj` no Xcode → target Runner → aba General → campo "Bundle Identifier"; ou procurar `PRODUCT_BUNDLE_IDENTIFIER` dentro de `ios/Runner.xcodeproj/project.pbxproj`.

**Como validar o Redirect URI**: mesmo princípio do Android — `<Bundle ID>://outlookauth`, idêntico no `Info.plist`, no `.env` do app, e no Azure.

## 5. Ordem de validação (seguir nesta sequência)

1. Azure (App Registration criado, Client ID/Secret obtidos, Redirect URI cadastrado)
2. Supabase (`MICROSOFT_CLIENT_ID`/`MICROSOFT_CLIENT_SECRET` configurados)
3. `.env` do app (`MICROSOFT_CLIENT_ID`, `MICROSOFT_REDIRECT_URI` — nunca o Client Secret)
4. Android/iOS (redirect scheme configurado, batendo com o Redirect URI real)
5. `flutter pub get`
6. `flutter analyze`
7. `flutter test`
8. OAuth real (conectar uma conta Microsoft de teste pelo app)
9. Microsoft Graph (confirmar que a sincronização de eventos funciona de ponta a ponta)

## Segurança — regras que nunca mudam

- Client Secret: **nunca** em `lib/`, **nunca** no `.env` do aplicativo — só como secret do Supabase
- `refresh_token`: nunca é devolvido pelas Edge Functions ao app — fica só no banco, lido só pela função de refresh com a service role key
- `access_token`: lido do Supabase sob demanda, nunca persistido localmente no dispositivo
