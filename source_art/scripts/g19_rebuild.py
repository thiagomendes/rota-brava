"""RB-R1 G19: regravar SO os clipes de um heroi v2 sobre o .blend versionado, sem refazer malha, UV nem texturas.

Usado pelos build_*_v2.py com `--anim-only`. A malha, os materiais e as texturas empacotadas do .blend ficam como estao
(o build completo reassa as texturas e ja reempacotou UVs numa reexportacao, ver PROVENANCE do Pico). O corpo e montado
numa cena vazia so para ler as medidas (Frame `F`, olhos), que sao Python puro; depois o .blend e aberto, os clipes
antigos (Actions e faixas NLA) sao apagados e o author() do heroi grava tudo de novo, com os ossos HoldPoint.
"""
import bpy

from rbart import reset_scene


def reopen(blend_path, body_build):
    reset_scene()
    b = body_build()
    rig_name = b.rig.name
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    rig = bpy.data.objects[rig_name]
    groups = {o["rbgroup"]: o for o in bpy.data.objects if o.type == "MESH" and "rbgroup" in o}
    owners = [rig] + [o.data.shape_keys for o in groups.values() if o.data.shape_keys is not None]
    for ow in owners:
        ad = ow.animation_data
        if ad is None:
            continue
        ad.action = None
        for tr in list(ad.nla_tracks):
            ad.nla_tracks.remove(tr)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    pb = rig.pose.bones
    for p in pb:
        p.rotation_mode = "QUATERNION"
        p.rotation_quaternion = (1, 0, 0, 0)
        p.location = (0, 0, 0)
    for o in groups.values():
        if o.data.shape_keys is not None:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = 0.0
    return b, rig, groups
