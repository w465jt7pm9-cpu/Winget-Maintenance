<#
.SYNOPSIS
    Automated application maintenance using Winget.

.DESCRIPTION
    Updates installed Winget-managed packages, performs source validation,
    handles logging and log retention, and is intended to run as a scheduled task.

.NOTES
    Author  : CTN
    Version : 1.4.0
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

function Get-LastSuccessfulFridayRun {
    Get-ChildItem `
        -Path $LogDir `
        -Filter 'Winget_*.log' `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match '^Winget_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})\.log$'
    } |
    ForEach-Object {
        $RunDate = [datetime]::ParseExact(
            $matches[1],
            'yyyy-MM-dd_HH-mm-ss',
            [Globalization.CultureInfo]::InvariantCulture
        )

        if (
            $RunDate.DayOfWeek -eq [DayOfWeek]::Friday -and
            (Select-String -Path $_.FullName -Pattern 'Alle verfuegbaren Updates wurden erfolgreich verarbeitet.' -Quiet)
        ) {
            $RunDate
        }
    } |
    Sort-Object -Descending |
    Select-Object -First 1
}

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

$OriginalOutputEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
	
try {

    # -----------------------------------------------------------------------
    # Startinformationen
    # -----------------------------------------------------------------------

	Write-Log '=================================================='
	Write-Log 'Winget-Wartung gestartet'
	Write-Log "Computer      : $env:COMPUTERNAME"
	Write-Log "Benutzer      : $env:USERNAME"
	Write-Log "Winget        : $WingetExe"
    Write-Log 'Skriptversion : 1.4.0'
	Write-Log '=================================================='

    $Now = Get-Date
    $LastSuccessfulFridayRun = Get-LastSuccessfulFridayRun
    $FridayCutoff = $Now.AddDays(-7)

    if (
        $LastSuccessfulFridayRun -and
        ($LastSuccessfulFridayRun.Date -eq $Now.Date -or $LastSuccessfulFridayRun -ge $FridayCutoff)
    ) {
        Write-Log "Lauf übersprungen: Letzter erfolgreicher Freitagslauf war $LastSuccessfulFridayRun."
        return
    }

    # -----------------------------------------------------------------------
    # Winget-Quellen aktualisieren
    # -----------------------------------------------------------------------

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
            if (-not [string]::IsNullOrWhiteSpace([string]$Line)) {
                Write-Log ([string]$Line)
            }
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

    [Console]::OutputEncoding = $OriginalOutputEncoding

}