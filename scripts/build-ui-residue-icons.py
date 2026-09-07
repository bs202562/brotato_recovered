"""Five scoped UI replacements; original combat textures stay untouched."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'gdproj/combat3d/art/ui'

def stroke(shape, fill='#25434a', color='#edbe72', width=3):
    return f'<path d="{shape}" fill="{fill}" stroke="#12242c" stroke-width="{width+4}" stroke-linejoin="round" stroke-linecap="round" transform="translate(0 1.5)"/><path d="{shape}" fill="{fill}" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'

skull='M17 30V22C17 6 47 6 47 22V30L41 36V49H23V36Z M24 22H29V28H24Z M35 22H40V28H35Z M28 42V49M36 42V49'
crown='M20 12L17 4L27 9L32 2L37 9L47 4L44 12Z'
boss=stroke(skull)+stroke(crown, '#85633a', '#edbe72', 2)
icons={
 'ui_manual_cursor':(70, stroke('M35 5V16M35 54V65M5 35H16M54 35H65 M20 35A15 15 0 1 0 50 35A15 15 0 1 0 20 35','none','#75d5c4',2.5)+'<circle cx="35" cy="35" r="2.5" fill="#edbe72"/>', '0 0 70 70'),
 'ui_boss_event':(96,'<g transform="translate(0 4)">'+boss+'</g>','0 0 64 64'),
 'ui_two_bosses_event':(96,'<g transform="translate(0 8) scale(.62)">'+boss+'</g><g transform="translate(24 19) scale(.62)">'+boss+'</g>','0 0 64 64'),
 'ui_fog_event':(96,stroke('M5 31Q32 7 59 31Q32 55 5 31Z','none','#75d5c4',3)+stroke('M25 31A7 7 0 1 0 39 31A7 7 0 1 0 25 31','none','#75d5c4',3)+stroke('M7 22H28M37 22H55M12 33H49M5 44H25M33 44H59','none','#edbe72',4),'0 0 64 64'),
 'ui_bullet_hell_event':(80,stroke('M28 29L28 12L32 5L36 12V29Z M24 34L9 28L4 22L13 23L28 29Z M36 29L51 23L60 22L55 28L40 34Z M27 38L19 53L12 58L14 49L23 34Z M41 34L50 49L52 58L45 53L37 38Z','#25434a','#edbe72',2.5)+'<circle cx="32" cy="33" r="6" fill="#75d5c4" stroke="#12242c" stroke-width="3"/>','0 0 64 64'),
}
for name,(size,body,viewbox) in icons.items():
    (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{viewbox}">{body}</svg>\n',encoding='utf-8')
replacements={
 'ui/manual_cursor.png':'ui_manual_cursor',
 'ui/icons/misc/boss_icon.png':'ui_boss_event',
 'ui/icons/misc/two_bosses_icon.png':'ui_two_bosses_event',
 'ui/icons/misc/fog_icon.png':'ui_fog_event',
 'projectiles/bullet_hells/bullet_hell_icon.png':'ui_bullet_hell_event',
}
files=['singletons/cursor_manager.gd','ui/icons/all/boss_icon_data.tres','ui/icons/all/two_bosses_icon_data.tres','ui/icons/all/fog_of_war_icon_data.tres','ui/icons/all/bullet_hell_icon_data.tres','ui/menus/pages/killed_by_container.tscn']
for relative in files:
    p=ROOT/'gdproj'/relative
    text=p.read_text(encoding='utf-8-sig')
    revised=text
    for old,name in replacements.items(): revised=revised.replace('res://'+old,'res://combat3d/art/ui/'+name+'.svg')
    if revised != text: p.write_text(revised,encoding='utf-8',newline='\n')
print('Wrote five vector UI symbols; scoped six display resource files.')
