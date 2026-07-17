# Checklist de liberação do Fluxora

## Dependências externas pendentes

- [x] Criar o projeto Supabase na região de São Paulo.
- [x] Aplicar todas as migrações em `supabase/migrations/`.
  - `npx supabase db push --linked` retornou `Remote database is up to date`
    em 17/07/2026.
- [x] Implantar a função `delete-account` no Supabase remoto.
  - Código atualizado e validado pelo Flutter em 08/07/2026.
  - Deploy realizado no projeto `nqcoxxbzwzcuwprbzpdb` em 08/07/2026.
- [x] Configurar URL e publishable key no build.
- [x] Separar callbacks de confirmação/recuperação para Web e aplicativo.
- [x] Corrigir deep links Android/iOS e preservar o fluxo PKCE por plataforma.
- [ ] Confirmar no painel as seis URLs de autenticação documentadas.
- [ ] Configurar SMTP próprio para entregar e-mails a usuários externos.
- [ ] Definir e publicar e-mail oficial de suporte.
- [x] Publicar `privacy.html` e `delete-account.html` em endereço público.
  - Política: https://terriblegeorge.github.io/fluxora-legal/privacy.html
  - Exclusão de conta: https://terriblegeorge.github.io/fluxora-legal/delete-account.html

## Android e Google Play

- [x] Confirmar definitivamente o application ID `dev.devvoid.fluxora`.
- [x] Criar o upload keystore de produção (backup externo ainda necessário).
- [x] Substituir a assinatura de depuração da configuração `release`.
- [x] Criar o aplicativo na Play Console.
- [x] Preencher conteúdo do app e Data safety.
- [ ] Confirmar classificação etária antes do envio à revisão.
- [x] Gerar ícone e feature graphic finais da loja.
- [ ] Enviar capturas de tela finais.
- [ ] Configurar produtos de assinatura antes de habilitar cobranças.
  - Estratégia definida em `docs/MONETIZATION_STRATEGY.md`.
  - O Play Console exige upload de novo AAB com Billing antes de criar o produto.
  - Produto planejado: `fluxora_pro`.
- [x] Gerar e verificar o Android App Bundle assinado.
- [ ] Executar teste fechado com 12 testadores por 14 dias, se exigido pela conta.
- [ ] Solicitar acesso à produção e publicar após aprovação.

## Portal web de agendamento

- [x] Implementar página pública, catálogo, cotação e confirmação.
- [x] Implementar serviços e expediente por profissional e bloqueios de agenda.
- [x] Proteger a criação contra corrida e reenvio duplicado.
- [x] Manter preço cheio para identidade pública sem OTP e permitir associação
  interna auditável antes do checkout.
- [x] Gerar o build web de produção localmente.
- [x] Preparar workflow de CI/CD para publicação no GitHub Pages.
- [x] Aplicar as RPCs no Supabase remoto.
- [x] Escolher hospedagem inicial e configurar `PUBLIC_BOOKING_BASE_URL`.
  - Publicado: https://terriblegeorge.github.io/fluxora-agendamento/
  - GitHub Pages ativo com HTTPS; resposta HTTP 200 validada em 17/07/2026.
- [ ] Configurar prova de posse por OTP ou proteção anti-bot.
- [ ] Validar um agendamento completo em janela anônima no endereço publicado.

## Painel web administrativo

- [x] Publicar versão web administrativa para donos e gestores.
  - Publicado: https://terriblegeorge.github.io/fluxora-admin/
  - Repositório de artefatos: https://github.com/TerribleGeorge/fluxora-admin
  - GitHub Pages ativo com HTTPS; resposta HTTP 200 validada em 17/07/2026.
- [ ] Confirmar no Supabase os redirects do painel administrativo:
  - `https://terriblegeorge.github.io/fluxora-admin/?auth-action=password-recovery`
  - `https://terriblegeorge.github.io/fluxora-admin/?auth-action=email-confirmation`
- [ ] Testar login, cadastro, confirmação de e-mail e recuperação de senha no
  painel web publicado.

## Validação de produto

- [ ] Testar cadastro e confirmação de e-mail em Android real.
- [ ] Testar recuperação de senha pelo deep link.
- [ ] Validar isolamento de dois estabelecimentos no banco.
- [ ] Validar sincronização offline e reconexão em dois dispositivos.
- [ ] Validar exclusão completa da conta e dos dados em um usuário de teste.
- [ ] Validar os cálculos com pelo menos cinco negócios reais.
- [ ] Validar isolamento, bloqueios e concorrência do portal no Supabase remoto.
- [ ] Revisar textos legais com responsável jurídico antes da produção.

Nunca enviar `service_role`, senhas, `key.properties` ou arquivos de keystore ao
Git. A chave de upload deve possuir backup privado fora do computador.
