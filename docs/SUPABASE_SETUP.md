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
3. adicione `com.fluxora.app://reset-password` às URLs de redirecionamento;
4. configure SMTP próprio antes do lançamento;
5. nunca coloque `service_role` ou outra chave secreta no aplicativo.

Sem as duas variáveis, o Fluxora abre a tela de acesso em modo não configurado
e bloqueia operações de autenticação com uma mensagem segura.
