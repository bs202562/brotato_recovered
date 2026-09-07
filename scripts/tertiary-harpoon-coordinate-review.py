import json,struct
from pathlib import Path
from PIL import Image,ImageDraw
p=Path('gdproj/combat3d/models/weapon_harpoon_gun_tertiary_1500_raw.glb');r=p.read_bytes();n=struct.unpack_from('<I',r,12)[0];d=json.loads(r[20:20+n]);b=r[28+n:]
def read(i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];w={'SCALAR':1,'VEC3':3}[a['type']];f={5126:'f',5123:'H',5125:'I'}[a['componentType']];return [struct.unpack_from('<'+f*w,b,v.get('byteOffset',0)+a.get('byteOffset',0)+j*v.get('byteStride',w*struct.calcsize(f))) for j in range(a['count'])]
p=d['meshes'][0]['primitives'][0];t=d['nodes'][0].get('translation',[0,0,0]);ps=[tuple(v[k]+t[k] for k in range(3)) for v in read(p['attributes']['POSITION'])];ix=[x[0] for x in read(p['indices'])];im=Image.new('RGB',(1100,850),'#14252b');dr=ImageDraw.Draw(im)
def xy(v):return (int(550+v[0]*1000),int(780-v[1]*1000))
for i in range(0,len(ix),3):dr.polygon([xy(ps[j]) for j in ix[i:i+3]],outline='#68aaa8')
for k in range(-5,6):
 x=k/10;dr.line([xy((x,0)),xy((x,.72))],fill='#44525c');dr.text(xy((x,-.02)),str(x),fill='white')
for k in range(8):
 y=k/10;dr.line([xy((-.5,y)),xy((.5,y))],fill='#44525c');dr.text(xy((-.54,y)),str(y),fill='white')
im.save('docs/tertiary-harpoon-coordinate-review.png')
