[CmdletBinding()]
param(
    [switch]$KeepWindowsShellPath,
    [switch]$KeepNodeReplCliPath,
    [switch]$RemoveBuiltCli,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexShellPathManager.psm1') -Force -DisableNameChecking

if ($Help) {
    Write-Host @'
Codex Shell Path Manager rollback

Restores/removes CODEX_CLI_PATH and removes config.toml keys created by install.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\rollback.ps1 [options]

Options:
  -KeepWindowsShellPath   Leave [windows].shell_path in ~/.codex/config.toml.
  -KeepNodeReplCliPath    Leave node_repl CODEX_CLI_PATH in ~/.codex/config.toml.
  -RemoveBuiltCli         Delete ~/.codex/bin/codex-shell-path/codex.exe.
  -Help                   Print this help.

Notes:
  Restart Codex Desktop and open a new thread after rollback.
'@
    exit 0
}

Assert-RtkWindows
$paths = Get-RtkManagerPaths
$state = Read-RtkManagerState -StateFile $paths.StateFile

Backup-FileIfExists -Path $paths.ConfigPath -BackupRoot $paths.BackupsRoot -Label 'rollback-config' | Out-Null

if ($state -and $state.previousUserCODEX_CLI_PATH) {
    [Environment]::SetEnvironmentVariable('CODEX_CLI_PATH', [string]$state.previousUserCODEX_CLI_PATH, 'User')
    $env:CODEX_CLI_PATH = [string]$state.previousUserCODEX_CLI_PATH
    Write-Host "Restored user CODEX_CLI_PATH to previous value: $($state.previousUserCODEX_CLI_PATH)"
} else {
    [Environment]::SetEnvironmentVariable('CODEX_CLI_PATH', $null, 'User')
    Remove-Item Env:\CODEX_CLI_PATH -ErrorAction SilentlyContinue
    Write-Host 'Removed user CODEX_CLI_PATH.'
}

if (-not $KeepWindowsShellPath) {
    Remove-TomlKey -Path $paths.ConfigPath -Section 'windows' -Key 'shell_path'
    Write-Host 'Removed [windows].shell_path from config.toml.'
}

if (-not $KeepNodeReplCliPath) {
    Remove-TomlKey -Path $paths.ConfigPath -Section 'mcp_servers.node_repl.env' -Key 'CODEX_CLI_PATH'
    Write-Host 'Removed node_repl CODEX_CLI_PATH from config.toml.'
}

if ($RemoveBuiltCli -and (Test-Path -LiteralPath $paths.PatchedCodexExe)) {
    Remove-Item -LiteralPath $paths.PatchedCodexExe -Force
    Write-Host "Removed patched CLI: $($paths.PatchedCodexExe)"
}

Write-Host ''
Write-Host 'Rollback complete. Restart Codex Desktop and open a new thread to return to the official app-server path.'
