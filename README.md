# Patch Management Windows en PowerShell

Projet de sécurité des systèmes (S. Benayoune), EFREI ING2, 2026.
Auteur : DOSSOU Sam (monôme).

Solution simplifiée d'audit des correctifs de sécurité d'un parc Windows. Depuis un poste d'administration, elle lit un inventaire, interroge chaque poste par PowerShell Remoting (WinRM), vérifie la présence des correctifs obligatoires, produit un rapport CSV et HTML, journalise son exécution et prévient l'administrateur par mail en cas d'anomalie.

## Chaîne de traitement

`computers.txt` → test de disponibilité → collecte distante (WinRM) → comparaison avec `required-patches.txt` → rapport CSV et HTML → archivage et empreintes → journal → notification

## Structure du dépôt

| Élément | Contenu |
|---|---|
| `scripts/PatchManager.ps1` | Script principal : audit complet, rapport, archivage, journal, notification (parties 6, 7 et 8) |
| `scripts/Commun.ps1` | Fonctions partagées : lecture de l'inventaire et des correctifs requis, journal, rotation |
| `scripts/01-Test-Parc.ps1` | Partie 1 : disponibilité des postes |
| `scripts/02-Inventaire-Parc.ps1` | Partie 2 : inventaire système, `Inventory.csv` |
| `scripts/03-Inventaire-Correctifs.ps1` | Partie 3 : correctifs installés, `PatchesInventory.csv` |
| `scripts/04-Controle-Conformite.ps1` | Partie 4 : conformité, `ComplianceReport.csv` |
| `scripts/jea/Install-JeaPatchAudit.ps1` | Partie 8 : point de connexion JEA restreint, à installer sur chaque poste administré |
| `scripts/Test-IntegriteRapports.ps1` | Partie 8 : contrôle d'intégrité des rapports archivés |
| `config/computers.txt` | Inventaire du parc, une ligne `NOM;ADRESSE_IP` par poste |
| `config/required-patches.txt` | Correctifs obligatoires, une KB par ligne |
| `config/notification.psd1` | Paramètres d'envoi du mail (aucun mot de passe) |
| `config/tests/` | Jeux de test (cas sans anomalie) |
| `exemples/` | Exemples réels de fichiers produits dans le lab |
| `output/` | Fichiers générés à l'exécution, non versionnés |
| `captures/` | Captures d'écran et leur index (`INDEX.md`) |
| `rapport/` | Réponses aux questions du sujet et rapport final |
| `journal.md` | Journal de bord : étapes, choix techniques, difficultés et résolutions |

## Environnement de test

| Machine | Rôle | Adresse |
|---|---|---|
| DKLS777 (hôte Windows 11) | Poste d'administration | 192.168.56.1 |
| PC01 (VM VirtualBox, Windows 11 Entreprise) | Poste supervisé | 192.168.56.102 |
| PC03 | Poste fictif, pour le cas inaccessible | 192.168.56.150 |

## Utilisation

Depuis PowerShell Windows, à la racine du dépôt, sur le poste d'administration.

Audit avec un compte administrateur du poste distant :

```powershell
$cred = Get-Credential PC01\admin
.\scripts\PatchManager.ps1 -Credential $cred
```

Audit avec le compte de service à moindre privilège, par le point de connexion JEA (mode recommandé) :

```powershell
$credSvc = Get-Credential PC01\svc-patch
.\scripts\PatchManager.ps1 -Credential $credSvc -ConfigurationName PatchAudit
```

Options utiles :

| Paramètre | Effet |
|---|---|
| `-SansNotification` | N'envoie pas de mail |
| `-InventoryPath`, `-RequiredPath` | Utilise un autre inventaire ou une autre liste de correctifs |
| `-TailleMaxJournalKo`, `-RetentionJours` | Règle la rotation du journal et la durée de conservation des archives |

Contrôle d'intégrité des rapports archivés :

```powershell
.\scripts\Test-IntegriteRapports.ps1
```

## Prérequis

- Windows PowerShell 5.1 sur le poste d'administration.
- Sur chaque poste administré : `Enable-PSRemoting -Force`, règle de pare-feu WinRM limitée à l'adresse du poste d'administration.
- Hors domaine : adresse du poste administré déclarée dans les TrustedHosts du poste d'administration.
- Pour la notification : un serveur SMTP. Le lab utilise smtp4dev en local, port 2525.

## Sécurité

- Aucun mot de passe dans les scripts ni dans la configuration : identifiants demandés à l'exécution ou lus dans un fichier chiffré par DPAPI.
- Audit possible sans aucun compte administrateur, grâce à JEA : le compte de service ne peut appeler qu'une fonction de lecture, et chaque session est transcrite.
- Pare-feu WinRM des postes administrés limité à l'adresse du poste d'administration.
- Rapports archivés en lecture seule avec empreinte SHA-256, droits NTFS restreints.

## Limites connues

- Un poste dont le pare-feu bloque le ping est considéré comme inaccessible, même si WinRM répond.
- La liste des correctifs requis est une simple liste de numéros de KB : elle ne gère ni le remplacement d'une KB par une plus récente, ni la version de Windows concernée.
- Les postes sont interrogés l'un après l'autre.
- Authentification NTLM, faute de domaine Active Directory dans le lab.
- Les empreintes sont conservées sur le même poste que les rapports.
