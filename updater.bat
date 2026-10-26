@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Mise a jour automatique GitHub

cd /d "%~dp0"

REM ============ 1) Git installe ? ============
where git >nul 2>&1
if errorlevel 1 ( echo ERREUR : Git introuvable. & pause & exit /b 1 )

REM ============ 2) Racine depot ============
set "TMPGIT=%~dp0git_tmp.txt"
set "TMPERR=%~dp0git_err.txt"
git rev-parse --show-toplevel > "%TMPGIT%" 2>"%TMPERR%"
if errorlevel 1 (
    echo ==========================================
    echo  ERREUR : pas dans un depot Git
    echo ==========================================
    echo Dossier courant : %CD%
    echo.
    echo Detail de l'erreur Git :
    type "%TMPERR%"
    echo.
    echo Verifie que :
    echo   - Le dossier ".git" existe dans "%CD%" ou un parent
    echo   - Tu lances bien le .bat depuis le depot
    echo   - Git est bien installe
    echo.
    del "%TMPGIT%" "%TMPERR%" >nul 2>&1
    pause
    exit /b 1
)
del "%TMPERR%" >nul 2>&1

set "REPOROOT="
set /p REPOROOT=<"%TMPGIT%"
del "%TMPGIT%" >nul 2>&1

set "WORKDIR=%~dp0"
if "%WORKDIR:~-1%"=="\" set "WORKDIR=%WORKDIR:~0,-1%"

REM ============ 3) Remote + Branche ============
git remote get-url origin >nul 2>&1
if errorlevel 1 ( echo ERREUR : pas de remote origin. & pause & exit /b 1 )

git rev-parse --abbrev-ref HEAD > "%TMPGIT%" 2>nul
set "BRANCH="
set /p BRANCH=<"%TMPGIT%"
del "%TMPGIT%" >nul 2>&1
if "%BRANCH%"=="HEAD" (
    git checkout main >nul 2>&1 || git checkout master >nul 2>&1
    git rev-parse --abbrev-ref HEAD > "%TMPGIT%" 2>nul
    set /p BRANCH=<"%TMPGIT%"
    del "%TMPGIT%" >nul 2>&1
)
if not defined BRANCH set "BRANCH=main"

REM ============ 4) Nettoyage ============
echo [VERIF] Verification de l'etat du depot...
git ls-files -u > "%TMPGIT%" 2>nul
for %%A in ("%TMPGIT%") do set "FSIZE=%%~zA"
del "%TMPGIT%" >nul 2>&1

if !FSIZE! GTR 0 (
    echo [WARN] Conflits detectes dans Git. Nettoyage automatique...
    git reset --hard HEAD >nul 2>&1
    git clean -fd >nul 2>&1
)
echo.

REM ============ 5) Sync ============
echo [SYNC] Synchronisation avec origin/%BRANCH%...
git fetch origin %BRANCH% 2>nul
if errorlevel 1 (
    echo [WARN] Fetch echoue ^(reseau/credentials^). On continue.
) else (
    set "BEHIND="
    git rev-list --count HEAD..origin/%BRANCH% > "%TMPGIT%" 2>nul
    if not errorlevel 1 ( set /p BEHIND=<"%TMPGIT%" )
    del "%TMPGIT%" >nul 2>&1
    if defined BEHIND if not "!BEHIND!"=="0" (
        echo [INFO] En retard de !BEHIND! commit^(s^). Mise a jour...
        git pull --rebase --autostash origin %BRANCH%
        if errorlevel 1 (
            git rebase --abort >nul 2>&1
            git reset --hard HEAD >nul 2>&1
            git stash list > "%TMPGIT%" 2>nul
            if exist "%TMPGIT%" (
                for /f "usebackq tokens=1 delims=:" %%S in ("%TMPGIT%") do git stash drop %%S >nul 2>&1
            )
            del "%TMPGIT%" >nul 2>&1
        )
    )
)

REM ==========================================
REM  MENU PRINCIPAL
REM ==========================================
:MENU
cls
echo ==========================================
echo  MISE A JOUR AUTOMATIQUE GITHUB
echo ==========================================
echo Depot   : %REPOROOT%
echo Dossier : %WORKDIR%
echo.
echo   [1] Mettre a jour l'EXE ET version.txt
echo   [2] Remplacer seulement l'EXE
echo   [3] Modifier seulement version.txt
echo   [4] Supprimer un fichier
echo   [5] Quitter
echo.
set "CHOIX="
set /p "CHOIX=Votre choix [1-5] : "
if "%CHOIX%"=="1" goto :OPT1
if "%CHOIX%"=="2" goto :OPT2
if "%CHOIX%"=="3" goto :OPT3
if "%CHOIX%"=="4" goto :OPT4
if "%CHOIX%"=="5" exit /b 0
goto :MENU

REM ==========================================
REM  SOUS-PROGRAMME : CHOIX DU DOSSIER
REM ==========================================
:CHOIX_DOSSIER
echo.
echo Dossiers disponibles :
set "IDX=0"
for /d %%D in ("%WORKDIR%\*") do (
    if /i not "%%~nxD"==".git" (
        set /a IDX+=1
        set "DIR_!IDX!=%%~nxD"
        echo   [!IDX!] %%~nxD
    )
)
echo   [0] Racine du depot
echo   [N] Creer un nouveau dossier
echo.
set "SEL="
set /p "SEL=Choisir le numero du dossier (N=nouveau, R pour retour) : "
if /i "!SEL!"=="R" (
    set "RETOUR=1"
    exit /b
)
if /i "!SEL!"=="N" (
    call :CREER_DOSSIER
    exit /b
)
if "!SEL!"=="0" (
    set "DESTDIR=%WORKDIR%"
    echo [INFO] Dossier cible : Racine
) else (
    call set "CHOSEN=%%DIR_!SEL!%%"
    if defined CHOSEN (
        set "DESTDIR=%WORKDIR%\!CHOSEN!"
        echo [INFO] Dossier cible : !CHOSEN!
    ) else (
        echo [INFO] Choix invalide, racine par defaut.
        set "DESTDIR=%WORKDIR%"
    )
)
exit /b

REM ==========================================
REM  SOUS-PROGRAMME : CREER UN NOUVEAU DOSSIER
REM ==========================================
:CREER_DOSSIER
echo.
set "NEWDIR="
set /p "NEWDIR=Nom du nouveau dossier (R pour retour) : "
if /i "!NEWDIR!"=="R" (
    set "RETOUR=1"
    exit /b
)
if not defined NEWDIR (
    echo [INFO] Nom vide, retour.
    set "RETOUR=1"
    exit /b
)
REM Supprimer les guillemets eventuels
set "NEWDIR=!NEWDIR:"=!"

REM Verifier les caracteres interdits (un par un, sans regex compliquee)
set "BADNAME="
for %%C in ("\" "/" ":" "*" "?" "<" ">" "|") do (
    echo !NEWDIR! | find "%%~C" >nul && set "BADNAME=1"
)
if defined BADNAME (
    echo [ERREUR] Nom invalide ^(caractere interdit^).
    pause
    set "RETOUR=1"
    exit /b
)

REM Verifier que le dossier n'existe pas deja
if exist "%WORKDIR%\!NEWDIR!" (
    echo [ERREUR] Ce dossier existe deja.
    pause
    set "RETOUR=1"
    exit /b
)

mkdir "%WORKDIR%\!NEWDIR!" >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Impossible de creer le dossier.
    pause
    set "RETOUR=1"
    exit /b
)
set "DESTDIR=%WORKDIR%\!NEWDIR!"
echo [INFO] Dossier cree et selectionne : !NEWDIR!
exit /b

REM ==========================================
REM  SOUS-PROGRAMME : SAISIE VERSION.TXT
REM ==========================================
:SAISIR_VERSION
set "VERSIONCONTENT="
echo.
echo Que voulez-vous mettre dans version.txt ?
echo   [1] Un numero de version (ex: 1.2)
echo   [2] Maintenance
set "VERCHOIX="
set /p "VERCHOIX=Votre choix [1-2] (R pour retour) : "
if /i "!VERCHOIX!"=="R" (
    set "RETOUR=1"
    exit /b
)
if "!VERCHOIX!"=="1" (
    set /p "VERSIONCONTENT=Numero de version (ex: 1.2, vide pour retour) : "
    if not defined VERSIONCONTENT (
        set "RETOUR=1"
        exit /b
    )
) else if "!VERCHOIX!"=="2" (
    set "VERSIONCONTENT=maintenance"
) else (
    echo [INFO] Choix invalide.
    set "RETOUR=1"
    exit /b
)
exit /b

REM ==========================================
REM  SOUS-PROGRAMME : SAISIE DU CHEMIN EXE
REM  Redemande tant que le chemin est invalide
REM ==========================================
:DEMANDER_EXE
set "SOURCE="
set /p "SOURCE=Fichier EXE (glisser/coller, vide pour retour) : "
if not defined SOURCE (
    set "RETOUR=1"
    exit /b
)

REM Nettoyer guillemets, espaces en trop et caracteres parasites
set "SOURCE=!SOURCE:"=!"
for /f "tokens=* delims= " %%A in ("!SOURCE!") do set "SOURCE=%%A"
if "!SOURCE:~-1!"==" " set "SOURCE=!SOURCE:~0,-1!"

REM Si le chemin ressemble a un dossier, prevenir l'utilisateur
if exist "!SOURCE!\" (
    echo [ERREUR] "!SOURCE!" est un dossier, pas un fichier EXE.
    echo.
    goto :DEMANDER_EXE
)

REM Verifier l'existence du fichier
if not exist "!SOURCE!" (
    echo [ERREUR] Fichier introuvable : "!SOURCE!"
    echo Verifie que tu as bien colle le chemin COMPLET du fichier ^(avec guillemets si espaces^).
    echo.
    goto :DEMANDER_EXE
)

REM Verifier l'extension .exe
for %%F in ("!SOURCE!") do set "EXT=%%~xF"
if /i not "!EXT!"==".exe" (
    echo [WARN] Le fichier n'a pas l'extension .exe : "!SOURCE!"
    set "CONTINUER="
    set /p "CONTINUER=Continuer quand meme ? (O/N) : "
    if /i not "!CONTINUER!"=="O" (
        echo [INFO] Retour a la saisie.
        echo.
        goto :DEMANDER_EXE
    )
)

set "RETOUR="
exit /b

REM ==========================================
REM  OPTION 1 : TOUT METTRE A JOUR
REM ==========================================
:OPT1
call :CHOIX_DOSSIER
if defined RETOUR ( set "RETOUR=" & goto :MENU )

echo.
call :DEMANDER_EXE
if defined RETOUR ( set "RETOUR=" & goto :MENU )

if exist "!DESTDIR!\version.txt" (
    echo [INFO] version.txt existe. Contenu actuel :
    type "!DESTDIR!\version.txt"
    echo.
    set "UPDVER="
    set /p "UPDVER=Mettre a jour le contenu ? (O/N/R pour retour) : "
    if /i "!UPDVER!"=="R" goto :MENU
    if /i "!UPDVER!"=="O" (
        call :SAISIR_VERSION
        if defined RETOUR ( set "RETOUR=" & goto :MENU )
        > "!DESTDIR!\version.txt" echo !VERSIONCONTENT!
        echo [INFO] version.txt mis a jour.
    )
) else (
    call :SAISIR_VERSION
    if defined RETOUR ( set "RETOUR=" & goto :MENU )
    > "!DESTDIR!\version.txt" echo !VERSIONCONTENT!
    echo [INFO] version.txt cree avec : !VERSIONCONTENT!
)

for %%F in ("!SOURCE!") do set "EXENAME=%%~nxF"
set "SRCABS="
for %%A in ("!SOURCE!") do set "SRCABS=%%~fA"
set "DESTABS=!DESTDIR!\!EXENAME!"

call :REMPLACER_EXE
if defined RETOUR ( set "RETOUR=" & goto :MENU )

git add -A "!DESTDIR!\version.txt"
git add --force "!DESTDIR!\!EXENAME!"
goto :DO_COMMIT

REM ==========================================
REM  OPTION 2 : REMPLACER SEULEMENT L'EXE
REM ==========================================
:OPT2
call :CHOIX_DOSSIER
if defined RETOUR ( set "RETOUR=" & goto :MENU )

echo.
echo EXE actuellement presents dans ce dossier :
set "EXECOUNT=0"
if exist "!DESTDIR!\*.exe" (
    for %%E in ("!DESTDIR!\*.exe") do (
        set /a EXECOUNT+=1
        echo   - %%~nxE
    )
) else (
    echo   (aucun EXE pour le moment)
)
echo.

call :DEMANDER_EXE
if defined RETOUR ( set "RETOUR=" & goto :MENU )

for %%F in ("!SOURCE!") do set "EXENAME=%%~nxF"
set "SRCABS="
for %%A in ("!SOURCE!") do set "SRCABS=%%~fA"
set "DESTABS=!DESTDIR!\!EXENAME!"

call :REMPLACER_EXE
if defined RETOUR ( set "RETOUR=" & goto :MENU )

git add --force "!DESTDIR!\!EXENAME!"
goto :DO_COMMIT

REM ==========================================
REM  SOUS-PROGRAMME : REMPLACER EXE AUTOMATIQUEMENT
REM  (copie toujours, meme si identique)
REM ==========================================
:REMPLACER_EXE
if /i "!SRCABS!"=="!DESTABS!" (
    echo    -^> EXE deja en place.
    exit /b
)

set "EXECOUNT=0"
set "OLDEXE="
if exist "!DESTDIR!\*.exe" (
    for %%E in ("!DESTDIR!\*.exe") do (
        set /a EXECOUNT+=1
        set "OLDEXE=%%~nxE"
        set "E_!EXECOUNT!=%%~nxE"
    )
)

if !EXECOUNT! EQU 1 (
    if /i not "!OLDEXE!"=="!EXENAME!" (
        del /f /q "!DESTDIR!\!OLDEXE!" >nul 2>&1
        pushd "%REPOROOT%" 2>nul
        git rm --cached "!DESTDIR!\!OLDEXE!" >nul 2>&1
        popd 2>nul
        echo    -^> Ancien EXE supprime automatiquement : !OLDEXE!
    )
) else if !EXECOUNT! GTR 1 (
    echo.
    echo [INFO] Plusieurs EXE trouves. Lequel remplacer ?
    for /l %%I in (1,1,!EXECOUNT!) do (
        call echo   [%%I] %%E_%%I%%
    )
    set "SELE="
    set /p "SELE=Numero de l'ancien EXE (R pour retour, vide = garder) : "
    if /i "!SELE!"=="R" (
        set "RETOUR=1"
        exit /b
    )
    if defined SELE (
        call set "OLDE=%%E_!SELE!%%"
        if defined OLDE (
            if /i not "!OLDE!"=="!EXENAME!" (
                del /f /q "!DESTDIR!\!OLDE!" >nul 2>&1
                pushd "%REPOROOT%" 2>nul
                git rm --cached "!DESTDIR!\!OLDE!" >nul 2>&1
                popd 2>nul
                echo    -^> Supprime : !OLDE!
            )
        )
    )
)

REM Copie forcee, meme si le fichier est identique
copy /Y "!SOURCE!" "!DESTABS!" >nul
if errorlevel 1 (
    echo    -^> [ERREUR] Impossible de copier vers "!DESTABS!"
    exit /b
)
echo    -^> !EXENAME! copie.
exit /b

REM ==========================================
REM  OPTION 3 : MODIFIER SEULEMENT version.txt
REM ==========================================
:OPT3
call :CHOIX_DOSSIER
if defined RETOUR ( set "RETOUR=" & goto :MENU )

echo.
set "EXENAME=version.txt"
if exist "!DESTDIR!\version.txt" (
    echo Contenu actuel de version.txt :
    type "!DESTDIR!\version.txt"
    echo.
) else (
    echo [INFO] version.txt n'existe pas encore.
)
call :SAISIR_VERSION
if defined RETOUR ( set "RETOUR=" & goto :MENU )

> "!DESTDIR!\version.txt" echo !VERSIONCONTENT!
echo [INFO] version.txt mis a jour.
echo.
git add -A "!DESTDIR!\version.txt"
goto :DO_COMMIT

REM ==========================================
REM  OPTION 4 : SUPPRIMER UN FICHIER
REM ==========================================
:OPT4
call :CHOIX_DOSSIER
if defined RETOUR ( set "RETOUR=" & goto :MENU )

echo.
echo Fichiers disponibles dans ce dossier :
set "LISTFILE=%~dp0liste_temp.txt"
if exist "%LISTFILE%" del "%LISTFILE%" >nul 2>&1

dir /b /a-d "!DESTDIR!\*" > "%LISTFILE%" 2>nul

set "FILECOUNT=0"
for /f "usebackq delims=" %%F in ("%LISTFILE%") do (
    set /a FILECOUNT+=1
    set "FILE_!FILECOUNT!=%%F"
    echo   [!FILECOUNT!] %%F
)
if exist "%LISTFILE%" del "%LISTFILE%" >nul 2>&1

if !FILECOUNT! EQU 0 (
    echo   (aucun fichier a supprimer)
    pause
    goto :MENU
)

echo.
set "DELSEL="
set /p "DELSEL=Numero du fichier a supprimer (R pour retour, 0 pour annuler) : "
if /i "!DELSEL!"=="R" goto :MENU
if "!DELSEL!"=="0" goto :MENU
if "!DELSEL!"=="" goto :MENU

call set "FICHIER_A_SUPPRIMER=%%FILE_!DELSEL!%%"
if defined FICHIER_A_SUPPRIMER (
    echo [INFO] Suppression de : !FICHIER_A_SUPPRIMER!
    del /f /q "!DESTDIR!\!FICHIER_A_SUPPRIMER!" >nul 2>&1
    if errorlevel 1 (
        echo [ERREUR] Impossible de supprimer le fichier.
        pause
        goto :MENU
    )
    echo [INFO] Fichier supprime localement.
    echo.
    set "EXENAME=!FICHIER_A_SUPPRIMER! supprime"
    pushd "%REPOROOT%" 2>nul
    git rm --cached "!DESTDIR!\!FICHIER_A_SUPPRIMER!" >nul 2>&1
    popd 2>nul
    git add -u "!DESTDIR!"
    goto :DO_COMMIT
) else (
    echo [ERREUR] Choix invalide.
    pause
    goto :MENU
)

REM ==========================================
REM  ENVOI VERS GITHUB (Commun aux options)
REM  Commit TOUJOURS effectue (--allow-empty si rien n'a change)
REM ==========================================
:DO_COMMIT
git ls-files -u > "%TMPGIT%" 2>nul
for %%A in ("%TMPGIT%") do set "FSIZE=%%~zA"
del "%TMPGIT%" >nul 2>&1

if !FSIZE! GTR 0 (
    echo [ERREUR] Des conflits empechent le commit. Nettoyage d'urgence...
    git reset --hard HEAD >nul 2>&1
    git clean -fd >nul 2>&1
    echo [INFO] Veuillez relancer le script.
    pause
    goto :MENU
)

REM Toujours commiter, meme si aucun changement binaire n'est detecte
set "HAS_CHANGES=1"
git diff --cached --quiet
if not errorlevel 1 (
    echo [INFO] Aucun changement binaire detecte.
    echo [INFO] Commit force pour garder une trace sur GitHub.
    set "HAS_CHANGES=0"
)

echo [COMMIT] Preparation du commit...
if "!HAS_CHANGES!"=="1" (
    git commit -m "Mise a jour auto : %EXENAME%"
) else (
    git commit --allow-empty -m "Mise a jour auto (forcee) : %EXENAME%"
)
if errorlevel 1 (
    echo [ERREUR] Impossible de faire le commit.
    pause
    goto :MENU
)

echo [PUSH] Envoi vers GitHub...
git push origin %BRANCH%
if errorlevel 1 (
    echo [WARN] Push refuse. Tentative de pull --rebase --autostash...
    git pull --rebase --autostash origin %BRANCH%
    if errorlevel 1 (
        echo [ERREUR] Impossible de pull. Nettoyage...
        git rebase --abort >nul 2>&1
        git reset --hard HEAD >nul 2>&1
        pause
        goto :MENU
    )
    git push origin %BRANCH%
    if errorlevel 1 (
        echo [ERREUR] Impossible de push. Verifie ton token GitHub.
        pause
        goto :MENU
    )
)

echo.
echo ==========================================
echo  TERMINE AVEC SUCCES
echo ==========================================
git log -1 --oneline
echo.
pause
goto :MENU