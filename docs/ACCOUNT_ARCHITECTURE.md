# Arquitetura de contas, estabelecimentos e permissões

## Estrutura

```text
Usuário
  └── Vínculo com estabelecimento
        ├── Proprietário
        ├── Gestor
        └── Profissional
              └── Estabelecimento de beleza
```

Um usuário pode participar de mais de um estabelecimento. Cada vínculo possui
uma função própria; portanto, a mesma pessoa pode ser proprietária de um salão
e profissional em outro sem misturar permissões ou dados.

## Entidades

- `UserProfile`: identidade pública vinculada à autenticação.
- `BeautyBusiness`: estabelecimento e seu segmento dentro do ramo de beleza.
- `BusinessMembership`: vínculo entre usuário, estabelecimento e função.

Todo dado operacional futuro deverá carregar `businessId`. Esse identificador
será obrigatório nas políticas de segurança do banco para impedir acesso entre
estabelecimentos.

## Funções

### Proprietário

Possui controle total, incluindo dados do estabelecimento, membros, operação e
relatórios financeiros.

### Gestor

Opera equipe, serviços, atendimentos, caixa, despesas, comissões e relatórios.
Não pode alterar os dados principais nem assumir a propriedade do negócio.

### Profissional

Acessa somente sua própria agenda e seus próprios valores de comissão. Não
visualiza o resultado global do estabelecimento.

## Regras obrigatórias para o backend

1. A autenticação identifica o usuário, mas o vínculo determina o acesso.
2. Consultas operacionais sempre exigem um estabelecimento selecionado.
3. Permissões devem ser validadas no aplicativo e novamente no banco.
4. Desativar um vínculo revoga imediatamente todas as suas permissões.
5. Somente o proprietário pode alterar dados estruturais do estabelecimento.
6. Um estabelecimento deve conservar ao menos um proprietário ativo.
7. Nenhuma permissão é inferida por e-mail, aparelho ou informação da tela.
