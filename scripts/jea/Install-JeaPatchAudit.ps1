# Install-JeaPatchAudit.ps1
# Partie 8, points 3 et 7 : point de connexion JEA "PatchAudit".
#
# JEA (Just Enough Administration) cree un point de connexion PowerShell restreint :
# le compte de service s'y connecte, mais il ne peut y lancer QUE la fonction
# Get-PatchAudit. Cette fonction s'execute avec un compte virtuel temporaire qui a
# les droits necessaires pour lire WMI. Le compte de service, lui, n'a aucun droit
# d'administration sur le poste.
#
# A executer SUR le poste administre, avec un compte administrateur.
# Depuis le poste d'administration (PowerShell Windows) :
#   Invoke-Command -ComputerName <IP> -Credential $cred -FilePath .\scripts\jea\Install-JeaPatchAudit.ps1
# Puis, sur le poste administre : Restart-Service WinRM

param(
    [string]$Compte      = "svc-patch",
    [string]$NomEndpoint = "PatchAudit"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------- 1. module porteur du role
# Un fichier de role JEA doit se trouver dans le dossier RoleCapabilities d'un module
$module = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\PatchAudit"
$roles  = Join-Path $module "RoleCapabilities"
New-Item -ItemType Directory -Path $roles -Force | Out-Null
New-ModuleManifest -Path (Join-Path $module "PatchAudit.psd1") -Description "Role JEA pour l'audit des correctifs"

# ---------------------------------------------------------------- 2. role : une seule fonction visible
# La fonction renvoie exactement ce dont PatchManager.ps1 a besoin, en lecture seule.
# Les commandes sont appelees avec le nom de leur module pour ne pas pouvoir etre detournees.
$fonction = @{
    Name        = "Get-PatchAudit"
    ScriptBlock = {
        $os = CimCmdlets\Get-CimInstance -ClassName Win32_OperatingSystem
        [PSCustomObject]@{
            Windows          = "$($os.Caption) ($($os.Version))"
            DernierDemarrage = $os.LastBootUpTime
            WindowsUpdate    = (Microsoft.PowerShell.Management\Get-Service -Name wuauserv).Status.ToString()
            KBInstallees     = @((Microsoft.PowerShell.Management\Get-HotFix).HotFixID)
        }
    }
}

New-PSRoleCapabilityFile -Path (Join-Path $roles "PatchAudit.psrc") `
    -Description "Lecture seule des informations de Patch Management" `
    -ModulesToImport "CimCmdlets" `
    -FunctionDefinitions $fonction `
    -VisibleFunctions "Get-PatchAudit"

# ---------------------------------------------------------------- 3. configuration de session
$dossier     = Join-Path $env:ProgramData "JEA\PatchAudit"
$transcripts = Join-Path $dossier "Transcripts"
New-Item -ItemType Directory -Path $transcripts -Force | Out-Null
$pssc = Join-Path $dossier "PatchAudit.pssc"

# RestrictedRemoteServer : mode NoLanguage, presque aucune commande par defaut
# RunAsVirtualAccount    : les commandes tournent sous un compte virtuel temporaire
# TranscriptDirectory    : chaque session est enregistree (tracabilite)
# RoleDefinitions        : seul le compte de service a acces, avec le role PatchAudit
New-PSSessionConfigurationFile -Path $pssc `
    -Description "Point de connexion restreint pour l'audit des correctifs" `
    -SessionType RestrictedRemoteServer `
    -RunAsVirtualAccount `
    -TranscriptDirectory $transcripts `
    -RoleDefinitions @{ "$env:COMPUTERNAME\$Compte" = @{ RoleCapabilities = "PatchAudit" } }

if (-not (Test-PSSessionConfigurationFile -Path $pssc)) {
    throw "Fichier de configuration de session invalide : $pssc"
}

# ---------------------------------------------------------------- 4. enregistrement
if (Get-PSSessionConfiguration | Where-Object { $_.Name -eq $NomEndpoint }) {
    Unregister-PSSessionConfiguration -Name $NomEndpoint -NoServiceRestart -Force
}
Register-PSSessionConfiguration -Name $NomEndpoint -Path $pssc -NoServiceRestart -Force -WarningAction SilentlyContinue | Out-Null

"Point de connexion '$NomEndpoint' enregistre sur $env:COMPUTERNAME pour le compte $env:COMPUTERNAME\$Compte."
"Fichier de role     : $(Join-Path $roles 'PatchAudit.psrc')"
"Fichier de session  : $pssc"
"Transcriptions      : $transcripts"
"Il reste a redemarrer le service WinRM sur ce poste : Restart-Service WinRM"
