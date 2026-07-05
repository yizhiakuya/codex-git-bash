# Codex Shell Path Marketplace

Git marketplace for `codex-shell-path-manager`, a local Codex plugin that installs and maintains
the Windows Codex Desktop shell_path patch for Git Bash agent sessions.

Add the marketplace:

```bash
codex plugin marketplace add https://github.com/yizhiakuya/codex-shell-path-marketplace --ref main
```

Install the plugin:

```bash
codex plugin add codex-shell-path-manager@codex-shell-path
```

Upgrade the marketplace snapshot:

```bash
codex plugin marketplace upgrade codex-shell-path
```
