param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [string]$Profile = ""
)

# Error action setting
$ErrorActionPreference = "Stop"

# Record original location and temporary files
$originalLocation = Get-Location
$allTempFiles = @()

try {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    # Input file validation
    if (-not (Test-Path $InputFile -PathType Leaf)) {
        throw "Input file not found: $InputFile"
    }

    # Convert to absolute path
    $InputFile = Resolve-Path $InputFile

    # Load tasks.ini
    $ConfigFile = Join-Path $ScriptDir "..\tasks.ini"
    if (-not (Test-Path $ConfigFile -PathType Leaf)) {
        throw "tasks.ini not found at: $ConfigFile"
    }

    # Set working directory to tasks.ini directory
    $WorkingDir = Split-Path -Parent (Resolve-Path $ConfigFile)
    Set-Location $WorkingDir

    # INI parsing function
    function Read-ConfigurationFile {
        param([string]$FilePath)
        
        $Configuration = [ordered]@{}
        $CurrentSection = ""
        
        try {
            $content = Get-Content $FilePath -Encoding UTF8 -ErrorAction Stop
            
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

    # Profile validation function
    function Test-ProfileConfiguration {
        param(
            [System.Collections.Specialized.OrderedDictionary]$Configuration,
            [array]$ProfileNames
        )
        
        $validatedProfiles = @()
        
        foreach ($profileName in $ProfileNames) {
            if (-not $Configuration.Contains($profileName)) {
                Write-Host "Error: Profile '$profileName' not found" -ForegroundColor Red
                continue
            }
            
            $command = $Configuration[$profileName]["cmd"]
            if ([string]::IsNullOrWhiteSpace($command)) {
                Write-Host "Error: No cmd in task '$profileName'" -ForegroundColor Red
                continue
            }
            
            # Check for {INPUT} placeholder existence
            if ($command -notmatch '\{INPUT\}') {
                Write-Host "Warning: Task '$profileName' does not contain {INPUT} placeholder" -ForegroundColor Yellow
            }
            
            Write-Host "Task validated: '$profileName'" -ForegroundColor Green
            $validatedProfiles += @{
                Profile = $profileName
                Command = $command
            }
        }
        
        return $validatedProfiles
    }

    $validProfiles = Test-ProfileConfiguration -Configuration $Config -ProfileNames $selectedProfiles

    if ($validProfiles.Count -eq 0) {
        throw "No valid tasks to process."
    }

    # Command line generation function
    function New-SafeCommandLine {
        param(
            [string]$CommandTemplate,
            [string]$InputPath
        )
        
        # Escape input file path
        $escapedInput = $InputPath -replace '"', '""'
        
        # Expand environment variables and replace {INPUT}
        $expandedCommand = [System.Environment]::ExpandEnvironmentVariables($CommandTemplate)
        $finalCommand = $expandedCommand -replace '\{INPUT\}', "`"$escapedInput`""
        
        return $finalCommand
    }

    # Unique task ID generation function
    function New-UniqueTaskIdentifier {
        return "task_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    }

    # Process execution function
    function Invoke-Process {
        param(
            [string]$Command,
            [string]$WorkingDirectory
        )
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "cmd.exe"
        $processInfo.Arguments = "/c `"$Command`""
        $processInfo.WorkingDirectory = $WorkingDirectory
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $false
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        if (-not $process.Start()) {
            throw "Failed to start process"
        }
        
        $process.WaitForExit()
        
        if ($process.ExitCode -ne 0) {
            throw "Process failed with exit code $($process.ExitCode)"
        }
    }

    # Execute sequentially for each profile
    Write-Host ""
    Write-Host "Starting $($validProfiles.Count) task(s)..." -ForegroundColor Green

    $completionResults = @()
    $failureCount = 0

    foreach ($profileInfo in $validProfiles) {
        $profileName = $profileInfo.Profile
        $commandTemplate = $profileInfo.Command
        
        $taskIdentifier = New-UniqueTaskIdentifier
        $fullCommand = New-SafeCommandLine -CommandTemplate $commandTemplate -InputPath $InputFile
        
        # 2-pass log file processing
        $tempDirectory = [System.IO.Path]::GetTempPath()
        $passLogFile = $null
        
        if ($fullCommand -match "-pass\s+[12]") {
            $passLogFile = Join-Path $tempDirectory "2pass_${taskIdentifier}"
            
            # Add -passlogfile option to both Pass 1 and Pass 2
            $fullCommand = $fullCommand -replace "(-pass\s+1)", "-passlogfile `"$passLogFile`" `$1"
            $fullCommand = $fullCommand -replace "(&.*?-pass\s+2)", "`$1 -passlogfile `"$passLogFile`""
            
            # Track log files for cleanup
            $script:allTempFiles += "${passLogFile}-0.log"
            $script:allTempFiles += "${passLogFile}-0.log.mbtree"
        }
        
        Write-Host ""
        Write-Host "Processing: $profileName" -ForegroundColor Yellow
        Write-Host "$fullCommand" -ForegroundColor Gray
        
        try {
            if ($fullCommand -match " && ") {
                # 2-pass processing
                $commandParts = $fullCommand -split ' && ', 2
                $firstPassCommand = $commandParts[0].Trim()
                $secondPassCommand = $commandParts[1].Trim()
                
                Write-Host "Starting Pass 1..." -ForegroundColor Cyan
                Invoke-Process -Command $firstPassCommand -WorkingDirectory $WorkingDir
                
                Write-Host "Pass 1 completed. Starting Pass 2..." -ForegroundColor Cyan
                Invoke-Process -Command $secondPassCommand -WorkingDirectory $WorkingDir
            } else {
                # Single-pass processing
                Write-Host "Starting task..." -ForegroundColor Cyan
                Invoke-Process -Command $fullCommand -WorkingDirectory $WorkingDir
            }
            
            Write-Host "Success: $profileName" -ForegroundColor Green
            $completionResults += @{ Profile = $profileName; Success = $true }
            
        } catch {
            Write-Host "Failed: $profileName" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            $completionResults += @{ Profile = $profileName; Success = $false; Error = $_.Exception.Message }
            $failureCount++
        }
    }

    # Results
    Write-Host ""
    Write-Host "Task Summary" -ForegroundColor Yellow
    foreach ($result in $completionResults) {
        $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
        $statusColor = if ($result.Success) { "Green" } else { "Red" }
        Write-Host "$($result.Profile): $status" -ForegroundColor $statusColor
        if (-not $result.Success -and $result.Error) {
            Write-Host "  Error: $($result.Error)" -ForegroundColor Yellow
        }
    }
    
    # Final result determination
    if ($failureCount -gt 0) {
        Write-Host ""
        Write-Host "$failureCount of $($completionResults.Count) tasks failed." -ForegroundColor Red
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
        Set-Location $originalLocation
        
        # Delete temporary files
        if ($allTempFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            $cleanedFileCount = 0
            foreach ($tempFile in $allTempFiles) {
                if (Test-Path $tempFile) {
                    try {
                        Remove-Item $tempFile -Force -ErrorAction Stop
                        $cleanedFileCount++
                    } catch {
                        Write-Host "Warning: Could not remove $tempFile" -ForegroundColor Yellow
                    }
                }
            }
            if ($cleanedFileCount -gt 0) {
                Write-Host "Cleaned up $cleanedFileCount temporary files" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "Warning: Cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}