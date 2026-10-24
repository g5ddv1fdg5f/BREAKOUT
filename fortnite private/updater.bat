@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Mise a jour automatique GitHub

cd /d "%~dp0"

REM ============ 1) Git installe ? ============
where git >nul 2>&1
if errorlevel 1 ( echo ERREUR : Git introuvable. & pause & exit /b 1 )

REM ============ 2) Racine depot ============
set "TMPGIT=%TEMP%\updater_git_%RANDOM%.tmp"
git rev-parse --show-toplevel > "%TMPGIT%" 2>nul
if errorlevel 1 (
    del "%TMPGIT%" >nul 2>&1
    echo ERREUR : ce BAT doit etre dans un depot Git.
    pause & exit /b 1
)
set "REPOROOT="
set /p REPOROOT=<"%TMPGIT%"
del "%TMPGIT%" >nul 2>&1
cd /d "%REPOROOT%"

echo ==========================================
echo  MISE A JOUR AUTOMATIQUE GITHUB
echo ==========================================
echo Depot : "%REPOROOT%"
echo.

REM ============ 3) Creer un fichier ? ============
set "NEWFILE="
set "CREATEFILE="
set /p "CREATEFILE=Voulez-vous creer un fichier dans le depot ? (O/N) : "
if /i "!CREATEFILE!"=="O" (
    set "NEWFILE="
    set /p "NEWFILE=Nom du fichier a creer (ex: info.txt) : "
    if defined NEWFILE (
        if exist "%REPOROOT%\!NEWFILE!" (
            echo [INFO] "!NEWFILE!" existe deja, non ecrase.
        ) else (
            > "%REPOROOT%\!NEWFILE!" echo.
            echo [INFO] Fichier "!NEWFILE!" cree.
        )
    ) else (
        echo [INFO] Nom vide, fichier non cree.
    )
)
echo.

REM ============ 4) Fichier EXE ============
set "SOURCE="
set /p "SOURCE=Fichier EXE (glisser/coller) : "
if not defined SOURCE ( echo ERREUR : aucun fichier. & pause & exit /b 1 )
set "SOURCE=%SOURCE:"=%"
if not exist "%SOURCE%" ( echo ERREUR : "%SOURCE%" introuvable. & pause & exit /b 1 )
echo.

REM ============ 5) version.txt ============
if exist "%REPOROOT%\version.txt" (
    echo [INFO] version.txt existe deja. Contenu actuel :
    echo ----------------------------------------
    type "%REPOROOT%\version.txt"
    echo ----------------------------------------
    set "UPDVER="
    set /p "UPDVER=Mettre a jour le contenu ? (O/N) : "
    if /i "!UPDVER!"=="O" (
        set "VERSIONCONTENT="
        set /p "VERSIONCONTENT=Nouveau contenu (ex: 1.2) : "
        if defined VERSIONCONTENT (
            > "%REPOROOT%\version.txt" echo !VERSIONCONTENT!
            echo [INFO] version.txt mis a jour.
        )
    )
) else (
    echo [INFO] version.txt n'existe pas.
    set "VERSIONCONTENT="
    set /p "VERSIONCONTENT=Contenu de version.txt (ex: 1.2) : "
    if not defined VERSIONCONTENT set "VERSIONCONTENT=1.0"
    > "%REPOROOT%\version.txt" echo !VERSIONCONTENT!
    echo [INFO] version.txt cree avec : !VERSIONCONTENT!
)
echo.

REM ============ 6) Identite Git ============
git config user.name > "%TMPGIT%" 2>nul
set "GITNAME="
set /p GITNAME=<"%TMPGIT%"
del "%TMPGIT%" >nul 2>&1
git config user.email > "%TMPGIT%" 2>nul
set "GITMAIL="
set /p GITMAIL=<"%TMPGIT%"
del "%TMPGIT%" >nul 2>&1
if not defined GITNAME (
    set /p "GITNAME=Nom Git : "
    if defined GITNAME git config user.name "!GITNAME!"
)
if not defined GITMAIL (
    set /p "GITMAIL=Email Git : "
    if defined GITMAIL git config user.email "!GITMAIL!"
)

REM ============ 7) Remote origin ============
git remote get-url origin >nul 2>&1
if errorlevel 1 ( echo ERREUR : pas de remote origin. & pause & exit /b 1 )

REM ============ 8) Branche ============
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

REM ============ 9) Fetch + pull autostash ============
echo [1/6] Fetch origin %BRANCH%...
git fetch origin %BRANCH% 2>nul
if errorlevel 1 (
    echo [WARN] Fetch echoue. On continue.
) else (
    set "BEHIND="
    git rev-list --count HEAD..origin/%BRANCH% > "%TMPGIT%" 2>nul
    if not errorlevel 1 ( set /p BEHIND=<"%TMPGIT%" )
    del "%TMPGIT%" >nul 2>&1
    if defined BEHIND if not "!BEHIND!"=="0" (
        echo [INFO] En retard de !BEHIND! commit^(s^). Pull --rebase --autostash...
        git pull --rebase --autostash origin %BRANCH%
        if errorlevel 1 ( echo [ERREUR] Pull echoue. & pause & exit /b 1 )
    )
)

REM ============ 10) Copier EXE ============
echo [2/6] Copie de l'EXE...
for %%F in ("%SOURCE%") do set "EXENAME=%%~nxF"
copy /Y "%SOURCE%" "%REPOROOT%\%EXENAME%" >nul
if errorlevel 1 ( echo ERREUR copie. & pause & exit /b 1 )
echo    -^> %EXENAME%

REM ============ 11) git add ============
echo [3/6] git add...
if defined NEWFILE (
    git add "%EXENAME%" version.txt "!NEWFILE!"
) else (
    git add "%EXENAME%" version.txt
)
if errorlevel 1 ( echo ERREUR add. & pause & exit /b 1 )

REM ============ 12) rien a commit ? ============
git diff --cached --quiet
if not errorlevel 1 (
    echo [INFO] Aucun changement. Rien a commit.
    goto :PUSH
)

REM ============ 13) commit ============
echo [4/6] Commit...
set "MSG=Mise a jour"
if defined NEWFILE set "MSG=!MSG! + !NEWFILE!"
git commit -m "Mise a jour auto : %EXENAME% + version.txt"
if errorlevel 1 ( echo ERREUR commit. & pause & exit /b 1 )

:PUSH
REM ============ 14) push ============
echo [5/6] Push origin %BRANCH%...
git push origin %BRANCH%
if errorlevel 1 (
    echo [WARN] Push refuse. Pull --rebase --autostash puis retry...
    git pull --rebase --autostash origin %BRANCH%
    if errorlevel 1 ( echo [ERREUR] Pull impossible. & pause & exit /b 1 )
    git push origin %BRANCH%
    if errorlevel 1 ( echo [ERREUR] Push impossible. & pause & exit /b 1 )
)

echo.
echo [6/6] TERMINE.
git log -1 --oneline
pause
exit /b 0