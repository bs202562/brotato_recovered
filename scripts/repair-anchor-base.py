"""Audited anchor-only base removal: clip below the crown, seal cut, orient grip left."""
import hashlib, json, math, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'gdproj/combat3d/models/weapon_anchor_tertiary_1500_raw.glb'
target=source.with_name('weapon_anchor_1500_nobase.glb')
assert not target.exists()
raw=source.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=bytearray(raw[28+n:])
assert len(doc['meshes'])==len(doc['nodes'])==1 and not doc.get('skins') and not doc.get('animations')
assert len(doc['meshes'][0]['primitives'])==1
part=doc['meshes'][0]['primitives'][0]
assert set(part['attributes'])=={'POSITION','NORMAL','TEXCOORD_0'} and part.get('mode',4)==4
node=doc['nodes'][0];assert not any(k in node for k in ('matrix','scale','rotation','children'))
translation=node.get('translation',[0,0,0]);plane=.15
def read(i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];w={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']];f={5126:'f',5123:'H',5125:'I'}[a['componentType']];o=v.get('byteOffset',0)+a.get('byteOffset',0)
 return [struct.unpack_from('<'+f*w,binary,o+k*v.get('byteStride',w*struct.calcsize(f))) for k in range(a['count'])]
attrs={k:read(i) for k,i in part['attributes'].items()};indices=[v[0] for v in read(part['indices'])]
body={k:[] for k in attrs};points={};edges=set()
def key(p):return tuple(round(c,6) for c in p)
for t in range(0,len(indices),3):
 poly=[{k:v[i] for k,v in attrs.items()} for i in indices[t:t+3]];clipped=[];cuts=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  ia,ib=a['POSITION'][1]>=plane,b['POSITION'][1]>=plane
  if ia:clipped.append(a)
  if ia!=ib:
   f=(plane-a['POSITION'][1])/(b['POSITION'][1]-a['POSITION'][1]);c={k:tuple(x+(y-x)*f for x,y in zip(a[k],b[k])) for k in a};clipped.append(c);cuts.append(c['POSITION'])
 if len(cuts)==2 and key(cuts[0])!=key(cuts[1]):
  for c in cuts:points[key(c)]=c
  edges.add(tuple(sorted(map(key,cuts))))
 for i in range(1,len(clipped)-1):
  for c in (clipped[0],clipped[i],clipped[i+1]):
   for k in body:body[k].append(c[k])
neighbors={k:set() for k in points}
for a,b in edges:neighbors[a].add(b);neighbors[b].add(a)
assert all(len(v)==2 for v in neighbors.values()), 'Ambiguous cut boundary; do not guess cap'
unvisited=set(points);loops=[]
while unvisited:
 start=next(iter(unvisited));loop=[];previous=None;current=start
 while current not in loop:
  loop.append(current);unvisited.discard(current);options=neighbors[current]-({previous} if previous else set());following=next(iter(options));previous,current=current,following
 assert current==start;loops.append([points[k] for k in loop])
assert len(loops)==1, 'This repair is limited to a single solid anchor-crown section'
cap={k:[] for k in body};polygon=loops[0]
def cross(a,b,c):return (b[0]-a[0])*(c[2]-a[2])-(b[2]-a[2])*(c[0]-a[0])
area=sum(a[0]*b[2]-b[0]*a[2] for a,b in zip(polygon,polygon[1:]+polygon[:1]))
if area<0:polygon.reverse()
remaining=list(range(len(polygon)));cap_triangles=[]
while len(remaining)>3:
 for at in range(len(remaining)):
  ai,bi,ci=remaining[at-1],remaining[at],remaining[(at+1)%len(remaining)];a,b,c=polygon[ai],polygon[bi],polygon[ci]
  if cross(a,b,c)<=1e-12:continue
  if any(cross(a,b,polygon[i])>=-1e-12 and cross(b,c,polygon[i])>=-1e-12 and cross(c,a,polygon[i])>=-1e-12 for i in remaining if i not in (ai,bi,ci)):continue
  cap_triangles.append((a,b,c));remaining.pop(at);break
 else:raise AssertionError('Cap triangulation could not prove an ear')
cap_triangles.append(tuple(polygon[i] for i in remaining))
for tri in cap_triangles:
 for vertex in tri:
  cap['POSITION'].append(vertex);cap['NORMAL'].append((0,-1,0));cap['TEXCOORD_0'].append((0,0))
# Rotate +90 degrees around Z so the upper ring is LEFT and striking crown RIGHT.
for values in (body,cap):
 values['POSITION']=[(-(p[1]+translation[1]),p[0]+translation[0],p[2]+translation[2]) for p in values['POSITION']]
 values['NORMAL']=[(-p[1],p[0],p[2]) for p in values['NORMAL']]
positions=body['POSITION'];center=[(min(p[i] for p in positions)+max(p[i] for p in positions))/2 for i in range(3)]
for values in (body,cap):values['POSITION']=[tuple(p[i]-center[i] for i in range(3)) for p in values['POSITION']]
node.pop('translation',None)
def append(vals,kind,component=5126):
 w={'SCALAR':1,'VEC2':2,'VEC3':3}[kind];f='I' if component==5125 else 'f';binary.extend(b'\0'*(-len(binary)%4));o=len(binary)
 for v in vals:binary.extend(struct.pack('<'+f*w,*v))
 vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':o,'byteLength':len(binary)-o});a={'bufferView':vi,'componentType':component,'count':len(vals),'type':kind}
 if kind=='VEC3':a.update(min=[min(v[i] for v in vals) for i in range(3)],max=[max(v[i] for v in vals) for i in range(3)])
 idx=len(doc['accessors']);doc['accessors'].append(a);return idx
def primitive(values,material):return {'attributes':{k:append(v,'VEC2' if k=='TEXCOORD_0' else 'VEC3') for k,v in values.items()},'indices':append([(i,) for i in range(len(values['POSITION']))],'SCALAR',5125),'material':material,'mode':4}
material=len(doc['materials']);doc['materials'].append({'name':'Repaired anchor crown underside','pbrMetallicRoughness':{'baseColorFactor':[.15,.31,.29,1],'metallicFactor':.65,'roughnessFactor':.6}})
doc['meshes'][0]['primitives']=[primitive(body,part['material']),primitive(cap,material)]
doc['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*(-len(binary)%4));encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
target.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
evidence={'source':str(source.relative_to(ROOT)),'derived':str(target.relative_to(ROOT)),'source_sha256':hashlib.sha256(raw).hexdigest(),'derived_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'clip_local_y':plane,'boundary_loops':len(loops),'cap_triangles':len(cap_triangles),'body_triangles':len(body['POSITION'])//3,'triangles':(len(body['POSITION'])+len(cap['POSITION']))//3,'operation':'Audited anchor-only floor cut above display base; original anchor UVs interpolated at cut, closed crown underside, ring rotated left, recentered. Original source and embedded textures retained. Pending final Godot review.'}
target.with_suffix('.derivation.json').write_text(json.dumps(evidence,indent=2)+'\n');print(json.dumps(evidence))
