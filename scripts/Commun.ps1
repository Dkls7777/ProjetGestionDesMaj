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

function Get-CorrectifsRequis {
    # Lit required-patches.txt (une KB par ligne) et renvoie la liste des KB obligatoires
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Fichier des correctifs requis introuvable : $Path"
    }

    foreach ($ligne in Get-Content $Path) {

        # On ignore les lignes vides et les commentaires
        if ([string]::IsNullOrWhiteSpace($ligne) -or $ligne.Trim().StartsWith("#")) { continue }

        $kb = $ligne.Trim().ToUpper()

        # Une KB valide s'ecrit KB suivi de chiffres
        if ($kb -notmatch '^KB\d+$') {
            Write-Warning "Ligne ignoree (format attendu KB1234567) : $ligne"
            continue
        }

        $kb
    }
}
