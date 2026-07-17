# Notas da versão 1.0.0 (build 17)

## Texto para o Google Play Console

```text
<pt-BR>
Corrigimos a recuperação de senha no aplicativo e na Web. O link agora retorna ao mesmo ambiente em que foi solicitado, abre a tela de nova senha sem esperar a animação inicial e orienta sobre links expirados ou abertos fora do app ou perfil de navegador correto. Também separamos a confirmação de conta da recuperação, adicionamos confirmação da nova senha e melhoramos as mensagens de erro, mantendo agendamentos e dados financeiros protegidos.
</pt-BR>
```

## Detalhes internos

- Portal web público com serviço, profissional, data, horário e confirmação.
- Agenda individual com múltiplos períodos diários e bloqueios gerais ou
  específicos.
- Proteção contra conflito simultâneo e repetição da mesma tentativa.
- Preço cheio para identidade pública ainda não confirmada.
- Associação manual e auditável a cliente fiel antes do checkout.
- Busca restrita por atendimento, com e-mail e telefone mascarados.
- RPCs públicas reduzidas ao conjunto mínimo necessário.
- Build web de produção validado.
- Recuperação de senha separada por plataforma sem quebrar o fluxo PKCE.
- Deep links Android/iOS ajustados para o manipulador usado pelo Supabase.
- 99 testes automatizados aprovados e análise Flutter sem erros.
