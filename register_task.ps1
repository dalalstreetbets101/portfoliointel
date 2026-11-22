$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"
$scriptPath = "$workDir\run_direct_scan.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At "18:00"
Register-ScheduledTask -TaskName "Direct Daily Stock Scan" -Action $action -Trigger $trigger -Force
Write-Host "Direct Daily Stock Scan Task registered successfully for 6:00 PM IST daily."

