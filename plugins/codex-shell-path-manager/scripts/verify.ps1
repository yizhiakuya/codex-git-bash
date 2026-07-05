[CmdletBinding()]
param(
    [string]$BashPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RtkShellPathManager.psm1') -Force -DisableNameChecking

Assert-RtkWindows
$paths = Get-RtkManagerPaths
$failed = $false

function Report-Check {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Ok,
        [string]$Detail
    )
    $status = if ($Ok) { 'OK' } else { 'FAIL' }
    Write-Host ("[{0}] {1}" -f $status, $Name)
    if ($Detail) {
        Write-Host "     $Detail"
    }
    if (-not $Ok) {
        $script:failed = $true
    }
}

$userEnv = [Environment]::GetEnvironmentVariable('CODEX_CLI_PATH', 'User')
$processEnv = $env:CODEX_CLI_PATH
$configuredShell = Get-TomlStringKey -Path $paths.ConfigPath -Section 'windows' -Key 'shell_path'
$configuredCli = Get-TomlStringKey -Path $paths.ConfigPath -Section 'mcp_servers.node_repl.env' -Key 'CODEX_CLI_PATH'

Report-Check -Name 'Patched codex.exe exists' -Ok (Test-Path -LiteralPath $paths.PatchedCodexExe -PathType Leaf) -Detail $paths.PatchedCodexExe
Report-Check -Name 'User CODEX_CLI_PATH points at patched CLI' -Ok ($userEnv -eq $paths.PatchedCodexExe) -Detail "user=$userEnv"
Report-Check -Name 'config [windows].shell_path is set' -Ok ([bool]$configuredShell) -Detail "shell_path=$configuredShell"
Report-Check -Name 'config node_repl CODEX_CLI_PATH is set' -Ok ($configuredCli -eq $paths.PatchedCodexExe) -Detail "node_repl=$configuredCli"

try {
    $resolvedBash = Resolve-GitBashPath -PreferredPath $(if ($BashPath) { $BashPath } else { $configuredShell })
    Report-Check -Name 'Git Bash resolves and runs' -Ok $true -Detail $resolvedBash
    Write-Host ''
    Write-Host 'Git Bash probe:'
    & $resolvedBash -lc 'echo "shell=$SHELL"; bash --version | head -n 1; command -v git || true'
    if ($LASTEXITCODE -ne 0) {
        Report-Check -Name 'Git Bash probe exit code' -Ok $false -Detail "exit=$LASTEXITCODE"
    }
} catch {
    Report-Check -Name 'Git Bash resolves and runs' -Ok $false -Detail $_.Exception.Message
}

if (Test-Path -LiteralPath $paths.PatchedCodexExe -PathType Leaf) {
    Write-Host ''
    Write-Host 'Patched Codex version probe:'
    & $paths.PatchedCodexExe --version
    if ($LASTEXITCODE -ne 0) {
        Report-Check -Name 'Patched Codex version probe' -Ok $false -Detail "exit=$LASTEXITCODE"
    }
}

Write-Host ''
Write-Host "Process CODEX_CLI_PATH: $processEnv"
Write-Host "State file:             $($paths.StateFile)"

if ($failed) {
    exit 1
}
