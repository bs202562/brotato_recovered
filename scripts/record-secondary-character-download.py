"""Validate downloaded character and record secondary handoff, no acceptance writes."""
import json,struct,hashlib,io,sys
from pathlib import Path
from PIL import Image
key=sys.argv[1];p=Path('gdproj/combat3d/models/survivor_'+key+'_secondary_6000_idle.glb')
raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:];sizes=[]
for im in doc.get('images',[]):
 v=doc['bufferViews'][im['bufferView']];sizes.append(list(Image.open(io.BytesIO(binary[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])).size))
tri=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
animations=[a.get('name') for a in doc.get('animations',[])]
assert 0<tri<=6000 and len(doc.get('skins',[]))==1 and 'preset:biped:idle' in animations
assert sizes and all(x==[1024,1024] for x in sizes)
f=Path('docs/tripo-secondary-production-handoff.json');d=json.loads(f.read_text(encoding='utf-8-sig'))
e=next(x for x in d['assets'] if x['target_identity']=='character_'+key)
e.update(status='downloaded_pending_validation',file=str(p).replace('\\','/'),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),actual_triangles=tri,skins=1,animations=animations,texture_sizes=sizes)
f.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8');print(key,tri,len(raw),animations,sizes)
