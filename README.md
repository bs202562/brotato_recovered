# Brotato 恢复工程

游戏工程集中在 `gdproj/`，学习文档保留在 `docs/`。

```text
Brotato_recovered/
├── gdproj/                     Godot 游戏工程根目录
│   ├── project.godot           在 Godot 中导入／打开此文件
│   ├── main.gd / main.tscn     主场景与逻辑
│   ├── items/                 角色、道具、套装、升级与难度配置
│   ├── weapons/               武器逻辑与数值资源
│   ├── entities/              玩家、敌人及其他实体
│   ├── effects/               效果定义
│   ├── effect_behaviors/      效果行为
│   ├── singletons/            全局服务与局内数据
│   ├── global/                管理器
│   ├── ui/                    界面
│   ├── zones/                 地图与波次
│   ├── dlcs/                  DLC 资源与逻辑
│   ├── resources/             字体、音频、翻译等资源
│   ├── addons/                插件
│   ├── tools/                 游戏开发与测试工具
│   ├── .assets/               恢复出的源资源
│   ├── .autoconverted/        自动转换资源
│   └── .import/               现有导入资源
└── docs/
    └── game_design/           技能与数值学习手册、图鉴及生成脚本
```

其他运行资源、图标、场景、脚本、恢复日志和项目配置备份也位于 `gdproj/`。游戏内部目录层级保持原样，`res://` 现在对应 `gdproj/`。

- 游戏入口：[gdproj/project.godot](gdproj/project.godot)
- 学习手册：[离线阅读版](docs/game_design/Brotato_技能与数值设计手册.html)
- 文档说明：[docs/game_design/README.md](docs/game_design/README.md)

在仓库根目录重新生成图鉴：

```powershell
python docs/game_design/build_reference.py
```

目录迁移保留了原有文件内容和已有本地修改；未自动提交或重新暂存 Git 更改。原先导入根目录项目的 Godot 编辑器需要改为打开 `gdproj/project.godot`。
