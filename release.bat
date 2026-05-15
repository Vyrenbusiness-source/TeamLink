@echo off
setlocal EnableDelayedExpansion
title TeamLink - Release

REM ============================================================
REM  TeamLink Release-Workflow
REM  1) build.bat ausfuehren (erzeugt dist\TeamLink-vX.Y.Z-win-x64.zip)
REM  2) Git-Tag v<version> setzen + pushen
REM  3) GitHub Release anlegen, ZIP als Asset anhaengen
REM  Voraussetzung: gh CLI installiert + 'gh auth login' einmal gemacht.
REM ============================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

echo.
echo === TeamLink Release ===
echo.

REM ----------------------------------------------------------------
REM 1) gh CLI pruefen
REM ----------------------------------------------------------------
where gh >nul 2>nul
if errorlevel 1 (
  echo [X] gh CLI nicht gefunden.
  echo     Installation:  winget install GitHub.cli
  echo     Danach einmalig anmelden:  gh auth login
  echo.
  exit /b 1
)

gh auth status >nul 2>nul
if errorlevel 1 (
  echo [X] Du bist nicht bei GitHub angemeldet.
  echo     Bitte einmalig ausfuehren:  gh auth login
  echo.
  exit /b 1
)

REM ----------------------------------------------------------------
REM 2) Saubere Working-Copy verlangen, damit der Tag das richtige Commit trifft
REM ----------------------------------------------------------------
git diff --quiet
if errorlevel 1 (
  echo [!] Es gibt uncommitete Aenderungen im Working-Tree.
  echo     Bitte erst committen + pushen ^(`git push`^), dann erneut.
  echo.
  exit /b 1
)
git diff --cached --quiet
if errorlevel 1 (
  echo [!] Es gibt gestagete, nicht committete Aenderungen.
  exit /b 1
)

REM ----------------------------------------------------------------
REM 3) build.bat ausfuehren
REM ----------------------------------------------------------------
echo === Schritt 1/3: Bundle bauen ===
echo.
call "%ROOT%\build.bat"
if errorlevel 1 (
  echo.
  echo [X] build.bat ist fehlgeschlagen - Release abgebrochen.
  exit /b 1
)

REM ----------------------------------------------------------------
REM 4) Version aus dem gerade gebauten Bundle holen (gleiche Quelle wie build.bat)
REM ----------------------------------------------------------------
set "BUNDLE_NODE=%ROOT%\dist\TeamLink\runtime\node\node.exe"
if not exist "%BUNDLE_NODE%" (
  echo [X] Gebuendeltes Node fehlt: %BUNDLE_NODE%
  exit /b 1
)
for /f "delims=" %%v in ('"%BUNDLE_NODE%" -p "require('./sync-server/package.json').version || '0.0.0'"') do (
  set "APP_VERSION=%%v"
)
if "!APP_VERSION!"=="" (
  echo [X] Version aus package.json nicht ermittelbar.
  exit /b 1
)

set "ZIP_PATH=%ROOT%\dist\TeamLink-v!APP_VERSION!-win-x64.zip"
if not exist "!ZIP_PATH!" (
  echo [X] ZIP nicht gefunden: !ZIP_PATH!
  exit /b 1
)

set "TAG=v!APP_VERSION!"

REM ----------------------------------------------------------------
REM 5) Tag existiert schon? Dann Abbruch mit klarer Anweisung.
REM ----------------------------------------------------------------
git rev-parse "!TAG!" >nul 2>nul
if not errorlevel 1 (
  echo [X] Tag !TAG! existiert bereits.
  echo     Bumpe die Version in sync-server\package.json oder loesche den Tag:
  echo       git tag -d !TAG!
  echo       git push origin :refs/tags/!TAG!
  exit /b 1
)

REM ----------------------------------------------------------------
REM 6) GitHub Release anlegen + ZIP attachen
REM ----------------------------------------------------------------
echo.
echo === Schritt 2/3: Git-Tag !TAG! anlegen und pushen ===
git tag -a "!TAG!" -m "TeamLink !TAG!"
if errorlevel 1 ( echo [X] Tag anlegen fehlgeschlagen. & exit /b 1 )
git push origin "!TAG!"
if errorlevel 1 (
  echo [X] Tag-Push fehlgeschlagen. Lokalen Tag wieder entfernen:
  echo       git tag -d !TAG!
  exit /b 1
)

echo.
echo === Schritt 3/3: GitHub Release veroeffentlichen ===
gh release create "!TAG!" "!ZIP_PATH!" --title "TeamLink !TAG!" --generate-notes
if errorlevel 1 (
  echo [X] gh release create fehlgeschlagen.
  echo     Tag bleibt; nach Fix erneut:
  echo       gh release create !TAG! "!ZIP_PATH!" --title "TeamLink !TAG!" --generate-notes
  exit /b 1
)

echo.
echo === Release fertig ===
echo Tag:       !TAG!
echo ZIP:       !ZIP_PATH!
echo Download:  https://github.com/Vyrenbusiness-source/TeamLink/releases/latest/download/TeamLink-v!APP_VERSION!-win-x64.zip
echo.
endlocal
exit /b 0
