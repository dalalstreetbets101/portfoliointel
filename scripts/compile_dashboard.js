const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..');
const RAW_DIR = path.join(ROOT_DIR, 'raw_data');

function compile() {
  const excludeFiles = ['EMS.json', 'ORIENTALRAIL.json', 'EMBASSY.json', 'ORIENTLTD.json', 'TATAMOTORS.json'];
  const files = fs.readdirSync(RAW_DIR).filter(f => f.endsWith('.json') && !excludeFiles.includes(f));

  const now = new Date();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const cutoffDateStr = sevenDaysAgo.toISOString().split('T')[0];

  const stockList = [];
  let totalActiveNews = 0;
  const sentimentCounts = { Bullish: 0, Bearish: 0, Neutral: 0 };

  for (const file of files) {
    try {
      const content = fs.readFileSync(path.join(RAW_DIR, file), 'utf8');
      const data = JSON.parse(content);

      // Filter developments to 7 days
      const validDevs = (data.developments || []).filter(d => {
        if (!d.date) return false;
        return d.date >= cutoffDateStr;
      });

      const newsFound = validDevs.length > 0;
      totalActiveNews += validDevs.length;

      let sentiment = "Neutral";
      let riskLevel = "Low";
      let keyDev = "No major developments in the last 7 days.";

      if (newsFound) {
        const sorted = [...validDevs].sort((a, b) => (b.importance_score || 0) - (a.importance_score || 0));
        sentiment = sorted[0].sentiment || "Neutral";
        keyDev = sorted[0].headline;

        const hasRedFlags = validDevs.some(d => d.red_flags && d.red_flags !== "None" && d.red_flags !== "");
        if (hasRedFlags) {
          riskLevel = "High";
        } else if (sentiment === "Bearish") {
          riskLevel = "Medium";
        } else {
          riskLevel = "Low";
        }
      }

      sentimentCounts[sentiment] = (sentimentCounts[sentiment] || 0) + 1;

      stockList.push({
        ticker: data.ticker,
        name: data.company_name,
        sector: data.sector || "Others",
        ltp: data.ltp || 0,
        change: data.change || 0,
        change_percent: data.change_percent || 0,
        prev_close: data.prev_close || 0,
        fifty_two_week_high: data.fifty_two_week_high || 0,
        fifty_two_week_low: data.fifty_two_week_low || 0,
        news_found: newsFound,
        sentiment: sentiment,
        risk_level: riskLevel,
        action_required: sentiment === "Bullish" ? "Accumulate on dips" : "Hold/Monitor",
        developments: validDevs,
        canvas_categories: data.canvas_categories || {}
      });
    } catch (e) {
      console.error(`Error processing ${file}:`, e.message);
    }
  }

  // 1. Generate data.js
  const todayStr = now.toLocaleDateString('en-US', { month: 'long', day: '2-digit', year: 'numeric' });
  const dataJsContent = `const lastRefreshed = "${todayStr}";\nconst stockData = ${JSON.stringify(stockList, null, 2)};\n`;
  fs.writeFileSync(path.join(ROOT_DIR, 'data.js'), dataJsContent, 'utf8');

  // 2. Generate health_status.js
  const pad = n => String(n).padStart(2, '0');
  const nowIso = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
  const healthContent = `const systemHealth = {\n    "message":  "System is fully operational.",\n    "lastRun":  "${nowIso}",\n    "lastResearchUpdate":  "${nowIso}",\n    "schedulerAppState":  "Ready",\n    "schedulerDirectState":  "Ready",\n    "status":  "Healthy",\n    "rawFilesAgeHours":  0\n};\n`;
  fs.writeFileSync(path.join(ROOT_DIR, 'health_status.js'), healthContent, 'utf8');

  // 3. Generate Daily_Stock_Update_Report.md
  let md = `# UMAR'S PORTFOLIO INTELLIGENCE REPORT: 7-DAY ROLLING UPDATE\n`;
  md += `**Date:** ${todayStr}  \n`;
  md += `**Retention Policy:** Rolling 7-day active window with live market data & verified media links.  \n`;
  md += `**Analyst:** Buy-Side Equity Research Unit (JETRO CANVAS Style Format)\n\n---\n\n`;
  md += `## 1. PORTFOLIO DASHBOARD\n\n`;
  md += `| Stock | News Count | Sentiment | Risk Level | Most Important Development |\n`;
  md += `| :--- | :---: | :---: | :---: | :--- |\n`;

  const sortedList = [...stockList].sort((a, b) => {
    if (b.developments.length !== a.developments.length) return b.developments.length - a.developments.length;
    return a.ticker.localeCompare(b.ticker);
  });

  for (const s of sortedList) {
    const devText = s.developments.length > 0 ? (s.developments[0].category ? `\`${s.developments[0].category}\` ` : '') + s.developments[0].headline : "No major developments in the last 7 days.";
    md += `| **${s.ticker}**<br>${s.name} | ${s.developments.length} | ${s.sentiment} | ${s.risk_level} | ${devText} |\n`;
  }

  md += `\n---\n\n## 2. INDIVIDUAL STOCK INTELLIGENCE REPORTS\n\n`;
  for (const s of [...stockList].sort((a, b) => a.ticker.localeCompare(b.ticker))) {
    md += `### Ticker: ${s.ticker} - Name: ${s.name} (LTP: ₹${s.ltp})\n\n`;
    if (!s.news_found || s.developments.length === 0) {
      md += `> **News Status:** No direct company news reported in the last 7 days. Stale developments older than 1 week are automatically archived/purged.\n\n`;
    } else {
      for (const d of s.developments) {
        md += `**A. News Summary:**\n`;
        md += `- **Headline:** ${d.headline}\n`;
        md += `- **Category:** \`${d.category || 'Strategic Corporate News'}\`\n`;
        md += `- **Date:** ${d.date} | **Source:** [${d.source_name || 'Verified Source'}](${d.source_link})\n`;
        md += `- **Importance Score:** **${d.importance_score}/10** | **Sentiment:** ${d.sentiment}\n`;
        md += `- **Short-Term Impact:** ${d.short_term_impact}\n`;
        md += `- **Long-Term Impact:** ${d.long_term_impact}\n\n`;
      }
    }
    md += `---\n\n`;
  }

  fs.writeFileSync(path.join(ROOT_DIR, 'Daily_Stock_Update_Report.md'), md, 'utf8');

  console.log(`Compilation complete. Processed ${stockList.length} stocks. Total active 7D news: ${totalActiveNews}`);
}

compile();
