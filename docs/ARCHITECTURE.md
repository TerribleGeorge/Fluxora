# Arquitetura do Fluxora

## Direção de produto

O Fluxora será um sistema operacional e financeiro para negócios de beleza e
bem-estar: barbearias, salões, esmalterias, spas, estúdios de
sobrancelhas/cílios, maquiagem e clínicas de estética não médicas.

O núcleo do produto é o lucro real do dono: agenda, serviços, produtos,
comissões, taxas, despesas, estoque e caixa existem para responder quanto
realmente sobrou no estabelecimento.

## Estado e dependências

- BLoC recebe eventos, executa regras e publica estados imutáveis.
- Provider injeta contratos de infraestrutura e nunca duplica estado do BLoC.
- Widgets apenas apresentam estados e disparam eventos.
- Repositórios isolam o domínio da tecnologia de armazenamento.

## Estratégia de dados

1. Armazenamento local: mantém o aplicativo disponível offline.
2. SQL principal: PostgreSQL com autenticação e políticas por usuário.
3. MySQL: adaptador de integração para clientes que já possuam sistemas MySQL;
   o aplicativo nunca acessa credenciais de banco diretamente.
4. NoSQL: reservado a cache, eventos e documentos quando houver vantagem
   mensurável; não será uma segunda fonte de verdade financeira.

Transações financeiras terão uma única fonte de verdade. Sincronização será
idempotente, auditável e protegida contra duplicidade.

## Regras sensíveis no Supabase

Regras que afetam dinheiro ou permissão não devem depender apenas da interface.
O Supabase é a autoridade para:

- identificação antifraude do cliente no link público de agendamento;
- cálculo de nível de fidelidade;
- snapshots de preço e desconto no agendamento;
- fechamento de atendimento com produtos;
- baixa de estoque;
- criação de venda;
- restrição de funcionário a agenda e vendas próprias.

As regras detalhadas estão em
[`docs/BEAUTY_BUSINESS_RULES.md`](BEAUTY_BUSINESS_RULES.md).
