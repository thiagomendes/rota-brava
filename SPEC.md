# Rota Brava — Especificação de produto e produção

Versão 0.1 · 23 de novembro de 2026  
Documento de referência para a raiz do projeto.

## 1. Visão de produto

Uma buzina soa no porto. Um barco amarelo encosta sozinho, uma caixa de pêssegos desliza pelo convés e alguém na multidão pergunta pelo piloto. A criança já pode andar até a amurada. Sobre o banco molhado há duas pegadas pequenas demais para pertencer ao piloto. Quem da turma ela chamaria?

**Rota Brava** é um jogo 3D de aventuras episódicas para crianças de 5 a 12 anos. O jogador comanda uma equipe de exploradores com talentos complementares. Cada episódio apresenta um mistério, leva a turma a campo e termina com alguém recebendo ajuda. A ação de um integrante muda o que o próximo consegue fazer. A recompensa principal é presenciar a consequência da própria intervenção.

| Decisão | Direção de produção |
|---|---|
| Marca | Rota Brava é o título de trabalho e o nome da equipe. Farol 7 é a base e o indicativo de rádio. O nome Rota Brava já apareceu em conteúdo de viagens. A disponibilidade para registro e uso internacional permanece em aberto. |
| Primeira entrega | Um episódio completo para Windows, jogável offline por uma pessoa. Android e iOS entram no desenho de entrada, interface e desempenho desde o início. |
| Idiomas | Vozes, textos e legendas em português brasileiro no piloto. Novos idiomas entram por dados, inclusive nas sequências dirigidas. |
| Produção | Thiago dirige e aprova. Agentes executam roteiro, código, arte, animação, som, integração e revisão. O jogo distribuído roda localmente, sem chamadas a modelos de IA. |
| Direção técnica | Godot 4 estável, GDScript tipado, renderizador Mobile também no Windows e Blender para autoria. Fixar as versões efetivamente testadas no primeiro build. |
| Escopo do piloto | Três protagonistas, um cais, um trecho de rio, uma ilha, um piloto e um filhote. Farol 7 participa pelo rádio. |
| Expansão | Avaliar outros episódios, uma base explorável e novos personagens após comprovar a qualidade e o custo de produção do primeiro episódio. |

**Prioridades de produto:** direção de arte 3D original, UI/UX infantil, animação e produção de áudio. Planejar o trabalho dessas disciplinas desde o primeiro trecho jogável. Reservar tempo para a revisão do resultado integrado.

As referências de séries infantis orientam o ritmo de aventura em equipe. Criar elenco, emblemas, figurinos, veículos, música, falas e identidade visual próprios. Os desenhos físicos, as vozes, a duração e as metas numéricas abaixo são propostas iniciais. O primeiro trecho aprovado estabelece a referência para o restante da produção.

## 2. Equipe de exploradores

Usar **Rastro, Pico e Leme** como chamados em pt-BR. Os identificadores internos são estáveis mesmo se a direção mudar um nome. Para o primeiro estudo visual, representar os três como jovens exploradores humanos. A aparência definitiva depende da aprovação das silhuetas. Cada integrante deve ser reconhecível de costas e em miniatura.

| Integrante | Silhueta, gesto e personalidade | Ação que o jogador domina |
|---|---|---|
| **Rastro**, a rastreadora (`tracker`) | Caderno lateral e postura baixa ao investigar. É observadora, dá tempo para os outros responderem e desenha a pista antes de anunciar a conclusão. | Examinar rastros, comparar evidências e apontar o caminho. Uma escolha incorreta convida a olhar para um detalhe concreto. |
| **Pico**, o especialista em travessias (`climber`) | Corda enrolada e mosquetões arredondados. Gosta de chegar ao alto e sempre testa a linha com dois puxões. | Escolher apoios, atravessar e fixar uma linha persistente. A próxima pessoa usa o caminho que ele abriu. |
| **Leme**, a piloto (`pilot`) | Colete de navegação e mãos expressivas no volante. Conversa com o motor e conhece os sons dos barcos. | Pilotar, ler a direção da corrente e alinhar a embarcação para outra pessoa embarcar. Aproximações admitem correção. |

A escolha de personagem tem consequência mecânica. No piloto, a câmera mostra quem está em posição de agir, a criança confirma e assume o controle. Os outros respondem com gesto, fala ou movimento visível. O roteiro distribui descobertas e decisões entre os três. Em episódios futuros, alternar quem percebe o problema e quem propõe o plano.

## 3. Episódio 01 — O barco sem capitão

Duração inicial pretendida de 8 a 12 minutos, a confirmar em jogo. Adotar câmera em terceira pessoa dirigida por área. Construir uma geografia compacta e compreensível entre porto e ilha. O filhote está acompanhado e o piloto acena ao avistar a equipe. A tensão vem de descobrir como ajudá-los.

| Etapa | Ação jogável e condição de avanço | Direção e recuperação |
|---|---|---|
| 0 · Chegada | Selecionar Jogar. Ver a chegada do barco e assumir Rastro quando ele para. Pular a abertura leva ao mesmo ponto de controle. | A buzina, o deslocamento da caixa e a reação de Leme contam o ocorrido mesmo com vozes desligadas. |
| 1 · Investigar | Examinar a marca no banco e a pegada de bota na margem, em qualquer ordem. Escolher a margem como destino. | Ícones distintos mostram pata e bota. Inspecionar uma pista que não resolve a dedução gera uma observação específica. Salvar após a dedução. |
| 2 · Subir o rio | Assumir Leme, contornar uma boia e chegar à enseada. A direção da água se lê pelo movimento das folhas. Avistar o piloto com o filhote. | Margens guiam de volta para a rota. O barco desacelera perto de obstáculos. Salvar ao desembarcar Pico. |
| 3 · Abrir a travessia | Com Pico, escolher apoios numa rocha, cruzar o braço do rio e fixar a linha entre os pontos marcados. | Mostrar a ilha e o barco juntos. Um passo perdido devolve Pico ao último apoio seguro. Os dois puxões confirmam que a linha está pronta. Salvar. |
| 4 · Atracar | Voltar a Leme. Usar a linha como guia e alinhar o barco no lado protegido. Confirmar embarque quando casco e plataforma estiverem próximos. | No modo assistido, estabilizar direção e velocidade nos metros finais. Permitir nova aproximação sem reiniciar a etapa. |
| 5 · Voltar | O jogador aciona a partida. O piloto agradece. O filhote pisa na buzina e resolve a piada da abertura. | Registrar conclusão uma vez. Oferecer rever episódio ou voltar ao menu. Rejogar inicia uma execução limpa e preserva o registro de conclusão. |

**Profundidade opcional.** No rio, oferecer uma rota por trás de um banco de areia. A criança que observa a corrente encontra uma aproximação mais suave. Validar primeiro o caminho principal.

**Primeiro minuto de referência.** Produzir um trecho reproduzível da chegada do barco até a descoberta da primeira pegada. Ele concentra água, personagem, animação facial, câmera, locução, som espacial, toque e interface de inspeção. Aprovar esse minuto em execução real antes de multiplicar cenários ou gravar todas as falas.

## 4. Direção de arte e autoria 3D

**Toda geometria apresentada à criança será construída do zero para Rota Brava.** Isso inclui protagonistas e seus corpos-base, moradores, animais, barcos, construções, vegetação, pedras, acessórios, figurinos e objetos de fundo. Malhas prontas, kits comerciais, personagens-base de terceiros, modelos baixados e peças de bibliotecas de kitbash ficam excluídos inclusive dos cenários secundários.

Primitivas matemáticas, ferramentas do Blender e geração procedural escrita para o projeto são métodos válidos. Blocos simples feitos pela equipe servem para prototipagem. Identificá-los como temporários até a aprovação artística. Reutilizar peças modulares originais produzidas para Rota Brava.

### Linguagem visual

Aventura 3D estilizada com proporções expressivas e materiais fáceis de distinguir. No cais, a madeira desbotada e a água verde-azulada formam o fundo. O casco amarelo conduz o olhar até a pista. Reservar o contraste mais alto para a ação do momento.

Usar espuma junto ao casco, balanço discreto da boia e reflexos simplificados para comunicar corrente e velocidade. Testar sombras e reflexos com a câmera de jogo no renderizador escolhido. Preservar leitura sob luz clara e sombra. Evitar ruído de superfície que esconda as pegadas.

### Personagens em movimento

Antes de modelar o trio inteiro, desenhar três silhuetas por integrante, escolher uma e criar vistas frontal, lateral e traseira com proporções e expressões. Produzir primeiro Rastro em escala final.

Aprovar andar, parar, abaixar, tocar a pista e voltar o olhar para Leme. Os pés mantêm contato com o chão e a mão alcança a marca sem atravessar o banco. Para Pico, verificar contato das mãos com os apoios. Para Leme, verificar mão no volante e inclinação nas curvas. Testar na distância real da câmera.

### Entrega por ativo final

1. Fonte editável em Blender e texturas-fonte ou receita procedural do projeto. Registrar agente, processo e arquivos de origem em um manifesto versionado.
2. Exportação glTF/GLB reproduzível, escala em metros, origem funcional, nomes estáveis e materiais identificados. O barco tem pivô coerente com a manobra. Dobradiças giram no eixo real.
3. Para personagens, incluir rig editável, pesos e animações nomeadas. Conferir deformação de ombro, joelho e rosto nas poses extremas.
4. Importar na Godot, acrescentar colisão simples e comportamento numa cena própria. Manter modificações de gameplay fora da cena gerada pelo importador para que reexportar preserve o trabalho.
5. Entregar vista do modelo, imagem da malha e captura em jogo. Fazer uma pequena alteração na fonte e repetir a importação no primeiro ativo de cada tipo. Origem desconhecida, modelo pronto ou ausência de fonte exige correção antes da aprovação.

Medir materiais, chamadas de desenho, transparência, memória e tempo de GPU na cena crítica antes de fixar orçamento de polígonos ou reduzir detalhes do elenco.

## 5. UI e UX infantil

A criança deve entender três coisas em qualquer momento jogável: **quem controla, o que pode fazer agora e o que mudou ao agir**. Os ícones de caderno, linha e leme repetem formas reais do equipamento, desenhadas no estilo do cenário. Nas telas 2D, usar tipografia com acentos bem desenhados, pictogramas originais e hierarquia de foco consistente.

| Situação | Implementação esperada | Critério observável |
|---|---|---|
| Menu e retomada | Continuar quando existir checkpoint, Jogar/Rejogar e Opções. Pedir confirmação para iniciar nova execução sobre uma partida em andamento. | Primeiro controle com foco. Todas as telas permitem confirmar, voltar e recuperar foco após pausar. |
| Exploração | Um objetivo ativo, pista visual no mundo e ação contextual perto do alvo. Em sobreposição, priorizar o alvo enquadrado e manter foco estável. | Ao aproximar-se do banco, aparece Examinar com ícone. Ao afastar-se, some. Uma pressão gera uma interação. |
| Troca de integrante | O personagem ativo olha para quem vai agir. Mostrar retrato e símbolo da habilidade do próximo. Transferir câmera e controle após confirmação. | A criança vê de onde o próximo integrante parte. Pressão mantida não atravessa duas confirmações. |
| Ajuda | Botão para repetir instrução. Após inatividade jogável, apresentar primeiro gesto ou olhar, depois pista falada curta. Pausa e leitura ficam fora do contador. | A ajuda explica uma ação concreta, como “Olha o tamanho da marca no banco”. Há tempo para experimentar antes da próxima dica. |
| Leitura e acesso | Legendas ajustáveis com nome do falante, fundo contrastante e quebra por frase. Codificar objetivos por forma, gesto e som. Oferecer redução de movimento, volumes separados e assistência de pilotagem. | A missão é compreensível com áudio desligado. Uma criança em alfabetização pode seguir as instruções faladas e os gestos. |
| Toque | Layout horizontal com áreas seguras, alvo inicial de pelo menos 48 dp equivalentes, movimento de um lado e ação do outro. Calibrar tamanho físico no aparelho. | Duas ações simultâneas funcionam. Soltar ou cancelar o toque zera o controle correspondente. A mão não encobre o atracadouro no enquadramento final. |

**Entrada.** Mapear intenções na Input Map. Teclado usa WASD/setas, E para interagir e Esc para pausar/voltar. Controle usa analógico, botão primário e menu. No toque, oferecer direcional e botão contextual. Menus aceitam mouse, toque e navegação por foco. A câmera acompanha automaticamente. A ação contextual abrange examinar, fixar, entregar controle e embarcar conforme a etapa. Exibir o comando do último dispositivo usado sem alterar o estado do episódio.

**Validação.** Capturar menu, cais, inspeção e atracação em 16:9, telefone alongado e tablet 4:3. Conferir legenda máxima, foco, ícones, sobreposição das mãos e área segura. Fazer uma passagem sem locução e outra com foco na comunicação oral. Registrar reações reais quando houver teste voluntário acompanhado com crianças. Até lá, descrever adequação etária como hipótese. Incluir um percurso assistido e outro exploratório na revisão.

## 6. Produção de áudio

O som fornece informação jogável. A buzina revela a chegada antes da câmera enquadrar o barco. A mudança de rotação do motor ajuda a atracar. Os dois estalos da linha confirmam a ação de Pico. Toda pista sonora essencial tem equivalente visual.

| Camada | Direção de produção | Aceite |
|---|---|---|
| Voz | Uma voz consistente por integrante, com intenção, ritmo e pronúncia registrados. Rastro fala baixo e claro. Pico confirma em frases curtas. Leme conversa em movimento. Aprovar uma fala normal, uma de urgência e uma de descoberta por voz. | Sem sílabas cortadas, pronúncias inconsistentes ou mudança de timbre entre tomadas. Testar com correnteza e motor ligados. |
| Ambiente e efeitos | Separar água perto do cais, vento leve, casco, passos em madeira, motor e corda. Variar passos e impactos. Usar intensidade e velocidade da ação para modular o efeito. | O passo acompanha contato visível. O motor responde ao controle. Os loops atravessam a emenda sem clique. |
| Música | Tema instrumental original com versões de descoberta, exploração e retorno. Preservar espaço na mixagem para pista e diálogo. | Entradas e saídas por seção ou transição curta, sem corte perceptível. Pausar e retomar soa natural. |
| Mixagem | Buses Master, Voz, Música, Efeitos e Ambiente. Fazer ducking suave da música durante falas. Priorizar uma fala narrativa por vez e cancelar dicas antigas ao mudar de etapa. | Comparar em fones, alto-falantes de notebook e telefone. Medir pico do master na chegada e atracação. Teto inicial de −1 dBTP no material capturado. Confirmar inteligibilidade e ausência de saturação. |

Guardar fontes sem perdas, pistas separadas, roteiro de gravação, ferramenta/origem e permissões de uso de vozes e música. Exportar versões de runtime conforme tamanho e qualidade medidos. Cada fala recebe ID, personagem, intenção, idioma, legenda e arquivo.

A fala “Farol 7, aqui é Rota Brava. Achamos o barco.” testa a pronúncia do nome da equipe, o filtro de rádio e a inteligibilidade. Aprovar clipe audiovisual com locução, ambiente e música juntos antes da produção em lote.

## 7. Arquitetura de execução

Estrutura proposta para um repositório novo. Em projeto existente, preservar convenções compatíveis. Manter fontes pesadas de autoria fora da árvore importada pela engine.

```text
SPEC.md
game/project.godot
game/export_presets.cfg
game/core/                 # sessão, progresso e opções
game/episodes/ep01/        # cena principal, direção e dados do episódio
game/actors/               # personagens, barco e interações
game/ui/                   # telas, HUD, tema e foco
game/audio/                # buses, arquivos runtime e catálogo de falas
game/i18n/                 # chaves e traduções
game/tests/                # testes determinísticos e cenas mínimas
source_art/                # arquivos Blender, texturas e proveniência
source_audio/              # fontes, vozes, sessões e stems
tools/                     # validação, conversão e exportação
specs/features/            # tickets SDD e evidências
```

| Componente | Responsabilidade e contrato |
|---|---|
| EpisodeDirector | Possui o estado da missão. Recebe eventos validados, aceita transições permitidas, ativa o personagem e pede apresentação da próxima ação. Usar máquina de estados explícita para EP01. |
| Atores e interações | Controlam movimento, alcance, animação e interação local. Publicam eventos com ID estável, como pista examinada, linha fixada e barco atracado. Leem ações da Input Map. |
| Mundo | Constrói a cena a partir do estado atual. Linha fixada, pilotagem disponível, localização do piloto e estado do barco são reaplicáveis após carga. |
| HUD e câmera | Consomem estado e sinais de apresentação. Pedem confirmação, pausa ou ajuda. A conclusão da etapa pertence ao diretor. |
| Áudio e localização | Resolvem IDs de fala e conteúdo por idioma. Notificam fim, cancelamento ou avanço manual. Uma fala ausente conserva a legenda e libera a sequência. |
| Persistência | Grava em `user://` ao concluir etapas estáveis. Separar preferências, progresso histórico e execução atual. Escrever em temporário e substituir com backup recuperável. |

**Estado.** Usar IDs como `ep01`, `dock_investigation`, `river_search`, `island_crossing`, `docking` e `complete`. Campos mínimos: versão do esquema, episódio, checkpoint, pistas encontradas no checkpoint, linha fixada e episódios concluídos. Salvar IDs e valores simples. Reconstruir nós a partir deles.

Eventos duplicados, atrasados ou emitidos pelo personagem inativo não concedem progresso. Para a entrada na ilha, exigir `river_search` e chegada válida. Para concluir a atracação, exigir `docking`, linha fixada e proximidade/alinhamento do barco.

**Retomada.** Ao salvar a fixação, restaurar diretamente a etapa de atracação com a linha presente, Pico em segurança e Leme no comando. Sair no meio de uma travessia retorna ao último ponto estável. Em arquivo corrompido, recuperar backup. Sem backup válido, oferecer reiniciar o episódio preservando opções legíveis. Testar fechar durante gravação, reabrir, repetir evento e rejogar episódio concluído.

**Recorte técnico.** Correnteza por zonas com direção e intensidade reguláveis. Aproximação orientada por área e tolerância ajustável. A corda mantém dois pontos e uma curva visual. Os eventos de gameplay dependem dos pontos fixados. A travessia pode ser testada sem simulação física complexa.

## 8. Localização desde a primeira entrega

Português brasileiro é o idioma completo do piloto. Versionar catálogos de texto e de falas. Separar idioma de interface/legendas e idioma de voz nas opções. Ao faltar recurso no idioma escolhido, usar pt-BR como fallback, registrar a ocorrência e manter a sequência jogável. Detectar chaves ausentes na validação de conteúdo.

| Campo | Exemplo |
|---|---|
| ID | `ep01.dock.tracker.small_print` |
| Falante e contexto | `tracker`, examinando o banco pela primeira vez |
| Texto pt-BR | “Essa pegada cabe na palma da minha mão.” |
| Apresentação | Legenda com nome localizado e duração baseada no clipe. Avanço manual disponível. |
| Associação de voz | ID da fala e idioma direcionam ao clipe correto. |

Usar mensagens completas e parâmetros nomeados. Manter textos fora das texturas e das regras de missão. Placas narrativas recebem conteúdo localizável. Usar identificadores estáveis para equipe e integrantes e um glossário com grafia, intenção e pronúncia.

Testar pseudoidioma com acentos, texto expandido em 40% e um clipe propositalmente mais longo. Aceite: legenda inteira, botões utilizáveis, fala seguinte aguarda a anterior e pular uma fala preserva a próxima interação.

## 9. Build, desempenho e verificação

Fixar versão e checksum da engine, templates correspondentes e versão do Blender. Versionar perfis de exportação sem credenciais. Rodar importação limpa e exportação Windows na integração. Exemplo a partir da raiz, após criar o perfil `Windows Desktop` e instalar os templates da versão fixada:

```powershell
$ErrorActionPreference = 'Stop'
$godot = (Get-Command godot -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path 'build/windows' | Out-Null

& $godot --headless --path game --import
if ($LASTEXITCODE -ne 0) { throw 'Falha na importação do projeto Godot.' }

& $godot --headless --path game --export-release 'Windows Desktop' '../build/windows/RotaBrava.exe'
if ($LASTEXITCODE -ne 0) { throw 'Falha na exportação para Windows.' }
```

Quando Godot não estiver no PATH, resolver o caminho do executável console instalado e passá-lo explicitamente. Registrar o comando efetivamente executado.

Abrir o executável em Windows e iniciar uma missão. Build headless valida exportação. Revisão visual e sonora exige execução com renderização e áudio. Linux remoto pode hospedar desenvolvimento, importação e exportações compatíveis. Para Android, configurar SDK/JDK compatíveis e instalar a build num aparelho. Para iOS, prever macOS, Xcode e assinatura para teste em dispositivo.

Verificar toque, área segura, pausa ao perder foco, retomada e áudio após interrupção no primeiro teste de cada plataforma.

| Alvo | Meta inicial | Como verificar |
|---|---|---|
| Windows | 1080p, 60 fps, orçamento de 16,7 ms/quadro | Identificar GPU, RAM, SO, renderizador e build. Medir p95 em três passagens da chegada e da atracação após aquecimento. |
| Celular de referência | 30 fps, orçamento de 33,3 ms/quadro | Registrar aparelho e resolução interna. Repetir a cena por dez minutos e observar travadas e degradação. |

Registrar separadamente as plataformas efetivamente verificadas. O aceite do piloto Windows depende de execução real em Windows.

Referências oficiais para a versão fixada: [Renderizadores](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [linha de comando](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) e [iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

## 10. Plano de execução para agentes

Cada tarefa cabe em uma feature branch local. O orquestrador transmite ao executor a seção da spec, estado inicial, comportamento esperado, arquivos pertinentes, decisões aprovadas e evidência pedida. O executor implementa a menor mudança completa e reproduz o caminho do usuário. O revisor confere integração e comportamento observável. Ao reprovar, devolve defeito reproduzível, expectativa e ponto de retorno.

| Ordem | Entrega | Evidência |
|---|---|---|
| 01 · Fundação | Fixar ferramentas, criar projeto Godot, perfil Windows, Input Map, cena inicial e controles de foco. | Checkout limpo gera executável que abre, aceita entrada e fecha corretamente. Registrar comandos e versões. |
| 02 · Missão em blocos | Construir o episódio inteiro com primitivas próprias, três ações centrais e estados do diretor. | Vídeo da chegada à conclusão. Testes das pistas em ambas as ordens, avanço indevido e evento duplicado. |
| 03 · Referências | Estudos de elenco, barco, cais e HUD, amostras de voz e música. Produzir um ativo original com ida e volta Blender → Godot. | Prancha, malha, fonte editável, três falas e captura na câmera real. Thiago escolhe a referência de produção. |
| 04 · Primeiro minuto | Finalizar chegada e primeira inspeção com arte original, animação, interface, mixagem e ajuda. | Build, vídeo com som, captura em tamanho de telefone, proveniência e tempos de quadro. Aprovação artística de Thiago. |
| 05 · Episódio final | Estender a referência ao rio, à travessia e à atracação. Integrar save, retomada, opções, replay e locução. | Completar por teclado e controle, retomar cada checkpoint e reproduzir sequência final uma vez. |
| 06 · Portabilidade e idioma | Executar percurso em Android, preparar e validar perfil iOS conforme ambiente disponível, aplicar pseudoidioma e fala longa. | Relatório por plataforma com aparelho e resultado. Identificar pendências de assinatura ou hardware. Capturas de toque, legendas e retomada. |
| 07 · Candidato do piloto | Corrigir falhas de clareza, acabamento e desempenho. Revisar fontes dos modelos e áudio final. | Build Windows identificada por commit, checklist com evidências, pendências e decisão de aceite. |

**Exemplo de ticket para executor de baixo esforço — RB-02A, investigar o banco.** Partir da cena do cais em blocos e da etapa `dock_investigation`. Implementar as interações da pata e da bota. Ao confirmar dentro do alcance configurado, guardar o ID da pista uma vez, exibir símbolo correspondente e tocar a observação localizada. A segunda pista libera a escolha de margem. A transição para `river_search` ocorre quando a criança confirma a margem correta. Entregar teste das duas ordens, tentativa repetida, confirmação distante e tentativa de avançar com uma pista. Anexar clipe de uma interação por teclado e indicar o comando de teste. Modelagem final e navegação do barco pertencem a outros tickets.

## 11. Definição de pronto do piloto

- [ ] Uma partida nova e uma retomada chegam ao encerramento. Rastro, Pico e Leme têm ações distintas, necessárias e compreensíveis.
- [ ] Cada fonte 3D é editável e rastreável. Todos os modelos em tela foram produzidos do zero para o projeto. Ativos temporários foram substituídos ou aprovados como arte final após revisão.
- [ ] O primeiro minuto e a cena mais carregada receberam avaliação de movimento, materiais, contato físico, iluminação, composição, UI e som em execução.
- [ ] Menu, pausa, opções, repetição de fala, troca de personagem e rejogar funcionam. Foco, toque e legenda foram revistos nos formatos definidos.
- [ ] O episódio funciona com som desligado e oferece condução por fala e gesto para crianças em alfabetização. Dicas e assistência permitem recuperar erros.
- [ ] A mixagem mantém voz inteligível, sem cortes audíveis, falas sobrepostas ou falhas de loop. Fontes e usos de áudio estão documentados.
- [ ] Pt-BR está completo. O pseudoidioma e o teste de duração de voz passaram.
- [ ] A build é reproduzível e as metas de desempenho foram medidas. O relatório distingue medições realizadas, problemas conhecidos e testes pendentes.
- [ ] Thiago avaliou o episódio completo. A decisão de produzir o segundo episódio considera diversão, clareza para o público e custo de repetir o padrão audiovisual.

## 12. Operação local no OpenCode Desktop para Windows

Abra a pasta que contém este SPEC.md como projeto. Na sessão inicial com capacidade de editar e executar comandos, selecione no catálogo do provedor Sonnet 5.5 com esforço alto, se disponível. Cole o bloco da seção 13. O prompt autoriza criar os perfis locais e começar o desenvolvimento.

### Modelos e roteamento

Um agente primário, `rota-lead`, faz arquitetura, decomposição, síntese de evidências e integração. Subagentes especializados trabalham por ticket. Configurar cada executor explicitamente em baixo esforço para evitar herdar o esforço alto do orquestrador.

Verificar versão instalada, esquema suportado e catálogo da conta antes de escrever a configuração. Na sintaxe documentada com variantes, o exemplo para o primário é `anthropic/claude-sonnet-5-5#high`. Usar a variante `low` quando oferecida pelo provedor. O modelo selecionado na sessão pode ser independente do agente primário selecionado. Conferir ambos e registrar a configuração efetivamente utilizada. Qualquer fallback deve usar modelos já autorizados e deixar explícita a diferença.

Usar perfis em `.opencode/agents/<agente>.md` e procedimentos reutilizáveis em `.opencode/skills/<habilidade>/SKILL.md` conforme a versão instalada. Cada skill deve declarar entradas, procedimento, teste e entrega. Referenciar as seções desta spec para evitar versões divergentes. Testar uma delegação curta antes de confiar no roteamento.

### Papéis dos agentes

| Perfil | Competências e skills | Entrega característica |
|---|---|---|
| `rota-lead` · primário · alto | SDD, arquitetura, direção de produto, dependências, Git local e integração | Contrato da tarefa, decisões, merge verificado e próxima tarefa pronta |
| `gameplay` · baixo | Godot/GDScript, atores, entrada, câmera, estados, save e testes determinísticos | Mecânica jogável e teste de estado/recuperação |
| `adventure` · baixo | Design de missões, puzzles cooperativos, narrativa infantil, roteiro localizado e assistência gradual | Cena com pistas, alternativas e transições verificáveis |
| `art3d` · baixo | Blender, modelagem original, rig, animação, materiais, luz, GLB e orçamento gráfico | Fonte editável, proveniência, importação reproduzível e captura na câmera de jogo |
| `ux` · baixo | UX infantil, UI Godot, foco, entrada multimodal, acessibilidade, localização e áreas seguras | Fluxo navegável e evidências em proporções de tela distintas |
| `audio` · baixo | Direção de voz, foley, composição, implementação, mixagem e sincronização | Stems, takes, IDs de fala e captura da mixagem em jogo |
| `build-qa` · baixo | Windows/PowerShell, exportação Godot, profiling e testes em aparelho | Build executável, comandos reproduzíveis, métricas e limitações observadas |
| `reviewer` · baixo | Revisão independente de código, conteúdo, regressão, autoria e acessibilidade | Parecer por critério com evidência, defeito reproduzível ou aprovação |

Acionar apenas a especialidade necessária ao ticket. Um revisor diferente do autor examina o resultado. O primário integra. Especialistas editam o escopo atribuído. O revisor inspeciona e executa verificações. Confirmar acesso real a Godot, Blender, dispositivos e ferramentas de áudio antes de prometer resultados. Quando faltar uma ferramenta, preparar as fontes ou a automação possível e identificar a evidência pendente.

### Git e Windows

Detectar shell e caminhos reais. Preferir PowerShell para automação nativa. Manter artefatos de build, cache `.godot` e credenciais fora do histórico. Para trabalho concorrente, usar `git worktree add` com diretório irmão e branch própria. Manter um único responsável por cada arquivo em edição. Serializar alterações de `project.godot`, cenas compartilhadas, arquivos Blender e integração.

Referências: [Agentes do OpenCode](https://opencode.ai/docs/agents/), [modelos e variantes](https://opencode.ai/docs/models/) e [skills de projeto](https://opencode.ai/docs/skills/).

## 13. Prompt inicial — copiar no OpenCode Desktop

```text
Você é o orquestrador técnico e de produção de Rota Brava. Leia SPEC.md na raiz e as instruções aplicáveis do repositório. Sua missão é IMPLEMENTAR e integrar o piloto, começando agora pela tarefa 01. Use a spec como contrato de produto. Trabalhe até o próximo resultado jogável e prossiga pelas dependências enquanto houver trabalho autorizado. Ao iniciar uma nova sessão, reconstrua o estado por Git, tickets, evidências e última build.

1. Inspecione a pasta, git status, branch de integração existente, ferramentas e versões reais no Windows. Preserve alterações do usuário. Se a pasta ainda não for repositório, inicialize Git local com main e faça um baseline apenas dos arquivos pertinentes. Crie feature/rb-01-fundacao. Configure exclusões e ferramentas de maneira reproduzível. Trabalhe localmente, sem publicar ou fazer push.

2. Configure o workflow agêntico da seção 12 na versão instalada do OpenCode. Você é rota-lead, preferencialmente Sonnet 5.5 com esforço alto. Para os subagentes, use Sonnet 5.5 com esforço baixo explicitamente, conforme o catálogo disponível. Confira a configuração efetiva da sessão e da primeira delegação. Use somente modelos e provedores já autorizados. Se as variantes exatas estiverem indisponíveis, use a configuração autorizada mais próxima, registre a diferença e siga com o trabalho viável. Crie os perfis e skills locais à medida que forem necessários. Delegue com o mecanismo nativo de subagentes disponível. Se faltar suporte, registre o impedimento real e execute tarefas independentes na sessão atual.

3. Pratique Spec-Driven Development (SDD) em cada feature. Antes do código, registre um ticket curto em specs/features/RB-XX.md. Inclua objetivo observável, referência à SPEC, escopo, contrato de entrada/saída ou interação, critérios de aceite, casos de falha e verificação. Prefira a solução mais simples que satisfaça esses critérios. Registre as evidências no mesmo ticket. Corrija a implementação quando divergir do contrato. Mudanças de produto ficam explícitas.

4. Crie uma feature branch local por tarefa. Dê a cada executor um objetivo pequeno, área de escrita, dependências, critérios e uma forma concreta de provar a entrega. Paralelize somente tarefas independentes, usando worktrees separados para escritas simultâneas. Peça commits focados. Preserve binários editáveis e mantenha builds e caches fora do Git. Se um .blend tiver conflito, escolha um responsável para integrar e reexportar a partir das fontes. Valide visualmente o resultado.

5. Peça revisão independente. O revisor verifica diff, testes e o caminho real do jogador, além das evidências audiovisuais pertinentes. Falha gera correção e nova revisão. Após três reprovações pelo mesmo problema, reavalie a estratégia, reduza o recorte ou troque o especialista. É sua responsabilidade resolver a integração. Com critérios atendidos, revisão concluída e verificações passando, faça o merge LOCAL por conta própria na branch de integração. Resolva conflitos dentro do escopo, rode o smoke test no resultado integrado, registre commit e evidências e inicie a próxima feature disponível. Um teste headless não comprova renderização, som, UX ou desempenho.

6. Exerça autonomia sobre arquitetura reversível, detalhes de implementação, branches, commits, merges, tentativas de correção e ordem de tickets independentes. Para arte e áudio, use o primeiro minuto de referência como padrão. Reúna escolhas criativas em uma única demonstração nos marcos de aprovação. Continue trabalho independente enquanto aguarda uma decisão. Escale ao Thiago somente uma decisão de produto realmente ambígua que altere o jogo, aceite artístico previsto que dependa do gosto dele, gasto/credencial/permissão ainda indisponível, risco de perder trabalho preexistente ou bloqueio sem alternativa viável. Ao escalar, apresente decisão mínima, evidência, recomendação e impacto. Autonomia local não autoriza compras ou publicação.

7. Trate a originalidade dos modelos, UI/UX infantil e acabamento audiovisual como critérios de conclusão. Produza toda a geometria do zero. Entregue fontes Blender editáveis, procedência, inspeção de malha e captura em jogo. Produza som, voz e interface coerentes com a cena. Identifique provisórios. Nunca declare que ouviu, viu, mediu ou executou algo sem ter realizado a verificação. Quando o ambiente não permitir revisão perceptual, forneça build/captura e deixe o aceite correspondente pendente.

Comece pela inspeção do ambiente, pelo ticket RB-01 e pela primeira feature branch. A primeira entrega é uma build Windows que abre e fecha, aceita entrada e pode ser reproduzida, acompanhada do commit integrado e dos comandos reais utilizados. Depois avance para o episódio em blocos. Em cada marco, informe em poucas linhas o que já dá para jogar, como executar, o que foi verificado e qualquer decisão que realmente precise de mim.
```