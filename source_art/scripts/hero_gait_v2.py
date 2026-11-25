"""Ciclos de andar e correr dos herois v2 (RB-R1, ciclos v2). FK + IK de 2 ossos, 30 fps, sem root motion. PROVISORIO.

Pedido de Thiago (2026-11-25): "os pes estao muito acelerados". O jogo escala o clipe por velocidade_real / velocidade_nominal
(walk_speed_mps / run_speed_mps nas cenas *_model.tscn); com o passo curto do hero_anim (0,26 m de apoio) a escala ia a x2,5.
Aqui a passada e longa para a escala ficar perto de 1 a 1,4 m/s (andar) e 3,2 m/s (correr):

- apoio: o pe plantado recua `s` metros (calcanhar -> chapado -> bola) em `sf` do ciclo; velocidade nominal = s / (sf * T);
  avanco do corpo por ciclo = s / sf (dois passos).
- pernas chibi curtas (~0,27 m do quadril ao tornozelo): a altura do quadril sai, quadro a quadro, do alcance REAL das duas
  pernas (IK com folga `reach`), com o estilo de quique de cada heroi por cima (min suave). Assim o pe de apoio nunca e puxado
  do chao pela perna esticada e a passada longa nao patina.
- passada maior que a perna: o quadril gira (guinada) para frente com a perna que pisa e o pe rola do calcanhar a ponta.
- balanco: o pe sai rente ao chao, sobe com o joelho a frente (altura `lift`, pico em `lift_at`) e desce rente antes de pisar,
  o que no correr esconde a fase de voo baixa (os pes "raspam"); os pes nunca mudam de x (folga entre botas do rig mantida).

Os clipes do hero_anim (moradores, capitao, herois v1) nao mudam: este modulo so substitui `walk` e `run` dos herois v2.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mathutils import Vector

import char_anim as ca
from char_anim import blink_curve, foot_ankle, lerp, smooth, torso
from char_lib import eul

FPS = 30


def nominal_speed(g):
    """Velocidade do pe de apoio (m/s) no tempo do clipe: o que vai em walk_speed_mps / run_speed_mps."""
    return g["s"] / (g["sf"] * g["T"])


def advance(g):
    """Avanco do corpo por ciclo (dois passos), em metros."""
    return g["s"] / g["sf"]


def summary(g, game_mps):
    v = nominal_speed(g)
    k = game_mps / v
    return {"ciclo_s": round(g["T"], 4), "apoio_frac": round(g["sf"], 4), "curso_apoio_m": round(g["s"], 4),
            "avanco_ciclo_m": round(advance(g), 4), "velocidade_nominal_mps": round(v, 4),
            "escala_no_jogo": round(k, 3), "passos_por_s_no_jogo": round(2.0 * k / g["T"], 3), "mps_jogo": game_mps}


def _bump(w, p, at, low):
    """Altura do balanco (0..1): zero nas janelas rentes ao chao (w < low e w > 1 - low), 1 em w = at; o expoente p
    achata a subida e a descida."""
    if w <= low or w >= 1.0 - low:
        return 0.0
    v = (w - low) / (1.0 - 2.0 * low)
    a = (at - low) / (1.0 - 2.0 * low)
    q = math.log(0.5) / math.log(a)             # v**q = 0.5 em v = a
    return math.sin(math.pi * (v ** q)) ** p


def _slack(w, low):
    """Folga de alcance do pe no ar: 0 nas janelas rentes ao chao (ele limita o quadril como um pe plantado), grande no
    meio do balanco (o IK so aproxima o pe do corpo). Continua, para a curva do quadril nao saltar."""
    return 0.5 * smooth(w, low, low + 0.12) * (1.0 - smooth(w, 1.0 - low - 0.12, 1.0 - low))


def _feet(R, g, p0):
    """Alvos dos dois pes: lista de (lado, tornozelo, phi, pivo, em_apoio, folga_de_alcance)."""
    out = []
    s, sf = g["s"], g["sf"]
    for side, off in (("R", 0.0), ("L", 0.5)):
        p = (p0 + off) % 1.0
        h0 = R.rest_head["heel." + side].y + g["center"]
        front, back = h0 + s / 2, h0 - s / 2
        if p < sf:
            u = p / sf
            hy = front - s * u
            if u < g["land_u"]:
                phi, piv = g["phi_land"] * (1 - smooth(u, 0, g["land_u"])), "heel"
            elif u < g["push_u"]:
                phi, piv = 0.0, "heel"
            else:
                phi, piv = g["phi_push"] * smooth(u, g["push_u"], 1.0), "ball"
            out.append((side, foot_ankle(R, side, hy, phi, piv), phi, piv, True, 0.0))   # (lado, tornozelo, phi, pivo, apoio, folga)
        else:
            w = (p - sf) / (1 - sf)
            a_end = foot_ankle(R, side, back, g["phi_push"], "ball")
            a_beg = foot_ankle(R, side, front, g["phi_land"], "heel")
            # Hermite em y: sai e chega com a velocidade do chao (o pe que deixa o chao continua recuando um pouco enquanto
            # sobe; o que vai pisar ja recua quando encosta), entao nao ha patinada na saida nem na chegada
            m = -g["match"] * advance(g) * (1 - sf)
            w2, w3 = w * w, w * w * w
            a = Vector((lerp(a_end.x, a_beg.x, smooth(w)),
                        a_end.y * (2 * w3 - 3 * w2 + 1) + a_beg.y * (3 * w2 - 2 * w3) + m * (w3 - 2 * w2 + w) + m * (w3 - w2),
                        lerp(a_end.z, a_beg.z, smooth(w)) + g["lift"] * _bump(w, g["lift_p"], g["lift_at"], g["low_w"])
                        + g["skim"] * smooth(w, 0.0, 0.25 * g["low_w"]) * (1.0 - smooth(w, 1.0 - 0.25 * g["low_w"], 1.0))))
            # dedo para baixo no meio do balanco e para cima antes de pisar
            phi = lerp(g["phi_push"], g["phi_land"], smooth(w, 0.15, 0.92)) + g["phi_mid"] * math.sin(math.pi * w) ** 2
            out.append((side, a, phi, "heel", False, _slack(w, g["low_w"]) + g["low_slack"]))
    return out


def _hip_ceiling(R, feet, reach):
    """Maior deslocamento vertical do quadril em que as pernas ainda alcancam os pes plantados e os que acabam de sair ou
    estao para pisar (rentes ao chao, `low_w` do balanco), com folga. No meio do balanco o pe nao limita o quadril: se
    passar do alcance, o IK so o aproxima do corpo."""
    R.evaluate()
    best = 9.0
    for side, a, _phi, _piv, _planted, slack in feet:
        hj = R.pos["thigh." + side]
        L = (R.length("thigh." + side) + R.length("shin." + side)) * reach
        dxy = math.hypot(a.x - hj.x, a.y - hj.y)
        if dxy >= L:
            if slack > 0.0:
                continue
            return -1.0                          # pe no chao inalcancavel: o probe reporta
        best = min(best, a.z + math.sqrt(L * L - dxy * dxy) - hj.z + slack)
    return best


def _hips_rot(R, g, p0):
    ph = 2 * math.pi * p0
    R.rel("hips", eul(z=g["hip_yaw"] * math.cos(ph), y=g["hip_roll"] * math.cos(ph + math.pi / 2)))


def _style(g, p0):
    sfh = g["sf"] / 2                           # meio do apoio do pe direito
    c = math.cos(4 * math.pi * (p0 - sfh))
    if g["bob_mode"] == "vault":                # andar: quadril mais alto no meio do apoio
        return g["base"] + g["bob"] * c
    return g["base"] - g["bob"] * c             # correr: comprime no apoio, sobe no voo


HIP_N = 120
_CURVES = {}


def hip_curve(R, g):
    """Altura do quadril no ciclo (HIP_N amostras): min(estilo, teto de alcance), erodida e suavizada. Erosao de raio 2r
    seguida de duas medias de raio r fica sempre abaixo do min original: o pe plantado nunca e puxado do chao."""
    key = tuple(sorted((k, v) for k, v in g.items() if not isinstance(v, dict)))
    if key in _CURVES:
        return _CURVES[key]
    N = HIP_N
    h, c = [], []
    for i in range(N):
        p0 = i / N
        R.reset()
        _hips_rot(R, g, p0)
        feet = _feet(R, g, p0)
        R.hips_off = Vector((0.0, g.get("hips_y", 0.0), 0.0))
        ce = _hip_ceiling(R, feet, g["reach"])
        c.append(ce)
        h.append(min(_style(g, p0), ce))
    r = max(1, int(round(g["hip_smooth"] * N)))
    e = [min(h[(i + k) % N] for k in range(-2 * r, 2 * r + 1)) for i in range(N)]
    for _ in range(2):
        e = [sum(e[(i + k) % N] for k in range(-r, r + 1)) / (2 * r + 1) for i in range(N)]
    R.reset()
    _CURVES[key] = (e, c)
    return _CURVES[key]


def _sample(curve, p0):
    N = len(curve)
    x = (p0 % 1.0) * N
    i = int(math.floor(x))
    return lerp(curve[i % N], curve[(i + 1) % N], x - i)


def pose(R, F, t, g):
    p0 = (t / g["T"]) % 1.0
    ph = 2 * math.pi * p0                       # p0 = 0: calcanhar direito pisa na frente
    sfh = g["sf"] / 2
    curve, ceil_ = hip_curve(R, g)
    _hips_rot(R, g, p0)
    feet = _feet(R, g, p0)
    R.hips_off = Vector((0.0, g.get("hips_y", 0.0), _sample(curve, p0)))
    R.last_ceiling = _sample(ceil_, p0)
    torso(R, lean=g["lean"] + g.get("lean_bob", 0.0) * math.cos(4 * math.pi * (p0 - sfh)),
          yaw=-g["torso_yaw"] * math.cos(ph), roll=g.get("torso_roll", 0.0) * math.sin(ph),
          head_pitch=g["head_pitch"] + g.get("head_bob", 0.0) * math.cos(4 * math.pi * (p0 - sfh)),
          head_yaw=g["head_yaw"] * math.cos(ph) + g.get("head_look", 0.0) * math.sin(ph * 0.5) ** 2,
          head_roll=g["head_roll"] * math.sin(ph))
    sw = g["arm_swing"] * math.cos(ph - g.get("arm_lag", 0.0))
    for s, sx, a in (("R", 1, -sw), ("L", -1, sw)):
        R.rel("upper_arm." + s, eul(x=a + g.get("arm_fwd", 0.0), y=-g["arm_out"] * sx))
        R.rel("forearm." + s, eul(x=g["arm_bend"] + max(a, 0.0) * g.get("arm_pump", 0.6)))
    for side, a, phi, piv, _planted, _slack_ in feet:
        sx = 1 if side == "R" else -1
        ca.put_foot(R, side, 0.0, phi, piv, ankle=a, pole=(sx * g.get("knee_out", 0.05), 1.0, 0.0))
    f = {k: v for k, v in g.get("face", {}).items()}
    f["blink"] = blink_curve(t, g["blink_at"]) if g.get("blink_at") is not None else 0.0
    return f


def clip(g):
    """(duracao, loop, funcao) no formato dos CLIPS do hero_anim."""
    return (g["T"], True, lambda R, F, t, T: pose(R, F, t, g))


def gait_cfg(T, s, adv, **kw):
    """Monta a configuracao a partir do curso de apoio `s` (m) e do avanco por ciclo desejado `adv` (m): sf = s / adv."""
    g = dict(T=T, s=s, sf=s / adv, center=0.0, land_u=0.14, push_u=0.6, phi_land=10.0, phi_push=-30.0, phi_mid=-10.0,
             match=0.3, skim=0.010, low_w=0.10, low_slack=0.0, hip_smooth=0.03, lift=0.06, lift_p=1.8, lift_at=0.45, reach=0.975, hip_yaw=10.0, hip_roll=3.0,
             bob_mode="vault", base=-0.010, bob=0.008, lean=4.0, torso_yaw=7.0, head_pitch=-1.0, head_yaw=4.0,
             head_roll=2.0, arm_swing=28.0, arm_bend=20.0, arm_out=6.0, blink_at=0.55, face={})
    g.update(kw)
    return g
