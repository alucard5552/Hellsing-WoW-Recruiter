# HELLSING Organization - PowerShell Automated Build Pipeline
Write-Host "========================================================" -ForegroundColor Red
Write-Host "  HELLSING ORGANIZATION - COMPILER PIPELINE v1.0.0" -ForegroundColor DarkRed
Write-Host "  World of Warcraft Autonomous Recruiter" -ForegroundColor DarkRed
Write-Host "========================================================" -ForegroundColor Red

$repoDir = Split-Path -Parent $PSScriptRoot
Set-Location $repoDir
Write-Host "[INFO] Repository Root: $repoDir" -ForegroundColor Gray

# 1. Проверка синтаксиса
Write-Host "`n[1/4] Verifying Lua and Python syntax..." -ForegroundColor Yellow
python check_lua_syntax.py "AddOns\KeyAutoRecruit\KeyAutoRecruit.lua"
if ($LASTEXITCODE -ne 0) { throw "Lua syntax verification failed!" }

python -m py_compile wow_voice_clicker.py html_installer.py
if ($LASTEXITCODE -ne 0) { throw "Python syntax verification failed!" }
Write-Host "[OK] Syntax verified cleanly." -ForegroundColor Green

# 2. Сборка службы WoWSmartRecruiter.exe
Write-Host "`n[2/4] Compiling WoWSmartRecruiter.exe (Daemon)..." -ForegroundColor Yellow
python -m PyInstaller --clean -y WoWSmartRecruiter.spec
if ($LASTEXITCODE -ne 0) { throw "Failed to compile WoWSmartRecruiter.exe!" }
Copy-Item "dist\WoWSmartRecruiter.exe" "WoWSmartRecruiter.exe" -Force
Write-Host "[OK] WoWSmartRecruiter.exe compiled." -ForegroundColor Green

# 3. Сборка автономного инсталлятора HELLSING_Recruiter_Setup.exe
Write-Host "`n[3/4] Compiling HELLSING_Recruiter_Setup.exe (Standalone Installer)..." -ForegroundColor Yellow
python -m PyInstaller --clean -y HELLSING_Recruiter_Setup.spec
if ($LASTEXITCODE -ne 0) { throw "Failed to compile HELLSING_Recruiter_Setup.exe!" }
Write-Host "[OK] HELLSING_Recruiter_Setup.exe compiled." -ForegroundColor Green

# 4. Итоги
Write-Host "`n[4/4] Build complete! Artifacts in dist/:" -ForegroundColor Cyan
Get-ChildItem -Path "dist\*.exe" | Select-Object Name, Length, LastWriteTime | Format-Table
Write-Host "========================================================" -ForegroundColor Red
Write-Host "  HELLSING BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Red
