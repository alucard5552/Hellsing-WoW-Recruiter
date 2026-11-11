@echo off
chcp 65001 >nul
title HELLSING Organization - Install Dependencies
echo ========================================================
echo   HELLSING ORGANIZATION - DEPENDENCY INSTALLER
echo   World of Warcraft Autonomous Recruiter
echo ========================================================
echo.
python --version
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH!
    pause
    exit /b 1
)
echo [1/2] Upgrading pip...
python -m pip install --upgrade pip

echo [2/2] Installing requirements from requirements.txt...
python -m pip install -r "%~dp0..\requirements.txt"

echo.
echo [SUCCESS] All Hellsing Recruiter dependencies installed!
pause
