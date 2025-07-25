param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [string]$Profile = ""
)

# Error action setting
$ErrorActionPreference = "Stop"

# Record original location
$originalLocation = Get-Location
$tempDirectory = $null
$allTempFiles = @()

try {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    # Input file validation
    if (-not (Test-Path -Path $InputFile -PathType Leaf)) {
        throw "Input file not found: $InputFile"
    }

    # Convert to absolute path
    $InputFile = (Resolve-Path -Path $InputFile).Path

    # Load tasks.ini
    $ConfigFile = Join-Path -Path $ScriptDir -ChildPath "..\tasks.ini"
    if (-not (Test-Path -Path $ConfigFile -PathType Leaf)) {
        throw "tasks.ini not found at: $ConfigFile"
    }

    # Set working directory to tasks.ini directory
    $WorkingDir = Split-Path -Parent (Resolve-Path -Path $ConfigFile).Path
    Set-Location -Path $WorkingDir

    # Create dedicated temporary directory for this program
    $tempDirectory = Join-Path $WorkingDir "tmp"
    
    # Cleanup existing temp directory if it exists
    if (Test-Path $tempDirectory) {
        Write-Host "Cleaning up existing temporary directory..." -ForegroundColor Yellow
        try {
            $tempFiles = Get-ChildItem -Path $tempDirectory -File -ErrorAction SilentlyContinue
            $cleanedFileCount = 0
            foreach ($tempFile in $tempFiles) {
                try {
                    Remove-Item $tempFile.FullName -Force -ErrorAction Stop
                    $cleanedFileCount++
                    Write-Host "  Removed: $($tempFile.Name)" -ForegroundColor Gray
                } catch {
                    Write-Host "  Failed to remove: $($tempFile.Name)" -ForegroundColor Yellow
                }
            }
            
            if ($cleanedFileCount -gt 0) {
                Write-Host "Cleaned up $cleanedFileCount temporary files" -ForegroundColor Green
            } else {
                Write-Host "No temporary files to clean up" -ForegroundColor Gray
            }
        } catch {
            Write-Host "Warning: Temp directory cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Creating temporary directory: $tempDirectory" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
    }

    # bin directory path
    $BinDir = Join-Path -Path $ScriptDir -ChildPath "..\bin"

    # Binary search function
    function Find-Binary {
        param([string]$BinaryName)
        
        # 1. Search in bin folder
        if (Test-Path $BinDir) {
            $binPath = Join-Path $BinDir "$BinaryName.exe"
            if (Test-Path $binPath) {
                return $binPath
            }
        }
        
        # 2. Search in environment variable PATH
        try {
            $pathResult = Get-Command $BinaryName -ErrorAction Stop
            return $pathResult.Path
        } catch {
            return $null
        }
    }

    # Function to extract binary name from command
    function Get-BinaryFromCommand {
        param([string]$Command)
        
        # Extract first word (binary name) from command
        $firstWord = ($Command -split '\s+')[0]
        return $firstWord
    }

    # Command line generation function
    function CommandLine {
        param(
            [string]$CommandTemplate,
            [string]$InputPath,
            [string]$BinaryPath = ""
        )
        
        # Expand environment variables first
        $expandedCommand = [System.Environment]::ExpandEnvironmentVariables($CommandTemplate)
        
        # Replace binary path if provided
        if (-not [string]::IsNullOrEmpty($BinaryPath)) {
            $binaryName = Get-BinaryFromCommand $expandedCommand
            $expandedCommand = $expandedCommand -replace "^$([regex]::Escape($binaryName))", "`"$BinaryPath`""
        }
        
        # Handle all possible {INPUT} patterns
        $patterns = @(
            '"\{INPUT\}"',  # Already quoted
            '\{INPUT\}'     # Not quoted
        )
        
        $finalCommand = $expandedCommand
        foreach ($pattern in $patterns) {
            if ($expandedCommand -match $pattern) {
                if ($pattern -eq '"\{INPUT\}"') {
                    # Already quoted pattern - replace with quoted path
                    $finalCommand = $expandedCommand -replace $pattern, "`"$InputPath`""
                } else {
                    # Unquoted pattern - add quotes if needed
                    if ($InputPath -match '\s') {
                        $finalCommand = $expandedCommand -replace $pattern, "`"$InputPath`""
                    } else {
                        $finalCommand = $expandedCommand -replace $pattern, $InputPath
                    }
                }
                break
            }
        }
        
        # Clean up any double quotes that might have been created
        $finalCommand = $finalCommand -replace '""', '"'
        
        return $finalCommand
    }

    # INI parsing function
    function Read-ConfigurationFile {
        param([string]$FilePath)
        
        $Configuration = [ordered]@{}
        $CurrentSection = ""
        
        try {
            $content = Get-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop
            
            foreach ($line in $content) {
                $cleanLine = $line.Trim()
                
                # Skip empty lines and comment lines
                if ([string]::IsNullOrEmpty($cleanLine) -or 
                    $cleanLine.StartsWith("#") -or 
                    $cleanLine.StartsWith(";")) { 
                    continue 
                }
                
                # Process section lines
                if ($cleanLine -match '^\[(.+)\]$') {
                    $CurrentSection = $matches[1].Trim()
                    $Configuration[$CurrentSection] = @{}
                    continue
                }
                
                # Process key=value
                if ($cleanLine -match '^([^=]+)=(.*)$' -and -not [string]::IsNullOrEmpty($CurrentSection)) {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    $Configuration[$CurrentSection][$key] = $value
                }
            }
        }
        catch {
            throw "Failed to read configuration file: $($_.Exception.Message)"
        }
        
        return $Configuration
    }

    $Config = Read-ConfigurationFile -FilePath $ConfigFile

    if ($Config.Count -eq 0) {
        throw "No valid sections found in tasks.ini"
    }

    # Profile selection function
    function Select-ProcessingProfiles {
        param(
            [System.Collections.Specialized.OrderedDictionary]$Configuration,
            [string]$ProfileInput
        )
        
        $selectedProfiles = @()

        if ([string]::IsNullOrEmpty($ProfileInput)) {
            # Interactive selection
            Write-Host ""
            Write-Host "Available tasks:" -ForegroundColor Yellow
            
            # Keys of [ordered]@{} maintain order
            $ProfileList = @($Configuration.Keys)
            $maxDigitLength = $ProfileList.Count.ToString().Length
            
            for ($i = 0; $i -lt $ProfileList.Count; $i++) {
                $profileName = $ProfileList[$i]
                $description = ""
                if ($Configuration[$profileName].Contains("description")) { 
                    $description = " - $($Configuration[$profileName]['description'])" 
                }
                $paddedNumber = ($i + 1).ToString().PadLeft($maxDigitLength)
                Write-Host "$paddedNumber. $profileName$description" -ForegroundColor Cyan
            }
            
            do {
                Write-Host ""
                Write-Host "Select tasks number (1-$($ProfileList.Count), comma-separated): " -ForegroundColor Green -NoNewline
                $userInput = Read-Host
                
                if ([string]::IsNullOrWhiteSpace($userInput)) {
                    Write-Host "Please enter a valid selection." -ForegroundColor Red
                    continue
                }
                
                $numbers = $userInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                $isValid = $true
                $tempProfiles = @()
                
                foreach ($number in $numbers) {
                    if ($number -match '^[0-9]+$') {
                        $index = [int]$number
                        if ($index -ge 1 -and $index -le $ProfileList.Count) {
                            $profileName = $ProfileList[$index - 1]
                            if ($tempProfiles -notcontains $profileName) {
                                $tempProfiles += $profileName
                            }
                        } else {
                            Write-Host "Invalid number: $number (must be 1-$($ProfileList.Count))" -ForegroundColor Red
                            $isValid = $false
                            break
                        }
                    } else {
                        Write-Host "Invalid input: $number (must be a number)" -ForegroundColor Red
                        $isValid = $false
                        break
                    }
                }
                
                if ($isValid -and $tempProfiles.Count -gt 0) {
                    $selectedProfiles = $tempProfiles
                    break
                }
            } while ($true)
        } else {
            # From command line arguments
            $selectedProfiles = $ProfileInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        }
        
        return $selectedProfiles
    }

    $selectedProfiles = Select-ProcessingProfiles -Configuration $Config -ProfileInput $Profile

    Write-Host "Selected tasks: $($selectedProfiles -join ', ')" -ForegroundColor Green

    # Binary existence check and profile validation
    $validProfiles = @()
    foreach ($prof in $selectedProfiles) {
        if (-not $Config.Contains($prof)) {
            Write-Host "Error: Profile '$prof' not found" -ForegroundColor Red
            continue
        }
        
        $cmd = $Config[$prof]["cmd"]
        if (-not $cmd) {
            Write-Host "Error: No cmd in task '$prof'" -ForegroundColor Red
            continue
        }
        
        # Extract binary name from command
        $binaryName = Get-BinaryFromCommand $cmd
        $binaryPath = Find-Binary $binaryName
        
        if ($binaryPath) {
            Write-Host "Binary found for '$prof': $binaryPath" -ForegroundColor Green
            $validProfiles += @{
                Profile = $prof
                Command = $cmd
                BinaryPath = $binaryPath
            }
        } else {
            Write-Host "Error: Binary '$binaryName' not found for task '$prof'" -ForegroundColor Red
            Write-Host "  Searched in: $BinDir and system PATH" -ForegroundColor Yellow
        }
    }

    if ($validProfiles.Count -eq 0) {
        throw "No valid tasks to process (no binaries found)."
    }

    # Execute each profile in parallel
    $processes = @()
    $windowIndex = 0

    foreach ($profileInfo in $validProfiles) {
        $prof = $profileInfo.Profile
        $cmd = $profileInfo.Command
        $binaryPath = $profileInfo.BinaryPath
        
        # Generate unique task ID
        $taskId = "task_$(Get-Random)"
        
        # Use the command line function
        $fullCmd = CommandLine -CommandTemplate $cmd -InputPath $InputFile -BinaryPath $binaryPath
        
        # Handle FFmpeg 2-pass log files with individual paths
        if ($fullCmd -match "-pass\s+[12]") {
            $passLogFile = Join-Path $tempDirectory "ffmpeg2pass_${taskId}"
            
            # Add -passlogfile option to both Pass 1 and Pass 2
            # First ffmpeg command (Pass 1)
            $fullCmd = $fullCmd -replace "(-pass\s+1)", "-passlogfile `"$passLogFile`" `$1"
            
            # Second ffmpeg command (Pass 2, after &&)
            $fullCmd = $fullCmd -replace "&&\s*([^&]*?)(-pass\s+2)", "&& `$1-passlogfile `"$passLogFile`" `$2"
            
            # Track log files for cleanup
            $allTempFiles += "${passLogFile}-0.log"
            $allTempFiles += "${passLogFile}-0.log.mbtree"
        }
        
        Write-Host "Starting: $prof" -ForegroundColor Yellow
        Write-Host "Modified command: $fullCmd" -ForegroundColor Gray
        
        # Result file path
        $resultFile = Join-Path $tempDirectory "result_${taskId}.txt"
        $allTempFiles += $resultFile
        
        # Create temporary batch file
        $tempBatch = Join-Path $tempDirectory "batch_${taskId}.bat"
        $allTempFiles += $tempBatch
        
        # Calculate window position
        $xPos = 100 + ($windowIndex * 60)
        $yPos = 100 + ($windowIndex * 60)
        
        # Create batch command (considering special characters)
        $safeProf = $prof -replace '[^\w\-]', '_'  # Replace non-alphanumeric characters except hyphens with underscores
        
        # Handle 2-pass encoding by splitting and executing commands
        if ($fullCmd -match " && ") {
            $commands = $fullCmd -split ' && '
            $pass1Cmd = $commands[0].Trim()
            $pass2Cmd = $commands[1].Trim()
            
            $batchCmd = @"
@echo off
title task: $safeProf
mode con: cols=120 lines=35
echo Starting tasks: $prof
echo Task ID: $taskId
echo Pass log file: $passLogFile
echo.
echo $pass1Cmd
echo.
echo Executing First Pass
$pass1Cmd
if %ERRORLEVEL% neq 0 (
    echo FAILED > "$resultFile"
    echo.
    echo Pass 1 Failed: $prof [Error: %ERRORLEVEL%]
    echo Press any key to close this window...
    pause > nul
    exit
)
echo First Pass completed successfully
echo.
echo $pass2Cmd
echo.
echo Executing Second Pass
$pass2Cmd
if %ERRORLEVEL% equ 0 (
    echo SUCCESS > "$resultFile"
    echo.
    echo Task Success: $prof
    timeout /t 2 > nul
    exit
) else (
    echo FAILED > "$resultFile"
    echo.
    echo Second Pass Failed: $prof [Error: %ERRORLEVEL%]
    echo Press any key to close this window...
    pause > nul
    exit
)
"@
        } else {
            # Single pass case
            $batchCmd = @"
@echo off
title task: $safeProf
mode con: cols=120 lines=35
echo Starting tasks: $prof
echo Command: $fullCmd
echo Task ID: $taskId
echo.
echo Executing command
$fullCmd
echo.
echo Command completed with exit code: %ERRORLEVEL%
if %ERRORLEVEL% equ 0 (
    echo SUCCESS > "$resultFile"
    echo.
    echo Task Success: $prof
    timeout /t 2 > nul
    exit
) else (
    echo FAILED > "$resultFile"
    echo.
    echo Task Failed: $prof [Error: %ERRORLEVEL%]
    echo Press any key to close this window...
    pause > nul
    exit
)
"@
        }
        
        # Create temporary batch file
        $batchCmd | Out-File -FilePath $tempBatch -Encoding ASCII
        
        # Start process (launch in normal window)
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tempBatch`"" -PassThru -WindowStyle Normal
        
        # Adjust window position after a short wait (execute in background)
        Start-Job -ScriptBlock {
            param($processId, $x, $y, $safeProf)
            Start-Sleep -Seconds 1
            Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                using System.Diagnostics;
                public class WindowHelper {
                    [DllImport("user32.dll")]
                    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
                    [DllImport("user32.dll")]
                    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
                    [DllImport("user32.dll")]
                    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                }
"@
            try {
                $windowTitle = "task: $safeProf"
                $hwnd = [WindowHelper]::FindWindow($null, $windowTitle)
                if ($hwnd -ne [IntPtr]::Zero) {
                    [WindowHelper]::ShowWindow($hwnd, 1) # SW_SHOWNORMAL
                    [WindowHelper]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001) # SWP_NOSIZE
                }
            } catch {
                # Ignore errors
            }
        } -ArgumentList $process.Id, $xPos, $yPos, $safeProf | Out-Null
        
        # Save process information
        $processes += @{
            Profile = $prof
            Process = $process
            ResultFile = $resultFile
            TempBatch = $tempBatch
            TaskId = $taskId
            Processed = $false
        }
        
        $windowIndex++
        Start-Sleep -Milliseconds 200  # Window startup interval
    }

    if ($processes.Count -eq 0) {
        throw "No valid tasks to process."
    }

    Write-Host ""
    Write-Host "Monitoring $($processes.Count) task process(es)..." -ForegroundColor Green

    # Process monitoring
    $completed = @()
    $remainingProcesses = $processes.Count
    $failCount = 0

    while ($remainingProcesses -gt 0) {
        Start-Sleep -Seconds 2
        
        foreach ($proc in $processes) {
            # Skip already processed processes
            if ($proc.Processed) { continue }
            
            # Check process termination
            if ($proc.Process.HasExited) {
                $proc.Processed = $true
                $remainingProcesses--
                
                # Check result file (wait a bit before checking)
                Start-Sleep -Milliseconds 1000
                if (Test-Path $proc.ResultFile) {
                    try {
                        $result = (Get-Content $proc.ResultFile -ErrorAction Stop).Trim()
                        if ($result -eq "SUCCESS") {
                            Write-Host "Success: $($proc.Profile)" -ForegroundColor Green
                            $completed += @{ Profile = $proc.Profile; Success = $true }
                        } else {
                            Write-Host "Failed: $($proc.Profile)" -ForegroundColor Red
                            $completed += @{ Profile = $proc.Profile; Success = $false }
                            $failCount++
                        }
                    } catch {
                        Write-Host "Error reading result: $($proc.Profile)" -ForegroundColor Yellow
                        $completed += @{ Profile = $proc.Profile; Success = $false }
                        $failCount++
                    }
                } else {
                    Write-Host "No result file: $($proc.Profile)" -ForegroundColor Yellow
                    $completed += @{ Profile = $proc.Profile; Success = $false }
                    $failCount++
                }
            }
        }
    }

    # Results summary
    Write-Host ""
    Write-Host "Task Summary" -ForegroundColor Yellow
    foreach ($result in $completed) {
        $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
        $statusColor = if ($result.Success) { "Green" } else { "Red" }
        Write-Host "$($result.Profile): $status" -ForegroundColor $statusColor
    }
    
    # Final result determination
    if ($failCount -gt 0) {
        Write-Host ""
        Write-Host "$failCount of $($completed.Count) tasks failed." -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "All tasks completed successfully." -ForegroundColor Green
        exit 0
    }

} catch {
    Write-Host "Fatal Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Script execution aborted." -ForegroundColor Yellow
    exit 1
    
} finally {
    # Cleanup processing
    try {
        # Return to original directory
        Set-Location -Path $originalLocation
        
        # Clean up all temporary files
        if ($allTempFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            Write-Host "Total tracked files: $($allTempFiles.Count)" -ForegroundColor Gray
            $cleanedCount = 0
            $notFoundCount = 0
            foreach ($tempFile in $allTempFiles) {
                if (Test-Path $tempFile) {
                    try {
                        Remove-Item $tempFile -Force -ErrorAction Stop
                        $cleanedCount++
                        Write-Host "  Removed: $(Split-Path -Leaf $tempFile)" -ForegroundColor Gray
                    } catch {
                        Write-Host "  Failed to remove: $(Split-Path -Leaf $tempFile)" -ForegroundColor Yellow
                    }
                } else {
                    $notFoundCount++
                    Write-Host "  Already removed: $(Split-Path -Leaf $tempFile)" -ForegroundColor Gray
                }
            }
            Write-Host "Cleaned up: $cleanedCount files, Already removed: $notFoundCount files" -ForegroundColor Green
        }
    } catch {
        Write-Host "Warning: Cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}