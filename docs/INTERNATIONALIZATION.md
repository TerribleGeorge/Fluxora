# Internacionalização do Fluxora

O Fluxora foi preparado para receber usuários fora do Brasil.

## O que já foi configurado

- `flutter_localizations` foi adicionado ao projeto.
- `MaterialApp` agora usa:
  - `GlobalMaterialLocalizations`;
  - `GlobalCupertinoLocalizations`;
  - `GlobalWidgetsLocalizations`.
- A lista `FluxoraSupportedLocales.all` prepara o app para idiomas e variações
  regionais usadas em grande parte dos mercados globais.

Isso localiza automaticamente elementos de sistema, como:

- calendários;
- seletores de data e hora;
- botões e rótulos internos do Flutter;
- direção de texto em idiomas RTL, como árabe e hebraico;
- formatação regional suportada pelo sistema.

## O que ainda precisa ser traduzido por produto

Os textos próprios do Fluxora ainda precisam migrar gradualmente de strings
fixas para uma camada de tradução. Exemplos:

- menus;
- botões;
- mensagens de erro;
- patch notes;
- onboarding;
- descrições de fidelidade;
- nomes de relatórios.

## Estratégia recomendada

1. Manter `pt-BR` como idioma de origem.
2. Traduzir primeiro para:
   - inglês;
   - espanhol;
   - português de Portugal.
3. Depois expandir por mercado conforme houver usuários reais.

Essa estratégia evita publicar traduções ruins em dezenas de idiomas antes do
produto validar demanda nesses países.

## Regra de produto

Quando um texto afetar dinheiro, assinatura, privacidade ou exclusão de dados,
ele deve ser revisado com mais cuidado antes de entrar em outro idioma.
