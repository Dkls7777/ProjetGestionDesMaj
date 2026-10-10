# Test-IntegriteRapports.ps1
# Partie 8, point 8 : controle d'integrite des rapports archives.
# Recalcule l'empreinte SHA-256 de chaque rapport archive et la compare a celle
# enregistree au moment de l'audit dans output\archives\empreintes.csv.
#
# Usage (PowerShell Windows, depuis la racine du depot) :
#   .\scripts\Test-IntegriteRapports.ps1

param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\output")
)

$archives = Join-Path $OutputDir "archives"
$registre = Join-Path $archives "empreintes.csv"

if (-not (Test-Path $registre)) {
    Write-Error "Registre des empreintes introuvable : $registre"
    exit 1
}

$resultats = foreach ($ligne in Import-Csv -Path $registre -Delimiter ";") {

    $fichier = Join-Path $archives $ligne.Fichier

    if (-not (Test-Path $fichier)) {
        $etat = "ABSENT"
    }
    elseif ((Get-FileHash -Path $fichier -Algorithm SHA256).Hash -eq $ligne.SHA256) {
        $etat = "OK"
    }
    else {
        $etat = "ALTERE"
    }

    [PSCustomObject]@{
        DateControle = $ligne.DateControle
        Fichier      = $ligne.Fichier
        Etat         = $etat
    }
}

$resultats = @($resultats)
$resultats | Format-Table -AutoSize

$anomalies = @($resultats | Where-Object { $_.Etat -ne "OK" })
if ($anomalies.Count -eq 0) {
    Write-Host "Integrite verifiee : $($resultats.Count) fichier(s) conforme(s) a leur empreinte."
}
else {
    Write-Warning "$($anomalies.Count) fichier(s) absent(s) ou altere(s) sur $($resultats.Count)."
    exit 2
}
