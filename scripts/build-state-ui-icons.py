"""Four scoped state symbols. Curse center stays completely transparent."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'gdproj'
OUT=PROJECT/'combat3d/art/ui'
def path(d,color='#edbe72',fill='none',width=3):
    return f'<path d="{d}" fill="{fill}" stroke="#12242c" stroke-width="{width+4}" stroke-linecap="round" stroke-linejoin="round"/><path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
rows=[
 ('random_icon',96,'Random / unknown',path('M14 8H47L55 16V56H9V13Z',fill='#25434a')+path('M24 23C24 11 45 13 43 25C42 31 32 31 32 39 M32 47V48','#75d5c4',width=4)),
 ('curse_border_light',256,'Cursed overlay',path('M5 22V8L8 5H22 M42 5H56L59 8V22 M59 42V56L56 59H42 M22 59H8L5 56V42','#ba91dc',width=2)+path('M4 14L10 10L14 4 M50 4L54 10L60 14 M60 50L54 54L50 60 M14 60L10 54L4 50','#76568d',width=2)),
 ('info',96,'Information',path('M8 32A24 24 0 1 0 56 32A24 24 0 1 0 8 32','#75d5c4',fill='#25434a')+path('M32 28V46M26 46H38M32 17V18',width=4)),
 ('baned_item',256,'Banned item',path('M8 32A24 24 0 1 0 56 32A24 24 0 1 0 8 32 M15 49L49 15','#f0e9d8',width=4)),
]
mapping={}
icons=[]
for key,size,label,body in rows:
    target='res://combat3d/art/ui/ui_state_'+key+'.svg'
    (PROJECT/target.removeprefix('res://')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 64 64">{body}</svg>\n',encoding='utf-8')
    source=f'res://items/global/{key}.png'
    mapping[source]=target
    icons.append({'id':key,'source':source,'target':target,'size':size,'label':label})
resources=[]
for p in PROJECT.rglob('*'):
    if p.suffix not in ('.tscn','.tres','.gd') or 'combat3d' in p.parts or '.import' in p.parts: continue
    before=p.read_text(encoding='utf-8-sig')
    after=before
    for source,target in mapping.items(): after=after.replace(source,target)
    if before==after: continue
    assert len(before.splitlines())==len(after.splitlines())
    p.write_text(after,encoding='utf-8',newline='\n')
    resources.append(p.relative_to(ROOT).as_posix())
(ROOT/'docs/state-ui-icon-map.json').write_text(json.dumps({'icons':icons,'resources':resources},indent=2)+'\n')
print('4 state icons connected in',len(resources),'display resources')
