@echo off
rem AI Resume Server - foreground start (debug; production uses install.ps1 scheduled task)
cd /d "%~dp0.."
set "LD_LIBRARY_PATH="
set PYTHONUNBUFFERED=1
if "%PORT%"=="" set PORT=8000
if "%BIND_HOST%"=="" set BIND_HOST=0.0.0.0
echo Starting AI Resume Server: http://%BIND_HOST%:%PORT%
runtime\python.exe -m uvicorn app.main:app --host %BIND_HOST% --port %PORT%
