@echo off
setlocal EnableDelayedExpansion

echo o3utl v1.0.3
echo https://github.com/oo0v/o3utl
echo.

call :main %*
set "EXIT_CODE=!errorlevel!"
endlocal
exit /b !EXIT_CODE!

:main
REM Argument check
if "%~1"=="" (
    echo Usage: 
    echo   %~nx0 ^<input_file^> [profile]
    echo   Or drag and drop a file onto this batch file
    echo.
    echo Arguments:
    echo   input_file  : Path to the file to process
    echo   profile     : Optional processing profile
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Input file path
set "INPUT_FILE=%~1"

REM File existence check
if not exist "!INPUT_FILE!" (
    echo Error: File not found: !INPUT_FILE!
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Check existence of core.ps1
set "CORE_SCRIPT=%~dp0src\core.ps1"
if not exist "!CORE_SCRIPT!" (
    echo Error: core.ps1 not found in src directory
    echo Expected location: !CORE_SCRIPT!
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo Processing started at %date% %time%
echo Input file: !INPUT_FILE!

REM Call PowerShell core module
set "PROFILE=%~2"

REM Build PowerShell command line
set "PS_COMMAND=powershell.exe -ExecutionPolicy RemoteSigned -File "!CORE_SCRIPT!" -InputFile "!INPUT_FILE!""
if not "!PROFILE!"=="" (
    set "PS_COMMAND=!PS_COMMAND! -Profile "!PROFILE!""
)

REM Execute PowerShell
!PS_COMMAND!

set "PS_EXIT_CODE=!errorlevel!"
echo.
echo Processing completed at %date% %time%

echo.
echo Press any key to exit...
pause >nul
exit /b 0