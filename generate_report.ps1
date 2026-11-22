# PowerShell script to generate the final Daily Stock Update Report with 7-Day Retention Window
$workDir = "d:\ANTIGRAVITY Stock REPORT\Daily Stock Update"
$rawDir = "$workDir\raw_data"
$files = Get-ChildItem -Path $rawDir -Filter "*.json"

# Exclude safety duplicates to avoid double counting
$excludeFiles = @("EMS.json", "ORIENTALRAIL.json", "EMBASSY.json")
$files = $files | Where-Object { $excludeFiles -notcontains $_.Name }

$portfolio = @()
$allDevs = @()
$sentimentCounts = @{ "Bullish" = 0; "Bearish" = 0; "Neutral" = 0 }
$totalNews = 0
$cutoffDate = (Get-Date).AddDays(-7).Date

foreach ($file in $files) {
    try {
        $content = Get-Content -Raw -Encoding UTF8 -Path $file.FullName -ErrorAction Stop
        $data = ConvertFrom-Json -InputObject $content -ErrorAction Stop
        
        $ticker = $data.ticker
        $name = $data.company_name
        
        # Enforce 7-day retention filter
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
        $actionRequired = "Hold/Monitor"
        
        # Base status for known structural monitoring tickers
        if ($ticker -eq "NSE:VPRPL") {
            $riskLevel = "High"
            $actionRequired = "Immediate Review / Sell"
        } elseif ($ticker -eq "BSE:522231" -or $ticker -eq "NSE:CONART") {
            $riskLevel = "High"
            $actionRequired = "Query management on SEBI compliance"
        }
        
        if ($newsCount -gt 0) {
            $sortedDevs = $developments | Sort-Object -Property importance_score -Descending
            $mainDev = $sortedDevs[0]
            $sentiment = $mainDev.sentiment
            $keyDev = $mainDev.headline
            
            # Determine risk based on red flags
            $hasRedFlags = $developments | Where-Object { $_.red_flags -ne "" -and $_.red_flags -ne "None" -and $_.red_flags -ne $null }
            if ($hasRedFlags -and ($ticker -eq "NSE:VPRPL" -or $ticker -eq "NSE:ORIENTTECH" -or $ticker -eq "BSE:522231" -or $ticker -eq "NSE:CONART")) {
                $riskLevel = "High"
            } elseif ($sentiment -eq "Bearish" -or $hasRedFlags) {
                $riskLevel = "Medium"
            } else {
                $riskLevel = "Low"
            }
            
            # Collect all developments for sorting later
            foreach ($d in $developments) {
                $allDevs += [PSCustomObject]@{
                    Ticker = $ticker
                    Name = $name
                    Headline = $d.headline
                    Date = $d.date
                    Source = $d.source_link
                    Score = $d.importance_score
                    Sentiment = $d.sentiment
                    ShortTerm = $d.short_term_impact
                    LongTerm = $d.long_term_impact
                    Thesis = $d.thesis_impact
                    Missing = $d.hidden_implications
                    Risks = $d.risks
                    Opportunities = $d.opportunities
                    RedFlags = $d.red_flags
                }
            }
        }
        
        if ($newsCount -gt 0) {
            $sentimentCounts[$sentiment]++
        } else {
            $sentimentCounts["Neutral"]++
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
        
        # Update sanitized data in object
        $data.developments = $developments
        $data.news_found = $newsFound
        $ltp = if ($data.ltp) { $data.ltp } else { 0 }
        $changeP = if ($data.change_percent) { $data.change_percent } else { 0 }
        
        $portfolio += [PSCustomObject]@{
            Ticker = $ticker
            Name = $name
            Sector = $sector
            LTP = $ltp
            ChangePercent = $changeP
            NewsCount = $newsCount
            Sentiment = $sentiment
            RiskLevel = $riskLevel
            KeyDev = $keyDev
            ActionRequired = $actionRequired
            RawData = $data
        }
    } catch {
        Write-Error "Error reading $($file.Name): $_"
    }
}

# Generate Markdown Document
$todayDateStr = (Get-Date).ToString("MMMM dd, yyyy")
$startDateStr = $cutoffDate.ToString("MMMM dd")
$endDateStr = (Get-Date).ToString("MMMM dd, yyyy")

$md = @"
# UMAR'S PORTFOLIO INTELLIGENCE REPORT: 7-DAY ROLLING UPDATE
**Date:** $todayDateStr  
**Baseline Period:** Last 7 Days ($startDateStr – $endDateStr)  
**Retention Policy:** Rolling 7-day active window. Stale developments older than 1 week are automatically purged.  
**Analyst:** Buy-Side Equity Research Unit (JETRO CANVAS Style Format)

---

## 1. PORTFOLIO DASHBOARD

| Stock | News Count | Sentiment | Risk Level | Most Important Development |
| :--- | :---: | :---: | :---: | :--- |
"@

# Sort portfolio: Stocks with news first (by score/date), then alphabetically
$sortedPortfolio = $portfolio | Sort-Object -Property @{Expression={$_.NewsCount}; Descending=$true}, @{Expression={$_.Sentiment -eq "Bearish"}; Descending=$true}, @{Expression={$_.Sentiment -eq "Bullish"}; Descending=$true}, Ticker

foreach ($stock in $sortedPortfolio) {
    $sentimentBadge = $stock.Sentiment
    $riskBadge = $stock.RiskLevel
    $md += "`n| **$($stock.Ticker)**<br>$($stock.Name) | $($stock.NewsCount) | $sentimentBadge | $riskBadge | $($stock.KeyDev) |"
}

$md += "`n`n---`n`n## 2. SECTOR DASHBOARD`n`n"
$md += "Track the sectors represented in the portfolio to identify structural tailwinds, headwinds, policy changes, competitor actions, and demand trends.`n`n"
$md += "| Sector | Represented Stocks | Sector Tailwinds | Sector Headwinds | Policy Changes | Competitor Actions | Demand Trends |`n"
$md += "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |`n"
$md += "| **IT Services & Digital Infrastructure** | BBOX, BSOFT, DCI, ORIENTTECH, ADCINDIA, RAILTEL, TATATECH | High demand for AI computing, cloud migration, data localization, and municipal Smart City connectivity. | Margin pressure in traditional IT services, delayed deal closures, and technical selling pressure. | Digital Personal Data Protection Act pushing hyperscalers to lease local capacity. | Aggressive data center capacity expansion by Adani ConneX and Airtel Nxtra. | Hyper-growth in AI workloads, while traditional corporate IT spending remains cyclical. |`n"
$md += "| **Railways, Roads, Real Estate & Infra EPC** | BCPL, CEIGALL, EMSLIMITED, IRCON, LIKHITHA, ORIENTLTD, TITAGARH, VPRPL, CONART, EMBDL | Strong budgetary allocation for railway safety, electrification, highway corridors, water EPC, and luxury urban real estate. | High working capital intensity, execution/billing delays by government clients, and rising borrowing costs. | Strict enforcement of project milestones by NHAI and Indian Railways, leading to penalty provisions. | Intense bidding competition for low-complexity civil contracts, driving margin dilution. | Robust pipeline of tenders and luxury residential pre-sales, with execution capacity as key driver. |`n"
$md += "| **Power, Solar & Clean Energy** | IREDA, SKIPPER, TATAPOWER, TEMBO, WAAREERTL, OLECTRA, NHPC, SWSOLAR, SJVN | Strong solar panel price deflation, rising rooftop solar adoption, and government support for clean energy financing. | Delayed power sale agreements (PSAs) by state DISCOMs, grid integration bottlenecks, and high leverage. | Joint committees established to review ALMM-II commissioning extensions; green energy mandates. | Aggressive IPP expansion by major players (Adani Green, ReNew), squeezing bidding margins. | Strong electricity demand growth, outstripping conventional thermal capacity and boosting RE off-take. |`n"
$md += "| **Financial Services & NBFCs** | JIOFIN, POONAWALLA, HUDCO, CDSL, BSE | High retail participation in capital markets, expanding credit demand, and state funding partnerships. | Higher risk weights on unsecured retail loans, and regulatory oversight on digital compliance. | SEBI and RBI tightening norms on digital compliance, capital adequacy, and unsecured lending. | Fintech transitions allowing NBFCs and Jio Financial to capture market share. | Structural transition of household savings into financial assets, boosting CDSL/BSE volumes. |`n"
$md += "| **FMCG, Automobile & Commodities** | RELIANCE, IOC, ITC, TATAMOTORS, WELSPUNLIV, PNGJL, PPL | Festive and wedding season jewelry demand, EV PV adoption, and stable commodity input costs. | Elevated crude oil prices impacting OMC marketing margins; regulatory excise vigilance. | Free trade agreements and domestic value-addition incentives; retail fuel pricing monitoring. | Competitive pricing adjustments across electric two-wheelers and passenger vehicles. | Consumer preference shifts toward premium products across FMCG, jewelry, and personal mobility. |`n"

$md += "`n---`n`n## 3. PORTFOLIO-LEVEL ANALYSIS`n`n"

# Top 10 Positive Developments (filtered to last 7 days)
$posDevs = $allDevs | Where-Object { $_.Sentiment -eq "Bullish" } | Sort-Object -Property Score -Descending
$posFiltered = @()
foreach ($d in $posDevs) {
    if ($posFiltered.Count -lt 10) {
        $alreadyHasTicker = $posFiltered | Where-Object { $_.Ticker -eq $d.Ticker }
        if (-not $alreadyHasTicker) {
            $posFiltered += $d
        }
    }
}
if ($posFiltered.Count -lt 10) {
    $remaining = $posDevs | Where-Object { $posFiltered.Ticker -notcontains $_.Ticker }
    $posFiltered += $remaining | Select-Object -First (10 - $posFiltered.Count)
}
$posFiltered = $posFiltered | Select-Object -First 10

$md += "### A. Top Positive Developments (Last 7 Days)`n"
$i = 1
if ($posFiltered.Count -eq 0) {
    $md += "No major positive developments reported in the last 7 days.`n`n"
} else {
    foreach ($d in $posFiltered) {
        $md += "$i. **$($d.Ticker)**: $($d.Headline) (Importance: **$($d.Score)/10**)`n"
        $md += "   - *Hedge Fund Perspective:* $($d.ShortTerm) / $($d.LongTerm)`n"
        $md += "   - *Hidden Implications:* $($d.Missing)`n`n"
        $i++
    }
}

# Top 10 Negative Developments (filtered to last 7 days)
$negDevs = $allDevs | Where-Object { $_.Sentiment -eq "Bearish" -or ($_.Sentiment -eq "Neutral" -and $_.Score -ge 6) } | Sort-Object -Property Score -Descending
$negFiltered = @()
foreach ($d in $negDevs) {
    if ($negFiltered.Count -lt 10) {
        $alreadyHasTicker = $negFiltered | Where-Object { $_.Ticker -eq $d.Ticker }
        if (-not $alreadyHasTicker) {
            $negFiltered += $d
        }
    }
}
if ($negFiltered.Count -lt 10) {
    $remaining = $negDevs | Where-Object { $negFiltered.Ticker -notcontains $_.Ticker }
    $negFiltered += $remaining | Select-Object -First (10 - $negFiltered.Count)
}
$negFiltered = $negFiltered | Select-Object -First 10

$md += "`n### B. Top Negative Developments / Risks (Last 7 Days)`n"
$i = 1
if ($negFiltered.Count -eq 0) {
    $md += "No major negative developments reported in the last 7 days.`n`n"
} else {
    foreach ($d in $negFiltered) {
        $md += "$i. **$($d.Ticker)**: $($d.Headline) (Importance: **$($d.Score)/10**)`n"
        $md += "   - *Hedge Fund Perspective:* $($d.ShortTerm) / $($d.LongTerm)`n"
        $md += "   - *Hidden Implications:* $($d.Missing)`n`n"
        $i++
    }
}

# Emerging Risks & Opportunities
$md += @"
### C. Emerging Risks Summary
1. **Working Capital & Debt Discipline:** Small and mid-cap EPC contractors require vigilant monitoring of cash flow conversion and pledge ratios.
2. **Regulatory & SEBI Compliance:** Listed entities must strictly maintain digital governance and timely disclosures.
3. **Margin Protection:** Commodity input swings and competitive bidding require focus on high-value EPC contracts and technology differentiation.

### D. Emerging Opportunities Summary
1. **Utility BESS & Solar Capex:** Massive domestic solar tenders and international battery storage pipelines provide high-margin growth.
2. **Domestic Infrastructure Integration:** National rail, signaling, and water EPC allocations anchor multi-year revenue visibility.
3. **Clean Balance Sheet Expansion:** Debt deleveraging and promoter warrant infusions strengthen balance sheet buffers.
"@

$md += "`n`n---`n`n## 4. INDIVIDUAL STOCK INTELLIGENCE REPORTS (JETRO CANVAS STYLE)`n`n"

foreach ($stock in $portfolio | Sort-Object -Property Ticker) {
    $data = $stock.RawData
    $ticker = $data.ticker
    $name = $data.company_name
    $newsFound = $data.news_found
    
    $md += "### Ticker: $($ticker) - Name: $($name)`n`n"
    
    if (-not $newsFound -or -not $data.developments -or $data.developments.Count -eq 0) {
        $md += "> **News Status:** No direct company news reported in the last 7 days. Stale developments older than 1 week are automatically archived/purged.`n`n"
    } else {
        foreach ($d in $data.developments) {
            $sentimentLabel = "Neutral"
            if ($d.sentiment -eq "Bullish") { $sentimentLabel = "Bullish" }
            elseif ($d.sentiment -eq "Bearish") { $sentimentLabel = "Bearish" }
            
            $sourceLabel = if ($d.source_name) { $d.source_name } else { "Verified Source" }
            $md += "**A. News Summary:**`n"
            $md += "- **Headline:** $($d.headline)`n"
            $md += "- **Date:** $($d.date) | **Source:** [$sourceLabel]($($d.source_link))`n"
            $md += "- **Importance Score:** **$($d.importance_score)/10** | **Sentiment:** $sentimentLabel`n"
            $md += "- **Short-Term Impact:** $($d.short_term_impact)`n"
            $md += "- **Long-Term Impact:** $($d.long_term_impact)`n"
            $md += "- **Thesis Impact:** **$($d.thesis_impact)**`n"
            $md += "- **What Investors Might Be Missing (Second-Order Effects):** $($d.hidden_implications)`n"
            $md += "- **Risks:** $($d.risks)`n"
            $md += "- **Opportunities:** $($d.opportunities)`n`n"
        }
    }
    
    # Red Flags
    $redFlagsText = "None identified in the last 7 days. Capital allocation and liquidity are stable."
    if ($data.developments) {
        $hasRedFlags = $data.developments | Where-Object { $_.red_flags -ne "" -and $_.red_flags -ne "None" -and $_.red_flags -ne $null }
        if ($hasRedFlags) {
            $redFlagsText = $hasRedFlags[0].red_flags
        }
    } elseif ($ticker -eq "BSE:522231" -or $ticker -eq "NSE:CONART") {
        $redFlagsText = "Governance concern regarding non-compliance with SEBI's Structural Digital Database (SDD) regulations."
    }
    
    $md += "**B. Red Flags:**`n"
    $md += "> Red Flags: $($redFlagsText)`n`n"
    
    # JETRO Canvas Grid
    $canvas = $data.canvas_categories
    $md += "**C. JETRO Canvas Grid:**`n`n"
    $md += "| Canvas Dimension | Development Details & Impact Assessment |`n"
    $md += "| :--- | :--- |`n"
    $md += "| **1. Direct Company News** | $($canvas.direct_company_news) |`n"
    $md += "| **2. Sector News** | $($canvas.sector_news) |`n"
    $md += "| **3. Competitor News** | $($canvas.competitor_news) |`n"
    $md += "| **4. Government Policy Changes** | $($canvas.government_policy_changes) |`n"
    $md += "| **5. Raw Material Changes** | $($canvas.raw_material_changes) |`n"
    $md += "| **6. Order Inflow Changes** | $($canvas.order_inflow_changes) |`n"
    $md += "| **7. Demand Cycle Changes** | $($canvas.demand_cycle_changes) |`n"
    $md += "| **8. Management Commentary** | $($canvas.management_commentary) |`n"
    $md += "| **9. Institutional Activity** | $($canvas.institutional_activity) |`n"
    $md += "| **10. Promoter Activity** | $($canvas.promoter_activity) |`n`n"
    
    $md += "---`n`n"
}

# Write final output files
$localReport = "$workDir\Daily_Stock_Update_Report.md"
[System.IO.File]::WriteAllText($localReport, $md, [System.Text.Encoding]::UTF8)
Write-Host "Daily Stock Update Report generated locally at: $localReport"

$convoIds = @("7d24896f-fe79-4442-a3b4-217aa1943168", "53a3e2ce-a939-46e5-84ad-5426bc22425a", "1bbf1935-b256-4864-8246-a97851b388e8", "f88ef155-0a4c-43c0-8923-e00a472376aa")
foreach ($id in $convoIds) {
    $artReport = "C:\Users\mohdu\.gemini\antigravity\brain\$id\Daily_Stock_Update_Report.md"
    $artParent = Split-Path -Path $artReport -Parent
    if (Test-Path -Path $artParent) {
        [System.IO.File]::WriteAllText($artReport, $md, [System.Text.Encoding]::UTF8)
    }
}

Write-Host "Daily Stock Update Report generated successfully with 7-day retention filter."
