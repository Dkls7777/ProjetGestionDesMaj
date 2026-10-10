# Réponses aux questions du sujet

Brouillon alimenté au fil du projet, repris dans le rapport final. À relire et reformuler avec tes mots.

## Partie 1 : préparation de l'environnement

### Quel est le rôle de WinRM dans PowerShell Remoting ?

WinRM (Windows Remote Management) est l'implémentation Microsoft du protocole standard WS-Management. C'est le service qui écoute sur le poste distant, authentifie l'appelant et transporte les échanges. PowerShell Remoting s'appuie dessus : quand on lance `Enter-PSSession` ou `Invoke-Command`, la commande est envoyée au service WinRM de la cible, qui démarre un processus PowerShell hôte, l'exécute et renvoie le résultat sous forme d'objets sérialisés. Sans WinRM démarré et configuré sur la cible, aucune commande distante n'aboutit.

Dans le lab : service WinRM arrêté par défaut sur PC01 (capture 029), puis démarré (capture 030).

### Quelle commande permet d'activer PowerShell Remoting ?

`Enable-PSRemoting -Force`, dans une console PowerShell lancée en administrateur sur le poste à administrer. Elle démarre le service WinRM et le passe en démarrage automatique, crée un écouteur HTTP, active l'exception de pare-feu et enregistre les configurations de session. Sur un poste hors domaine, elle configure aussi LocalAccountTokenFilterPolicy pour que les comptes locaux administrateurs gardent leurs droits à distance (capture 029).

### Quels ports réseau sont utilisés par WinRM ?

- TCP 5985 pour HTTP (utilisé dans le lab).
- TCP 5986 pour HTTPS.

### Pourquoi le pare-feu Windows peut-il empêcher une connexion PowerShell distante ?

Le pare-feu Windows bloque par défaut les connexions entrantes qui ne correspondent à aucune règle d'autorisation. Tant que la règle « Gestion à distance de Windows (HTTP-Entrée) » n'est pas activée, le port 5985 est fermé et la connexion échoue même si le service WinRM tourne. Le profil réseau compte aussi : sur un réseau classé Public, les règles sont plus strictes (l'accès WinRM y est limité au sous-réseau local, voire refusé).

Dans le lab, on a observé le même mécanisme avec le ping : la carte du réseau d'administration de PC01 était en profil Public et le pare-feu bloquait l'ICMP (captures 025 et 026). Après passage en profil Privé et activation de la règle, le ping passe (capture 027).

### Quelle différence entre Test-Connection et Test-WSMan ?

- `Test-Connection` envoie un ping ICMP. Il vérifie que la machine est joignable au niveau réseau, rien de plus.
- `Test-WSMan` interroge le service WinRM sur le port 5985. Il vérifie que le service écoute et répond, donc que l'administration distante est possible (capture 034).

Les deux résultats sont indépendants : une machine peut répondre au ping avec WinRM arrêté, et à l'inverse avoir WinRM ouvert alors que le pare-feu bloque le ping.

### Pourquoi vérifier l'accessibilité d'une machine avant une commande distante ?

- Éviter d'attendre le délai d'expiration de WinRM sur chaque poste éteint, ce qui ralentit fortement l'audit d'un grand parc.
- Distinguer les causes d'échec : poste éteint ou hors réseau, WinRM fermé, ou problème de droits. Le rapport est alors exploitable par l'administrateur.
- Permettre au script de continuer proprement avec les autres postes et de journaliser un état clair (Inaccessible) au lieu d'une erreur brute.

### Quels problèmes de sécurité si PowerShell Remoting est activé sans restriction ?

- Exécution de code à distance : tout compte autorisé (ou volé) peut lancer des commandes avec ses privilèges sur le poste.
- Mouvement latéral : un attaquant qui compromet un compte administrateur réutilisé sur plusieurs postes rebondit de machine en machine. En NTLM, le vol du condensat du mot de passe peut suffire (pass-the-hash).
- LocalAccountTokenFilterPolicy rend les comptes locaux administrateurs pleinement utilisables à distance.
- Absence d'authentification du serveur hors Kerberos ou HTTPS : avec NTLM sur HTTP et des TrustedHosts trop larges (par exemple `*`), le client peut envoyer ses identifiants à une machine usurpée.
- Surface d'attaque étendue si le port 5985 est joignable depuis tous les réseaux et non depuis le seul poste d'administration.

Mesures traitées en partie 8 : filtrage du pare-feu par adresse source, compte dédié à moindre privilège, HTTPS ou Kerberos, JEA, journalisation.

## Partie 4 : contrôle de conformité

### Pourquoi la politique de conformité doit-elle être régulièrement mise à jour ?

- Microsoft publie de nouveaux correctifs de sécurité chaque mois (Patch Tuesday), plus des correctifs hors cycle pour les failles exploitées activement. Une liste figée devient vite obsolète : un poste peut rester « conforme » à une politique ancienne tout en étant vulnérable aux failles publiées depuis.
- Les correctifs sont cumulatifs et se remplacent. Une KB exigée peut être remplacée par une plus récente : un poste à jour n'a alors plus l'ancienne KB et apparaîtrait à tort non conforme.
- Les KB dépendent de la version de Windows. Quand le parc évolue (nouvelle version, nouveaux postes), la liste doit suivre, sinon elle exige des correctifs qui ne s'appliquent pas à certaines machines.
- Certaines versions arrivent en fin de support et ne reçoivent plus de correctifs : la politique doit alors exiger une montée de version plutôt qu'une KB.
- La priorité dépend de la menace du moment : une faille activement exploitée justifie d'ajouter sa KB en urgence.

Dans le lab : PC01 est installé depuis une image de septembre 2025 et n'a reçu aucun correctif depuis, alors que le poste d'administration en a reçu jusqu'au 29/09/2026. Avec une politique datée de 2025, PC01 serait déclaré conforme malgré un an de retard.

Limite de notre solution : une simple liste de numéros de KB ne gère ni le remplacement d'une KB par une autre, ni la version de Windows concernée. Un outil réel (WSUS, Intune, Windows Update for Business) s'appuie sur le catalogue Microsoft pour ça.

## Partie 7 : notification

### Quels sont les inconvénients de cette solution ?

- Dépendance à un serveur SMTP : s'il est en panne ou injoignable, l'alerte est perdue. Le script le journalise, mais personne n'est prévenu.
- Sécurité du transport : un envoi SMTP simple peut circuler en clair et sans authentification. Or le rapport joint liste les postes vulnérables et les correctifs qui leur manquent, une information précieuse pour un attaquant.
- Gestion d'un secret : si le serveur exige une authentification, il faut stocker des identifiants sur le poste d'administration. On les protège ici par un fichier chiffré (DPAPI), mais le risque existe.
- `Send-MailMessage` est une commande obsolète : elle ne gère pas l'authentification moderne (OAuth 2.0) exigée par les messageries actuelles comme Microsoft 365.
- Un mail est une alerte passive : pas d'accusé de prise en charge, pas d'escalade si personne ne réagit, pas de suivi de la résolution. Il peut finir dans les indésirables ou noyé dans la boîte de réception.
- Fatigue d'alerte : le script envoie un mail à chaque exécution tant que l'anomalie persiste, sans dédoublonnage. Lancé toutes les heures, il produirait 24 mails par jour pour le même poste.
- La notification n'existe que si le script s'exécute : si la tâche planifiée ne tourne plus, plus aucune alerte, et aucun mécanisme ne le signale.

### Quelles alternatives modernes à un simple envoi SMTP depuis le script ?

- Messagerie par API avec authentification moderne : Microsoft Graph (`Send-MgUserMail`) avec OAuth 2.0 et une identité applicative, au lieu d'un mot de passe.
- Webhooks vers une messagerie d'équipe : Microsoft Teams ou Slack, un simple appel HTTPS (`Invoke-RestMethod`) qui publie l'alerte dans un canal suivi par l'équipe.
- Création automatique d'un ticket dans l'outil ITSM (GLPI, ServiceNow, Jira Service Management) par son API : l'anomalie a alors un responsable, un statut et un historique.
- Plateformes d'astreinte et d'alerte (PagerDuty, Opsgenie) : dédoublonnage, escalade, accusé de réception.
- Supervision et SIEM : écrire un événement dans le journal Windows ou envoyer en syslog, puis laisser Microsoft Sentinel, Splunk, Elastic ou Zabbix corréler et alerter.
- Outils de gestion des correctifs intégrés (Microsoft Intune, WSUS, Azure Update Manager) : ils fournissent nativement tableaux de bord de conformité et alertes, sans script maison.

## Partie 8 : sécurisation de la solution

### 1. Principaux risques liés à PowerShell Remoting / WinRM dans l'architecture mise en place

- Exécution de commandes à distance : WinRM est par nature une porte d'administration. Tout compte autorisé, légitime ou volé, exécute du code sur le poste. Avant durcissement, le seul compte utilisable était `admin`, administrateur local (capture 083).
- Mouvement latéral : le poste d'administration détient des identifiants valables sur tous les postes du parc. S'il est compromis, tout le parc l'est. C'est le point le plus sensible de l'architecture.
- Authentification NTLM hors domaine (capture 096) : le client ne peut pas vérifier l'identité du serveur, d'où l'obligation de déclarer PC01 dans les TrustedHosts. Une machine qui usurpe l'adresse 192.168.56.102 recevrait la tentative d'authentification. NTLM est aussi exposé au relais et à la réutilisation du condensat du mot de passe (pass-the-hash).
- LocalAccountTokenFilterPolicy, activé par `Enable-PSRemoting` (capture 029) : les comptes locaux administrateurs gardent tous leurs privilèges à distance. Un mot de passe d'administrateur local réutilisé d'un poste à l'autre donne accès à tous.
- Transport HTTP (port 5985) : les messages sont chiffrés (`AllowUnencrypted` à false), mais sans certificat rien n'authentifie le serveur au niveau du transport.
- Exposition réseau : par défaut, la règle de pare-feu des profils Privé et Domaine acceptait toute adresse source (capture 095, avant).
- Fuite d'information : rapports, journaux et transcriptions décrivent les postes vulnérables et les correctifs manquants.
- Gestion des secrets : identifiants saisis ou stockés sur le poste d'administration, mot de passe du serveur de messagerie.

Mesures mises en œuvre : filtrage du pare-feu par adresse source (point 5), compte de service sans privilège (point 3), point de connexion JEA limité à une fonction de lecture (point 7), transcription des sessions, droits restreints sur les fichiers (point 4), aucun mot de passe dans les scripts.

### 2. Utilisateurs autorisés à ouvrir une session distante

Voir captures 083 et 086. Sur PC01, le point de connexion par défaut `microsoft.powershell` est ouvert aux membres des groupes Administrateurs et Utilisateurs de gestion à distance. Après durcissement :

| Point de connexion | Qui peut s'y connecter | Ce qu'il permet |
|---|---|---|
| microsoft.powershell (par défaut) | `admin` uniquement (groupe Administrateurs). Le groupe Utilisateurs de gestion à distance est vide. | Session PowerShell complète, droits d'administration |
| PatchAudit (JEA) | `svc-patch` uniquement | Une seule fonction de lecture, `Get-PatchAudit` |

### 3. Limitation des privilèges du compte utilisé

- Compte dédié `svc-patch`, simple utilisateur local, membre d'aucun groupe privilégié (captures 084 et 092).
- Constat : un compte non administrateur peut se connecter mais se voit refuser les lectures WMI (`Get-CimInstance`, `Get-HotFix`), car WMI réserve l'accès distant aux administrateurs (capture 085).
- Solution retenue : JEA plutôt qu'un élargissement des droits WMI. Le compte ne peut appeler qu'une fonction, exécutée par un compte virtuel temporaire (captures 087 à 091).
- Résultat : l'audit complet fonctionne sans aucun compte administrateur (capture 091), et `svc-patch` ne peut plus ouvrir de session PowerShell ordinaire (capture 093).

### 4. Accès aux fichiers produits

- Dossier `output` du poste d'administration : accès limité au compte de l'administrateur, à Système et au groupe Administrateurs. Les droits étaient déjà corrects par héritage du profil utilisateur, ils ont été rendus explicites pour ne plus dépendre de l'emplacement du dossier (capture 097).
- Transcriptions JEA sur PC01 : accès limité à Système et aux Administrateurs.
- Le dossier `output` et les fichiers `*.log` sont exclus du dépôt Git par `.gitignore`. Seuls des exemples sont versionnés, dans un dépôt privé.

### 5. Règles de pare-feu associées à WinRM

Voir capture 095. Deux règles entrantes autorisent le port TCP 5985 sur PC01 : `WINRM-HTTP-In-TCP` (profil Public) et `WINRM-HTTP-In-TCP-NoScope` (profils Domaine et Privé). Les deux sont désormais limitées à l'adresse distante 192.168.56.1, celle du poste d'administration. Aucune autre machine ne peut atteindre le service, quel que soit le profil réseau actif.

Limite : une adresse IP peut être usurpée sur un même réseau local. Le filtrage réduit la surface d'attaque, il ne remplace pas l'authentification.

### 6. Mode d'authentification, et cas où Kerberos est préférable

Mode utilisé dans le lab : NTLM, négocié par le mode Negotiate (capture 096). Basic, Certificate et CredSSP sont désactivés côté service.

Kerberos est préférable dès que les machines appartiennent à un domaine Active Directory et que l'on se connecte par nom de machine :

- Authentification mutuelle : le client vérifie l'identité du serveur grâce au ticket délivré par le contrôleur de domaine. Plus besoin de TrustedHosts, et une machine usurpatrice est détectée.
- Le mot de passe et son condensat ne circulent jamais vers le serveur : le client présente un ticket à durée de vie limitée. Les attaques par relais NTLM et pass-the-hash ne s'appliquent pas de la même façon.
- Gestion centralisée : comptes, groupes et délégation sont administrés dans l'annuaire, et non poste par poste.

Kerberos n'est pas utilisable dans notre lab : pas de domaine, et connexion par adresse IP. Hors domaine, l'alternative pour authentifier le serveur est WinRM sur HTTPS (port 5986) avec un certificat.

### 7. Just Enough Administration (JEA)

Principe : au lieu de donner à un compte une session PowerShell complète, on publie un point de connexion restreint qui n'expose que les commandes nécessaires à une tâche. JEA repose sur trois éléments :

- un fichier de rôle (`.psrc`) qui liste les commandes, fonctions et paramètres autorisés ;
- un fichier de configuration de session (`.pssc`) qui associe des utilisateurs à des rôles, fixe le mode de langage (NoLanguage : ni variables ni scripts) et l'identité d'exécution ;
- un compte virtuel temporaire : les commandes s'exécutent avec les droits nécessaires, sans que l'utilisateur les possède lui-même.

Mise en œuvre dans le projet (`scripts/jea/Install-JeaPatchAudit.ps1`) : point de connexion `PatchAudit`, accessible au seul compte `svc-patch`, exposant une unique fonction `Get-PatchAudit`. Toute autre commande est introuvable dans la session (captures 088 à 090). Chaque session est transcrite, avec l'utilisateur connecté et l'identité d'exécution (capture 094).

Bénéfice : si les identifiants de `svc-patch` sont volés, l'attaquant peut seulement lire la liste des correctifs d'un poste. Il ne peut ni installer, ni modifier, ni rebondir.

Limites : la sécurité repose sur la qualité des fonctions exposées (une fonction acceptant des paramètres mal contrôlés pourrait être détournée, d'où le choix d'une fonction sans paramètre) et le compte virtuel est administrateur local, donc le fichier de rôle doit lui-même être protégé contre toute modification.

### 8. Stratégie de conservation des rapports et des journaux

La stratégie comporte une partie mise en œuvre dans `PatchManager.ps1` et une partie proposée, qui dépend d'une infrastructure absente du lab.

Mis en œuvre dans le projet :

| Risque | Mesure | Preuve |
|---|---|---|
| Modification non autorisée | À chaque audit, copie datée des rapports dans `output/archives/<date>/`, passée en lecture seule, et empreinte SHA-256 enregistrée dans `empreintes.csv` et dans le journal. `Test-IntegriteRapports.ps1` recalcule les empreintes et signale tout fichier altéré ou absent. | Captures 100, 102 et 103 |
| Modification non autorisée | L'empreinte du rapport est aussi écrite dans le mail de notification : une copie de référence existe hors du poste d'administration. | Code de `PatchManager.ps1` |
| Suppression | Chaque audit laisse sa propre archive, l'historique ne dépend plus d'un fichier unique écrasé à chaque exécution. | Capture 100 |
| Croissance sans limite | Rotation du journal au-delà d'une taille maximale (`-TailleMaxJournalKo`), et suppression des archives plus anciennes que la durée de conservation (`-RetentionJours`, 365 jours par défaut). | Code de `PatchManager.ps1`, non déclenché dans le lab |
| Exposition d'informations | Droits NTFS limités à l'administrateur, Système et Administrateurs sur `output` (les archives en héritent), transcriptions JEA limitées à Système et Administrateurs, dossier `output` exclu du dépôt Git, dépôt privé, aucun secret dans les journaux. | Captures 097 et 098 |

Proposé, non mis en œuvre :

- Centralisation des journaux vers un serveur dédié ou un SIEM, qui en reçoit une copie que le poste d'administration ne peut plus modifier. C'est la vraie protection contre un attaquant devenu administrateur du poste : dans notre solution, il pourrait réécrire à la fois un rapport et son empreinte locale.
- Sauvegarde sur un support distinct, selon la règle 3-2-1 (trois copies, deux supports, une hors site), et stockage en écriture unique (WORM) pour les journaux.
- Chiffrement du disque du poste d'administration (BitLocker) et chiffrement du transport pour tout envoi de rapport.
- Signature numérique des rapports par un certificat, plus forte qu'une simple empreinte.

Limite assumée : l'attribut lecture seule et l'empreinte locale détectent une modification accidentelle ou maladroite, pas un attaquant disposant des droits d'administration sur le poste.
