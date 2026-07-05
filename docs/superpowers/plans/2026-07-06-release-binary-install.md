# Release Binary Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional GitHub Releases binary install path while preserving the current build-from-source path.

**Architecture:** Keep `install.ps1` as the user entry point. Add release asset helpers to `CodexShellPathManager.psm1`, wire `-UseReleaseBinary` into install flow, and add a GitHub Actions workflow that builds the patched Windows CLI and uploads a zip, SHA256 file, build metadata, and notices.

**Tech Stack:** PowerShell 5+, GitHub Actions Windows runner, GitHub CLI for validation, Codex plugin validation helpers.

---

### Task 1: Release Asset Helper

**Files:**
- Modify: `plugins/codex-git-bash-shell/scripts/CodexShellPathManager.psm1`
- Create: `tests/release-helper-tests.ps1`

- [ ] Write a PowerShell test that creates a fake release directory with `codex-git-bash-windows-x86_64.zip`, `SHA256SUMS.txt`, and `BUILD_INFO.json`, then expects the helper to verify SHA256, extract `codex.exe`, copy it to a target directory, and return the installed path.
- [ ] Run the test before implementing the helper and confirm it fails because `Install-CodexReleaseBinary` is not defined.
- [ ] Implement `Install-CodexReleaseBinary`, `Get-GitHubReleaseMetadata`, and local extraction/hash helpers.
- [ ] Run the test again and confirm it passes.

### Task 2: Installer Switches

**Files:**
- Modify: `plugins/codex-git-bash-shell/scripts/install.ps1`
- Modify: `plugins/codex-git-bash-shell/skills/codex-git-bash-shell/SKILL.md`

- [ ] Add `-UseReleaseBinary`, `-ReleaseTag`, `-ReleaseAssetBaseUrl`, and `-ExpectedReleaseSha256` parameters to `install.ps1`.
- [ ] Route binary mode through `Install-CodexReleaseBinary` and keep source build mode unchanged.
- [ ] Prevent incompatible options such as `-UseReleaseBinary -RunTests` from silently doing the wrong thing.
- [ ] Update script help and skill docs.

### Task 3: GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] Add manual `workflow_dispatch` inputs for upstream Codex ref, release tag, and prerelease flag.
- [ ] Checkout this repository and `openai/codex`, apply the patch, build `codex-cli --release`, stage `codex.exe`, notices, and build metadata.
- [ ] Generate `codex-git-bash-windows-x86_64.zip`, `SHA256SUMS.txt`, and `BUILD_INFO.json`.
- [ ] Create or update the GitHub Release and upload the assets.

### Task 4: Documentation And Validation

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `CHANGELOG.md`
- Modify: `CHANGELOG.zh-CN.md`
- Modify: `plugins/codex-git-bash-shell/.codex-plugin/plugin.json`

- [ ] Document the recommended release-binary install command and source-build fallback.
- [ ] Document release asset names, SHA256 verification, unsigned binary warning, and build provenance.
- [ ] Update cachebuster version.
- [ ] Run plugin validation, skill validation, PowerShell parser validation, helper tests, local plugin reinstall, and remote marketplace install.
- [ ] Commit and push.
