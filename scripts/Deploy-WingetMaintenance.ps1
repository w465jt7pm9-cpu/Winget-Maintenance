<#
.SYNOPSIS
    Deployt WingetMaintenance in ProgramData und registriert die geplante Aufgabe.

.DESCRIPTION
    Kopiert die aktuellen Skripte in das Installationsverzeichnis unter
    %ProgramData%\WingetMaintenance und registriert danach die geplante Task.
    Mit -SkipValidation kann der automatische Deployment-Check übersprungen
    werden.

.NOTES
    Author      : CTN
    Version     : 1.0.0
    PowerShell  : 5.1 oder neuer
    License     : MIT
#>

[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$TargetDir = (Join-Path $env:ProgramData 'WingetMaintenance'),
    [switch]$SkipValidation
)

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = if ($PSScriptRoot) {
        (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    }
    else {
        (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')).Path
    }
}

$ErrorActionPreference = 'Stop'

$currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    throw 'Bitte als Administrator ausführen, damit WingetMaintenance deployed werden kann.'
}

$requiredFiles = @(
    (Join-Path $SourceRoot 'scripts\Winget-Auto-Update.ps1'),
    (Join-Path $SourceRoot 'scripts\Register-Winget-Auto-Update.ps1'),
    (Join-Path $SourceRoot 'scripts\Test-WingetMaintenance.ps1')
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Erforderliche Datei nicht gefunden: $file"
    }
}

New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null

foreach ($file in $requiredFiles) {
    Copy-Item -Path $file -Destination $TargetDir -Force
}

$registrationScript = Join-Path $TargetDir 'Register-Winget-Auto-Update.ps1'
if (-not (Test-Path -LiteralPath $registrationScript)) {
    throw "Registrierungs-Skript nicht gefunden nach dem Kopieren: $registrationScript"
}

& $registrationScript

if (-not $SkipValidation) {
    $validationScript = Join-Path $TargetDir 'Test-WingetMaintenance.ps1'
    if (-not (Test-Path -LiteralPath $validationScript)) {
        throw "Validierungs-Skript nicht gefunden nach dem Kopieren: $validationScript"
    }

    & $validationScript
}

Write-Host ''
Write-Host '=================================================='
Write-Host 'WingetMaintenance erfolgreich deployed'
Write-Host "Zielverzeichnis : $TargetDir"
Write-Host '=================================================='
Write-Host ''
