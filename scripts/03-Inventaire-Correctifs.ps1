# 03-Inventaire-Correctifs.ps1
# Partie 3 : inventaire des correctifs.
# Pour chaque poste accessible de computers.txt : recupere a distance la liste des
# correctifs installes, centralise le tout dans PatchesInventory.csv (trie par poste
# puis par date d'installation decroissante) et affiche une synthese par machine.
#
# Usage (PowerShell Windows, depuis la racine du depot) :
#   .\scripts\03-Inventaire-Correctifs.ps1 -Credential $cred

param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot "..\config\computers.txt"),
    [string]$OutputDir     = (Join-Path $PSScriptRoot "..\output"),
    [System.Management.Automation.PSCredential]$Credential
)

. (Join-Path $PSScriptRoot "Commun.ps1")

if (-not $Credential) {
    $Credential = Get-Credential -Message "Compte d'administration des postes (ex : PC01\admin)"
}

# Bloc execute SUR le poste distant. On ne garde que les 4 informations utiles.
$lecture = {
    Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy
}

$correctifs = @()   # une ligne par correctif, tous postes confondus
$etats      = @()   # une ligne par poste : accessible ou non, et pourquoi

foreach ($pc in Get-Inventaire -Path $InventoryPath) {

    Write-Host "Lecture des correctifs de $($pc.Poste) ($($pc.AdresseIP))..."

    # Poste injoignable : on le note et on passe au suivant
    if (-not (Test-Connection -ComputerName $pc.AdresseIP -Count 1 -Quiet)) {
        Write-Warning "$($pc.Poste) ignore : aucune reponse au ping"
        $etats += [PSCustomObject]@{ Poste = $pc.Poste; AdresseIP = $pc.AdresseIP; Etat = "Inaccessible"; Erreur = "Aucune reponse au ping" }
        continue
    }

    try {
        # @() force un tableau, meme s'il n'y a qu'un seul correctif
        $fixes = @(Invoke-Command -ComputerName $pc.AdresseIP -Credential $Credential -ScriptBlock $lecture -ErrorAction Stop)
    }
    catch {
        $message = ($_.Exception.Message -replace '\s+', ' ').Trim()
        Write-Warning "$($pc.Poste) ignore : commande distante en echec"
        $etats += [PSCustomObject]@{ Poste = $pc.Poste; AdresseIP = $pc.AdresseIP; Etat = "Inaccessible"; Erreur = "Commande distante en echec : $message" }
        continue
    }

    $etats += [PSCustomObject]@{ Poste = $pc.Poste; AdresseIP = $pc.AdresseIP; Etat = "Accessible"; Erreur = "" }

    foreach ($f in $fixes) {
        $correctifs += [PSCustomObject]@{
            Poste            = $pc.Poste
            AdresseIP        = $pc.AdresseIP
            KB               = $f.HotFixID
            Description      = $f.Description
            DateInstallation = if ($f.InstalledOn) { $f.InstalledOn.ToString("dd/MM/yyyy") } else { "-" }
            InstallePar      = if ($f.InstalledBy) { $f.InstalledBy } else { "-" }
            # Vraie date, gardee uniquement pour trier correctement
            DateTri          = $f.InstalledOn
        }
    }
}

# Tri : par poste, puis du correctif le plus recent au plus ancien.
# Le numero de KB departage les correctifs installes le meme jour.
$tries = @($correctifs | Sort-Object -Property Poste,
    @{ Expression = "DateTri"; Descending = $true },
    @{ Expression = "KB"; Descending = $true })

Write-Host ""
Write-Host "=== Correctifs installes ==="
$tries | Format-Table Poste, AdresseIP, KB, Description, DateInstallation -AutoSize

# Export CSV (sans la colonne technique DateTri)
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$csv = Join-Path $OutputDir "PatchesInventory.csv"
if ($tries.Count -gt 0) {
    $tries |
        Select-Object Poste, AdresseIP, KB, Description, DateInstallation, InstallePar |
        Export-Csv -Path $csv -NoTypeInformation -Delimiter ";" -Encoding UTF8
    Write-Host "Inventaire des correctifs exporte : $csv"
}
else {
    Write-Warning "Aucun correctif recense : $csv n'a pas ete genere"
}

# Synthese par machine : nombre de correctifs, date et KB du plus recent
$synthese = foreach ($e in $etats) {
    $duPoste = @($tries | Where-Object { $_.Poste -eq $e.Poste })
    $dernier = if ($duPoste.Count -gt 0) { $duPoste[0] } else { $null }

    [PSCustomObject]@{
        Poste            = $e.Poste
        Etat             = $e.Etat
        NbCorrectifs     = if ($e.Etat -eq "Accessible") { $duPoste.Count } else { "-" }
        DernierCorrectif = if ($dernier) { $dernier.DateInstallation } else { "-" }
        DerniereKB       = if ($dernier) { $dernier.KB } else { "-" }
    }
}

Write-Host ""
Write-Host "=== Synthese par poste ==="
$synthese | Format-Table -AutoSize
