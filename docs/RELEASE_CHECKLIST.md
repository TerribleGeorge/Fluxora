# Checklist de liberação do Fluxora

## Dependências externas pendentes

- [ ] Criar o projeto Supabase.
- [ ] Aplicar todas as migrações em `supabase/migrations/`.
- [ ] Implantar a função `delete-account`.
- [ ] Configurar URL e publishable key no build.
- [ ] Configurar SMTP e URLs de confirmação/recuperação.
- [ ] Definir e publicar e-mail oficial de suporte.
- [ ] Publicar `privacy.html` e `delete-account.html` em endereço público.

## Android e Google Play

- [ ] Confirmar definitivamente o application ID `com.fluxora.fluxora`.
- [ ] Criar e guardar em backup o upload keystore de produção.
- [ ] Substituir a assinatura de depuração da configuração `release`.
- [ ] Criar o aplicativo na Play Console.
- [ ] Preencher conteúdo, classificação etária e Data safety.
- [ ] Enviar ícone, feature graphic e capturas de tela finais.
- [ ] Configurar produtos de assinatura antes de habilitar cobranças.
- [ ] Gerar e verificar o Android App Bundle assinado.
- [ ] Executar teste fechado com 12 testadores por 14 dias, se exigido pela conta.
- [ ] Solicitar acesso à produção e publicar após aprovação.

## Validação de produto

- [ ] Testar cadastro e confirmação de e-mail em Android real.
- [ ] Testar recuperação de senha pelo deep link.
- [ ] Validar isolamento de dois estabelecimentos no banco.
- [ ] Validar sincronização offline e reconexão em dois dispositivos.
- [ ] Validar exclusão completa da conta e dos dados.
- [ ] Validar os cálculos com pelo menos cinco negócios reais.
- [ ] Revisar textos legais com responsável jurídico antes da produção.

Nunca enviar `service_role`, senhas, `key.properties` ou arquivos de keystore ao
Git. A chave de upload deve possuir backup privado fora do computador.
