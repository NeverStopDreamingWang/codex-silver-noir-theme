[CmdletBinding()]
param(
  [int]$Port = 9335,
  [switch]$NoShortcuts,
  [switch]$DeferRelaunch
)

$ErrorActionPreference = 'Stop'
$PortExplicit = $PSBoundParameters.ContainsKey('Port')
$SkillRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')

function Stop-DreamSkinTrayForInstall {
  param([Parameter(Mandatory = $true)][string]$StateRoot)

  if (-not (Test-DreamSkinTrayActive)) { return $false }
  $trayScript = [System.IO.Path]::GetFullPath(
    (Join-Path $StateRoot 'engine\scripts\tray-dream-skin.ps1')
  )
  $stopped = $false
  $processes = Get-CimInstance Win32_Process `
    -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction Stop
  foreach ($process in $processes) {
    if ($process.ProcessId -eq $PID -or -not $process.CommandLine) { continue }
    if ($process.CommandLine.IndexOf($trayScript, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
      $stopped = $true
    }
  }
  if (-not $stopped) {
    throw 'The Dream Skin tray is active, but its managed process could not be identified safely.'
  }

  $deadline = (Get-Date).AddSeconds(5)
  while ((Test-DreamSkinTrayActive) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 100
  }
  if (Test-DreamSkinTrayActive) {
    throw 'The Dream Skin tray did not stop within 5 seconds.'
  }
  return $true
}

function Start-DreamSkinTrayAfterInstall {
  param(
    [Parameter(Mandatory = $true)][string]$StateRoot,
    [Parameter(Mandatory = $true)][int]$Port
  )

  if (Test-DreamSkinTrayActive) { return }
  $trayScript = Join-Path $StateRoot 'engine\scripts\tray-dream-skin.ps1'
  if (-not (Test-Path -LiteralPath $trayScript -PathType Leaf)) {
    throw "The managed Dream Skin tray script is unavailable: $trayScript"
  }
  $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
  $arguments = ConvertTo-DreamSkinArgumentLine -Arguments @(
    '-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
    '-File', $trayScript, '-Port', "$Port"
  )
  Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden | Out-Null
}

$codexWasRunning = $false
$trayWasRunning = $false
$engine = $null
$relaunchCodex = $null
$installError = $null
$operationLock = Enter-DreamSkinOperationLock
try {
  Assert-DreamSkinPort -Port $Port
  $null = Get-DreamSkinNodeRuntime
  $registeredInstalls = @(Get-DreamSkinRegisteredCodexInstalls)
  if ($registeredInstalls.Count -eq 0) {
    throw 'The official OpenAI.Codex Store package is not installed or its identity cannot be validated.'
  }
  $StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $themePaths = Get-DreamSkinThemePaths -StateRoot $StateRoot
  $StatePath = Join-Path $StateRoot 'state.json'
  $existingState = Read-DreamSkinState -Path $StatePath
  $savedPathCandidate = Get-DreamSkinCodexStatePathCandidate -State $existingState
  $savedCodex = Resolve-DreamSkinCodexInstallFromState -State $existingState -RegisteredInstalls $registeredInstalls
  if ($null -ne $savedPathCandidate -and $null -eq $savedCodex -and
    (Get-DreamSkinCodexProcesses -Codex $savedPathCandidate).Count -gt 0) {
    throw 'The saved Codex path is still running but no longer matches a registered Store package. Close it manually before installing.'
  }

  $runningInstalls = @($registeredInstalls | Where-Object {
    (Get-DreamSkinCodexProcesses -Codex $_).Count -gt 0
  })
  $codexWasRunning = $runningInstalls.Count -gt 0
  if ($runningInstalls.Count -gt 0) {
    $confirmed = Confirm-DreamSkinRestart -Message (
      'Codex is running. Installation will close it, update Dream Skin, apply the selected theme, ' +
      'and then reopen Codex with Dream Skin. Continue?'
    )
    if (-not $confirmed) {
      Write-Host 'Dream Skin installation was cancelled; no state or configuration was changed.'
      return [pscustomobject]@{
        ResultType = 'CodexDreamSkinInstall'
        Cancelled = $true
        CodexWasRunning = $true
        TrayWasRunning = (Test-DreamSkinTrayActive)
      }
    }
    $relaunchCodex = $runningInstalls[0]
  }

  $trayWasRunning = Test-DreamSkinTrayActive
  if ($trayWasRunning) {
    $null = Stop-DreamSkinTrayForInstall -StateRoot $StateRoot
  }
  if ($codexWasRunning) {
    foreach ($registeredCodex in $runningInstalls) {
      Stop-DreamSkinCodex -Codex $registeredCodex -AllowForce
    }
  }

  if ($null -ne $existingState) {
    $null = Stop-DreamSkinRecordedInjector -State $existingState
    Remove-Item -LiteralPath $StatePath -Force -ErrorAction SilentlyContinue
  }

  Ensure-DreamSkinManagedDirectory -Path $themePaths.Root -Root $themePaths.Root
  $engine = Install-DreamSkinRuntimeEngine -SkillRoot $SkillRoot -StateRoot $StateRoot
  $null = Initialize-DreamSkinThemeStore -SkillRoot $engine.Root -StateRoot $StateRoot
  $ConfigPath = Join-Path $HOME '.codex\config.toml'
  $BackupPath = Join-Path $StateRoot 'config.before-dream-skin.toml'
  Install-DreamSkinBaseTheme -ConfigPath $ConfigPath -BackupPath $BackupPath

  if (-not $NoShortcuts) {
    $shell = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $startScript = $engine.Start
    $restoreScript = $engine.Restore
    $trayScript = $engine.Tray
    $portArgument = if ($PortExplicit) { " -Port $Port" } else { '' }

    foreach ($folder in @($desktop, $startMenu)) {
      $shortcut = $shell.CreateShortcut((Join-Path $folder 'Codex Dream Skin.lnk'))
      $shortcut.TargetPath = $powershell
      $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`"$portArgument -PromptRestart"
      $shortcut.WorkingDirectory = $engine.Root
      $shortcut.Description = 'Launch the official Codex app with Codex Dream Skin'
      $shortcut.Save()
    }

    $restore = $shell.CreateShortcut((Join-Path $desktop 'Codex Dream Skin - Restore.lnk'))
    $restore.TargetPath = $powershell
    $restore.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$restoreScript`"$portArgument -RestoreBaseTheme -PromptRestart"
    $restore.WorkingDirectory = $engine.Root
    $restore.Description = 'Restore the official Codex appearance and close the CDP session'
    $restore.Save()

  }

  if ((-not $NoShortcuts) -or $trayWasRunning) {
    Start-DreamSkinTrayAfterInstall -StateRoot $StateRoot -Port $Port
  }

  if ($NoShortcuts) {
    Write-Host "Codex Dream Skin base theme installed at $($engine.Root). Run $($engine.Start) to launch it."
  } else {
    Write-Host 'Codex Dream Skin installed. The launch shortcut starts the tray controls and asks before restarting an open Codex window.'
  }
} catch {
  $installError = $_
} finally {
  Exit-DreamSkinOperationLock -Mutex $operationLock
}

if ($null -ne $installError) {
  if ($trayWasRunning) {
    try {
      Start-DreamSkinTrayAfterInstall -StateRoot $StateRoot -Port $Port
    } catch {
      Write-Warning "Installation failed and the previous tray could not be restarted: $($_.Exception.Message)"
    }
  }
  if ($codexWasRunning -and $null -ne $relaunchCodex -and
    (Get-DreamSkinCodexProcesses -Codex $relaunchCodex).Count -eq 0) {
    try {
      $null = Start-DreamSkinCodex -Codex $relaunchCodex
    } catch {
      Write-Warning "Installation failed and Codex could not be reopened automatically: $($_.Exception.Message)"
    }
  }
  throw $installError
}

if ($codexWasRunning -and -not $DeferRelaunch) {
  & $engine.Start -Port $Port
}

[pscustomobject]@{
  ResultType = 'CodexDreamSkinInstall'
  Cancelled = $false
  CodexWasRunning = $codexWasRunning
  TrayWasRunning = $trayWasRunning
}
