# Silver Noir for Codex Desktop — Windows 安装包

**银夜黑金·星穹**

此安装包包含完整的银夜黑金皮肤：

- 黑金背景图与构图参数
- 黑金按钮、输入框、弹窗和顶部导航样式
- Codex 原生深色外观导入参数
- 兼容 Codex 原生导入生成的嵌套 `config.toml` 表
- Dream Skin 启动、托盘、恢复和主题切换脚本

## 安装

1. 解压 ZIP，不能直接在压缩包预览窗口中运行。
2. 关闭所有 Codex 窗口。
3. 如果 Dream Skin 托盘正在运行，右键托盘图标并选择“退出托盘”。
4. 在解压目录打开 PowerShell，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-silver-noir.ps1 -StartNow
```

安装程序会安装或安全更新 Dream Skin、保存配置备份、导入并选择银夜黑金，然后启动 Codex。

## 只安装，不立即启动

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-silver-noir.ps1
```

之后双击桌面的 `Codex Dream Skin` 快捷方式。

## 不创建快捷方式

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-silver-noir.ps1 -NoShortcuts -StartNow
```

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
