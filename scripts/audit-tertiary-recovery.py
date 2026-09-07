"""Read-only GLB audit, updating only tertiary handoff recovery evidence."""
import io,json,struct,hashlib,datetime,collections
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];hp=root/'docs/tripo-tertiary-production-handoff.json';h=json.loads(hp.read_text(encoding='utf-8-sig'));q=json.loads((root/'docs/model-production-queue.json').read_text(encoding='utf-8-sig'));queue={x['id']:x for x in q['models'] if x['category']=='weapon'}
rows=[]
for a in h['assets']:
 if not a.get('file'):continue
 p=root/a['file'];raw=p.read_bytes();magic,ver,total=struct.unpack_from('<4sII',raw);assert magic==b'glTF' and ver==2 and total==len(raw)
 n,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a;d=json.loads(raw[20:20+n]);bn,bk=struct.unpack_from('<II',raw,20+n);assert bk==0x004e4942 and 28+n+bn==len(raw);b=raw[28+n:]
 tri=sum(d['accessors'][p['indices']]['count']//3 if 'indices'in p else d['accessors'][p['attributes']['POSITION']]['count']//3 for m in d['meshes'] for p in m['primitives']);assert all(p.get('mode',4)==4 for m in d['meshes'] for p in m['primitives'])
 dims=[]
 for im in d.get('images',[]):
  v=d['bufferViews'][im['bufferView']];pic=Image.open(io.BytesIO(b[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]));dims.append(list(pic.size))
 sha=hashlib.sha256(raw).hexdigest();assert sha==a['sha256'].lower();assert tri==a['actual_ui_triangles'];assert not d.get('skins') and not d.get('animations');assert dims==[[1024,1024]]*3
 rows.append(dict(id=a['id'],target_identity=a['target_identity'],studio_id=a['studio_id'],file=a['file'],bytes=len(raw),sha256=sha,header_valid=True,triangles=tri,texture_dimensions=dims,over_1545=tri>1545,rejected=a['status'].startswith('rejected')))
uuids=[a['studio_id'] for a in h['assets']];active=[a for a in h['assets'] if not a['status'].startswith('rejected')];identities=[a['target_identity'] for a in active];assert len(set(uuids))==len(uuids)==45;assert len(set(identities))==len(identities)==42;assert not(set(identities)-set(queue))
assigned={x['id'] for x in json.loads((root/'docs/next-model-batches.json').read_text(encoding='utf-8-sig')) if x['category']=='weapon' and x['batch'] in (6,11,15,18,21,24,27)};assert set(identities)==assigned
pending=[dict(id=a['target_identity'],studio_id=a['studio_id'],url=a['url'],queue_status=queue[a['target_identity']]['status'],action='Open existing paid UUID; preview, GLB export at 1K and immediate download. Never regenerate.') for a in active if not a.get('file')]
retopo=[dict(id=x['target_identity'],studio_id=x['studio_id'],original_file=x['file'],actual_triangles=x['triangles'],action='Once per existing UUID, official retopology target1500 only if price5; export separate 1K static reduced GLB; preserve raw.',max_credits=5) for x in rows if x['over_1545'] and not x['rejected']]
h['recovery_audit']=dict(checked_at=datetime.datetime.now().astimezone().isoformat(),unique_studio_uuids=len(set(uuids)),paid_attempts=len(uuids),active_unique_identities=len(identities),rejected_attempts=3,assigned_batches=[6,11,15,18,21,24,27],assigned_identity_set_equals_queue_subset=True,queue_weapon_total=len(queue),downloaded_raw_count=len(rows),downloaded_raw_bytes=sum(x['bytes'] for x in rows),all_headers_triangles_hashes_3x1k_valid=True,downloaded=rows,pending_exports=pending,retopology_required=retopo,retopology_spent=0,retopology_authorized_cap=100,note='45 attempts are 42 assigned queue identities plus 3 rejected first attempts. Not equal to all 78 weapon identities. Queue statuses are snapshot, never overwritten.')
hp.write_text(json.dumps(h,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in h['recovery_audit'].items() if k not in ('downloaded','pending_exports')},ensure_ascii=False))
