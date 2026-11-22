// JETRO Canvas Web Application Logic
document.addEventListener("DOMContentLoaded", () => {
    // Check if stockData is loaded
    if (typeof stockData === 'undefined') {
        console.error("stockData is not defined. Make sure data.js is loaded.");
        return;
    }

    // Update refresh date dynamically if available
    if (typeof lastRefreshed !== 'undefined') {
        const refreshDateEl = document.querySelector("#db-refresh-date");
        if (refreshDateEl) {
            refreshDateEl.textContent = lastRefreshed;
        }
    }


    // Update system health status dynamically if available
    if (typeof systemHealth !== 'undefined') {
        const healthBadge = document.querySelector("#system-health-badge");
        if (healthBadge) {
            healthBadge.textContent = `● System: ${systemHealth.status}`;
            if (systemHealth.status === "Healthy") {
                healthBadge.className = "badge low"; // green
                healthBadge.style.backgroundColor = "#1b4d3e";
                healthBadge.style.color = "#a3e635";
            } else if (systemHealth.status === "Out of Date") {
                healthBadge.className = "badge high"; // red
                healthBadge.style.backgroundColor = "#7f1d1d";
                healthBadge.style.color = "#fca5a5";
            } else {
                healthBadge.className = "badge medium"; // yellow/orange
                healthBadge.style.backgroundColor = "#7c2d12";
                healthBadge.style.color = "#fdba74";
            }
            healthBadge.title = `${systemHealth.message}\nLast Run: ${systemHealth.lastRun}\nLast Research Update: ${systemHealth.lastResearchUpdate}`;
        }
    }

    // Helper function to format relative date
    function getRelativeDateString(dateStr) {
        if (!dateStr) return "No Date";
        
        const parts = dateStr.split('-');
        if (parts.length !== 3) return dateStr;
        
        const year = parseInt(parts[0], 10);
        const month = parseInt(parts[1], 10) - 1; // months are 0-indexed in JS
        const day = parseInt(parts[2], 10);
        
        const devDate = new Date(year, month, day);
        const today = new Date();
        
        devDate.setHours(0,0,0,0);
        today.setHours(0,0,0,0);
        
        const diffTime = today - devDate;
        const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
        
        const formatter = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        const formattedDate = formatter.format(devDate);
        
        if (diffDays === 0) {
            return `Today (${formattedDate})`;
        } else if (diffDays === 1) {
            return `1 day ago (${formattedDate})`;
        } else if (diffDays === 2) {
            return `2 days ago (${formattedDate})`;
        } else if (diffDays > 2) {
            return `${diffDays} days ago (${formattedDate})`;
        } else {
            return `Today (${formattedDate})`;
        }
    }

    // Helper function to check if a development is within the 7-day retention window
    function isWithinLast7Days(dateStr) {
        if (!dateStr) return false;
        const parts = dateStr.split('-');
        if (parts.length !== 3) return true;
        const devDate = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        const today = new Date();
        devDate.setHours(0, 0, 0, 0);
        today.setHours(0, 0, 0, 0);
        const diffDays = Math.round((today - devDate) / (1000 * 60 * 60 * 24));
        return diffDays <= 7;
    }

    // Initialize State
    let currentTab = "dashboard";
    let selectedStockTicker = stockData[0] ? stockData[0].ticker : "";
    let searchFilter = "";
    let sectorFilter = "";
    let sentimentFilter = "";

    // DOM Elements
    const navItems = document.querySelectorAll(".nav-item");
    const tabContents = document.querySelectorAll(".tab-content");
    const tbody = document.querySelector("#portfolio-table-body");
    const stockSelector = document.querySelector("#stock-selector");
    const searchInput = document.querySelector("#search-input");
    const sectorSelect = document.querySelector("#sector-select");
    const sentimentSelect = document.querySelector("#sentiment-select");

    // Initialize Page
    calculateStats();
    renderHighImpactNews();
    renderPortfolioTable();
    populateStockSelector();
    renderSectorDashboard();
    
    if (selectedStockTicker) {
        renderStockCanvas(selectedStockTicker);
    }

    // Tab Navigation
    navItems.forEach(item => {
        item.addEventListener("click", () => {
            const tabName = item.getAttribute("data-tab");
            switchTab(tabName);
        });
    });

    function switchTab(tabName) {
        currentTab = tabName;
        
        // Update Nav Menu active state
        navItems.forEach(nav => {
            if (nav.getAttribute("data-tab") === tabName) {
                nav.classList.add("active");
            } else {
                nav.classList.remove("active");
            }
        });

        // Update Tab Contents active state
        tabContents.forEach(content => {
            if (content.id === `${tabName}-tab`) {
                content.classList.add("active");
            } else {
                content.classList.remove("active");
            }
        });
    }

    // Calculate Summary Stats
    function calculateStats() {
        const total = stockData.length;
        let bullish = 0;
        let bearish = 0;
        let neutral = 0;

        stockData.forEach(stock => {
            // Count based on overall sentiment
            if (stock.sentiment === "Bullish") bullish++;
            else if (stock.sentiment === "Bearish") bearish++;
            else neutral++;
        });

        document.querySelector("#stat-total").textContent = total;
        document.querySelector("#stat-bullish").textContent = bullish;
        document.querySelector("#stat-bearish").textContent = bearish;
        document.querySelector("#stat-neutral").textContent = neutral;
    }

    // Render High Impact News Panels (Top 5 Positive, Top 5 Negative)
    function renderHighImpactNews() {
        const allDevelopments = [];
        stockData.forEach(stock => {
            if (stock.news_found && stock.developments) {
                stock.developments.forEach(dev => {
                    if (!isWithinLast7Days(dev.date)) return;
                    allDevelopments.push({
                        ticker: stock.ticker,
                        name: stock.name,
                        headline: dev.headline,
                        sentiment: dev.sentiment,
                        score: dev.importance_score,
                        short_term: dev.short_term_impact,
                        long_term: dev.long_term_impact,
                        missing: dev.hidden_implications,
                        date: dev.date,
                        source_name: dev.source_name || "Verified Source",
                        source_link: dev.source_link || "#"
                    });
                });
            }
        });

        // Sort primarily by date descending, secondarily by importance score descending
        allDevelopments.sort((a, b) => {
            const dateA = a.date ? new Date(a.date + "T00:00:00") : new Date(0);
            const dateB = b.date ? new Date(b.date + "T00:00:00") : new Date(0);
            if (dateB - dateA !== 0) {
                return dateB - dateA;
            }
            return b.score - a.score;
        });

        // Filter Top 5 Positive (Bullish)
        const positiveNews = allDevelopments.filter(d => d.sentiment === "Bullish").slice(0, 5);
        // Filter Top 5 Negative (Bearish or high-importance Neutral with issues)
        const negativeNews = allDevelopments.filter(d => d.sentiment === "Bearish" || (d.sentiment === "Neutral" && d.score >= 6)).slice(0, 5);

        const positiveContainer = document.querySelector("#positive-news-list");
        const negativeContainer = document.querySelector("#negative-news-list");

        positiveContainer.innerHTML = positiveNews.map(d => `
            <div class="news-item">
                <div class="news-header">
                    <span class="news-headline" onclick="viewStockCanvasDirect('${d.ticker}')">${d.ticker} - ${d.headline}</span>
                    <div style="display: flex; gap: 0.5rem; align-items: center; flex-shrink: 0;">
                        <span class="tag date-tag">${getRelativeDateString(d.date)}</span>
                        <a href="${d.source_link}" target="_blank" onclick="event.stopPropagation();" class="tag" style="background: rgba(99, 102, 241, 0.15); color: #818cf8; text-decoration: underline;">${d.source_name}</a>
                        <span class="tag bullish">Imp: ${d.score}/10</span>
                    </div>
                </div>
                <div class="news-explanation">
                    <strong>Hedge Fund Perspective:</strong> ${d.short_term} ${d.long_term}<br>
                    <strong>What Investors Miss:</strong> ${d.missing}
                </div>
            </div>
        `).join("");

        negativeContainer.innerHTML = negativeNews.map(d => `
            <div class="news-item">
                <div class="news-header">
                    <span class="news-headline" onclick="viewStockCanvasDirect('${d.ticker}')">${d.ticker} - ${d.headline}</span>
                    <div style="display: flex; gap: 0.5rem; align-items: center; flex-shrink: 0;">
                        <span class="tag date-tag">${getRelativeDateString(d.date)}</span>
                        <a href="${d.source_link}" target="_blank" onclick="event.stopPropagation();" class="tag" style="background: rgba(239, 68, 68, 0.15); color: #f87171; text-decoration: underline;">${d.source_name}</a>
                        <span class="tag bearish">Imp: ${d.score}/10</span>
                    </div>
                </div>
                <div class="news-explanation">
                    <strong>Hedge Fund Perspective:</strong> ${d.short_term} ${d.long_term}<br>
                    <strong>What Investors Miss:</strong> ${d.missing}
                </div>
            </div>
        `).join("");
    }

    // Render Portfolio Dashboard Table
    function renderPortfolioTable() {
        const filtered = stockData.filter(stock => {
            const matchesSearch = stock.ticker.toLowerCase().includes(searchFilter.toLowerCase()) || 
                                  stock.name.toLowerCase().includes(searchFilter.toLowerCase());
            const matchesSector = sectorFilter === "" || stock.sector === sectorFilter;
            const matchesSentiment = sentimentFilter === "" || stock.sentiment === sentimentFilter;
            return matchesSearch && matchesSector && matchesSentiment;
        });

        if (filtered.length === 0) {
            tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 3rem;">No stocks matching filter criteria.</td></tr>`;
            return;
        }

        // Sort: Newest development date first, then Bearish first, then Bullish, then Neutral
        filtered.sort((a, b) => {
            const dateAStr = a.developments && a.developments.length > 0 ? a.developments[0].date : "1970-01-01";
            const dateBStr = b.developments && b.developments.length > 0 ? b.developments[0].date : "1970-01-01";
            
            const dateA = new Date(dateAStr + "T00:00:00");
            const dateB = new Date(dateBStr + "T00:00:00");
            
            if (dateB - dateA !== 0) {
                return dateB - dateA;
            }
            
            const priority = { "Bearish": 0, "Bullish": 1, "Neutral": 2 };
            return priority[a.sentiment] - priority[b.sentiment];
        });

        tbody.innerHTML = filtered.map(stock => {
            let sentimentClass = "neutral";
            let sentimentBadgeText = "Neutral";
            if (stock.sentiment === "Bullish") {
                sentimentClass = "bullish";
                sentimentBadgeText = "Bullish";
            } else if (stock.sentiment === "Bearish") {
                sentimentClass = "bearish";
                sentimentBadgeText = "Bearish";
            }

            let riskClass = "low";
            if (stock.risk_level === "High") riskClass = "high";
            else if (stock.risk_level === "Medium") riskClass = "medium";

            let firstDev = (stock.developments && stock.developments.length > 0 && isWithinLast7Days(stock.developments[0].date)) ? stock.developments[0] : null;
            let devHtml = "No major developments in the last 7 days.";
            if (firstDev) {
                const srcName = firstDev.source_name || "Verified Source";
                devHtml = `<span class="date-badge">${getRelativeDateString(firstDev.date)}</span> ${firstDev.headline} <a href="${firstDev.source_link}" target="_blank" onclick="event.stopPropagation();" style="color: var(--accent); margin-left: 6px; text-decoration: underline; font-weight: 500;">[${srcName}]</a>`;
            }

            return `
                <tr onclick="viewStockCanvasDirect('${stock.ticker}')">
                    <td><span class="ticker-badge">${stock.ticker}</span></td>
                    <td>
                        <div class="company-name-cell">${stock.name}</div>
                        <div class="company-sector">${stock.sector}</div>
                    </td>
                    <td style="text-align: center;"><span class="tag ${sentimentClass}">${sentimentBadgeText}</span></td>
                    <td style="text-align: center;"><span class="badge ${riskClass}">${stock.risk_level}</span></td>
                    <td class="key-dev-cell">${devHtml}</td>
                </tr>
            `;
        }).join("");
    }

    // Populate Stock Selector Dropdown in Canvas Tab
    function populateStockSelector() {
        stockSelector.innerHTML = stockData.map(stock => `
            <option value="${stock.ticker}">${stock.ticker} - ${stock.name}</option>
        `).join("");

        stockSelector.addEventListener("change", (e) => {
            selectedStockTicker = e.target.value;
            renderStockCanvas(selectedStockTicker);
        });
    }

    // Render Individual JETRO Canvas
    function renderStockCanvas(ticker) {
        const stock = stockData.find(s => s.ticker === ticker);
        if (!stock) return;

        // Profile Details
        const ltpText = stock.ltp ? ` · ₹${Number(stock.ltp).toLocaleString('en-IN', { minimumFractionDigits: 2 })} (${stock.change_percent >= 0 ? '+' : ''}${stock.change_percent}%)` : '';
        document.querySelector("#profile-ticker").textContent = `${stock.ticker}${ltpText}`;
        document.querySelector("#profile-name").textContent = stock.name;
        document.querySelector("#profile-sector").textContent = stock.sector;
        
        const sentimentContainer = document.querySelector("#profile-sentiment");
        sentimentContainer.className = `tag ${stock.sentiment.toLowerCase()}`;
        sentimentContainer.textContent = stock.sentiment;

        const riskContainer = document.querySelector("#profile-risk");
        riskContainer.className = `badge ${stock.risk_level.toLowerCase()}`;
        riskContainer.textContent = `${stock.risk_level} Risk`;

        // Action Plan removed

        // Top Summary Headline
        const summaryBox = document.querySelector("#stock-summary-box");
        if (stock.news_found && stock.developments && stock.developments.length > 0) {
            const dev = stock.developments[0];
            summaryBox.style.display = "block";
            summaryBox.innerHTML = `
                <h4 style="font-size: 1rem; font-weight: 700; margin-bottom: 0.5rem; color: var(--accent);">${dev.headline}</h4>
                <p style="font-size: 0.85rem; line-height: 1.5; color: var(--text-muted); margin-bottom: 0.5rem; display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
                    <span><strong>Date:</strong> <span class="tag date-tag">${getRelativeDateString(dev.date)}</span></span>
                    <span>|</span>
                    <span><strong>Source:</strong> <a href="${dev.source_link}" target="_blank" style="color: var(--accent); text-decoration: underline; font-weight: 600;">${dev.source_name || "Verified Source"}</a></span>
                    <span>|</span>
                    <span><strong>Importance:</strong> ${dev.importance_score}/10</span>
                </p>
                <p style="font-size: 0.85rem; line-height: 1.5; margin-bottom: 0.5rem;">
                    <strong>Hedge Fund Analysis:</strong> ${dev.short_term_impact} ${dev.long_term_impact}
                </p>
                <p style="font-size: 0.85rem; line-height: 1.5; color: var(--text-main);">
                    <strong>What Investors Miss:</strong> ${dev.hidden_implications}
                </p>
            `;
        } else {
            summaryBox.style.display = "none";
        }

        // Red Flags Alert
        const redFlagsContainer = document.querySelector("#profile-red-flags");
        let redFlagsText = "None identified in the last 7 days. Capital allocation and liquidity are stable.";
        if (stock.developments && stock.developments.length > 0 && stock.developments[0].red_flags && stock.developments[0].red_flags !== "None") {
            redFlagsText = stock.developments[0].red_flags;
        } else if (stock.ticker === "BSE:522231" || stock.ticker === "NSE:CONART") {
            redFlagsText = "Non-compliance with SEBI's Structural Digital Database (SDD) regulations flagged.";
        }
        
        redFlagsContainer.innerHTML = `
            <svg style="width: 20px; height: 20px; flex-shrink: 0;" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
            </svg>
            <div><strong>Red Flags / Monitorables:</strong> ${redFlagsText}</div>
        `;
        
        if (redFlagsText.includes("None identified")) {
            redFlagsContainer.style.background = "rgba(16, 185, 129, 0.08)";
            redFlagsContainer.style.borderColor = "rgba(16, 185, 129, 0.2)";
            redFlagsContainer.style.color = "#a7f3d0";
        } else {
            redFlagsContainer.style.background = "rgba(239, 68, 68, 0.08)";
            redFlagsContainer.style.borderColor = "rgba(239, 68, 68, 0.2)";
            redFlagsContainer.style.color = "#fca5a5";
        }

        // Render 10 Canvas Blocks
        const canvasContainer = document.querySelector("#canvas-grid-container");
        const categories = stock.canvas_categories;
        const sentimentClass = stock.sentiment.toLowerCase();

        const blockDefinitions = [
            { id: 1, title: "Direct Company News", key: "direct_company_news", isDirect: true },
            { id: 2, title: "Sector News", key: "sector_news" },
            { id: 3, title: "Competitor News", key: "competitor_news" },
            { id: 4, title: "Government Policy", key: "government_policy_changes" },
            { id: 5, title: "Raw Material Changes", key: "raw_material_changes" },
            { id: 6, title: "Order Inflows", key: "order_inflow_changes" },
            { id: 7, title: "Demand Cycle", key: "demand_cycle_changes" },
            { id: 8, title: "Management Commentary", key: "management_commentary" },
            { id: 9, title: "Institutional Activity", key: "institutional_activity" },
            { id: 10, title: "Promoter Activity", key: "promoter_activity" }
        ];

        canvasContainer.innerHTML = blockDefinitions.map(block => {
            const hasNews = stock.news_found;
            let activeClass = "";
            
            // Highlight blocks that are highly relevant to today's news
            if (hasNews) {
                if (block.isDirect) {
                    activeClass = `active-news ${sentimentClass}`;
                } else if (block.key === "order_inflow_changes" && (stock.ticker === "NSE:BCPL" || stock.ticker === "NSE:CEIGALL" || stock.ticker === "NSE:RAILTEL" || stock.ticker === "NSE:WAAREERTL" || stock.ticker === "NSE:SKIPPER")) {
                    activeClass = `active-news bullish`;
                } else if (block.key === "promoter_activity" && (stock.ticker === "NSE:EMBDL" || stock.ticker === "NSE:TEMBO" || stock.ticker === "NSE:VPRPL")) {
                    activeClass = `active-news ${sentimentClass}`;
                } else if (block.key === "raw_material_changes" && stock.ticker === "NSE:WELSPUNLIV") {
                    activeClass = `active-news bullish`;
                }
            }

            return `
                <div class="canvas-block ${activeClass}">
                    <div class="canvas-block-header">
                        <span class="canvas-block-number">${block.id}</span>
                        <span class="canvas-block-title">${block.title}</span>
                    </div>
                    <div class="canvas-block-content">${categories[block.key] || "No material developments reported."}</div>
                </div>
            `;
        }).join("");
    }

    // Render Sector Dashboard Tab
    function renderSectorDashboard() {
        const sectorContainer = document.querySelector("#sector-grid-container");
        
        const sectors = [
            {
                name: "IT Services & Digital Infrastructure",
                stocks: ["BBOX", "BSOFT", "DCI", "ORIENTTECH", "ADCINDIA", "RAILTEL", "TATATECH"],
                tailwinds: "High demand for AI workloads, cloud migrations, and municipal smart connectivity.",
                headwinds: "Margin compression in commodity IT services and technical momentum downgrades.",
                policy: "Digital Personal Data Protection Act forcing localized cloud capacity leases.",
                competitors: "Hyperscalers scaling out custom silicon data centers.",
                demand: "Exponential growth in AI model hosting, with flat traditional application maintenance."
            },
            {
                name: "Railways, Real Estate, Roads & Infrastructure EPC",
                stocks: ["BCPL", "CEIGALL", "EMSLIMITED", "IRCON", "LIKHITHA", "ORIENTLTD", "TITAGARH", "VPRPL", "CONART", "EMBDL"],
                tailwinds: "Strong central capital expenditure budgets and localized urban infrastructure programs.",
                headwinds: "Severe working capital distress in smaller caps, and rating downgrades (Issuer Not Cooperating).",
                policy: "Strict project execution penalty guidelines enforced by NHAI and South East Central Railway.",
                competitors: "Intense price bidding for lower complexity sub-₹100 Cr tenders.",
                demand: "Massive bidding pipeline but constrained by capital guarantee/bank credit availability."
            },
            {
                name: "Power, Solar & Clean Energy Financing",
                stocks: ["IREDA", "SKIPPER", "TATAPOWER", "TEMBO", "WAAREERTL", "OLECTRA", "NHPC", "SWSOLAR", "SJVN"],
                tailwinds: "Drastic solar module cost reductions and central Rooftop Solar (PM Surya Ghar) policy push.",
                headwinds: "DISCOM delays in executing Power Sale Agreements (PSAs) for awarded capacity.",
                policy: "Commissioning extension reviews for domestic solar mandate projects beyond May 31.",
                competitors: "Intense solar tariff bidding among IPPs leading to low double-digit equity IRRs.",
                demand: "Surging grid power demand forcing utilities to rapidly buy clean power capacity."
            },
            {
                name: "Financial Services, NBFCs & Exchanges",
                stocks: ["JIOFIN", "POONAWALLA", "HUDCO", "CDSL", "BSE"],
                tailwinds: "Deepening financialization of household assets and growth of retail investment accounts.",
                headwinds: "Regulatory crackdown on unsecured retail lending and digital security audit compliance.",
                policy: "SEBI and RBI tightening risk weights on credit card/unsecured credit books.",
                competitors: "Traditional banks competing aggressively on interest rates for high-quality retail depositors.",
                demand: "Robust volume growth in derivative clearing and investment account creation."
            },
            {
                name: "FMCG, Auto & Industrial Energy",
                stocks: ["RELIANCE", "IOC", "ITC", "TATAMOTORS", "WELSPUNLIV", "PNGJL", "PPL"],
                tailwinds: "Customs duty scrapping on cotton imports; strong commercial vehicle demand.",
                headwinds: "Elevated global crude prices squeezing marketing margins of state oil companies.",
                policy: "Abolition of 11% import taxes on cotton; strict state fuel price regulations.",
                competitors: "Private fuel retail price adjustments shifting retail volume back to PSU fuel outlets.",
                demand: "Steady passenger EV transition and premium retail product volume growth."
            }
        ];

        sectorContainer.innerHTML = sectors.map(sec => `
            <div class="sector-card">
                <div class="sector-card-header">
                    <span class="sector-name">${sec.name}</span>
                    <div class="sector-badge-list">
                        ${sec.stocks.map(s => `<span class="ticker-badge">${s}</span>`).join("")}
                    </div>
                </div>
                <div class="sector-dimension-grid">
                    <div class="sector-dimension-block">
                        <div class="sector-dimension-title">Tailwinds</div>
                        <div class="sector-dimension-text">${sec.tailwinds}</div>
                    </div>
                    <div class="sector-dimension-block">
                        <div class="sector-dimension-title">Headwinds</div>
                        <div class="sector-dimension-text">${sec.headwinds}</div>
                    </div>
                    <div class="sector-dimension-block">
                        <div class="sector-dimension-title">Policy Changes</div>
                        <div class="sector-dimension-text">${sec.policy}</div>
                    </div>
                    <div class="sector-dimension-block">
                        <div class="sector-dimension-title">Competitor Actions</div>
                        <div class="sector-dimension-text">${sec.competitors}</div>
                    </div>
                    <div class="sector-dimension-block">
                        <div class="sector-dimension-title">Demand Trends</div>
                        <div class="sector-dimension-text">${sec.demand}</div>
                    </div>
                </div>
            </div>
        `).join("");
    }

    // Global helper function to jump to Stock Canvas tab
    window.viewStockCanvasDirect = function(ticker) {
        selectedStockTicker = ticker;
        stockSelector.value = ticker;
        renderStockCanvas(ticker);
        switchTab("explorer");
    };

    // Filter Listeners
    searchInput.addEventListener("input", (e) => {
        searchFilter = e.target.value;
        renderPortfolioTable();
    });

    sectorSelect.addEventListener("change", (e) => {
        sectorFilter = e.target.value;
        renderPortfolioTable();
    });

    sentimentSelect.addEventListener("change", (e) => {
        sentimentFilter = e.target.value;
        renderPortfolioTable();
    });
});
