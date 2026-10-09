# 02-Inventaire-Parc.ps1
# Partie 2 : inventaire du parc.
# Pour chaque poste de computers.txt : teste la disponibilite, collecte a distance
# les caracteristiques systeme et les informations utiles au Patch Management,
# affiche un tableau recapitulatif et exporte le tout en CSV.
#
# Usage (PowerShell Windows, depuis la racine du depot) :
#   .\scripts\02-Inventaire-Parc.ps1 -Credential $cred

param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot "..\config\computers.txt"),
    [string]$OutputDir     = (Join-Path $PSScriptRoot "..\output"),
    [System.Management.Automation.PSCredential]$Credential
)

. (Join-Path $PSScriptRoot "Commun.ps1")

# Le mot de passe n'est jamais ecrit dans le script : on le demande si besoin
if (-not $Credential) {
    $Credential = Get-Credential -Message "Compte d'administration des postes (ex : PC01\admin)"
}

# Bloc execute SUR le poste distant. Il renvoie un seul objet avec toutes les mesures.
$collecte = {
    $cs    = Get-CimInstance -ClassName Win32_ComputerSystem
    $os    = Get-CimInstance -ClassName Win32_OperatingSystem
    $bios  = Get-CimInstance -ClassName Win32_BIOS
    $disk  = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $wu    = Get-Service -Name wuauserv
    # @() force un tableau, meme s'il n'y a qu'un seul correctif
    $fixes = @(Get-HotFix)
    $dernier = $fixes | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1

    [PSCustomObject]@{
        NomPoste         = $env:COMPUTERNAME
        Modele           = $cs.Model
        VersionBios      = $bios.SMBIOSBIOSVersion
        Windows          = $os.Caption
        VersionWindows   = $os.Version
        Architecture     = $os.OSArchitecture
        DernierDemarrage = $os.LastBootUpTime
        RamGo            = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        DisqueLibreGo    = [math]::Round($disk.FreeSpace / 1GB, 1)
        DerniereMaj      = $dernier.InstalledOn
        NbMaj            = $fixes.Count
        WindowsUpdate    = $wu.Status.ToString()
    }
}

# Fabrique une ligne d'inventaire. Toutes les lignes ont les memes colonnes,
# sinon l'export CSV perdrait des champs.
function New-LigneInventaire {
    param($Poste, $AdresseIP, $Etat, $Infos, $Erreur = "")

    $formatDate = "dd/MM/yyyy HH:mm"
    [PSCustomObject]@{
        Poste            = $Poste
        AdresseIP        = $AdresseIP
        Etat             = $Etat
        Modele           = if ($Infos) { $Infos.Modele } else { "-" }
        VersionBios      = if ($Infos) { $Infos.VersionBios } else { "-" }
        Windows          = if ($Infos) { $Infos.Windows } else { "-" }
        VersionWindows   = if ($Infos) { $Infos.VersionWindows } else { "-" }
        Architecture     = if ($Infos) { $Infos.Architecture } else { "-" }
        DernierDemarrage = if ($Infos -and $Infos.DernierDemarrage) { $Infos.DernierDemarrage.ToString($formatDate) } else { "-" }
        RamGo            = if ($Infos) { $Infos.RamGo } else { "-" }
        DisqueLibreGo    = if ($Infos) { $Infos.DisqueLibreGo } else { "-" }
        DerniereMaj      = if ($Infos -and $Infos.DerniereMaj) { $Infos.DerniereMaj.ToString("dd/MM/yyyy") } else { "-" }
        NbMaj            = if ($Infos) { $Infos.NbMaj } else { "-" }
        WindowsUpdate    = if ($Infos) { $Infos.WindowsUpdate } else { "-" }
        Erreur           = $Erreur
    }
}

$inventaire = foreach ($pc in Get-Inventaire -Path $InventoryPath) {

    Write-Host "Controle de $($pc.Poste) ($($pc.AdresseIP))..."

    # Etape 1 : le poste repond-il au ping ?
    if (-not (Test-Connection -ComputerName $pc.AdresseIP -Count 1 -Quiet)) {
        New-LigneInventaire -Poste $pc.Poste -AdresseIP $pc.AdresseIP -Etat "Inaccessible" -Erreur "Aucune reponse au ping"
        continue
    }

    # Etape 2 : collecte a distance. try/catch pour que le script continue en cas d'echec.
    try {
        $infos = Invoke-Command -ComputerName $pc.AdresseIP -Credential $Credential -ScriptBlock $collecte -ErrorAction Stop
        New-LigneInventaire -Poste $pc.Poste -AdresseIP $pc.AdresseIP -Etat "Accessible" -Infos $infos
    }
    catch {
        # On garde le message d'erreur sur une seule ligne pour le CSV
        $message = ($_.Exception.Message -replace '\s+', ' ').Trim()
        New-LigneInventaire -Poste $pc.Poste -AdresseIP $pc.AdresseIP -Etat "Inaccessible" -Erreur "Commande distante en echec : $message"
    }
}

# Tableau recapitulatif a l'ecran
$inventaire |
    Format-Table Poste, AdresseIP, Windows, Architecture, DernierDemarrage, WindowsUpdate, Etat -AutoSize

# Export CSV (separateur ; pour s'ouvrir directement dans Excel en francais)
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$csv = Join-Path $OutputDir "Inventory.csv"
$inventaire | Export-Csv -Path $csv -NoTypeInformation -Delimiter ";" -Encoding UTF8

Write-Host "Inventaire exporte : $csv"
