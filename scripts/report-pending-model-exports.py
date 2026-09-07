"""Offline export inventory only; never imports Godot or changes acceptance."""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
queue = json.loads((ROOT / 'docs/model-production-queue.json').read_text(encoding='utf-8'))
pending = {row['id']: row for row in queue['models'] if not all(row['acceptance'].values())}
ledger = json.loads((ROOT / 'docs/tripo-production-2026-09-06.json').read_text(encoding='utf-8'))
rows = []
for job in ledger['assets']:
    identity = job.get('target_identity')
    if identity not in pending or 'reject' in job.get('status', '').lower():
        continue
    for field in ('file', 'engine_file'):
        name = job.get(field)
        if not name:
            continue
        path = ROOT / name.replace('res://', 'gdproj/')
        if not path.is_file():
            continue
        raw = path.read_bytes()
        assert struct.unpack_from('<4sII', raw) == (b'glTF', 2, len(raw)), path
        cursor, chunks = 12, {}
        while cursor < len(raw):
            size, kind = struct.unpack_from('<II', raw, cursor)
            assert cursor + 8 + size <= len(raw), path
            chunks[kind] = raw[cursor + 8:cursor + 8 + size]
            cursor += 8 + size
        assert cursor == len(raw), path
        document = json.loads(chunks[0x4E4F534A])
        binary = chunks.get(0x004E4942, b'')
        triangles = 0
        for mesh in document.get('meshes', []):
            for part in mesh['primitives']:
                assert part.get('mode', 4) == 4, path
                accessor = document['accessors'][part.get('indices', part['attributes']['POSITION'])]
                assert accessor['count'] % 3 == 0, path
                triangles += accessor['count'] // 3
        textures = []
        for item in document.get('images', []):
            if 'bufferView' not in item:
                textures.append({'external_uri': item.get('uri')})
                continue
            view = document['bufferViews'][item['bufferView']]
            start = view.get('byteOffset', 0)
            payload = binary[start:start + view['byteLength']]
            with Image.open(io.BytesIO(payload)) as picture:
                picture.load()
                textures.append({'size': list(picture.size), 'sha256': hashlib.sha256(payload).hexdigest()})
        rows.append({'identity': identity, 'studio_uuid': job.get('studio_id'),
                     'field': field, 'file': name, 'bytes': len(raw),
                     'sha256': hashlib.sha256(raw).hexdigest(), 'triangles': triangles,
                     'target_triangles': pending[identity]['target_triangles'],
                     'skins': len(document.get('skins', [])),
                     'animations': [animation.get('name') for animation in document.get('animations', [])],
                     'textures': textures, 'status': 'offline_inventory_pending_engine_and_visual_validation'})
report = {'scope': 'Existing non-rejected pending exports from live ledger; file/engine_file may describe the same identity. No acceptance flags changed.', 'exports': rows}
(ROOT / 'docs/pending-model-exports.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'identities': len({row['identity'] for row in rows}), 'exports': len(rows)}))
