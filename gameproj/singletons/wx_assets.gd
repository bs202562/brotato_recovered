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
const ASSET_BASE_AUDIO := "http://localhost:8666/audio/"
const ASSET_BASE_PACKS := "http://localhost:8666/packs/"

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


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	_user_dir = OS.get_user_data_dir()
	var d := Directory.new()
	d.make_dir_recursive("user://audiocache")
	d.make_dir_recursive("user://packs")
	if Engine.has_singleton("JavaScript"):
		_js = Engine.get_singleton("JavaScript")
	_load_manifest()
	_packs = _manifest.packs if _manifest.has("packs") else []
	_start_overlay()


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
	print("[WxAssets] manifest 音乐条目 ", _manifest.audio.size(), "，JS桥=", _js != null)


# ---------- overlay（贴图/字体/音效覆盖挂载）----------

func _start_overlay() -> void:
	if _packs.empty() or _js == null:
		# 非 HTML5 或无 overlay：不阻塞启动门
		overlay_ready = true
		return
	# 已缓存的直接挂载；未缓存的触发下载
	var f := File.new()
	for pk in _packs:
		var local = "user://packs/%s" % pk.file
		if f.file_exists(local):
			_mount_pack(pk.file)
		else:
			_request_pack_download(pk.file)
	_check_overlay_done()
	print("[WxAssets] overlay 分块 ", _packs.size(), "，开始下载/挂载")


func _mount_pack(file: String) -> void:
	if _mounted.has(file):
		return
	# replace=true：按相同 res:// 路径覆盖 base pck 里的占位资源
	var ok = ProjectSettings.load_resource_pack("user://packs/%s" % file, true)
	_mounted[file] = ok
	if not ok:
		print("[WxAssets] 挂载失败 ", file)


func _request_pack_download(file: String) -> void:
	if _js == null:
		return
	var abs_path := "%s/packs/%s" % [_user_dir, file]
	if _requested.has(abs_path):
		return
	_requested[abs_path] = true
	var url := ASSET_BASE_PACKS + file
	_js.eval("GameGlobal.wxDownloadAsset(%s, %s)" % [_js_str(url), _js_str(abs_path)], true)


func _check_overlay_done() -> void:
	for pk in _packs:
		if not _mounted.get(pk.file, false):
			return
	if not overlay_ready:
		overlay_ready = true
		print("[WxAssets] overlay 全部挂载完成（", _packs.size(), " 块）")


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


func _request_download(fhash: String) -> void:
	if _js == null:
		return  # 非 HTML5，无法下载
	var abs_path := "%s/audiocache/%s.mp3" % [_user_dir, fhash]
	if _requested.has(abs_path):
		return
	_requested[abs_path] = true
	var url := ASSET_BASE_AUDIO + fhash + ".mp3"
	# 调宿主下载桥（asset-loader.js）
	_js.eval("GameGlobal.wxDownloadAsset(%s, %s)" % [_js_str(url), _js_str(abs_path)], true)


func _process(delta: float) -> void:
	if _pending.empty() and overlay_ready:
		return
	_poll_accum += delta
	if _poll_accum < 0.3:
		return
	_poll_accum = 0.0
	var f := File.new()
	# overlay：挂载已下载但未挂载的分块
	if not overlay_ready:
		for pk in _packs:
			if not _mounted.has(pk.file) and f.file_exists("user://packs/%s" % pk.file):
				_mount_pack(pk.file)
		_check_overlay_done()
	# 音乐：就绪的曲目发信号
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
