@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title TeamLink - Setup

REM ============================================================
REM  TeamLink - Erst-Setup fuer neue Benutzer/Entwickler
REM  Installiert/prueft alle Abhaengigkeiten:
REM    1) Flutter SDK
REM    2) Node.js (LTS)
REM    3) pnpm (via corepack)
REM    4) melos (Dart-Tool)
REM    5) JS-Workspaces (pnpm install)
REM    6) shared-models Dart-Codegen
REM    7) desktop-client Flutter pub get
REM    8) build_runner (Freezed/Riverpod-Codegen)
REM    9) sync-server .env aus .env.example
REM ============================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "STEP=0"
set "FAILED=0"

echo.
echo ===============================================
echo   TeamLink - Setup
echo ===============================================
echo.
echo Pfad: %ROOT%
echo.

REM ----------------------------------------------------------------
REM 1) Flutter SDK
REM ----------------------------------------------------------------
set /a STEP+=1
echo [!STEP!/9] Flutter SDK pruefen ...
where flutter >nul 2>nul
if errorlevel 1 (
  echo     [!] Flutter nicht im PATH gefunden.
  where winget >nul 2>nul
  if errorlevel 1 (
    echo     [X] winget steht nicht zur Verfuegung.
    echo         Bitte Flutter manuell installieren:
    echo         https://docs.flutter.dev/get-started/install/windows
    goto :error
  )
  echo     Installiere Flutter via winget ...
  winget install --id Google.Flutter -e --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo     [X] winget install Google.Flutter ist fehlgeschlagen.
    echo         Bitte Flutter manuell installieren:
    echo         https://docs.flutter.dev/get-started/install/windows
    goto :error
  )
  echo     [i] Flutter wurde installiert. Bitte NEUE Konsole oeffnen,
  echo         damit die PATH-Aenderungen wirksam werden, und setup.bat
  echo         erneut starten.
  goto :end
) else (
  for /f "tokens=*" %%v in ('flutter --version 2^>nul ^| findstr /b "Flutter"') do echo     OK: %%v
)

REM ----------------------------------------------------------------
REM 2) Node.js
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] Node.js pruefen ...
where node >nul 2>nul
if errorlevel 1 (
  echo     [!] Node.js nicht im PATH gefunden.
  where winget >nul 2>nul
  if errorlevel 1 (
    echo     [X] winget steht nicht zur Verfuegung.
    echo         Bitte Node.js 18+ LTS manuell installieren:
    echo         https://nodejs.org/de/download/
    goto :error
  )
  echo     Installiere Node.js LTS via winget ...
  winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo     [X] winget install OpenJS.NodeJS.LTS ist fehlgeschlagen.
    echo         Bitte Node.js 18+ LTS manuell installieren:
    echo         https://nodejs.org/de/download/
    goto :error
  )
  echo     [i] Node.js wurde installiert. Bitte NEUE Konsole oeffnen,
  echo         damit die PATH-Aenderungen wirksam werden, und setup.bat
  echo         erneut starten.
  goto :end
) else (
  for /f "tokens=*" %%v in ('node --version 2^>nul') do echo     OK: Node.js %%v
)

REM Mindestversion Node.js 18 pruefen
for /f "tokens=1 delims=." %%v in ('node -p "process.versions.node" 2^>nul') do set "NODE_MAJOR=%%v"
if defined NODE_MAJOR (
  if !NODE_MAJOR! LSS 18 (
    echo     [X] Node.js Version zu alt: v!NODE_MAJOR!.x  benoetigt: ^>=18
    echo         Bitte aktualisieren: https://nodejs.org/de/download/
    goto :error
  )
)

REM ----------------------------------------------------------------
REM 3) pnpm via corepack
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] pnpm pruefen (via corepack) ...
where pnpm >nul 2>nul
if errorlevel 1 (
  echo     pnpm nicht gefunden - aktiviere via corepack ...
  call corepack enable
  if errorlevel 1 (
    echo     [!] corepack enable fehlgeschlagen - versuche npm i -g pnpm ...
    call npm install -g pnpm@9
    if errorlevel 1 (
      echo     [X] pnpm konnte nicht installiert werden.
      goto :error
    )
  )
  call corepack prepare pnpm@9.12.0 --activate >nul 2>nul
)
for /f "tokens=*" %%v in ('pnpm --version 2^>nul') do echo     OK: pnpm %%v

REM ----------------------------------------------------------------
REM 4) melos (Dart global)
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] melos pruefen ...
where melos >nul 2>nul
if errorlevel 1 (
  echo     melos nicht gefunden - aktiviere via 'dart pub global activate' ...
  call dart pub global activate melos
  if errorlevel 1 (
    echo     [!] melos konnte nicht aktiviert werden. Setup faehrt trotzdem fort
    echo         - melos ist optional fuer das Erst-Setup.
  ) else (
    echo     [i] melos installiert. Falls 'melos' nicht direkt aufrufbar ist,
    echo         pruefe ob '%%LOCALAPPDATA%%\Pub\Cache\bin' im PATH steht.
  )
) else (
  for /f "tokens=*" %%v in ('melos --version 2^>nul') do echo     OK: melos %%v
)

REM ----------------------------------------------------------------
REM 5) JS-Workspaces installieren (pnpm install)
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] JS-Workspaces installieren (pnpm install) ...
pushd "%ROOT%"
call pnpm install
if errorlevel 1 (
  echo     [X] pnpm install ist fehlgeschlagen.
  popd
  goto :error
)
popd
echo     OK: JS-Abhaengigkeiten installiert.

REM ----------------------------------------------------------------
REM 6) shared-models -> Dart-Modelle generieren
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] shared-models Dart-Codegen (node generate.js) ...
pushd "%ROOT%\shared-models"
call node generate.js
if errorlevel 1 (
  echo     [X] shared-models generate.js fehlgeschlagen.
  popd
  goto :error
)
popd
echo     OK: Dart-Modelle generiert.

REM ----------------------------------------------------------------
REM 7) desktop-client - flutter pub get
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] desktop-client flutter pub get ...
pushd "%ROOT%\desktop-client"
call flutter pub get
if errorlevel 1 (
  echo     [X] flutter pub get fehlgeschlagen.
  popd
  goto :error
)
popd
echo     OK: Flutter-Abhaengigkeiten installiert.

REM ----------------------------------------------------------------
REM 8) build_runner (Freezed / Riverpod / drift)
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] build_runner (Freezed/Riverpod/drift) ...
pushd "%ROOT%\desktop-client"
call dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
  echo     [X] build_runner ist fehlgeschlagen.
  popd
  goto :error
)
popd
echo     OK: Codegen abgeschlossen.

REM ----------------------------------------------------------------
REM 9) sync-server .env aus .env.example
REM ----------------------------------------------------------------
set /a STEP+=1
echo.
echo [!STEP!/9] sync-server .env vorbereiten ...
if exist "%ROOT%\sync-server\.env" (
  echo     OK: sync-server\.env existiert bereits - nicht ueberschrieben.
) else (
  if exist "%ROOT%\sync-server\.env.example" (
    copy /Y "%ROOT%\sync-server\.env.example" "%ROOT%\sync-server\.env" >nul
    if errorlevel 1 (
      echo     [!] Konnte .env nicht aus .env.example kopieren.
    ) else (
      echo     OK: sync-server\.env aus .env.example angelegt.
      echo     [i] WICHTIG: JWT_SECRET in sync-server\.env aendern!
    )
  ) else (
    echo     [!] sync-server\.env.example fehlt - .env nicht angelegt.
  )
)

REM ----------------------------------------------------------------
REM  Fertig
REM ----------------------------------------------------------------
echo.
echo ===============================================
echo   Setup erfolgreich abgeschlossen.
echo ===============================================
echo.
echo Naechste Schritte:
echo   - Sync-Server starten:   pnpm run server:dev
echo   - Desktop-Client:        cd desktop-client ^&^& flutter run -d windows
echo   - Verteilbares Bundle:   build.bat
echo.
goto :end

:error
echo.
echo *** Setup fehlgeschlagen ***
echo Bitte den Fehler oben pruefen und setup.bat erneut starten.
endlocal
exit /b 1

:end
endlocal
exit /b 0
