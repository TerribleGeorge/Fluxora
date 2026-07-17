# Fluxora — regras de negócio para beleza e bem-estar

O Fluxora agora é focado em negócios de beleza e bem-estar: barbearias, salões,
esmalterias, spas, estúdios de sobrancelhas/cílios, maquiagem e clínicas de
estética não médicas.

O objetivo central é financeiro: mostrar ao dono quanto realmente sobrou depois
de descontar comissão, taxa de cartão, custo de produtos/insumos, despesas,
impostos e retiradas.

## Papéis do sistema

### Dono

Tem acesso total:

- visão geral e relatórios;
- lucro real;
- caixa;
- despesas;
- comissões;
- equipe;
- serviços;
- produtos e custos de estoque;
- clientes e fidelidade;
- importação de base antiga.

### Funcionário

Tem acesso restrito:

- própria agenda;
- detalhes dos próprios atendimentos;
- concluir atendimento;
- adicionar produtos ao checkout daquele atendimento;
- consultar produtos vendáveis sem enxergar custo interno.

Não pode ver faturamento total, relatórios da empresa, vendas de outros
profissionais, despesas, retiradas ou margem de produto.

### Cliente

Não usa aplicativo. Agenda por link web público.

O cliente informa:

- nome;
- e-mail;
- telefone.

Ele não escolhe nível de fidelidade e não vê controles de desconto. Sem prova
de posse por OTP, o Supabase mantém o preço cheio; o desconto só é recalculado
após associação interna a um cadastro fiel verificado.

## Fidelidade por níveis

O dono possui uma chave on/off por estabelecimento.

Quando a fidelidade está desligada:

- todo cliente paga o preço padrão;
- o sistema retorna nível `new`.

Quando a fidelidade está ligada:

- `new`: primeiro agendamento ou cliente sem frequência recente;
- `standard`: pelo menos 3 meses de relacionamento ativo;
- `gold`: pelo menos 6 meses de relacionamento ativo;
- `premium`: pelo menos 12 meses de relacionamento ativo.

Um cliente é considerado inativo quando passa mais dias sem atendimento
concluído do que o limite configurado em `inactive_after_days`. O padrão inicial
é 90 dias.

O dono pode fixar manualmente um nível, útil para importação de clientes antigos.

## Blindagem antifraude no agendamento público

O fluxo público não expõe botões de nível. Em modo seguro sem OTP, o Supabase:

1. valida nome, e-mail e telefone obrigatórios;
2. usa correspondência estrita apenas para evitar cadastros duplicados;
3. não concede desconto com base em dados públicos não verificados;
4. cria o agendamento como `new`, com preço cheio;
5. permite que a equipe faça a associação segura antes do checkout.

Quando a prova de posse por OTP for implementada, a identidade confirmada poderá
receber o nível automaticamente sem abrir um oráculo de clientes ou descontos.

O preço aplicado fica congelado no agendamento:

- preço base;
- nível aplicado;
- percentual de desconto;
- valor do desconto;
- preço final.

Isso evita que uma alteração futura de desconto mude vendas antigas.

## Correção na cadeira

Quando um cliente fiel agenda com dados novos e cai como cliente novo, o app
terá o fluxo “Associar a Cliente Fiel”.

A função `link_appointment_to_customer`, disponível somente antes do checkout:

- vincula o agendamento ao cliente correto;
- grava as novas identidades de e-mail/telefone;
- recalcula preço/desconto;
- registra auditoria;
- bloqueia a alteração se a venda já existir, preservando o livro financeiro.

O funcionário responsável busca o cadastro por uma RPC específica do próprio
atendimento. A resposta limita-se a nome, contato mascarado e nível; as tabelas
de clientes e configurações de fidelidade continuam protegidas por RLS.

## Produtos e estoque por nicho

Produtos são segmentados pelo tipo de estabelecimento. O banco impede produto de
um nicho diferente do negócio.

Exemplos:

- barbearia: pomada, óleo para barba, balm, shampoo masculino;
- esmalteria: esmalte, base fortalecedora, lixa, óleo secante;
- spa: óleo corporal, sais de banho, creme hidratante;
- estética não médica: protetor solar cosmético, sérum cosmético, máscara facial.

O funcionário acessa produtos vendáveis pela view `sellable_products`, que não
expõe `unit_cost`.

## Checkout de atendimento

Ao concluir atendimento, a função `complete_appointment_checkout`:

1. valida se o usuário é dono/gerente ou o profissional responsável;
2. lê o preço final do serviço;
3. adiciona produtos selecionados;
4. baixa estoque;
5. registra movimentos de estoque;
6. cria a venda;
7. marca o agendamento como concluído;
8. atualiza histórico do cliente;
9. calcula lucro estimado da venda.

O lucro estimado considera:

- total recebido;
- taxa de pagamento;
- comissão;
- custo dos produtos.

As despesas fixas, impostos e retiradas continuam entrando nos relatórios
financeiros mensais.

## Segurança no Supabase

As regras sensíveis ficam no banco:

- funcionários não leem `finance_transactions`;
- funcionários só veem vendas próprias;
- donos/gerentes gerenciam clientes, produtos e fidelidade;
- produtos completos mostram custo apenas para dono/gerente;
- funcionários usam `sellable_products` sem custo interno;
- funções RPC executam operações fechadas e auditáveis.

Essa separação reduz risco de um app antigo, bugado ou manipulado gravar números
errados no caixa.
