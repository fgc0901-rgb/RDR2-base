@echo off
:: Shim: call PowerShell version for reliable execution in PS/CMD
setlocal
set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%Switch-RedM-Account-Advanced.ps1"
if not exist "%PS1%" (
  echo [ERRO] Nao encontrei %PS1%
  exit /b 1
)
:: Preserve arguments and allow endpoint colons
powershell -ExecutionPolicy Bypass -File "%PS1%" %*
exit /b %ERRORLEVEL%
