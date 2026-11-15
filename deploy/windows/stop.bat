@echo off
rem AI Resume Server - stop staging task and its python processes
powershell -NoProfile -Command "Stop-ScheduledTask -TaskName 'AIResumeServer' -ErrorAction SilentlyContinue; Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*ai-resume*' } | Stop-Process -Force" >nul 2>&1
echo Stopped AIResumeServer task and ai-resume python processes.
