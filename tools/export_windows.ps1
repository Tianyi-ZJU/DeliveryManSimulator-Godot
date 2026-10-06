param(
    [string]$GodotPath = 'godot'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
& (Join-Path $PSScriptRoot 'set_version.ps1') -Check
$version = [IO.File]::ReadAllText((Join-Path $projectRoot 'VERSION')).Trim()
$godotCommand = Get-Command $GodotPath -ErrorAction Stop
$releaseRoot = Join-Path $projectRoot "tmp/releases/v$version"
$stagingRoot = Join-Path $releaseRoot 'project'
$packageName = "DeliveryManSimulator-v$version-windows-x86_64"
$packageRoot = Join-Path $releaseRoot $packageName
if (Test-Path -LiteralPath $releaseRoot) {
    throw "Release output already exists: $releaseRoot. Use a fresh version or move this output before rebuilding."
}
New-Item -ItemType Directory -Path $stagingRoot, $packageRoot | Out-Null

# Copy shipping source only; do not change the editor's live project.
foreach ($directory in @('assets', 'data', 'scenes', 'scripts', 'shaders')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $stagingRoot -Recurse
}
foreach ($file in @('project.godot', 'export_presets.cfg', 'default_bus_layout.tres')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $stagingRoot
}
$encoding = [Text.UTF8Encoding]::new($false)
$settingsPath = Join-Path $stagingRoot 'project.godot'
$settings = [IO.File]::ReadAllText($settingsPath)
$settings = [regex]::Replace($settings, '(?m)^MCPRuntimeProbe=.*\r?\n', '')
$settings = [regex]::Replace($settings, '(?ms)^\[editor_plugins\]\r?\n.*?(?=^\[|\z)', '')
[IO.File]::WriteAllText($settingsPath, $settings, $encoding)

function Invoke-ReleaseGodot([string]$Name, [string[]]$CheckArguments) {
    $logPath = Join-Path $releaseRoot "$Name.log"
    $output = & $godotCommand.Source --headless --path $stagingRoot --log-file $logPath @CheckArguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    if ($exitCode -ne 0 -or $text -match 'SCRIPT ERROR:|Parse Error:|Export failed|Failed to export') {
        Write-Output $text
        throw "$Name failed with exit code $exitCode"
    }
    Write-Output "$Name passed. Log: $logPath"
}
Invoke-ReleaseGodot 'import' @('--import')
$executablePath = Join-Path $packageRoot 'DeliveryManSimulator.exe'
Invoke-ReleaseGodot 'export' @('--export-release', 'Windows Desktop', $executablePath)
foreach ($file in @('DeliveryManSimulator.exe', 'DeliveryManSimulator.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $file))) { throw "Missing export file: $file" }
}
$exportVersion = (Get-Item -LiteralPath $executablePath).VersionInfo
if ($exportVersion.FileVersion -ne "$version.0" -or $exportVersion.ProductVersion -ne "$version.0") {
    throw 'Windows executable version metadata does not match VERSION.'
}

$playerReadme = @"
外卖员模拟器 / Delivery Man Simulator
Godot port v$version · Windows x86_64

运行 DeliveryManSimulator.exe，无需安装 Godot。
请将 DeliveryManSimulator.exe 与 DeliveryManSimulator.pck 保留在同一目录。

鼠标左键：接单、选择任务和操作界面；骑手自动沿道路派送。
拖动任务卡：调整派送顺序。
Shift：加速；Ctrl：慢时；Space：催餐、收工或进入下一天；M：静音。

包含五天派送流程、天气效果、休息升级、BGM 和在线排行榜。
排行榜使用原项目 PlayFab 服务，联网失败不影响单机游玩。
尚未包含启动教程、游戏进度存档和跨设备账号找回。

Godot 迁移仓库：https://github.com/Tianyi-ZJU/DeliveryManSimulator-Godot
原 Unity 项目：https://github.com/Ameftn14/DeliveryManSimulator
原项目及素材的权利归属保持不变。
"@
[IO.File]::WriteAllText((Join-Path $packageRoot 'README.txt'), $playerReadme, $encoding)
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/BarlowCondensed/OFL.txt') -Destination (Join-Path $packageRoot 'BarlowCondensed-OFL.txt')
Compress-Archive -LiteralPath $packageRoot -DestinationPath (Join-Path $releaseRoot "$packageName.zip")
$archivePath = Join-Path $releaseRoot "$packageName.zip"
$checksum = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $releaseRoot 'SHA256SUMS.txt'), "$checksum  $packageName.zip`n", $encoding)
Write-Output "WINDOWS RELEASE PACKAGE: $archivePath"
