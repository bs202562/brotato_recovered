"""Read-only current-reference art audit. Static evidence never means visual acceptance."""
import collections
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'gdproj'
TEXT = {'.gd', '.tscn', '.tres', '.godot', '.shader', '.json'}
MEDIA = {'.png', '.svg', '.jpg', '.jpeg', '.webp', '.ico', '.icns', '.ttf', '.otf', '.glb', '.gltf', '.ogv', '.webm'}
URI = re.compile(r'res://[^"\s\)\],;]+')
DISPLAY = re.compile(r'^(?:texture|icon|atlas|normal_map|bulletIcon|logo|image|custom_icons/[^ ]+|texture_normal|texture_pressed|texture_hover|texture_disabled|mouse_cursor/custom_image|boot_splash/image|config/(?:icon|windows_native_icon|macos_native_icon))\s*=')

def ref(file, line, code, **kwargs):
    return dict(file=file, line=line, code=code.strip()[:350], **kwargs)

def main():
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    files = {}
    assets = {}
    graph = collections.defaultdict(list)
    dynamic = []
    for p in sorted(PROJECT.rglob('*')):
        if not p.is_file() or any(x in p.parts for x in ('.import', '.git', '.godot')):
            continue
        rel = p.relative_to(PROJECT).as_posix()
        uri = 'res://' + rel
        if p.suffix.lower() in MEDIA:
            assets[uri] = {'path':uri, 'file':p.relative_to(ROOT).as_posix(), 'bytes':p.stat().st_size, 'mtime_ns':p.stat().st_mtime_ns, 'references':[]}
        if p.suffix.lower() in TEXT:
            try:
                files[uri] = p.read_text(encoding='utf-8-sig')
            except (UnicodeError, OSError):
                pass
    mappings = collections.defaultdict(list)
    coverage = []
    for p in sorted((ROOT/'docs').glob('*.json')):
        if not any(x in p.name for x in ('art-map', 'icon-map', 'art-coverage', 'icon-coverage')):
            continue
        try:
            payload = json.loads(p.read_text(encoding='utf-8'))
        except (ValueError, UnicodeError):
            continue
        coverage.append({'file':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        if isinstance(payload, dict):
            for source, dest in payload.items():
                if source.startswith('res://') and isinstance(dest, str):
                    mappings[source].append({'target':dest,'map':p.relative_to(ROOT).as_posix()})
    for uri, content in files.items():
        rel = 'gdproj/' + uri.removeprefix('res://')
        lines = content.splitlines()
        ext = {}
        for num, line in enumerate(lines, 1):
            if line.lstrip().startswith('#'):
                continue
            match = re.search(r'\[ext_resource path="([^"]+)".*?id=(\d+)', line)
            if match:
                ext[match[2]] = match[1]
            for target in URI.findall(line):
                if target.endswith(('.png', '.svg', '.jpg', '.jpeg', '.webp', '.ico', '.icns', '.ttf', '.otf', '.glb', '.gltf', '.ogv', '.webm')):
                    if target not in assets:
                        target_file = PROJECT / target.removeprefix('res://')
                        stat = target_file.stat() if target_file.exists() else None
                        assets[target] = {'path':target,'file':'gdproj/'+target.removeprefix('res://'),'bytes':stat.st_size if stat else None,'mtime_ns':stat.st_mtime_ns if stat else None,'references':[]}
                    output_only = bool(re.search(r'\.(?:save_png|save_jpg|save_webp|save_exr)\s*\(',line))
                    assets[target]['references'].append(ref(rel,num,line,reference_type='generated_output_literal' if output_only else 'static_literal',display_property=bool(DISPLAY.match(line.strip()))))
                graph[target].append(ref(rel,num,line))
            if uri.endswith('.gd'):
                call = re.search(r'\b(?:load|preload|load_interactive|load_threaded_request)\s*\((.+)',line)
                # Dynamic resource access includes variable-only calls, formatted literals and concatenation.
                if call and (not re.match(r'\s*"res://[^"%]+"\s*\)',call[1]) or '+' in call[1] or '%' in call[1]):
                    dynamic.append(ref(rel,num,line,reason='Resource expression is variable, formatted, concatenated or nonliteral; static scan cannot prove resolved art path.'))
                elif re.search(r'(?:\.|^\s*)(?:texture|icon)\s*=(?!=)(?!\s*null\b)',line) and not ('load(' in line or 'preload(' in line):
                    dynamic.append(ref(rel,num,line,reason='Texture/icon assignment from runtime value; trace resource identity and screen trigger.'))
        section = ''
        for num, line in enumerate(lines, 1):
            if line.startswith('['): section = line
            if not DISPLAY.match(line.strip()): continue
            for eid in re.findall(r'ExtResource\(\s*(\d+)\s*\)',line):
                target = ext.get(eid)
                if target in assets:
                    assets[target]['references'].append(ref(rel,num,line,reference_type='display_binding',display_property=True,section=section))
    tree = subprocess.run(['git','ls-tree','-r','HEAD','gdproj'],cwd=ROOT,capture_output=True,text=True,encoding='utf-8',check=True).stdout
    baseline = {}
    for line in tree.splitlines():
        meta, path = line.split('\t',1)
        baseline[path] = meta.split()[2]
    guards = [ref('gdproj/combat3d/battle_3d.gd',n,line) for n,line in enumerate(files['res://combat3d/battle_3d.gd'].splitlines(),1) if any(s in line for s in ('const SOURCES', 'node.modulate.a = 0.0', 'SOURCES +'))]
    # Only use positive source evidence for default-hidden 2D surfaces, never filename existence alone.
    combat_roots = ('gdproj/entities/','gdproj/projectiles/','gdproj/particles/','gdproj/visual_effects/','gdproj/weapons/','gdproj/dlcs/dlc_1/enemies/','gdproj/dlcs/dlc_1/weapons/')
    def display_context(r):
        return r['file'].startswith(('gdproj/ui/', 'gdproj/resources/themes/')) or r['file']=='gdproj/project.godot' or r['file']=='gdproj/singletons/cursor_manager.gd'
    for uri, asset in assets.items():
        p = ROOT/asset['file']
        if p.exists():
            data = p.read_bytes()
            asset['sha256'] = hashlib.sha256(data).hexdigest()
            blob = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
            asset['baseline_state'] = 'same_as_HEAD' if baseline.get(asset['file'])==blob else 'changed_since_HEAD' if asset['file'] in baseline else 'not_in_HEAD'
            asset['changed_during_audit'] = p.stat().st_mtime_ns != asset['mtime_ns']
        else:
            asset['baseline_state']='missing'
            asset['changed_during_audit']=False
        refs = asset['references']
        asset['replacement_maps'] = mappings.get(uri,[])
        asset['visual_acceptance'] = 'not_proven_by_static_audit'
        asset['direct_display_references'] = [r for r in refs if display_context(r) and (r['display_property'] or r['file'].endswith('.gd'))]
        # A .tres icon may be displayed through runtime data without a UI direct texture literal.
        asset['data_icon_references'] = [r for r in refs if r['reference_type']=='display_binding' and r['code'].startswith('icon =')]
        if refs and all(r['reference_type']=='generated_output_literal' for r in refs):
            cat, why = 'generated_output_not_input', 'Only an image export/save destination, not a runtime input asset. Missing file is not a broken load reference.'
        elif asset['baseline_state']=='missing':
            cat, why = 'missing_referenced_resource', 'Literal media resource path does not exist at audit time.'
        elif not refs:
            cat, why = 'no_static_reference_found', 'No supported literal reference found. Dynamic access, importer dependencies and platform metadata may still use it; not unused/deletable evidence.'
        elif uri.startswith('res://combat3d/'):
            cat, why = 'replacement_resource_referenced', 'New presentation directory is referenced, but visual quality and runtime coverage remain unverified.'
        elif asset['baseline_state']=='changed_since_HEAD':
            cat, why = 'in_place_changed_asset_needs_visual_review', 'File differs from HEAD at its old path. Do not call it original art merely from its filename.'
        elif asset['direct_display_references'] or asset['data_icon_references']:
            cat, why = 'legacy_display_binding_needs_route_review', 'Current display property/UI/cursor references a legacy-path asset. Binding exists; scene reachability, conditional override and actual content require review.'
        elif all(r['file'].startswith(combat_roots) for r in refs):
            cat, why = 'combat_2d_compatibility_or_logic_candidate', 'References are confined to combat source resources. Default 3D renderer alpha-hides source containers, but per-instance parentage/F8 and any logic size use require confirmation.'
        else:
            cat, why = 'legacy_reference_needs_route_review', 'Referenced outside proven replacement directory; no sufficient static evidence to assert visible residue or hidden compatibility.'
        if Path(uri).suffix in ('.ttf','.otf'):
            cat, why = 'font_reference_needs_style_review', 'Font is a visible style dependency, not a 3D model or necessarily an obsolete illustration.'
        asset['classification']=cat
        asset['basis']=why
        # Incoming scene/resource references establish potential route, not reachability proof.
        owners = {'res://'+r['file'].removeprefix('gdproj/') for r in refs}
        asset['owner_incoming_references'] = [v for owner in sorted(owners) for v in graph.get(owner,[])][:30]
        if cat=='combat_2d_compatibility_or_logic_candidate': asset['container_hiding_evidence']=guards
    def evidence_at(file, needle):
        content=files['res://'+file]
        return [ref('gdproj/'+file,n,line) for n,line in enumerate(content.splitlines(),1) if needle in line]
    confirmed=[]
    specs=[('res://ui/manual_cursor.png','Manual aiming cursor','singletons/cursor_manager.gd','return manual_image if show_manual_cursor else normal_image','Enable manual aiming in combat; confirm 70x70 cursor/hotspot before replacing.'),('res://projectiles/bullet_hells/bullet_hell_icon.png','Bullet-hell death recap','ui/menus/pages/killed_by_container.gd','icon.texture = bulletIcon','Trigger bullet-hell death recap; replace only UI bulletIcon or its texture, not projectile collision sprites.')]
    specs += [
        ('res://items/global/random_icon.png','Random item reveal','ui/menus/ingame/item_panel_ui.gd','_random_icon_container.visible = true','Open a random item panel/reveal; inspect the existing TextureRect and preserve reveal animation.'),
        ('res://items/global/curse_border_light.png','Cursed item border','ui/menus/shop/icon_panel.gd','_curse.visible = is_cursed','Display a cursed item in shop/codex; preserve overlay transparency and item icon visibility.'),
        ('res://items/global/info.png','Character selection records panel','ui/menus/run/character_selection.gd','_info_panel.visible = not RunData.is_coop_run and not element.is_random','Select a non-random character in solo mode and inspect the records/info panel.'),
        ('res://items/global/baned_item.png','Banned item filter button','ui/menus/ingame/ingame_main_menu.gd','_button_banned_items.visible = true','Open in-game menu with at least one banned item; inspect button icon and negative-color modulation.'),
        ('res://ui/icons/misc/buffer_unlockall.png','Unlock-all profile badge','ui/menus/pages/menu_codex.gd','_unlockall_icon.visible = ProgressData.is_unlock_all_save()','Open codex/profile for an unlock-all save without changing save status; inspect the badge and preserve its condition.'),
    ]
    for uri,label,file,needle,check in specs:
        asset=assets.get(uri)
        if asset and asset['references'] and asset['baseline_state']=='same_as_HEAD':
            asset['classification']='code_proven_conditional_legacy_display'
            asset['basis']='Unchanged HEAD image, current display binding plus code explicitly selects/shows its UI surface under the documented condition. Runtime screenshot still required.'
            confirmed.append({'path':uri,'surface':label,'evidence':asset['direct_display_references']+evidence_at(file,needle),'check':check,'acceptance':'static route proven; no runtime screenshot in this audit'})
    for uri,key in [('res://ui/icons/misc/boss_icon.png','icon_boss_hash'),('res://ui/icons/misc/two_bosses_icon.png','icon_two_bosses_hash'),('res://ui/icons/misc/fog_icon.png','icon_fog_of_war_hash')]:
        a=assets.get(uri)
        if a and a['baseline_state']=='same_as_HEAD' and a['data_icon_references']:
            chain=evidence_at('ui/hud/ui_timeline.gd',key)+evidence_at('ui/hud/ui_timeline_slot.gd','_event_icon.texture = event_icons[0][0]')+evidence_at('singletons/item_service.gd','return get_element(icons, icon_id).icon')
            if len(chain)>=3:
                a['classification']='code_proven_conditional_legacy_display'
                a['basis']='Unchanged icon data, ItemService lookup and timeline texture assignment form a conditional event display route; runtime screenshot still needed.'
                confirmed.append({'path':uri,'surface':'Timeline event '+key,'evidence':a['data_icon_references']+chain,'check':'Open wave timeline with the relevant boss/two-boss/fog event; replace icon data resource reference and verify event readability.','acceptance':'static route proven; no runtime screenshot in this audit'})
    upgrade_rows=[]
    for role in ('curious','king','fairy'):
        for mood in ('happy','sad'):
            uri=f'res://ui/icons/misc/{role}_{mood}.png'
            asset=assets.get(uri)
            if not asset or asset['baseline_state']!='same_as_HEAD' or not asset['data_icon_references']: continue
            route=evidence_at('singletons/item_service.gd',f'icon_{role}_{mood}')+evidence_at('ui/menus/shop/shop_item.gd','get_icon_for_duplicate_shop_item')+evidence_at('ui/menus/shop/shop_item.gd','_button.set_additional_icon(texture)')+evidence_at('ui/menus/shop/button_with_icon.gd','additional_icon.texture = icon')
            if len(route)<4: continue
            asset['classification']='code_proven_conditional_legacy_display'
            asset['basis']='IconData lookup under character/fairy item conditions flows through shop item ImageTexture creation into ButtonWithIcon.additional_icon. Actual trigger preview still required.'
            confirmed.append({'path':uri,'surface':f'{role} {mood} shop recommendation','evidence':asset['data_icon_references']+route,'check':'Use character_curious/character_king or fairy item conditions with matching owned-item and rarity states; preserve positive/negative semantics and verify shop plus upgrade take button.','acceptance':'static route proven; no runtime trigger screenshot in this audit'})
    for a in assets.values():
        if a['path'].startswith('res://items/upgrades/') and a['data_icon_references'] and a['baseline_state']=='same_as_HEAD':
            upgrade_rows.append({'path':a['path'],'evidence':a['data_icon_references'],'check':'Offer this upgrade in level-up UI; absent an active SkinManager override, ItemParentData.get_icon returns this image. Replace upgrade icon references, preserving effects and tier data.'})
    upgrade_chain=evidence_at('ui/menus/upgrades/upgrade_ui.gd','_upgrade_description.set_item')+evidence_at('ui/menus/shop/item_description.gd','_icon.texture = item_data.get_icon()')+evidence_at('items/global/item_parent_data.gd','return SkinManager.get_skin(icon)')+evidence_at('singletons/skin_manager.gd','return original_texture')
    report={'schema':1,'started_utc':started,'finished_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Current gdproj static resource references, display bindings, dynamic loading/texture assignments, file identity vs HEAD, and existing replacement maps. No game/resource/ledger changes; no Godot run.', 'limits':['Static bindings are not runtime reachability or visual acceptance.','HEAD equality proves unchanged bytes relative to this checkout baseline, not historical authorship.','Dynamic loading, packed binary import internals, platform-specific screens and conditions remain explicit review work.','No-reference records must never be treated as unused or safe to delete.','Scan is not transactional; changed_during_audit flags assets altered while reading.'], 'source_files_scanned':len(files),'coverage_inputs':coverage,'classification_counts':dict(collections.Counter(a['classification'] for a in assets.values())),'code_proven_conditional_residuals':confirmed,'assets':sorted(assets.values(),key=lambda a:a['path']),'dynamic_references':dynamic,'default_3d_gates':evidence_at('singletons/tower_defense_rules.gd','const ENABLED')+evidence_at('main.gd','combat3d/battle_3d')+evidence_at('ui/menus/title_screen/title_screen.gd','TowerDefenseRules.ENABLED')+evidence_at('ui/menus/title_screen/title_screen.gd','combat3d/art/title_data.tres'),'logic_size_evidence':evidence_at('weapons/weapon.gd','sprite.texture.get_size()')}
    report['upgrade_icons_with_skin_override_condition']={'count':len(upgrade_rows),'route_evidence':upgrade_chain,'entries':upgrade_rows,'limitation':'SkinManager can replace icons from external skin PCK/settings; inspect running skin state before claiming visible legacy pixels.'}
    queue = json.loads((ROOT/'docs/model-production-queue.json').read_text(encoding='utf-8'))
    queued = {r['source'] for r in queue['models']} | {r['id'] for r in queue['models']}
    gaps=[]
    for identity, basename in [('consumable_poisoned_fruit','poisoned_fruit'),('consumable_cursed_chest','cursed_chest')]:
        if identity not in queued and 'prop:'+basename not in queued:
            gaps.append({'identity':identity,'evidence':evidence_at('dlcs/dlc_1/consumables/'+basename+'_data.tres','my_id =')+evidence_at('dlcs/dlc_1/dlc_data.tres',basename+'_data.tres'),'basis':'Registered DLC consumable identity is absent from current independent model queue. Visibility requires DLC trigger; current generic supply rendering alone does not prove distinct poisonous/cursed semantics.','check':'Add to full-art scope, trace DLC spawn/pickup and reward/death UI, then verify distinct warning silhouette/icon and unchanged gameplay.'})
    report['model_queue_scope_gaps']=gaps
    (ROOT/'docs/current-art-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    md=['# 当前可见美术引用审计','',f'扫描时间：{started} 至 {report["finished_utc"]}。扫描 {len(files)} 个文本资源，记录 {len(assets)} 个媒体路径。只读审计；没有运行Godot，没有变更资源、旧inventory或生产账本。','', '**静态接线不等于画面验收；旧路径不等于旧内容；没有静态引用不等于可以删除。** JSON保留逐资源路径、行号、引用上下文、HEAD字节比较、映射证据和动态赋值。','', '## 可直接着手修复的条件显示残留','']
    for row in confirmed:
        md += [f'- `{row["path"]}` — {row["surface"]}。{row["check"]}', '  证据：'+'；'.join(f'`{r["file"]}:{r["line"]}`' for r in row['evidence'])+'.']
    md += ['', '上述条目只有在文件仍与HEAD一致且当前绑定与赋值链都存在时才列入。仍需实际画面验证；不能把条件画面说成每帧都显示。','', '## 分类数量','', '| 分类 | 数量 |','|---|---:|']
    md += [f'| {k} | {v} |' for k,v in report['classification_counts'].items()]
    md += ['',f'扫描期间有 {sum(a["changed_during_audit"] for a in assets.values())} 个媒体文件发生修改，JSON已标记，完成验收前应重跑这些条目。']
    md += ['', f'另有 **{len(upgrade_rows)} 张升级属性旧图**：UpgradeUI→ItemDescription→ItemParentData.get_icon→SkinManager形成显示链；无皮肤覆盖时返回原图。完整路径在JSON的`upgrade_icons_with_skin_override_condition`。不能忽略外部皮肤PCK/设置条件。证据：'+ '；'.join(f'`{r["file"]}:{r["line"]}`' for r in upgrade_chain)+'.']
    md += ['', '## 模型队列的具体范围缺口','']
    for gap in gaps:
        md.append('- `'+gap['identity']+'`：已注册的DLC拾取物未在当前模型队列中。需加入全美术范围并触发验证毒性/诅咒警示及拾取后UI；不能把260当全集上限。证据：'+'；'.join(f'`{r["file"]}:{r["line"]}`' for r in gap['evidence'])+'.')
    md += ['', '## 下一批显示接线复核（最多40个，完整列表见JSON）','', '这些条目已经存在显示属性或UI引用，但尚未证明当前模式一定经过该界面。先按证据行检查，不要全局替换。','', '| 路径 | 首个显示证据 | 已有替代映射 |','|---|---|---|']
    candidates=[a for a in report['assets'] if a['classification']=='legacy_display_binding_needs_route_review']
    for a in candidates[:40]:
        r=(a['direct_display_references']+a['data_icon_references'])[0]
        md.append(f'| `{a["path"]}` | `{r["file"]}:{r["line"]}` | '+(', '.join('`'+x['target']+'`' for x in a['replacement_maps']) or '无')+' |')
    md += ['', '## 防止误替换的执行门槛','', '- 战斗2D图：先检查实例确在battle_3d隐藏的源容器内，再查纹理尺寸、出生动画、F8兼容使用。`weapons/weapon.gd`仍用纹理尺寸设置轮廓材质；禁止按“旧PNG”一键替换全部战斗纹理。','- 原路径已修改：按`in_place_changed_asset_needs_visual_review`查看真实文件，不能误报启动图/应用图标仍是原图。','- 原标题背景：`TowerDefenseRules.ENABLED`为true，标题函数提前加载新title_data并return；旧标题静态引用需检查是否仅其他模式可达。','- 道具与肖像：数据`icon`接线和运行时`texture = data.icon`需一起追踪，逐选人、商店、图鉴、死亡来源、奖励弹窗取证。','- 动态路径：JSON的`dynamic_references`记录变量load和texture/icon赋值。先定位触发界面与数据身份，禁止猜测最终文件名。','- 完成门槛：每个默认/条件可达显示面需有替代资源、触发步骤和运行截图；每项保留的旧图需有逻辑尺寸/默认隐藏或兼容用途证据；媒体文件视觉质量必须另验。','', '## 动态UI赋值优先检查','']
    for r in [r for r in dynamic if r['file'].startswith(('gdproj/ui/','gdproj/singletons/cursor'))][:35]:
        md.append(f'- `{r["file"]}:{r["line"]}` — `{r["code"].replace("`", "")}`')
    (ROOT/'docs/current-art-audit.md').write_text('\n'.join(md)+'\n',encoding='utf-8')
    print(json.dumps({'files':len(files),'assets':len(assets),'categories':report['classification_counts'],'dynamic':len(dynamic),'code_proven_conditional_residuals':len(confirmed)},ensure_ascii=False))

if __name__=='__main__': main()
