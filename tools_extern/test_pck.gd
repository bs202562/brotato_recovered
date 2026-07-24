extends SceneTree

# 验证 Node 手写的 overlay pck 能否被 load_resource_pack 接受，并能否取出真实资源。
# 用法：Godot --no-window --script tools_extern/test_pck.gd -- <pck绝对路径> <pck内res路径>
func _init():
	var args = OS.get_cmdline_args()
	var pck_path = ""
	var res_path = ""
	# 取 -- 之后的两个参数
	var after = false
	for a in args:
		if a == "--":
			after = true
			continue
		if after:
			if pck_path == "":
				pck_path = a
			elif res_path == "":
				res_path = a
	print("== 测试 pck: ", pck_path)
	print("== 目标资源: ", res_path)
	var ok = ProjectSettings.load_resource_pack(pck_path, true)
	print("== load_resource_pack -> ", ok)
	if ok and res_path != "":
		var f = File.new()
		print("== File.file_exists(", res_path, ") -> ", f.file_exists(res_path))
		var r = ResourceLoader.load(res_path)
		print("== ResourceLoader.load -> ", r)
		if r != null and r is Texture:
			print("== Texture 尺寸: ", r.get_size())
	quit()
