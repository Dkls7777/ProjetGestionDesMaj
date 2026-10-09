# Index des captures

| N° | Fichier | Partie | Ce que la capture montre | Légende proposée pour le rapport |
|---|---|---|---|---|
| 001 | 001-disque-c-sature-avant-nettoyage.png | Préparation | Disque C: avec 8,57 Go libres sur 420 Go | Espace disque insuffisant sur l'hôte avant la mise en place du lab |
| 002 | 002-disque-c-apres-nettoyage-54go-libres.png | Préparation | Disque C: avec 54,8 Go libres après nettoyage | Espace disque libéré, suffisant pour une VM Windows |
| 003 | 003-virtualbox-vm-existantes-aucune-windows.png | Préparation | Gestionnaire VirtualBox, VM existantes (aucune sous Windows) | État initial de VirtualBox avant création du poste PC01 |
| 004 | 004-virtualbox-version-7.2.8.png | Préparation | Fenêtre À propos : VirtualBox 7.2.8 r173730 | Version de l'hyperviseur utilisé |
| 005 | 005-github-menu-new-repository.png | Préparation | Menu « + » de GitHub avant création du dépôt | Hors rapport (capture de navigation) |
| 006 | 006-github-creation-depot-prive.png | Livrables | Formulaire de création du dépôt ProjetGestionDesMaj, propriétaire Dkls7777, visibilité Private | Création du dépôt GitHub privé du projet |
| 007 | 007-github-depot-en-cours-de-creation.png | Livrables | Même formulaire, bouton « Creating repository... » | Hors rapport (doublon de 006) |
| 008 | 008-github-depot-apres-push.png | Livrables | Dépôt Dkls7777/ProjetGestionDesMaj après le push : arborescence et dernier commit 64c7141 | Contenu du dépôt GitHub après le premier push |
| 009 | 009-github-depot-prive-badge.png | Livrables | Haut de la page du dépôt avec le badge « Private » et le commit 64c7141 | Dépôt GitHub privé ProjetGestionDesMaj |
| 010 | 010-virtualbox-avant-creation-pc01.png | Partie 1 | Gestionnaire VirtualBox avant création de PC01 | Hors rapport (doublon de 003) |
| 011 | 011-virtualbox-reseau-prive-hote-192.168.56.0.png | Partie 1 | Réseau privé hôte VirtualBox : adaptateur 192.168.56.1/24, serveur DHCP activé | Réseau privé hôte utilisé entre le poste d'administration et PC01 |
| 012 | 012-virtualbox-nouvelle-vm-pc01-nom-iso.png | Partie 1 | Assistant de création de PC01 : nom, ISO Windows 11 Entreprise évaluation 26200.6584 fr-FR | Création de la VM PC01 à partir de l'ISO d'évaluation Windows 11 Entreprise |
| 013 | 013-virtualbox-pc01-installation-sans-assistance.png | Partie 1 | Section installation sans assistance de PC01 avant saisie (compte, nom d'hôte PC01) | Hors rapport (état intermédiaire) |
| 014 | 014-virtualbox-pc01-materiel-4096mo-2cpu-efi.png | Partie 1 | Matériel virtuel de PC01 : 4096 Mo de RAM, 2 processeurs, EFI activé | Ressources matérielles allouées à PC01 |
| 015 | 015-virtualbox-pc01-disque-50go-dynamique.png | Partie 1 | Disque virtuel de PC01 : VDI de 50,68 Gio, sans pré-allocation | Disque virtuel de PC01 en allocation dynamique |
| 016 | 016-virtualbox-pc01-en-fonction-ecran-noir.png | Partie 1 | PC01 créée et en fonction (TPM 2.0, EFI, Secure Boot, interface 1 en NAT), écran noir pendant l'installation | À garder seulement si l'écran noir se révèle être une difficulté à documenter |
| 017 | 017-pc01-ecran-noir-apres-redemarrage.png | Partie 1 | Fenêtre de PC01 toujours noire après redémarrage, disque VDI à 0 Go | Difficulté : la VM ne démarre pas sur l'ISO (écran noir) |
| 018 | 018-pc01-installation-windows11-en-cours.png | Partie 1 | PC01 : « Installation en cours de Windows 11 », 11 % effectué, après désactivation de Hyper-V sur l'hôte | Installation de Windows 11 sur PC01 après résolution du conflit avec Hyper-V |
| 019 | 019-pc01-bureau-windows11-session-admin.png | Partie 1 | Bureau Windows 11 de PC01, menu Démarrer ouvert, session du compte local admin | Poste PC01 installé, session du compte local admin ouverte |
| 020 | 020-pc01-reseau-adapter1-nat.png | Partie 1 | Configuration réseau de PC01, Adapter 1 en NAT (MAC 0800275A336B) | Interface 1 de PC01 en NAT pour l'accès Internet |
| 021 | 021-pc01-reseau-adapter2-prive-hote.png | Partie 1 | Configuration réseau de PC01, Adapter 2 en réseau privé hôte sur VirtualBox Host-Only Ethernet Adapter (MAC 080027BC3BBE) | Interface 2 de PC01 sur le réseau privé hôte, utilisée pour l'administration distante |
| 022 | 022-pc01-ipconfig-10.0.2.15-et-192.168.56.102.png | Partie 1, Q1 | `ipconfig` dans PC01 : Ethernet en 10.0.2.15 (NAT), Ethernet 2 en 192.168.56.102 (réseau privé hôte) | Adressage IP de PC01 : 192.168.56.102 sur le réseau d'administration |
| 023 | 023-hote-ipconfig-host-only-192.168.56.1.png | Partie 1, Q1 | `ipconfig` sur l'hôte : carte Ethernet 2 (VirtualBox Host-Only) en 192.168.56.1 | Adressage IP du poste d'administration : 192.168.56.1 |
| 024 | 024-hote-ipconfig-suite-wifi-vmware.png | Partie 1, Q1 | Suite de `ipconfig` sur l'hôte : cartes VMware et Wi-Fi | Hors rapport (cartes sans rapport avec le lab) |
| 025 | 025-hote-ping-pc01-echec-parefeu.png | Partie 1, Q1 | `Test-Connection` de l'hôte vers 192.168.56.102 en échec (PingException) | Premier test de connectivité en échec : le pare-feu de PC01 bloque l'ICMP |
| 026 | 026-pc01-profil-reseau-public.png | Partie 1, Q1 | `Get-NetConnectionProfile` dans PC01 : Ethernet 2 en catégorie Public | Les deux interfaces de PC01 sont classées en profil Public |
| 027 | 027-hote-ping-pc01-reussi-hostname.png | Partie 1, Q1 | `Test-Connection` réussi depuis DKLS777 vers 192.168.56.102, puis `hostname` | Connectivité validée entre le poste d'administration DKLS777 et PC01 |
| 028 | 028-script-01-test-parc-resultat.png | Partie 1, Q3 | Exécution de `01-Test-Parc.ps1` sur DKLS777 : PC01 Accessible, PC03 Inaccessible | Résultat du script de disponibilité à partir de computers.txt |
| 029 | 029-pc01-winrm-stopped-puis-enable-psremoting.png | Partie 1, Q4 | PC01 : service WinRM Stopped, puis `Enable-PSRemoting -Force` réussi (service démarré, exception de pare-feu, LocalAccountTokenFilterPolicy) | Activation de PowerShell Remoting sur PC01 |
| 030 | 030-pc01-winrm-running-test-wsman-local.png | Partie 1, Q4 | PC01 : service WinRM Running, et `Test-WSMan` lancé depuis PC01 vers lui-même | Service WinRM démarré sur PC01 (le test WSMan depuis l'hôte est à refaire) |
| 031 | 031-hote-trustedhosts-192.168.56.102.png | Partie 1, Q5 | Hôte : démarrage de WinRM, ajout de 192.168.56.102 aux TrustedHosts, vérification | Déclaration de PC01 comme hôte de confiance sur le poste d'administration |
| 032 | 032-hote-enter-pssession-demande-identifiants.png | Partie 1, Q5 | Hôte : `Enter-PSSession` vers 192.168.56.102, fenêtre de saisie des identifiants PC01\admin | Authentification avec le compte PC01\admin à l'ouverture de la session distante |
| 033 | 033-hote-session-distante-commandes-sur-pc01.png | Partie 1, Q5 | Session `Enter-PSSession` depuis l'hôte : `hostname` (PC01), `whoami` (pc01\admin), `Get-Service wuauserv` (Running), `Get-HotFix` (4 correctifs) | Session distante interactive sur PC01 et exécution de commandes |
| 034 | 034-hote-test-wsman-vers-pc01.png | Partie 1, Q4 | `Test-WSMan -ComputerName 192.168.56.102` depuis l'hôte, réponse de PC01 (Stack 3.0) | Test de l'accès WinRM à PC01 depuis le poste d'administration |
| 035 | 035-hote-invoke-command-pc01.png | Partie 1, Q6 | `Get-Credential` puis `Invoke-Command` vers PC01 : renvoie PC01 et 4 correctifs | Exécution distante non interactive avec Invoke-Command |
| 036 | 036-virtualbox-pc01-instantanes-avant-prise.png | Partie 1 | Onglet Instantanés de PC01, aucun instantané encore pris | Hors rapport (état avant la prise de l'instantané) |
| 037 | 037-virtualbox-pc01-instantane-winrm-ok.png | Partie 1 | Instantané WinRM-OK de PC01 pris le 09/10/2026 à 20:24 | Instantané de PC01 après configuration de WinRM, point de retour pour la suite |
| 038 | 038-script-02-inventaire-pc01-inaccessible.png | Partie 2 | Première exécution de `02-Inventaire-Parc.ps1` : PC01 et PC03 Inaccessible, CSV exporté | Le script poursuit son exécution malgré l'échec de la commande distante |
| 039 | 039-inventory-csv-erreur-winrm-pc01.png | Partie 2 | Contenu de Inventory.csv : erreur WinRM enregistrée pour PC01 (exception de pare-feu), « Aucune reponse au ping » pour PC03 | Enregistrement de l'erreur rencontrée dans l'inventaire, avec deux causes distinctes |
| 040 | 040-pc01-profils-public-regle-winrm-desactivee.png | Partie 2 / Partie 8 | PC01 : les deux interfaces sont repassées en profil Public, WinRM Running, règle WINRM-HTTP-In-TCP (Public) désactivée, WINRM-HTTP-In-TCP-NoScope (Domain, Private) activée | Diagnostic : le pare-feu bloque WinRM car l'interface est repassée en profil Public |
| 041 | 041-pc01-regle-winrm-public-limitee-192.168.56.1.png | Partie 2 / Partie 8 | PC01 : règle WINRM-HTTP-In-TCP (Public) activée et limitée à RemoteAddress 192.168.56.1 | Ouverture de WinRM sur le profil Public, restreinte au seul poste d'administration |
| 042 | 042-script-02-inventaire-pc01-accessible.png | Partie 2 | `Test-WSMan` réussi depuis l'hôte, puis `02-Inventaire-Parc.ps1` : PC01 Accessible (Windows 11 Entreprise, 64 bits, Windows Update Running), PC03 Inaccessible | Tableau récapitulatif de l'inventaire du parc |
| 043 | 043-inventory-csv-detail-pc01-pc03.png | Partie 2 | Contenu de Inventory.csv : PC01 (VirtualBox, 10.0.26200, 4 Go de RAM, 25,1 Go libres, 4 mises à jour, dernière le 15/09/2025), PC03 avec l'erreur « Aucune reponse au ping » | Inventaire détaillé exporté en CSV |
| 044 | 044-pc01-fuseau-date-dernier-demarrage.png | Partie 2 | PC01 : fuseau Romance Standard Time (Paris), date système correcte, LastBootUpTime au 09/10/2026 18:37:31 | Vérification locale de la date de dernier démarrage renvoyée par le script |
| 045 | 045-pc01-terminal-erreur-pendant-extinction.png | Partie 2 | PC01 : erreur 0xd000003a au lancement de PowerShell pendant l'extinction de Windows | Hors rapport (terminal ouvert pendant le redémarrage) |
| 046 | 046-pc01-redemarrage-fige.png | Partie 2 | PC01 figé sur « Redémarrage en cours » plusieurs minutes après Restart-Computer | Hors rapport, sauf si le blocage est documenté comme difficulté |
