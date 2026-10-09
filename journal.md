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
- Test sur DKLS777 : PC01 Accessible, PC03 Inaccessible, résultat conforme à l'attendu (capture 028).
- Choix : l'hôte n'est pas listé comme poste supervisé pour ne pas ouvrir WinRM sur une machine personnelle connectée à un Wi-Fi partagé.

### Activation de WinRM sur PC01 (question 4)
- État initial : `Get-Service WinRM` renvoie Stopped.
- `Enable-PSRemoting -Force` dans PC01 (terminal administrateur), réussi du premier coup (capture 029). La commande a :
  - démarré le service WinRM et passé son démarrage en automatique ;
  - créé l'écouteur HTTP (port 5985) ;
  - activé l'exception de pare-feu WinRM ;
  - configuré LocalAccountTokenFilterPolicy, qui donne les droits d'administration à distance aux comptes locaux administrateurs.
- À retenir pour la partie 8 : LocalAccountTokenFilterPolicy élargit la surface d'attaque (un compte local administrateur compromis devient utilisable à distance avec tous ses privilèges).

- Vérification : `Get-Service WinRM` renvoie Running (capture 030).

### Première session distante (question 5)
- Contexte : pas de domaine Active Directory, donc pas de Kerberos. L'authentification se fait en NTLM, qui ne permet pas au client de vérifier l'identité du serveur. PowerShell refuse la connexion tant que la cible n'est pas déclarée dans les TrustedHosts du client.
- Sur l'hôte (PowerShell Windows en administrateur), capture 031 :
  - `Start-Service WinRM` (nécessaire pour accéder au lecteur WSMan:)
  - `Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.56.102" -Force`
- `Enter-PSSession -ComputerName 192.168.56.102 -Credential PC01\admin` : saisie du mot de passe (capture 032), puis invite `[192.168.56.102]: PS C:\Users\admin\Documents>`. La session distante fonctionne.

- Commandes exécutées dans la session (capture 033) : `hostname` renvoie PC01, `whoami` renvoie pc01\admin, `Get-Service wuauserv` est Running, `Get-HotFix` liste 4 correctifs installés le 15/09/2025 (KB5066613, KB5054156, KB5065426, KB5064531). Sortie par `Exit-PSSession`.
- `Test-WSMan -ComputerName 192.168.56.102` depuis l'hôte : réponse de PC01, pile WSMan 3.0 (capture 034).

### Exécution non interactive (question 6)
- `$cred = Get-Credential PC01\admin` : les identifiants sont gardés en mémoire dans un objet PSCredential, le mot de passe n'apparaît jamais en clair dans une commande.
- `Invoke-Command -ComputerName 192.168.56.102 -Credential $cred -ScriptBlock { hostname; (Get-HotFix).Count }` renvoie PC01 et 4 (capture 035).
- Partie 1 terminée côté manipulation. Réponses aux 7 questions rédigées dans `rapport/reponses-questions.md`.

### À savoir pour les prochaines séances
- Après un redémarrage de l'hôte, relancer `Start-Service WinRM` si l'accès à WSMan: échoue. La valeur TrustedHosts est conservée.
- `$cred` disparaît à la fermeture de PowerShell, il faut refaire `Get-Credential`.

- Instantané VirtualBox `WinRM-OK` pris sur PC01 (capture 037) : point de retour si une restriction de la partie 8 casse l'accès distant.

## Partie 2 : inventaire du parc

### Scripts
- `scripts/Commun.ps1` : fonction `Get-Inventaire`, qui lit computers.txt et renvoie un objet par poste. Chargée par les autres scripts pour ne pas dupliquer la lecture du fichier.
- `scripts/02-Inventaire-Parc.ps1` :
  - identifiants passés par `-Credential` ou demandés par `Get-Credential`, jamais écrits dans le script ;
  - étape 1, ping (`Test-Connection -Quiet`) ; étape 2, collecte par `Invoke-Command` dans un `try/catch` avec `-ErrorAction Stop` pour que le script continue et enregistre l'erreur ;
  - collecte par `Get-CimInstance` (Win32_ComputerSystem, Win32_OperatingSystem, Win32_BIOS, Win32_LogicalDisk), `Get-HotFix` et `Get-Service wuauserv` ;
  - une fonction `New-LigneInventaire` garantit les mêmes colonnes pour toutes les lignes, y compris les postes inaccessibles ;
  - export dans `output/Inventory.csv`, séparateur point-virgule.
- Choix : un poste qui répond au ping mais dont la commande distante échoue est classé Inaccessible, avec la cause dans la colonne Erreur.
- Limite connue : un poste dont le pare-feu bloque le ping mais laisse passer WinRM serait classé Inaccessible.

### Difficulté : WinRM bloqué quelques heures après la partie 1
- Symptôme : première exécution de `02-Inventaire-Parc.ps1`, PC01 répond au ping mais la commande distante échoue (« vérifiez que l'exception de pare-feu pour le service Gestion à distance de Windows est activée »). Le script continue et enregistre l'erreur dans Inventory.csv (captures 038 et 039), ce qui valide la gestion d'erreur demandée par le sujet.
- Diagnostic dans PC01 (capture 040) :
  - `Get-NetConnectionProfile` : les deux interfaces sont repassées en profil Public. « Ethernet 2 » est un réseau non identifié (pas de passerelle), le passage en Privé fait en partie 1 n'a pas tenu.
  - `Get-Service WinRM` : Running, le service n'est pas en cause.
  - `Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP*"` : la règle `WINRM-HTTP-In-TCP-NoScope` (Domain, Private) est activée, la règle `WINRM-HTTP-In-TCP` (Public) est désactivée. `Enable-PSRemoting` n'avait ouvert WinRM que pour Domain et Private.
- Correction dans PC01 (capture 041) :
  - `Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -RemoteAddress 192.168.56.1`
  - `Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"`
- Choix : plutôt que de repasser le réseau en Privé (réglage instable ici), on autorise WinRM sur le profil Public uniquement depuis l'adresse du poste d'administration. La correction ne dépend plus du profil réseau et applique déjà le filtrage par adresse source demandé en partie 8.
- Erreur de parcours : j'avais d'abord supposé une règle nommée `WINRM-HTTP-In-TCP-PUBLIC`. La liste réelle des règles a donné le bon nom.

### Résultat de la partie 2
- `Test-WSMan` de nouveau réussi depuis l'hôte, puis `02-Inventaire-Parc.ps1 -Credential $cred` (capture 042) : PC01 Accessible, PC03 Inaccessible.
- Inventory.csv (capture 043), PC01 : modèle VirtualBox, BIOS VirtualBox, Windows 11 Entreprise évaluation 10.0.26200, 64 bits, 4 Go de RAM, 25,1 Go libres sur le disque système, 4 mises à jour, dernière le 15/09/2025, Windows Update Running.
- Vérification du dernier démarrage (capture 044) : dans PC01, le fuseau est correct (Romance Standard Time, Paris), l'horloge aussi, et `(Get-CimInstance Win32_OperatingSystem).LastBootUpTime` renvoie bien 09/10/2026 18:37:31. Le script restitue donc fidèlement la valeur de Windows.
- Explication probable de l'écart avec l'heure réelle (VM arrêtée puis relancée vers 19h50) : le démarrage rapide de Windows. Un arrêt suivi d'un démarrage met le noyau en hibernation au lieu de le recharger, donc LastBootUpTime garde la date du dernier démarrage complet, ici pendant l'installation, avant le réglage du fuseau horaire.
- Intérêt pour le Patch Management : avec le démarrage rapide, « éteindre puis rallumer » n'est pas un redémarrage. Un poste peut garder longtemps des correctifs en attente de redémarrage. La date de dernier démarrage de l'inventaire sert justement à repérer ces postes.
- Les paramètres régionaux de PC01 sont en anglais (dates au format américain). Le script impose son propre format `dd/MM/yyyy HH:mm`, donc l'inventaire reste homogène quel que soit le poste.

### Reste à faire
- Inviter l'enseignant comme collaborateur du dépôt et déposer le lien sur Moodle.
- Partie 3 : inventaire des correctifs (PatchesInventory.csv).
