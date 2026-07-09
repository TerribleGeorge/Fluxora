# Configuração do Supabase

O aplicativo não contém chaves fixas no código. Para habilitar autenticação,
crie um projeto Supabase e execute o Flutter com variáveis de compilação:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

No painel do Supabase:

1. habilite autenticação por e-mail e senha;
2. mantenha confirmação de e-mail ativa para produção;
3. adicione `dev.devvoid.fluxora://reset-password` às URLs de redirecionamento;
4. configure SMTP próprio antes do lançamento;
5. nunca coloque `service_role` ou outra chave secreta no aplicativo.

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
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY
```

Não use `flutter build appbundle --release` sozinho para releases da Play
Store, porque o app será gerado sem autenticação Supabase.

Também é possível usar o script versionado:

```powershell
.\scripts\build_play_release.ps1
```
