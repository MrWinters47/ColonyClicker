@echo off
:: =============================================================
::  push.bat — Upgraded Auto Commit, Tag, & Push Script
::  Godot Game Project: cc-main
:: =============================================================

:: Change to the project directory (handles running from anywhere)
cd /d "%~dp0"

echo.
echo =================================================
echo   CC-MAIN  -  Interactive Git Assistant
echo =================================================
echo.

:: Check that Git is installed
where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Git is not installed or not in PATH.
    pause
    exit /b 1
)

:: Check that we are inside a Git repo
git rev-parse --git-dir >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This folder is not a Git repository.
    pause
    exit /b 1
)

:: Show current status so you know what will be committed
echo --- Unsaved Changes ---
git status --short
echo.
echo -------------------------------------------------

:: 1. Ask for the change description
echo 📝 [Step 1/2] Describe your changes.
set /p DESC="What did you do? (Press Enter for auto-timestamp): "

:: 2. Ask for the version
echo.
echo 🏷️ [Step 2/2] Optional: Mark a version/milestone.
echo (e.g., v0.1-alpha, beta-v1, release-v1.0)
set /p VER="What version is this? (Press Enter to skip): "
echo.
echo -------------------------------------------------

:: Build timestamp fallback
for /f "tokens=1-5 delims=/:. " %%a in ('powershell -NoProfile -Command "Get-Date -Format \"yyyy-MM-dd HH:mm\""') do (
    set TIMESTAMP=%%a-%%b-%%c %%d:%%e
)

:: Format the Commit Message
if "%DESC%"=="" (
    set COMMIT_MSG=auto-save: %TIMESTAMP%
) else (
    set COMMIT_MSG=%DESC%
)

:: If they entered a version, prefix the commit message with it
if not "%VER%"=="" (
    set COMMIT_MSG=[%VER%] %COMMIT_MSG%
)

:: Stage all changes
echo.
echo [1/3] Staging all files...
git add --all
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Staging failed.
    pause
    exit /b 1
)

:: Commit changes
echo [2/3] Committing: "%COMMIT_MSG%"
git commit -m "%COMMIT_MSG%"
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Nothing new to commit (working tree is clean).
    goto CHECK_TAGS
)

:CHECK_TAGS
:: If they entered a version, create a git tag locally
if not "%VER%"=="" (
    echo.
    echo [TAGGING] Creating release tag: %VER%
    :: Delete tag locally if it already exists to avoid conflicts, then recreate
    git tag -d %VER% >nul 2>&1
    git tag -a %VER% -m "Release %VER%: %COMMIT_MSG%"
)

:: Push changes to GitHub
echo.
echo [3/3] Pushing code to GitHub...
git push
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Push failed. Check your internet connection or GitHub credentials.
    pause
    exit /b 1
)

:: Push the tag to GitHub if they entered one
if not "%VER%"=="" (
    echo.
    echo [TAGGING] Pushing version tag to GitHub...
    git push origin %VER% --force
    echo.
    echo 🎉 Version "%VER%" is now officially registered on GitHub!
)

echo.
echo =================================================
echo   Done! All changes and tags are now safe online.
echo =================================================
echo.
pause
