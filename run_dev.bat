@echo off
setlocal enabledelayedexpansion

set PROJECT_DIR=%~dp0
set ENV_FILE=%PROJECT_DIR%.env.dev

set SUPABASE_URL=
set SUPABASE_ANON_KEY=
set GOOGLE_MAPS_API_KEY=

if exist "%ENV_FILE%" (
    for /f "usebackq tokens=*" %%a in ("%ENV_FILE%") do (
        set "line=%%a"
        set "line=!line: =!"
        if not "!line:~0,1!"=="#" (
            for /f "tokens=1,2 delims==" %%b in ("!line!") do (
                if /i "%%b"=="SUPABASE_URL" set SUPABASE_URL=%%c
                if /i "%%b"=="SUPABASE_PUBLISHABLE_KEY" set SUPABASE_ANON_KEY=%%c
                if /i "%%b"=="SUPABASE_ANON_KEY" set SUPABASE_ANON_KEY=%%c
                if /i "%%b"=="GOOGLE_MAPS_API_KEY" set GOOGLE_MAPS_API_KEY=%%c
            )
        )
    )
) else (
    echo Fichier .env.dev introuvable, utilisation des valeurs par defaut.
)

cd /d "%PROJECT_DIR%transitci"

flutter run ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% ^
  --dart-define=GOOGLE_MAPS_API_KEY=%GOOGLE_MAPS_API_KEY%
