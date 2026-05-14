@echo off
setlocal EnableDelayedExpansion
title TeamLink - Build

REM ============================================================
REM  TeamLink - Entwickler-Build
REM  Erzeugt ein verteilbares Bundle in dist\TeamLink\.
REM  Endnutzer starten daraus einfach TeamLink.exe.
REM ============================================================

REM === Konfiguration ===
set "NODE_VERSION=v22.11.0"
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
REM 3) Distributionsverzeichnis vorbereiten
REM ----------------------------------------------------------------
echo [1/6] Vorheriges Build aufraeumen ...
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%"
if not exist "%CACHE%" mkdir "%CACHE%"

REM ----------------------------------------------------------------
REM 4) Flutter Windows Release-Build
REM ----------------------------------------------------------------
echo [2/6] Flutter Windows Release-Build ...
pushd "%ROOT%\desktop-client"
call flutter pub get
if errorlevel 1 ( popd & goto :error )
call flutter build windows --release
if errorlevel 1 ( popd & goto :error )
popd

if not exist "%FLUTTER_OUT%\desktop_client.exe" (
  echo [X] Flutter-Build nicht gefunden: %FLUTTER_OUT%\desktop_client.exe
  goto :error
)

REM ----------------------------------------------------------------
REM 5) Launcher.cs -> TeamLink.exe
REM ----------------------------------------------------------------
echo [3/6] Launcher kompilieren ...
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
  echo [4/6] Lade portables Node.js %NODE_VERSION% ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_CACHE_ZIP%'"
  if errorlevel 1 (
    echo [X] Download fehlgeschlagen: %NODE_URL%
    goto :error
  )
) else (
  echo [4/6] Portables Node.js bereits im Cache.
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
REM 7) Bundle zusammenstellen: Flutter + sync-server
REM ----------------------------------------------------------------
echo [5/6] Bundle zusammenstellen ...

mkdir "%DIST%\desktop-client\build\windows\x64\runner\Release"
xcopy "%FLUTTER_OUT%" "%DIST%\desktop-client\build\windows\x64\runner\Release" /E /I /Y /Q >nul
if errorlevel 1 (
  echo [X] Kopieren des Flutter-Builds fehlgeschlagen.
  goto :error
)

mkdir "%DIST%\sync-server"
xcopy "%ROOT%\sync-server\src" "%DIST%\sync-server\src" /E /I /Y /Q >nul
copy /Y "%ROOT%\sync-server\package.json" "%DIST%\sync-server\" >nul
if exist "%ROOT%\sync-server\package-lock.json" copy /Y "%ROOT%\sync-server\package-lock.json" "%DIST%\sync-server\" >nul

REM LIESMICH.txt fuer den Endnutzer
(
  echo TeamLink - Doppelklick auf TeamLink.exe zum Starten.
  echo.
  echo Beim ersten Start im Host-Modus werden automatisch die
  echo Server-Abhaengigkeiten installiert (Internetverbindung noetig,
  echo ca. 30 Sekunden^).
  echo.
  echo Portables Node.js liegt in runtime\node\ und wird vom Launcher
  echo bevorzugt verwendet, auch wenn Node nicht systemweit installiert ist.
) > "%DIST%\LIESMICH.txt"

echo [6/6] Fertig.
echo.
echo Bundle: %DIST%
echo Start:  %DIST%\TeamLink.exe
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
