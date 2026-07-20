# Silver Noir for Codex Desktop — Windows 安装包

**银夜黑金·夜冕**

此安装包包含偏贵族绅士风格的完整银夜黑金皮肤：

- 黑金背景图与构图参数
- 黑金按钮、输入框、弹窗和顶部导航样式
- Codex 原生深色外观导入参数
- 兼容 Codex 原生导入生成的嵌套 `config.toml` 表
- Dream Skin 启动、托盘、恢复和主题切换脚本

## 安装

1. 解压 ZIP，不能直接在压缩包预览窗口中运行。
2. 在解压目录打开 PowerShell，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-silver-noir.ps1 -StartNow
```

安装程序可以安全地重复运行。已有托盘会自动停止并在更新后重启，无需手动退出；如果 Codex 正在运行，确认后会自动关闭、完成安装并以 Dream Skin 重新打开。取消确认不会修改配置。

## 只安装，不立即启动

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-silver-noir.ps1
```

Codex 原本关闭时，安装完成后仍保持关闭，之后可双击桌面的 `Codex Dream Skin`；Codex 原本运行时，安装完成后会自动重新打开。

## 不创建快捷方式

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-silver-noir.ps1 -NoShortcuts -StartNow
```

## 两个快捷方式的作用

- `Codex Dream Skin`：日常启动入口，负责建立本地调试会话、启动皮肤注入，并自动启动任务栏通知区域中的托盘控制。
- `Codex Dream Skin - Restore`：独立恢复入口，负责停止托盘与皮肤注入、结束本地调试会话，并恢复安装前记录的 Codex 外观相关配置。

## 恢复 Codex

双击桌面的 `Codex Dream Skin - Restore` 快捷方式，或使用托盘菜单中的“完全恢复 Codex”。
恢复操作会移除 Dream Skin 注入并恢复安装前保存的 Codex 外观设置；已保存的皮肤文件仍留在
`%LOCALAPPDATA%\CodexDreamSkin\themes`，方便以后重新使用。

## 原生主题与完整皮肤的区别

`native-theme` 文件夹中的 `codex-theme-v1` 导入串只包含 Codex 原生颜色、字体和代码主题。
完整的背景图、布局、按钮、输入框和弹窗样式需要本安装包中的 Dream Skin 运行时。

该文件夹仅保留两份格式统一、可直接导入的 `.txt` 文件：

- `silver-noir-dark.codex-theme.txt`：银夜黑金深色主题
- `codex-default-dark-backup.codex-theme.txt`：Codex 默认深色恢复主题
