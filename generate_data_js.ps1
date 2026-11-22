# PowerShell script to generate data.js from raw_data JSON files with 7-Day Retention Window
$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"
$rawDir = "$workDir\raw_data"

# Step 1: Automatically purge any developments older than 7 days from raw_data files
$purgeScript = "$workDir\purge_old_data.ps1"
if (Test-Path -Path $purgeScript) {
    & powershell -ExecutionPolicy Bypass -File $purgeScript -DaysToKeep 7 | Out-Null
}

$files = Get-ChildItem -Path $rawDir -Filter "*.json"

# Exclude safety duplicates to avoid double counting
$excludeFiles = @("EMS.json", "ORIENTALRAIL.json", "EMBASSY.json")
$files = $files | Where-Object { $excludeFiles -notcontains $_.Name }

$jsonDataList = @()
$cutoffDate = (Get-Date).AddDays(-7).Date

foreach ($file in $files) {
    try {
        $content = Get-Content -Raw -Encoding UTF8 -Path $file.FullName -ErrorAction Stop
        $data = ConvertFrom-Json -InputObject $content -ErrorAction Stop
        
        $ticker = $data.ticker
        $name = $data.company_name
        
        # Enforce 7-day retention filter on developments
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
        
        # Calculate sentiment and risk level
        $sentiment = "Neutral"
        $riskLevel = "Low"
        $actionRequired = "Hold/Monitor"
        
        # Base status for known structural monitoring tickers
        if ($ticker -eq "NSE:VPRPL") {
            $riskLevel = "High"
            $sentiment = if ($newsFound) { "Neutral" } else { "Neutral" }
            $actionRequired = "Immediate Review / Sell"
        } elseif ($ticker -eq "BSE:522231" -or $ticker -eq "NSE:CONART") {
            $riskLevel = "High"
            $actionRequired = "Query management on SEBI compliance"
        }
        
        if ($newsFound -and $developments.Count -gt 0) {
            $sortedDevs = $developments | Sort-Object -Property importance_score -Descending
            $mainDev = $sortedDevs[0]
            $sentiment = $mainDev.sentiment
            
            $hasRedFlags = $developments | Where-Object { $_.red_flags -ne "" -and $_.red_flags -ne "None" -and $_.red_flags -ne $null }
            if ($hasRedFlags -and ($ticker -eq "NSE:VPRPL" -or $ticker -eq "NSE:ORIENTTECH" -or $ticker -eq "BSE:522231" -or $ticker -eq "NSE:CONART")) {
                $riskLevel = "High"
            } elseif ($sentiment -eq "Bearish" -or $hasRedFlags) {
                $riskLevel = "Medium"
            } else {
                $riskLevel = "Low"
            }
        }
        
        if ($sentiment -eq "Bullish" -and $riskLevel -eq "Low") {
            $actionRequired = "Accumulate on dips"
        } elseif ($sentiment -eq "Bullish" -and $riskLevel -eq "Medium") {
            $actionRequired = "Hold / Buy on milestones"
        }
        
        # Sector grouping
        $sector = "Others"
        if ($ticker -in @("NSE:BBOX", "NSE:BSOFT", "NSE:DCI", "NSE:ORIENTTECH", "NSE:ADCINDIA", "NSE:RAILTEL", "NSE:TATATECH")) {
            $sector = "IT & Telecom"
        } elseif ($ticker -in @("NSE:BCPL", "NSE:CEIGALL", "NSE:EMSLIMITED", "NSE:IRCON", "NSE:LIKHITHA", "NSE:ORIENTLTD", "NSE:TITAGARH", "NSE:VPRPL", "BSE:522231", "NSE:CONART", "NSE:EMBDL")) {
            $sector = "Infra & Railways"
        } elseif ($ticker -in @("NSE:IREDA", "NSE:SKIPPER", "NSE:TATAPOWER", "NSE:TEMBO", "NSE:WAAREERTL", "NSE:OLECTRA", "NSE:NHPC", "NSE:SWSOLAR", "NSE:SJVN")) {
            $sector = "Power & Renewables"
        } elseif ($ticker -in @("NSE:JIOFIN", "NSE:POONAWALLA", "NSE:HUDCO", "NSE:CDSL", "NSE:BSE")) {
            $sector = "Financials"
        } elseif ($ticker -in @("NSE:RELIANCE", "NSE:IOC", "NSE:ITC", "NSE:TATAMOTORS", "NSE:WELSPUNLIV", "NSE:PNGJL", "NSE:PPL")) {
            $sector = "Auto, FMCG & Energy"
        }
        
        # Create a clean PSCustomObject
        $stockObj = [PSCustomObject]@{
            ticker = $ticker
            name = $name
            sector = $sector
            ltp = if ($data.ltp) { $data.ltp } else { 0 }
            change = if ($data.change) { $data.change } else { 0 }
            change_percent = if ($data.change_percent) { $data.change_percent } else { 0 }
            prev_close = if ($data.prev_close) { $data.prev_close } else { 0 }
            fifty_two_week_high = if ($data.fifty_two_week_high) { $data.fifty_two_week_high } else { 0 }
            fifty_two_week_low = if ($data.fifty_two_week_low) { $data.fifty_two_week_low } else { 0 }
            news_found = $newsFound
            sentiment = $sentiment
            risk_level = $riskLevel
            action_required = $actionRequired
            developments = $developments
            canvas_categories = $data.canvas_categories
        }
        $jsonDataList += $stockObj
    } catch {
        Write-Error "Error processing $($file.Name): $_"
    }
}

# Convert to JSON string
$finalJson = ConvertTo-Json -InputObject $jsonDataList -Depth 100 -Compress
$todayStr = (Get-Date).ToString("MMMM dd, yyyy")
$jsContent = "const lastRefreshed = `"$todayStr`";`nconst stockData = $finalJson;"

# Write to file
$targetPath = "$workDir\data.js"
[System.IO.File]::WriteAllText($targetPath, $jsContent, [System.Text.Encoding]::UTF8)

$convoIds = @("7d24896f-fe79-4442-a3b4-217aa1943168", "53a3e2ce-a939-46e5-84ad-5426bc22425a", "1bbf1935-b256-4864-8246-a97851b388e8", "f88ef155-0a4c-43c0-8923-e00a472376aa")
foreach ($id in $convoIds) {
    $artPath = "C:\Users\mohdu\.gemini\antigravity\brain\$id\data.js"
    $artParent = Split-Path -Path $artPath -Parent
    if (Test-Path -Path $artParent) {
        [System.IO.File]::WriteAllText($artPath, $jsContent, [System.Text.Encoding]::UTF8)
    }
}

Write-Host "Generated data.js with $($jsonDataList.Count) stocks at: $targetPath (Filtered to 7-Day Retention)"
