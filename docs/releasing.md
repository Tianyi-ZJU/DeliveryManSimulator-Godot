# 发布版本

版本号由 `VERSION` 维护。同步 `README.md`、Godot 配置和 Windows 文件版本：

```powershell
.\tools\set_version.ps1 -Version 1.0.0
```

为 `CHANGELOG.md` 添加带日期的版本记录，然后验证并构建 Windows 包：

```powershell
.\tools\verify_godot.ps1 -GodotPath '完整 Godot console.exe 路径' -ImportAssets
.\tools\export_windows.ps1 -GodotPath '完整 Godot console.exe 路径'
```

需要安装相同 Godot 版本的 Windows x86_64 导出模板。产物位于 `tmp/releases/v版本号/`：游戏压缩包及 `SHA256SUMS.txt`。目录已存在时脚本会停止，避免覆盖已验证产物。

打包脚本复制游戏源码到独立目录并重新导入，不依赖开发目录的缓存。发布包移除 MCP 调试自动加载与编辑器插件，仅保留游戏资产、脚本、场景及公开 PlayFab 配置，不包含测试、文档和本机代理。

发布前应检查压缩包解压后的 `.exe` 与 `.pck`，验证启动菜单、进入游戏、休息升级及排行榜界面；联网权限与真实后台设置仍以 PlayFab 接入说明为准。

验证后提交源码，创建对应的附注 Git 标签 `v版本号`，将分支和标签推送到 GitHub，并在该标签创建正式 Release，上传游戏压缩包与校验文件。
