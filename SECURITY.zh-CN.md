# 安全政策

[English](SECURITY.md)

这个仓库包含一个社区维护插件，用于在 Windows 上构建并运行 patched Codex CLI。

这是一个非官方社区项目，不隶属于 OpenAI，也不代表 OpenAI 背书或赞助。

## 报告方式

如果安全问题不包含私密凭据，可以直接开 GitHub issue。对于敏感报告，请先通过 GitHub
联系仓库 owner，并请求私密披露方式。

## 范围

范围内：

- 不安全的脚本行为
- 意外写入 `~/.codex` 之外的位置
- marketplace 打包问题
- 回滚失败导致 Codex Desktop 处于损坏状态

范围外：

- 上游 Codex 的漏洞
- Git for Windows、Rust、PowerShell 或 Windows 的漏洞
- 本地修改 bundled patch 后造成的问题

## 运行说明

安装器会修改用户级 `CODEX_CLI_PATH` 和 `~/.codex/config.toml`。它不会修改 WindowsApps
里的 Codex 安装目录。
