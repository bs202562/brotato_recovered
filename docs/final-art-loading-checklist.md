# 待最终统一加载阶段处理的美术接口

用户当前要求先生成全部资源，最后统一加载验证。本清单不代表已运行测试，也不修改模型生产验收状态。

## Minigun 修正版的多管轮廓（离线几何已修正 / 待引擎验证）

`weapon_minigun_1500_v2.glb` 已去掉首版的支柱底板，但离线三视图显示突出中央单管，前端多管簇仍不够清楚（`root-minigun-v2-components.png`）。原件及修正版均保留，不再立即付费生成第三版。

- [x] 已生成 `weapon_minigun_1500_multibarrel.glb`（1483 三角面）：保留枪身原材质与嵌入贴图，截除单管前端，替换为六根等长有内孔枪管及固定箍；不是直接叠加在旧突出单管上。三视图 `root-minigun-multibarrel-components.png` 已看，截断边缘半径小于密封套筒内接半径，局部修正未额外消耗积分。
- [ ] 最终检查四档图标、实际发射端点、枪体朝向、俯视轮廓和旧模型清理。当前只是离线派生候选，不计完整视觉验收。

## BuilderTurret 四档外观（待实施 / 待验证）

证据：`gdproj/entities/structures/turret/builder/builder_turret.gd:176–179、276–280` 真实 `_current_level` 更新并选择 `turret_sprites[_current_level]`。截至 2026-09-07，combat3d 没有对应字段观察分支；隐藏源 Sprite 后四档原外观差异可能丢失。

- [ ] 在同一独立 builder_turret 模型上观察真实 `_current_level=0/1/2/3`，以附加装甲、可数级别灯/标记等纯视觉方式区分四档。不得修改 XP 阈值、structure_range、武器复制、伤害、冷却或升级概率。
- [ ] 用真实 BuilderTurret 初始化和升级入口触发四档；不要只给独立视觉节点手写 metadata。记录实际字段值、原选择纹理、3D 标记与截图对应关系。
- [ ] 检查等级变化后旧标记不重复累积；代理回收/重建后恢复正确档位；低档新对象不继承前一个高档标记。
- [ ] 检查真实炮塔朝向、F8、隐藏/死亡及波后清理仍正确，标记不遮住炮口或误成弹体。
- [ ] 四档几何使用引擎附加体；**不额外付费生成四个模型**。最终验收记录应清楚区分完整 GLB 与引擎级别表现。

来源审计：[batch 6–10 brief 审计](model-batches-6-10-brief-review.md)。当前只完成源码定位，不声称已完成上述事项。

## Torch 新 GLB 适配复核（功能已实现，待新资产确认）

此前 TorchFlameArt 共享创建/动画接口、真实 emitter 位置/状态、F8 与换档已在旧模型通过独立测试；这里不将其重新记为未实施。

- [ ] 以新 torch GLB 实际包布头核对真实 `Sprite/Muzzle/BurningParticles` 投影位置和高度。图标局部头端记录约 `[0.33, 0.137, 0]`；战斗由真实 source emitter 驱动，不能直接假设图标坐标与战斗投影一致。
- [ ] 对新实体做旋转、品质切换、F8 后的火焰贴合检查；火焰不能落在木杆中部或脱离头端。
- [ ] 保留 curse 时原 Weapon 替换/移除枪口粒子的行为。确认旧火焰不存在时不会保留过期火焰，也不为了新模型私自恢复原逻辑移除的火。

## Ghost 系实体与原 aura / outline 层（待新资产保真复核）

- [ ] 实体使用不透明材质；对 ghost_flint、ghost_axe、ghost_scepter 的源场景核对独立 aura/outline Sprite 在 3D 模式是否已有对应表现，缺失才补纯视觉层。不要将纹理轮廓光误生成实体薄壳。
- [ ] 保留原翻转/显隐和等级语义；确认新模型下无原 2D 光圈漏出、重复或错误位置。`sprite_following_weapon.gd` 原先只同步翻转，不能把“有 aura 文件”当已验证 3D 覆盖。

## Catling 新 GLB 空双座适配（双炮功能已实现并通过旧模型验证）

- [ ] 新模型只有猫体和左右空枪座，不含固定枪管或中央炮塔；引擎 CatlingAimArt 两根独立枪正确各归一侧。
- [ ] 对真实左右目标、原 flip 分支及真实 `_left_muzzle/_right_muzzle` 出弹位置检查新模型枪座附近的连接关系；不得为让外观贴合而改原弹道或随机散射。
- [ ] 原初始诅咒→解除无重复状态节点、强化标记、动作身体分组已通过旧模型；只复核新 GLB 层级不破坏这些既有功能，不重写动作逻辑。

## 新批次清底座派生资源（待统一导入 / 验收）

- [ ] 确认移除的是生成展示底座，保留真实武器护手、炮塔支脚、完整杆柄与本体连接件；源 GLB 与派生 GLB 来源可追踪。
- [ ] 每个新身份检查实体完整、尺度、前向、握持端/枪口端；RIGHT 生产坐标与运行 local -Z/+X 按具体 Factory 接口映射，不全局套用一个旋转值。
- [ ] 派生资源的四档武器图标检查裁切、居中、材质、等级标记和必要共享 FX；不将四张图标当四个新模型。
- [ ] 最终真实战斗检查新实体姿态、攻击端位置、源隐藏/F8 与回收；已有旧模型通过的功能作为基线，只记录新资产带来的差异。

## Fireball / FlamingKnuckles / Wand 源持续火焰（源码证实存在，3D 对应待补查）

`weapons/melee/flaming_knuckles/flaming_knuckles.tscn:8、47–50` 与 `weapons/ranged/fireball/fireball.tscn:7、36–43` 都实例化真实 torch_burning_particles；`fireball.gd:6–10` 在 update_sprite 切 emitting。当前 `combat3d/torch_flame_art.gd:4` 仅接受 weapon_torch。

补充：`weapons/ranged/wand/wand.tscn:36–37` 同样实例化该真实 BurningParticles，亦需检查本体火焰。

- [ ] 在最终加载阶段确认两武器实体表面真实火焰是否缺失；已有发射火球/命中烧伤不能代替武器本体火焰。
- [ ] 如缺失，复用共享 TorchFlameArt 几何接口，以两者真实 emitter 状态和局部位置驱动，保留 Fireball 换图/冷却时的 emitting 翻转；不加第二套计时或改变烧伤规则。
- [ ] 同步需要点燃外观的武器图标；身体仍生成不带游离火焰的实体，不为火焰增加付费模型。curse 原粒子替换分支同样按真实状态处理。

## IronLung / Spiky_Lung 满载孵化状态（待实施 / 待验证）

`dlcs/dlc_1/enemies/iron_lung/iron_lung.gd` 与 `spiky_lung/spiky_lung.gd:34–44` 分别在真实检测区进入 stargazer / scaled_stargazer 时设置 is_full、换 full 纹理、300 tick 孵化冷却、消耗目标并 emit became_full。respawn:19–25 重置，生成子怪回调:28–31 后自身死亡。当前 combat3d 未找到这两个状态字段的对应观察，不能以旧 Sprite 已换图判定 3D 覆盖。

- [ ] 保留两个独立身份各自正常模型，观察真实 `is_full` 表达满载：例如呼吸舱状态灯、连接在壳上的内容标记或局部膨大；不添加额外付费满载模型。
- [ ] 真实检测入口分别使用正确 stargazer / scaled_stargazer，确认从未满→满载→真实生成子怪→源死亡的外观时序一致，伤害/血量/孵化时间和概率均不改。
- [ ] 原 `*_full.png` 的罩内生物/红框仅为源语义，不要求在新胸壳永久烘焙第二只完整怪物；模型生成不等待此状态实现。
- [ ] 回收 respawn 后清除满载标记；未满时原伙伴死亡的清理路径、魅惑归属、F8 和源隐藏按现有实际行为复核。
