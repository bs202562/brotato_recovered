"""Distinct recommendation faces and four settings symbols, display paths only."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'gdproj'
OUT=PROJECT/'combat3d/art/ui'
def path(d,color='#edbe72',fill='none',width=3):
    return f'<path d="{d}" fill="{fill}" stroke="#12242c" stroke-width="{width+3}" stroke-linecap="round" stroke-linejoin="round"/><path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
icons=[]
for role in ('curious','king','fairy'):
    for mood in ('happy','sad'):
        color='#75d5c4' if mood=='happy' else '#e78c7e'
        body=''
        if role=='fairy': body=path('M19 24C2 7 1 36 17 40 M45 24C62 7 63 36 47 40', '#ba91dc', '#354050')
        body+=path('M17 22Q17 12 32 12Q47 12 47 22V41Q45 55 32 55Q19 55 17 41Z', color, '#25434a')
        if role=='curious': body+=path('M18 27H28V35H18Z M36 27H46V35H36Z M28 30H36','#edbe72',width=2)
        else: body+=path('M25 29V31M39 29V31',color,width=3)
        if role=='king': body+=path('M16 18L13 5L25 11L32 3L39 11L51 5L48 18Z','#edbe72','#604d36',2)
        if role=='curious': body+=path('M19 17L16 9L35 5L47 13','#edbe72','#35434a',2)
        if role=='fairy': body+=path('M27 12L32 4L37 12','#ba91dc',width=2)
        body+=path('M25 42Q32 51 39 42' if mood=='happy' else 'M25 47Q32 38 39 47',color,width=2.5)
        icons.append({'id':role+'_'+mood,'label':role.title()+' '+mood,'size':96,'source':f'res://ui/icons/misc/{role}_{mood}.png','target':f'res://combat3d/art/ui/ui_shop_{role}_{mood}.svg','body':body})
settings={
 'audio':'M8 25H20L34 13V51L20 39H8Z M42 23Q54 32 42 41 M49 16Q65 32 49 48',
 'video':'M7 9H57V45H7Z M32 45V55M20 56H44',
 'gameplay':'M18 20H46Q56 20 58 35L60 46Q60 55 51 48L42 40H22L13 48Q4 55 4 46L6 35Q8 20 18 20Z M19 26V37M14 32H25 M43 28V29M49 34V35',
 'accessibility':'M8 32A24 24 0 1 0 56 32A24 24 0 1 0 8 32 M28 17A4 4 0 1 0 36 17A4 4 0 1 0 28 17 M18 27H46M32 27V38L23 49M32 38L41 49',
}
for key,shape in settings.items(): icons.append({'id':key,'label':key.title(),'size':100,'source':f'res://ui/menus/global/{key}_icon.png','target':f'res://combat3d/art/ui/ui_settings_{key}.svg','body':path(shape,'#75d5c4' if key=='accessibility' else '#edbe72')})
for row in icons:
    body=row.pop('body')
    (PROJECT/row['target'].removeprefix('res://')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{row["size"]}" height="{row["size"]}" viewBox="0 0 64 64">{body}</svg>\n',encoding='utf-8')
resources=[]
for p in PROJECT.rglob('*'):
    if p.suffix not in ('.tscn','.tres','.gd') or 'combat3d' in p.parts or '.import' in p.parts: continue
    before=p.read_text(encoding='utf-8-sig'); after=before
    for row in icons: after=after.replace(row['source'],row['target'])
    if before!=after:
        p.write_text(after,encoding='utf-8',newline='\n')
        resources.append(p.relative_to(ROOT).as_posix())
(ROOT/'docs/shop-settings-icon-map.json').write_text(json.dumps({'icons':icons,'resources':resources},indent=2)+'\n')
print('10 shop/settings icons; display files changed:',len(resources))
