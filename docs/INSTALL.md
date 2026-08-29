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

The registration script protects this directory automatically. Only `SYSTEM`
and local administrators retain write access to the scripts, task definition,
and logs.

---

# Deploy the Scripts

The recommended way is to use the deployment helper script, which copies the current repository versions into `%ProgramData%\WingetMaintenance` and re-registers the scheduled task. Run it elevated:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\Repos\WingetMaintenance\scripts\Deploy-WingetMaintenance.ps1"'
```

Alternatively, when an elevated shell is already open:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\Deploy-WingetMaintenance.ps1"
```

Manual copy is still possible:

```powershell
Copy-Item ".\scripts\Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
Copy-Item ".\scripts\Register-Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
Copy-Item ".\scripts\Test-WingetMaintenance.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

---

# Test Before Deployment

Before rolling out to production, a quick deployment check should be run.
The validation script checks the syntax, Winget availability, directory permissions, and the scheduled task.

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
| Main run | Every Friday at 12:00 PM |
| Logon fallback | Only when the last successful Friday run is more than 7 days old |
| Missed runs | Caught up automatically |
| Task restarts | Up to 3 retries |

Verify the protection:

```powershell
icacls "$env:ProgramData\WingetMaintenance"
```

The output should not grant write permissions to `Users` or other untrusted accounts.

Updates are restricted to identified packages from the `winget` source. Packages
that Winget cannot identify are not updated automatically.

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

## Manual override for a single run

To bypass the Friday-success check and trigger the update logic immediately, run the maintenance script directly with the switch:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ProgramData\WingetMaintenance\Winget-Auto-Update.ps1" -SkipFridayCheck
```

This is intended for manual maintenance or validation runs only. The default scheduled task behavior remains unchanged unless the switch is explicitly used.

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

For known issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).