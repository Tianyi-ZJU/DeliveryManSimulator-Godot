param(
    [string]$Version,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$versionPath = Join-Path $projectRoot 'VERSION'
$versionPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

if ($Check -and $PSBoundParameters.ContainsKey('Version')) {
    throw 'Use -Check alone to verify the current version.'
}
$requestedVersion = if ($Check) { [IO.File]::ReadAllText($versionPath).Trim() } else { $Version }
if ([string]::IsNullOrWhiteSpace($requestedVersion) -or $requestedVersion -notmatch $versionPattern) {
    throw 'Use -Version with MAJOR.MINOR.PATCH (for example 0.1.1), or -Check.'
}
foreach ($part in $requestedVersion.Split('.')) {
    if ([decimal]$part -gt 65535) { throw 'Windows version components must be between 0 and 65535.' }
}

$targets = @(
    @{file='project.godot'; pattern='(?m)^config/version="[^"\r\n]*"'; value=('config/version="{0}"' -f $requestedVersion)},
    @{file='export_presets.cfg'; pattern='(?m)^application/file_version="[^"\r\n]*"'; value=('application/file_version="{0}.0"' -f $requestedVersion)},
    @{file='export_presets.cfg'; pattern='(?m)^application/product_version="[^"\r\n]*"'; value=('application/product_version="{0}.0"' -f $requestedVersion)},
    @{file='README.md'; pattern='(?m)(?<=\u5f53\u524d\u7248\u672c\uFF1A\*\*)[^*\r\n]+(?=\*\*)'; value=$requestedVersion}
)
$contents = @{}
foreach ($target in $targets) {
    $path = Join-Path $projectRoot $target.file
    if (-not $contents.ContainsKey($path)) { $contents[$path] = [IO.File]::ReadAllText($path) }
    $regex = [regex]::new($target.pattern)
    $matchesFound = $regex.Matches($contents[$path])
    if ($matchesFound.Count -ne 1) { throw "Expected one version field in $($target.file): $($target.pattern)" }
    if ($Check) {
        if ($matchesFound[0].Value -ne $target.value) { throw "Version mismatch in $($target.file). Run this script with -Version $requestedVersion." }
    } else {
        $contents[$path] = $regex.Replace($contents[$path], $target.value, 1)
    }
}
if ($Check) {
    $changelog = [IO.File]::ReadAllText((Join-Path $projectRoot 'CHANGELOG.md'))
    if (-not $changelog.Contains("## [$requestedVersion] - ")) { throw "Add a dated $requestedVersion entry to CHANGELOG.md before release." }
    Write-Output "VERSION CHECK PASS: $requestedVersion"
    return
}

# Validate every target before writing; retain unrelated settings and text.
$encoding = [Text.UTF8Encoding]::new($false)
foreach ($path in $contents.Keys) { [IO.File]::WriteAllText($path, $contents[$path], $encoding) }
[IO.File]::WriteAllText($versionPath, "$requestedVersion`n", $encoding)
Write-Output "Version synchronized: $requestedVersion (Windows: $requestedVersion.0). Update CHANGELOG.md before release."
