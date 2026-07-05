[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'plugins\codex-git-bash-shell\scripts\CodexShellPathManager.psm1'
Import-Module $modulePath -Force -DisableNameChecking

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

function Assert-PathExists {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Message Missing=[$Path]"
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-release-helper-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $assetRoot = Join-Path $tempRoot 'assets'
    $payloadRoot = Join-Path $tempRoot 'payload'
    $outputRoot = Join-Path $tempRoot 'output'
    New-Item -ItemType Directory -Path $assetRoot, $payloadRoot, $outputRoot -Force | Out-Null

    $fakeExe = Join-Path $payloadRoot 'codex.exe'
    [System.IO.File]::WriteAllText($fakeExe, 'fake codex exe')

    $zipPath = Join-Path $assetRoot 'codex-git-bash-windows-x86_64.zip'
    Compress-Archive -Path $fakeExe -DestinationPath $zipPath -Force
    $sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()

    $shaFile = Join-Path $assetRoot 'SHA256SUMS.txt'
    [System.IO.File]::WriteAllText($shaFile, "$sha  codex-git-bash-windows-x86_64.zip`n")

    $buildInfo = Join-Path $assetRoot 'BUILD_INFO.json'
    [System.IO.File]::WriteAllText($buildInfo, '{"releaseTag":"v-test","upstreamRef":"test-ref"}')

    $installed = Install-CodexReleaseBinary `
        -OutputDir $outputRoot `
        -ReleaseAssetBaseUrl $assetRoot `
        -ExpectedSha256 $sha

    $expectedExe = Join-Path $outputRoot 'codex.exe'
    Assert-Equal -Actual $installed -Expected (Resolve-Path -LiteralPath $expectedExe).Path -Message 'installed path should point at output codex.exe'
    Assert-PathExists -Path $expectedExe -Message 'codex.exe should be installed'
    Assert-Equal -Actual ([System.IO.File]::ReadAllText($expectedExe)) -Expected 'fake codex exe' -Message 'installed exe content should match extracted payload'

    $badHashFailed = $false
    try {
        Install-CodexReleaseBinary `
            -OutputDir (Join-Path $tempRoot 'bad-output') `
            -ReleaseAssetBaseUrl $assetRoot `
            -ExpectedSha256 ('0' * 64) | Out-Null
    } catch {
        $badHashFailed = $_.Exception.Message -like '*SHA256*'
    }
    Assert-Equal -Actual $badHashFailed -Expected $true -Message 'bad expected hash should fail'

    Write-Host 'release helper tests passed'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
