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

### Test de persistance après redémarrage de PC01
- `Restart-Computer` dans PC01. Pendant l'extinction, une exécution du script a relevé Windows Update en `StopPending` avec l'ancienne date de démarrage : le script rapporte l'état réel à l'instant de la mesure, y compris un état transitoire.
- Difficulté : PC01 est resté figé plus de 5 minutes sur « Redémarrage en cours » (capture 046). Résolu par Machine > Redémarrer dans VirtualBox.
- Après redémarrage (capture 047), sans aucune intervention sur PC01 :
  - PC01 est Accessible, donc la règle de pare-feu WinRM limitée à 192.168.56.1 persiste ;
  - le dernier démarrage passe à 10/10/2026 00:53, ce qui confirme l'explication du démarrage rapide ;
  - Windows Update est `Stopped`, état normal : le service wuauserv est à démarrage manuel déclenché et ne tourne que lorsqu'une recherche de mises à jour est en cours. Un état Stopped ne signifie donc pas que Windows Update est désactivé.
- Exemple de résultat versionné : `exemples/Inventory.csv`.

## Partie 3 : inventaire des correctifs

### Script
- `scripts/03-Inventaire-Correctifs.ps1` :
  - sur chaque poste accessible, `Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy` par `Invoke-Command`. La sélection est faite côté poste distant pour que la date arrive déjà sous forme de date, sans dépendre des paramètres régionaux ;
  - postes inaccessibles ignorés avec un avertissement, sans interrompre le script (`try/catch` et `continue`) ;
  - tri par poste puis par date d'installation décroissante, export dans `output/PatchesInventory.csv` ;
  - synthèse par poste : nombre de correctifs, date du plus récent, KB du plus récent.
- Limite : `InstalledOn` ne donne que le jour, pas l'heure. Quand plusieurs correctifs sont installés le même jour (cas de PC01), le « dernier » est départagé par le numéro de KB le plus élevé, ce qui est un choix arbitraire mais stable d'une exécution à l'autre.
- Limite : `Get-HotFix` ne liste que les correctifs enregistrés dans Win32_QuickFixEngineering. Certaines mises à jour (pilotes, définitions antivirus, applications du Store) n'y figurent pas.

### Résultat de la partie 3
- En local sur DKLS777 (capture 048) : 4 correctifs, KB5124010 (29/09/2026), KB5124009 (24/09/2026), KB5126052 (16/09/2026), KB5054156 (23/12/2025), tous installés par AUTORITE NT\Système, c'est-à-dire par Windows Update lui-même.
- Script exécuté sans erreur du premier coup (capture 049) : PC03 ignoré avec un avertissement, 4 correctifs pour PC01 (KB5066613, KB5065426 Security Update, KB5064531, KB5054156), tous du 15/09/2025, compte d'installation non renseigné.
- Synthèse : PC01, 4 correctifs, dernier le 15/09/2025, KB5066613. PC03 Inaccessible.
- PatchesInventory.csv conforme à l'attendu (capture 050). Exemple versionné dans `exemples/`.
- Constat utile pour la partie 4 : les correctifs de PC01 datent de l'image d'installation (septembre 2025). Le poste a plus d'un an de retard sur l'hôte, qui a reçu des correctifs jusqu'au 29/09/2026. Un seul correctif est commun aux deux machines : KB5054156.

## Partie 4 : contrôle de conformité

### Fichiers
- `config/required-patches.txt` : KB5065426 et KB5054156 (présentes sur PC01), KB5124010 (présente sur l'hôte, absente de PC01).
  - Réserve : ces KB sont choisies parmi celles observées dans le lab pour obtenir un cas réaliste. Leur contenu exact n'a pas été vérifié dans le catalogue Microsoft, et KB5124010 pourrait ne pas s'appliquer à la version de Windows de PC01. Une vraie politique se construit à partir des bulletins de sécurité Microsoft, par version de Windows.
- `scripts/Commun.ps1` : ajout de `Get-CorrectifsRequis` (ignore lignes vides et commentaires, met en majuscules, rejette ce qui ne ressemble pas à KB suivi de chiffres).
- `scripts/04-Controle-Conformite.ps1` :
  - récupère les KB installées par `Invoke-Command { (Get-HotFix).HotFixID }` ;
  - KB manquantes = KB requises absentes des KB installées (`-notcontains`) ;
  - états CONFORME (aucune manquante), NON CONFORME, INACCESSIBLE ;
  - date et heure du contrôle, détail des KB manquantes, export `output/ComplianceReport.csv` ;
  - taux de conformité = postes conformes / postes contrôlés, les postes inaccessibles étant exclus du calcul.
- Réponse à la question 7 rédigée dans `rapport/reponses-questions.md`.

### Difficulté : fonction introuvable au premier lancement
- Symptôme : `Get-CorrectifsRequis : Le terme n'est pas reconnu`, puis « Aucun correctif requis ».
- Cause : le fichier `Commun.ps1` présent sur le poste était l'ancienne version, sans la nouvelle fonction (fichier non synchronisé avant le test). Le script chargeait donc une bibliothèque incomplète.
- Résolution : mise à jour de `Commun.ps1`, vérification par comparaison des tailles de fichiers, puis relance.
- Leçon : quand un script dépend d'un fichier commun, toujours vérifier que les deux sont à la même version avant de conclure à un bug.

### Résultat de la partie 4, cas non conforme
- Contrôle du 10/10/2026 01:11:37 (capture 051) : 3 KB requises, PC01 NON CONFORME avec 1 KB manquante (KB5124010), PC03 INACCESSIBLE.
- Taux de conformité : 0 %, soit 0 poste conforme sur 1 contrôlé, PC03 étant exclu du calcul.

### Résultat de la partie 4, cas conforme
- KB5124010 mise en commentaire dans required-patches.txt (capture 054), puis contrôle du 10/10/2026 01:15:29 (capture 055) : 2 KB requises, PC01 CONFORME, taux de 100 % (1 poste conforme sur 1 contrôlé).
- Les deux tests montrent que l'état d'un même poste dépend entièrement de la politique : c'est l'illustration directe de la question 7.

- Politique remise à 3 KB, contrôle final du 10/10/2026 01:17:21 (capture 056). ComplianceReport.csv contient pour chaque poste : KB requises, nombre et liste des KB manquantes, état, date du contrôle et erreur éventuelle. Exemple versionné dans `exemples/`.
- Partie 4 terminée.

## Partie 6 : rapport de sécurité

### Choix d'architecture
- Les scripts 01 à 04 interrogent chacun le parc séparément. Pour le rapport, un script principal `scripts/PatchManager.ps1` fait un audit complet en une seule passe : un seul `Invoke-Command` par poste récupère la version de Windows, le dernier démarrage, l'état de Windows Update et la liste des KB installées. Moins de connexions, et toutes les mesures d'un poste datent du même instant.
- Les scripts 01 à 04 restent dans le dépôt comme étapes de construction, chacun répondant à une partie du sujet.

### Fichiers
- `scripts/Commun.ps1` : ajout de `Write-Journal`, qui écrit une ligne `date heure ; champ ; champ` en fin de fichier (`Add-Content`), donc l'historique des exécutions est conservé.
- `scripts/PatchManager.ps1` produit :
  - `output/SecurityReport.csv` : une ligne par poste avec les 11 informations demandées ;
  - `output/SecurityReport.html` : synthèse globale, section des postes nécessitant une intervention, détail par poste, états en couleur ;
  - `output/PatchManager.log` : début d'audit, état de chaque poste, rapport généré, fin d'audit.
- Synthèse globale : total, accessibles, inaccessibles, conformes, non conformes, total de correctifs manquants, taux de conformité sur les postes accessibles.
- Sécurité du rapport HTML : les valeurs issues des postes distants passent par `[System.Net.WebUtility]::HtmlEncode` avant insertion dans la page, pour qu'un nom ou une valeur contenant du HTML ne puisse pas être interprété par le navigateur.
- Détail pratique : les accents de la page HTML sont écrits en entités (`&eacute;`), ce qui garde le script en ASCII pur et évite les problèmes d'encodage de PowerShell 5.1.
- `.gitignore` : exception `!exemples/*.log` pour pouvoir versionner un exemple de journal.

### Résultat de la partie 6, console
- `PatchManager.ps1` exécuté sans erreur du premier coup, audit du 10/10/2026 01:24:33 (capture 057).
- Synthèse : 2 postes, 1 accessible, 1 inaccessible, 0 conforme, 1 non conforme, 1 correctif manquant, taux de conformité 0 %.
- Postes nécessitant une intervention : PC01 (NON CONFORME, KB5124010 manquante) et PC03 (INACCESSIBLE, aucune réponse au ping).

### Résultat de la partie 6, rapport HTML et journal
- `SecurityReport.html` (captures 058 et 059) : accents corrects, synthèse globale, section des postes à traiter (NON CONFORME en rouge, INACCESSIBLE en jaune), détail par poste avec les 11 informations demandées.
- `PatchManager.log` (capture 060) : début d'audit, PC01 accessible puis non conforme avec la KB manquante, PC03 inaccessible, rapport généré, fin d'audit.
- Second audit à 01:30:16 : ses lignes s'ajoutent à la suite du premier (capture 062). L'historique est bien conservé.
- Mesure : un audit de 2 postes dure environ 13 secondes, dont 8 à 9 pour la connexion WinRM à PC01 et 4 pour l'attente du ping de PC03. Sur un grand parc, il faudrait paralléliser (`Invoke-Command` accepte une liste de machines).
- Entre les deux audits, Windows Update est passé de Running à Stopped : le service s'arrête de lui-même après usage.
- Exemples versionnés dans `exemples/` : SecurityReport.csv, SecurityReport.html, PatchManager.log.
- Partie 6 terminée.

## Partie 7 : notification

### Fichiers
- `config/notification.psd1` : serveur SMTP (127.0.0.1, port 2525), expéditeur, destinataire, chemin optionnel d'un fichier d'identifiants. Lu par `Import-PowerShellDataFile`, qui n'exécute aucun code.
- `scripts/PatchManager.ps1` : ajout du bloc de notification après la génération du rapport.
  - Déclenchement uniquement s'il existe au moins un poste NON CONFORME ou INACCESSIBLE. Sinon aucune notification, et une ligne « Aucune anomalie » dans le journal.
  - Message conforme au modèle du sujet : objet `[PATCH MANAGEMENT] Anomalies détectées`, date du contrôle, postes contrôlés, non conformes, inaccessibles, puis le détail par poste avec les KB manquantes.
  - Pièce jointe : SecurityReport.html.
  - Envoi par `Send-MailMessage` dans un `try/catch` : « Notification envoyee a ... » ou « ERREUR ; Notification non envoyee » dans le journal.
  - Paramètre `-SansNotification` pour lancer un audit sans envoyer de mail.
- Aucun mot de passe dans le script ni dans la configuration. Si le serveur exige une authentification, les identifiants sont lus dans un fichier créé par `Get-Credential | Export-Clixml`, où le mot de passe est chiffré par Windows (DPAPI) : seul le même compte, sur le même poste, peut le relire. `.gitignore` exclut `*.clixml`.
- Serveur de test : smtp4dev 3.15.0, en local. Il reçoit les mails sans les relayer et les affiche dans une interface web.
- Réponses aux questions 2 et 3 rédigées dans `rapport/reponses-questions.md`.

### Installation de smtp4dev
- Téléchargement de `Rnwood.Smtp4dev-win-x64-3.15.0.zip` depuis les publications GitHub du projet, décompression dans `C:\Users\dossa\smtp4dev`, hors du dépôt.
- Lancement dans une seconde fenêtre PowerShell : `.\Rnwood.Smtp4dev.exe --smtpport=2525 --urls=http://127.0.0.1:5000` (capture 064). SMTP sur le port 2525, interface web sur http://127.0.0.1:5000.
- Difficulté de sécurité : au premier lancement, Windows a proposé d'autoriser le programme dans le pare-feu et l'autorisation a été accordée. smtp4dev écoute sur toutes les interfaces, donc aussi sur le Wi-Fi partagé, et expose en plus IMAP (143) et POP3 (110), qui permettent de lire les mails reçus, donc le rapport listant les postes vulnérables.
- Correction (capture 065) : `Get-NetFirewallRule -DisplayName "*smtp4dev*" | Set-NetFirewallRule -Action Block`. Les deux règles créées (profil Public) passent en Block. L'usage local reste possible, le trafic de bouclage n'étant pas filtré par ces règles.
- Leçon pour la partie 8 : une demande d'autorisation du pare-feu acceptée par réflexe ouvre un service au réseau. Le principe de moindre exposition s'applique aussi aux outils de test.

### Résultat de la partie 7, cas avec anomalies
- Audit du 10/10/2026 01:48:10 (capture 067) : 2 anomalies, « Notification envoyee a admin@entreprise.local ».
- Mail reçu dans smtp4dev à 01:48:18 (capture 068) : expéditeur patchmanager@entreprise.local, objet `[PATCH MANAGEMENT] Anomalies détectées` avec les accents corrects, corps conforme au modèle du sujet (date, 2 postes contrôlés, 1 non conforme, 1 inaccessible, détail par poste), pièce jointe SecurityReport.html.
- Fichiers de test ajoutés dans `config/tests/` pour le cas sans anomalie : un inventaire réduit à PC01 et une politique réduite aux 2 KB qu'il possède. Ils se passent au script par `-InventoryPath` et `-RequiredPath`, sans toucher à la configuration réelle.

### Résultat de la partie 7, cas sans anomalie
- Audit du 10/10/2026 01:58:30 avec `-InventoryPath` et `-RequiredPath` pointant sur `config/tests/` (capture 069) : 1 poste, CONFORME, taux de 100 %, section intervention « Aucun », et « Aucune anomalie detectee : pas de notification ». Le script se termine sans envoyer de mail.

- Vérification dans smtp4dev (capture 070) : toujours un seul mail après cet audit.

### Résultat de la partie 7, cas d'échec d'envoi
- smtp4dev arrêté par Ctrl+C, puis audit du 10/10/2026 02:01:50 (capture 071) : avertissement « Notification non envoyee : Impossible de se connecter au serveur distant ». Le rapport est quand même produit et le script se termine normalement.
- Journal (capture 072), les trois cas à la suite :
  - 01:48:18, « Notification envoyee a admin@entreprise.local » ;
  - 01:58:36, « Aucune anomalie ; Pas de notification » ;
  - 02:02:01, « ERREUR ; Notification non envoyee ; Impossible de se connecter au serveur distant ».
- Partie 7 terminée.

### Difficulté : disque de l'hôte saturé
- Premier symptôme : smtp4dev ne redémarre pas, `SQLite Error 10: 'disk I/O error'` sur sa base, puis « SMTP server failed to start ». Supprimer la base n'y change rien.
- Vraie cause : `Get-PSDrive C` affiche 0 Go libre, alors qu'il y en avait 54,8 l'après-midi.
- Analyse par `Get-ChildItem "$HOME\VirtualBox VMs\PC01" -Recurse -File | Sort-Object Length -Descending` :
  - `PC01.vdi`, 18,0 Go : disque figé au moment de l'instantané WinRM-OK ;
  - disque différentiel `{56ef2235...}.vdi`, 28,1 Go : tout ce qui a changé depuis l'instantané, en 6 heures ;
  - fichier `.sav`, 2,0 Go : mémoire vive enregistrée avec l'instantané, pris VM allumée.
- Explication : PC01, installé depuis une image de septembre 2025, télécharge et installe un an de mises à jour par Windows Update. Avec un instantané actif, VirtualBox conserve l'ancien état du disque en plus du nouveau, donc chaque bloc modifié consomme de l'espace supplémentaire.
- Conséquence : VirtualBox a mis PC01 en pause automatiquement (capture 073), ce qui protège le disque virtuel de la corruption.
- Résolution immédiate : retrait de l'ISO du lecteur virtuel de PC01 (il verrouillait le fichier), suppression de l'ISO (6 Go) et d'autres fichiers, 9,8 Go libres, reprise de la VM, suspension de Windows Update dans PC01 (capture 074), puis arrêt de la VM.
- Après nettoyage complémentaire : 31,3 Go libres sur C: (capture 075). Travail sauvegardé par le commit 2a2a6ee.
- Suppression de l'instantané WinRM-OK, VM éteinte : VirtualBox fusionne le disque différentiel dans le disque de base. Résultat (capture 076) : un seul fichier `PC01.vdi` de 32,26 Go au lieu de 48 Go répartis sur trois fichiers, et 48,8 Go libres sur C:.
- Bilan chiffré : 0 Go libre au pire, 48,8 Go après résolution. PC01 occupe 32 Go, contre 18 Go juste après son installation : la différence correspond aux mises à jour Windows téléchargées en quelques heures.
- Leçons :
  - surveiller l'espace disque de l'hôte quand une VM a un instantané actif ;
  - prendre les instantanés VM éteinte (pas de fichier de mémoire) ;
  - suspendre Windows Update sur un poste de lab dont on veut garder l'état stable. Sans cela, PC01 aurait fini par installer la KB manquante et serait devenu conforme entre deux démonstrations.
  - une erreur applicative peu claire (« disk I/O error ») cachait un problème système : vérifier les ressources de base avant de soupçonner le logiciel.

## État en fin de séance du 10/10/2026 (03h00)

- Parties 1, 2, 3, 4, 6 et 7 terminées et poussées sur GitHub (dernier commit : 0592cde).
- PC01 éteinte, un seul disque de 32 Go, instantané `Avant-partie-8` pris VM éteinte (capture 077). 48,8 Go libres sur l'hôte.
- Hyper-V désactivé sur l'hôte (`bcdedit /set hypervisorlaunchtype off`). À réactiver par `auto` si WSL2 ou Docker redeviennent nécessaires.
- smtp4dev installé dans `C:\Users\dossa\smtp4dev`, arrêté. Sa base a été supprimée, il devrait redémarrer maintenant que le disque a de la place.

## Séance du 11/10/2026 : partie 8

### Reprise
- PC01 démarrée. Windows Update est bien suspendu, jusqu'au 14/11/2026 (capture 078).
- Hôte : 45,7 Go libres, `Start-Service WinRM`, `Test-WSMan` vers 192.168.56.102 réussi : l'adresse DHCP de PC01 n'a pas changé (capture 079).
- `PatchManager.ps1 -Credential $cred -SansNotification` (capture 080) : PC01 toujours NON CONFORME, KB5124010 manquante. Windows Update n'a donc pas installé cette KB avant la suspension, le scénario de démonstration est intact.

### Point 2 : utilisateurs autorisés à ouvrir une session distante
- Première exécution faite par erreur sur l'hôte DKLS777 (capture 082) : elle renseigne sur le poste d'administration (compte `dossa` administrateur local, groupe Utilisateurs de gestion à distance vide).
- Vérification sur PC01, lancée depuis l'hôte par `Invoke-Command` (capture 083) :
  - `Get-PSSessionConfiguration` : le point de connexion par défaut `microsoft.powershell` autorise trois entités, INTERACTIF, BUILTIN\Administrateurs et BUILTIN\Utilisateurs de gestion à distance ;
  - `Get-LocalUser` : un seul compte actif, `admin`. Administrateur, Invité, DefaultAccount et WDAGUtilityAccount sont désactivés ;
  - `Get-LocalGroupMember -SID S-1-5-32-544` (Administrateurs) : `admin` et `Administrateur` ;
  - `Get-LocalGroupMember -SID S-1-5-32-580` (Utilisateurs de gestion à distance) : aucun membre.
- Conclusion : aujourd'hui, seul le compte `admin` peut ouvrir une session distante sur PC01, et il est administrateur local. La solution fonctionne donc avec beaucoup plus de droits que nécessaire pour lire des correctifs, ce que corrige le point 3.
- Les groupes sont désignés par leur SID et non par leur nom, qui dépend de la langue du système.

### Point 3 : compte dédié à moindre privilège
- Création sur PC01 du compte local `svc-patch`, depuis l'hôte, par `Invoke-Command` avec le compte `admin` (capture 084) :
  - mot de passe saisi par `Read-Host -AsSecureString` et transmis en `SecureString` : il n'apparaît ni dans la commande, ni dans l'historique, ni dans un fichier ;
  - `New-LocalUser -Name "svc-patch" ... -PasswordNeverExpires -UserMayNotChangePassword` ;
  - `Add-LocalGroupMember -SID S-1-5-32-580 -Member "svc-patch"` : membre du seul groupe Utilisateurs de gestion à distance.
- Résultat : `svc-patch` n'est pas administrateur. Il peut ouvrir une session WinRM, rien de plus.
- Erreur de parcours : premier essai refusé, la description du compte dépassait la limite de 48 caractères de `New-LocalUser`.
- Réserve : `-PasswordNeverExpires` convient à un lab. En production, un compte de service doit avoir une rotation de mot de passe, ou être un compte de service géré (gMSA) dans un domaine Active Directory.

- Test du compte `svc-patch` sur le point de connexion par défaut (capture 085) :
  - la connexion WinRM est acceptée, `whoami` renvoie pc01\svc-patch et le test d'appartenance au rôle Administrateur renvoie False ;
  - `Get-Service wuauserv` fonctionne ;
  - `Get-CimInstance Win32_OperatingSystem` et `Get-HotFix` échouent avec « Accès refusé » (HRESULT 0x80041003).
- Analyse : `Get-CimInstance` et `Get-HotFix` interrogent WMI. Dans une session WinRM, l'ouverture de session est de type réseau, et WMI exige alors le droit « Activation à distance » sur l'espace de noms root\cimv2, que seuls les administrateurs possèdent par défaut. Retirer les droits d'administration ne suffit donc pas : le compte restreint ne peut plus faire le travail.
- Deux solutions possibles : accorder à `svc-patch` des droits WMI sur root\cimv2 (il pourrait alors lire toutes les classes WMI du poste), ou utiliser JEA pour n'exposer que la lecture nécessaire. Choix : JEA, plus restrictif, et demandé au point 7.

### Points 3 et 7 : mise en œuvre de JEA
- `scripts/jea/Install-JeaPatchAudit.ps1`, à exécuter sur le poste administré avec un compte administrateur. Il crée :
  - un fichier de rôle `PatchAudit.psrc` qui définit une seule fonction visible, `Get-PatchAudit`, renvoyant la version de Windows, le dernier démarrage, l'état de Windows Update et la liste des KB installées ;
  - un fichier de session `PatchAudit.pssc` : type `RestrictedRemoteServer` (mode NoLanguage, quasiment aucune commande), `RunAsVirtualAccount` (les commandes tournent sous un compte virtuel temporaire, pas sous le compte de l'appelant), transcription de chaque session, et rôle attribué au seul compte `svc-patch` ;
  - le point de connexion `PatchAudit`, enregistré par `Register-PSSessionConfiguration`.
- `scripts/PatchManager.ps1` : nouveau paramètre `-ConfigurationName`. S'il est fourni, le script se connecte à ce point de connexion et n'y appelle que `Get-PatchAudit`.
- Principe : `svc-patch` n'a aucun droit d'administration. Même si son mot de passe est volé, l'attaquant ne peut lancer qu'une fonction de lecture, et chaque session est enregistrée.

- Installation lancée depuis l'hôte : `Invoke-Command -ComputerName 192.168.56.102 -Credential $cred -FilePath .\scripts\jea\Install-JeaPatchAudit.ps1`.
- Difficulté : la commande se termine par « L'opération d'entrée/sortie a été abandonnée » (WinRMOperationAborted). Cause : l'enregistrement du point de connexion a redémarré le service WinRM de PC01 malgré `-NoServiceRestart`, ce qui a coupé la session qui exécutait le script. L'installation, elle, était terminée.
- Vérification (capture 086) : `Test-WSMan` répond, `Get-PSSessionConfiguration` liste `PatchAudit` avec pour seule permission `PC01\svc-patch AccessAllowed`, et les fichiers `.pssc` et `.psrc` sont présents.
- Leçon : une erreur de transport ne dit rien du résultat de l'opération distante. Il faut vérifier l'état réel du poste avant de relancer.

### Résultat de JEA
- `Invoke-Command -Credential $credSvc -ConfigurationName PatchAudit -ScriptBlock { Get-PatchAudit }` (capture 087) : toutes les informations reviennent sans erreur, alors que les mêmes lectures étaient refusées sur le point de connexion par défaut.
- Commandes non autorisées : `Get-Process` (capture 088) et `whoami` (capture 089) renvoient « n'est pas reconnu ». Elles ne sont pas refusées, elles n'existent pas dans la session.
- `Get-Command` (capture 090) : 9 commandes au total, `Get-PatchAudit` et 8 commandes de base de toute session restreinte (Clear-Host, Exit-PSSession, Get-Command, Get-FormatData, Get-Help, Measure-Object, Out-Default, Select-Object).
- `PatchManager.ps1 -Credential $credSvc -ConfigurationName PatchAudit -SansNotification` (capture 091) : résultat identique à celui obtenu avec le compte `admin`, PC01 NON CONFORME, KB5124010 manquante.
- Observation : la liste des KB de PC01 contient maintenant KB5126052, installée par Windows Update avant la suspension. KB5124010 reste absente.
- Bilan du moindre privilège : l'audit n'utilise plus aucun compte administrateur. Le compte `admin` ne sert plus qu'à l'installation.

### Durcissement final du compte de service
- `Remove-LocalGroupMember -SID S-1-5-32-580 -Member "svc-patch"` : le groupe Utilisateurs de gestion à distance est de nouveau vide (capture 092). L'accès au point de connexion JEA ne dépend pas de ce groupe, il est accordé par le rôle défini dans le fichier `.pssc`.
- Vérification (capture 093) : avec `svc-patch`, une session sur le point de connexion par défaut échoue (« Accès refusé », AccessDenied), tandis que `Get-PatchAudit` sur `PatchAudit` fonctionne.
- État final : `svc-patch` n'appartient à aucun groupe privilégié et ne peut ouvrir qu'une session JEA limitée à une fonction de lecture.

### Traçabilité des sessions JEA
- Transcription lue dans `C:\ProgramData\JEA\PatchAudit\Transcripts` (capture 094) : heure de début, utilisateur connecté `PC01\svc-patch`, identité d'exécution `WinRM Virtual Users\WinRM VA_6_PC01_svc-patch`, nom de la configuration, commande invoquée et résultat, heure de fin.
- Le compte virtuel est créé pour la durée de la session et porte le nom de l'appelant : on garde le lien entre l'action et la personne, bien que la commande s'exécute avec d'autres droits.

### Reste à faire
- Partie 8 : risques de WinRM, utilisateurs autorisés à ouvrir une session distante, compte dédié à moindre privilège, droits NTFS sur les fichiers produits, règles de pare-feu WinRM (déjà limitées à 192.168.56.1), mode d'authentification et Kerberos, JEA, stratégie de conservation des rapports et journaux.
- Inviter l'enseignant comme collaborateur du dépôt et déposer le lien sur Moodle.
- Relire `rapport/reponses-questions.md` et le reformuler.
- Rapport final Word et PDF (page de garde EFREI, sommaire cliquable, légendes sous les captures).
- Vidéo de démonstration d'environ 15 minutes.
