# System Health Status Check for Portfolio Scanner
$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"

$task1 = Get-ScheduledTask -TaskName "Direct Daily Stock Scan" -ErrorAction SilentlyContinue
$task1State = if ($task1) { $task1.State.ToString() } else { "Not Found" }

$task2 = Get-ScheduledTask -TaskName "Start Antigravity" -ErrorAction SilentlyContinue
$task2State = if ($task2) { $task2.State.ToString() } else { "Not Found" }

$rawFiles = Get-ChildItem -Path "$workDir\raw_data" -Filter "*.json"
$latestFile = $rawFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$latestTime = if ($latestFile) { $latestFile.LastWriteTime } else { [DateTime]::MinValue }
$latestTimeStr = if ($latestFile) { $latestTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }

$diffHours = if ($latestFile) { [Math]::Round(((Get-Date) - $latestTime).TotalHours, 1) } else { 999.0 }

$status = "Healthy"
$msg = "System is fully operational."

if ($diffHours -gt 24) {
    $status = "Out of Date"
    $msg = "Warning: Stock updates have not been fetched for over 24 hours. The scheduler or subagents may have missed a run."
}

$validStates = @("Ready", "Running")
if ($task1State -notin $validStates -or $task2State -notin $validStates) {
    $status = "Scheduler Offline"
    $msg = "Warning: Windows Scheduled Tasks are not in the Ready/Running state. Check task registrations."
}

$healthJson = @{
    status = $status
    message = $msg
    lastRun = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    lastResearchUpdate = $latestTimeStr
    rawFilesAgeHours = $diffHours
    schedulerDirectState = $task1State
    schedulerAppState = $task2State
} | ConvertTo-Json

$jsContent = "const systemHealth = $healthJson;"
[System.IO.File]::WriteAllText("$workDir\health_status.js", $jsContent, [System.Text.Encoding]::UTF8)

# Write to brain folder for active sync
$convoIds = @("7d24896f-fe79-4442-a3b4-217aa1943168", "53a3e2ce-a939-46e5-84ad-5426bc22425a", "1bbf1935-b256-4864-8246-a97851b388e8", "f88ef155-0a4c-43c0-8923-e00a472376aa")
foreach ($id in $convoIds) {
    $artParent = "C:\Users\mohdu\.gemini\antigravity\brain\$id"
    if (Test-Path -Path $artParent) {
        [System.IO.File]::WriteAllText("$artParent\health_status.js", $jsContent, [System.Text.Encoding]::UTF8)
    }
}

Write-Host "System Health status updated successfully: Status=$status, rawFilesAgeHours=$diffHours"
