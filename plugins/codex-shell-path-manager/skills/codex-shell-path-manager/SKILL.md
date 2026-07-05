---
name: codex-shell-path-manager
description: Install, verify, repair, or roll back the local Codex Desktop Windows shell_path patch that lets Codex agent sessions use Git Bash instead of native PowerShell. Use when CODEX_CLI_PATH routing is broken after a Codex Desktop update, when ~/.codex/config.toml [windows].shell_path needs repair, when Git Bash is missing or installed in a different path, or when the user wants to recover to the official Codex CLI.
---

# Codex Shell Path Manager

This is a Codex plugin type: it has `.codex-plugin/plugin.json`, is listed in the personal
marketplace, and is installed with `codex plugin add codex-shell-path-manager@personal`.

Use it to maintain the local Windows Codex Desktop setup where:

- a patched `codex.exe` adds `[windows].shell_path`
- Desktop starts its app-server from user env var `CODEX_CLI_PATH`
- `[windows].shell_path` points at Git Bash
- agent sessions start in Git Bash instead of native PowerShell

RTK is only the user's local shell command wrapper in some environments. Do not describe this as an
RTK plugin. When the active AGENTS rules require `rtk`, prefix shell commands with `rtk`; otherwise
the plugin scripts are normal Codex plugin resources.

## Important Boundary

Codex Desktop reads `CODEX_CLI_PATH` when the app-server starts. After install or rollback, tell
the user to restart Codex Desktop and open a new thread. Existing threads may keep the old
app-server and shell.

## Script Entry Points

Resolve the plugin root from this skill path, then run scripts from `<plugin-root>/scripts/`.

Install or repair from Git Bash:

```bash
bash /c/Users/admin/plugins/codex-shell-path-manager/scripts/install.sh
```

Verify:

```bash
bash /c/Users/admin/plugins/codex-shell-path-manager/scripts/verify.sh
```

Rollback:

```bash
bash /c/Users/admin/plugins/codex-shell-path-manager/scripts/rollback.sh
```

When running from PowerShell instead, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\admin\plugins\codex-shell-path-manager\scripts\install.ps1
```

## Install Behavior

`install.ps1`:

1. Detects Git Bash from `-BashPath`, `CODEX_GIT_BASH_PATH`, common Git for Windows paths, or `PATH`.
2. If Git Bash is missing, installs official Git for Windows with `winget install --id Git.Git`
   unless `-SkipGitInstall` is passed.
3. Clones Codex source into `~/.codex/codex-shell-path-manager/sources/` unless `-SourceDir` is passed.
4. Applies `patches/codex-windows-shell-path.patch`.
5. Optionally runs targeted tests when `-RunTests` is passed.
6. Builds `codex-cli` and copies `codex.exe` to `~/.codex/bin/codex-shell-path-rtk/codex.exe`.
7. Sets user `CODEX_CLI_PATH`.
8. Updates `[windows].shell_path` and `[mcp_servers.node_repl.env].CODEX_CLI_PATH` in `config.toml`.
9. Writes backups and state under `~/.codex/codex-shell-path-manager/`.

Useful options:

```powershell
-SourceDir <path>       Use an existing Codex checkout.
-BashPath <path>        Force a specific Git Bash path.
-RunTests               Run the targeted shell_path test set before copying codex.exe.
-Release                Build release profile instead of debug.
-SkipGitInstall         Fail instead of installing Git for Windows when bash.exe is missing.
-SkipUserEnvironment    Do not set user CODEX_CLI_PATH.
-SkipConfig             Do not edit config.toml.
```

## Verification Checklist

Run `verify.ps1` after install and again in a new thread after restarting Desktop. A healthy setup
has:

- `~/.codex/bin/codex-shell-path-rtk/codex.exe` present
- user `CODEX_CLI_PATH` equal to that path
- `[windows].shell_path` set to a working Git Bash `bash.exe`
- node_repl `CODEX_CLI_PATH` set for plugin-side helpers
- Git Bash probe can start and run commands

## Rollback Behavior

`rollback.ps1` removes user `CODEX_CLI_PATH` or restores the pre-install value from state, removes
the config keys added by install, and leaves the built patched CLI on disk unless
`-RemoveBuiltCli` is passed.

After rollback, restart Codex Desktop and open a new thread.
