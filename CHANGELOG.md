# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Projekt orientiert sich an den Grundsätzen von:

- Keep a Changelog
- Semantic Versioning (SemVer)

---

# [1.5.0] - 2026-08-22

## Geändert

- Updates auf die explizite `winget`-Quelle begrenzt
- Automatische Updates unbekannter Pakete deaktiviert

---

# [1.4.0] - 2026-08-22

## Geändert

- Hauptlauf der geplanten Aufgabe auf jeden Freitag um 12:00 Uhr umgestellt
- Anmeldetrigger auf überfällige Freitagsläufe begrenzt
- Redundanten `winget search 7zip`-Vorabcheck entfernt
- Leere Winget-Ausgabezeilen werden beim Logging ignoriert
- Native Winget-Ausgabe wird als UTF-8 verarbeitet
- Dokumentation und Deployment-Check an den neuen Zeitplan angepasst

---

# [1.2.0] - 2026-08-17

## Hinzugefügt

- Englischsprachige Projektdokumentation (ARCHITECTURE, CONCEPTS, INSTALL, TROUBLESHOOTING)

## Geändert

- README-Komponententabelle um Testskript und fehlende Dokumente ergänzt

## Behoben

- Abweichende Skriptversion in der Protokollausgabe von Winget-Auto-Update.ps1 korrigiert (1.1.0 -> 1.2.0)
- Fehlerhafte Beschreibung des Ausführungskontos (SYSTEM statt Administratorkonto) in Register-Winget-Auto-Update.ps1 korrigiert

---

# [1.1.1] - 2026-08-16

## Hinzugefügt

- Pre-Deployment-Check-Skript für syntaktische und konfigurationsbezogene Validierung
- Testskript zum Verifizieren von Winget, Basisordnern und geplanter Task
- Installationshinweise für den Deployment-Check

## Geändert

- INSTALL-Dokumentation um Testlauf vor dem Deployment erweitert

---

# [1.1.0] - 2026-08-16

## Hinzugefügt

- Automatische Log-Retention
- Begrenzung der maximalen Anzahl historischer Logdateien
- Healthcheck der Winget-Quelle vor jedem Updatelauf
- Eigene UTF-8-Protokollierung
- Protokollierung der Winget-Ausgabe
- Detaillierte Fehlerbehandlung
- Dokumentation bekannter Reparaturmaßnahmen
- INSTALL-Dokumentation
- TROUBLESHOOTING-Dokumentation
- ARCHITECTURE-Dokumentation
- CONCEPT-Dokumentation

## Geändert

- Ermittlung des Winget-Pfades über `Get-Command`
- Umstellung von fest hinterlegten Pfaden auf Umgebungsvariablen
- Ausführung über geplante Aufgabe mit erhöhten Rechten
- Verbesserte Protokollstruktur
- Erweiterte Projektdokumentation

## Behoben

- Fehler `0x8A15000F` dokumentiert
- Diagnoseverfahren für beschädigte Winget-Quellen dokumentiert
- Reparatur der AppX-Registrierung des Pakets `Microsoft.Winget.Source` dokumentiert

## Entfernt

- Verwendung von `Start-Transcript`
- Abhängigkeit von PowerShell-Transcript-Logs

---

# [1.0.0] - 2026-08-15

## Erstveröffentlichung

### Enthaltene Funktionen

- Automatische Aktualisierung installierter Anwendungen über Winget
- Erstellung einer geplanten Aufgabe
- Tägliche Ausführung
- Grundlegendes Logging
- Fehlererkennung
- Paketquellen-Aktualisierung

---

# Versionsschema

## Major Version

Änderungen, die nicht rückwärtskompatibel sind.

Beispiel:

```text
1.x.x -> 2.0.0
```

## Minor Version

Neue Funktionen ohne Verlust der Kompatibilität.

Beispiel:

```text
1.1.0 -> 1.2.0
```

## Patch Version

Fehlerbehebungen und kleinere Verbesserungen.

Beispiel:

```text
1.1.0 -> 1.1.1
```

---

# Geplante Erweiterungen

Folgende Funktionen werden für zukünftige Versionen evaluiert:

- JSON-Logging
- Eventlog-Integration
- E-Mail-Benachrichtigungen
- Paket-Allowlist
- Paket-Blocklist
- Konfigurationsdatei
- GitHub Releases
- Erweiterte Reporting-Funktionen