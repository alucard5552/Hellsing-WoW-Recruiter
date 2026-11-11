@echo off
chcp 65001 >nul
title HELLSING Organization - Manual Build Pipeline
echo ========================================================
echo   HELLSING ORGANIZATION - COMPILER PIPELINE v1.0.0
echo   World of Warcraft Autonomous Recruiter
echo ========================================================
echo.

cd /d "%~dp0.."
echo [INFO] Working directory: %CD%
echo.

echo [1/4] Verifying Lua and Python syntax...
python check_lua_syntax.py "AddOns\KeyAutoRecruit\KeyAutoRecruit.lua"
if errorlevel 1 (
    echo [ERROR] Lua syntax check failed!
    pause
    exit /b 1
)
python -m py_compile wow_voice_clicker.py html_installer.py
if errorlevel 1 (
    echo [ERROR] Python syntax check failed!
    pause
    exit /b 1
)
echo [OK] Syntax verification passed.
echo.

echo [2/4] Compiling WoWSmartRecruiter.exe (Daemon)...
python -m PyInstaller --clean -y WoWSmartRecruiter.spec
if errorlevel 1 (
    echo [ERROR] Failed to compile WoWSmartRecruiter.exe!
    pause
    exit /b 1
)
copy /y dist\WoWSmartRecruiter.exe . >nul
echo [OK] WoWSmartRecruiter.exe compiled successfully.
echo.

echo [3/4] Compiling HELLSING_Recruiter_Setup.exe (Standalone Installer)...
python -m PyInstaller --clean -y HELLSING_Recruiter_Setup.spec
if errorlevel 1 (
    echo [ERROR] Failed to compile HELLSING_Recruiter_Setup.exe!
    pause
    exit /b 1
)
echo [OK] HELLSING_Recruiter_Setup.exe compiled successfully.
echo.

echo [4/4] Build complete! Artifacts:
dir dist\*.exe
echo.
echo ========================================================
echo   HELLSING BUILD SUCCESSFUL! ALL EXEs READY IN dist\
echo ========================================================
pause
