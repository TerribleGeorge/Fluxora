# Arquitetura do Fluxora

## Direção de produto

O Fluxora será um sistema financeiro híbrido para pessoas, profissionais
autônomos e pequenos negócios. O mesmo núcleo financeiro atenderá espaços
pessoais e empresariais sem misturar seus dados.

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
