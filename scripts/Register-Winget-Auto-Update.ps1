<#
.SYNOPSIS
    Registriert die geplante Aufgabe für automatische Winget-Updates.

.DESCRIPTION
    Erstellt oder aktualisiert eine Scheduled Task, die das
    Winget-Wartungsskript unter dem aktuellen Administratorkonto mit
    höchsten Privilegien ausführt.

    Die Aufgabe startet bei Benutzeranmeldung mit 5 Minuten Verzögerung
    und zusätzlich täglich um 12:00 Uhr.

.NOTES
    Author      : CTN
    Version     : 1.2.0
    PowerShell  : 5.1 oder neuer
    License     : MIT

.CHANGELOG
    1.2.0
        - Header aktualisiert und vereinfacht

    1.1.0
        - Zusätzlicher Anmeldetrigger
        - Täglicher Fallback-Trigger um 12:00 Uhr

    1.0.0
        - Erstversion
#>

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

# Konsolenausgabe auf UTF-8 stellen, damit deutsche Sonderzeichen
# korrekt dargestellt werden, auch wenn die Windows-Codepage anders ist.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

# Name der geplanten Aufgabe.
$TaskName = 'Winget Automatic Updates'

# Beschreibung der Aufgabe.
$TaskDescription = 'Automatische Aktualisierung installierter Anwendungen über Winget.'

# Speicherort des Wartungsskripts.
$ScriptPath = Join-Path `
    (Join-Path $env:ProgramData 'WingetMaintenance') `
    'Winget-Auto-Update.ps1'

# Täglicher Fallback-Zeitpunkt.
$ExecutionTime = '12:00'

# ---------------------------------------------------------------------------
# Vorbedingungen prüfen
# ---------------------------------------------------------------------------

# Sicherstellen, dass das Wartungsskript vorhanden ist.
if (-not (Test-Path $ScriptPath)) {
    throw "Winget-Wartungsskript wurde nicht gefunden: $ScriptPath"
}

# Das Registrierungs-Skript muss mit Administratorrechten ausgeführt werden,
# damit die geplante Aufgabe mit dem lokalen Admin-Benutzer und höchsten
# Rechten erstellt werden kann.
$currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    throw 'Bitte als Administrator ausführen, damit die geplante Aufgabe mit Admin-Rechten registriert wird.'
}

# Aktueller Benutzer, der die geplante Aufgabe ausführen soll.
$TaskUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# ---------------------------------------------------------------------------
# PowerShell-Pfad bestimmen
# ---------------------------------------------------------------------------

# Nutzung des systemeigenen PowerShell-Hosts.
# Die Verwendung von SystemRoot vermeidet feste Laufwerksbuchstaben.
$PowerShellExe = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path $PowerShellExe)) {
    throw "PowerShell wurde nicht gefunden: $PowerShellExe"
}

# ---------------------------------------------------------------------------
# Aktion definieren
# ---------------------------------------------------------------------------

# Auszuführender Prozess inkl. Skriptparameter.
$Action = New-ScheduledTaskAction `
    -Execute $PowerShellExe `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

# ---------------------------------------------------------------------------
# Trigger definieren
# ---------------------------------------------------------------------------

# Primärer Trigger:
# Task wird nach jeder Benutzeranmeldung gestartet.
#
# Die Verzögerung von 5 Minuten verhindert Konkurrenz mit
# OneDrive, Defender, Windows Update und sonstigen Autostarts.
$LogonTrigger = New-ScheduledTaskTrigger `
    -AtLogOn

$LogonTrigger.Delay = 'PT5M'

# Sekundärer Trigger:
# Tägliche Ausführung als Sicherheitsnetz.
$DailyTrigger = New-ScheduledTaskTrigger `
    -Daily `
    -At $ExecutionTime

# ---------------------------------------------------------------------------
# Sicherheitskontext definieren
# ---------------------------------------------------------------------------

# Aktueller lokaler Administrator:
# - Ausführung mit Admin-Rechten
# - Verwendung des aktuellen Benutzerkontos
# - Höchste lokale Berechtigungen
$Principal = New-ScheduledTaskPrincipal `
    -UserId $TaskUser `
    -LogonType S4U `
    -RunLevel Highest

# ---------------------------------------------------------------------------
# Erweiterte Einstellungen
# ---------------------------------------------------------------------------

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -WakeToRun `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 15)

# ---------------------------------------------------------------------------
# Task-Objekt erstellen
# ---------------------------------------------------------------------------

$Task = New-ScheduledTask `
    -Action $Action `
    -Trigger @(
        $LogonTrigger
        $DailyTrigger
    ) `
    -Principal $Principal `
    -Settings $Settings `
    -Description $TaskDescription

# ---------------------------------------------------------------------------
# Vorhandene Aufgabe aktualisieren
# ---------------------------------------------------------------------------

$ExistingTask = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

if ($ExistingTask) {

    Write-Host ''
    Write-Host "Vorhandene Aufgabe gefunden: $TaskName"
    Write-Host 'Aufgabe wird aktualisiert ...'

    Unregister-ScheduledTask `
        -TaskName $TaskName `
        -Confirm:$false
}

# ---------------------------------------------------------------------------
# Aufgabe registrieren
# ---------------------------------------------------------------------------

Register-ScheduledTask `
    -TaskName $TaskName `
    -InputObject $Task | Out-Null

# ---------------------------------------------------------------------------
# Ergebnisprüfung
# ---------------------------------------------------------------------------

$RegisteredTask = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction Stop

# ---------------------------------------------------------------------------
# Zusammenfassung ausgeben
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=================================================='
Write-Host 'Winget Scheduled Task erfolgreich eingerichtet'
Write-Host '=================================================='
Write-Host "Name            : $($RegisteredTask.TaskName)"
Write-Host "Skript          : $ScriptPath"
Write-Host "Konto           : $TaskUser"
Write-Host 'Höchste Rechte  : Ja'
Write-Host 'Trigger         : Bei Anmeldung'
Write-Host "Fallback        : Täglich um $ExecutionTime"
Write-Host 'Verpasste Läufe : Werden nachgeholt'
Write-Host 'Neustarts       : Bis zu 3 Wiederholungen'
Write-Host '=================================================='
Write-Host ''

# ---------------------------------------------------------------------------
# Optionaler Testlauf-Hinweis
# ---------------------------------------------------------------------------

Write-Host 'Zum manuellen Testen kann folgender Befehl verwendet werden:'
Write-Host ''
Write-Host "Start-ScheduledTask -TaskName '$TaskName'"
Write-Host ''