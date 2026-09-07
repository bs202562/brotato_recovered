"""Keep explicitly audited connected components; retain source and embedded textures."""
import argparse,json,struct,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('audit',type=Path);p.add_argument('output',type=Path);p.add_argument('--keep',required=True,type=int,nargs='+');p.add_argument('--preserve-existing-rig',action='store_true');a=p.parse_args()
audit=json.loads(a.audit.read_text());source=Path(audit['source']);raw=source.read_bytes();assert hashlib.sha256(raw).hexdigest()==audit['sha256'];assert source.resolve()!=a.output.resolve()
assert not a.output.exists(), 'Output already exists; choose a new derived path'
n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);original=json.loads(raw[20:20+n]);binary=bytearray(raw[28+n:]);original_binary=bytes(binary)
assert a.preserve_existing_rig or (not doc.get('skins') and not doc.get('animations'))
if a.preserve_existing_rig:
 assert audit.get('skinned_bind_pose'), 'Explicit bind-pose component audit required'
 assert all('JOINTS_0' in part['attributes'] and 'WEIGHTS_0' in part['attributes'] for part in doc['meshes'][0]['primitives']), 'Existing per-vertex skin influences required'
assert len(doc.get('meshes',[]))==1, 'Single mesh only'
assert len(doc.get('buffers',[]))==1 and 'uri' not in doc['buffers'][0], 'Single internal buffer only'
assert not doc.get('extensionsUsed') and not doc.get('extensionsRequired'), 'Extensions, including compression, are unsupported'
assert all('sparse' not in ac for ac in doc['accessors']), 'Sparse accessors unsupported'
assert all(v.get('buffer',0)==0 for v in doc['bufferViews']), 'External buffer references unsupported'
assert all(part.get('mode',4)==4 and not part.get('targets') and not part.get('extensions') for part in doc['meshes'][0]['primitives']), 'TRIANGLES only; no morphs or compressed primitives'
assert not doc['meshes'][0].get('weights'), 'Morph weights unsupported'
assert set(a.keep).issubset({c['component'] for c in audit['components']}), 'Unknown requested component'
keep={tuple(ref) for c in audit['components'] if c['component'] in a.keep for ref in c['primitive_triangle_refs']};assert keep
def read(i):
 ac=doc['accessors'][i];v=doc['bufferViews'][ac['bufferView']];fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[ac['componentType']];w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[ac['type']];size=struct.calcsize(fmt)*w;offset=v.get('byteOffset',0)+ac.get('byteOffset',0)
 return ac,fmt,w,[struct.unpack_from('<'+fmt*w,binary,offset+j*v.get('byteStride',size)) for j in range(ac['count'])]
def append(ac,fmt,w,vals):
 binary.extend(b'\0'*(-len(binary)%4));offset=len(binary)
 for v in vals:binary.extend(struct.pack('<'+fmt*w,*v))
 vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(binary)-offset})
 new={k:v for k,v in ac.items() if k not in ['bufferView','byteOffset','count','min','max']};new.update(bufferView=vi,count=len(vals))
 if ac['type']!='SCALAR':new['min']=[min(v[j] for v in vals) for j in range(w)];new['max']=[max(v[j] for v in vals) for j in range(w)]
 idx=len(doc['accessors']);doc['accessors'].append(new);return idx
parts=[]
for pi,part in enumerate(doc['meshes'][0]['primitives']):
 ac,fmt,w,iv=read(part['indices']);indices=[v[0] for v in iv];selected=[v for ti in range(len(indices)//3) if (pi,ti) in keep for v in indices[ti*3:ti*3+3]]
 if not selected:continue
 used=sorted(set(selected));remap={old:new for new,old in enumerate(used)};new=dict(part);new['attributes']={}
 for key,idx in part['attributes'].items():
  attr,afmt,aw,vals=read(idx);new['attributes'][key]=append(attr,afmt,aw,[vals[i] for i in used])
 new['indices']=append(ac,fmt,w,[(remap[i],) for i in selected]);parts.append(new)
doc['meshes'][0]['primitives']=parts;doc['buffers'][0]['byteLength']=len(binary);binary.extend(b'\0'*(-len(binary)%4));encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
a.output.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
evidence={'source':str(source),'derived':str(a.output),'source_sha256':hashlib.sha256(raw).hexdigest(),'derived_sha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'kept_components':a.keep,'kept_triangles':len(keep),'removed_triangles':audit['triangles']-len(keep),'original_binary_prefix_unchanged':bytes(binary[:len(original_binary)])==original_binary,'materials_images_textures_unchanged':all(doc.get(k)==original.get(k) for k in ['materials','images','textures','samplers']),'operation':'Explicit component selection; compacted only referenced vertex attributes and triangle indices without modifying their values. Original binary retained; no height cutoff.'}
evidence['rig_and_animation_definitions_unchanged']=all(doc.get(k)==original.get(k) for k in ['skins','animations','nodes','scenes'])
a.output.with_suffix('.derivation.json').write_text(json.dumps(evidence,indent=2)+'\n');print(json.dumps(evidence))
