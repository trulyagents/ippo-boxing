"""Builds the Gassed and Hurt loops on top of the bought game's idle pose, legs kept planted.

  python tools/make_tells.py "path/to/sold to trulyagents (2).rbxlx" build/anims

then publish build/anims/Gassed.rbxmx and Hurt.rbxmx with tools/publish_anims.py."""
import sys,os,re,copy,math,xml.etree.ElementTree as ET
src,out=sys.argv[1],sys.argv[2]
os.makedirs(out,exist_ok=True)
# 3x4 cframes as (R 3x3 row-major, p)
def mul(a,b):
    Ra,pa=a; Rb,pb=b
    R=[[sum(Ra[i][k]*Rb[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    p=[sum(Ra[i][k]*pb[k] for k in range(3))+pa[i] for i in range(3)]
    return (R,p)
def inv(a):
    R,p=a; Rt=[[R[j][i] for j in range(3)] for i in range(3)]
    return (Rt,[-sum(Rt[i][k]*p[k] for k in range(3)) for i in range(3)])
def rot(v): return ([v[0:3],v[3:6],v[6:9]],[0,0,0])
def ang(x,y,z):  # roblox CFrame.Angles = Rx*Ry*Rz
    cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    Rx=([[1,0,0],[0,cx,-sx],[0,sx,cx]],[0,0,0]); Ry=([[cy,0,sy],[0,1,0],[-sy,0,cy]],[0,0,0]); Rz=([[cz,-sz,0],[sz,cz,0],[0,0,1]],[0,0,0])
    return mul(mul(Rx,Ry),Rz)
def tr(x,y,z): return ([[1,0,0],[0,1,0],[0,0,1]],[x,y,z])
C0={"Torso":rot([-1,0,0,0,0,1,0,1,0]),"Head":rot([-1,0,0,0,0,1,0,1,0]),"Left Arm":rot([0,0,-1,0,1,0,1,0,0]),"Right Arm":rot([0,0,1,0,1,0,-1,0,0])}
def prop(it,n):
    p=it.find('Properties')
    for c in (p if p is not None else []):
        if c.get('name')==n: return c
def nm(it):
    c=prop(it,'Name'); return (c.text or '') if c is not None else ''
idle=None
for it in ET.parse(src).getroot().iter('Item'):
    if it.get('class')=='KeyframeSequence' and nm(it)=='OrthodoxStanceIdle': idle=it; break
kfs=[k for k in idle.findall('Item') if k.get('class')=='Keyframe']
def t_of(k):
    c=prop(k,'Time'); return float(c.text) if c is not None else 0
k0=min(kfs,key=t_of)
TAGS=['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22']
def readcf(p):
    c=prop(p,'CFrame')
    if c is None: return ([[1,0,0],[0,1,0],[0,0,1]],[0,0,0])
    v={x.tag:float(x.text) for x in c}
    return ([[v['R00'],v['R01'],v['R02']],[v['R10'],v['R11'],v['R12']],[v['R20'],v['R21'],v['R22']]],[v['X'],v['Y'],v['Z']])
def writecf(p,cf):
    c=prop(p,'CFrame')
    if c is None:
        c=ET.SubElement(p.find('Properties'),'CoordinateFrame',{'name':'CFrame'})
        for tg in TAGS: ET.SubElement(c,tg)
    R,pos=cf
    vals=dict(zip(TAGS,pos+[R[0][0],R[0][1],R[0][2],R[1][0],R[1][1],R[1][2],R[2][0],R[2][1],R[2][2]]))
    for x in c: x.text=repr(vals[x.tag])
RC1=rot([-1,0,0,0,0,1,0,1,0])
HC0={"Left Leg":([[0,0,-1],[0,1,0],[1,0,0]],[-1,-1,0]),"Right Leg":([[0,0,1],[0,1,0],[-1,0,0]],[1,-1,0])}
# keep the feet where the stance had them when the torso leans or drops
def planted(leg,tleg,t_old,t_new):
    return mul(mul(mul(mul(mul(mul(inv(HC0[leg]),RC1),inv(t_new)),t_old),inv(RC1)),HC0[leg]),tleg)
def inparent(name,base,cf): return mul(mul(mul(inv(C0[name]),cf),C0[name]),base)
r=math.radians
def apply(kf,spec):
    torso_old=torso_new=None
    for p in kf.iter('Item'):
        if p.get('class')!='Pose': continue
        n=nm(p)
        if n in ('MouthPart','PupilsPart','EyesPart','NosePart','EyebrowPart'): continue
        b=readcf(p)
        if n=='Torso':
            torso_old=b
            torso_new=inparent(n,b,mul(tr(0,-spec.get('drop',0),0),ang(r(-spec.get('lean',0)),0,r(spec.get('roll',0)))))
            writecf(p,torso_new)
        elif n in ('Left Leg','Right Leg') and torso_new is not None: writecf(p,planted(n,b,torso_old,torso_new))
        elif n=='Head': writecf(p,inparent(n,b,ang(r(-spec.get('nod',0)),0,r(spec.get('tilt',0)))))
        elif n in ('Left Arm','Right Arm'): writecf(p,inparent(n,b,ang(r(-spec.get('sag',0)),0,0)))
        es=prop(p,'EasingStyle')
        if es is None: es=ET.SubElement(p.find('Properties'),'token',{'name':'EasingStyle'})
        es.text='4'  # cubic
        ed=prop(p,'EasingDirection')
        if ed is None: ed=ET.SubElement(p.find('Properties'),'token',{'name':'EasingDirection'})
        ed.text='2'  # inout
def build(name,frames,prio):
    ks=copy.deepcopy(idle)
    for k in [k for k in ks.findall('Item') if k.get('class')=='Keyframe']: ks.remove(k)
    prop(ks,'Name').text=name
    for n,tag,val in (('Loop','bool','true'),('Priority','token',str(prio))):
        c=prop(ks,n)
        if c is None: c=ET.SubElement(ks.find('Properties'),tag,{'name':n})
        c.text=val
    for t,spec in frames:
        k=copy.deepcopy(k0); tc=prop(k,'Time')
        if tc is None: tc=ET.SubElement(k.find('Properties'),'float',{'name':'Time'})
        tc.text=repr(t); apply(k,spec); ks.append(k)
    root=ET.Element('roblox',{'version':'4'}); root.append(ks)
    s=ET.tostring(root,encoding='unicode'); i=[0]
    s=re.sub(r'referent="[^"]+"',lambda m:(i.__setitem__(0,i[0]+1) or f'referent="R{i[0]}"'),s)
    open(os.path.join(out,name+'.rbxmx'),'w',encoding='utf-8').write(s); print(name,len(s))
build('Gassed',[(0,dict(lean=14,sag=18,nod=8)),(0.55,dict(lean=19,drop=0.1,sag=24,nod=13)),(1.1,dict(lean=14,sag=18,nod=8))],0)
build('Hurt',[(0,dict(lean=-4,roll=6,tilt=-8,sag=30,nod=10,drop=0.1)),(0.4,dict(lean=-2,sag=34,nod=14,drop=0.12)),(0.8,dict(lean=-4,roll=-6,tilt=8,sag=30,nod=10,drop=0.1)),(1.2,dict(lean=-2,sag=34,nod=14,drop=0.12)),(1.6,dict(lean=-4,roll=6,tilt=-8,sag=30,nod=10,drop=0.1))],0)
# print one check value to compare with studio: Gassed kf0 Torso
