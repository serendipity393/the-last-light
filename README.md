# 最后一盏灯

一款离线游玩的原创 3D 剧情冒险短篇。你将作为回乡的灯塔维修员，在暴雨海港中借助能照见记忆的回声灯探索、潜行并解开机关。游戏包含四章、六段可收集记忆和两个结局。

**Windows 免安装版：**前往 [GitHub Releases](https://github.com/serendipity393/the-last-light/releases/latest) 下载 `The-Last-Light-Windows-x64.zip`，完整解压后双击 `最后一盏灯.exe`。无需安装 Godot 或联网，运行时需要支持 OpenGL 3.3 的显卡。

## 操作

| 按键 | 功能 |
| --- | --- |
| WASD | 移动 |
| 鼠标 | 灯光朝向 |
| 按住鼠标右键 | 使用回声灯，显现隐藏线索 |
| E | 交互、推进对白 |
| 空格 / 鼠标左键 | 推进对白 |
| Shift | 慢行，降低被发现范围 |
| Q | 投掷声音诱饵 |
| H | 逐级提示 |
| J | 查看手记 |
| Esc | 暂停 / 退出机关 |
| F11 | 窗口 / 全屏 |

## 从源码构建

工程位于 `source`，使用 Godot 4.4.1 Standard 与 GDScript，Compatibility / OpenGL 3.3 渲染，不依赖第三方 Godot 插件。

1. 从 [Godot 4.4.1 官方归档](https://godotengine.org/download/archive/4.4.1-stable/) 下载 Windows x86_64 Standard 编辑器，将压缩包解压到 `tools/godot`。构建脚本需要 `Godot_v4.4.1-stable_win64_console.exe`；编辑器为 `Godot_v4.4.1-stable_win64.exe`。
2. 从同一官方归档下载 Windows Export Templates。按 Godot 文档安装后，将 `windows_release_x86_64.exe` 放在 `tools/templates/windows_release_x86_64.exe`。模板用于导出，未随源码仓库分发。
3. 在 Windows PowerShell 运行 `source/build.ps1`。该脚本会把引擎导入缓存和临时文件写入本项目 `artifacts`；它还需要 Node.js 与 MinGW-w64（`gcc`、`windres`）来重新编译 Win32 启动器。
4. 可直接用 Godot 打开 `source/project.godot` 编辑与运行。逻辑回归参数为 `--headless --path source -- --self-test`；实际移动流程回归参数为 `--headless --path source -- --walkthrough`。

引擎下载、导出模板和编译工具不放在 Git 仓库中。官方引擎及其第三方组件许可见 [GODOT_COPYRIGHT.txt](GODOT_COPYRIGHT.txt) 和 [THIRD-PARTY.md](THIRD-PARTY.md)。

## 许可

本项目原创代码、故事、程序化美术和合成音频按 [MIT License](LICENSE.txt) 开源。Godot Engine 和其组件保留各自许可；Windows 字体由系统提供，未将字体文件打包进工程。

## 范围说明

本作是体量有限的独立短篇，以程序化微缩场景呈现雨夜海港。没有完整角色配音、多人、手柄、移动端或 macOS/Linux 版本。30–45 分钟是首次探索的设计目标，未经过真人盲玩计时。