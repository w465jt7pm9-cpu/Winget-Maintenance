<#
.SYNOPSIS
    Erstellt oder aktualisiert eine geplante Aufgabe für automatische
    Winget-Updates.

.DESCRIPTION
    Dieses Skript registriert eine Scheduled Task, welche das
    Winget-Wartungsskript 'Winget Automatic Updates'

    - bei Benutzeranmeldung sowie
    - zusätzlich täglich um 12:00 Uhr

    unter dem lokalen Administratorkonto mit höchsten Privilegien ausführt.

    Eigenschaften:

    - Ausführung unabhängig von Benutzeranmeldungen
    - Höchste Berechtigungsstufe
    - Automatischer Neustart bei Fehlern
    - Keine parallelen Task-Instanzen
    - Nachholen verpasster Ausführungen
    - Optionale Reaktivierung des Computers
    - Idempotente Ausführung (Update statt Duplikat)

.NOTES
    Autor      : CTN
    Version    : 1.1.0
    PowerShell : 5.1 oder neuer
    Lizenz     : Intern

.CHANGELOG
    1.1.0
        - Zusätzlicher Anmeldetrigger
        - Täglicher Fallback-Trigger um 12:00 Uhr
        - Erweiterte Dokumentation

    1.0.0
        - Erstversion
#>

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

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

# SYSTEM-Konto:
# - Keine Anmeldedaten erforderlich
# - Keine Passwortabläufe
# - Geeignet für Wartungsaufgaben
# - Höchste lokale Berechtigungen
$Principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
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
Write-Host 'Konto           : SYSTEM'
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