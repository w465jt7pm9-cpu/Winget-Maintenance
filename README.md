# WingetMaintenance

Automatic application updates via Winget with a focus on transparency, maintainability, and minimal dependencies.

## Features

- Automatic updates for all applications managed by Winget
- Scheduled execution through Windows Task Scheduler
- Winget source refresh before every update run
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

- Run every Friday at 12:00 PM
- Check after user logon only when the last successful Friday run is more than 7 days old
- Execute with elevated privileges

## Manual override

For a one-off run without the Friday-success gate, start the script with the optional switch:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ProgramData\WingetMaintenance\Winget-Auto-Update.ps1" -SkipFridayCheck
```

This is useful for manual maintenance runs or testing after an update was already applied outside the normal schedule.

## Installation

See [docs/INSTALL.md](docs/INSTALL.md) for prerequisites, installation, and verification.
Known issues are documented in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## License

MIT License

## Author

CTN
