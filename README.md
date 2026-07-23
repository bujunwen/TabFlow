# TabFlow

轻量、窗口级的 macOS `Command + Tab` 切换器。

## 当前功能

- 同一应用的每个窗口单独参与切换
- 按窗口最近使用顺序排列
- 按住 `Command`，重复按 `Tab` 向下选择，松开 `Command` 切换
- 纯文字列表，无缩略图、鼠标选择和额外动画
- 支持当前屏幕或所有屏幕
- 支持最小化窗口
- 只考虑当前 Space
- 原生开机自动启动，可在菜单栏关闭
- 原生 Swift + AppKit，无第三方运行时依赖

## 构建与运行

```bash
make run
```

生成的应用位于：

```text
build/TabFlow.app
```

首次运行需要在“系统设置 → 隐私与安全性 → 辅助功能”中允许 TabFlow。

## 使用

- `Command + Tab`：呼出并选中上一个窗口
- 按住 `Command`，继续按 `Tab`：向下选择
- 松开 `Command`：切换到选中窗口
- 菜单栏图标：选择“仅当前屏幕”或“所有屏幕”，以及开关“开机自动启动”

## 开发

这是 Swift Package 项目，可直接使用 Xcode 打开 `Package.swift`。
