# Journal de bord : Patch Management PowerShell

Projet de sécurité des systèmes (S. Benayoune), EFREI ING2. Monôme : DOSSOU Sam.
Échéance : 31 octobre 2026.

## 2026-10-02 : cadrage

- Lecture du sujet. Parties 1 à 8, le sujet ne contient pas de partie 5.
- Estimation de charge : 25 à 35 heures en monôme.
- Prérequis identifiés : hyperviseur, une VM Windows, PowerShell 5.1 (intégré), Git, serveur SMTP de test, outil de capture vidéo.

## 2026-10-09 : préparation de l'environnement

### Fait
- Disque C: de l'hôte saturé (8,57 Go libres sur 420 Go), nettoyage puis 54,8 Go libres (captures 001 et 002).
- VirtualBox 7.2.8 déjà installé (capture 004). Aucune VM Windows parmi les VM existantes (capture 003).
- Téléchargement de l'ISO Windows 11 Entreprise évaluation 64 bits (fr-FR) depuis le Centre d'évaluation Microsoft.
- Création de la structure du dépôt.

### Choix techniques
- Architecture réduite autorisée par le sujet : hôte Windows = poste d'administration, VM PC01 = poste supervisé.
- Un poste fictif sera ajouté dans computers.txt pour démontrer le cas INACCESSIBLE sans VM supplémentaire.
- Réseau de la VM : interface 1 en NAT (accès Internet), interface 2 en réseau privé hôte (adresses stables entre l'hôte et la VM). Le réseau NatMediConnect d'un autre projet n'est pas réutilisé.
- VM : 4 Go de RAM, 2 processeurs, disque 50 Go en allocation dynamique pour limiter l'espace occupé.
- Compte local avec mot de passe sur la VM : WinRM refuse les comptes sans mot de passe.

### Difficultés
- Espace disque insuffisant pour une VM. Résolu par nettoyage du disque C:.

### Dépôt Git
- Dépôt GitHub privé créé : https://github.com/Dkls7777/ProjetGestionDesMaj (capture 006).
- Dépôt local sur l'hôte : C:\Users\dossa\ProjetGestionDesMaj, placé hors de Documents pour éviter la synchronisation OneDrive.
- Premier push effectué (3 commits, branche main).
- Commandes clés (PowerShell Windows) : `git init -b main`, `git remote add origin <url>`, `git push -u origin main`.

### Réseau du lab
- Réseau privé hôte VirtualBox déjà présent : VirtualBox Host-Only Ethernet Adapter, 192.168.56.1/24, DHCP activé (capture 011). L'hôte y porte l'adresse 192.168.56.1.

### Création de la VM PC01
- ISO : Windows 11 Entreprise évaluation 26200.6584 (25H2), x64, fr-FR (capture 012).
- Matériel : 4096 Mo, 2 processeurs, EFI (capture 014). Disque VDI de 50 Go en allocation dynamique (capture 015).
- Choix : installation sans assistance de VirtualBox. Elle crée directement le compte local `admin` avec mot de passe et nomme la machine PC01, ce qui évite l'écran de compte Microsoft et le renommage manuel.
- Conséquence : la VM démarre dès la fin de l'assistant, donc la deuxième interface réseau (réseau privé hôte) sera ajoutée après l'installation, VM éteinte.

### Difficulté : PC01 reste sur un écran noir
- Symptôme : après la création, fenêtre de la VM noire pendant 20 minutes, y compris après un redémarrage (captures 016 et 017).
- Vérification 1 (PowerShell Windows) : taille réelle du disque virtuel, restée à 0 Go, donc Windows ne s'est jamais installé.
  `Get-ChildItem "$HOME\VirtualBox VMs\PC01\*.vdi" | Select-Object Name, @{n='Go';e={[math]::Round($_.Length/1GB,2)}}`
- Vérification 2 : lecture de `VBox.log`. Ligne clé : `HM: HMR3Init: Attempting fall back to NEM: VT-x is not available`. L'hyperviseur Windows (Hyper-V) est actif sur l'hôte, VirtualBox ne peut pas utiliser VT-x directement et passe par l'API Hyper-V (mode NEM). Le firmware UEFI de la VM se fige ensuite au chargement de `PciHostBridgeDxe.efi`, aux deux démarrages, avant même d'atteindre l'ISO.
- Cause retenue : conflit entre VirtualBox (VM en UEFI, exigé par Windows 11) et Hyper-V actif sur l'hôte.

- Résolution (PowerShell Windows en administrateur, sur l'hôte) : `bcdedit /set hypervisorlaunchtype off`, puis redémarrage de l'hôte. VirtualBox utilise alors VT-x directement.
- Résultat : au démarrage suivant, PC01 démarre sur l'ISO et l'installation de Windows 11 se lance (capture 018). Cause confirmée.
- Retour arrière possible : `bcdedit /set hypervisorlaunchtype auto` puis redémarrage (nécessaire pour WSL2 ou Docker Desktop).

### PC01 opérationnel
- Installation de Windows 11 Entreprise terminée en une dizaine de minutes, session du compte local `admin` ouverte (capture 019).

- Réseau de PC01 configuré VM éteinte : Adapter 1 en NAT (capture 020), Adapter 2 en réseau privé hôte sur VirtualBox Host-Only Ethernet Adapter (capture 021).

## Partie 1 : préparation de l'environnement

### Adressage (question 1)
- Commande `ipconfig` sur les deux machines (captures 022 et 023).
- PC01 : 192.168.56.102/24 sur le réseau privé hôte (attribuée par le DHCP de VirtualBox), 10.0.2.15 sur le NAT.
- Hôte (poste d'administration) : 192.168.56.1/24 sur la carte VirtualBox Host-Only.
- Les deux machines sont dans le même réseau 192.168.56.0/24.
- Point d'attention : l'adresse de PC01 vient du DHCP, elle pourrait changer. À fixer en statique si elle bouge.

### Connectivité (question 1)
- Premier test depuis l'hôte : `Test-Connection -ComputerName 192.168.56.102 -Count 2` en échec, PingException (capture 025).
- Diagnostic dans PC01 : `Get-NetConnectionProfile` montre « Ethernet 2 » en catégorie Public, le profil le plus restrictif du pare-feu Windows (capture 026). Les demandes d'écho ICMP entrantes y sont bloquées.
- Correction dans PC01 (terminal administrateur) :
  - `Set-NetConnectionProfile -InterfaceAlias "Ethernet 2" -NetworkCategory Private`
  - `Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In`
- Second test réussi, 2 réponses en moins de 1 ms (capture 027). Nom du poste d'administration : DKLS777.

### computers.txt et script de disponibilité (questions 2 et 3)
- `config/computers.txt` : PC01 (192.168.56.102) et PC03 (192.168.56.150), poste fictif sans machine derrière, pour tester le cas inaccessible.
- `scripts/01-Test-Parc.ps1` : lit l'inventaire, ignore les lignes vides, les commentaires et les lignes mal formées, teste chaque poste avec `Test-Connection -Count 1 -Quiet`, produit un objet par poste (Poste, AdresseIP, Etat).
- Choix : l'hôte n'est pas listé comme poste supervisé pour ne pas ouvrir WinRM sur une machine personnelle connectée à un Wi-Fi partagé.

### Reste à faire
- Inviter l'enseignant comme collaborateur du dépôt et déposer le lien sur Moodle.
- Partie 1 : activation de WinRM, Test-WSMan, Enter-PSSession, Invoke-Command, réponses aux questions.
