"""Record observed Studio state, never infer completion from a submission."""
import argparse
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--asset',required=True)
p.add_argument('--status',required=True)
p.add_argument('--balance',type=int)
p.add_argument('--retopology',type=int)
p.add_argument('--rigging',type=int)
p.add_argument('--triangles',type=int)
p.add_argument('--file')
p.add_argument('--animation')
args=p.parse_args()
path=root/'docs/tripo-production-2026-09-06.json'
batch=json.loads(path.read_text())
asset=next(a for a in batch['assets'] if a['id']==args.asset)
asset['status']=args.status
for argument,key in [('retopology','retopology_credits'),('rigging','rigging_credits'),('triangles','target_triangles'),('animation','animation')]:
    if getattr(args,argument) is not None: asset[key]=getattr(args,argument)
if args.file:
    assert (root/args.file).is_file()
    asset['file']=args.file
if args.balance is not None:
    assert args.balance<=batch['latest_observed_balance'],'Do not overwrite current balance with a stale tab balance'
    batch['latest_observed_balance']=args.balance
    batch['credits_spent_this_batch']=batch['starting_balance']-args.balance
path.write_text(json.dumps(batch,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
ledger_path=root/'docs/combat3d-assets.json'
ledger=json.loads(ledger_path.read_text())
ledger['observed_latest_balance']=batch['latest_observed_balance']
ledger['credits_spent']=ledger['observed_start_balance']-ledger['observed_latest_balance']
assert ledger['credits_spent']<=ledger['authorized_credit_limit']
ledger_path.write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(args.asset,args.status,'Observed balance:',batch['latest_observed_balance'])
