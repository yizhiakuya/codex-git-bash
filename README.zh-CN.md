# Codex Git Bash Marketplace

[English](README.md) | 简体中文

这是一个 Git marketplace，提供 `codex-git-bash-shell` Codex 插件。它用于帮助 Windows
Codex Desktop 的 agent 会话从 Git Bash 启动，而不是使用 Windows 原生 PowerShell。

这个仓库打包的是维护型插件，不是 Codex Desktop 的替代品。插件会构建一个打过补丁的
`codex.exe`，通过 `CODEX_CLI_PATH` 让 Desktop 启动这个 patched CLI，并在
`~/.codex/config.toml` 写入 `[windows].shell_path`。

## 状态

这是 Windows shell 选择能力的社区临时方案。适用于上游 Codex 还没有稳定内置
`windows.shell_path` 配置时。

相关上游讨论：

- <https://github.com/openai/codex/issues/16579>
- <https://github.com/openai/codex/issues/27390>

如果以后上游 Codex 正式支持这个功能，应优先使用官方实现。

## 安装 Marketplace

```bash
codex plugin marketplace add https://github.com/yizhiakuya/codex-git-bash --ref main
codex plugin add codex-git-bash-shell@codex-git-bash
```

marketplace manifest 位于：

```text
.agents/plugins/marketplace.json
```

## 使用插件

安装插件后，新开一个 Codex 线程，然后说：

```text
Use codex-git-bash-shell to repair my Codex Git Bash shell setup.
```

skill 会指导 Codex 运行插件内置脚本。

你也可以直接从已安装的插件缓存目录，或从本仓库运行脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\rollback.ps1
```

查看脚本帮助：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1 -Help
```

## 安装脚本做什么

`install.ps1` 会：

1. 从 `-BashPath`、`CODEX_GIT_BASH_PATH`、常见 Git for Windows 路径或 `PATH` 中查找 Git Bash。
2. 如果找不到 Git Bash，则用 `winget install Git.Git` 安装 Git for Windows，除非传入
   `-SkipGitInstall`。
3. 克隆 `https://github.com/openai/codex.git` 到
   `~/.codex/codex-git-bash-shell/sources/`，除非传入 `-SourceDir`。
4. 应用 `plugins/codex-git-bash-shell/patches/codex-windows-shell-path.patch`。
5. 如果传入 `-RunTests`，运行针对性的测试。
6. 构建 `codex-cli`，并把 patched executable 复制到
   `~/.codex/bin/codex-git-bash/codex.exe`。
7. 把用户级 `CODEX_CLI_PATH` 设置为 patched executable。
8. 更新 `~/.codex/config.toml`：

```toml
[windows]
shell_path = "C:\\Program Files\\Git\\bin\\bash.exe"

[mcp_servers.node_repl.env]
CODEX_CLI_PATH = "C:\\Users\\you\\.codex\\bin\\codex-git-bash\\codex.exe"
```

9. 把备份和状态写到 `~/.codex/codex-git-bash-shell/`。

脚本不会修改 WindowsApps 里的 Codex 安装目录。

## 需求

- Windows Codex Desktop
- PowerShell
- Git for Windows；如果没有，需要系统可用 `winget` 以便安装器安装。根据机器策略，
  `winget --silent` 仍可能弹出 Windows 提示或需要管理员权限。
- 能构建 Codex CLI 的 Rust/Cargo toolchain。安装器会先尝试固定的
  `1.95-x86_64-pc-windows-msvc` toolchain，失败后回退到默认 Cargo toolchain。
- 网络访问；如果使用 `-SourceDir` 指向已有源码，则克隆 Codex 源码不需要网络

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\verify.ps1
```

健康状态应显示：

- patched `codex.exe` 存在
- 用户级 `CODEX_CLI_PATH` 指向 patched CLI
- `[windows].shell_path` 已设置
- Git Bash 可以正常启动

安装或回滚后，需要重启 Codex Desktop 并新开线程。已有线程可能继续使用旧 app-server 进程。

## 升级

刷新 marketplace 并重新安装插件：

```bash
codex plugin marketplace upgrade codex-git-bash
codex plugin add codex-git-bash-shell@codex-git-bash
```

然后重新运行安装器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\install.ps1
```

## 回滚

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\plugins\codex-git-bash-shell\scripts\rollback.ps1
```

回滚会恢复或移除用户级 `CODEX_CLI_PATH`，删除安装器写入的 config key。除非传入
`-RemoveBuiltCli`，否则会保留已构建的 patched CLI 文件。

## 仓库结构

```text
.agents/plugins/marketplace.json
plugins/codex-git-bash-shell/
  .codex-plugin/plugin.json
  skills/codex-git-bash-shell/SKILL.md
  scripts/
  patches/codex-windows-shell-path.patch
```

## 安全说明

- 运行安装器前建议先审阅 patch。
- 安装器会修改用户级环境变量和 `~/.codex/config.toml`。
- 安装器会在 `~/.codex/codex-git-bash-shell/backups/` 创建备份。
- 这是本地维护工具，不是 OpenAI 官方插件。
