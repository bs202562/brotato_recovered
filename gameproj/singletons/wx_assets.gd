extends Node

# 微信小游戏资源外置——运行时下载/注入管理器（自动加载单例 WxAssets）
#
# 背景：完整 Brotato 的 pck 达 195MB，远超微信小游戏 30MB 代码包上限。构建期把音乐等大资源
# 从 pck 里抽出、替换为占位（见 tools_extern/externalize-music.js），运行时按需从服务器下载
# 真实字节再注入。本单例负责运行时这一半。
#
# 链路：GDScript --(JavaScript.eval)--> 宿主 GameGlobal.wxDownloadAsset(wx.downloadFile)
#       --> GameGlobal.godotWriteUserFile(FS.writeFile 写进引擎 FS 的 user://)
#       --> 本单例 _process 轮询 File.file_exists 就绪 --> emit audio_ready --> 使用方加载
#
# 非 HTML5（桌面/编辑器）无 JavaScript 单例，get_audio_stream 原样返回传入资源（占位静音），
# 便于回归；真机/小游戏才走下载。桌面要听真音乐请先 `node externalize-music.js --restore`。

signal audio_ready(res_path)

# 本地 dev 资源服务器地址（开发者工具需勾选“不校验合法域名”）。上架换正式 HTTPS 域名。
const ASSET_BASE_AUDIO := "http://192.168.1.31:8666/audio/"
const ASSET_BASE_PACKS := "http://192.168.1.31:8666/packs/"

var _manifest := {"audio": {}}
var _cache := {}           # hash -> AudioStreamMP3（已注入内存）
var _requested := {}       # abs_path -> true，下载去重
var _pending := {}         # res_path -> hash，等待就绪
var _js = null             # JavaScript 单例（仅 HTML5）
var _user_dir := ""        # OS.get_user_data_dir() 绝对路径，喂给宿主避免 user:// 映射猜测
var _poll_accum := 0.0

# overlay（贴图/字体/音效）——分块 pck，下载后 load_resource_pack(replace=true) 覆盖占位
var _packs := []           # [{file, hash, size}]
var _mounted := {}         # file -> bool（挂载结果）
var overlay_ready := false


# overlay 必须在 _init 里挂载，不能等 _ready！
# Godot 3 的 Main::start() 是【先把所有 autoload 全部加载+实例化完，再统一 add_child】，
# 而 _ready 只在 add_child 时触发。也就是说所有 autoload 在"加载阶段"通过 preload/常量
# 拉进来的资源，全都发生在任何一个 _ready 之前。资源一旦进了 ResourceCache 就按路径钉死，
# 之后再 load_resource_pack 也换不掉——表现为部分贴图永远停在 1x1 占位（敌人看不见）。
# WxAssets 是 autoload #2，它的 _init 在加载循环里执行，早于 #3 之后所有 autoload 被加载。
func _init() -> void:
	_user_dir = OS.get_user_data_dir()
	var d := Directory.new()
	d.make_dir_recursive("user://audiocache")
	d.make_dir_recursive("user://packs")
	d.make_dir_recursive("user://logs")  # CrashReporter/ModLoader 写日志的目录，缺则报 store_string 错
	d.make_dir_recursive("user://user")  # 存档目录
	_load_manifest()
	_packs = _manifest.packs if _manifest.has("packs") else []
	_start_overlay()


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	if Engine.has_singleton("JavaScript"):
		_js = Engine.get_singleton("JavaScript")


func _load_manifest() -> void:
	var f := File.new()
	if f.file_exists("res://asset_manifest.json"):
		var err := f.open("res://asset_manifest.json", File.READ)
		if err == OK:
			var parsed = JSON.parse(f.get_as_text())
			f.close()
			if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
				_manifest = parsed.result
				if not _manifest.has("audio"):
					_manifest["audio"] = {}
	print("[WxAssets] manifest 音乐条目 ", _manifest.audio.size(), "，JS桥=", _js != null, "，user_dir=", _user_dir)


# ---------- overlay（贴图/字体/音效覆盖挂载）----------

func _start_overlay() -> void:
	if _packs.empty():
		overlay_ready = true
		return
	# 微信禁 eval，下载由宿主(loader.js)在启动前完成并经 preloadUserFiles 恢复进 FS。
	# 这里只负责【同步挂载】——WxAssets 是自动加载 #2，早于加载贴图的 ItemService 等单例，
	# 挂载后它们首次加载即命中真实资源，无占位缓存问题。
	var f := File.new()
	var missing := 0
	for pk in _packs:
		if f.file_exists("user://packs/%s" % pk.file):
			_mount_pack(pk.file)
		else:
			missing += 1
			print("[WxAssets] overlay 分块缺失（宿主未下到）: ", pk.file)
	# 缺失的分块对应贴图退化为占位，但不阻塞启动
	overlay_ready = true
	var ok_count := 0
	for file in _mounted:
		if _mounted[file]:
			ok_count += 1
	print("[WxAssets] overlay 挂载成功 ", ok_count, "/", _packs.size(), " 块，缺失 ", missing)
	_verify_overlay()


# 自检：overlay 生效与否，看 res://.import/ 的实际字节数就能一眼分辨。
# 构建期源图被替换成 1px png / 静音 wav，base pck 里的 .import 产物总共只有 ~0.2MB；
# overlay 挂载成功后同名路径被真实产物覆盖，应为几十 MB。若仍是 0.x MB，说明贴图
# 全部退化为占位——表现就是"怪物看不见、角色动画不对"。
func _verify_overlay() -> void:
	var d := Directory.new()
	if d.open("res://.import") != OK:
		print("[WxAssets] 自检: 打不开 res://.import")
		return
	var f := File.new()
	var total := 0
	var n := 0
	var real_n := 0
	d.list_dir_begin(true, true)
	var name := d.get_next()
	while name != "":
		if name.ends_with(".stex") or name.ends_with(".sample"):
			n += 1
			if f.open("res://.import/" + name, File.READ) == OK:
				var sz := f.get_len()
				f.close()
				total += sz
				if sz > 2048:  # 1px png/静音 wav 的产物远小于此
					real_n += 1
		name = d.get_next()
	d.list_dir_end()
	var ok_count := 0
	for file in _mounted:
		if _mounted[file]:
			ok_count += 1
	# 塞进 [perf] 每行输出——WxAssets 自己的 print 在小游戏控制台里不知为何不显示，
	# 而 [perf] 行是能稳定看到的，把结论挂上去才不会漏。
	_overlay_status = "overlay=%d/%d块 真实=%d/%d(%.0fMB)%s" % [
		ok_count, _packs.size(), real_n, n, total / 1048576.0,
		"" if total > 20 * 1048576 else " ←占位!",
	]
	print("[WxAssets] 自检: ", _overlay_status)
	# 再直接验两张对照图：挂载后立刻 load，尺寸不是 1x1 才算对具体资源真的生效。
	# （这里 load 会把它们以真实版本写进 ResourceCache，属于顺带的好处）
	for p in ["res://entities/units/enemies/chaser/chaser.png", "res://entities/units/player/potato.png"]:
		var t = load(p)
		print("[WxAssets] 挂载后 load %s → %s" % [
			p, "null" if t == null else "%dx%d" % [t.get_width(), t.get_height()],
		])


func _mount_pack(file: String) -> void:
	if _mounted.has(file):
		return
	# replace=true：按相同 res:// 路径覆盖 base pck 里的占位资源
	var ok = ProjectSettings.load_resource_pack("user://packs/%s" % file, true)
	_mounted[file] = ok
	if not ok:
		print("[WxAssets] 挂载失败 ", file)


# 供启动门显示进度：[已挂载, 总数]
func overlay_progress() -> Array:
	return [_mounted.size(), _packs.size()]


# 传入一个 AudioStream（可能是占位），返回可播放的真实流：
#   - 未外置（不在 manifest）→ 原样返回
#   - 已缓存/已下载 → 真实 AudioStreamMP3
#   - 未就绪 → 触发下载并返回 null（就绪后经 audio_ready 信号通知）
func get_audio_stream(track):
	if track == null:
		return null
	var res_path: String = track.resource_path
	if not _manifest.audio.has(res_path):
		return track
	var fhash: String = _manifest.audio[res_path].hash
	if _cache.has(fhash):
		return _cache[fhash]
	var user_local := "user://audiocache/%s.mp3" % fhash
	var f := File.new()
	if f.file_exists(user_local):
		var stream = _load_mp3(user_local)
		if stream:
			_cache[fhash] = stream
			return stream
	# 未就绪：触发下载 + 登记等待
	_pending[res_path] = fhash
	_request_download(fhash)
	return null


func _load_mp3(user_local: String):
	var f := File.new()
	if f.open(user_local, File.READ) != OK:
		return null
	var bytes := f.get_buffer(f.get_len())
	f.close()
	if bytes.size() == 0:
		return null
	var s := AudioStreamMP3.new()
	s.data = bytes
	return s


# 微信禁 eval，无法从 GDScript 直接调宿主。改用【文件桥】：把待下载请求写进
# user://.wxreq.json，宿主(asset-loader.js)轮询该文件、下载后写回引擎 FS，GDScript 轮询就绪。
func _request_download(fhash: String) -> void:
	if _js == null:
		return  # 非 HTML5，无法下载
	var abs_path := "%s/audiocache/%s.mp3" % [_user_dir, fhash]
	if _requested.has(abs_path):
		return
	_requested[abs_path] = {"url": ASSET_BASE_AUDIO + fhash + ".mp3", "path": abs_path}
	_write_requests()


func _write_requests() -> void:
	var arr := []
	for k in _requested:
		arr.append(_requested[k])
	var f := File.new()
	if f.open("user://.wxreq.json", File.WRITE) == OK:
		f.store_string(to_json(arr))
		f.close()


# ---------- 性能采样（排查小游戏卡顿用，定位完把 PERF_LOG 改回 false）----------
# 注意：Godot 3 的 GLES2 光栅器不填 RENDER_DRAW_CALLS_IN_FRAME（恒 0），绘制调用数
# 改由宿主侧 loader.js 的 GL 计数器给出（[gl] 日志）。
#
# 这里统计【窗口内】的真实值而非瞬时值——瞬时 fps 会把卡顿完全漏掉：
#   均帧率低 + 最差帧大（>100ms）  → 有周期性长卡顿，看是哪一帧在做重活
#   均帧率低 + 最差帧接近平均      → 均匀慢，纯吞吐瓶颈（配合 [gl] 看是不是 GL 调用量）
#   进程/物理 时间高               → CPU 瓶颈在 GDScript
const PERF_LOG := true
const PERF_INTERVAL := 2.0
var _perf_accum := 0.0
var _perf_frames := 0
var _perf_worst := 0.0
var _overlay_status := "overlay=未自检"


func _perf_tick(delta: float) -> void:
	_perf_frames += 1
	if delta > _perf_worst:
		_perf_worst = delta
	_perf_accum += delta
	if _perf_accum < PERF_INTERVAL:
		return
	var vp := get_viewport()
	print("[perf] %s 均帧率=%.1f 最差帧=%.0fms 进程=%.1fms 物理=%.1fms 节点=%d 对象=%d 显存=%.1fMB 视口=%s 时间缩放=%.2f" % [
		_overlay_status,
		_perf_frames / _perf_accum,
		_perf_worst * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		str(vp.size) if vp != null else "?",
		Engine.time_scale,
	])
	_perf_accum = 0.0
	_perf_frames = 0
	_perf_worst = 0.0


# ---------- 实体可见性探针（排查"怪物看不见"，定位完把 ENTITY_PROBE 改回 false）----------
# 由 entity.gd 的 init() 延迟一帧调用。敌人和掉落物是同一个基类 Entity，两者都会被打印，
# 可以直接对比"看得见的物品"和"看不见的敌人"在哪一项上不同。
const ENTITY_PROBE := true
const ENTITY_PROBE_MAX := 12
var _probe_n := 0


func probe_entity(e) -> void:
	if not ENTITY_PROBE or _probe_n >= ENTITY_PROBE_MAX:
		return
	if not is_instance_valid(e):
		return
	_probe_n += 1
	var sp = e.get_node_or_null("Animation/Sprite")
	if sp == null:
		print("[probe] %s ← 没有 Animation/Sprite 子节点" % e.name)
		return
	var tex_desc := "null"
	if sp.texture != null:
		tex_desc = "%dx%d %s" % [sp.texture.get_width(), sp.texture.get_height(), sp.texture.resource_path]
	print("[probe] %s 贴图=%s sp可见=%s 实体可见=%s alpha=%.2f sp缩放=%s 父缩放=%s z=%d 材质=%s 位置=%s" % [
		e.name, tex_desc, sp.visible, e.visible, sp.modulate.a,
		str(sp.scale), str(sp.get_parent().scale), sp.z_index,
		("有" if sp.material != null else "无"), str(e.global_position),
	])


func _process(delta: float) -> void:
	if PERF_LOG:
		_perf_tick(delta)
	if _pending.empty() and overlay_ready:
		return
	_poll_accum += delta
	if _poll_accum < 0.3:
		return
	_poll_accum = 0.0
	var f := File.new()
	# 音乐：宿主(asset-loader.js)下载完会把文件写进 FS，这里轮询就绪并发信号
	var ready_paths := []
	for res_path in _pending.keys():
		var fhash: String = _pending[res_path]
		if f.file_exists("user://audiocache/%s.mp3" % fhash):
			ready_paths.append(res_path)
	for res_path in ready_paths:
		_pending.erase(res_path)
		emit_signal("audio_ready", res_path)


# 把字符串转成 JS 字面量（含引号），供 eval 拼接
func _js_str(s: String) -> String:
	return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
