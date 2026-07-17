# Configuração do Supabase

O aplicativo não contém chaves fixas no código. Para habilitar autenticação,
crie um projeto Supabase e execute o Flutter com variáveis de compilação:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA `
  --dart-define=AUTH_WEB_REDIRECT_BASE_URL=https://SEU-DOMINIO/
```

No painel do Supabase:

1. habilite autenticação por e-mail e senha;
2. mantenha confirmação de e-mail ativa para produção;
3. em **Authentication > URL Configuration**, defina a Site URL como
   `https://terriblegeorge.github.io/fluxora-admin/`;
4. adicione exatamente estas URLs à lista de redirecionamentos permitidos:
   - `dev.devvoid.fluxora://reset-password`
   - `dev.devvoid.fluxora://auth-confirmation`
   - `https://terriblegeorge.github.io/fluxora-admin/?auth-action=password-recovery`
   - `https://terriblegeorge.github.io/fluxora-admin/?auth-action=email-confirmation`
   - `https://terriblegeorge.github.io/fluxora-agendamento/?auth-action=password-recovery`
   - `https://terriblegeorge.github.io/fluxora-agendamento/?auth-action=email-confirmation`
5. no template **Reset Password**, mantenha o botão usando
   `{{ .ConfirmationURL }}`;
6. configure SMTP próprio antes de convidar usuários externos;
7. nunca coloque `service_role` ou outra chave secreta no aplicativo.

O Fluxora usa PKCE, mecanismo que mantém um verificador secreto no ambiente que
pediu o e-mail. Por isso, o callback Web retorna ao navegador e o callback
móvel retorna ao aplicativo. O usuário deve abrir o link no mesmo aplicativo ou
perfil de navegador em que solicitou a recuperação.

Sem as duas variáveis, o Fluxora abre a tela de acesso em modo não configurado
e bloqueia operações de autenticação com uma mensagem segura.

## Build de release para Google Play

Antes de gerar um AAB de produção ou teste interno, carregue as variáveis da
`.env` local e passe os valores com `--dart-define`. Exemplo em PowerShell:

```powershell
$envLines = Get-Content .env | Where-Object { $_ -and -not $_.StartsWith('#') }
foreach ($line in $envLines) {
  $name, $value = $line -split '=', 2
  [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}

flutter build appbundle --release `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY `
  --dart-define=PUBLIC_BOOKING_BASE_URL=$env:PUBLIC_BOOKING_BASE_URL `
  --dart-define=AUTH_WEB_REDIRECT_BASE_URL=$env:AUTH_WEB_REDIRECT_BASE_URL
```

`PUBLIC_BOOKING_BASE_URL` é opcional no desenvolvimento, mas deve apontar para
o domínio do portal web na versão distribuída pela Play Store, para que o dono
consiga copiar e compartilhar o endereço correto pelo aplicativo.

`AUTH_WEB_REDIRECT_BASE_URL` informa a raiz Web usada pela confirmação de conta
e pela recuperação de senha. Ela precisa corresponder à URL permitida no
Supabase.

## URLs web publicadas

| URL | Uso |
| --- | --- |
| `https://terriblegeorge.github.io/fluxora-admin/` | Painel web do dono/administrador. |
| `https://terriblegeorge.github.io/fluxora-agendamento/` | Site público para clientes encontrarem estabelecimentos e agendarem sem login. |

Não use `flutter build appbundle --release` sozinho para releases da Play
Store, porque o app será gerado sem autenticação Supabase.

Também é possível usar o script versionado:

```powershell
.\scripts\build_play_release.ps1
```
