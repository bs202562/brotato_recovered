"""Record static-model acceptance only after explicit human/agent visual review.

Reads production ledgers without modifying them. Validates the actual configured
GLB, imported source hashes, icons and combat logs before updating the queue.
"""
import argparse
import hashlib
import io
import json
import re
import struct
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('identities', nargs='+')
parser.add_argument('--import-log', required=True)
parser.add_argument('--visual-reviewed', action='store_true', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
project = root / 'gdproj'
queue_path = root / 'docs/model-production-queue.json'
queue = json.loads(queue_path.read_text(encoding='utf-8'))
manifest = json.loads((project / 'combat3d/models.json').read_text(encoding='utf-8'))
ledger = json.loads((root / 'docs/tripo-production-2026-09-06.json').read_text(encoding='utf-8'))
import_log = root / args.import_log
assert 'ICONS_COMPLETE:' in import_log.read_text(encoding='utf-8')
bad_errors = r'SCRIPT ERROR|Parse Error|Assertion failed'
assert not re.search(bad_errors, import_log.with_suffix('.err').read_text(encoding='utf-8'))

def check_import(source):
    remap = Path(str(source) + '.import').read_text(encoding='utf-8')
    imported = project / re.search(r'^path="res://([^"]+)"', remap, re.M)[1]
    assert imported.is_file(), imported
    digest = imported.with_suffix('.md5').read_text(encoding='utf-8')
    assert 'source_md5="' + hashlib.md5(source.read_bytes()).hexdigest() + '"' in digest, source

for identity in args.identities:
    assert identity.startswith(('weapon_', 'prop:')), identity
    row = next(r for r in queue['models'] if r['id'] == identity)
    assert not row['rig'], 'Rigged models require animation acceptance'
    entry = manifest[identity]
    source = project / entry['path'].removeprefix('res://')
    check_import(source)
    data = source.read_bytes()
    assert struct.unpack_from('<4sII', data) == (b'glTF', 2, len(data))
    chunks, offset = {}, 12
    while offset < len(data):
        size, kind = struct.unpack_from('<II', data, offset)
        chunks[kind] = data[offset+8:offset+8+size]
        offset += 8 + size
    gltf = json.loads(chunks[0x4E4F534A])
    assert not gltf.get('skins') and not gltf.get('animations')
    triangles = 0
    for mesh in gltf['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4
            triangles += gltf['accessors'][primitive['indices']]['count'] // 3
    assert 0 < triangles <= row['target_triangles'] * 1.03
    assert gltf.get('images'), 'Textured export expected'
    for texture in gltf['images']:
        view = gltf['bufferViews'][texture['bufferView']]
        start = view.get('byteOffset', 0)
        encoded = chunks[0x004E4942][start:start+view['byteLength']]
        assert Image.open(io.BytesIO(encoded)).size == (1024,1024)
    weapon = identity.startswith('weapon_')
    key = identity if weapon else identity.removeprefix('prop:')
    stem = 'docs/' + key + ('-placement-battle' if weapon else '-model-battle')
    output = (root / (stem + '.log')).read_text(encoding='utf-8')
    assert 'COMBAT3D_TEST_COMPLETE:' in output
    assert 'COMBAT3D_ART_IDENTITY_VERIFIED: ' + identity in output
    assert 'COMBAT3D_MODEL_VERIFIED: ' + entry['path'] in output
    assert not re.search(bad_errors, (root / (stem + '.err')).read_text(encoding='utf-8'))
    if weapon: assert 'COMBAT3D_WEAPON_PRESENTATION_VERIFIED: ' + identity in output
    capture = root / (stem + '-hud.png')
    assert Image.open(capture).size[1] > 500
    icons = [project / ('combat3d/art/weapons/' + identity + '_' + str(tier) + '.png') for tier in range(4)] if weapon else [project / ('combat3d/art/props/' + key + '.png')]
    for icon in icons: check_import(icon)
    matching_assets = [a for a in ledger['assets']
                       if a.get('target_identity') == identity
                       and 'reject' not in a.get('status', '').lower()
                       and entry['path'] in [str(a.get(key, '')).replace('gdproj/', 'res://') for key in ('file', 'engine_file')]]
    assert len(matching_assets) == 1, (identity, 'Expected one non-rejected ledger asset matching the actual engine file', len(matching_assets))
    asset = matching_assets[0]
    exported = asset['file'].replace('gdproj/', 'res://')
    row.update(status='downloaded_imported_engine_reviewed', local_glb=entry['path'], studio_url=asset['url'], production_asset=asset['id'])
    if exported != entry['path']: row['source_export_glb'] = exported
    row['acceptance'] = {flag: True for flag in row['acceptance']}
    evidence = row.setdefault('evidence', {})
    evidence.update(sha256=hashlib.sha256(data).hexdigest(), triangles=triangles, engine_review_log=args.import_log, runtime_log=stem+'.log', visually_reviewed_runtime_capture=stem+'-hud.png', visually_reviewed_icon=str(icons[1 if weapon else 0].relative_to(root)).replace('\\','/'))
    if weapon: evidence['placement_and_tier_verified'] = True
    print('Verified reviewed asset:', identity, triangles, 'triangles')

temporary = queue_path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(queue, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
temporary.replace(queue_path)
print('Fully accepted:', sum(all(r['acceptance'].values()) for r in queue['models']), '/', len(queue['models']))
