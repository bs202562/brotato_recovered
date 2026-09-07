import json
import re
import argparse
from pathlib import Path
root = Path(__file__).resolve().parents[1]
project = root/'gdproj'
parser = argparse.ArgumentParser()
parser.add_argument('--props', help='Targeted DLC consumable keys, comma-separated; preserves all other resources and map entries.')
args = parser.parse_args()
dlc_keys = ['poisoned_fruit','cursed_chest']
if args.props:
    keys = args.props.split(',')
    assert keys and all(key in dlc_keys for key in keys), keys
    map_path = root/'docs/prop-icon-map.json'
    targeted_map = json.loads(map_path.read_text()) if map_path.exists() else {}
    for key in keys:
        icon = f'res://combat3d/art/props/{key}.png'
        assert (project/icon.removeprefix('res://')).exists(), key
        path = project/f'dlcs/dlc_1/consumables/{key}_data.tres'
        source = f'res://dlcs/dlc_1/consumables/{key}.png'
        text = path.read_text(encoding='utf-8-sig')
        assert f'my_id = "consumable_{key}"' in text, key
        revised = text.replace(f'path="{source}" type="Texture"',f'path="{icon}" type="Texture"')
        assert revised != text or f'path="{icon}" type="Texture"' in text, key
        if revised != text: path.write_text(revised,encoding='utf-8',newline='\n')
        targeted_map[source] = icon
    map_path.write_text(json.dumps(targeted_map,indent=2)+'\n')
    print('Connected targeted DLC consumable icons:', ', '.join(keys))
    raise SystemExit(0)
mapped = {}
changed = []
for path in project.rglob('*_item.tres'):
    text = path.read_text(encoding='utf-8-sig')
    if 'res://entities/units/pet/ItemPet.gd' not in text: continue
    key = path.stem.removesuffix('_item')
    icon = f'res://combat3d/art/props/{key}.png'
    assert (project/icon.removeprefix('res://')).exists(),key
    def replace(match):
        mapped[match[1]] = icon
        return match[0].replace(match[1],icon)
    text = re.sub(r'\[ext_resource path="([^"]+\.png)" type="Texture" id=\d+\]',replace,text)
    path.write_text(text,encoding='utf-8',newline='\n')
    changed.append(path.relative_to(project).as_posix())
for key in ['fruit','item_box','legendary_item_box']:
    mapped[f'res://items/consumables/{key}/{key}.png'] = f'res://combat3d/art/props/{key}.png'
for key in dlc_keys:
    mapped[f'res://dlcs/dlc_1/consumables/{key}.png'] = f'res://combat3d/art/props/{key}.png'
for path in (project/'items/materials').glob('*.png'):
    mapped['res://'+path.relative_to(project).as_posix()] = 'res://combat3d/art/props/material.png'
(root/'docs/prop-icon-map.json').write_text(json.dumps(mapped,indent=2)+'\n')
print('Connected pet codex resources:',len(changed))
