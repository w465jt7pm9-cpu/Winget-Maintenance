# Concepts

This document explains the background concepts and design decisions behind WingetMaintenance. It complements [ARCHITECTURE.md](./ARCHITECTURE.md), which describes *how* the components work, by explaining *why* they work that way.

## What is Winget?

Winget (Windows Package Manager) is Microsoft's built-in command-line package manager, shipped as part of the **App Installer**. It can install, upgrade, and remove applications from configured sources (primarily the community `winget` source). WingetMaintenance relies entirely on the `winget.exe` CLI — it does not use any private API or additional package manager.

The project refreshes the source with `winget source update` and upgrades all installed packages with `winget upgrade --all --include-unknown --silent`.

## Why a Scheduled Task instead of a service?

A Windows Service would require a long-running process, a separate installer, and its own privilege/account management. A **Scheduled Task** is simpler:

- Runs on demand or on a schedule, then exits — no persistent memory/CPU usage.
- Built into Windows, no additional runtime or service framework required.
- Exit codes and run history are natively tracked by Task Scheduler (`Get-ScheduledTaskInfo`).
- Easy to inspect, modify, or remove using standard Windows tools (`taskschd.msc`, `Get-ScheduledTask`).

## Why two triggers (logon + weekly)?

Relying on a single trigger creates blind spots:

- **Logon-only** would never run on machines that stay logged in for days without reboot/relogon.
- **Weekly-only** would delay updates on machines that are frequently restarted but rarely stay on until the fixed time.

The weekly trigger covers long-running sessions. The logon trigger catches machines that were offline at the scheduled time, but the script suppresses it when a successful Friday run occurred within the last seven days. Its 5-minute delay avoids contention during logon.

## Why run as the administrator account instead of SYSTEM?

Winget's per-user integrations behave more predictably in the administrator's security context. The task therefore uses the current administrator with `S4U` and `Highest` run level.

## Why store data in `ProgramData` instead of a user profile?

`%ProgramData%` provides a stable, machine-wide location for scripts and shared logs.

## Why timestamped, per-run log files?

Each execution creates a new `Winget_<yyyy-MM-dd_HH-mm-ss>.log` file. This avoids concurrent writes, simplifies correlation with Task Scheduler, and makes retention straightforward.

## Why log retention (age- and count-based)?

Unattended, recurring tasks can silently accumulate log files indefinitely. Two independent limits keep this in check:

- **Age-based**: files older than 90 days are deleted, since they are unlikely to be useful for troubleshooting recent issues.
- **Count-based**: only the newest 100 files are kept, protecting against unexpectedly frequent runs filling the disk.

Retention failures are warnings and never abort the update.

## Why fail loudly instead of swallowing errors?

The maintenance script re-throws any error after logging it. This is intentional: a scheduled task that always reports "success" regardless of outcome provides false confidence. By exiting with a non-zero code on failure:

- Task Scheduler's "Last Run Result" accurately reflects whether the run succeeded.
- Monitoring tools or manual checks (`Get-ScheduledTaskInfo`) can detect failures without parsing log content.
- Administrators are not misled into thinking updates are current when they are not.

## Why a separate validation script (`Test-WingetMaintenance.ps1`)?

Deploying scripts and scheduled tasks via automation (e.g., Intune, GPO, CI/CD) carries the risk of partial or broken deployments (missing files, syntax errors introduced by packaging, a task that failed to register correctly). `Test-WingetMaintenance.ps1` provides a **fast, read-only** way to catch such problems immediately after deployment, before waiting for the next real update cycle to reveal an issue. It intentionally performs no upgrades or task changes, so it is safe to run repeatedly, including in automated pipelines.

## Design Trade-offs

| Decision | Trade-off accepted |
|---|---|
| Scheduled Task instead of a Windows Service | Slightly less control over precise timing, in exchange for simplicity and no persistent process |
| Admin account + S4U instead of SYSTEM | Requires an administrator to be present/registered; avoids some SYSTEM-context Winget quirks |
| Per-run log files instead of one continuous log | More files to manage, but simpler retention and no concurrency concerns |
| No third-party dependencies | More verbose native PowerShell/Task Scheduler cmdlets, but nothing to install or keep updated |

## Related Documentation

- [docs/ARCHITECTURE.md](./ARCHITECTURE.md) — component structure and runtime flow
- [docs/INSTALL.md](./INSTALL.md) — installation and setup steps
- [docs/TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — known issues and fixes
