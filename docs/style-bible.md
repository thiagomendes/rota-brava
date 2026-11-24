# Rota Brava · Bíblia de estilo (v0, para o Portão 1)

Status: **proposta do lead para aprovação de Thiago**. Referência de ritmo e apelo: séries de aventura pré-escolar em 3D com equipe de heróis (ex.: Patrulha Canina, PJ Masks). **Nada é copiado**: nenhum personagem, emblema, veículo, paleta-assinatura, logotipo, bordão ou música dessas séries. O que se toma é o princípio: equipe com identidade forte, cor-assinatura por herói, equipamento icônico, pose de equipe, mundo colorido e acolhedor, UI chunky e legível.

## 1. Tom
Aventura ensolarada, curiosa e gentil. Ninguém é vilão; o problema é alguém precisando de ajuda. Humor físico leve (o filhote e a buzina). Tudo arredondado, brilhante, limpo e “de brinquedo premium”.

## 2. Formas
- **Regra das três formas:** heróis = círculos (cabeça, olhos, mãos, botas); cenário = retângulos arredondados (casas, cais, caixas); natureza = gotas e nuvens (árvores, arbustos, rochas). Nada pontiagudo perto da criança.
- **Chanfro em tudo** (bevel visível de 1 a 4 cm conforme a escala); silhuetas com variação de largura (gordinho embaixo, estreito em cima nas casas; copa maior que o tronco nas árvores).
- **Escala:** heróis ~1,10 m; portas 2,0 m; o mundo é para adultos, os heróis são crianças: o farol, as casas e o barco parecem grandes ao lado deles.

## 3. Heróis (crianças-heróis)
| | Rastro (`tracker`) | Pico (`climber`) | Leme (`pilot`) |
|---|---|---|---|
| Idade aparente | 8 | 7 | 9 |
| Cor-assinatura | Laranja `#FF8A1F` | Verde `#3DBE5A` | Azul `#2F8CFF` |
| Cor secundária | Creme `#FFF1D6` | Amarelo corda `#FFD23F` | Branco `#F7FBFF` |
| Silhueta | Chapéu de aba larga com faixa do emblema; mochila-carteira lateral com caderno | Capacete arredondado com lanterna; rolo de corda a tiracolo; mosquetões grandes no cinto | Boné náutico; colete salva-vidas com faixas refletivas; bússola de pulso |
| Gesto-assinatura | Agacha, aponta a lupa, anota | Dois puxões na corda, punho erguido | Mão no volante, aceno aberto, “joinha” |
| Personalidade no idle | Olha em volta, consulta o caderno | Quica na ponta dos pés, alonga | Gira a bússola, sorri para o mar |

- **Proporção:** cabeça 33 a 38% da altura; olhos grandes (≥ 20% da altura da cabeça) com íris colorida, pupila e **dois brilhos**; sobrancelhas grossas e móveis; nariz botão; bochechas com leve rubor; boca que abre para falar.
- **Mãos:** 4 dedos, grandes e arredondadas; luvas em Pico.
- **Uniforme comum:** jaqueta curta de equipe com o emblema no peito (lado esquerdo), gola na cor secundária, cinto de equipe com fivela-bússola, botas grandes com sola clara. Cada um personaliza com o equipamento próprio.
- **Pele, cabelo e etnia:** trio diverso (tons de pele variados, cabelos com volume e cor contrastando com o uniforme).
- **Leitura:** reconhecível a 48 px e de costas pelo contorno do chapéu, capacete e rolo de corda, e boné e colete.

## 4. Emblema da Rota Brava
Escudo arredondado em forma de **gota/onda** com uma **rosa dos ventos** de 4 pontas no centro e uma faixa curva embaixo. Cores: azul-marinho `#123A5E`, amarelo `#FFC83D`, branco. Versões: completa (logo), simplificada (peito do uniforme) e monocromática (ícone de UI). Feito em SVG no projeto.

## 5. Paleta do mundo
- **Água:** raso `#4FD1C5` → fundo `#1A7A8C`; espuma `#F2FFFD`.
- **Madeira desbotada:** `#C9A57A` / `#9C7A55` / sombra `#6E5338`.
- **Vila:** fachadas em pastéis quentes (pêssego `#FFC9A3`, menta `#BDEBD3`, céu `#BFE3FF`, limão `#FFF0A8`, rosa `#FFC6D3`) com telhados terracota `#D8693F` e azul `#3A7BD5`; janelas com moldura branca.
- **Natureza:** verdes amarelados e saturados na luz (`#7CCB4A`, `#4FA83D`), azulados na sombra (`#2F7D5B`); rochas cinza-lilás `#A9A3B8`.
- **Céu:** topo `#4FA6E8`, horizonte `#FDE9C9`; nuvens fofas brancas com base lilás.
- **Ação do momento:** amarelo-ouro `#FFD23F` com brilho; é a única cor que pulsa.

## 6. Luz e atmosfera
Fim da manhã: sol quente (`#FFE6BE`) a ~45°, sombra fria azulada (nunca preta), contraluz suave nos heróis (rim), céu com nuvens, névoa leve de distância que separa planos, bloom discreto em brilhos e na água. Por etapa: chegada (sol aberto), rio (mais verde e sombreado), ilha (dourado de tarde), retorno (pôr do sol rosado).

## 7. Materiais
Toon suave com gradiente por região (topo mais claro), contorno fino só nos personagens e itens interativos, rim de luz quente, oclusão por altura. Textura pintada procedural: veio de madeira, ladrilho de telhado, costura e tecido nas roupas, brilho especular arredondado nos olhos e no casco. Nada de ruído que esconda pistas.

## 8. Composição e câmera
Câmera de 3/4 alta (~35°) na exploração, mais baixa nos momentos de descoberta e de equipe. Herói ocupa 12 a 18% da altura da tela na exploração; 40 a 60% nas apresentações. O caminho jogável é mais limpo; densidade nas bordas e no fundo. Marco sempre visível: o farol.

## 9. UI
Chunky e redonda: cantos de 24 a 32 px, contorno grosso claro, sombras suaves, ícones pictográficos (pata, bota, caderno, corda, leme, estrela), retratos circulares dos heróis com anel na cor-assinatura, botão de ação redondo grande, legenda em balão com retrato e emotes. Tipografia Fredoka (OFL) em pesos 600 a 700. Animações de entrada com mola (overshoot), troca de herói com “cartão de equipe” e pose. Sons em toda interação.

## 10. Som
Balbucio dos personagens (timbre próprio, intenção, sincronizado à boca) e rádio de Farol 7 em voz Piper filtrada para as instruções. Música de aventura com instrumentos reais (CC0): marimba, ukulele, metais leves, cordas pizzicato, percussão de praia; tema da equipe com motivo de 4 a 6 notas. Ambiente da vila (gaivotas, mercado, água, vento) em camadas.
