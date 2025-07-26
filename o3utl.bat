@echo off
setlocal EnableDelayedExpansion

call :main %*
set "EXIT_CODE=!errorlevel!"
endlocal
exit /b !EXIT_CODE!

:main
REM Check for multiple files
if not "%~2"=="" (
    echo Error: Multiple files not supported
    echo Usage: 
    echo   %~nx0 ^<input_file^>
    echo   Only single file processing is allowed
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Usage check
if "%~1"=="" (
    echo Usage: 
    echo   %~nx0 ^<input_file^>
    echo   Or drag and drop a file onto this batch file
    echo.
    echo Arguments:
    echo   input_file  : Path to the file to process
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Input file path
set "INPUT_FILE=%~1"

REM Input file check
if not exist "!INPUT_FILE!" (
    echo Error: File not found: !INPUT_FILE!
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Core script check
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

REM Execute PowerShell core
set "PROFILE="

REM Build and execute PowerShell command
set "PS_COMMAND=powershell.exe -ExecutionPolicy Bypass -File "!CORE_SCRIPT!" -InputFile "!INPUT_FILE!""

REM Execute PowerShell
!PS_COMMAND!

set "PS_EXIT_CODE=!errorlevel!"
echo.
echo Processing completed at %date% %time%

echo.
echo Press any key to exit...
pause >nul
exit /b 0