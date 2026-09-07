"""Register a verified Studio submission and its observed charge."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
for name in ('id', 'identity', 'studio-id', 'url', 'brief'):
    p.add_argument('--' + name, required=True)
p.add_argument('--balance', type=int, required=True)
p.add_argument('--credits', type=int, default=55)
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
path = root / 'docs/tripo-production-2026-09-06.json'
batch = json.loads(path.read_text())
assert args.balance <= batch['latest_observed_balance']
assert not any(a['studio_id'] == args.studio_id or a['id'] == args.id for a in batch['assets'])
assert args.studio_id in args.url and args.url.startswith('https://studio.tripo3d.ai/')
batch['assets'].append(dict(id=args.id, target_identity=args.identity,
    studio_id=args.studio_id, url=args.url, generation_credits=args.credits,
    status='generation_running', brief=args.brief))
batch['latest_observed_balance'] = args.balance
batch['credits_spent_this_batch'] = batch['starting_balance'] - args.balance
ledger_path = root / 'docs/combat3d-assets.json'
ledger = json.loads(ledger_path.read_text())
ledger['observed_latest_balance'] = args.balance
ledger['credits_spent'] = ledger['observed_start_balance'] - args.balance
assert ledger['credits_spent'] <= ledger['authorized_credit_limit']
path.write_text(json.dumps(batch, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
ledger_path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(args.id, 'registered; observed balance:', args.balance)
