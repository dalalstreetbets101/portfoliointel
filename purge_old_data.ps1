# PowerShell script to purge news developments older than 7 days (1 week)
param (
    [int]$DaysToKeep = 7
)

$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"
$rawDir = "$workDir\raw_data"
$cutoffDate = (Get-Date).AddDays(-$DaysToKeep).Date

Write-Host "=================================================="
Write-Host "DATA RETENTION PURGE: KEEPING LAST $DaysToKeep DAYS"
Write-Host "Current Date: $((Get-Date).ToString('yyyy-MM-dd'))"
Write-Host "Cutoff Date:  $($cutoffDate.ToString('yyyy-MM-dd'))"
Write-Host "=================================================="

$files = Get-ChildItem -Path $rawDir -Filter "*.json"
$totalBefore = 0
$totalPurged = 0
$totalRemaining = 0
$modifiedFiles = 0

foreach ($file in $files) {
    try {
        $content = Get-Content -Raw -Encoding UTF8 -Path $file.FullName -ErrorAction Stop
        $data = ConvertFrom-Json -InputObject $content -ErrorAction Stop
        
        $devs = $data.developments
        if ($devs) {
            $initialCount = $devs.Count
            $totalBefore += $initialCount
            
            $validDevs = @()
            foreach ($d in $devs) {
                $isValid = $false
                if ($d.date) {
                    try {
                        $dDate = [DateTime]$d.date
                        if ($dDate.Date -ge $cutoffDate) {
                            $isValid = $true
                        }
                    } catch {
                        $isValid = $false
                    }
                }
                
                if ($isValid) {
                    $validDevs += $d
                }
            }
            
            $purgedForThisFile = $initialCount - $validDevs.Count
            $totalPurged += $purgedForThisFile
            $totalRemaining += $validDevs.Count
            
            if ($purgedForThisFile -gt 0) {
                $data.developments = $validDevs
                $data.news_found = ($validDevs.Count -gt 0)
                
                # Write back updated pretty-printed JSON
                $updatedJson = ConvertTo-Json -InputObject $data -Depth 20
                [System.IO.File]::WriteAllText($file.FullName, $updatedJson, [System.Text.Encoding]::UTF8)
                $modifiedFiles++
                Write-Host "  Purged $purgedForThisFile old development(s) from $($file.Name) (Remaining: $($validDevs.Count))"
            }
        }
    } catch {
        Write-Warning "Error processing $($file.Name): $_"
    }
}

Write-Host "=================================================="
Write-Host "PURGE COMPLETE:"
Write-Host "  Total developments before purge: $totalBefore"
Write-Host "  Developments purged (> 7 days):  $totalPurged"
Write-Host "  Developments retained:           $totalRemaining"
Write-Host "  Files updated:                   $modifiedFiles"
Write-Host "=================================================="
