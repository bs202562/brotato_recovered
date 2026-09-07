import json
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
project=root/'gdproj'
refs={}
for folder in ['ui','resources/themes']:
    for file in (project/folder).rglob('*'):
        if file.suffix not in ['.gd','.tscn','.tres']: continue
        for path in re.findall(r'res://[^"\s]+\.png',file.read_text(encoding='utf-8-sig')):
            if 'combat3d' in path: continue
            refs.setdefault(path,[]).append(file.relative_to(project).as_posix())
(root/'docs/remaining-ui-art.json').write_text(json.dumps(refs,indent=2)+'\n')
print('\n'.join(sorted(refs)))
