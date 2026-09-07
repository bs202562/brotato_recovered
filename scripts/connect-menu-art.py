import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'gdproj'
mapping={
 'res://ui/menus/shop/shop_background.png':'res://combat3d/art/armory_menu.png',
 'res://ui/menus/shop/crash_zone_background.png':'res://combat3d/art/armory_menu.png',
 'res://dlcs/dlc_1/zones/abyss/resources/bg_mono.png':'res://combat3d/art/armory_menu.png',
 'res://ui/menus/shop/random_zone_background.png':'res://combat3d/art/armory_menu.png',
 'res://icon.png':'res://combat3d/art/enemies/colossus.png',
}
count=0
for path in root.rglob('*'):
    if path.suffix not in ['.gd','.tscn','.tres','.godot'] or 'combat3d' in path.parts or '.import' in path.parts: continue
    text=path.read_text(encoding='utf-8-sig')
    revised=re.sub(r'res://[^"\s]+\.png',lambda m:mapping.get(m[0],m[0]),text)
    if 'ui' in path.parts:
        revised=revised.replace('res://entities/units/player/potato.png','res://combat3d/art/characters/character_well_rounded.png')
    if revised!=text:
        path.write_text(revised,encoding='utf-8',newline='\n')
        count+=1
print('Connected armory/menu art in',count,'resources')
