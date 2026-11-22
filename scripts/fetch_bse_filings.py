import os
import json
import datetime
from pathlib import Path

# Map of 38 stocks with BSE scrip codes
BSE_SCRIP_MAP = {
    "500463": "BBOX",
    "532400": "BSOFT",
    "532528": "DCI",
    "544236": "ORIENTTECH",
    "523411": "ADCINDIA",
    "543265": "RAILTEL",
    "544028": "TATATECH",
    "543940": "JIOFIN",
    "524000": "POONAWALLA",
    "540530": "HUDCO",
    "540615": "CDSL",
    "532977": "BSE",
    "542057": "BCPL",
    "544223": "CEIGALL",
    "543983": "EMSLIMITED",
    "541956": "IRCON",
    "543240": "LIKHITHA",
    "531859": "ORIENTLTD",
    "532966": "TITAGARH",
    "522231": "CONART",
    "543974": "VPRPL",
    "532832": "EMBDL",
    "544026": "IREDA",
    "538562": "SKIPPER",
    "500400": "TATAPOWER",
    "542060": "TEMBO",
    "534618": "WAAREERTL",
    "532480": "OLECTRA",
    "533098": "NHPC",
    "542765": "SWSOLAR",
    "533206": "SJVN",
    "500570": "TATAMOTORS",
    "500325": "RELIANCE",
    "530965": "IOC",
    "500875": "ITC",
    "514162": "WELSPUNLIV",
    "544252": "PNGJL",
    "542684": "PPL"
}

ROOT_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT_DIR / "raw_data"

def run():
    try:
        from bse import BSE
    except ImportError:
        print("[Notice] 'bse' library (BennyThadikaran/BseIndiaApi) not installed. Run 'pip install -U bse' to fetch direct exchange filings.")
        return

    print("==================================================")
    print("FETCHING OFFICIAL BSE REGULATORY ANNOUNCEMENTS")
    print("==================================================")

    matches_by_code = {}

    try:
        with BSE(download_folder=str(ROOT_DIR / "scratch")) as bse_api:
            # Check up to 5 pages of announcements
            for page in range(1, 6):
                try:
                    res = bse_api.announcements(page_no=page)
                    if not res or "Table" not in res:
                        break
                    table = res.get("Table", [])
                    if not table:
                        break

                    for item in table:
                        scrip = str(item.get("SCRIP_CD", "")).strip()
                        if scrip in BSE_SCRIP_MAP:
                            stock_code = BSE_SCRIP_MAP[scrip]
                            attachment = item.get("ATTACHMENTNAME", "")
                            pdf_url = f"https://www.bseindia.com/xml-data/corpfiling/AttachLive/{attachment}" if attachment else f"https://www.bseindia.com/stock-share-price/{stock_code}/{scrip}/"
                            
                            headline = item.get("NEWSSUB", "") or item.get("MORE", "") or "BSE Corporate Announcement"
                            dt_str = item.get("DT_TM", "")
                            
                            # Parse date
                            iso_date = datetime.date.today().isoformat()
                            if dt_str:
                                try:
                                    dt_part = dt_str.split("T")[0] if "T" in dt_str else dt_str.split(" ")[0]
                                    iso_date = dt_part
                                except:
                                    pass

                            dev = {
                                "date": iso_date,
                                "headline": headline,
                                "source_name": "BSE Official Filing (PDF)",
                                "source_link": pdf_url,
                                "sentiment": "Bullish" if any(w in headline.lower() for w in ["win", "order", "dividend", "profit", "award", "approval"]) else "Neutral",
                                "importance_score": 9,
                                "short_term_impact": f"Official regulatory disclosure filed with BSE under Scrip Code {scrip}.",
                                "long_term_impact": "Direct regulatory compliance event filed on official exchange repository.",
                                "thesis_impact": "Bullish",
                                "opportunities": "Verified exchange-level corporate action/announcement.",
                                "risks": "Subject to operational execution.",
                                "red_flags": "None",
                                "hidden_implications": f"Original signed filing document available at official BSE repository."
                            }

                            if stock_code not in matches_by_code:
                                matches_by_code[stock_code] = []
                            matches_by_code[stock_code].append(dev)

                except Exception as pe:
                    print(f"Page {page} fetch error: {pe}")
                    break

        print(f"Found official BSE announcements for {len(matches_by_code)} portfolio stocks.")

        # Merge with raw_data JSONs
        for stock_code, new_devs in matches_by_code.items():
            json_file = RAW_DIR / f"{stock_code}.json"
            if json_file.exists():
                try:
                    with open(json_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    
                    existing_devs = data.get("developments", [])
                    # Prepend new official filings if not already present
                    existing_links = {d.get("source_link") for d in existing_devs}
                    added = 0
                    for nd in new_devs:
                        if nd["source_link"] not in existing_links:
                            existing_devs.insert(0, nd)
                            added += 1
                    
                    data["developments"] = existing_devs
                    data["news_found"] = len(existing_devs) > 0
                    
                    with open(json_file, "w", encoding="utf-8") as f:
                        json.dump(data, f, indent=2)
                    
                    if added > 0:
                        print(f"Added {added} official BSE filing(s) to {stock_code}.json")
                except Exception as e:
                    print(f"Error updating {stock_code}.json: {e}")

    except Exception as e:
        print(f"BSE API Error: {e}")

if __name__ == "__main__":
    run()
