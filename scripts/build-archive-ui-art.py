"""Archive/profile presentation only; preserve canvas sizes and central UI windows."""
import json
from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'gdproj'
OUT=PROJECT/'combat3d/art/ui'
def rect(x,y,w,h,fill,stroke='none',sw=0,rx=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def line(d,color='#75d5c4',sw=4,fill='none'):
    return f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>'
def symbol(d,color='#edbe72'):
    return line(d,'#12242c',7)+line(d,color,3)
def bolts(points):
    return ''.join(f'<circle cx="{x}" cy="{y}" r="8" fill="#95aaa7"/>'+line(f'M{x-3} {y}H{x+3}','#263d44',2) for x,y in points)
def frame(x,y,w,h,b=30):
    # Four bars: no opaque rectangle beneath the content window.
    return rect(x,y,w,b,'#29444c','#72918f',5)+rect(x,y+h-b,w,b,'#29444c','#72918f',5)+rect(x,y+b,b,h-b*2,'#29444c','#72918f',5)+rect(x+w-b,y+b,b,h-b*2,'#29444c','#72918f',5)
sources=['ui/icons/misc/buffer_unlockall.png','ui/menus/global/inverse_order_icon.png']
sources += ['ui/menus/pages/menu_codex/'+n+'.png' for n in ['codex_menu_button','codex_menu_button_pressed','codex_menu_cable','codex_menu_pointer','codex_menu_shelf','grid_graph']]
sources += ['ui/menus/pages/menu_profil/'+n+'.png' for n in ['button_physic_normal','button_physic_pressed','menu_profil_run_on0000','profil_copy_icon','profil_delete_icon','profil_menu_back','profil_menu_base','profil_menu_electric_wire_0_back','profil_menu_electric_wire_0_front','profil_menu_electric_wire_1_back','profil_menu_electric_wire_1_front','profil_menu_floppy_disk','profil_menu_support','profil_selected','profil_unlockall_icon','separator_physic']]
rows=[]
for source in sources:
    p=PROJECT/source; name=p.stem; w,h=struct.unpack('>II',p.read_bytes()[16:24]); body=''; view=f'0 0 {w} {h}'
    if name in ('buffer_unlockall','profil_unlockall_icon'):
        view='0 0 64 64'; body=symbol('M20 29V19Q20 6 32 6Q44 6 44 19 M14 29H50V54H14Z M32 37V45')+line('M7 12L9 17L14 18L9 20L7 25L5 20L1 18L5 16Z','#75d5c4',1,'#75d5c4')
    elif name=='inverse_order_icon':
        view='0 0 64 64'; body=symbol('M19 53V10M9 20L19 10L29 20 M45 11V54M35 44L45 54L55 44')
    elif name=='profil_copy_icon':
        view='0 0 64 64'; body=symbol('M10 42V7H42V16 M20 18H54V57H20Z M28 29H46M28 38H46M28 47H40')
    elif name=='profil_delete_icon':
        view='0 0 64 64'; body=symbol('M13 19H51M25 19V10H39V19 M18 24L21 55H43L46 24 M28 29V46M36 29V46','#f0e9d8')
    elif name=='profil_selected':
        view='0 0 64 64'; body=symbol('M8 32A24 24 0 1 0 56 32A24 24 0 1 0 8 32 M20 32L29 41L45 23','#f0e9d8')
    elif name=='menu_profil_run_on0000':
        view='0 0 64 64'; body=symbol('M8 32A24 24 0 1 0 56 32A24 24 0 1 0 8 32 M26 19L45 32L26 45Z','#75d5c4')
    elif name.startswith('button_physic') or name.startswith('codex_menu_button'):
        pressed='pressed' in name; y=12 if pressed else 5
        body=rect(4,15,w-8,h-19,'#7e9197','#e0e9e1',3,12)+rect(4,y,w-8,h-25,'#d6e1de','#f2f0df',3,12)+line(f'M20 {y+9}H{w-20}','#f5f2e7',3)+line(f'M20 {h-17}H{w-20}','#819b9b',3)
    elif name=='separator_physic': body=rect(0,12,w,5,'#99b3b2')+rect(0,19,w,3,'#35535c')
    elif name=='grid_graph':
        body=''.join(line(f'M{x} 0V{h}','#45636b',1) for x in range(0,w,38))+''.join(line(f'M0 {y}H{w}','#45636b',1) for y in range(0,h,28))
    elif name=='codex_menu_pointer': body=line('M5 5L74 19L5 33L18 19Z','#f4d9a0',3,'#c28f4e')
    elif name=='codex_menu_cable':
        body=line('M110 5V145Q110 200 160 240Q215 280 160 360L80 465Q35 535 90 620Q140 700 130 885','#122831',40)+line('M110 5V145Q110 200 160 240Q215 280 160 360L80 465Q35 535 90 620Q140 700 130 885','#78918f',18)+line('M104 5V140Q104 190 153 236','#e3b875',4)
    elif name=='codex_menu_shelf':
        body=frame(124,175,1680,870,110)+rect(250,955,765,78,'#203943','#637f84',4,12)+rect(1040,955,150,78,'#203943','#637f84',4,12)+bolts([(175,225),(175,990),(1755,225),(1755,990)])+line('M260 205H620M1300 205H1660','#d8af72',8)
        # Preserve the original left/right window bounds exactly enough for behind-parent controls.
        body=rect(124,175,1680,49,'#29444c','#72918f',5)+rect(124,224,123,724,'#29444c','#72918f',5)+rect(1668,224,136,724,'#29444c','#72918f',5)+rect(124,948,1680,97,'#29444c','#72918f',5)+bolts([(175,200),(175,990),(1755,200),(1755,990)])+line('M300 200H650M1270 200H1620','#d8af72',8)
    elif name=='profil_menu_base':
        body=rect(330,220,1260,107,'#29444c','#72918f',5,18)+rect(330,327,80,510,'#29444c','#72918f',5)+rect(1040,327,550,510,'#213a42','#72918f',5)+rect(330,837,1260,53,'#29444c','#72918f',5)+bolts([(365,255),(1552,255),(365,861),(1552,861)])+line('M450 249H760M1160 249H1470','#d8af72',7)
    elif name=='profil_menu_support':
        body=rect(500,888,930,49,'#3d565c','#79958f',5,14)+rect(800,940,320,140,'#213a42','#637f84',5)+''.join(line(f'M815 {y}H1105','#597782',5) for y in range(960,1080,25))
    elif name=='profil_menu_back': body=rect(4,4,w-8,h-8,'#203943','#72918f',4,12)+line(f'M20 16H{w-20}','#c09c68',3)
    elif name=='profil_menu_floppy_disk':
        body=rect(7,7,w-14,h-14,'#a6bfc0','#e6ede3',7,19)+rect(65,11,190,90,'#dae3df','#819b9f',5,4)+rect(93,21,116,63,'#557d85')+rect(42,142,235,134,'#d7dfd4','#7a989c',5,7)+line('M62 177H251M62 208H219','#859f9f',4)+bolts([(27,283),(291,283)])
    elif 'electric_wire' in name:
        shift=20 if '_1_' in name else 0; d=f'M{80+shift} 5V95Q{80+shift} 160 180 193Q275 235 183 302Q110 351 135 435'
        body=line(d,'#132a33',32)+line(d,'#718d8c' if name.endswith('back') else '#d3b078',15)+line(d,'#acc0b4' if name.endswith('back') else '#f0d49b',3)
    else: raise AssertionError(name)
    target='res://combat3d/art/ui/ui_archive_'+name+'.svg'
    (PROJECT/target.removeprefix('res://')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{view}">{body}</svg>\n',encoding='utf-8')
    rows.append({'id':name,'source':'res://'+source,'target':target,'size':[w,h]})
resources=[]
for p in PROJECT.rglob('*'):
    if p.suffix not in ('.gd','.tscn','.tres') or 'combat3d' in p.parts or '.import' in p.parts: continue
    before=p.read_text(encoding='utf-8-sig'); after=before
    for row in rows: after=after.replace(row['source'],row['target'])
    if before!=after:
        p.write_text(after,encoding='utf-8',newline='\n'); resources.append(p.relative_to(ROOT).as_posix())
(ROOT/'docs/archive-ui-art-map.json').write_text(json.dumps({'assets':rows,'resources':resources,'preserved':'Original dimensions, StyleBox region rectangles/margins, control coordinates, functional callbacks and data unchanged.'},indent=2)+'\n')
print('Archive assets:',len(rows),'display resources:',len(resources))
