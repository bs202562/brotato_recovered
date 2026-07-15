# ============================================================
# 调试用视口截帧工具
#
# 挂在 Viewport 节点上。按住 "ui_ban" 输入动作期间，把该视口
# 每一帧的画面导出为 PNG 序列（保存在 user:// 目录下），
# 主要供开发时录帧 / 导出素材使用，正常游玩不会触发。
# ============================================================
extends SubViewport

@export var file_name: String  # 导出文件名前缀
var frame_index: int = 0  # 已保存的帧序号（用于文件名 6 位编号）

func _process(delta):
	if Input.is_action_pressed("ui_ban"):
		# 抓取当前视口纹理，保存为 user://<前缀>_000000.png 这样的序列帧
		# 4.x 移植: get_data() 改名 get_image()
		var capture = get_texture().get_image()
		var file_path = "user://" + file_name + "_" + str(frame_index).pad_zeros(6) + ".png"
		capture.save_png(file_path)

		frame_index += 1
