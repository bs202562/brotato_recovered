"""Record observed rig cost and visual review in secondary handoff only."""
import json,sys
from pathlib import Path
p=Path('docs/tripo-secondary-production-handoff.json');d=json.loads(p.read_text(encoding='utf-8-sig'))
key,balance,tri,note=sys.argv[1:]
e=next(x for x in d['assets'] if x['target_identity']=='character_'+key)
assert e.get('rigging_credits',0)==0
e.update(rigging_credits=20,observed_balance=int(balance),status='rigging',ui_triangles=int(tri),visual_note=note)
p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8');print(key,'rig recorded')
