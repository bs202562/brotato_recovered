"""Read-only production snapshot; downloaded files are not runtime acceptance."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
queue = json.loads((ROOT / 'docs/model-production-queue.json').read_text(encoding='utf-8'))
ledger = json.loads((ROOT / 'docs/tripo-production-2026-09-06.json').read_text(encoding='utf-8'))

def local_file(value):
    if not value:
        return False
    path = ROOT / (value.replace('res://', 'gdproj/') if value.startswith('res://') else value)
    return path.is_file() and path.stat().st_size > 20

rows = []
for model in queue['models']:
    jobs = [job for job in ledger['assets'] if job.get('target_identity') == model['id']]
    usable = [job for job in jobs if 'reject' not in job.get('status', '').lower()]
    accepted = all(model['acceptance'].values())
    downloads = [job for job in usable if local_file(job.get('file'))]
    downloaded = bool(downloads) or (accepted and local_file(model.get('local_glb')))
    state = 'accepted' if accepted else 'downloaded_pending_validation' if downloaded else 'studio_job_exists' if usable else 'needs_replacement' if jobs else 'not_submitted'
    rows.append({'id': model['id'], 'category': model['category'], 'state': state,
                 'local_files': [job['file'] for job in downloads]})
report = {'scope': 'Read-only snapshot. Download presence does not prove visual, structural or runtime acceptance.',
          'total': len(rows), 'counts': dict(Counter(row['state'] for row in rows)),
          'downloaded_or_accepted': sum(row['state'] in ('accepted', 'downloaded_pending_validation') for row in rows),
          'latest_ledger_balance': ledger.get('latest_observed_balance'), 'models': rows}
(ROOT / 'docs/model-generation-snapshot.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key != 'models'}))
