"""Read-only welded triangle connectivity and orthographic component diagnostic."""
import argparse,json,struct,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path);p.add_argument('--edge-connectivity',action='store_true');p.add_argument('--skinned-bind-pose',action='store_true');a=p.parse_args()
raw=a.source.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
assert a.skinned_bind_pose or (not doc.get('skins') and not doc.get('animations'))
assert len(doc['meshes'])==1
mesh_nodes=[node for node in doc['nodes'] if 'mesh' in node];assert len(mesh_nodes)==1
node=mesh_nodes[0];assert not any(k in node for k in ['matrix','rotation','children'])
def values(i):
 ac=doc['accessors'][i];v=doc['bufferViews'][ac['bufferView']];fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[ac['componentType']];w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[ac['type']];s=struct.calcsize(fmt)*w;o=v.get('byteOffset',0)+ac.get('byteOffset',0)
 return [struct.unpack_from('<'+fmt*w,binary,o+j*v.get('byteStride',s)) for j in range(ac['count'])]
faces=[];refs=[]
for pi,part in enumerate(doc['meshes'][0]['primitives']):
 assert part.get('mode',4)==4
 pos=values(part['attributes']['POSITION']);idx=[v[0] for v in values(part['indices'])]
 for ti in range(0,len(idx),3):
  faces.append([tuple(pos[k][j]*node.get('scale',[1,1,1])[j]+node.get('translation',[0,0,0])[j] for j in range(3)) for k in idx[ti:ti+3]]);refs.append([pi,ti//3])
parent=list(range(len(faces)))
def find(x):
 while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
 return x
seen={}
for fi,face in enumerate(faces):
 vertices=[tuple(round(c,6) for c in v) for v in face]
 keys=[tuple(sorted((vertices[i],vertices[(i+1)%3]))) for i in range(3)] if a.edge_connectivity else vertices
 for key in keys:
  if key in seen:parent[find(fi)]=find(seen[key])
  else:seen[key]=fi
groups={}
for i in range(len(faces)):groups.setdefault(find(i),[]).append(i)
groups=sorted(groups.values(),key=len,reverse=True);report=[]
for ci,group in enumerate(groups):
 pts=[v for i in group for v in faces[i]];report.append({'component':ci,'triangles':len(group),'min':[min(v[j] for v in pts) for j in range(3)],'max':[max(v[j] for v in pts) for j in range(3)],'primitive_triangle_refs':[refs[i] for i in group]})
out={'source':str(a.source),'sha256':hashlib.sha256(raw).hexdigest(),'weld_decimal_places':6,'connectivity':'edge' if a.edge_connectivity else 'vertex','skinned_bind_pose':a.skinned_bind_pose,'coordinate_scope':'mesh bind pose; no animation deformation or ancestor transform evaluation','triangles':len(faces),'components':report}
a.output.with_suffix('.json').write_text(json.dumps(out,indent=2)+'\n')
im=Image.new('RGB',(1500,540),'#17252e');d=ImageDraw.Draw(im);colors=['#73c6b6','#ed9061','#c39bd3','#f4d03f','#5dade2','#f1948a']
pts=[v for f in faces for v in f];lo=[min(v[j] for v in pts) for j in range(3)];hi=[max(v[j] for v in pts) for j in range(3)]
for pane,(u,v,depth) in enumerate([(0,1,2),(2,1,0),(0,2,1)]):
 scale=430/max(hi[u]-lo[u],hi[v]-lo[v]);cx=(lo[u]+hi[u])/2;cy=(lo[v]+hi[v])/2
 visible=[(sum(x[depth] for x in faces[fi]),ci,fi) for ci,g in enumerate(groups) for fi in g]
 for _,ci,fi in sorted(visible):
  xy=[(pane*500+250+(x[u]-cx)*scale,270-(x[v]-cy)*scale) for x in faces[fi]];d.polygon(xy,fill=colors[ci%len(colors)],outline='#34434a')
 d.text((pane*500+15,15),['XY front','ZY side','XZ top'][pane],fill='white')
d.text((15,510),' | '.join(f'{c["component"]}: {c["triangles"]} tris' for c in report[:12]),fill='white');im.save(a.output.with_suffix('.png'))
print(json.dumps([{k:v for k,v in c.items() if k!='primitive_triangle_refs'} for c in report]))
