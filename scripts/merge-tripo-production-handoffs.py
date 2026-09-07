"""Single-ledger-owner merge of observed secondary/tertiary submissions."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'docs/tripo-production-2026-09-06.json'
read = lambda p: json.loads(p.read_text(encoding='utf-8'))
for station, owner in [('secondary', 'combat_fx'), ('tertiary', 'art_backlog')]:
    source = ROOT / f'docs/tripo-{station}-production-handoff.json'
    if not source.exists():
        continue
    for incoming in read(source)['assets']:
        uuid = incoming.get('studio_id')
        if not uuid:
            continue
        batch = read(path)
        asset = next((a for a in batch['assets'] if a['studio_id'] == uuid), None)
        if asset is None:
            identity = incoming['target_identity']
            default_id = ('survivor_' + identity.removeprefix('character_')) if identity.startswith('character_') else ('enemy_' + identity.split(':')[-1] if identity.startswith('enemy:') else 'utility_' + identity.split(':')[-1])
            aid = incoming.get('id') or default_id
            if incoming.get('attempt'):
                aid += '_' + incoming['attempt']
            balance = incoming.get('observed_balance', incoming.get('observed_balance_after'))
            assert balance is not None
            subprocess.run(['python', str(ROOT / 'scripts/register-tripo-asset.py'),
                '--id', aid, '--identity', identity, '--studio-id', uuid,
                '--url', incoming['url'], '--credits', str(incoming['generation_credits']),
                '--balance', str(min(balance, batch['latest_observed_balance'])),
                '--brief', incoming.get('prompt', incoming.get('brief'))], check=True, cwd=ROOT)
            batch = read(path)
            asset = next(a for a in batch['assets'] if a['studio_id'] == uuid)
        asset['production_owner'] = owner
        if incoming.get('rigging_credits', 0) > asset.get('rigging_credits', 0):
            balance = incoming.get('observed_balance', incoming.get('observed_balance_after', batch['latest_observed_balance']))
            subprocess.run(['python', str(ROOT / 'scripts/record-tripo-phase.py'),
                '--asset', asset['id'], '--status', incoming.get('status', 'rigging_running'),
                '--rigging', str(incoming['rigging_credits']),
                '--balance', str(min(balance, batch['latest_observed_balance']))], check=True, cwd=ROOT)
            batch = read(path)
            asset = next(a for a in batch['assets'] if a['studio_id'] == uuid)
        for key in ['target_triangles', 'rigging_credits', 'retopology_credits']:
            if key in incoming:
                asset[key] = incoming[key]
        if incoming.get('file') and (ROOT / incoming['file']).is_file():
            for key in ['file', 'bytes', 'sha256', 'actual_triangles', 'skins', 'animations', 'texture_sizes', 'visual_note']:
                if key in incoming:
                    asset[key] = incoming[key]
            if asset['status'] in {'generation_running', 'rigging', 'rigging_running'} and incoming.get('status', '').startswith('downloaded'):
                asset['status'] = incoming['status']
        path.write_text(json.dumps(batch, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Handoffs merged by UUID; observed balance:', read(path)['latest_observed_balance'])
