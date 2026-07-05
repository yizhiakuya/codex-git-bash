# Contributing

Thanks for improving this marketplace.

## Development

Validate the plugin after changes. If you have the Codex plugin creator helper installed locally,
run:

```bash
python ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/codex-shell-path-manager
```

You can also validate through Codex itself by adding this repository as a local marketplace and
installing the plugin:

```bash
codex plugin marketplace add .
codex plugin add codex-shell-path-manager@codex-shell-path
```

Check PowerShell syntax:

```powershell
$files = @(
  "plugins\codex-shell-path-manager\scripts\CodexShellPathManager.psm1",
  "plugins\codex-shell-path-manager\scripts\install.ps1",
  "plugins\codex-shell-path-manager\scripts\verify.ps1",
  "plugins\codex-shell-path-manager\scripts\rollback.ps1"
)
foreach ($f in $files) {
  $tokens = $null
  $errs = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs)
  if ($errs.Count) { throw (($errs | ForEach-Object { $_.Message }) -join "; ") }
}
```

## Release

1. Update `plugins/codex-shell-path-manager/.codex-plugin/plugin.json`.
2. Validate the plugin.
3. Commit and push to `main`.
4. Users can refresh with:

```bash
codex plugin marketplace upgrade codex-shell-path
codex plugin add codex-shell-path-manager@codex-shell-path
```
