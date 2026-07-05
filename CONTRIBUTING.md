# Contributing

[简体中文](CONTRIBUTING.zh-CN.md)

Thanks for improving this marketplace.

## Development

Validate the plugin after changes. If you have the Codex plugin creator helper installed locally,
run:

```bash
python ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/codex-git-bash-shell
```

You can also validate through Codex itself by adding this repository as a local marketplace and
installing the plugin:

```bash
codex plugin marketplace add .
codex plugin add codex-git-bash-shell@codex-git-bash
```

Check PowerShell syntax:

```powershell
$files = @(
  "plugins\codex-git-bash-shell\scripts\CodexShellPathManager.psm1",
  "plugins\codex-git-bash-shell\scripts\install.ps1",
  "plugins\codex-git-bash-shell\scripts\verify.ps1",
  "plugins\codex-git-bash-shell\scripts\rollback.ps1"
)
foreach ($f in $files) {
  $tokens = $null
  $errs = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs)
  if ($errs.Count) { throw (($errs | ForEach-Object { $_.Message }) -join "; ") }
}
```

## Release

1. Update `plugins/codex-git-bash-shell/.codex-plugin/plugin.json`.
2. Validate the plugin.
3. Commit and push to `main`.
4. Users can refresh with:

```bash
codex plugin marketplace upgrade codex-git-bash
codex plugin add codex-git-bash-shell@codex-git-bash
```
