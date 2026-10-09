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
