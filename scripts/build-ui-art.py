"""Vector-native HUD symbols; readable at small sizes, with matching teal/brass edges."""
import json
import re
import struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
project=root/'gdproj'
out=project/'combat3d/art/ui'
out.mkdir(parents=True,exist_ok=True)
symbols={
 'max_hp':'M32 51L13 33C0 16 23 6 32 23C41 6 64 16 51 33Z',
 'hp_regeneration':'M26 12H38V26H52V38H38V52H26V38H12V26H26Z',
 'lifesteal':'M32 8C26 22 14 30 14 40A18 18 0 0 0 50 40C50 30 38 22 32 8Z M25 37H39M32 30V44',
 'percent_damage':'M13 45L39 19L45 25L19 51Z M39 19L45 7L57 7L57 19L45 25 M10 34L30 54',
 'melee_damage':'M14 50L38 26L34 22L54 8L51 29L46 25L22 49 M9 39L25 55',
 'ranged_damage':'M8 20H50L57 27L50 34H27L23 51H12L16 34H8Z M39 14V20',
 'elemental_damage':'M34 7C40 27 53 25 51 43C48 59 14 60 12 42C10 30 20 27 21 19L27 33C33 24 28 16 34 7Z',
 'attack_speed':'M10 17H31L19 29H37L14 53L21 35H8Z M38 14L51 27L38 40 M48 14L61 27L48 40',
 'crit_chance':'M32 7L38 24L56 18L44 33L58 45L39 42L32 59L25 42L7 46L20 33L8 19L26 24Z',
 'engineering':'M17 8L26 18L21 26L12 24L7 14C1 29 15 39 25 33L45 55L55 45L33 25C39 14 29 2 17 8Z',
 'range':'M8 32H56M8 26V38M56 26V38 M17 14A25 25 0 0 1 47 14 M17 50A25 25 0 0 0 47 50',
 'armor':'M10 13L32 6L54 13V34C51 46 41 53 32 59C23 53 13 46 10 34Z M32 15V48',
 'dodge':'M9 23L24 8L36 13L43 8L55 23L46 28L39 43L26 55L17 48L27 33L20 27Z',
 'speed':'M11 49L23 31L32 37L40 16L49 19L47 41L56 46L55 54H12Z M8 22H26M5 31H19',
 'luck':'M32 29C6 2 2 34 25 33C2 36 18 61 32 39C46 61 62 36 39 33C62 34 58 2 32 29Z M32 37L29 58',
 'harvesting':'M31 56V14 M30 24C10 26 9 12 12 8C27 8 31 14 30 24Z M33 35C53 36 56 21 52 16C39 17 33 24 33 35Z M30 45C10 44 8 33 12 29C24 29 30 36 30 45Z',
 'shield':'M10 13L32 6L54 13V34C51 46 41 53 32 59C23 53 13 46 10 34Z M22 31L29 39L44 23',
 'lock':'M17 28V19A15 15 0 0 1 47 19V28 M12 28H52V56H12Z M32 38V47',
 'skull':'M12 31V22C12 0 52 0 52 22V31L44 38V51H20V38Z M20 21H27V29H20Z M37 21H44V29H37Z M28 42V52M36 42V52',
 'plus':'M26 10H38V26H54V38H38V54H26V38H10V26H26Z',
 'cross':'M14 14L50 50M50 14L14 50',
 'check':'M10 32L25 47L54 16',
 'arrow_right':'M10 25H35V12L56 32L35 52V39H10Z',
 'arrow_left':'M54 25H29V12L8 32L29 52V39H54Z',
 'triangle_right':'M17 9L52 32L17 55Z',
 'triangle_left':'M47 9L12 32L47 55Z',
 'triangle_up':'M9 47L32 12L55 47Z',
 'triangle_down':'M9 17L32 52L55 17Z',
 'reset':'M50 24A21 21 0 1 0 52 42 M50 7V24H34',
 'codex':'M7 12H25L32 18L39 12H57V51H39L32 56L25 51H7Z M32 20V50',
 'profile':'M20 18A12 12 0 1 0 44 18A12 12 0 1 0 20 18 M9 55V46C9 27 55 27 55 46V55Z',
 'crosshair':'M32 4V17M32 47V60M4 32H17M47 32H60 M19 32A13 13 0 1 0 45 32A13 13 0 1 0 19 32',
 'cursor':'M9 5L49 33L32 37L25 55Z',
 'upgrade':'M9 40V32C9 15 36 15 36 32V40L29 48H16Z M43 49V25H35L47 9L60 25H52V49Z',
}
mapping={}
for name in ['max_hp','hp_regeneration','lifesteal','percent_damage','melee_damage','ranged_damage','elemental_damage','attack_speed','crit_chance','engineering','range','armor','dodge','speed','luck','harvesting']:
    mapping['res://items/stats/'+name+'.png']=name
extra={'items/global/locked_icon.png':'lock','ui/hud/hit_protection_icon.png':'shield','ui/crosshair.png':'crosshair','ui/custom_cursor.png':'cursor','ui/menus/global/big_checkmark.png':'check','ui/menus/global/cross_icon..png':'cross','ui/menus/global/plus_icon..png':'plus','ui/menus/global/codex_icon.png':'codex','ui/menus/global/profil_icon.png':'profile','ui/menus/global/reset_icon.png':'reset','ui/icons/misc/enemy_icon.png':'skull','ui/icons/misc/elite_icon.png':'skull','ui/icons/misc/horde_icon.png':'skull'}
for direction in ['right','left','up','down']:
    extra[f'ui/menus/global/triangle_{direction}_icon.png']='triangle_'+direction
for direction in ['right','left']:
    for suffix in ['','_border']: extra[f'ui/menus/global/arrow_{direction}{suffix}.png']='arrow_'+direction
mapping.update({'res://'+k:v for k,v in extra.items()})
mapping['res://items/upgrades/upgrade_icon.png']='upgrade'
mapping['res://items/upgrades/armor/flat_dmg_reduction.png']='armor'
replacements={}
for source,symbol in mapping.items():
    original=project/source.removeprefix('res://')
    if not original.exists(): continue
    width,height=struct.unpack('>II',original.read_bytes()[16:24])
    filename=source.removeprefix('res://').replace('/','_').replace('.png','.svg')
    color='#75d5c4' if symbol in ['hp_regeneration','lifesteal','shield','check','crosshair'] else '#edbe72'
    shape=symbols[symbol]
    fill='none' if symbol in ['range','cross','check','reset','crosshair'] else '#25434a'
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 64 64"><path d="{shape}" fill="{fill}" stroke="#12242c" stroke-width="8" stroke-linejoin="round" stroke-linecap="round" transform="translate(0 2)"/><path d="{shape}" fill="{fill}" stroke="{color}" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/></svg>'
    (out/filename).write_text(svg)
    replacements[source]='res://combat3d/art/ui/'+filename
for path in project.rglob('*'):
    if path.suffix not in ['.gd','.tscn','.tres','.godot'] or 'combat3d' in path.parts or '.import' in path.parts: continue
    text=path.read_text(encoding='utf-8-sig')
    revised=re.sub(r'res://[^"\s]+\.png',lambda m:replacements.get(m[0],m[0]),text)
    if revised!=text: path.write_text(revised,encoding='utf-8',newline='\n')
(root/'docs/ui-art-map.json').write_text(json.dumps(replacements,indent=2)+'\n')
print('New vector HUD symbols:',len(replacements))
