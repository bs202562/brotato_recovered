"""Evidence overlay for remaining static display candidates, never deletion approval."""
import json
from pathlib import Path
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
audit=json.loads((ROOT/'docs/current-art-audit.json').read_text(encoding='utf-8'))
rows=[]
for asset in audit['assets']:
 if asset['classification']!='legacy_display_binding_needs_route_review':continue
 path=asset['path'];route='unresolved_route';reason='Static display or data binding only; no claim of visual completion.';evidence=[]
 if any('/title_screen/' in ref['file'] for ref in asset['direct_display_references']):
  route='nondefault_title_branch';reason='TowerDefenseRules.ENABLED selects the new title and returns before original keyart selection. Preserve alternate-mode resources.'
  evidence=['gdproj/ui/menus/title_screen/title_screen.gd:93','gdproj/ui/menus/title_screen/title_screen.gd:96']
 elif any('/menu_credits.tscn' in ref['file'] for ref in asset['direct_display_references']):
  route='retained_author_attribution';reason='Original creator identities are legitimate credits, not battle-character art to replace.'
 elif any('/debug_menu.tscn' in ref['file'] for ref in asset['direct_display_references']):
  route='debug_menu_only_candidate';reason='Binding located in debug menu; not exercised by default pause/upgrade screens. No debug actions executed.'
 elif path=='res://entities/units/player/highlight.png':
  route='hidden_old_character_detail_source';reason='CharacterPanelUI hides CharacterAnimation, stops old animation and creates independent 3D preview; paused default/doctor and actual weapon-page screenshots verified.'
  evidence=['gdproj/ui/menus/ingame/character_panel_ui.gd:39','docs/character-detail-3d-review.md']
 elif 'evil_mob_swimmer_icon' in path:
  route='stats_icon_without_proven_display_route';reason='DLC item uses new evil_mob icon, old swimmer stats used for numeric descriptions. Live swimmer scene uses base evil_mob stats and enemy_id. _set_item_stat exists but has no located callers; no unique model demand inferred.'
  evidence=['gdproj/dlcs/dlc_1/dlc_data.tres:236','gdproj/dlcs/dlc_1/enemies/evil_mob_swimmer/evil_mob_swimmer_item.tres:4','gdproj/dlcs/dlc_1/enemies/evil_mob_swimmer/evil_mob_swimmer.tscn:6','gdproj/entities/units/ItemEntity.gd:13','gdproj/ui/menus/pages/killed_by_container.gd:28']
 elif 'corrupted_tree_icon' in path:
  route='unproven_spawn_route';reason='Stats icon referenced by corrupted_tree scene, but no normal spawn reference or enemy_id established. items_test and reused pivot script do not establish this enemy is spawned.'
  evidence=['gdproj/entities/units/enemies/corrupted_tree/corrupted_tree.tscn:8','gdproj/items_test.tscn:79']
 elif 'bullet_environment' in path:
  route='combat_projectile_review_not_ui_replacement';reason='BulletHell scene texture can affect combat dimensions. Do not replace based on UI audit; bullet-hell death recap already uses separate new UI art.'
  evidence=['gdproj/ui/menus/pages/killed_by_container.gd:20']
 elif 'knuckles_icon' in path:
  route='weapon_data_and_test_scene_coordinate_with_producer';reason='Weapon icon data and items_test binding; weapon producer owns final identity rendering. No blanket replacement here.'
 rows.append({'path':path,'route':route,'reason':reason,'evidence':evidence,'original_references':asset['references'],'visual_acceptance':'not_granted_by_route_overlay'})
counts={}
for row in rows:counts[row['route']]=counts.get(row['route'],0)+1
out={'recorded_utc':datetime.now(timezone.utc).isoformat(),'audit_finished_utc':audit['finished_utc'],'counts':counts,'rows':rows,'runtime_checks':{'pause':'docs/agent-actual-pause-review-final.log','upgrades':'docs/agent-actual-upgrades-review.log','notice':'docs/agent-actual-notice-review.log'},'limits':'Runtime texture/icon scan excludes StyleBox/shader/internal resource textures and only covers these initialized states. Static unreferenced assets are not deletion candidates.'}
(ROOT/'docs/current-art-route-review.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
md=['# 剩余显示引用的路由证据','',f'记录时间 {out["recorded_utc"]}；对应审计 {audit["finished_utc"]}。这是证据分层，不是视觉验收或删除许可。','', '| 路由 | 数量 |','|---|---:|']
md += [f'| {key} | {value} |' for key,value in counts.items()]
md += ['','逐路径来源/行号保存在 current-art-route-review.json。真实暂停、升级和公告页的可见节点 Texture/Icon 扫描均为无旧路径；它不覆盖 StyleBox、shader、另选道具或其他条件状态。','', '本批实际修复：公告400px图示、区域初始标记/未选加号、属性初始标记、时间线圆点，仅改四个 UI 场景；再补实际暂停页发现的96px curse小图。战斗共享粒子PNG和其他引用未变。','', '泳者/腐化树没有因此新增身份或生产项；原署名标识保留。','', '| 路径 | 分类 |','|---|---|']
md += [f'| `{r["path"]}` | {r["route"]} |' for r in rows]
(ROOT/'docs/current-art-route-review.md').write_text('\n'.join(md)+'\n',encoding='utf-8')
print(counts)
