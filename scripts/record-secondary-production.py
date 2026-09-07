"""Append observed secondary UI submission; never edits authoritative ledgers."""
import json,sys
from pathlib import Path
p=Path('docs/tripo-secondary-production-handoff.json');d=json.loads(p.read_text());key,uuid,balance,next_key=sys.argv[1:]
e=next(e for e in d['assets'] if e['target_identity']=='prop:'+key);assert e['status']=='not_submitted'
e.update(status='generating',studio_id=uuid,url='https://studio.tripo3d.ai/zh/workspace/generate/'+uuid,generation_credits=55,observed_balance=int(balance),tab_id='1119470612');p.write_text(json.dumps(d,indent=2)+'\n')
if next_key!='none':
 for f in ['docs/tripo-production-2026-09-06.json','docs/combat3d-assets.json']:
  assert not [e for e in json.load(open(f,encoding='utf8'))['assets'] if e.get('target_identity')=='prop:'+next_key or e.get('id')=='prop:'+next_key]
 assert next(e for e in d['assets'] if e['target_identity']=='prop:'+next_key)['status']=='not_submitted'
print('Recorded',key,'next identity duplicate check passed:',next_key)
