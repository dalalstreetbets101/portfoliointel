# Direct Independent Daily Stock Update Runner
$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"
Set-Location $workDir

$logFile = "$workDir\task_run.log"
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
Add-Content -Path $logFile -Value "[$timestamp] Triggering Daily Stock Research Scan via native CLI..."

# Purge developments older than 7 days
try {
    if (Test-Path "$workDir\purge_old_data.ps1") {
        & powershell -ExecutionPolicy Bypass -File "$workDir\purge_old_data.ps1" -DaysToKeep 7 | Out-Null
        Add-Content -Path $logFile -Value "[$timestamp] Purged developments older than 7 days from raw_data."
    }
} catch {
    Add-Content -Path $logFile -Value "[$timestamp] Warning during data purge: $_"
}

# Cleanup previous automated scan conversations to prevent UI clutter
try {
    $brainDir = "C:\Users\mohdu\.gemini\antigravity\brain"
    if (Test-Path $brainDir) {
        $subDirs = Get-ChildItem -Path $brainDir -Directory
        $cleanedCount = 0
        foreach ($dir in $subDirs) {
            $transcriptPath = Join-Path $dir.FullName ".system_generated\logs\transcript.jsonl"
            if (Test-Path $transcriptPath) {
                $firstLine = Get-Content -Path $transcriptPath -TotalCount 1
                if ($firstLine -match "Run Todays Scan" -or $firstLine -match "Research developments for the last 24-48 hours") {
                    Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    $cleanedCount++
                }
            }
        }
        Add-Content -Path $logFile -Value "[$timestamp] Cleaned up $cleanedCount old daily scan chats from the brain directory."
    }
} catch {
    Add-Content -Path $logFile -Value "[$timestamp] Warning during conversation cleanup: $_"
}

try {
    # Step 1: Run deterministic live market data & verified news engine
    Add-Content -Path $logFile -Value "[$timestamp] Running fetch_live_data.js (Yahoo Finance quotes + Google News verified feeds)..."
    & node "$workDir\scripts\fetch_live_data.js" | Out-Null
    
    # Step 2: Compile data.js, report, consolidate, and update health status
    & powershell -ExecutionPolicy Bypass -File "$workDir\generate_data_js.ps1" | Out-Null
    & powershell -ExecutionPolicy Bypass -File "$workDir\generate_report.ps1" | Out-Null
    & powershell -ExecutionPolicy Bypass -File "$workDir\consolidate.ps1" | Out-Null
    & powershell -ExecutionPolicy Bypass -File "$workDir\check_health.ps1" | Out-Null

    $endTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $logFile -Value "[$endTimestamp] Live scan and compilation completed successfully."
} catch {
    $errTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $logFile -Value "[$errTimestamp] ERROR: $_"
}

