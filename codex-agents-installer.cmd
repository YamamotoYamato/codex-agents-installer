@echo off
setlocal

if exist "%ProgramFiles%\Git\bin\bash.exe" goto run64

if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" goto run86

>&2 echo Git Bash was not found. Install Git for Windows.
exit /b 1

:run64
"%ProgramFiles%\Git\bin\bash.exe" "%~dp0codex-agents-installer" %*
exit /b %errorlevel%

:run86
"%ProgramFiles(x86)%\Git\bin\bash.exe" "%~dp0codex-agents-installer" %*
exit /b %errorlevel%
