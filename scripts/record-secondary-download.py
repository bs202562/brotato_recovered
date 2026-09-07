"""Inspect downloaded secondary model and update only its handoff."""
import json,struct,hashlib,io,sys
from pathlib import Path
from PIL import Image
key,note=sys.argv[1:3];suffix=sys.argv[3] if len(sys.argv)>3 else '';p=Path('gdproj/combat3d/models/utility_'+key+'_3000'+suffix+'.glb');raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:];sizes=[]
for im in doc.get('images',[]):
 v=doc['bufferViews'][im['bufferView']];sizes.append(list(Image.open(io.BytesIO(binary[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']])).size))
f=Path('docs/tripo-secondary-production-handoff.json');d=json.loads(f.read_text());matches=[e for e in d['assets'] if e['target_identity']=='prop:'+key];e=matches[-1] if suffix else matches[0];e.update(status='downloaded_pending_validation',file=str(p).replace('\\','/'),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),actual_triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives']),skins=len(doc.get('skins',[])),animations=[a.get('name') for a in doc.get('animations',[])],texture_sizes=sizes,visual_note=note);f.write_text(json.dumps(d,indent=2)+'\n');print(key,e['actual_triangles'],e['bytes'],sizes)
