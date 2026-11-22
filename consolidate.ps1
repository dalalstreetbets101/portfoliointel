# PowerShell script to consolidate JSON results from raw_data with 7-day retention
$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"
$rawDir = "$workDir\raw_data"
$files = Get-ChildItem -Path $rawDir -Filter "*.json"

# Exclude safety duplicates to avoid double counting
$excludeFiles = @("EMS.json", "ORIENTALRAIL.json", "EMBASSY.json")
$files = $files | Where-Object { $excludeFiles -notcontains $_.Name }

$portfolio = @()
$sentimentCounts = @{ "Bullish" = 0; "Bearish" = 0; "Neutral" = 0 }
$totalNews = 0
$cutoffDate = (Get-Date).AddDays(-7).Date

foreach ($file in $files) {
    try {
        $content = Get-Content -Raw -Encoding UTF8 -Path $file.FullName -ErrorAction Stop
        $data = ConvertFrom-Json -InputObject $content -ErrorAction Stop
        
        $ticker = $data.ticker
        $name = $data.company_name
        
        # Enforce 7-day filter
        $validDevs = @()
        if ($data.developments) {
            foreach ($d in $data.developments) {
                if ($d.date) {
                    try {
                        $dDate = [DateTime]$d.date
                        if ($dDate.Date -ge $cutoffDate) {
                            $validDevs += $d
                        }
                    } catch {}
                }
            }
        }
        
        $developments = $validDevs
        $newsFound = ($developments.Count -gt 0)
        $newsCount = $developments.Count
        $totalNews += $newsCount
        
        # Determine overall sentiment and risk level
        $sentiment = "Neutral"
        $riskLevel = "Low"
        $keyDev = "No major developments in the last 7 days."
        
        if ($newsCount -gt 0) {
            $sortedDevs = $developments | Sort-Object -Property importance_score -Descending
            $mainDev = $sortedDevs[0]
            $sentiment = $mainDev.sentiment
            $keyDev = $mainDev.headline
            
            $hasRedFlags = $developments | Where-Object { $_.red_flags -ne "" -and $_.red_flags -ne "None" -and $_.red_flags -ne $null }
            if ($hasRedFlags) {
                $riskLevel = "High"
            } elseif ($sentiment -eq "Bearish") {
                $riskLevel = "Medium"
            } else {
                $riskLevel = "Low"
            }
        }
        
        if ($newsCount -gt 0) {
            $sentimentCounts[$sentiment]++
        } else {
            $sentimentCounts["Neutral"]++
        }
        
        $ltp = if ($data.ltp) { $data.ltp } else { 0 }
        $changeP = if ($data.change_percent) { $data.change_percent } else { 0 }
        $portfolio += [PSCustomObject]@{
            Ticker = $ticker
            Name = $name
            LTP = $ltp
            ChangeP = $changeP
            NewsCount = $newsCount
            Sentiment = $sentiment
            RiskLevel = $riskLevel
            KeyDevelopment = $keyDev
        }
    } catch {
        Write-Error "Error processing file $($file.Name): $_"
    }
}

Write-Host "========================================"
Write-Host "AGGREGATE SUMMARY (LAST 7 DAYS RETENTION)"
Write-Host "========================================"
Write-Host "Total Stocks Processed: $($portfolio.Count)"
Write-Host "Total Active News Items (<= 7 Days): $totalNews"
Write-Host "Sentiment Breakdown: Bullish=$($sentimentCounts['Bullish']), Bearish=$($sentimentCounts['Bearish']), Neutral=$($sentimentCounts['Neutral'])"
Write-Host "========================================"

Write-Host ""
Write-Host "Markdown Table for Dashboard:"
Write-Host ""
Write-Host "| Stock | LTP (₹) | Day Change | News (7D) | Sentiment | Risk Level | Key Development |"
Write-Host "| :--- | :---: | :---: | :---: | :---: | :---: | :--- |"
foreach ($stock in $portfolio) {
    $changeSign = if ($stock.ChangeP -ge 0) { "+$($stock.ChangeP)%" } else { "$($stock.ChangeP)%" }
    Write-Host "| $($stock.Ticker) ($($stock.Name)) | ₹$($stock.LTP) | $changeSign | $($stock.NewsCount) | $($stock.Sentiment) | $($stock.RiskLevel) | $($stock.KeyDevelopment) |"
}
