# Patch Management Windows en PowerShell

Projet de sécurité des systèmes (S. Benayoune), EFREI ING2, 2026.
Auteur : DOSSOU Sam (monôme).

Solution simplifiée d'audit des correctifs de sécurité d'un parc Windows : lecture de l'inventaire `computers.txt`, contrôle à distance par PowerShell Remoting / WinRM, inventaire, conformité aux KB requises, rapport HTML, journalisation et notification.

## Structure

| Dossier | Contenu |
|---|---|
| `scripts/` | Scripts PowerShell |
| `config/` | `computers.txt`, `required-patches.txt` |
| `exemples/` | Exemples de fichiers produits (CSV, HTML, log) |
| `output/` | Fichiers générés à l'exécution (non versionnés) |
| `captures/` | Captures d'écran et leur index |
| `rapport/` | Rapport final |
| `journal.md` | Journal de bord |
