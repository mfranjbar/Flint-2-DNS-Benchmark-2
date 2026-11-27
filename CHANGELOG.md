# Changelog

Notable user-facing changes are recorded here. The benchmark version remains independent from the original v1 project.

## Unreleased

- Reworked the GitHub README with project badges, a table of contents, feature overview, requirements, copy-ready install and uninstall commands, v1-to-v2 migration details, benchmark methodology, safety notes, and project file guide.
- Hardened the v2 installer with preflight validation, conflict detection, staged file replacement, timestamped backups, and rollback when installation or the post-install check fails.
- Prevented the installer from replacing unrelated command files, command symlinks, dashboard files, or symlinked script targets.
- Hardened the uninstaller so it removes only files carrying the expected v2 identity markers and preserves unrelated paths.
- Expanded lifecycle tests to cover rollback and backup behavior.
- Documented measurement limitations, endpoint drift, and package-preservation behavior.

## 2.0.0

- Added separate v2 benchmark command and installation paths.
- Added public UDP/TCP, Iranian UDP/TCP, DNS-over-TLS, and DNS-over-HTTPS testing.
- Added a fixed ten-row combined report and SSH login dashboard.
- Added pre-check, version, help, installer, uninstaller, and mocked CI tests.
