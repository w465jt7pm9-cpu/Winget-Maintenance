# Installation

Dieses Dokument beschreibt die vollständige Installation, Konfiguration, Überprüfung und Wartung von WingetMaintenance.

---

# Voraussetzungen

Das Zielsystem muss folgende Voraussetzungen erfüllen:

- Windows 11
- Microsoft App Installer (Winget)
- PowerShell 5.1 oder neuer
- Lokale Administratorrechte
- Internetzugang für Paketquellen

---

# Winget prüfen

Vor der Installation sollte geprüft werden, ob Winget verfügbar ist:

```powershell
winget --version
```

Beispiel:

```text
v1.29.290
```

Zusätzlich sollte der App Installer installiert sein:

```powershell
Get-AppxPackage Microsoft.DesktopAppInstaller | Select-Object Name,Version
```

---

# Repository bereitstellen

Repository klonen:

```powershell
git clone <REPOSITORY-URL>
```

Arbeitsverzeichnis öffnen:

```powershell
cd WingetMaintenance
```

Alternativ kann das Repository als ZIP-Datei heruntergeladen und entpackt werden.

---

# Zielverzeichnis erstellen

WingetMaintenance verwendet standardmäßig folgendes Arbeitsverzeichnis:

```text
%ProgramData%\WingetMaintenance
```

Verzeichnis erstellen:

```powershell
New-Item -Path "$env:ProgramData\WingetMaintenance" -ItemType Directory -Force
```

---

# Skripte bereitstellen

Wartungsskript kopieren:

```powershell
Copy-Item ".\scripts\Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Task-Registrierungsskript kopieren:

```powershell
Copy-Item ".\scripts\Register-Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Prüfskript kopieren:

```powershell
Copy-Item ".\scripts\Test-WingetMaintenance.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

---

# Vor dem Deployment testen

Vor der produktiven Freigabe sollte ein kurzer Deployment-Check ausgeführt werden.
Das Prüfskript validiert die Syntax, die Winget-Verfügbarkeit und die geplante Aufgabe.

Ausführen:

```powershell
& "$env:ProgramData\WingetMaintenance\Test-WingetMaintenance.ps1"
```

Optional mit Pflichtprüfung auf die existierende Task:

```powershell
& "$env:ProgramData\WingetMaintenance\Test-WingetMaintenance.ps1" -RequireTask
```

Erwartetes Ergebnis:

```text
Deployment-Check erfolgreich: Alle Prüfungen bestanden.
```

Wenn ein Prüfpunkt fehlschlägt, endet das Skript mit Exit-Code 1 und zeigt die Fehlerdetails an.

---

# Geplante Aufgabe anlegen

Das Registrierungsskript muss als Administrator ausgeführt werden, damit die geplante Aufgabe mit den richtigen Rechten und dem aktuellen Admin-Konto registriert wird.

PowerShell als Administrator starten:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File "C:\Repos\WingetMaintenance\scripts\Register-Winget-Auto-Update.ps1"'
```

Alternativ direkt aus einem bereits geöffneten Administrator-Fenster:

```powershell
& "$env:ProgramData\WingetMaintenance\Register-Winget-Auto-Update.ps1"
```

Erwartete Ausgabe:

```text
Winget Scheduled Task erfolgreich eingerichtet
```

Wenn das Skript ohne Admin-Rechte gestartet wird, beendet es sich mit einer klaren Meldung: "Bitte als Administrator ausführen ..."

---

# Konfiguration der Aufgabe

Standardmäßig wird die Aufgabe mit folgenden Einstellungen erstellt:

| Einstellung | Wert |
|------------|------|
| Konto | Administratorkonto |
| Berechtigungen | Höchste Rechte |
| Anmeldung | 5 Minuten nach Benutzeranmeldung |
| Fallback | Täglich um 12:00 Uhr |
| Verpasste Läufe | Automatisch nachholen |
| Task-Neustarts | Bis zu 3 Wiederholungen |

---

# Registrierung überprüfen

Vorhandene Aufgabe anzeigen:

```powershell
Get-ScheduledTask -TaskName "Winget Automatic Updates"
```

Details anzeigen:

```powershell
Get-ScheduledTaskInfo -TaskName "Winget Automatic Updates"
```

---

# Funktionstest

Manuellen Testlauf starten:

```powershell
Start-ScheduledTask -TaskName "Winget Automatic Updates"
```

Status prüfen:

```powershell
Get-ScheduledTaskInfo -TaskName "Winget Automatic Updates"
```

Erfolgreiche Ausführung:

```text
LastTaskResult : 0
```

---

# Logdateien prüfen

Logdateien befinden sich unter:

```text
%ProgramData%\WingetMaintenance\Logs
```

Alle Logdateien anzeigen:

```powershell
Get-ChildItem "$env:ProgramData\WingetMaintenance\Logs"
```

Neueste Logdatei anzeigen:

```powershell
Get-Content ((Get-ChildItem "$env:ProgramData\WingetMaintenance\Logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName)
```

---

# Typischer erfolgreicher Lauf

Beispiel:

```text
2026-08-16 12:00:02 [INFO ] Winget-Wartung gestartet
2026-08-16 12:00:02 [INFO ] Pruefe Winget-Quelle ...
2026-08-16 12:00:08 [INFO ] Pruefe auf Updates ...
2026-08-16 12:00:11 [INFO ] Es wurde kein installiertes Paket gefunden, das den Eingabekriterien entspricht.
2026-08-16 12:00:11 [INFO ] Update-Dauer : 00:00:03.1278341
2026-08-16 12:00:11 [INFO ] Alle verfuegbaren Updates wurden erfolgreich verarbeitet.
```

---

# Skript aktualisieren

Neue Version des Wartungsskripts bereitstellen:

```powershell
Copy-Item ".\scripts\Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Neue Version des Registrierungsskripts bereitstellen:

```powershell
Copy-Item ".\scripts\Register-Winget-Auto-Update.ps1" "$env:ProgramData\WingetMaintenance\" -Force
```

Anschließend die Aufgabe aktualisieren:

```powershell
& "$env:ProgramData\WingetMaintenance\Register-Winget-Auto-Update.ps1"
```

---

# Log-Retention

Das Wartungsskript bereinigt alte Logdateien automatisch.

Standardwerte:

```text
Aufbewahrungsdauer : 90 Tage
Maximale Anzahl    : 100 Logdateien
```

Die Bereinigung erfolgt bei jedem Lauf.

---

# Winget-Quelle prüfen

Die Funktionsfähigkeit der Winget-Quelle kann manuell geprüft werden:

```powershell
winget search 7zip --source winget
```

Eine erfolgreiche Antwort enthält Pakettreffer.

---

# Deinstallation

Geplante Aufgabe entfernen:

```powershell
Unregister-ScheduledTask -TaskName "Winget Automatic Updates" -Confirm:$false
```

Arbeitsverzeichnis entfernen:

```powershell
Remove-Item "$env:ProgramData\WingetMaintenance" -Recurse -Force
```

Repository optional entfernen:

```powershell
Remove-Item "C:\Repos\WingetMaintenance" -Recurse -Force
```

---

# Fehlerbehebung

Für bekannte Fehlerbilder siehe:

```text
docs/TROUBLESHOOTING.md
```

Insbesondere:

```text
0x8A15000F
Von der Quelle benoetigte Daten fehlen
```

ist dort ausführlich dokumentiert.

---

# Empfohlene Betriebsweise

Für den produktiven Einsatz wird empfohlen:

- automatische Windows-Updates aktivieren
- Microsoft Store Updates aktivieren
- WingetMaintenance regelmäßig laufen lassen
- Logdateien gelegentlich prüfen
- Repository aktuell halten

Dadurch lassen sich die meisten Anwendungen ohne manuelle Pflege auf einem aktuellen Stand halten.