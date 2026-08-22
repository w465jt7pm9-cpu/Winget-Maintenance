# Troubleshooting

This document lists known issues, their causes, and how to resolve them.

---

# `winget.exe` was not found

**Symptom**

The maintenance script fails immediately with:

```text
winget.exe wurde nicht gefunden.
```

**Possible causes**

- The Microsoft App Installer is not installed.
- The installation is corrupted.
- The app was removed.
- The `PATH` configuration is broken.

**Resolution**

Install or repair the Microsoft App Installer, then run the script again:

```powershell
Get-AppxPackage Microsoft.DesktopAppInstaller | Select-Object Name,Version
```

If the package is missing, install it from the Microsoft Store or via `winget`/`Add-AppxPackage`.

---

# Winget source is not reachable

**Symptom**

The maintenance script fails while updating the Winget source with:

```text
Fehler beim Aktualisieren der Winget-Paketquellen
```

The maintenance script uses `winget source update` to validate and refresh the source before updating packages.

**Possible causes**

- No internet connectivity.
- The Winget source registration is corrupted.
- The `Microsoft.Winget.Source` AppX package is broken.

**Resolution**

Reset and update the Winget source:

```powershell
winget source reset --force
winget source update
```

---

# Error `0x8A15000F`

**Symptom**

Winget commands fail with error code `0x8A15000F`, typically related to a corrupted or unregistered `Microsoft.Winget.Source` package.

**Resolution**

Re-register the AppX package, then reset the source:

```powershell
Add-AppxPackage -Register -DisableDevelopmentMode "$((Get-AppxPackage Microsoft.Winget.Source -AllUsers).InstallLocation)\AppxManifest.xml"
```

Followed by:

```powershell
winget source reset --force
winget source update
```

---

# `source update` or `upgrade --all` fails with a non-zero exit code

**Symptom**

The log contains an error such as:

```text
Fehler beim Aktualisieren der Winget-Paketquellen (ExitCode: <code>)
```

or

```text
Mindestens ein Paketupdate wurde nicht erfolgreich abgeschlossen (ExitCode: <code>)
```

**Possible causes**

- One or more packages failed to upgrade (e.g., blocked by a running process, missing permissions, or an incompatible installer).
- A transient network issue during source update.

**Resolution**

1. Open the latest log file in `%ProgramData%\WingetMaintenance\Logs` and inspect the raw Winget output that precedes the error — it identifies which package(s) failed.
2. Re-run the failing upgrade manually for more detail:

   ```powershell
   winget upgrade --all --source winget --accept-source-agreements --accept-package-agreements
   ```

3. If a specific package consistently fails, try upgrading it individually or excluding it, and check for vendor-specific installer issues.

---

# Registration script must be run as Administrator

**Symptom**

`Register-Winget-Auto-Update.ps1` fails with:

```text
Bitte als Administrator ausführen, damit die geplante Aufgabe mit Admin-Rechten registriert wird.
```

**Cause**

The script must run elevated to register a scheduled task with the `Highest` run level and a specific principal.

**Resolution**

Start PowerShell as Administrator, then re-run the script:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File "C:\Repos\WingetMaintenance\scripts\Register-Winget-Auto-Update.ps1"'
```

---

# Maintenance script not found during registration

**Symptom**

`Register-Winget-Auto-Update.ps1` fails with:

```text
Winget-Wartungsskript wurde nicht gefunden: <path>
```

**Cause**

The registration script expects `Winget-Auto-Update.ps1` to already exist at:

```text
%ProgramData%\WingetMaintenance\Winget-Auto-Update.ps1
```

**Resolution**

Copy the maintenance script to that location before running the registration script:

```powershell
Copy-Item ".\scripts\Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

---

# PowerShell executable not found

**Symptom**

`Register-Winget-Auto-Update.ps1` fails with:

```text
PowerShell wurde nicht gefunden: <path>
```

**Cause**

The script expects Windows PowerShell at:

```text
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
```

**Resolution**

Verify that Windows PowerShell 5.1 is installed and not removed or blocked by system policy. This is a built-in Windows component and should normally always be present; check for a heavily customized or stripped-down Windows image if it is missing.

---

# Scheduled task does not run / "Last Run Result" is non-zero

**Symptom**

`Get-ScheduledTaskInfo -TaskName "Winget Automatic Updates"` shows a non-zero `LastTaskResult`.

**Resolution**

1. Check the latest log file in `%ProgramData%\WingetMaintenance\Logs` for the logged `ERROR` entry and exception message.
2. Confirm the task's principal and triggers are still correctly configured:

   ```powershell
   Get-ScheduledTask -TaskName "Winget Automatic Updates" | Select-Object -ExpandProperty Principal
   Get-ScheduledTask -TaskName "Winget Automatic Updates" | Select-Object -ExpandProperty Triggers
   ```

3. If the configuration looks wrong (e.g., after a Windows update or manual edit), simply re-run `Register-Winget-Auto-Update.ps1` as Administrator — it removes and re-creates the task idempotently.

---

# Deployment check reports failures

**Symptom**

`Test-WingetMaintenance.ps1` exits with code `1` and prints:

```text
Deployment sollte nicht fortgesetzt werden.
```

**Resolution**

Review the `[FAIL]` lines printed above the summary — each one names the specific check (e.g., `Winget`, `Skript-Syntax`, `Geplante Aufgabe`, `Aufgaben-Principal`, `Task-Trigger`, `Task-Aktion`) and a description of what was expected. Address each failure individually:

| Failed check | Typical fix |
|---|---|
| `Winget` | Install/repair the Microsoft App Installer |
| `Basisverzeichnis` / `Log-Verzeichnis` | Re-run the directory setup step from [INSTALL.md](./INSTALL.md) |
| `Skript-Syntax` | Re-copy the script file; check for corruption during deployment/packaging |
| `Geplante Aufgabe` | Run `Register-Winget-Auto-Update.ps1` as Administrator |
| `Aufgaben-Principal` | Re-register the task under an administrator account (not `SYSTEM`) |
| `Task-Trigger` / `Task-Aktion` | Re-register the task; do not manually edit it outside the registration script |

Re-run the check after applying fixes:

```powershell
& "$env:ProgramData\WingetMaintenance\Test-WingetMaintenance.ps1" -RequireTask
```

---

# Log files are missing or not being cleaned up

**Symptom**

No log files appear, or old log files are not being removed.

**Possible causes**

- The scheduled task never ran (see the section above).
- `%ProgramData%\WingetMaintenance\Logs` was manually deleted and not recreated (the script recreates it automatically on the next run).
- Retention only removes files older than 90 days or beyond the newest 100 — recent files are expected to remain.

**Resolution**

Retention failures are logged as warnings and do not stop the update run. Check the log file for a line such as:

```text
Log-Retention fehlgeschlagen: <message>
```

This usually indicates a permissions issue on the `Logs` folder. Verify the executing account has write access to `%ProgramData%\WingetMaintenance\Logs`.

---

## Related Documentation

- [docs/INSTALL.md](./INSTALL.md) — installation and setup steps
- [docs/ARCHITECTURE.md](./ARCHITECTURE.md) — component structure and runtime flow
- [docs/CONCEPTS.md](./CONCEPTS.md) — background concepts and design decisions
