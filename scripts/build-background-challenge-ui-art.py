"""Display-only swatches retain existing environment names; no floor/gameplay edits."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];P=ROOT/'gdproj'
def path(d,c='#d7c69a',fill='none',w=2):return f'<path d="{d}" stroke="{c}" fill="{fill}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>'
shapes={
'dirt':('M18 25L25 22L33 25M42 32L49 29L56 32M31 35L36 33','#9b8061'),
'forest':('M19 25L27 10L35 25ZM27 25V32M40 29L48 14L56 29ZM48 29V35','#689a7d'),
'volcano':('M21 30L30 12H39L51 32M30 12L34 19L39 12M34 20L32 29L39 35','#ce795d'),
'dreamy_lands':('M27 12L31 22L41 26L31 30L27 40L23 30L13 26L23 22ZM52 10L55 17L62 20L55 23L52 30L49 23L42 20L49 17Z','#b494cb'),
'boneyard':('M20 16Q12 12 14 20Q10 26 19 24L46 35Q52 43 55 36Q64 32 55 29L28 18Q28 10 20 16Z','#a4a091'),
'darklands':('M18 34L25 15L32 34M32 34L41 8L50 34M48 34L56 21L63 34','#77668f'),
'ocean':('M12 22Q18 15 25 22Q32 29 39 22Q46 15 53 22Q59 29 65 22M12 31Q18 24 25 31Q32 38 39 31Q46 24 53 31Q59 38 65 31','#619cac'),
'shipwreck':('M13 27L20 37H53L62 27H43L36 31L31 27ZM36 26V7L51 22H36','#8c988b'),
'abyss':('M18 15L30 24L18 39M58 15L46 24L58 39M34 9V35L39 30M27 12L19 7M49 12L57 7','#756a9c')}
rows=[]
for i,(name,(shape,c)) in enumerate(shapes.items()):
 source='res://resources/tiles/icon_'+str(i+1)+'.png' if i<6 else 'res://dlcs/dlc_1/resources/tiles/bg_'+name+'_icon.png'
 body=path('M4 17L36 3L71 17V31L39 46L4 31Z','#719191','#1b333d')+path('M4 17L39 32L71 17M39 32V46','#719191')+path(shape,c,w=2.5)
 rows.append({'id':name,'source':source,'size':[75,48],'body':body,'view':'0 0 75 48'})
rows.append({'id':'ban_challenge','source':'res://items/challenges/ban_system_icon.png','size':[96,96],'view':'0 0 64 64','body':path('M8 32A24 24 0 1 0 56 32A24 24 0 1 0 8 32M15 15L49 49','#e7a08a',w=4)+path('M23 22H42V42H23Z','#edbe72',w=2)})
rows.append({'id':'paws_challenge','source':'res://items/challenges/beast_master_challenge.png','size':[96,96],'view':'0 0 64 64','body':path('M16 43Q16 37 25 32Q32 26 39 32Q48 37 48 43Q48 52 39 50Q32 47 25 50Q16 52 16 43Z','#75d5c4','#29464b',3)+''.join(f'<ellipse cx="{x}" cy="{y}" rx="5" ry="8" fill="#29464b" stroke="#75d5c4" stroke-width="3"/>' for x,y in [(12,28),(25,17),(39,17),(52,28)])})
for row in rows:
 row['target']='res://combat3d/art/ui/ui_environment_'+row['id']+'.svg'
 (P/row['target'][6:]).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{row["size"][0]}" height="{row["size"][1]}" viewBox="{row.pop("view")}">{row.pop("body")}</svg>\n',encoding='utf-8')
resources=[]
for p in P.rglob('*.tres'):
 if 'combat3d' in p.parts or '.import' in p.parts:continue
 before=p.read_text(encoding='utf-8-sig');after=before
 for row in rows:after=after.replace(row['source'],row['target'])
 if before!=after:p.write_text(after,encoding='utf-8',newline='\n');resources.append(p.relative_to(ROOT).as_posix())
(ROOT/'docs/background-challenge-ui-art-map.json').write_text(json.dumps({'assets':rows,'resources':resources},indent=2)+'\n')
print(len(rows),'assets;',len(resources),'resources')
