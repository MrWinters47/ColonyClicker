@echo off
:: =============================================================
::  push.bat — Auto Commit & Push Script
::  Godot Game Project: cc-main
::  Usage: Double-click or run from command prompt
:: =============================================================

:: Change to the project directory (handles running from anywhere)
cd /d "%~dp0"

echo.
echo =========================================
echo   CC-MAIN  —  Auto Git Push
echo =========================================
echo.

:: Check that Git is installed
where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Git is not installed or not in PATH.
    echo         Download Git from https://git-scm.com
    pause
    exit /b 1
)

:: Check that we are inside a Git repo
git rev-parse --git-dir >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This folder is not a Git repository.
    echo         Run: git init  — then set up your remote and try again.
    pause
    exit /b 1
)

:: Show current status so you know what will be committed
echo --- Files to be staged ---
git status --short
echo.

:: Stage ALL changes (new files, modifications, deletions)
echo [1/3] Staging all changes...
git add --all
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] git add failed.
    pause
    exit /b 1
)

:: Build a timestamp for the commit message  e.g. "2026-05-24 22:03"
for /f "tokens=1-5 delims=/:. " %%a in ('powershell -NoProfile -Command "Get-Date -Format \"yyyy-MM-dd HH:mm\""') do (
    set TIMESTAMP=%%a-%%b-%%c %%d:%%e
)
:: Simpler fallback using DATE and TIME env vars (always available)
:: Format: YYYY-MM-DD HH:MM
set TIMESTAMP=%DATE:~10,4%-%DATE:~4,2%-%DATE:~7,2% %TIME:~0,5%

set COMMIT_MSG=auto-save: %TIMESTAMP%

echo [2/3] Committing: "%COMMIT_MSG%"
git commit -m "%COMMIT_MSG%"
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Nothing new to commit (working tree is clean).
    pause
    exit /b 0
)

:: Push to the remote (origin) on the current branch
echo [3/3] Pushing to remote...
git push
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Push failed. Common causes:
    echo   - No remote set up yet  (run: git remote add origin YOUR_URL)
    echo   - Not authenticated     (run: git push --set-upstream origin main)
    echo   - No internet connection
    pause
    exit /b 1
)

echo.
echo =========================================
echo   Done! Changes pushed successfully.
echo =========================================
echo.
pause
