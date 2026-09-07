"""Resolve direct UI references to the same art as their data resources."""
import json
import re
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
project = root/'gdproj'
mapping = json.loads((root/'docs/prop-icon-map.json').read_text())
rows = []
for name in ['character-art-coverage.json','weapon-art-coverage.json','enemy-icon-coverage.json','item-art-coverage.json']:
    payload = json.loads((root/'docs'/name).read_text())
    if isinstance(payload,dict): payload = payload.get('connected',payload.get('resources',[]))
    rows.extend(payload)
for row in rows:
    resource = row['resource'].replace('res://','gdproj/')
    target = row.get('icon',row.get('texture'))
    if not target: continue
    result = subprocess.run(['git','show','HEAD:'+resource],cwd=root,capture_output=True,text=True,encoding='utf-8')
    if result.returncode: continue
    icon = re.search(r'^icon = ExtResource\( (\d+) \)',result.stdout,re.M)
    if not icon: continue
    old = re.search(rf'\[ext_resource path="([^"]+)" type="Texture" id={icon[1]}\]',result.stdout)
    if old: mapping.setdefault(old[1],target)
changed = []
for path in project.rglob('*'):
    if path.suffix not in ['.gd','.tscn','.tres','.godot']: continue
    if 'combat3d' in path.parts or '.import' in path.parts: continue
    text = path.read_text(encoding='utf-8-sig')
    revised = re.sub(r'res://[^"\s]+\.(?:png|svg)',lambda m:mapping.get(m[0],m[0]),text)
    if revised != text:
        path.write_text(revised,encoding='utf-8',newline='\n')
        changed.append(path.relative_to(project).as_posix())
(root/'docs/shared-art-map.json').write_text(json.dumps(mapping,indent=2)+'\n')
print('Updated direct art references in',len(changed),'resources')
