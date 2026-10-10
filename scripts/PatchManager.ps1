# PatchManager.ps1
# Parties 6 et 7 : rapport de securite et notification.
# Script principal de la solution. Il realise un audit complet du parc en une seule
# passe (accessibilite, informations systeme, correctifs, conformite), puis produit :
#   - output\SecurityReport.csv   : le rapport detaille, une ligne par poste
#   - output\SecurityReport.html  : le meme rapport, lisible dans un navigateur
#   - output\PatchManager.log     : l'historique des executions
# Si au moins un poste est NON CONFORME ou INACCESSIBLE, il envoie un mail a
# l'administrateur avec le rapport HTML en piece jointe (config\notification.psd1).
#
# Usage (PowerShell Windows, depuis la racine du depot) :
#   .\scripts\PatchManager.ps1 -Credential $cred
#   .\scripts\PatchManager.ps1 -Credential $cred -SansNotification

param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot "..\config\computers.txt"),
    [string]$RequiredPath  = (Join-Path $PSScriptRoot "..\config\required-patches.txt"),
    [string]$OutputDir     = (Join-Path $PSScriptRoot "..\output"),
    [string]$NotificationConfig = (Join-Path $PSScriptRoot "..\config\notification.psd1"),
    [System.Management.Automation.PSCredential]$Credential,
    # Pour lancer un audit sans envoyer de mail
    [switch]$SansNotification
)

. (Join-Path $PSScriptRoot "Commun.ps1")

if (-not $Credential) {
    $Credential = Get-Credential -Message "Compte d'administration des postes (ex : PC01\admin)"
}

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$log      = Join-Path $OutputDir "PatchManager.log"
$csvPath  = Join-Path $OutputDir "SecurityReport.csv"
$htmlPath = Join-Path $OutputDir "SecurityReport.html"

Write-Journal -Path $log -Champs "Debut de l'audit"

$requis = @(Get-CorrectifsRequis -Path $RequiredPath)
if ($requis.Count -eq 0) {
    Write-Journal -Path $log -Champs "ERREUR", "Aucun correctif requis dans $RequiredPath"
    Write-Error "Aucun correctif requis dans $RequiredPath : audit impossible"
    exit 1
}

$dateControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

# Bloc execute SUR le poste distant : tout ce dont le rapport a besoin, en un seul appel
$collecte = {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    [PSCustomObject]@{
        Windows          = "$($os.Caption) ($($os.Version))"
        DernierDemarrage = $os.LastBootUpTime
        WindowsUpdate    = (Get-Service -Name wuauserv).Status.ToString()
        KBInstallees     = @((Get-HotFix).HotFixID)
    }
}

# ---------------------------------------------------------------- audit du parc
$rapport = foreach ($pc in Get-Inventaire -Path $InventoryPath) {

    Write-Host "Audit de $($pc.Poste) ($($pc.AdresseIP))..."

    $erreur = ""
    $infos  = $null

    if (-not (Test-Connection -ComputerName $pc.AdresseIP -Count 1 -Quiet)) {
        $erreur = "Aucune reponse au ping"
        Write-Journal -Path $log -Champs $pc.Poste, "Inaccessible", $erreur
    }
    else {
        try {
            $infos = Invoke-Command -ComputerName $pc.AdresseIP -Credential $Credential -ScriptBlock $collecte -ErrorAction Stop
            Write-Journal -Path $log -Champs $pc.Poste, "Accessible"
        }
        catch {
            $erreur = "Commande distante en echec : " + ($_.Exception.Message -replace '\s+', ' ').Trim()
            Write-Journal -Path $log -Champs $pc.Poste, "WinRM inaccessible"
        }
    }

    if (-not $infos) {
        [PSCustomObject]@{
            Poste            = $pc.Poste
            AdresseIP        = $pc.AdresseIP
            Accessibilite    = "Inaccessible"
            Windows          = "-"
            DernierDemarrage = "-"
            WindowsUpdate    = "-"
            KBRequises       = $requis.Count
            KBManquantes     = "-"
            ListeManquantes  = ""
            Conformite       = "INACCESSIBLE"
            DateControle     = $dateControle
            Erreur           = $erreur
        }
        continue
    }

    $manquantes = @($requis | Where-Object { $infos.KBInstallees -notcontains $_ })

    if ($manquantes.Count -eq 0) {
        $conformite = "CONFORME"
        Write-Journal -Path $log -Champs $pc.Poste, "Conforme"
    }
    else {
        $conformite = "NON CONFORME"
        Write-Journal -Path $log -Champs $pc.Poste, "Non conforme", ($manquantes -join ", ")
    }

    [PSCustomObject]@{
        Poste            = $pc.Poste
        AdresseIP        = $pc.AdresseIP
        Accessibilite    = "Accessible"
        Windows          = $infos.Windows
        DernierDemarrage = if ($infos.DernierDemarrage) { $infos.DernierDemarrage.ToString("dd/MM/yyyy HH:mm") } else { "-" }
        WindowsUpdate    = $infos.WindowsUpdate
        KBRequises       = $requis.Count
        KBManquantes     = $manquantes.Count
        ListeManquantes  = $manquantes -join ", "
        Conformite       = $conformite
        DateControle     = $dateControle
        Erreur           = ""
    }
}
$rapport = @($rapport)

# ---------------------------------------------------------------- synthese globale
$accessibles   = @($rapport | Where-Object { $_.Accessibilite -eq "Accessible" })
$inaccessibles = @($rapport | Where-Object { $_.Accessibilite -eq "Inaccessible" })
$conformes     = @($rapport | Where-Object { $_.Conformite -eq "CONFORME" })
$nonConformes  = @($rapport | Where-Object { $_.Conformite -eq "NON CONFORME" })
$aTraiter      = @($rapport | Where-Object { $_.Conformite -ne "CONFORME" })

$totalManquants = 0
foreach ($p in $nonConformes) { $totalManquants += $p.KBManquantes }

# Taux calcule sur les postes accessibles uniquement
$taux = if ($accessibles.Count -gt 0) {
    "{0} %" -f [math]::Round(100 * $conformes.Count / $accessibles.Count, 1)
} else {
    "non calculable"
}

$synthese = [PSCustomObject]@{
    TotalPostes              = $rapport.Count
    PostesAccessibles        = $accessibles.Count
    PostesInaccessibles      = $inaccessibles.Count
    PostesConformes          = $conformes.Count
    PostesNonConformes       = $nonConformes.Count
    TotalCorrectifsManquants = $totalManquants
    TauxConformite           = $taux
}

# ---------------------------------------------------------------- affichage console
Write-Host ""
Write-Host "=== Rapport de securite du $dateControle ==="
$rapport | Format-Table Poste, AdresseIP, Accessibilite, WindowsUpdate, KBRequises, KBManquantes, Conformite -AutoSize

Write-Host "=== Synthese globale ==="
$synthese | Format-List

Write-Host "=== Postes necessitant une intervention ==="
if ($aTraiter.Count -eq 0) {
    Write-Host "Aucun"
}
else {
    foreach ($p in $aTraiter) {
        if ($p.Conformite -eq "NON CONFORME") {
            Write-Host "$($p.Poste) ($($p.AdresseIP)) : NON CONFORME, KB manquantes : $($p.ListeManquantes)"
        }
        else {
            Write-Host "$($p.Poste) ($($p.AdresseIP)) : INACCESSIBLE, $($p.Erreur)"
        }
    }
}
Write-Host ""

# ---------------------------------------------------------------- export CSV
$rapport | Export-Csv -Path $csvPath -NoTypeInformation -Delimiter ";" -Encoding UTF8

# ---------------------------------------------------------------- export HTML
# Les valeurs viennent des postes distants : on les encode avant de les inserer dans la page
function Protect-Html {
    param($Texte)
    [System.Net.WebUtility]::HtmlEncode([string]$Texte)
}

function Get-ClasseEtat {
    param([string]$Etat)
    switch ($Etat) {
        "CONFORME"     { "ok" }
        "NON CONFORME" { "ko" }
        default        { "na" }
    }
}

$lignesDetail = foreach ($l in $rapport) {
    $classe = Get-ClasseEtat -Etat $l.Conformite
    "<tr><td>$(Protect-Html $l.Poste)</td><td>$(Protect-Html $l.AdresseIP)</td><td>$(Protect-Html $l.Accessibilite)</td>" +
    "<td>$(Protect-Html $l.Windows)</td><td>$(Protect-Html $l.DernierDemarrage)</td><td>$(Protect-Html $l.WindowsUpdate)</td>" +
    "<td class=`"num`">$(Protect-Html $l.KBRequises)</td><td class=`"num`">$(Protect-Html $l.KBManquantes)</td>" +
    "<td>$(Protect-Html $l.ListeManquantes)</td><td><span class=`"etat $classe`">$(Protect-Html $l.Conformite)</span></td>" +
    "<td>$(Protect-Html $l.DateControle)</td></tr>"
}

if ($aTraiter.Count -eq 0) {
    $blocIntervention = "<p>Aucun poste ne n&eacute;cessite d'intervention.</p>"
}
else {
    $lignesIntervention = foreach ($l in $aTraiter) {
        $classe = Get-ClasseEtat -Etat $l.Conformite
        $motif  = if ($l.Conformite -eq "NON CONFORME") { "KB manquantes : $($l.ListeManquantes)" } else { $l.Erreur }
        "<tr><td>$(Protect-Html $l.Poste)</td><td>$(Protect-Html $l.AdresseIP)</td>" +
        "<td><span class=`"etat $classe`">$(Protect-Html $l.Conformite)</span></td><td>$(Protect-Html $motif)</td></tr>"
    }
    $blocIntervention = "<table><thead><tr><th>Poste</th><th>Adresse IP</th><th>&Eacute;tat</th><th>Motif</th></tr></thead><tbody>`n" +
        ($lignesIntervention -join "`n") + "`n</tbody></table>"
}

$html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Rapport de s&eacute;curit&eacute; - Patch Management</title>
<style>
  body { font-family: Segoe UI, Arial, sans-serif; margin: 2rem; color: #1f2328; background: #ffffff; }
  h1 { font-size: 1.6rem; margin-bottom: 0.2rem; }
  h2 { font-size: 1.15rem; margin-top: 2rem; border-bottom: 1px solid #d0d7de; padding-bottom: 0.3rem; }
  .meta { color: #57606a; margin-top: 0; }
  table { border-collapse: collapse; width: 100%; margin-top: 0.8rem; }
  th, td { border: 1px solid #d0d7de; padding: 0.45rem 0.6rem; text-align: left; font-size: 0.92rem; vertical-align: top; }
  th { background: #f6f8fa; }
  td.num { text-align: right; }
  table.synthese { width: auto; min-width: 22rem; }
  table.synthese td.num { font-weight: 600; }
  .etat { display: inline-block; padding: 0.1rem 0.5rem; border-radius: 0.3rem; font-weight: 600; white-space: nowrap; }
  .ok { background: #dafbe1; color: #116329; }
  .ko { background: #ffebe9; color: #a40e26; }
  .na { background: #fff8c5; color: #7d4e00; }
</style>
</head>
<body>
<h1>Rapport de s&eacute;curit&eacute; du parc</h1>
<p class="meta">Contr&ocirc;le du $dateControle. Poste d'administration : $(Protect-Html $env:COMPUTERNAME). Correctifs requis : $(Protect-Html ($requis -join ', ')).</p>

<h2>Synth&egrave;se globale</h2>
<table class="synthese">
<tbody>
<tr><td>Nombre total de postes</td><td class="num">$($synthese.TotalPostes)</td></tr>
<tr><td>Postes accessibles</td><td class="num">$($synthese.PostesAccessibles)</td></tr>
<tr><td>Postes inaccessibles</td><td class="num">$($synthese.PostesInaccessibles)</td></tr>
<tr><td>Postes conformes</td><td class="num">$($synthese.PostesConformes)</td></tr>
<tr><td>Postes non conformes</td><td class="num">$($synthese.PostesNonConformes)</td></tr>
<tr><td>Total de correctifs manquants</td><td class="num">$($synthese.TotalCorrectifsManquants)</td></tr>
<tr><td>Taux de conformit&eacute; (postes accessibles)</td><td class="num">$(Protect-Html $synthese.TauxConformite)</td></tr>
</tbody>
</table>

<h2>Postes n&eacute;cessitant une intervention</h2>
$blocIntervention

<h2>D&eacute;tail par poste</h2>
<table>
<thead>
<tr><th>Poste</th><th>Adresse IP</th><th>Accessibilit&eacute;</th><th>Windows</th><th>Dernier d&eacute;marrage</th><th>Windows Update</th><th>KB requises</th><th>KB manquantes</th><th>Liste des KB manquantes</th><th>Conformit&eacute;</th><th>Date du contr&ocirc;le</th></tr>
</thead>
<tbody>
$($lignesDetail -join "`n")
</tbody>
</table>
</body>
</html>
"@

$html | Out-File -FilePath $htmlPath -Encoding UTF8

Write-Journal -Path $log -Champs "Rapport genere"
Write-Host "Rapport CSV  : $csvPath"
Write-Host "Rapport HTML : $htmlPath"
Write-Host "Journal      : $log"

# ---------------------------------------------------------------- notification (partie 7)
# Un mail n'est envoye que s'il existe au moins une anomalie.
if ($SansNotification) {
    Write-Host "Notification desactivee (-SansNotification)"
}
elseif ($aTraiter.Count -eq 0) {
    Write-Host "Aucune anomalie detectee : pas de notification"
    Write-Journal -Path $log -Champs "Aucune anomalie", "Pas de notification"
}
elseif (-not (Test-Path $NotificationConfig)) {
    Write-Warning "Configuration de notification introuvable : $NotificationConfig"
    Write-Journal -Path $log -Champs "ERREUR", "Notification non envoyee", "Configuration introuvable"
}
else {
    $conf = Import-PowerShellDataFile -Path $NotificationConfig

    # Lettres accentuees construites par code, pour garder ce fichier en ASCII
    $e  = [char]0xE9   # e accent aigu
    $eg = [char]0xE8   # e accent grave
    $o  = [char]0xF4   # o accent circonflexe
    $ag = [char]0xE0   # a accent grave

    $objet = "[PATCH MANAGEMENT] Anomalies d${e}tect${e}es"

    $lignes = @(
        "Date du contr${o}le : $dateControle"
        "Postes contr${o}l${e}s : $($rapport.Count)"
        "Postes non conformes : $($nonConformes.Count)"
        "Postes inaccessibles : $($inaccessibles.Count)"
        ""
    )
    foreach ($p in $aTraiter) {
        $lignes += "$($p.Poste) : $($p.Conformite)"
        if ($p.Conformite -eq "NON CONFORME") {
            foreach ($kb in ($p.ListeManquantes -split ", ")) {
                $lignes += "    $kb manquante"
            }
        }
        else {
            $lignes += "    $($p.Erreur)"
        }
    }
    $lignes += ""
    $lignes += "Le rapport complet est joint ${ag} ce message (SecurityReport.html)."

    # Parametres d'envoi regroupes dans une table (splatting)
    $mail = @{
        SmtpServer  = $conf.SmtpServer
        Port        = $conf.Port
        From        = $conf.From
        To          = $conf.To
        Subject     = $objet
        Body        = $lignes -join "`r`n"
        Attachments = $htmlPath
        Encoding    = [System.Text.Encoding]::UTF8
        ErrorAction = "Stop"
    }
    if ($conf.UseSsl) { $mail.UseSsl = $true }

    # Identifiants eventuels : lus dans un fichier chiffre, jamais ecrits en clair
    if ($conf.CredentialFile) {
        $fichierCred = [Environment]::ExpandEnvironmentVariables($conf.CredentialFile)
        if (Test-Path $fichierCred) {
            $mail.Credential = Import-Clixml -Path $fichierCred
        }
        else {
            Write-Warning "Fichier d'identifiants SMTP introuvable : $fichierCred"
        }
    }

    try {
        Send-MailMessage @mail
        Write-Journal -Path $log -Champs "Notification envoyee a $($conf.To)"
        Write-Host "Notification envoyee a $($conf.To)"
    }
    catch {
        $message = ($_.Exception.Message -replace '\s+', ' ').Trim()
        Write-Journal -Path $log -Champs "ERREUR", "Notification non envoyee", $message
        Write-Warning "Notification non envoyee : $message"
    }
}

Write-Journal -Path $log -Champs "Fin de l'audit"
