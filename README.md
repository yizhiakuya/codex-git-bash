# Codex Git Bash Marketplace

English | [简体中文](README.zh-CN.md)

A Git marketplace for `codex-git-bash-shell`, a Codex plugin that helps Windows Codex Desktop
agents start in Git Bash instead of the native Windows PowerShell shell.

This is an unofficial community project. It is not affiliated with, endorsed by, or sponsored by
OpenAI.

This repository packages a maintenance plugin, not a replacement for Codex Desktop. The plugin
builds a patched `codex.exe`, configures Desktop to start that patched CLI through
`CODEX_CLI_PATH`, and writes `[windows].shell_path` in `~/.codex/config.toml`.

## Status

This is a community workaround for Windows shell selection. It is useful while upstream Codex does
not expose a stable built-in `windows.shell_path` setting.

Related upstream discussion:

- <https://github.com/openai/codex/issues/16579>
- <https://github.com/openai/codex/issues/27390>

If upstream Codex later ships this feature, prefer the official implementation.

## Licensing

Project code and documentation are released under the MIT license unless otherwise noted. The
bundled patch targets OpenAI Codex source code and follows the upstream Apache-2.0 notice
requirements. See [NOTICE](NOTICE), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and
[LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt).

## Install The Marketplace

```bash
codex plugin marketplace add https://github.com/yizhiakuya/codex-git-bash --ref main
codex plugin add codex-git-bash-shell@codex-git-bash
```

The marketplace manifest lives at:

```text
.agents/plugins/marketplace.json
```

## Use The Plugin

After installing the plugin, start a new Codex thread and ask:

```text
Use codex-git-bash-shell to repair my Codex Git Bash shell setup.
```

The skill will guide Codex to run the bundled scripts.

You can also run the scripts directly from the installed plugin cache or from this repository:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1 -UseReleaseBinary
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\rollback.ps1
```

Print script help:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1 -Help
```

## What Install Does

Recommended release-binary install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1 -UseReleaseBinary
```

Source-build install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1
```

`install.ps1`:

1. Finds Git Bash from `-BashPath`, `CODEX_GIT_BASH_PATH`, common Git for Windows paths, or `PATH`.
2. Installs Git for Windows with `winget install Git.Git` if Git Bash is missing, unless
   `-SkipGitInstall` is used.
3. With `-UseReleaseBinary`, downloads `codex-git-bash-windows-x86_64.zip` from GitHub Releases,
   verifies `SHA256SUMS.txt`, and copies the patched executable to
   `~/.codex/bin/codex-git-bash/codex.exe`.
4. Without `-UseReleaseBinary`, clones `https://github.com/openai/codex.git` into
   `~/.codex/codex-git-bash-shell/sources/` unless `-SourceDir` is provided.
5. Applies `plugins/codex-git-bash-shell/patches/codex-windows-shell-path.patch`.
6. Optionally runs targeted tests with `-RunTests`.
7. Builds `codex-cli` and copies the patched executable to
   `~/.codex/bin/codex-git-bash/codex.exe`.
8. Sets user `CODEX_CLI_PATH` to the patched executable.
9. Updates `~/.codex/config.toml`:

```toml
[windows]
shell_path = "C:\\Program Files\\Git\\bin\\bash.exe"

[mcp_servers.node_repl.env]
CODEX_CLI_PATH = "C:\\Users\\you\\.codex\\bin\\codex-git-bash\\codex.exe"
```

10. Stores backups and state under `~/.codex/codex-git-bash-shell/`.

The script does not modify the WindowsApps Codex installation.

## Requirements

- Windows Codex Desktop
- PowerShell
- Git for Windows, or `winget` so the installer can install it. `winget --silent` may still show
  a Windows prompt or require admin rights depending on the machine policy.
- Network access for GitHub Releases when using `-UseReleaseBinary`.
- Rust/Cargo toolchain capable of building Codex CLI when building from source. The installer first
  tries the pinned `1.95-x86_64-pc-windows-msvc` toolchain and falls back to the default Cargo
  toolchain.
- Network access for cloning Codex source unless `-SourceDir` is used when building from source.

Release binaries are unofficial community builds and are currently unsigned, so Windows SmartScreen
may warn before first use. Each release includes `SHA256SUMS.txt` and `BUILD_INFO.json`.

## Verify

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\verify.ps1
```

Healthy output should show:

- patched `codex.exe` exists
- user `CODEX_CLI_PATH` points at the patched CLI
- `[windows].shell_path` is set
- Git Bash starts successfully

Restart Codex Desktop and open a new thread after install or rollback. Existing threads may keep an
old app-server process.

## Upgrade

Refresh the marketplace and reinstall the plugin:

```bash
codex plugin marketplace upgrade codex-git-bash
codex plugin add codex-git-bash-shell@codex-git-bash
```

Then run the installer again:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1 -UseReleaseBinary
```

## Rollback

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\rollback.ps1
```

Rollback restores or removes user `CODEX_CLI_PATH`, removes the config keys added by install, and
leaves the built patched CLI on disk unless `-RemoveBuiltCli` is used.

## Repository Layout

```text
.agents/plugins/marketplace.json
plugins/codex-git-bash-shell/
  .codex-plugin/plugin.json
  skills/codex-git-bash-shell/SKILL.md
  scripts/
  patches/codex-windows-shell-path.patch
```

## Safety Notes

- Review the patch before running install.
- The installer edits user-level environment variables and `~/.codex/config.toml`.
- The installer creates backups under `~/.codex/codex-git-bash-shell/backups/`.
- This is a local maintenance tool. It is not an official OpenAI plugin.
- The bundled patch targets OpenAI Codex source code, which is licensed under Apache-2.0. See
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [NOTICE](NOTICE), and
  [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt).
