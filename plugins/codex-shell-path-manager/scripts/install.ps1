[CmdletBinding()]
param(
    [string]$SourceDir,
    [string]$RepoUrl = 'https://github.com/openai/codex.git',
    [string]$Ref,
    [string]$BashPath,
    [string]$RustToolchain = '1.95-x86_64-pc-windows-msvc',
    [switch]$RunTests,
    [switch]$Release,
    [switch]$SkipGitInstall,
    [switch]$SkipUserEnvironment,
    [switch]$SkipConfig,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexShellPathManager.psm1') -Force -DisableNameChecking

if ($Help) {
    Write-Host @'
Codex Shell Path Manager installer

Builds a patched Codex CLI, configures Codex Desktop to start that CLI through
CODEX_CLI_PATH, and sets [windows].shell_path to Git Bash.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [options]

Options:
  -SourceDir <path>       Use an existing openai/codex checkout instead of cloning.
  -RepoUrl <url>          Codex source repo to clone. Default: https://github.com/openai/codex.git
  -Ref <ref>              Git ref to fetch/checkout before patching.
  -BashPath <path>        Use a specific Git Bash bash.exe.
  -RustToolchain <name>   Rust toolchain passed as +toolchain. Default: 1.95-x86_64-pc-windows-msvc
  -RunTests               Run targeted codex-core tests before installing codex.exe.
  -Release                Build target\release\codex.exe instead of target\debug\codex.exe.
  -SkipGitInstall         Do not use winget to install Git for Windows if bash.exe is missing.
  -SkipUserEnvironment    Do not set the user CODEX_CLI_PATH environment variable.
  -SkipConfig             Do not edit ~/.codex/config.toml.
  -Help                   Print this help.

Notes:
  Restart Codex Desktop and open a new thread after install.
  This script does not modify the WindowsApps Codex installation.
'@
    exit 0
}

Assert-RtkWindows
$paths = Get-RtkManagerPaths
New-DirectoryIfMissing -Path $paths.StateRoot
New-DirectoryIfMissing -Path $paths.BackupsRoot

$previousEnv = [Environment]::GetEnvironmentVariable('CODEX_CLI_PATH', 'User')
$resolvedBash = Resolve-GitBashPath -PreferredPath $BashPath -InstallIfMissing:(!$SkipGitInstall)
$gitExe = Resolve-GitExePath -BashPath $resolvedBash

if ($SourceDir) {
    $resolvedSource = (Resolve-Path -LiteralPath $SourceDir).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedSource '.git'))) {
        throw "SourceDir is not a Git repository: $resolvedSource"
    }
} else {
    $resolvedSource = New-CodexSourceClone -GitExe $gitExe -RepoUrl $RepoUrl -Ref $Ref -SourcesRoot $paths.SourcesRoot
}

$patchStatus = Apply-CodexShellPathPatch -GitExe $gitExe -SourceDir $resolvedSource -PatchPath $paths.PatchPath

if ($RunTests) {
    Invoke-CodexShellPathTests -SourceDir $resolvedSource -RustToolchain $RustToolchain
}

$codexCliPath = Build-CodexCli -SourceDir $resolvedSource -OutputDir $paths.BinDir -RustToolchain $RustToolchain -Release:$Release
Set-CodexDesktopRouting `
    -CodexCliPath $codexCliPath `
    -BashPath $resolvedBash `
    -ConfigPath $paths.ConfigPath `
    -BackupRoot $paths.BackupsRoot `
    -SkipUserEnvironment:$SkipUserEnvironment `
    -SkipConfig:$SkipConfig

Save-RtkManagerState -StateFile $paths.StateFile -State @{
    installedAt = (Get-Date).ToString('o')
    sourceDir = $resolvedSource
    repoUrl = $RepoUrl
    ref = $Ref
    patchStatus = $patchStatus
    bashPath = $resolvedBash
    gitExe = $gitExe
    codexCliPath = $codexCliPath
    previousUserCODEX_CLI_PATH = $previousEnv
    skippedUserEnvironment = [bool]$SkipUserEnvironment
    skippedConfig = [bool]$SkipConfig
}

Write-Host ''
Write-Host 'Codex shell path manager install complete.'
Write-Host "Git Bash:        $resolvedBash"
Write-Host "Patched Codex:   $codexCliPath"
Write-Host "Config:          $($paths.ConfigPath)"
if (-not $SkipUserEnvironment) {
    Write-Host 'User env:        CODEX_CLI_PATH updated'
}
Write-Host ''
Write-Host 'Restart Codex Desktop and open a new thread for the app-server to pick up CODEX_CLI_PATH.'
