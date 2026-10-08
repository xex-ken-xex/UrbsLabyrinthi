@echo off
cd /d "%~dp0"
UrbsLabyrinthi.console.exe --verbose > urbs-log.txt 2>&1
echo exit code: %ERRORLEVEL% >> urbs-log.txt
echo Done. Please send urbs-log.txt
pause
