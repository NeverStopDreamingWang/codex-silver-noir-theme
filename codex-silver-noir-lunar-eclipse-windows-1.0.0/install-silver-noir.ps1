[CmdletBinding()]
param(
  [int]$Port = 9335,
  [switch]$NoShortcuts,
  [switch]$StartNow
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = Join-Path $packageRoot 'runtime'
$skinRoot = Join-Path $packageRoot 'skin'
$runtimeInstaller = Join-Path $runtimeRoot 'scripts\install-dream-skin.ps1'

if (-not (Test-Path -LiteralPath $runtimeInstaller -PathType Leaf)) {
  throw "Bundled Dream Skin runtime is incomplete: $runtimeInstaller"
}
if (-not (Test-Path -LiteralPath (Join-Path $skinRoot 'theme.json') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $skinRoot 'background.png') -PathType Leaf)) {
  throw 'Bundled Silver Noir skin files are incomplete.'
}

$installArguments = @{ Port = $Port; DeferRelaunch = $true }
if ($NoShortcuts) { $installArguments.NoShortcuts = $true }
$installOutput = @(& $runtimeInstaller @installArguments)
$installResult = @($installOutput | Where-Object {
  $null -ne $_ -and $_.PSObject.Properties.Name -contains 'ResultType' -and
  $_.ResultType -eq 'CodexDreamSkinInstall'
}) | Select-Object -Last 1
if ($null -eq $installResult) {
  throw 'Bundled Dream Skin runtime did not return a valid installation result.'
}
if ($installResult.Cancelled) {
  Write-Host 'Silver Noir installation was cancelled.'
  return
}

$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$engineScripts = Join-Path $stateRoot 'engine\scripts'
. (Join-Path $engineScripts 'common-windows.ps1')
. (Join-Path $engineScripts 'theme-windows.ps1')

$paths = Get-DreamSkinThemePaths -StateRoot $stateRoot
$themeManifestPath = Join-Path $skinRoot 'theme.json'
$themeManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $themeManifestPath | ConvertFrom-Json
$themeId = [string]$themeManifest.id
if ($themeId -notmatch '^[a-z0-9][a-z0-9._-]*$') {
  throw "Bundled Silver Noir theme id is invalid: $themeId"
}
$savedTheme = Join-Path $paths.Saved $themeId
Ensure-DreamSkinManagedDirectory -Path $savedTheme -Root $paths.Root
Copy-Item -LiteralPath (Join-Path $skinRoot 'background.png') `
  -Destination (Join-Path $savedTheme 'background.png') -Force
Copy-Item -LiteralPath (Join-Path $skinRoot 'theme.json') `
  -Destination (Join-Path $savedTheme 'theme.json') -Force
$null = Read-DreamSkinTheme -ThemeDirectory $savedTheme

$configPath = Join-Path $HOME '.codex\config.toml'
$applied = Use-DreamSkinSavedTheme -ThemeDirectory $savedTheme -StateRoot $stateRoot `
  -ConfigPath $configPath

if ($StartNow -or $installResult.CodexWasRunning) {
  & (Join-Path $engineScripts 'start-dream-skin.ps1') -Port $Port
  if ($LASTEXITCODE -ne 0) { throw "Dream Skin start failed with exit code $LASTEXITCODE" }
}

Write-Host "Installed and selected: $($applied.Theme.name)"
if (-not $StartNow -and -not $installResult.CodexWasRunning) {
  Write-Host 'Use the Codex Dream Skin shortcut to start, or rerun this installer with -StartNow.'
}
