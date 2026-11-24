# Temas de Rota Brava (RB-04, esboço original)

Gerados por `themes.py` (via `./tools/gen-audio.ps1`). 104 bpm, 4/4, estéreo 32 kHz 16 bits, pico -6 dBFS (`theme_explore_low` -9 dBFS). Renderização circular: caudas dobram no início e o passa-baixa é circular, então a última amostra continua a primeira (salto na emenda em `report.json`). **Nada disto foi ouvido.**

## theme_explore (Dó maior, 16 compassos = 36,9 s, forma A A' B A'')
| Comp. | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Acorde | C | G | Am | F | C | G | F | G | F | G | Em | Am | C | G | F | G |
| Seção | A | | | | A' | | | | B | | | | A'' | | | |

**Motivo** (para assobiar): `G4 C5 E5 - D5 C5 G4` (colcheia, colcheia, semínima, colcheia, colcheia, semínima): salto de quarta, subida à terça, volta por grau conjunto. Nos compassos 2, 3 e 6 é transposto sobre G, Am. Compasso 4 resolve em suspensão (D5 sobre F); A' termina em G5 longo (meia cadência); A'' termina com `B4 D5 F5 D5 B4 G4` e o G4 final puxa o G4 do início do loop. B (ponte): notas longas e agudas (C6 B5 E5...), baixo sincopado, acordes de pizzicato em contratempo, eco da marimba.

Instrumentos: marimba (fundamental + parciais 4x e 9,9x), pizzicato (4 harmônicos), baixo (raiz e quinta), sino suave (parciais 1, 2,76, 5,4), flauta (contramelodia: duas notas do acorde por compasso, vibrato leve), pad (par de senoides desafinadas, ataque lento), shaker (ruído passa-altas 5 kHz) desde o comp. 3 e claves (2,45/3,15 kHz) desde o comp. 7. Variação entre repetições: A só marimba+baixo+pad (+shaker), A' dobra a marimba uma oitava abaixo e acrescenta arpejo pizz e flauta, B muda a textura, A'' acrescenta sino; dinâmica por compasso (0,82 a 1,05); micro-timing e velocidade determinísticos (semente 2026).

## theme_explore_low (mesma harmonia, esparso, para durante a fala)
Só notas longas da melodia (marimba suave), pad mais presente, baixo na raiz, sino nos comp. 1 e 9, sem percussão nem contramelodia, passa-baixa ~3,5 kHz. Pico -9 dBFS.

## theme_discovery (sting de 5,4 s, sem loop)
`Am - F - G -> C`: pergunta `E5 F5 G5 B5` (uma por tempo) e resposta `C6` sustentado em C maior, com sino, flauta G4 e pad; queda suave nos últimos 1,5 s. A fala pode entrar a partir de ~2 s sem colidir com o ataque.

## Espaço para a voz (EQ do bus Musica; `default_bus_layout.tres`)
EQ6: -6 dB em 32 Hz, -2 dB em 320 Hz, -3 dB em 1 kHz, -3 dB em 3,2 kHz (presença da fala), -2 dB em 10 kHz, além do sidechain da Voz (-28 dB, 3:1, 40 ms/600 ms) e `duck_music()` (-6 dB). Melodia fica em ~400 Hz-1,1 kHz (G4-C6) e baixo/pad abaixo de ~330 Hz.