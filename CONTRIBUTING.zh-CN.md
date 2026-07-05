# 贡献指南

[English](CONTRIBUTING.md)

感谢你改进这个 marketplace。

## 开发

修改后请验证插件。如果本机安装了 Codex plugin creator helper，可以运行：

```bash
python ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/codex-git-bash-shell
```

也可以通过 Codex 自己验证：把本仓库作为本地 marketplace 添加并安装插件：

```bash
codex plugin marketplace add .
codex plugin add codex-git-bash-shell@codex-git-bash
```

检查 PowerShell 语法：

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

## 发布

1. 更新 `plugins/codex-git-bash-shell/.codex-plugin/plugin.json`。
2. 验证插件。
3. commit 并 push 到 `main`。
4. 用户可以用下面命令刷新：

```bash
codex plugin marketplace upgrade codex-git-bash
codex plugin add codex-git-bash-shell@codex-git-bash
```
