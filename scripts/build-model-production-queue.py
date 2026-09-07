"""Inventory-driven production queue. A queued record is never completion evidence."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
project=root/'gdproj'
inventory=json.loads((root/'docs/art-inventory.json').read_text())
manifest=json.loads((project/'combat3d/models.json').read_text())
weapons=json.loads((root/'docs/weapon-art-coverage.json').read_text())['resources']
props=json.loads((project/'combat3d/prop_catalog.json').read_text())
destination=root/'docs/model-production-queue.json'
previous={r['id']:r for r in json.loads(destination.read_text()).get('models',[])} if destination.exists() else {}
records=[]
def add(identity,category,triangles,rig,source,role=''):
    item={'id':identity,'category':category,'source':source,'role':role,'target_triangles':triangles,'texture_size':1024,'rig':rig,'status':'pending_generation','estimated_credits':80 if rig else 60,'local_glb':None,'studio_url':None,'acceptance':{'local_file':False,'topology':False,'engine_import':False,'visual_review':False,'runtime_identity':False}}
    if identity in previous: item.update(previous[identity])
    records.append(item)
for item in inventory['identities']['characters']:
    add(item['id'],'survivor',6000,'humanoid',item['resource'])
for key,entry in manifest.items():
    if not key.startswith('enemy:'): continue
    add(key,'enemy',6000 if entry.get('scale',1)>=2 else 3000,'humanoid' if not entry.get('recipe') else None,key,entry.get('role',entry.get('recipe','')))
seen=set()
for item in weapons:
    if item['weapon'] in seen: continue
    seen.add(item['weapon'])
    add(item['weapon'],'weapon',1500,None,item['resource'])
for key,entry in props.items():
    add('prop:'+key,entry['kind'],3000,'animal' if entry['kind']=='pet' else None,entry['identity'])
for key in ['shopfront','vending_machine','bench','shopping_cart','kiosk','barricade','pillar','escalator','security_gate','supply_shelf','generator','lamp']:
    add('environment:'+key,'environment',3000,None,'mall arena')
baseline={'character_well_rounded':'survivor_security_6000_idle','enemy:baby_alien':'zombie_shopper_3000_walk','enemy:colossus':'zombie_riot_captain_6000_walk','enemy:mom':'zombie_foodcourt_chef_6000_walk','enemy:spitter':'zombie_toxic_janitor_3000_walk'}
for identity,filename in baseline.items():
    row=next(r for r in records if r['id']==identity)
    local='res://combat3d/models/'+filename+'.glb'
    if (project/local.removeprefix('res://')).exists() and row['status']=='pending_generation':
        row.update(status='existing_local_pending_full_acceptance',local_glb=local)
        row['acceptance']['local_file']=True
for file in ['tripo-production-2026-09-06.json']:
    batch=json.loads((root/'docs'/file).read_text())
    for asset in batch['assets']:
        row=next((r for r in records if r['id']==asset.get('target_identity')),None)
        if row:
            row.update(status=asset['status'],studio_url=asset['url'],production_asset=asset['id'])
            if asset.get('file'):
                row['local_glb']=asset['file'].replace('gdproj/','res://')
                row['acceptance']['local_file']=(root/asset['file']).exists()
                imported_path = manifest.get(row['id'], {}).get('path')
                if row['acceptance'].get('engine_import') and imported_path and imported_path != row['local_glb']:
                    row['source_export_glb'] = row['local_glb']
                    row['local_glb'] = imported_path
                    row['acceptance']['local_file'] = (project/imported_path.removeprefix('res://')).exists()
payload={'scope':'All selectable survivors, every enemy identity, all weapon families, active utility objects and mall environment pieces. Shared procedural substitutes do not satisfy independent-model acceptance.','estimated_full_pass_credits':sum(r['estimated_credits'] for r in records),'models':records}
destination.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Model queue:',len(records),'Estimated full pass credits:',payload['estimated_full_pass_credits'])
