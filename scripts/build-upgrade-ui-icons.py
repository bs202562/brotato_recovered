"""Replace only 19 upgrade/stat display texture families, preserving all gameplay data."""
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'gdproj'
OUT=PROJECT/'combat3d/art/ui'
ROWS=[
 ('accuracy','accuracy','Accuracy',None),('attack_speed','attack_speed','Attack speed','attack_speed'),
 ('crit_chance','crit_chance','Crit chance','crit_chance'),('crit_damage','crit_dmg','Crit damage',None),
 ('damage','flat_dmg','Flat damage',None),('dodge','dodge','Dodge',None),
 ('elemental_damage','elemental_dmg','Elemental','elemental_damage'),('engineering','engineering','Engineering','engineering'),
 ('harvesting','harvesting','Harvesting','harvesting'),('health','health','Max health','max_hp'),
 ('health_regeneration','health_regen','Regeneration','hp_regeneration'),('lifesteal','lifesteal','Life steal','lifesteal'),
 ('luck','consumable_drop_chance','Luck','luck'),('melee_damage','melee_dmg','Melee damage','melee_damage'),
 ('percent_damage','percent_dmg','Damage %',None),('range','range','Range','range'),
 ('ranged_damage','ranged_dmg','Ranged damage','ranged_damage'),('speed','speed','Speed','speed'),
 ('weapon_slot','weapon_slot','Weapon slots',None),
]
custom={
 'dodge':('M18 12A5 5 0 1 0 28 12A5 5 0 1 0 18 12 M26 23L17 39L7 51M17 39L34 51M26 23L39 30 M41 9C59 17 59 35 44 45 M48 34L44 45L56 43','none','#edbe72'),
 'accuracy':('M11 32A21 21 0 1 0 53 32A21 21 0 1 0 11 32 M23 32A9 9 0 1 0 41 32A9 9 0 1 0 23 32 M32 3V15M32 49V61M3 32H15M49 32H61','none','#75d5c4'),
 'crit_damage':('M32 6L38 22L54 14L45 31L58 41L41 42L37 58L28 44L12 53L18 36L5 26L22 24Z M25 25L39 39M39 25L25 39','#25434a','#edbe72'),
 'damage':('M10 51L31 30L27 26L40 13L53 26L40 39L36 35L15 56Z M12 8V24M4 16H20','#25434a','#edbe72'),
 'percent_damage':('M14 49L50 13 M10 18A8 8 0 1 0 26 18A8 8 0 1 0 10 18 M38 46A8 8 0 1 0 54 46A8 8 0 1 0 38 46','none','#edbe72'),
 'weapon_slot':('M5 10H20V34H5Z M25 10H40V34H25Z M45 10H60V34H45Z M32 42V59M23 50H41','#25434a','#75d5c4'),
}
rows=[]
for key,file,label,reuse in ROWS:
    target='res://combat3d/art/ui/ui_upgrade_'+key+'.svg'
    source=f'res://items/upgrades/{key}/{file}.png'
    if reuse:
        svg=(OUT/('items_stats_'+reuse+'.svg')).read_text(encoding='utf-8')
        svg=re.sub(r'width="\d+" height="\d+"','width="96" height="96"',svg,count=1)
    else:
        shape,fill,color=custom[key]
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 64 64"><path d="{shape}" fill="{fill}" stroke="#12242c" stroke-width="7" stroke-linejoin="round" stroke-linecap="round" transform="translate(0 1)"/><path d="{shape}" fill="{fill}" stroke="{color}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/></svg>'
    (PROJECT/target.removeprefix('res://')).write_text(svg+'\n',encoding='utf-8')
    rows.append({'id':key,'label':label,'source':source,'target':target,'reused_symbol':reuse,'size':[96,96]})
mapping={r['source']:r['target'] for r in rows}
resources=[]
for p in PROJECT.rglob('*'):
    if p.suffix not in ('.gd','.tscn','.tres') or '.import' in p.parts or 'combat3d' in p.parts: continue
    before=p.read_text(encoding='utf-8-sig')
    after=before
    matches=[]
    for source,target in mapping.items():
        if source in before or target in before: matches.append({'source':source,'target':target})
        after=after.replace(source,target)
    if not matches: continue
    if before!=after: p.write_text(after,encoding='utf-8',newline='\n')
    resources.append({'file':p.relative_to(ROOT).as_posix(),'bindings':matches,'changed':before!=after,'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest(),'only_allowed_path_substitutions':all((old==new or any(old.replace(m['source'],m['target'])==new for m in matches)) for old,new in zip(before.splitlines(),after.splitlines())) and len(before.splitlines())==len(after.splitlines())})
assert all(r['only_allowed_path_substitutions'] for r in resources)
report={'icons':rows,'resources':resources,'scope':'Only exact 19 old upgrade texture paths replaced; existing stat symbols reused for 13 matching meanings; six additional symbols designed. All dimensions 96x96. No visual acceptance inferred.'}
(ROOT/'docs/upgrade-ui-icon-map.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Upgrade icons:',len(rows),'display resources:',len(resources),'path-only data changes verified')
