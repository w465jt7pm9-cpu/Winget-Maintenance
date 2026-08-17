# Installation

This document describes the complete installation, configuration, verification, and maintenance of WingetMaintenance.

---

# Prerequisites

The target system must meet the following requirements:

- Windows 11
- Microsoft App Installer (Winget)
- PowerShell 5.1 or later
- Local administrator privileges
- Internet access for package sources

---

# Verify Winget

Before installation, check whether Winget is available:

```powershell
winget --version
```

Example:

```text
v1.29.290
```

The App Installer should also be installed:

```powershell
Get-AppxPackage Microsoft.DesktopAppInstaller | Select-Object Name,Version
```

---

# Provide the Repository

Clone the repository:

```powershell
git clone <REPOSITORY-URL>
```

Open the working directory:

```powershell
cd WingetMaintenance
```

Alternatively, the repository can be downloaded as a ZIP file and extracted.

---

# Create the Target Directory

WingetMaintenance uses the following working directory by default:

```text
%ProgramData%\WingetMaintenance
```

Create the directory:

```powershell
New-Item -Path "$env:ProgramData\WingetMaintenance" -ItemType Directory -Force
```

---

# Deploy the Scripts

Copy the maintenance script:

```powershell
Copy-Item ".\scripts\Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Copy the task registration script:

```powershell
Copy-Item ".\scripts\Register-Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Copy the validation script:

```powershell
Copy-Item ".\scripts\Test-WingetMaintenance.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

---

# Test Before Deployment

Before rolling out to production, a quick deployment check should be run.
The validation script checks the syntax, Winget availability, and the scheduled task.

Run:

```powershell
& "$env:ProgramData\WingetMaintenance\Test-WingetMaintenance.ps1"
```

Optionally with a mandatory check for the existing task:

```powershell
& "$env:ProgramData\WingetMaintenance\Test-WingetMaintenance.ps1" -RequireTask
```

Expected result:

```text
Deployment-Check erfolgreich: Alle Prüfungen bestanden.
```

If a check fails, the script exits with exit code 1 and displays the error details.

---

# Create the Scheduled Task

The registration script must be run as an administrator so the scheduled task is registered with the correct privileges and the current admin account.

Start PowerShell as an administrator:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File "C:\Repos\WingetMaintenance\scripts\Register-Winget-Auto-Update.ps1"'
```

Alternatively, run it directly from an already elevated window:

```powershell
& "$env:ProgramData\WingetMaintenance\Register-Winget-Auto-Update.ps1"
```

Expected output:

```text
Winget Scheduled Task erfolgreich eingerichtet
```

If the script is started without administrator privileges, it stops with a clear message: "Bitte als Administrator ausführen ..."

---

# Task Configuration

By default, the task is created with the following settings:

| Setting | Value |
|------------|------|
| Account | Administrator account |
| Privileges | Highest |
| Logon | 5 minutes after user logon |
| Fallback | Daily at 12:00 PM |
| Missed runs | Caught up automatically |
| Task restarts | Up to 3 retries |

---

# Verify the Registration

Show the existing task:

```powershell
Get-ScheduledTask -TaskName "Winget Automatic Updates"
```

Show details:

```powershell
Get-ScheduledTaskInfo -TaskName "Winget Automatic Updates"
```

---

# Functional Test

Start a manual test run:

```powershell
Start-ScheduledTask -TaskName "Winget Automatic Updates"
```

Check the status:

```powershell
Get-ScheduledTaskInfo -TaskName "Winget Automatic Updates"
```

Successful execution:

```text
LastTaskResult : 0
```

---

# Check Log Files

Log files are located at:

```text
%ProgramData%\WingetMaintenance\Logs
```

Show all log files:

```powershell
Get-ChildItem "$env:ProgramData\WingetMaintenance\Logs"
```

Show the latest log file:

```powershell
Get-Content ((Get-ChildItem "$env:ProgramData\WingetMaintenance\Logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName)
```

---

# Typical Successful Run

Example:

```text
2026-08-16 12:00:02 [INFO ] Winget-Wartung gestartet
2026-08-16 12:00:02 [INFO ] Pruefe Winget-Quelle ...
2026-08-16 12:00:08 [INFO ] Pruefe auf Updates ...
2026-08-16 12:00:11 [INFO ] Es wurde kein installiertes Paket gefunden, das den Eingabekriterien entspricht.
2026-08-16 12:00:11 [INFO ] Update-Dauer : 00:00:03.1278341
2026-08-16 12:00:11 [INFO ] Alle verfuegbaren Updates wurden erfolgreich verarbeitet.
```

---

# Update the Scripts

Deploy the new version of the maintenance script:

```powershell
Copy-Item ".\scripts\Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Deploy the new version of the registration script:

```powershell
Copy-Item ".\scripts\Register-Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Then update the task:

```powershell
& "$env:ProgramData\WingetMaintenance\Register-Winget-Auto-Update.ps1"
```

---

# Log Retention

The maintenance script automatically cleans up old log files.

Default values:

```text
Retention period : 90 days
Maximum count    : 100 log files
```

Cleanup runs on every execution.

---

# Verify the Winget Source

The health of the Winget source can be checked manually:

```powershell
winget search 7zip --source winget
```

A successful response contains package hits.

---

# Uninstallation

Remove the scheduled task:

```powershell
Unregister-ScheduledTask -TaskName "Winget Automatic Updates" -Confirm:$false
```

Remove the working directory:

```powershell
Remove-Item "$env:ProgramData\WingetMaintenance" -Recurse -Force
```

Optionally remove the repository:

```powershell
Remove-Item "C:\Repos\WingetMaintenance" -Recurse -Force
```

---

# Troubleshooting

For known issues, see:

```text
docs/TROUBLESHOOTING.md
```

In particular:

```text
0x8A15000F
Von der Quelle benoetigte Daten fehlen
```

is documented there in detail.

---

# Recommended Operating Practice

For production use, it is recommended to:

- enable automatic Windows updates
- enable Microsoft Store updates
- let WingetMaintenance run regularly
- occasionally review log files
- keep the repository up to date

This keeps most applications up to date without manual maintenance.