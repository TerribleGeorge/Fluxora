# Estratégia de monetização do Fluxora

## Decisão V1

Na primeira versão comercial, o Fluxora usa um único produto de assinatura:

- Produto Google Play: `fluxora_pro`
- Nome comercial: Fluxora Pro Fundador
- Plano mensal: `mensal` — R$ 39,99/mês
- Plano anual planejado: `pro-fundador-anual` — R$ 399,90/ano
- Oferta de aquisição: `teste-14-dias` — 2 semanas grátis para novos usuários
  (equivalente comercial a 14 dias)

## Por que um único produto

O app ainda está em fase inicial de validação com negócios reais. Criar muitos
planos agora aumenta complexidade de compra, suporte, copy, permissões e
validação sem necessariamente aumentar conversão.

Um único produto deixa a mensagem mais forte:

> Fluxora Pro Fundador: tudo que o negócio precisa para controlar vendas,
> comissões, caixa, despesas e lucro real.

Depois que o produto tiver agenda, automações, relatórios avançados, WhatsApp,
multiunidade ou integrações contábeis, podemos criar um plano superior ou
reprecificar novas entradas.

## Por que preço fundador

O preço de R$ 39,99/mês é competitivo para pequenos negócios de beleza e evita
posicionar o Fluxora como ferramenta barata demais. A narrativa correta não é
"vamos aumentar depois", mas:

> Os primeiros clientes entram em condição de fundador porque ajudam a validar e
> melhorar o produto. Novos preços refletem novas entregas e mais maturidade.

Isso reduz objeção de preço e cria senso de vantagem para quem entra cedo.

## Por que Google Play Billing

Como a distribuição principal será Android pela Google Play, a cobrança precisa
usar Google Play Billing para assinaturas digitais dentro do app. Isso garante:

- compra pela conta Google do usuário;
- cancelamento e renovação gerenciados pela Play Store;
- compatibilidade com a política de pagamentos do Google;
- possibilidade de teste interno antes de cobrar usuários reais.

## Objeção encontrada no Play Console

Ao tentar criar a assinatura, o Play Console mostrou apenas a ação
"Faça upload de um novo APK". Isso acontece porque o app enviado ainda não
incluía a biblioteca/permissão de billing.

Correção aplicada:

1. Adicionamos `in_app_purchase`.
2. Criamos um catálogo de billing com IDs estáveis.
3. Criamos `GooglePlayBillingRepository` para consultar e iniciar compra.
4. Atualizamos a tela de planos para refletir o plano fundador.
5. O próximo AAB precisa ser enviado ao teste interno antes de criar/ativar a
   assinatura no Console.

## Status operacional

- [x] Gerar AAB assinado com Billing.
- [x] Subir no teste interno da Play Console.
- [x] Criar produto de assinatura `fluxora_pro`.
- [x] Criar plano base mensal `mensal`.
- [x] Ativar plano mensal por R$ 39,99/mês.
- [x] Criar oferta `teste-14-dias` com teste gratuito de 2 semanas.
- [ ] Testar compra com testador licenciado antes de produção.
