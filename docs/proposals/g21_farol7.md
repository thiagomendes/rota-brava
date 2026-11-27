# G21 · Farol 7, a base da equipe, e quem fala no rádio

Proposta do `adventure` (RB-R1, linha G21). Só documento: nada aplicado no jogo, no catálogo nem nas vozes.
Base: decisão de Thiago no G21 (`specs/features/RB-R1.md`), `SPEC.md` (Farol 7 = base e indicativo de rádio), `docs/proposals/ep01_v3_cutscenes.md`, `game/episodes/ep01/v3/ep01_v3_cutscenes.json`, `tools/voice/cast.json` (`farol7`, Schedar), `docs/style-bible.md`.

Nesta proposta a personagem é chamada de **[NOME]** até Thiago escolher.

## 0. Conflito encontrado (resolver junto)

- A vila hoje se chama **Farol 7** no texto: `ep01.narrator.intro.village` ("Esta é a Vila Farol 7, à beira-mar!") e `ep01.narrator.opening.village` ("Na vila Farol 7, hoje tem festa!").
- O plano 9 da `game_intro` mostra o **farol da vila** (`M7_LanternPivot`) com a fala "Aqui é o Farol 7". É justamente isso que faz a criança achar que o rádio é o farol da vila.
- O estilo de voz em `cast.json` descreve "o rádio amigo da vila".
- Proposta: a vila perde o "Farol 7" no nome. Fica só "a vila" ou ganha um nome próprio (sugestão: **Vila Maré**; Thiago decide). As duas falas do narrador entram na contagem de vozes (seção 4). O estilo de voz muda para "operadora da base da equipe" (seção 4.3).

## 1. Ficha do personagem

### Nome (3 opções para Thiago)
| Opção | Por quê |
|---|---|
| **Lumi** | Duas sílabas e lembra "luz", combinando com o farol. Fácil de dizer aos 4 anos. |
| **Nina** | Duas sílabas, sons que a criança já fala cedo. Calorosa e comum no Brasil. |
| **Tita** | Duas sílabas repetidas, o tipo de nome mais fácil para a idade. Soa como apelido carinhoso. |

Nenhuma das três lembra um personagem infantil conhecido, até onde sei. **Não fiz busca de marca** e isso fica em aberto, como já está o nome Rota Brava no `SPEC.md`. Nenhuma repete som de Rastro, Pico, Leme, Amora ou capitão.

### Quem é
- **Gênero:** proponho **mulher** ("a Lumi do Farol 7"), o que equilibra o elenco adulto (capitão, Dona Amora). **Pendente de confirmação por quem ouviu a Schedar.** Se a voz soar masculina, as opções viram Lumo, Nino e Tito, e os artigos mudam.
- **Idade:** adulta jovem, por volta de 30 anos. É mais velha que o trio (7 a 9 anos) e mais nova que o capitão e a Dona Amora.
- **Personalidade em 3 traços:**
  1. **Calma:** nunca apressa ninguém ("tudo bem ir com calma").
  2. **Atenta:** vê tudo no mapa e aponta uma coisa de cada vez.
  3. **Animada com pouco:** comemora cada acerto da equipe como se fosse grande.

### Como fala
- Frases de até cerca de 8 palavras e uma ideia por frase. Chama cada herói pelo nome antes da dica (o padrão que o Ep01 v3 já usa).
- **Expressão própria:** "**Na escuta!**". Abre quando ela entra no rádio ("Na escuta! Aqui é a Lumi."), sem repetir em toda fala: no máximo uma vez por missão, sempre na primeira entrada da ajuda.
- Voz Schedar, versão crua (aprovada em 2026-11-25). O tom muda de "locutor de notícias da vila" para "colega que cuida da equipe".

### Visual (para o `art3d`, no padrão dos secundários v2)
- **Silhueta-chave:** **coque alto e redondo** no topo da cabeça. Na lateral do fone sai uma **antena curta com bolinha coral**, e a bolinha é uma esfera simples na cor coral da atlas (o "acender" é opcional, ver seção 5). De costas e a 48 px, o contorno fica "coque + antena", diferente de todos:
  - Rastro: chapéu de aba larga.
  - Pico: capacete com lanterna.
  - Leme: boné náutico e fones. Os fones da Leme são de ouvido; os da [NOME] são de **arco com microfone de haste**.
  - Capitão: quepe e barba.
  - Dona Amora: lenço e cabelo grisalho.
  - Filhote: quadrúpede.
- **Roupa:**
  - Jaqueta de equipe azul `0B2440` com gola amarela `FFD23A` e o emblema no peito à esquerda, como o uniforme do trio. Uma faixa coral `E2453A` desce no ombro, só ela tem.
  - Calça clara e tênis com sola amarela.
  - Proporção adulta: cabeça menor na altura que a do trio, mas os mesmos olhos grandes com dois brilhos.
- **Fone e microfone:** arco amarelo `FFD23A`, conchas azuis e haste do microfone coral até a boca. A haste fica longe da boca o bastante para não esconder a boca que fala.
- **Acessório marcante:** a antena com bolinha coral no fone. É o "sinal de que ela está falando" e também aparece no retrato do HUD.
- **Pose base:** sentada numa cadeira giratória, que entra no cenário e não no modelo. Precisa também ficar de pé para um uso futuro.
- **Pele e cabelo:** diferentes dos tons do trio, do capitão e da Amora. Proposta: pele marrom-média, cabelo preto crespo no coque. O `art3d` confere o contraste com o fundo azul da sala.

## 2. A base Farol 7

### Onde fica
Numa **casa-torre pequena na ponta das pedras**, do outro lado da baía. A vila vê a base de longe e a base vê a vila pela janela. A base **não é o farol da vila**: o farol do M7 continua sendo da vila, alto, com a lanterna apagada que a equipe conserta.

### O cenário de um plano (`art3d`)
Uma sala só. A câmera vê três paredes e nunca precisa de teto inteiro.
- **Parede do fundo:** **janela redonda (escotilha grande)** para o mar. Dá para ver a vila pequenininha e, de longe, o farol da vila. É isso que mostra que são dois lugares.
- **Mesa do rádio:** console azul com 3 botões grandes nas cores dos heróis (laranja `#FF8A1F`, verde `#3DBE5A`, azul `#2F8CFF`), um microfone de mesa e uma luzinha que pisca quando ela fala.
- **Parede da esquerda:** **mapa da vila** ilustrado e simples. O cais, a praça, o galpão e o farol da vila aparecem como desenhos chapados, sem texto, e ícones das missões vêm do catálogo de ícones (estrela, pata, flor). Três "pinos" com os rostos do trio ficam espetados no mapa.
- **Parede da direita:** **emblema da Rota Brava grande** (o SVG do projeto em relevo) e um cabide com um colete e um capacete de reserva.
- **No alto:** clarabóia redonda por onde se vê a **luz giratória da base**, um feixe **amarelo** `FFD23A` curto em cima da casa. É diferente da lanterna do farol da vila (M7): a da base é pequena e baixa, e gira sempre, mesmo de dia.
- **Peças:** cerca de 10. Cadeira giratória, mesa, console, microfone, mapa, emblema, cabide, janela, clarabóia e caneca. Geometria original e chanfrada como manda a bíblia.

### Como a criança entende que é a base da equipe
1. **Cores e emblema:** a sala é toda azul, amarela e coral, as cores da equipe, com o emblema grande na parede. O farol da vila tem as cores da vila.
2. **Os rostos do trio estão no mapa:** a criança reconhece Rastro, Pico e Leme nos pinos e conclui que "é a casa deles".
3. **A janela mostra o farol da vila longe:** os dois aparecem no mesmo quadro, então não são o mesmo lugar.
4. **A fala diz:** o narrador diz "base da equipe" em voz alta (seção 3).
5. **Ela tem rosto:** daqui em diante a legenda do rádio mostra o retrato dela, e não um ícone de farol.

## 3. Roteiro do plano na abertura

### Onde entra
A `game_intro` tem hoje 10 planos e 34,5 s (`ep01_v3_cutscenes.json`, cena `game_intro`). O **plano 9** (4,0 s, `orbit` em `M7_LanternPivot`, fala `ep01.radio.intro.hello`) mostra o farol da vila. Proposta: **trocar o plano 9 por três planos na base**, num total de 10,0 s. O saldo é **+6,0 s**:
- `game_intro`: 34,5 → **40,5 s**.
- Orçamento total das cenas: 123,0 → **129,0 s**.

O lugar é bom porque vem depois de o trio se apresentar (a criança já conhece quem a base ajuda) e antes do fecho "Rota Brava, para a aventura!" (plano 10, sem mudança).

### Planos novos (durações estimadas, não medidas)
| # | s | Câmera | Quem e clipe | Fala (chave · texto) |
|---|---|---|---|---|
| 9a | 3,0 | Fora: a casa-torre na ponta das pedras, com a luz amarela girando. Corte para dentro com `dolly` lento, da escotilha até a cadeira de costas. | [NOME] de costas, girando a cadeira para a câmera (`turn_chair`) | `ep01.narrator.intro.base` (narrator) · **E aqui é o Farol 7, a base da equipe!** (8 palavras) |
| 9b | 3,5 | Plano médio frontal: ela na cadeira, com o mapa com os pinos do trio atrás à esquerda. | [NOME] `wave` e depois `talk` | `ep01.radio.intro.hello` (radio) · **Na escuta! Sou a [NOME], do rádio.** (7 palavras) |
| 9c | 3,5 | Aproxima da mão no microfone, com a escotilha e a vila longe ao fundo. **O disco da ajuda do HUD aparece e pulsa durante o plano.** | [NOME] `point` para a câmera e depois `thumbs_up` | `ep01.radio.intro.help` (radio) · **Precisou? Aperte {help} que eu ajudo!** (6 palavras com o glifo) |

- A fala 9c usa o marcador `{help}`. O G15 desenha o glifo do aparelho em uso: a tecla H no teclado, o botão do controle ou a mão no toque.
- **Texto falado (TTS) da 9c:** "Precisou? Aperte o botão de ajuda que eu ajudo!". A voz não lê o glifo, então a fala precisa de um texto próprio para a voz. O mesmo vale para qualquer fala com `{...}`.
- Com movimento reduzido, os três planos viram cortes, como todos os outros.
- `exit_look` sem mudança: a cena continua saindo para o plano 10 no `M0_RastroStart`.

## 4. Revisão das falas de rádio

**Observação:** não existe nenhuma chave `help.radio.*` no catálogo (busquei em `game/i18n/`). As dicas da ajuda em 3 degraus estão em `ep01.radio.v3_m*.*` (com sufixos `_2` e `_3`) e `ep01.radio.help.invite_*`. Revisei essas e as demais `*.radio.*` do Ep01 v3 (`ep01_v3_dialogue.json`). As `ep01.radio.objective.*`, `dock.*`, `river.*`, `island.*`, `docking.*` e `return.*` são do Ep01 v2 e **não foram revisadas**, porque o v3 não as usa: só aparecem em `game/audio/voice_catalog.json`.

### 4.1 Regra
- As **dicas de missão** (`ep01.radio.v3_m*`) **ficam como estão**. Já começam pelo nome do herói e são concretas; pôr o nome dela em cada dica alongaria as frases sem ajudar. Quem fala aparece no **retrato da legenda**.
- O **nome dela** entra só onde ela **chega ao rádio**: a apresentação e os convites da ajuda.
- `member.radio.name`: "Farol 7" → "**[NOME]**". O retrato do HUD passa a ser o rosto dela, com a antena acesa. O `speaker_for` não muda, porque a chave continua `radio`.

### 4.2 Trocas propostas (não aplicadas)
| Chave | Hoje | Proposta | Voz? |
|---|---|---|---|
| `ep01.narrator.intro.base` | (nova) | E aqui é o Farol 7, a base da equipe! | sim, nova (narrador) |
| `ep01.radio.intro.hello` | Aqui é o Farol 7, sempre no rádio! | Na escuta! Sou a [NOME], do rádio. | sim, trocada (já tem take) |
| `ep01.radio.intro.help` | (nova) | Precisou? Aperte {help} que eu ajudo! · voz: "…aperte o botão de ajuda…" | sim, nova |
| `ep01.radio.help.invite_1` | Farol 7 aqui. Quer uma ajudinha? | Na escuta! É a [NOME]. Quer ajuda? | sim, trocada |
| `ep01.radio.help.invite_2` | Precisam de mim? Estou no rádio. | (fica) | não |
| `ep01.radio.help.invite_3` | Tudo bem ir com calma, equipe. | (fica) | não |
| `ep01.radio.help.invite_4` | Uma dica? Escutem o Farol 7. | Uma dica? Aqui é a [NOME]! | sim, trocada |
| `ep01.radio.help.invite_5` | Olhem em volta. Eu ajudo! | (fica) | não |
| `ep01.narrator.intro.village` | Esta é a Vila Farol 7, à beira-mar! | Esta é a vila, à beira-mar! (ou "a Vila Maré") | sim, trocada |
| `ep01.narrator.opening.village` | Na vila Farol 7, hoje tem festa! | Na vila, hoje tem festa! (ou "Na Vila Maré…") | sim, trocada |
| `ep01.arrival.radio.festival`, `ep01.plaza.radio.water_back`, `ep01.lighthouse.radio.lights_on`, `ep01.festival.radio.night` | (como estão) | ficam | não |

**Contagem de voz:**
- **2 falas novas:** `intro.base` (narrador) e `intro.help` (Schedar, gravada a partir do texto falado, sem o glifo).
- **5 trocadas:** `intro.hello`, `invite_1`, `invite_4` e as duas falas do narrador com a vila.
- **Total: 7 takes** (4 da Schedar e 3 do narrador).
- Das 5 trocadas, só a `ep01.radio.intro.hello` já tem take gerado: o `voice_v3_catalog.json` tem 19 falas de rádio geradas e os `invite_*` não estão entre elas. O take da `intro.hello` tem de ser refeito e o antigo marcado como obsoleto.
- Cabe na cota diária de 100 do Tier 1.

### 4.3 Estilo de voz (`cast.json`, entrada `farol7`, não aplicado)
Trocar "Voz de Farol 7, o rádio amigo da vila, locutor gentil…" por "Voz de [NOME], operadora da base Farol 7 da equipe Rota Brava, calma e animada, fala de português do Brasil com boa dicção, como uma colega que cuida das crianças pelo rádio. Sem efeito de rádio: voz limpa." O artigo e o gênero dependem da confirmação da seção 1.

## 5. O que cada agente precisa

### `art3d`
1. **Modelo da [NOME]: critério de qualidade explícito (pedido de Thiago).** Ela tem de seguir o padrão dos outros personagens, e o modelo só entra no jogo se cumprir todos os pontos:
   - **Mesmo pipeline** do trio e dos secundários v2: SKIN + SUBSURF, atlas assada em PBR, sem contorno. Usar `source_art/characters/secondary_v2/sv2_human.py` (adulta, como o capitão e a Dona Amora) ou o gerador do trio, conforme a idade; para uma adulta de cerca de 30 anos, o `sv2_human.py`.
   - **Mãos encaixadas na manga, sem vão.**
   - **Olhos abertos (G1)** e **idle com braços relaxados.**
   - **Proporção coerente com o elenco:** mais alta que o trio, perto da altura da Dona Amora, com cabeça e olhos na mesma família de formas.
   - **Captura lado a lado** com o trio, o capitão e a Dona Amora (de frente, de costas e de perfil) e **revisão antes de entrar no jogo** (`reviewer`, depois Thiago).
   - **Realizável nesse padrão:** coque alto, fone de arco e haste do microfone são formas simples (esfera, toro e cilindro chanfrados) presas ao esqueleto pela cabeça, sem cabelo solto nem fio. A antena é um cilindro curto com uma esfera coral, pintados na atlas. Não precisa de material próprio: se o "acender ao falar" exigir material separado e quebrar a atlas única, ele fica de fora e quem fala continua sendo mostrado pelo retrato da legenda. Faixa coral no ombro e emblema no peito vão pintados na atlas, sem geometria extra. Se algum detalhe não sustentar o padrão, o `art3d` simplifica e avisa.
   - Clipes: `idle_seated`, `turn_chair` (de costas para a frente, cerca de 1 s), `wave`, `talk` (loop), `point`, `thumbs_up`, `idle_standing` (reserva).
   - Visemas, ou pelo menos boca que abre, como os outros que falam.
   - Rodar a auditoria `prop_overlap` (G6) no cenário.
2. **Cenário `base_farol7`**, separado da vila. Sala com cerca de 10 peças (seção 2), cadeira com pivô de giro e luz própria. O fundo visto pela escotilha pode ser uma imagem da vila tirada da cena real, com o farol da vila visível.
3. **Exterior da casa-torre** para o começo do plano 9a: uma peça pequena na ponta das pedras com a luz amarela giratória. Basta para um plano de 1 a 1,5 s.
4. **Retrato do HUD** no formato dos retratos v2 (E7), no mesmo padrão dos retratos do trio. Substitui o retrato atual do Farol 7.
5. Marcadores do cenário: `Base_Chair`, `Base_CamWide`, `Base_CamMic` e `Base_Exterior` (este último na vila, se a casa-torre entrar no mundo).

### `gameplay`
1. **Suporte a cena fora da vila na cutscene.** Hoje a câmera e os atores da ficha usam só marcadores de `village_world.tscn`. Os planos 9a, 9b e 9c pedem um destes dois caminhos:
   - (a) instanciar `base_farol7.tscn` longe da área jogável e expor os marcadores dele ao `ep01_v3_cutscene.gd`;
   - (b) o campo `"stage": "base_farol7"` no plano, que troca o palco durante o plano.

   A escolha e o teste são do `gameplay`.
2. **Ficha:** substituir o plano 9 de `game_intro` em `ep01_v3_cutscenes.json` pelos planos 9a, 9b e 9c (seção 3). Atualizar `total_duration` (123,0 → 129,0) e o orçamento do `ep01_v3_cutscenes.md`.
3. **Ator novo `operator`** (ou `radio`) no elenco da cutscene, com os clipes da seção 5. Acender a antena enquanto ela fala só se o `art3d` entregar isso sem sair do padrão (item 1 do `art3d`).
4. **Glifo na legenda.**
   - O `_sub_text` do HUD é um `Label` (`game/ui/hud.gd`, linha 88) e mostraria `{help}` escrito. A legenda precisa passar a usar o `GlyphText` (G15) quando o texto tiver um marcador.
   - Conferi que a intenção `help` existe na Input Map e que o `GlyphText` aceita qualquer intenção que ela tenha.
5. **Disco da ajuda aceso no plano 9c:** mostrar e pulsar o disco da ajuda do HUD durante a cutscene, só nesse plano, para a criança ligar a fala ao botão.
6. **Texto da voz separado da legenda** para falas com `{...}`: o campo `tts_text` em `gen_v3.py` ou no catálogo de vozes.
7. **Testes:**
   - a ficha da `game_intro` soma 40,5 s;
   - toda fala do plano novo tem chave no catálogo;
   - nenhum texto falado contém `{`;
   - a legenda com `{help}` mostra o glifo e não o marcador.
8. **i18n:** aplicar as trocas da seção 4.2 depois que Thiago escolher o nome e o nome da vila.

## 6. Pendências para Thiago
- Escolher o nome (Lumi, Nina ou Tita).
- Confirmar o gênero ouvindo a Schedar.
- Escolher o nome da vila: só "a vila" ou um nome próprio como "Vila Maré".
- Busca de marca dos nomes: não foi feita.
