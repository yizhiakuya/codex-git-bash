[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$installScript = Join-Path $repoRoot 'plugins\codex-git-bash-shell\scripts\install.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-install-release-test-" + [guid]::NewGuid().ToString('N'))

function Assert-Equal {
    param(
        [Parameter(Mandatory)]$Actual,
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Actual -ne $Expected) {
        throw "$Message Expected=[$Expected] Actual=[$Actual]"
    }
}

function New-TestReleaseAssets {
    param([Parameter(Mandatory)][string]$AssetRoot)

    $payloadRoot = Join-Path $AssetRoot 'payload'
    New-Item -ItemType Directory -Path $payloadRoot -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $payloadRoot 'codex.exe'), 'fake release codex')

    $zipPath = Join-Path $AssetRoot 'codex-git-bash-windows-x86_64.zip'
    Compress-Archive -Path (Join-Path $payloadRoot 'codex.exe') -DestinationPath $zipPath -Force
    $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText((Join-Path $AssetRoot 'SHA256SUMS.txt'), "$sha  codex-git-bash-windows-x86_64.zip`n")
    [System.IO.File]::WriteAllText((Join-Path $AssetRoot 'BUILD_INFO.json'), '{"releaseTag":"v-test"}')
    return $sha
}

function Resolve-InstalledExe {
    param([Parameter(Mandatory)][string]$CodexHome)
    return (Join-Path $CodexHome 'bin\codex-git-bash\codex.exe')
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $assetRoot = Join-Path $tempRoot 'assets'
    $codexHome = Join-Path $tempRoot 'codex-home'
    New-Item -ItemType Directory -Path $assetRoot, $codexHome -Force | Out-Null

    $bashPath = (Get-Command bash.exe -ErrorAction Stop).Source
    $sha = New-TestReleaseAssets -AssetRoot $assetRoot

    $env:CODEX_HOME = $codexHome
    & $installScript `
        -UseReleaseBinary `
        -ReleaseAssetBaseUrl $assetRoot `
        -ExpectedReleaseSha256 $sha `
        -BashPath $bashPath `
        -SkipGitInstall `
        -SkipUserEnvironment `
        -SkipConfig

    if ($LASTEXITCODE -ne 0) {
        throw "install.ps1 exited with $LASTEXITCODE"
    }

    $installedExe = Resolve-InstalledExe -CodexHome $codexHome
    Assert-Equal -Actual ([System.IO.File]::ReadAllText($installedExe)) -Expected 'fake release codex' -Message 'release binary mode should install extracted codex.exe'

    $state = Get-Content -LiteralPath (Join-Path $codexHome 'codex-git-bash-shell\state.json') -Raw | ConvertFrom-Json
    Assert-Equal -Actual $state.installMode -Expected 'release-binary' -Message 'state should record release-binary mode'
    Assert-Equal -Actual $state.releaseAssetBaseUrl -Expected $assetRoot -Message 'state should record release asset base'

    $incompatibleFailed = $false
    try {
        & $installScript -UseReleaseBinary -RunTests -BashPath $bashPath -SkipGitInstall -SkipUserEnvironment -SkipConfig
    } catch {
        $incompatibleFailed = $_.Exception.Message -like '*only valid when building from source*'
    }
    Assert-Equal -Actual $incompatibleFailed -Expected $true -Message 'release mode should reject source-only options'

    Write-Host 'install release mode tests passed'
} finally {
    Remove-Item Env:\CODEX_HOME -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
