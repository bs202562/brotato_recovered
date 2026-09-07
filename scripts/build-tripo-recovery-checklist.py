"""Read local evidence only; do not submit jobs or alter acceptance."""
import collections
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: json.loads((ROOT / p).read_text(encoding='utf-8'))
ledger = read('docs/tripo-production-2026-09-06.json')
queue = read('docs/model-production-queue.json')['models']
targets = {x['id']: x for x in queue}
incoming = {}
for station in ('secondary', 'tertiary'):
    for a in read(f'docs/tripo-{station}-production-handoff.json')['assets']:
        incoming[a['studio_id']] = a

rows, exclusions, local = [], [], []
for a in ledger['assets']:
    uuid = a['studio_id']
    identity = a.get('target_identity')
    row = {'identity': identity, 'asset_id': a['id'], 'studio_uuid': uuid,
           'studio_url': a.get('url'), 'ledger_status': a['status'],
           'owner': a.get('production_owner', 'tripo_production'),
           'generation_credits_paid': a.get('generation_credits', 0),
           'rigging_credits_paid': a.get('rigging_credits', 0),
           'note': a.get('production_note', incoming.get(uuid, {}).get('preview_notes', ''))}
    if 'reject' in a['status'] or a['status'].startswith('unused'):
        row['action'] = 'Preserve original UUID and costs; excluded from recovery. Do not regenerate or bind this rejected/unused attempt.'
        exclusions.append(row)
        continue
    file = a.get('file')
    if file and (ROOT / file).is_file():
        raw = (ROOT / file).read_bytes()
        assert struct.unpack_from('<4sII', raw) == (b'glTF', 2, len(raw)), file
        row.update(file=file, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(),
                   action='Local export exists. Do not download/regenerate/rebind merely because ledger status was stale. Final engine validation remains separate.')
        local.append(dict(row))
        gltf_len = struct.unpack_from('<I', raw, 12)[0]
        gltf = json.loads(raw[20:20+gltf_len])
        needs_motion = targets.get(identity, {}).get('category') in {'enemy', 'survivor'} and targets.get(identity, {}).get('rig')
        if not needs_motion or (gltf.get('skins') and gltf.get('animations')):
            continue
        row['raw_local_file'] = file
    meta = incoming.get(uuid, {})
    if row['rigging_credits_paid']:
        row['phase'] = 'paid_rig_needs_clip_or_export'
        clip = 'preset:biped:idle' if identity.startswith('character_') else 'preset:biped:walk'
        row['action'] = f'Open existing rigging UUID; inspect current skeleton. Select free {clip} once if absent, wait, revisit existing page, export GLB/1K with skeleton=1 and selected animation=1. Never click paid rig retry.'
    elif not targets.get(identity, {}).get('rig'):
        row['phase'] = 'generated_needs_download'
        row['action'] = 'Open existing UUID; finish/check generation if needed, then free GLB/1K export. Download observed signed URL immediately and verify local GLB. Do not submit generation or rig.'
    else:
        row['phase'] = 'generated_needs_rig'
        row['action'] = 'Open existing UUID and verify generation/visual completeness. After service recovery, verify no prior paid rig has appeared before one v1.0 humanoid 20-credit bind, then free clip/GLB1K export. Do not regenerate.'
    if identity == 'enemy:buffer' and not row['rigging_credits_paid']:
        row['phase'] = 'generated_needs_visual_decision_before_rig'
        row['action'] = 'Free raw GLB/1K export for root review first: megaphone occludes head. No rig or regeneration until root resolves visual candidate.'
    row['handoff_status'] = meta.get('status')
    row['observed_triangles'] = a.get('observed_triangles', a.get('target_triangles', meta.get('actual_ui_triangles')))
    rows.append(row)

covered = {x['identity'] for x in rows + local}
for q in queue:
    if q['id'] in covered or all(q['acceptance'].values()):
        continue
    category = q['category']
    rows.append({'identity': q['id'], 'studio_uuid': None, 'phase': 'not_submitted',
                 'owner': {'enemy': 'tripo_production', 'survivor': 'combat_fx', 'weapon': 'art_backlog'}.get(category, 'root'),
                 'target_triangles': q['target_triangles'], 'rig': q.get('rig'),
                 'action': 'No active non-rejected UUID in local master ledger. Before first submission recheck live master + both station handoffs and Studio; keep assigned category ownership. Never infer a failed click means no job without verification.'})
report = {'scope': 'Local recovery snapshot, no generation/rig/export requests and no acceptance changes.',
          'observed_balance': ledger['latest_observed_balance'],
          'unattributed_credit_delta': ledger.get('credit_reconciliation', {}).get('unattributed_observed_credits'),
          'global_rules': ['Service has recovered; keep category ownership and UUID deduplication. Pause paid retries if another outage occurs.',
                           'Do not reuse stale signed download URLs; request free export from original UUID.',
                           'No paid retry while service is unresponsive. Original attempts and all observed fees stay recorded.',
                           'Downloaded and locally repaired candidates are not final engine acceptance.'],
          'counts': dict(collections.Counter(x['phase'] for x in rows)),
          'recover': rows, 'local_exports_do_not_repeat': local, 'excluded_attempts': exclusions}
(ROOT / 'docs/tripo-service-recovery-checklist.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'counts': report['counts'], 'local_exports': len(local), 'excluded': len(exclusions)}, ensure_ascii=False))
