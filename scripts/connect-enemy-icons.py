"""Use the rendered combat identities in the enemy codex, preserving all stats."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'gdproj'
connected = []
for path in PROJECT.rglob('*.tres'):
    source = path.read_text(encoding='utf-8-sig')
    if 'res://entities/units/enemies/ItemEnemy.gd' not in source:
        continue
    identity = re.search(r'^my_id = "([^"]+)"', source, re.M)[1]
    texture = f'res://combat3d/art/enemies/{identity}.png'
    assert (PROJECT / texture.removeprefix('res://')).exists(), identity
    icon = re.search(r'^icon = ExtResource\( (\d+) \)', source, re.M)[1]
    source, count = re.subn(rf'(\[ext_resource path=")[^"]+(" type="Texture" id={icon}\])', lambda m: m[1]+texture+m[2], source)
    assert count == 1, path
    path.write_text(source, encoding='utf-8', newline='\n')
    connected.append({'id': identity, 'resource': 'res://'+path.relative_to(PROJECT).as_posix(), 'icon': texture})
(ROOT / 'docs/enemy-icon-coverage.json').write_text(json.dumps(connected, indent=2)+'\n')
print(f'Connected {len(connected)} enemy codex portraits')
