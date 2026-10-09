# 01-Test-Parc.ps1
# Partie 1, question 3 : lit computers.txt et affiche pour chaque poste
# son nom, son adresse IP et son etat de disponibilite.
# Usage (PowerShell Windows, depuis la racine du depot) : .\scripts\01-Test-Parc.ps1

param(
    # Chemin de l'inventaire. Par defaut : config\computers.txt a cote du dossier scripts
    [string]$InventoryPath = (Join-Path $PSScriptRoot "..\config\computers.txt")
)

if (-not (Test-Path $InventoryPath)) {
    Write-Error "Fichier d'inventaire introuvable : $InventoryPath"
    exit 1
}

$resultats = foreach ($ligne in Get-Content $InventoryPath) {

    # On ignore les lignes vides et les commentaires
    if ([string]::IsNullOrWhiteSpace($ligne) -or $ligne.Trim().StartsWith("#")) { continue }

    # Format attendu : NOM;ADRESSE_IP
    $champs = $ligne.Split(";")
    if ($champs.Count -lt 2) {
        Write-Warning "Ligne ignoree (format attendu NOM;IP) : $ligne"
        continue
    }
    $nom = $champs[0].Trim()
    $ip  = $champs[1].Trim()

    # Un seul ping. -Quiet renvoie True ou False au lieu de lever une erreur
    $joignable = Test-Connection -ComputerName $ip -Count 1 -Quiet

    # Un objet par poste : plus simple a trier, afficher ou exporter ensuite
    [PSCustomObject]@{
        Poste     = $nom
        AdresseIP = $ip
        Etat      = if ($joignable) { "Accessible" } else { "Inaccessible" }
    }
}

$resultats | Format-Table -AutoSize
