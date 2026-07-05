Set-StrictMode -Version Latest

function Get-RtkManagerPaths {
    $userProfile = [Environment]::GetFolderPath('UserProfile')
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $userProfile '.codex' }
    $pluginRoot = Split-Path -Parent $PSScriptRoot
    $stateRoot = Join-Path $codexHome 'codex-shell-path-manager'
    $binDir = Join-Path $codexHome 'bin\codex-shell-path-rtk'

    [pscustomobject]@{
        UserProfile = $userProfile
        CodexHome = $codexHome
        PluginRoot = $pluginRoot
        StateRoot = $stateRoot
        SourcesRoot = Join-Path $stateRoot 'sources'
        BackupsRoot = Join-Path $stateRoot 'backups'
        StateFile = Join-Path $stateRoot 'state.json'
        BinDir = $binDir
        PatchedCodexExe = Join-Path $binDir 'codex.exe'
        ConfigPath = Join-Path $codexHome 'config.toml'
        PatchPath = Join-Path $pluginRoot 'patches\codex-windows-shell-path.patch'
    }
}

function Assert-RtkWindows {
    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw 'This manager is intended for Windows Codex Desktop.'
    }
}

function New-DirectoryIfMissing {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-DirectoryIfMissing -Path $parent
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function ConvertTo-TomlString {
    param([Parameter(Mandatory)][string]$Value)
    return ($Value | ConvertTo-Json -Compress)
}

function Backup-FileIfExists {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BackupRoot,
        [Parameter(Mandatory)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    New-DirectoryIfMissing -Path $BackupRoot
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $name = '{0}-{1}-{2}' -f $Label, $timestamp, (Split-Path -Leaf $Path)
    $destination = Join-Path $BackupRoot $name
    Copy-Item -LiteralPath $Path -Destination $destination -Force
    return $destination
}

function Get-TextLines {
    param([Parameter(Mandatory)][string]$Text)
    if ($Text.Length -eq 0) {
        return @()
    }
    return @($Text -split "\r?\n")
}

function Set-TomlStringKey {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )

    $text = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { '' }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-TextLines -Text $text)) {
        $lines.Add($line)
    }

    while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
        $lines.RemoveAt($lines.Count - 1)
    }

    $sectionPattern = '^\s*\[' + [regex]::Escape($Section) + '\]\s*(#.*)?$'
    $anySectionPattern = '^\s*\[[^\]]+\]\s*(#.*)?$'
    $keyPattern = '^\s*' + [regex]::Escape($Key) + '\s*='
    $tomlValue = ConvertTo-TomlString -Value $Value
    $newLine = "$Key = $tomlValue"

    $sectionStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            $sectionStart = $i
            break
        }
    }

    if ($sectionStart -lt 0) {
        if ($lines.Count -gt 0) {
            $lines.Add('')
        }
        $lines.Add("[$Section]")
        $lines.Add($newLine)
        Write-Utf8NoBomFile -Path $Path -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
        return
    }

    $sectionEnd = $lines.Count
    for ($i = $sectionStart + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anySectionPattern) {
            $sectionEnd = $i
            break
        }
    }

    for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
        if ($lines[$i] -match $keyPattern) {
            $lines[$i] = $newLine
            Write-Utf8NoBomFile -Path $Path -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
            return
        }
    }

    $lines.Insert($sectionStart + 1, $newLine)
    Write-Utf8NoBomFile -Path $Path -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Remove-TomlKey {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $text = Get-Content -LiteralPath $Path -Raw
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-TextLines -Text $text)) {
        $lines.Add($line)
    }

    $sectionPattern = '^\s*\[' + [regex]::Escape($Section) + '\]\s*(#.*)?$'
    $anySectionPattern = '^\s*\[[^\]]+\]\s*(#.*)?$'
    $keyPattern = '^\s*' + [regex]::Escape($Key) + '\s*='

    $sectionStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            $sectionStart = $i
            break
        }
    }
    if ($sectionStart -lt 0) {
        return
    }

    $sectionEnd = $lines.Count
    for ($i = $sectionStart + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anySectionPattern) {
            $sectionEnd = $i
            break
        }
    }

    for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
        if ($lines[$i] -match $keyPattern) {
            $lines.RemoveAt($i)
            while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
                $lines.RemoveAt($lines.Count - 1)
            }
            Write-Utf8NoBomFile -Path $Path -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
            return
        }
    }
}

function Get-TomlStringKey {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $lines = Get-Content -LiteralPath $Path
    $sectionPattern = '^\s*\[' + [regex]::Escape($Section) + '\]\s*(#.*)?$'
    $anySectionPattern = '^\s*\[[^\]]+\]\s*(#.*)?$'
    $keyPattern = '^\s*' + [regex]::Escape($Key) + '\s*=\s*(.+?)\s*(#.*)?$'
    $inSection = $false

    foreach ($line in $lines) {
        if ($line -match $sectionPattern) {
            $inSection = $true
            continue
        }
        if ($inSection -and $line -match $anySectionPattern) {
            break
        }
        if ($inSection -and $line -match $keyPattern) {
            $raw = $Matches[1].Trim()
            if ($raw.StartsWith('"')) {
                try {
                    return ($raw | ConvertFrom-Json)
                } catch {
                    return $raw.Trim('"')
                }
            }
            if ($raw.StartsWith("'") -and $raw.EndsWith("'")) {
                return $raw.Substring(1, $raw.Length - 2)
            }
            return $raw
        }
    }
    return $null
}

function Test-GitBashPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    try {
        $output = & $Path -lc 'printf RTK_GIT_BASH_OK' 2>$null
        return ($LASTEXITCODE -eq 0 -and (($output -join '') -eq 'RTK_GIT_BASH_OK'))
    } catch {
        return $false
    }
}

function Get-GitRootFromBash {
    param([Parameter(Mandatory)][string]$BashPath)
    $leafParent = Split-Path -Parent $BashPath
    $root = Split-Path -Parent $leafParent
    return $root
}

function Resolve-GitExePath {
    param([string]$BashPath)
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($BashPath) {
        $root = Get-GitRootFromBash -BashPath $BashPath
        $candidates.Add((Join-Path $root 'cmd\git.exe'))
        $candidates.Add((Join-Path $root 'bin\git.exe'))
        $candidates.Add((Join-Path $root 'mingw64\bin\git.exe'))
    }
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($command) {
        $candidates.Add($command.Source)
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'git.exe was not found. Install Git for Windows or pass -BashPath to a valid Git installation.'
}

function Install-GitForWindows {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'Git Bash was not found and winget.exe is unavailable. Install Git for Windows manually, then rerun install.ps1.'
    }

    Write-Host 'Git Bash was not found. Installing Git for Windows with winget...'
    $args = @(
        'install',
        '--id', 'Git.Git',
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--silent'
    )
    & $winget.Source @args
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed to install Git.Git with exit code $LASTEXITCODE."
    }
}

function Resolve-GitBashPath {
    param(
        [string]$PreferredPath,
        [switch]$InstallIfMissing
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($PreferredPath) {
        $candidates.Add($PreferredPath)
    }
    if ($env:CODEX_GIT_BASH_PATH) {
        $candidates.Add($env:CODEX_GIT_BASH_PATH)
    }

    $staticCandidates = @(
        'D:\Apps\Git\bin\bash.exe',
        'D:\Apps\Git\usr\bin\bash.exe',
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:ProgramFiles 'Git\usr\bin\bash.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\usr\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\usr\bin\bash.exe')
    )
    foreach ($candidate in $staticCandidates) {
        if ($candidate) {
            $candidates.Add($candidate)
        }
    }

    $bashCommand = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($bashCommand) {
        $candidates.Add($bashCommand.Source)
    }

    $seen = @{}
    foreach ($candidate in $candidates) {
        if (-not $candidate) {
            continue
        }
        $expanded = [Environment]::ExpandEnvironmentVariables($candidate)
        if ($seen.ContainsKey($expanded)) {
            continue
        }
        $seen[$expanded] = $true
        if (Test-GitBashPath -Path $expanded) {
            return (Resolve-Path -LiteralPath $expanded).Path
        }
    }

    if ($InstallIfMissing) {
        Install-GitForWindows
        return Resolve-GitBashPath -PreferredPath $PreferredPath
    }

    throw 'Git Bash was not found. Pass -BashPath or rerun without -SkipGitInstall to install Git for Windows with winget.'
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string]$WorkingDirectory
    )

    $display = $FilePath + ' ' + ($ArgumentList -join ' ')
    Write-Host "> $display"
    $previous = Get-Location
    try {
        if ($WorkingDirectory) {
            Set-Location -LiteralPath $WorkingDirectory
        }
        & $FilePath @ArgumentList
        $exitCode = $LASTEXITCODE
    } finally {
        Set-Location $previous
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $display"
    }
}

function Test-NativeSuccess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string]$WorkingDirectory
    )
    $previous = Get-Location
    try {
        if ($WorkingDirectory) {
            Set-Location -LiteralPath $WorkingDirectory
        }
        & $FilePath @ArgumentList *> $null
        return ($LASTEXITCODE -eq 0)
    } finally {
        Set-Location $previous
    }
}

function New-CodexSourceClone {
    param(
        [Parameter(Mandatory)][string]$GitExe,
        [Parameter(Mandatory)][string]$RepoUrl,
        [string]$Ref,
        [Parameter(Mandatory)][string]$SourcesRoot
    )
    New-DirectoryIfMissing -Path $SourcesRoot
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $sourceDir = Join-Path $SourcesRoot "codex-$timestamp"
    Invoke-Native -FilePath $GitExe -ArgumentList @('clone', '--depth', '1', $RepoUrl, $sourceDir)
    if ($Ref) {
        Invoke-Native -FilePath $GitExe -ArgumentList @('fetch', '--depth', '1', 'origin', $Ref) -WorkingDirectory $sourceDir
        Invoke-Native -FilePath $GitExe -ArgumentList @('checkout', '--detach', 'FETCH_HEAD') -WorkingDirectory $sourceDir
    }
    return $sourceDir
}

function Apply-CodexShellPathPatch {
    param(
        [Parameter(Mandatory)][string]$GitExe,
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$PatchPath
    )
    if (-not (Test-Path -LiteralPath $PatchPath -PathType Leaf)) {
        throw "Patch file not found: $PatchPath"
    }

    $checkArgs = @('apply', '--check', $PatchPath)
    if (Test-NativeSuccess -FilePath $GitExe -ArgumentList $checkArgs -WorkingDirectory $SourceDir) {
        Invoke-Native -FilePath $GitExe -ArgumentList @('apply', $PatchPath) -WorkingDirectory $SourceDir
        return 'applied'
    }

    $reverseArgs = @('apply', '--reverse', '--check', $PatchPath)
    if (Test-NativeSuccess -FilePath $GitExe -ArgumentList $reverseArgs -WorkingDirectory $SourceDir) {
        Write-Host 'Patch already appears to be applied.'
        return 'already-applied'
    }

    throw 'The Codex shell_path patch did not apply cleanly. The upstream Codex source likely changed; inspect the patch conflict before rebuilding.'
}

function Invoke-CargoWithFallback {
    param(
        [Parameter(Mandatory)][string[]]$CargoArgs,
        [Parameter(Mandatory)][string]$SourceDir,
        [string]$RustToolchain
    )
    $cargo = Get-Command cargo.exe -ErrorAction SilentlyContinue
    if (-not $cargo) {
        throw 'cargo.exe was not found. Install Rust with rustup, then rerun install.ps1.'
    }

    if ($RustToolchain) {
        try {
            Invoke-Native -FilePath $cargo.Source -ArgumentList (@("+$RustToolchain") + $CargoArgs) -WorkingDirectory $SourceDir
            return
        } catch {
            Write-Warning $_.Exception.Message
            Write-Warning 'Retrying with the default cargo toolchain.'
        }
    }

    Invoke-Native -FilePath $cargo.Source -ArgumentList $CargoArgs -WorkingDirectory $SourceDir
}

function Build-CodexCli {
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$OutputDir,
        [string]$RustToolchain,
        [switch]$Release
    )
    $cargoArgs = @('build', '-p', 'codex-cli', '--bin', 'codex')
    $targetProfile = 'debug'
    if ($Release) {
        $cargoArgs += '--release'
        $targetProfile = 'release'
    }

    Invoke-CargoWithFallback -CargoArgs $cargoArgs -SourceDir $SourceDir -RustToolchain $RustToolchain

    $builtExe = Join-Path $SourceDir "target\$targetProfile\codex.exe"
    if (-not (Test-Path -LiteralPath $builtExe -PathType Leaf)) {
        throw "Build completed but codex.exe was not found at $builtExe"
    }

    New-DirectoryIfMissing -Path $OutputDir
    $installedExe = Join-Path $OutputDir 'codex.exe'
    Copy-Item -LiteralPath $builtExe -Destination $installedExe -Force
    return (Resolve-Path -LiteralPath $installedExe).Path
}

function Invoke-CodexShellPathTests {
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [string]$RustToolchain
    )
    $filter = 'test(/(load_config_preserves_windows_shell_path|load_config_rejects_invalid_windows_shell_path|restricted_read_implicitly_allows_configured_windows_shell|default_session_shell_uses_configured_windows_shell_path|configured_windows_shell_path_uses_bash|invalid_windows_shell_path_is_rejected|can_run_on_shell_test)/)'
    $args = @(
        'nextest', 'run',
        '-p', 'codex-core',
        '-E', $filter,
        '--no-fail-fast'
    )
    Invoke-CargoWithFallback -CargoArgs $args -SourceDir $SourceDir -RustToolchain $RustToolchain
}

function Set-CodexDesktopRouting {
    param(
        [Parameter(Mandatory)][string]$CodexCliPath,
        [Parameter(Mandatory)][string]$BashPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$BackupRoot,
        [switch]$SkipUserEnvironment,
        [switch]$SkipConfig
    )

    if (-not $SkipUserEnvironment) {
        [Environment]::SetEnvironmentVariable('CODEX_CLI_PATH', $CodexCliPath, 'User')
        $env:CODEX_CLI_PATH = $CodexCliPath
    }

    if (-not $SkipConfig) {
        Backup-FileIfExists -Path $ConfigPath -BackupRoot $BackupRoot -Label 'config' | Out-Null
        Set-TomlStringKey -Path $ConfigPath -Section 'windows' -Key 'shell_path' -Value $BashPath
        Set-TomlStringKey -Path $ConfigPath -Section 'mcp_servers.node_repl.env' -Key 'CODEX_CLI_PATH' -Value $CodexCliPath
    }
}

function Save-RtkManagerState {
    param(
        [Parameter(Mandatory)][string]$StateFile,
        [Parameter(Mandatory)][hashtable]$State
    )
    $json = $State | ConvertTo-Json -Depth 5
    Write-Utf8NoBomFile -Path $StateFile -Content ($json + [Environment]::NewLine)
}

function Read-RtkManagerState {
    param([Parameter(Mandatory)][string]$StateFile)
    if (-not (Test-Path -LiteralPath $StateFile)) {
        return $null
    }
    return (Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json)
}

Export-ModuleMember -Function *-*
