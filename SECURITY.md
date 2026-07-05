# Security Policy

[简体中文](SECURITY.zh-CN.md)

This repository contains a community maintenance plugin that builds and runs a patched Codex CLI on
Windows.

This is an unofficial community project and is not affiliated with, endorsed by, or sponsored by
OpenAI.

## Reporting

Open a GitHub issue for security concerns that do not expose private credentials. For sensitive
reports, contact the repository owner through GitHub first and request a private disclosure path.

## Scope

In scope:

- unsafe script behavior
- unintended writes outside `~/.codex`
- marketplace packaging issues
- rollback failures that leave Codex Desktop in a broken state

Out of scope:

- vulnerabilities in upstream Codex
- vulnerabilities in Git for Windows, Rust, PowerShell, or Windows
- issues caused by local modifications to the bundled patch

## Operational Notes

The installer edits user-level `CODEX_CLI_PATH` and `~/.codex/config.toml`. It does not modify the
WindowsApps Codex installation.
