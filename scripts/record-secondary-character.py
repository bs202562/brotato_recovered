"""Record only observed secondary UI transactions; no authoritative ledger writes."""
import json, sys
from pathlib import Path
p=Path('docs/tripo-secondary-production-handoff.json')
d=json.loads(p.read_text(encoding='utf-8-sig'))
key,uuid,balance,tab=sys.argv[1:]
identity='character_'+key
assert not any(e.get('target_identity')==identity for e in d['assets'])
brief=next(e for e in json.loads(Path('docs/tripo-remaining-briefs.json').read_text(encoding='utf-8-sig'))['briefs'] if e['id']==identity)
batch=next(e['batch'] for e in json.loads(Path('docs/next-model-batches.json').read_text(encoding='utf-8-sig')) if e['id']==identity)
d['assets'].append(dict(target_identity=identity,prompt=brief['brief'].replace('  Full',' Full'),target_triangles=6000,texture_size=1024,rigging_credits=0,status='generating',studio_id=uuid,url='https://studio.tripo3d.ai/zh/workspace/generate/'+uuid,generation_credits=55,observed_balance=int(balance),tab_id=tab,batch='batch'+str(batch)))
d['all_submitted_downloaded']=False
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
print(identity,uuid,'recorded')
