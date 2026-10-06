param(
    [string]$GodotPath = 'godot',
    [switch]$ImportAssets
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logDirectory = Join-Path $projectPath 'tmp/regression'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$godotCommand = Get-Command $GodotPath -ErrorAction Stop

function Invoke-GodotCheck([string]$Name, [string[]]$CheckArguments) {
    $logPath = Join-Path $logDirectory "$Name.log"
    $output = & $godotCommand.Source --headless --path $projectPath --log-file $logPath @CheckArguments 2>&1
    $exitCode = $LASTEXITCODE
    $outputText = $output -join "`n"
    Write-Output $outputText
    if ($exitCode -ne 0 -or $outputText -match 'SCRIPT ERROR:|Parse Error:|MAIN SCENE FAILED|RESULT: FAIL') {
        throw "$Name failed with exit code $exitCode"
    }
}

& (Join-Path $PSScriptRoot 'set_version.ps1') -Check
if ($ImportAssets) { Invoke-GodotCheck 'import' @('--import') }
foreach ($scriptFile in (Get-ChildItem -LiteralPath (Join-Path $projectPath 'scripts') -Filter '*.gd' -Recurse | Sort-Object FullName)) {
    $relativePath = $scriptFile.FullName.Substring($projectPath.Length + 1).Replace('\', '/')
    $checkName = 'parse-' + $relativePath.Replace('/', '-').Replace('.gd', '')
    Invoke-GodotCheck $checkName @('--check-only', '--script', "res://$relativePath")
}
Invoke-GodotCheck 'weather' @('--script', 'res://tests/weather_regression_test.gd')
Invoke-GodotCheck 'architecture' @('--script', 'res://tests/architecture_regression_test.gd')
Invoke-GodotCheck 'playfab' @('--script', 'res://tests/playfab_regression_test.gd')
Invoke-GodotCheck 'menu' @('--script', 'res://tests/menu_smoke_test.gd')
Invoke-GodotCheck 'menu-exit' @('--script', 'res://tests/menu_smoke_test.gd', '--', '--test-exit')
Invoke-GodotCheck 'smoke' @('--script', 'res://tests/smoke_test.gd')
Invoke-GodotCheck 'behavior' @('--script', 'res://tests/regression_test.gd')
Invoke-GodotCheck 'audio' @('--script', 'res://tests/audio_regression_test.gd')
Invoke-GodotCheck 'notices' @('--script', 'res://tests/notification_regression_test.gd')
Invoke-GodotCheck 'boot' @('--quit-after', '120')
Write-Output 'GODOT VERIFICATION PASS'
