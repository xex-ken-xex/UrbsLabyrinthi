@echo off
rem Urbs Labyrinthi のセットアップ(Windows)。ダブルクリックで実行できる。
rem   setup-windows.bat -Dev     開発の道具も入れる
rem   setup-windows.bat -Check   足りないものだけ調べる
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
echo.
pause
