@echo off
setlocal EnableDelayedExpansion
title TeamLink - Build

REM ============================================================
REM  TeamLink - Entwickler-Build
REM  Erzeugt ein verteilbares Bundle in dist\TeamLink\.
REM  Endnutzer starten daraus einfach TeamLink.exe.
REM ============================================================

REM === Konfiguration ===
REM Node 24.x LTS - better-sqlite3 >=12 hat Prebuilds NUR fuer ABI 137 (Node 24).
REM Node 22 (ABI 127) wuerde zu einem Versions-Mismatch beim Laden des .node-Binarys fuehren.
set "NODE_VERSION=v24.5.0"
set "NODE_ARCHIVE=node-%NODE_VERSION%-win-x64.zip"
set "NODE_URL=https://nodejs.org/dist/%NODE_VERSION%/%NODE_ARCHIVE%"

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "DIST=%ROOT%\dist\TeamLink"
set "CACHE=%ROOT%\.build-cache"
set "FLUTTER_OUT=%ROOT%\desktop-client\build\windows\x64\runner\Release"

echo.
echo === TeamLink Build ===
echo.

REM ----------------------------------------------------------------
REM 1) Flutter pruefen, ggf. via winget installieren
REM ----------------------------------------------------------------
where flutter >nul 2>nul
if errorlevel 1 (
  echo [!] Flutter nicht im PATH gefunden.
  where winget >nul 2>nul
  if errorlevel 1 (
    echo [X] winget steht nicht zur Verfuegung.
    echo     Bitte Flutter manuell installieren:
    echo     https://docs.flutter.dev/get-started/install/windows
    goto :error
  )
  echo     Versuche 'winget install Flutter' ...
  winget install --id Google.Flutter -e --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo [X] winget install ist fehlgeschlagen.
    echo     Bitte Flutter manuell installieren.
    goto :error
  )
  echo [i] Flutter wurde installiert. Bitte eine neue Konsole oeffnen
  echo     damit die PATH-Aenderungen wirksam werden und build.bat erneut starten.
  goto :end
)

REM ----------------------------------------------------------------
REM 2) C#-Compiler aus dem .NET Framework
REM ----------------------------------------------------------------
set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo [X] csc.exe nicht gefunden: %CSC%
  echo     .NET Framework 4.x ist auf Windows 10/11 standardmaessig installiert.
  echo     Notfalls: https://dotnet.microsoft.com/download/dotnet-framework
  goto :error
)

REM ----------------------------------------------------------------
REM 2b) Windows-Entwicklermodus pruefen (Flutter braucht Symlinks)
REM ----------------------------------------------------------------
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2>nul | findstr /i "0x1" >nul
if errorlevel 1 (
  echo [X] Windows-Entwicklermodus ist NICHT aktiv.
  echo     Flutter Windows-Builds legen Symlinks fuer Plugins an. Ohne
  echo     Entwicklermodus verweigert Windows das und der Build bricht ab.
  echo.
  echo     So aktivierst du ihn:
  echo       Win+R druecken, 'ms-settings:developers' eingeben, Enter,
  echo       'Entwicklermodus' anschalten - dann build.bat neu starten.
  echo.
  goto :error
)

REM ----------------------------------------------------------------
REM 3) Distributionsverzeichnis vorbereiten
REM ----------------------------------------------------------------
echo [1/7] Vorheriges Build aufraeumen ...
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%"
if not exist "%CACHE%" mkdir "%CACHE%"

REM ----------------------------------------------------------------
REM 4) Flutter Windows Release-Build
REM ----------------------------------------------------------------
echo [2/7] Flutter Windows Release-Build ...
pushd "%ROOT%\desktop-client"
call flutter pub get
set "FLUTTER_RC=!errorlevel!"
if not "!FLUTTER_RC!"=="0" goto :flutter_pub_fail
call flutter build windows --release
set "FLUTTER_RC=!errorlevel!"
if not "!FLUTTER_RC!"=="0" goto :flutter_build_fail
popd
goto :after_flutter

:flutter_pub_fail
popd
echo [X] flutter pub get fehlgeschlagen, Code !FLUTTER_RC!.
goto :error

:flutter_build_fail
popd
echo [X] flutter build windows fehlgeschlagen, Code !FLUTTER_RC!.
goto :error

:after_flutter

if not exist "%FLUTTER_OUT%\desktop_client.exe" (
  echo [X] Flutter-Build nicht gefunden: %FLUTTER_OUT%\desktop_client.exe
  goto :error
)

REM ----------------------------------------------------------------
REM 5) Launcher.cs -> TeamLink.exe
REM ----------------------------------------------------------------
echo [3/7] Launcher kompilieren ...
"%CSC%" /nologo /target:winexe /out:"%DIST%\TeamLink.exe" ^
  /reference:System.Windows.Forms.dll ^
  /reference:System.Drawing.dll ^
  /reference:System.dll ^
  "%ROOT%\Launcher.cs"
if errorlevel 1 (
  echo [X] csc.exe ist fehlgeschlagen.
  goto :error
)

REM ----------------------------------------------------------------
REM 6) Portables Node.js holen (Cache nutzen)
REM ----------------------------------------------------------------
set "NODE_CACHE_ZIP=%CACHE%\%NODE_ARCHIVE%"
if not exist "%NODE_CACHE_ZIP%" (
  echo [4/7] Lade portables Node.js %NODE_VERSION% ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_CACHE_ZIP%'"
  if errorlevel 1 (
    echo [X] Download fehlgeschlagen: %NODE_URL%
    goto :error
  )
) else (
  echo [4/7] Portables Node.js bereits im Cache.
)

mkdir "%DIST%\runtime\node"
echo       Entpacke nach runtime\node\ ...
tar -xf "%NODE_CACHE_ZIP%" -C "%DIST%\runtime\node" --strip-components=1
if errorlevel 1 (
  echo [X] Entpacken fehlgeschlagen.
  goto :error
)

if not exist "%DIST%\runtime\node\node.exe" (
  echo [X] node.exe nach dem Entpacken nicht gefunden.
  goto :error
)

REM ----------------------------------------------------------------
REM 6b) Cloudflared-Binary fuer Host-Tunnel
REM ----------------------------------------------------------------
set "CLOUDFLARED_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
set "CLOUDFLARED_CACHE=%CACHE%\cloudflared-windows-amd64.exe"
if not exist "%CLOUDFLARED_CACHE%" (
  echo       Lade cloudflared ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%CLOUDFLARED_URL%' -OutFile '%CLOUDFLARED_CACHE%'"
  if errorlevel 1 (
    echo [X] cloudflared-Download fehlgeschlagen.
    goto :error
  )
) else (
  echo       cloudflared bereits im Cache.
)
mkdir "%DIST%\runtime\cloudflared"
copy /Y "%CLOUDFLARED_CACHE%" "%DIST%\runtime\cloudflared\cloudflared.exe" >nul
if not exist "%DIST%\runtime\cloudflared\cloudflared.exe" (
  echo [X] cloudflared.exe nicht im Bundle.
  goto :error
)

REM ----------------------------------------------------------------
REM 7) Bundle zusammenstellen: Flutter + sync-server
REM ----------------------------------------------------------------
echo [5/7] Bundle zusammenstellen ...

mkdir "%DIST%\desktop-client\build\windows\x64\runner\Release"
xcopy "%FLUTTER_OUT%" "%DIST%\desktop-client\build\windows\x64\runner\Release" /E /I /Y /Q >nul
if errorlevel 1 (
  echo [X] Kopieren des Flutter-Builds fehlgeschlagen.
  goto :error
)

REM VC++ Runtime app-lokal mitliefern, damit desktop_client.exe auch auf
REM frischen Windows-Installationen ohne installierten VC++ Redist startet.
REM Microsoft erlaubt app-lokales Deployment dieser DLLs.
echo       Buendle VC++ Runtime DLLs ...
for %%D in (vcruntime140.dll vcruntime140_1.dll msvcp140.dll msvcp140_1.dll msvcp140_2.dll concrt140.dll) do (
  if exist "%WINDIR%\System32\%%D" (
    copy /Y "%WINDIR%\System32\%%D" "%DIST%\desktop-client\build\windows\x64\runner\Release\" >nul
  ) else (
    echo [!] Warnung: %%D nicht im System32 - Endnutzer braucht ggf. VC++ Redistributable.
  )
)

mkdir "%DIST%\sync-server"
xcopy "%ROOT%\sync-server\src" "%DIST%\sync-server\src" /E /I /Y /Q >nul
copy /Y "%ROOT%\sync-server\package.json" "%DIST%\sync-server\" >nul
if exist "%ROOT%\sync-server\package-lock.json" copy /Y "%ROOT%\sync-server\package-lock.json" "%DIST%\sync-server\" >nul
REM Frische zufaellige Secrets pro Build erzeugen.
REM Dev-.env NIE ins Bundle kopieren - sonst teilen sich alle Endnutzer
REM die gleichen JWT-/Session-Secrets wie der Entwickler.
echo       Generiere frische .env mit zufaelligen Secrets ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\generate-bundle-env.ps1" -OutPath "%DIST%\sync-server\.env"
if errorlevel 1 (
  echo [X] .env-Erzeugung fehlgeschlagen.
  goto :error
)

REM ----------------------------------------------------------------
REM 8) npm install MIT dem gebuendelten Node ausfuehren.
REM    Wichtig: better-sqlite3 ist ein natives Modul; sein .node-Binary
REM    muss zur Node-Version im Bundle passen (NODE_MODULE_VERSION).
REM    Darum hier vorab installieren - nicht erst beim Endnutzer.
REM ----------------------------------------------------------------
echo [6/7] npm install mit gebuendeltem Node (das macht das .node-Binary kompatibel) ...
set "BUNDLE_NODE_DIR=%DIST%\runtime\node"
set "BUNDLE_NODE=%BUNDLE_NODE_DIR%\node.exe"
set "BUNDLE_NPM=%BUNDLE_NODE_DIR%\node_modules\npm\bin\npm-cli.js"
if not exist "%BUNDLE_NPM%" (
  echo [X] npm-cli.js im gebuendelten Node nicht gefunden: %BUNDLE_NPM%
  goto :error
)
REM PATH so isolieren, dass node-gyp den GEBUENDELTEN Node findet, nicht System-Node.
REM Sonst wuerden native Module (better-sqlite3) gegen die falsche ABI kompiliert.
set "_OLD_PATH=%PATH%"
set "PATH=%BUNDLE_NODE_DIR%;%SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\Wbem"
pushd "%DIST%\sync-server"
"%BUNDLE_NODE%" "%BUNDLE_NPM%" install --omit=dev --no-audit --no-fund
if errorlevel 1 (
  popd
  set "PATH=%_OLD_PATH%"
  echo [X] npm install im Bundle fehlgeschlagen.
  goto :error
)
popd
set "PATH=%_OLD_PATH%"

if not exist "%DIST%\sync-server\node_modules\better-sqlite3\build\Release\better_sqlite3.node" (
  echo [!] Warnung: better_sqlite3.node nicht gefunden - Start koennte trotzdem fehlschlagen.
)

REM LIESMICH.txt fuer den Endnutzer
(
  echo TeamLink - Doppelklick auf TeamLink.exe zum Starten.
  echo.
  echo Es ist KEINE Internetverbindung beim ersten Start noetig.
  echo Alle Abhaengigkeiten sind im Bundle enthalten.
  echo.
  echo Portables Node.js liegt in runtime\node\ und wird vom Launcher
  echo verwendet, ohne dass Node systemweit installiert sein muss.
) > "%DIST%\LIESMICH.txt"

REM ----------------------------------------------------------------
REM 9) Bundle als ZIP packen fuer einfache Verteilung.
REM ----------------------------------------------------------------
echo [7/7] Bundle in ZIP packen ...
for /f "tokens=1-3 delims=." %%a in ('"%BUNDLE_NODE%" -p "require('./sync-server/package.json').version || '0.0.0'"') do (
  set "APP_VERSION=%%a.%%b.%%c"
)
if "!APP_VERSION!"=="" set "APP_VERSION=0.1.0"
set "ZIP_PATH=%ROOT%\dist\TeamLink-v!APP_VERSION!-win-x64.zip"
if exist "!ZIP_PATH!" del /q "!ZIP_PATH!"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%DIST%\*' -DestinationPath '!ZIP_PATH!' -CompressionLevel Optimal -Force"
if errorlevel 1 (
  echo [X] ZIP-Erstellung fehlgeschlagen.
  goto :error
)
if not exist "!ZIP_PATH!" (
  echo [X] ZIP-Datei wurde nicht erzeugt.
  goto :error
)

echo.
echo === Fertig ===
echo Bundle:  %DIST%
echo Start:   %DIST%\TeamLink.exe
echo ZIP:     !ZIP_PATH!
echo.
echo Naechster Schritt zur Verteilung:
echo   gh release create v!APP_VERSION! "!ZIP_PATH!" --title "TeamLink v!APP_VERSION!" --generate-notes
echo.
goto :end

:error
echo.
echo *** Build fehlgeschlagen ***
endlocal
exit /b 1

:end
endlocal
exit /b 0
