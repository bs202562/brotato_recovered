# 使用 VS Code 调试 Brotato

在 VS Code 中打开仓库根目录 `Brotato_recovered`，不要只打开 `gdproj`。调试配置位于根目录 `.vscode`，游戏项目路径已设为 `${workspaceFolder}/gdproj`。

本机已检测到 `godparty.godparty-godot-tools` 0.1.4 扩展和 Godot 3.6.3 自定义构建。配置按这个扩展实际声明的 Godot 3 调试字段编写，未启用 Godot 4 专用协议。

## 启动和断点

1. 打开 `gdproj` 中的 `.gd` 文件，点击代码行左侧添加断点。
2. 按 `Ctrl+Shift+D` 打开“运行和调试”。
3. 选择 `Brotato：启动游戏（Godot 3）`，按 `F5`。
4. 游戏执行到断点时，可查看变量、调用堆栈及监视表达式。使用 `F10` 单步跳过、`F11` 单步进入、`Shift+F11` 跳出，`F5` 继续，`Shift+F5` 停止。

启动配置的 `scene: main` 表示使用 `project.godot` 的 `run/main_scene`，并非硬编码打开 `main.tscn`。当前主场景为 `res://pause.tscn`，因此调试启动遵循游戏本身的入口流程。

| 调试入口 | 用途 |
| --- | --- |
| 启动游戏 | 按完整入口运行，适合角色、战斗、商店逻辑断点 |
| 调试当前场景 | 先在 VS Code 中打开目标 `.tscn` 文件；从该场景运行 |
| 启动游戏并显示碰撞形状 | 观察攻击区域、受击区域、拾取范围等碰撞形状 |

单独运行场景仍需满足场景自身的初始化要求。依赖角色选择、局内数据或父场景的节点不一定能独立运行，遇到此类问题优先使用完整游戏入口。

## 引擎位置与代码补全

三个入口统一读取 `.vscode/settings.json` 的 `godotTools.editorPath.godot3`。现有路径为：

```text
D:\devlib\godot\godot-debug-v2\bin\godot.windows.opt.tools.64.exe
```

更换电脑或引擎位置时，只需修改这一项。调试类型 `godot` 由扩展提供；若提示不支持该类型，请检查工作区中的 Godot Tools 扩展是否启用。不要同时启用多个提供同名调试类型的 Godot Tools 分支。

需要 Godot 编辑器提供语言服务时，执行菜单“终端 → 运行任务 → Brotato：打开 Godot 3 编辑器”，并保持编辑器打开。这个任务独立于 F5，没有设为调试前置任务，避免等待编辑器退出而阻塞游戏启动。

## 排查

- 断点未命中：确认使用 F5 启动了调试配置、断点所在代码确实执行，并且文件属于当前 `gdproj`；仅从 Godot 编辑器普通运行游戏不等同于启动 VS Code 调试会话。
- 6007 端口被占用：停止其他调试会话，或同时调整相关调试配置的 `port`。如果 Godot 编辑器占用了该端口，可以先关闭编辑器，单独使用 VS Code 启动调试。
- 找不到引擎：检查 `godotTools.editorPath.godot3` 指向的是实际存在的 Godot 3 编辑器可执行文件。
- 游戏启动时报脚本错误：查看调试控制台和游戏输出；调试配置不会修复恢复工程本身的脚本或资源错误。

本次已检查引擎版本、扩展配置字段和路径；未实际执行 VS Code 的 F5 断点会话。
