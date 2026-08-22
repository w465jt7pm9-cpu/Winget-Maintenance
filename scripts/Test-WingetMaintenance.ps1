<#
.SYNOPSIS
    Validiert WingetMaintenance vor einem Deployment.

.DESCRIPTION
    Führt eine schnelle Vorabprüfung durch, um sicherzustellen, dass die
    Winget-Installation, die Skripte und die geplante Aufgabe nach einem
    Deployment erwartungsgemäß konfiguriert sind.

    Das Skript prüft nur die Konfiguration und Syntax und führt keine
    Paketaktualisierung oder Task-Änderung aus.

.NOTES
    Author      : CTN
    Version     : 1.0.0
    PowerShell  : 5.1 oder neuer
    License     : MIT
#>

[CmdletBinding()]
param(
    [string]$TaskName = 'Winget Automatic Updates',
    [string]$BaseDir = (Join-Path $env:ProgramData 'WingetMaintenance'),
    [switch]$RequireTask
)

$ErrorActionPreference = 'Stop'

$failures = @()
$checksPassed = 0

function Write-CheckResult {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Message
    )

    if ($Success) {
        Write-Host "[OK] $Name - $Message" -ForegroundColor Green
        $script:checksPassed++
    }
    else {
        Write-Host "[FAIL] $Name - $Message" -ForegroundColor Red
        $script:failures += "$($Name): $Message"
    }
}

function Test-ScriptSyntax {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-CheckResult -Name 'Skript-Datei' -Success $false -Message "Datei nicht gefunden: $Path"
        return
    }

    try {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors.Count -gt 0) {
            $details = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
            Write-CheckResult -Name 'Skript-Syntax' -Success $false -Message "$Path :: $details"
            return
        }

        Write-CheckResult -Name 'Skript-Syntax' -Success $true -Message "$Path"
    }
    catch {
        Write-CheckResult -Name 'Skript-Syntax' -Success $false -Message "Fehler beim Parsen von $Path`: $($_.Exception.Message)"
    }
}

function Test-InstallDirectorySecurity {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-CheckResult -Name 'Verzeichnisrechte' -Success $false -Message "Pfad nicht gefunden: $Path"
        return
    }

    try {
        $usersSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')
        $writeRights = [System.Security.AccessControl.FileSystemRights]::Write -bor
            [System.Security.AccessControl.FileSystemRights]::Modify -bor
            [System.Security.AccessControl.FileSystemRights]::FullControl
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $unsafeRules = @($acl.Access | Where-Object {
            $_.AccessControlType -eq 'Allow' -and
            $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $usersSid.Value -and
            (($_.FileSystemRights -band $writeRights) -ne 0)
        })

        if ($unsafeRules.Count -eq 0) {
            Write-CheckResult -Name 'Verzeichnisrechte' -Success $true -Message 'Nur SYSTEM und Administrators haben Schreibrechte'
        }
        else {
            Write-CheckResult -Name 'Verzeichnisrechte' -Success $false -Message 'Users besitzt Schreibrechte auf dem Installationsverzeichnis'
        }
    }
    catch {
        Write-CheckResult -Name 'Verzeichnisrechte' -Success $false -Message "ACL konnte nicht geprüft werden: $($_.Exception.Message)"
    }
}

Write-Host "== WingetMaintenance Deployment-Check ==" -ForegroundColor Cyan

$MaintenanceScript = Join-Path $BaseDir 'Winget-Auto-Update.ps1'
$RegistrationScript = Join-Path $BaseDir 'Register-Winget-Auto-Update.ps1'
$LogDir = Join-Path $BaseDir 'Logs'

# Winget vorhanden?
try {
    $winget = Get-Command -Name 'winget.exe' -ErrorAction Stop
    Write-CheckResult -Name 'Winget' -Success $true -Message $winget.Source
}
catch {
    Write-CheckResult -Name 'Winget' -Success $false -Message 'winget.exe nicht gefunden oder nicht verfügbar.'
}

# Basisverzeichnis prüfen
if (Test-Path $BaseDir) {
    Write-CheckResult -Name 'Basisverzeichnis' -Success $true -Message $BaseDir
}
else {
    Write-CheckResult -Name 'Basisverzeichnis' -Success $false -Message "Pfad nicht gefunden: $BaseDir"
}

# Log-Verzeichnis prüfen
if (Test-Path $LogDir) {
    Write-CheckResult -Name 'Log-Verzeichnis' -Success $true -Message $LogDir
}
else {
    Write-CheckResult -Name 'Log-Verzeichnis' -Success $false -Message "Pfad nicht gefunden: $LogDir"
}

Test-InstallDirectorySecurity -Path $BaseDir

# Wartungsskript prüfen
Test-ScriptSyntax -Path $MaintenanceScript

# Registrierungs-Skript prüfen
Test-ScriptSyntax -Path $RegistrationScript

# Geplante Aufgabe prüfen
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop

    if ($null -ne $task) {
        Write-CheckResult -Name 'Geplante Aufgabe' -Success $true -Message "Gefunden: $TaskName"

        if ($task.Principal.UserId -and $task.Principal.UserId -ne 'SYSTEM') {
            Write-CheckResult -Name 'Aufgaben-Principal' -Success $true -Message "Admin-Konto erkannt: $($task.Principal.UserId)"
        }
        else {
            Write-CheckResult -Name 'Aufgaben-Principal' -Success $false -Message "Unerwarteter Principal: $($task.Principal.UserId)"
        }

        $hasLogonTrigger = [bool]($task.Triggers | Where-Object {
            $_.TriggerType -eq 'Logon' -or $_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger'
        })
        $hasWeeklyTrigger = [bool]($task.Triggers | Where-Object {
            ($_.TriggerType -eq 'Weekly' -or $_.CimClass.CimClassName -eq 'MSFT_TaskWeeklyTrigger') -and
            ($_.DaysOfWeek -match 'Friday' -or $_.DaysOfWeek -contains 32)
        })

        if ($hasLogonTrigger -and $hasWeeklyTrigger) {
            Write-CheckResult -Name 'Task-Trigger' -Success $true -Message 'Anmelde- und Freitagstrigger registriert'
        }
        else {
            Write-CheckResult -Name 'Task-Trigger' -Success $false -Message 'Erwarteter Anmelde- oder Freitagstrigger fehlt'
        }

        if ($task.Actions.Count -ge 1) {
            Write-CheckResult -Name 'Task-Aktion' -Success $true -Message "Aktion erkannt: $($task.Actions[0].Execute)"
        }
        else {
            Write-CheckResult -Name 'Task-Aktion' -Success $false -Message 'Keine Task-Aktion gefunden'
        }
    }
}
catch {
    if ($RequireTask) {
        Write-CheckResult -Name 'Geplante Aufgabe' -Success $false -Message "Task '$TaskName' wurde nicht gefunden: $($_.Exception.Message)"
    }
    else {
        Write-Host "[WARN] Geplante Aufgabe - Task '$TaskName' nicht vorhanden, aber Prüfung läuft im Optional-Modus." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Prüfungen erfolgreich: $checksPassed" -ForegroundColor Cyan

if ($failures.Count -gt 0) {
    Write-Host "" 
    Write-Host 'Fehlermeldungen:' -ForegroundColor Yellow
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }

    Write-Host "" 
    Write-Host 'Deployment sollte nicht fortgesetzt werden.' -ForegroundColor Red
    exit 1
}

Write-Host "" 
Write-Host 'Deployment-Check erfolgreich: Alle Prüfungen bestanden.' -ForegroundColor Green
exit 0
