# Commun.ps1
# Fonctions partagees par les scripts du projet.
# A charger en debut de script avec :  . (Join-Path $PSScriptRoot "Commun.ps1")

function Get-Inventaire {
    # Lit computers.txt (format NOM;ADRESSE_IP) et renvoie un objet par poste
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Fichier d'inventaire introuvable : $Path"
    }

    foreach ($ligne in Get-Content $Path) {

        # On ignore les lignes vides et les commentaires
        if ([string]::IsNullOrWhiteSpace($ligne) -or $ligne.Trim().StartsWith("#")) { continue }

        $champs = $ligne.Split(";")
        if ($champs.Count -lt 2) {
            Write-Warning "Ligne ignoree (format attendu NOM;IP) : $ligne"
            continue
        }

        [PSCustomObject]@{
            Poste     = $champs[0].Trim()
            AdresseIP = $champs[1].Trim()
        }
    }
}
