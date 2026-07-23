# Notas da versão 1.0.0 (build 20)

## Texto para o Google Play Console

```text
<pt-BR>
Reforçamos o cadastro de estabelecimento com validação de CNPJ e bloqueio de duplicidade para reduzir abuso do teste gratuito por e-mails diferentes. O Fluxora agora normaliza o documento, aceita o novo padrão alfanumérico de CNPJ, mostra mensagens mais claras quando houver erro e mantém as melhorias recentes de login do funcionário, fidelidade, navegação financeira e segurança do backend.
</pt-BR>
```

## Detalhes internos

- Cadastro de estabelecimento agora exige CNPJ válido para liberar o teste
  gratuito com segurança.
- Validação local no app e validação final no Supabase.
- CNPJ é normalizado para evitar duplicidade por pontuação ou formatação
  diferente.
- O mesmo CNPJ não pode criar outro estabelecimento usando outro e-mail.
- Suporte ao novo padrão alfanumérico de CNPJ da Receita Federal.
- Mensagens de erro mais claras para documento inválido ou já cadastrado.
- Login de funcionário, fidelidade, navegação financeira e manual inicial
  continuam preservados nesta build.
