# Notas da versão 1.0.0 (build 16)

## Texto para o Google Play Console

```text
<pt-BR>
O Fluxora agora oferece agendamento online por link, sem exigir app do cliente. Configure serviços, expediente, intervalos, folgas e bloqueios de cada profissional. Reservas simultâneas e reenvios duplicados são protegidos no servidor. A nova opção “Associar a Cliente Fiel” corrige a identidade e recalcula o desconto antes do checkout, com dados mascarados e permissões restritas. Também incluímos melhorias de segurança, estabilidade e testes.
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
- 84 testes automatizados aprovados e análise Flutter sem erros.
