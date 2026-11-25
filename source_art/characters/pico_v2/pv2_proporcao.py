"""Medida de proporcao dos bracos (v2.3) em GLBs do trio: pulso, ponta dos dedos, quadril (cabeca do osso thigh), mao e
braco em relacao a altura total, em REPOUSO (rest pose do rig) e no quadro 0 do idle. Malha avaliada (armature).

Uso: bash tools/blender.sh --background --factory-startup --python source_art/characters/pico_v2/pv2_proporcao.py -- \
        saida.json a.glb [b.glb ...]
"""
import bpy,sys,json
import numpy as np
from mathutils import Vector
args=sys.argv[sys.argv.index("--")+1:]
out={}
for p in args[1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    arm=[o for o in bpy.data.objects if o.type=="ARMATURE"][0]
    res={}
    for mode in ("REST","IDLE0"):
        arm.data.pose_position="REST" if mode=="REST" else "POSE"
        if mode=="IDLE0":
            act=[a for a in bpy.data.actions if a.name.split("_")[0]=="idle" or a.name.startswith("idle")]
            if not arm.animation_data: arm.animation_data_create()
            for t in arm.animation_data.nla_tracks: t.mute=True
            arm.animation_data.action=act[0] if act else None
            bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get()
        allz=[];hand={"R":[],"L":[]};ua={"R":[],"L":[]};fa={"R":[],"L":[]}
        for o in bpy.data.objects:
            if o.type!="MESH" or o.parent!=arm: continue
            if o.hide_render or o.hide_get(): continue
            gi={g.index:g.name for g in o.vertex_groups}
            ev=o.evaluated_get(dg); me=ev.to_mesh()
            M=ev.matrix_world
            for v,vo in zip(me.vertices,o.data.vertices):
                co=M@v.co
                allz.append(co.z)
                if not vo.groups: continue
                g=max(vo.groups,key=lambda g:g.weight)
                n=gi.get(g.group,"")
                if g.weight<0.6: continue
                for s in "RL":
                    if n in ("hand."+s,"hand_tip."+s): hand[s].append(co[:])
                    if n=="upper_arm."+s: ua[s].append(co[:])
                    if n=="forearm."+s: fa[s].append(co[:])
            ev.to_mesh_clear()
        pb=arm.pose.bones
        W=arm.matrix_world
        H=max(allz)-min(allz); z0=min(allz)
        def bz(n,tail=False): b=pb[n]; return (W@(b.tail if tail else b.head)).z-z0
        def width(pts,a,b,t):
            P=np.array(pts); A=np.array(a);B=np.array(b);d=B-A;L=np.linalg.norm(d);d/=L
            u=(P-A)@d/L; sel=np.abs(u-t)<0.06
            Q=P[sel]-A; Q=Q-np.outer(Q@d,d)
            if len(Q)<4: return None
            # diametro: largura maxima em 36 direcoes perpendiculares -> media de min e max
            e1=np.cross(d,[0,1,0]); e1/=np.linalg.norm(e1); e2=np.cross(d,e1)
            ws=[ (Q@(np.cos(a)*e1+np.sin(a)*e2)).ptp() for a in np.linspace(0,np.pi,18,endpoint=False)]
            return dict(frontal=round(float((Q@e1).ptp()),4),max=round(float(max(ws)),4),min=round(float(min(ws)),4))
        r=dict(altura=round(H,4))
        for s in "R":
            hd=lambda n:(W@pb[n].head)
            r["ombro_z"]=round(bz("upper_arm."+s),4)
            r["quadril_thigh_z"]=round(bz("thigh."+s),4)
            r["hips_z"]=round(bz("hips"),4)
            r["pulso_z"]=round(bz("hand."+s),4)
            hp=np.array(hand[s]); r["dedos_z"]=round(float(hp[:,2].min()-z0),4)
            r["mao_comp"]=round(float(np.linalg.norm(np.array(W@pb["hand."+s].head)-hp,axis=1).max()),4)
            ext=hp.ptp(axis=0); r["mao_bbox"]=[round(float(x),4) for x in ext]
            r["braco_comp"]=round((hd("upper_arm."+s)-hd("hand."+s)).length,4)
            r["biceps"]=width(ua[s],hd("upper_arm."+s),hd("forearm."+s),0.5)
            r["antebraco"]=width(fa[s],hd("forearm."+s),hd("hand."+s),0.4)
            r["punho"]=width(fa[s],hd("forearm."+s),hd("hand."+s),0.85)
        r["pulso/H"]=round(r["pulso_z"]/H,4); r["dedos/H"]=round(r["dedos_z"]/H,4)
        r["dedos-quadril/H"]=round((r["dedos_z"]-r["quadril_thigh_z"])/H,4)
        r["pulso-quadril/H"]=round((r["pulso_z"]-r["quadril_thigh_z"])/H,4)
        r["braco/H"]=round(r["braco_comp"]/H,4)
        res[mode]=r
    out[p.split("/")[-1]]=res
json.dump(out,open(args[0],"w"),indent=1)
print(json.dumps(out,indent=1))
