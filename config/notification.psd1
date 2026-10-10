@{
    # Serveur SMTP de test local (smtp4dev). Aucun mail ne sort du poste.
    SmtpServer = "127.0.0.1"
    Port       = 2525
    UseSsl     = $false

    From = "patchmanager@entreprise.local"
    To   = "admin@entreprise.local"

    # Identifiants SMTP : jamais dans ce fichier ni dans le script.
    # Indiquer ici le chemin d'un fichier cree avec :
    #   Get-Credential | Export-Clixml "$HOME\.patchmanager\smtp-cred.clixml"
    # Le mot de passe y est chiffre par Windows (DPAPI) : seul le meme compte,
    # sur le meme poste, peut le relire.
    # Laisser vide si le serveur n'exige pas d'authentification (cas de smtp4dev).
    CredentialFile = ""
}
