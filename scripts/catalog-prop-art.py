import json
from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'gdproj'
catalog = {}
for category, folder in [('pet','entities/units/pet'), ('structure','entities/structures')]:
    for path in (root/folder).rglob('*.tscn'):
        if path.stem in ['pet','structure']: continue
        catalog[path.stem] = {'kind':category, 'identity':'res://'+path.relative_to(root).as_posix()}
catalog['tree'] = {'kind':'tree', 'identity':'res://entities/units/neutral/tree.tscn'}
for key in ['fruit','item_box','legendary_item_box']:
    catalog[key] = {'kind':'consumable', 'identity':'consumable_'+key}
catalog['material'] = {'kind':'material','identity':'material'}
(root/'combat3d/prop_catalog.json').write_text(json.dumps(catalog,indent=2)+'\n')
print('Prop identities:', len(catalog))
