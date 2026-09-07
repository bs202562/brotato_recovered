"""Replace texture-based chrome while keeping each control's original pixel dimensions."""
import json
import re
import struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
project=root/'gdproj'
out=project/'combat3d/art/ui'
mapping={}
folders=['ui/hud','resources/themes/panel','resources/themes/separator','resources/themes/button_styles']
for folder in folders:
    for path in (project/folder).rglob('*.png'):
        name=path.stem
        if not any(x in name for x in ['frame','panel','lifebar','progress_','separator','grabber','annonucement']): continue
        width,height=struct.unpack('>II',path.read_bytes()[16:24])
        transparent='frame' in name or 'outline' in name or 'transparent' in name
        fill='#ffffff' if 'fill' in name or 'progress_progress' in name else '#152d35'
        if transparent: fill='none'
        border='#728f92' if 'frame' in name else '#365962'
        if 'separator' in name:
            body=f'<rect x="0" y="0" width="{width}" height="{height}" fill="#819f9f"/>'
        else:
            thickness=min(3,width/12,height/8)
            body=f'<rect x="{thickness/2}" y="{thickness/2}" width="{width-thickness}" height="{height-thickness}" rx="{min(6,height/8)}" fill="{fill}" stroke="{border}" stroke-width="{thickness}"/>'
            if 'frame_character' in name:
                body+=f'<path d="M5 17V5H17 M{width-17} {height-5}H{width-5}V{height-17}" fill="none" stroke="#e0b572" stroke-width="3"/>'
        filename=path.relative_to(project).as_posix().replace('/','_').replace('.png','.svg')
        (out/filename).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>')
        mapping['res://'+path.relative_to(project).as_posix()]='res://combat3d/art/ui/'+filename
for path in project.rglob('*'):
    if path.suffix not in ['.gd','.tscn','.tres','.godot'] or 'combat3d' in path.parts or '.import' in path.parts: continue
    text=path.read_text(encoding='utf-8-sig')
    revised=re.sub(r'res://[^"\s]+\.png',lambda m:mapping.get(m[0],m[0]),text)
    if revised!=text: path.write_text(revised,encoding='utf-8',newline='\n')
(root/'docs/ui-panel-map.json').write_text(json.dumps(mapping,indent=2)+'\n')
print('Vector panel textures:',len(mapping))
