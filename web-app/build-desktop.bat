@echo off
REM ThirdBooks Desktop App Build Script for Windows

echo.
echo ThirdBooks Desktop App Builder
echo ================================
echo.

REM Check if in correct directory
if not exist package.json (
    echo Error: Must run from web-app directory
    exit /b 1
)

REM Check if Rust is installed
where cargo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Rust not installed
    echo Install from: https://rustup.rs
    exit /b 1
)

REM Check if Node.js is installed
where npm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Node.js/npm not installed
    exit /b 1
)

:menu
echo.
echo Select build type:
echo   1) Development (with hot reload)
echo   2) Production (optimized builds)
echo   3) Install dependencies only
echo   4) Check requirements
echo   5) Exit
echo.

set /p choice="Choice [1-5]: "

if "%choice%"=="1" goto dev
if "%choice%"=="2" goto prod
if "%choice%"=="3" goto deps
if "%choice%"=="4" goto check
if "%choice%"=="5" goto end
goto menu

:dev
echo.
echo Installing dependencies...
call npm install
echo.
echo Starting development build...
call npm run tauri:dev
goto end

:prod
echo.
echo Installing dependencies...
call npm install
echo.
echo Checking icons...
if not exist src-tauri\icons\icon.png (
    echo Warning: Icons not generated
    echo.
    echo Quick fix:
    echo   npm install -g @tauri-apps/cli
    echo   curl -L https://raw.githubusercontent.com/tauri-apps/tauri/dev/tooling/cli/templates/app/app-icon.png -o src-tauri\icon-source.png
    echo   cd src-tauri
    echo   tauri icon icon-source.png
    echo   cd ..
    echo.
    set /p continue="Continue anyway? (y/n): "
    if /i not "%continue%"=="y" goto end
)
echo.
echo Building for production...
call npm run tauri:build
echo.
echo Build complete!
echo.
echo Output locations:
echo   - Portable: src-tauri\target\release\thirdbooks.exe
echo   - Installer: src-tauri\target\release\bundle\msi\ThirdBooks_1.0.0_x64_en-US.msi
goto end

:deps
echo.
echo Installing dependencies...
call npm install
echo.
echo Dependencies installed!
goto end

:check
echo.
echo System Requirements:
echo ===================
echo.

where cargo >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Rust: Installed
) else (
    echo [X] Rust: Not installed
    echo     Install: https://rustup.rs
)

where node >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Node.js: Installed
) else (
    echo [X] Node.js: Not installed
)

where npm >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] npm: Installed
) else (
    echo [X] npm: Not installed
)

echo.
echo Platform-specific dependencies:
echo   - Microsoft Visual Studio C++ Build Tools
echo   - WebView2 (usually pre-installed on Windows 10/11)
echo.
pause
goto menu

:end
echo.
echo Goodbye!
exit /b 0
