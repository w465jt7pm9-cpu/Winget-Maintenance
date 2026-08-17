# WingetMaintenance

Automatic application updates via Winget with a focus on transparency, maintainability, and minimal dependencies.

## Features

- Automatic updates for all applications managed by Winget
- Scheduled execution through Windows Task Scheduler
- Winget source health check before every update run
- Detailed UTF-8 logging
- Automatic log retention
- Error handling with meaningful log entries
- Supports unattended execution
- No third-party dependencies

## Components

| File | Description |
|--------|--------|
| `scripts/Winget-Auto-Update.ps1` | Performs the actual update process |
| `scripts/Register-Winget-Auto-Update.ps1` | Creates or updates the scheduled task |
| `scripts/Test-WingetMaintenance.ps1` | Validates the deployment (Winget, scripts, scheduled task) |
| `docs/INSTALL.md` | Installation and setup guide |
| `docs/ARCHITECTURE.md` | Component structure and runtime flow |
| `docs/CONCEPTS.md` | Background concepts and design decisions |
| `docs/TROUBLESHOOTING.md` | Troubleshooting and known solutions |

## Default Behavior

The scheduled task is configured to:

- Run 5 minutes after user logon
- Run daily at 12:00 PM as a fallback
- Execute with elevated privileges
- Automatically catch up on missed runs

## Requirements

- Windows 11
- Winget (Microsoft App Installer)
- PowerShell 5.1 or later
- Administrative privileges

## Installation

The complete installation guide can be found in:

```text
docs/INSTALL.md
```

## Troubleshooting

Known issues and their solutions are documented in:

```text
docs/TROUBLESHOOTING.md
```

## License

MIT License

## Author

CTN
