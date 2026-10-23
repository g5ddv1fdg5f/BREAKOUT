BREAKOUT Loader Updater

- La version locale est définie dans loader.py : VERSION = "1.0".
- Le script lit version.txt depuis la branche main du dépôt GitHub.
- Si la version distante est plus récente, il télécharge loader.py dans le dossier updates/.
- Par sécurité, le script ne lance pas automatiquement le code téléchargé et ne remplace pas le fichier en cours.

À vérifier sur GitHub :
- version.txt doit contenir uniquement la version, par exemple : 1.1
- loader.py doit être présent à la racine de la branche main.
- Si le dépôt utilise une autre branche, adapte la constante REPOSITORY dans loader.py.
