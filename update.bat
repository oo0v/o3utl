@echo off
setlocal
set URL1=https://raw.githubusercontent.com/oo0v/o3utl/refs/heads/main/src/core.ps1
set URL2=https://raw.githubusercontent.com/oo0v/o3utl/refs/heads/main/o3utl.bat
set URL3=https://raw.githubusercontent.com/oo0v/o3utl/refs/heads/main/tasks.ini
set FILE1=src\core.ps1
set FILE2=o3utl.bat
set FILE3=tasks.ini
set MSG_CHECKING=Checking for updates...
set MSG_UPDATED=Updated:
set MSG_SUCCESS=Update completed successfully
set MSG_NO_UPDATE=All files are up to date

echo %MSG_CHECKING%

if not exist "src" mkdir src

powershell -Command "$wc=New-Object System.Net.WebClient;$old1=if(Test-Path '%FILE1%'){Get-FileHash '%FILE1%'|Select -ExpandProperty Hash}else{''};$old2=if(Test-Path '%FILE2%'){Get-FileHash '%FILE2%'|Select -ExpandProperty Hash}else{''};$old3=if(Test-Path '%FILE3%'){Get-FileHash '%FILE3%'|Select -ExpandProperty Hash}else{''};$wc.DownloadFile('%URL1%','temp1.ps1');$wc.DownloadFile('%URL2%','temp2.bat');$wc.DownloadFile('%URL3%','temp3.ini');$new1=Get-FileHash 'temp1.ps1'|Select -ExpandProperty Hash;$new2=Get-FileHash 'temp2.bat'|Select -ExpandProperty Hash;$new3=Get-FileHash 'temp3.ini'|Select -ExpandProperty Hash;$updated=$false;if($old1 -ne $new1){Move-Item 'temp1.ps1' '%FILE1%' -Force;Write-Host '%MSG_UPDATED% %FILE1%';$updated=$true}else{Remove-Item 'temp1.ps1'};if($old2 -ne $new2){Move-Item 'temp2.bat' '%FILE2%' -Force;Write-Host '%MSG_UPDATED% %FILE2%';$updated=$true}else{Remove-Item 'temp2.bat'};if($old3 -ne $new3){Move-Item 'temp3.ini' '%FILE3%' -Force;Write-Host '%MSG_UPDATED% %FILE3%';$updated=$true}else{Remove-Item 'temp3.ini'};if($updated){Write-Host '%MSG_SUCCESS%'}else{Write-Host '%MSG_NO_UPDATE%'}"

endlocal
pause