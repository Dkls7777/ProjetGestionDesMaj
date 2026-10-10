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

function Write-Journal {
    # Ajoute une ligne horodatee au fichier journal, champs separes par " ; "
    # Exemple : Write-Journal -Path $log -Champs "PC01", "Non conforme", "KB5124010"
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string[]]$Champs
    )

    $horodatage = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $ligne = (@($horodatage) + $Champs) -join " ; "
    Add-Content -Path $Path -Value $ligne -Encoding UTF8
}

function Invoke-RotationJournal {
    # Si le journal depasse la taille maximale, il est deplace dans le dossier
    # d'archives sous un nom date, puis passe en lecture seule.
    # Renvoie le chemin de l'archive creee, ou rien s'il n'y a pas eu de rotation.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ArchiveDir,
        [int]$TailleMaxKo = 1024
    )

    if (-not (Test-Path $Path)) { return }
    if ((Get-Item $Path).Length -lt ($TailleMaxKo * 1KB)) { return }

    if (-not (Test-Path $ArchiveDir)) { New-Item -ItemType Directory -Path $ArchiveDir | Out-Null }
    $nom   = "PatchManager-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")
    $cible = Join-Path $ArchiveDir $nom

    Move-Item -Path $Path -Destination $cible
    Set-ItemProperty -Path $cible -Name IsReadOnly -Value $true
    $cible
}
