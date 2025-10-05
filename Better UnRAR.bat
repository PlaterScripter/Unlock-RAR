@echo off
setlocal enabledelayedexpansion
title RAR Password Unlocker - Enterprise Edition

:: -------------------------
:: Configuration / Defaults
:: -------------------------
set "UNRAR_EXE="
set "TMP_DIR=%~dp0temp_unrar_%RANDOM%"
set "LOG=%TMP_DIR%\unrar_log.txt"

:: Try to find UnRAR automatically
if exist "%ProgramFiles%\WinRAR\UnRAR.exe" set "UNRAR_EXE=%ProgramFiles%\WinRAR\UnRAR.exe"
if "%UNRAR_EXE%"=="" if exist "%ProgramFiles(x86)%\WinRAR\UnRAR.exe" set "UNRAR_EXE=%ProgramFiles(x86)%\WinRAR\UnRAR.exe"
if "%UNRAR_EXE%"=="" (
    for %%G in (unrar.exe UNRAR.EXE) do (
        for %%H in ("%PATH:;=";"%") do (
            if exist "%%~H\%%G" if "%UNRAR_EXE%"=="" set "UNRAR_EXE=%%~H\%%G"
        )
    )
)

:CheckUnrar
if "%UNRAR_EXE%"=="" (
    echo ERROR: UnRAR.exe not found automatically.
    echo Please install WinRAR or copy UnRAR.exe into this folder or make sure it's on PATH.
    echo Expected typical locations:
    echo   %%ProgramFiles%%\WinRAR\UnRAR.exe or on PATH.
    pause
    goto :eof
)

:: Create temp folder
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"

:: Main menu
:MENU
cls
echo =====================================================
echo RAR Password Unlocker - Menu
echo =====================================================
echo UnRAR found at: %UNRAR_EXE%
echo.
echo 1. Numeric brute-force (1..N)
echo 2. Numeric brute-force with zero-padding (e.g. 0001..9999)
echo 3. Wordlist attack (use a dictionary file)
echo 4. Exit
echo.
set /p "CHOICE=Choose an option [1-4]: "
if "%CHOICE%"=="" goto MENU
if "%CHOICE%"=="1" goto BRUTE_SIMPLE
if "%CHOICE%"=="2" goto BRUTE_PADDED
if "%CHOICE%"=="3" goto WORDLIST
if "%CHOICE%"=="4" goto CLEANUP_EXIT
goto MENU

:: -----------------------------------------------------
:: Get target archive path function
:: -----------------------------------------------------
:GET_ARCHIVE
set /p "ARCHIVE=Enter full archive path (include .rar): "
if "%ARCHIVE%"=="" (
    echo You can't leave this blank.
    pause
    goto GET_ARCHIVE
)
if not exist "%ARCHIVE%" (
    echo File not found: %ARCHIVE%
    pause
    goto GET_ARCHIVE
)
goto :eof

:: -----------------------------------------------------
:: Numeric brute-force, simple
:: -----------------------------------------------------
:BRUTE_SIMPLE
cls
echo Numeric brute-force (incremental)
call :GET_ARCHIVE

set /p "START=Start number (default 1): "
if "%START%"=="" set "START=1"
set /p "END=End number (e.g. 999999): "
if "%END%"=="" (
    echo End cannot be empty.
    pause
    goto BRUTE_SIMPLE
)

echo Starting from %START% to %END%
echo Results will be logged to %LOG%
echo.>"%LOG%"

for /L %%i in (%START%,1,%END%) do (
    set "PW=%%i"
    rem Try to extract quietly (-inul) and overwrite (-y)
    "%UNRAR_EXE%" e -y -inul -p"!PW!" "%ARCHIVE%" "%TMP_DIR%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo SUCCESS: password found -> !PW!
        echo File: %ARCHIVE% >> "%LOG%"
        echo Password: !PW! >> "%LOG%"
        echo Date: %DATE% %TIME% >> "%LOG%"
        goto :FOUND
    )
)

echo Completed loop without success.
pause
goto MENU

:: -----------------------------------------------------
:: Numeric brute-force with padding
:: -----------------------------------------------------
:BRUTE_PADDED
cls
echo Numeric brute-force with zero-padding
call :GET_ARCHIVE

set /p "LENGTH=Password length (e.g. 4 for 0000..9999): "
if "%LENGTH%"=="" (
    echo Length cannot be empty.
    pause
    goto BRUTE_PADDED
)
set /a "MAX=1"
for /L %%i in (1,1,%LENGTH%) do set /a "MAX *= 10"
set /a "MAX = MAX - 1"

echo Brute-forcing 0 padded from 0 to %MAX% with width %LENGTH%
echo Results will be logged to %LOG%
echo.>"%LOG%"

for /L %%i in (0,1,%MAX%) do (
    set "NUM=%%i"
    set "PW=!NUM!"
    rem pad with leading zeros
    set "PAD=0000000000000000!PW!"
    set "PW=!PAD:~- %LENGTH%!"
    rem the above substring trick needs adjusted spacing removal
    set "PW=!PAD:~- %LENGTH%!"
    rem safe way to pad (works in cmd): use string slicing properly
    set "PW=!PAD:~- %LENGTH%!"
    rem But because CMD substring with variable-length index is picky, do this:
    set "PW=0000000000000000%%i"
    set "PW=!PW:~- %LENGTH%!"
    rem Try password
    "%UNRAR_EXE%" e -y -inul -p"!PW!" "%ARCHIVE%" "%TMP_DIR%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo SUCCESS: password found -> !PW!
        echo File: %ARCHIVE% >> "%LOG%"
        echo Password: !PW! >> "%LOG%"
        echo Date: %DATE% %TIME% >> "%LOG%"
        goto :FOUND
    )
)

echo Completed padded brute-force without success.
pause
goto MENU

:: -----------------------------------------------------
:: Wordlist attack
:: -----------------------------------------------------
:WORDLIST
cls
echo Wordlist attack
call :GET_ARCHIVE

set /p "WL=Enter full path to wordlist file: "
if "%WL%"=="" (
    echo Wordlist path cannot be blank.
    pause
    goto WORDLIST
)
if not exist "%WL%" (
    echo Wordlist not found: %WL%
    pause
    goto WORDLIST
)

echo Starting wordlist attack using %WL%
echo Results will be logged to %LOG%
echo.>"%LOG%"

for /f "usebackq delims=" %%P in ("%WL%") do (
    set "PW=%%P"
    "%UNRAR_EXE%" e -y -inul -p"!PW!" "%ARCHIVE%" "%TMP_DIR%" >nul 2>&1
    if !errorlevel! equ 0 (
        echo SUCCESS: password found -> !PW!
        echo File: %ARCHIVE% >> "%LOG%"
        echo Password: !PW! >> "%LOG%"
        echo Date: %DATE% %TIME% >> "%LOG%"
        goto :FOUND
    )
)

echo Wordlist exhausted - no password found.
pause
goto MENU

:: -----------------------------------------------------
:: Found label - cleanup and report
:: -----------------------------------------------------
:FOUND
echo.
echo =====================================================
echo Password found!
echo Archive: %ARCHIVE%
echo Password: !PW!
echo (Logged to %LOG%)
echo =====================================================
echo Extracted files (if any) are in: %TMP_DIR%
pause
goto CLEANUP_EXIT

:: -----------------------------------------------------
:: Cleanup and exit
:: -----------------------------------------------------
:CLEANUP_EXIT
echo Cleaning temporary files...
if exist "%TMP_DIR%" (
    rem Do not force-delete system folders - only remove our temp dir
    rd /s /q "%TMP_DIR%" >nul 2>&1
)
echo Done.
endlocal
exit /b 0
