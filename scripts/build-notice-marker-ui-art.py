"""Only UI references; globally shared particle textures remain untouched."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];P=ROOT/'gdproj'
def line(d,c='#edbe72',w=3,fill='none'):return f'<path d="{d}" fill="{fill}" stroke="{c}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>'
rows=[('notice','ui/popups/mods_update_warning_illustration.png',400,line('M12 16H52V49H12Z M22 49V56H42V49','#86ada9',3,'#203e49')+line('M32 18L49 44H15Z','#edbe72',3,'#493e32')+line('M32 26V34M32 39V40','#f5e6bb',3)),('zone_initial','particles/sprites/particle_2.png',64,line('M32 8L54 20V44L32 56L10 44V20Z','#f0e9d8',3,'#314b52')),('stat_initial','particles/sprites/particle_23.png',64,line('M12 48H52M19 43V30M32 43V16M45 43V24','#f0e9d8',4)),('wave_point','particles/sprites/particle_9.png',64,'<circle cx="32" cy="32" r="24" fill="#18292d"/><circle cx="32" cy="32" r="15" fill="#ffffff"/>'),('zone_unselected','particles/sprites/particle_26.png',64,line('M32 14V50M14 32H50','#ffffff',7))]
out=[]
for name,source,size,body in rows:
 target='res://combat3d/art/ui/ui_status_'+name+'.svg'
 (P/target[6:]).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 64 64">{body}</svg>\n',encoding='utf-8')
 out.append({'id':name,'source':'res://'+source,'target':target,'size':[size,size]})
resources=[]
for relative in ['ui/popups/popup_anouncement.tscn','ui/menus/run/zone_ui.tscn','ui/menus/shop/stat_container.tscn','ui/hud/ui_timeline_slot.tscn']:
 p=P/relative;before=p.read_text(encoding='utf-8-sig');after=before
 for row in out:after=after.replace(row['source'],row['target'])
 if before!=after:p.write_text(after,encoding='utf-8',newline='\n');resources.append('gdproj/'+relative)
(ROOT/'docs/notice-marker-ui-art-map.json').write_text(json.dumps({'assets':out,'resources':resources,'scope':'Only the four named display scenes; shared particle PNGs and other references preserved.'},indent=2)+'\n')
print(len(out),'assets',len(resources),'display resources')
