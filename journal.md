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

### Reste à faire
- Créer la VM PC01 et installer Windows.
- Partie 1 : connectivité, computers.txt, activation de WinRM, Enter-PSSession, Invoke-Command.
