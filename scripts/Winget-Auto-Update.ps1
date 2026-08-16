<#
.SYNOPSIS
    Automated application maintenance using Winget.

.DESCRIPTION
    Updates installed Winget-managed packages, performs source validation,
    handles logging and log retention, and is intended to run as a scheduled task.

.NOTES
    Author  : CTN
    Version : 1.2.0
    License : MIT
#>

# Bekannte Reparaturmaßnahme bei Fehler 0x8A15000F:
#
# Add-AppxPackage -Register -DisableDevelopmentMode "$((Get-AppxPackage Microsoft.Winget.Source -AllUsers).InstallLocation)\AppxManifest.xml"
# Anschließend:
#
# winget source reset --force
# winget source update

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

# Basisverzeichnis für Skriptdaten und Logs.
# ProgramData ist systemweit verfügbar und unabhängig vom Benutzerprofil.
$BaseDir = Join-Path $env:ProgramData 'WingetMaintenance'

# Verzeichnis für Protokolldateien.
$LogDir = Join-Path $BaseDir 'Logs'

# Aufbewahrungsdauer für Logdateien.
$LogRetentionDays = 90

# Maximale Anzahl historischer Logdateien.
$MaxLogFiles = 100

# ---------------------------------------------------------------------------
# Verzeichnisstruktur sicherstellen
# ---------------------------------------------------------------------------

if (-not (Test-Path $LogDir)) {
    New-Item `
        -Path $LogDir `
        -ItemType Directory `
        -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Log-Retention
# ---------------------------------------------------------------------------

try {

    # Entfernt Logs, die älter als die konfigurierte
    # Aufbewahrungsdauer sind.
    $RetentionDate = (Get-Date).AddDays(-$LogRetentionDays)

    Get-ChildItem `
        -Path $LogDir `
        -Filter '*.log' `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LastWriteTime -lt $RetentionDate
    } |
    Remove-Item `
        -Force `
        -ErrorAction Stop

    # Zusätzliche Begrenzung auf eine maximale Anzahl Logdateien.
    Get-ChildItem `
        -Path $LogDir `
        -Filter '*.log' `
        -File `
        -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip $MaxLogFiles |
    Remove-Item `
        -Force `
        -ErrorAction SilentlyContinue

}
catch {

    # Fehler bei der Log-Bereinigung sollen die
    # eigentliche Wartung nicht verhindern.
    Write-Warning "Log-Retention fehlgeschlagen: $($_.Exception.Message)"

}

# ---------------------------------------------------------------------------
# Winget-Verfügbarkeit prüfen
# ---------------------------------------------------------------------------

# Ermittelt den tatsächlichen Pfad zu winget.exe.
# Dies ist robuster als ein späterer Aufruf über PATH.
$WingetCommand = Get-Command `
    -Name 'winget.exe' `
    -ErrorAction SilentlyContinue

if (-not $WingetCommand) {

    throw @'
winget.exe wurde nicht gefunden.

Moegliche Ursachen:

- Microsoft App Installer ist nicht installiert.
- Die Installation ist beschädigt.
- Die App wurde entfernt.
- Die PATH-Konfiguration ist fehlerhaft.

Installieren oder reparieren Sie den Microsoft App Installer
und fuehren Sie das Skript anschließend erneut aus.
'@

}

# Vollständiger Pfad zur ermittelten Winget-Installation.
$WingetExe = $WingetCommand.Source

# ---------------------------------------------------------------------------
# Logdatei vorbereiten
# ---------------------------------------------------------------------------

# Jede Ausführung erhält ein eigenes Logfile,
# um Auditing und Fehleranalyse zu ermöglichen.
$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

$LogFile = Join-Path `
    $LogDir `
    "Winget_$Timestamp.log"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $FormattedLevel = $Level.PadRight(5)

    Add-Content `
        -Path $LogFile `
        -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$FormattedLevel] $Message" `
        -Encoding UTF8
}

# Logdatei für den aktuellen Lauf initialisieren
New-Item -Path $LogFile -ItemType File -Force | Out-Null
	
try {

    # -----------------------------------------------------------------------
    # Startinformationen
    # -----------------------------------------------------------------------

	Write-Log '=================================================='
	Write-Log 'Winget-Wartung gestartet'
	Write-Log "Computer      : $env:COMPUTERNAME"
	Write-Log "Benutzer      : $env:USERNAME"
	Write-Log "Winget        : $WingetExe"
	Write-Log 'Skriptversion : 1.1.0'
	Write-Log '=================================================='

    # -----------------------------------------------------------------------
    # Winget-Quellen aktualisieren
    # -----------------------------------------------------------------------

	Write-Log 'Pruefe Winget-Quelle ...'
	& $WingetExe search 7zip --source winget *> $null

	if ($LASTEXITCODE -ne 0) {
		throw 'Winget-Quelle ist nicht verfuegbar.'
	}

    Write-Log 'Aktualisiere Winget-Paketquellen ...'
    & $WingetExe source update

    if ($LASTEXITCODE -ne 0) {
        throw "Fehler beim Aktualisieren der Winget-Paketquellen (ExitCode: $LASTEXITCODE)."
    }

    # -----------------------------------------------------------------------
    # Paketupdates installieren
    # -----------------------------------------------------------------------

    Write-Log 'Pruefe auf Updates ...'
	
	$UpdateStart = Get-Date
	
	$WingetOutput = & $WingetExe upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements 2>&1
	$WingetExitCode = $LASTEXITCODE

	foreach ($Line in $WingetOutput) {
		Write-Log ([string]$Line)
	}

	$UpdateDuration = (Get-Date) - $UpdateStart
	Write-Log "Update-Dauer: $($UpdateDuration.ToString())"

    if ($WingetExitCode -ne 0) {
        throw "Mindestens ein Paketupdate wurde nicht erfolgreich abgeschlossen (ExitCode: $WingetExitCode)."
    }

    # -----------------------------------------------------------------------
    # Erfolgsmeldung
    # -----------------------------------------------------------------------

    Write-Log 'Alle verfuegbaren Updates wurden erfolgreich verarbeitet.'

}
catch {

    # -----------------------------------------------------------------------
    # Fehlerbehandlung
    # -----------------------------------------------------------------------

    Write-Log $_.Exception.Message 'ERROR'

    # Fehler erneut auslösen, damit der geplante Task
    # einen Fehlerstatus zurückliefert.
    throw

}
finally {

    # -----------------------------------------------------------------------
    # Abschlussinformationen
    # -----------------------------------------------------------------------

	Write-Log '=================================================='
	Write-Log 'Winget-Wartung beendet'
	Write-Log "Logdatei  : $LogFile"
	Write-Log '=================================================='

}