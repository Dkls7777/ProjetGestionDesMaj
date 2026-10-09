# 04-Controle-Conformite.ps1
# Partie 4 : controle de conformite.
# Compare les correctifs installes sur chaque poste avec la liste des correctifs
# obligatoires (required-patches.txt), attribue un etat CONFORME / NON CONFORME /
# INACCESSIBLE, exporte ComplianceReport.csv et calcule le taux de conformite du parc.
#
# Usage (PowerShell Windows, depuis la racine du depot) :
#   .\scripts\04-Controle-Conformite.ps1 -Credential $cred

param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot "..\config\computers.txt"),
    [string]$RequiredPath  = (Join-Path $PSScriptRoot "..\config\required-patches.txt"),
    [string]$OutputDir     = (Join-Path $PSScriptRoot "..\output"),
    [System.Management.Automation.PSCredential]$Credential
)

. (Join-Path $PSScriptRoot "Commun.ps1")

if (-not $Credential) {
    $Credential = Get-Credential -Message "Compte d'administration des postes (ex : PC01\admin)"
}

# Liste des KB obligatoires, lue une seule fois
$requis = @(Get-CorrectifsRequis -Path $RequiredPath)
if ($requis.Count -eq 0) {
    Write-Error "Aucun correctif requis dans $RequiredPath : controle impossible"
    exit 1
}

# Date et heure du controle, identiques pour tous les postes de cette execution
$dateControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

Write-Host "Controle de conformite du $dateControle"
Write-Host "Correctifs requis ($($requis.Count)) : $($requis -join ', ')"
Write-Host ""

# Bloc execute SUR le poste distant : renvoie seulement les numeros de KB installes
$lecture = { (Get-HotFix).HotFixID }

$rapport = foreach ($pc in Get-Inventaire -Path $InventoryPath) {

    $erreur = ""
    $installes = $null

    if (-not (Test-Connection -ComputerName $pc.AdresseIP -Count 1 -Quiet)) {
        $erreur = "Aucune reponse au ping"
    }
    else {
        try {
            $installes = @(Invoke-Command -ComputerName $pc.AdresseIP -Credential $Credential -ScriptBlock $lecture -ErrorAction Stop)
        }
        catch {
            $erreur = "Commande distante en echec : " + ($_.Exception.Message -replace '\s+', ' ').Trim()
        }
    }

    if ($erreur) {
        # Poste non controle : on ne peut rien dire de sa conformite
        [PSCustomObject]@{
            Poste           = $pc.Poste
            AdresseIP       = $pc.AdresseIP
            KBRequises      = $requis.Count
            KBManquantes    = "-"
            ListeManquantes = ""
            Etat            = "INACCESSIBLE"
            DateControle    = $dateControle
            Erreur          = $erreur
        }
        continue
    }

    # Une KB requise est manquante si elle n'apparait pas dans les KB installees
    # (-notcontains ne tient pas compte de la casse)
    $manquantes = @($requis | Where-Object { $installes -notcontains $_ })

    [PSCustomObject]@{
        Poste           = $pc.Poste
        AdresseIP       = $pc.AdresseIP
        KBRequises      = $requis.Count
        KBManquantes    = $manquantes.Count
        ListeManquantes = $manquantes -join ", "
        # Conforme uniquement si TOUTES les KB requises sont installees
        Etat            = if ($manquantes.Count -eq 0) { "CONFORME" } else { "NON CONFORME" }
        DateControle    = $dateControle
        Erreur          = ""
    }
}

$rapport = @($rapport)

Write-Host "=== Etat de conformite ==="
$rapport | Format-Table Poste, KBRequises, KBManquantes, Etat, DateControle -AutoSize

# Detail des postes non conformes
$nonConformes = @($rapport | Where-Object { $_.Etat -eq "NON CONFORME" })
if ($nonConformes.Count -gt 0) {
    Write-Host "=== Correctifs manquants ==="
    foreach ($p in $nonConformes) {
        Write-Host "$($p.Poste) ($($p.AdresseIP)) : $($p.ListeManquantes)"
    }
    Write-Host ""
}

# Export CSV
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$csv = Join-Path $OutputDir "ComplianceReport.csv"
$rapport | Export-Csv -Path $csv -NoTypeInformation -Delimiter ";" -Encoding UTF8
Write-Host "Rapport de conformite exporte : $csv"

# Taux global de conformite : les postes inaccessibles ne sont pas comptes
$controles = @($rapport | Where-Object { $_.Etat -ne "INACCESSIBLE" })
$conformes = @($rapport | Where-Object { $_.Etat -eq "CONFORME" })

Write-Host ""
if ($controles.Count -eq 0) {
    Write-Host "Taux de conformite : non calculable (aucun poste accessible)"
}
else {
    $taux = [math]::Round(100 * $conformes.Count / $controles.Count, 1)
    Write-Host "Taux de conformite : $taux % ($($conformes.Count) poste(s) conforme(s) sur $($controles.Count) controle(s), hors postes inaccessibles)"
}
