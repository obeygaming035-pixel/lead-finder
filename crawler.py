import os
import re
import time
import random
import socket
import sqlite3
import requests
from datetime import datetime
import subprocess
from pathlib import Path
from bs4 import BeautifulSoup
from config import BASE_DIR, DB_PATH, MOCKUPS_DIR, TARGET_CITIES, TARGET_NICHES, GLM_API_KEY, get_preview_url

import json

SETTINGS_FILE = BASE_DIR / "crawler_settings.json"

def load_settings():
    default_settings = {
        "whatsapp_enabled": False,  # Turned off by default as requested
        "min_delay": 90,
        "max_delay": 180,
        "max_results": 100
    }
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                return {**default_settings, **json.load(f)}
        except Exception:
            pass
    return default_settings

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS leads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            business_name TEXT UNIQUE,
            industry TEXT,
            city TEXT,
            current_website TEXT,
            proposed_domain TEXT,
            domain_available INTEGER,
            email TEXT,
            phone TEXT,
            owner_name TEXT,
            initial_pitch TEXT,
            followup_pitch TEXT,
            status TEXT DEFAULT 'Pending Review',
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

def get_random_images(industry, count=4):
    """
    Loads image_pool.json and returns a list of unique random image URLs for the industry.
    Falls back to a small default list if the file is missing or empty.
    """
    import json
    import random
    from pathlib import Path
    
    pool_file = Path(__file__).resolve().parent / "image_pool.json"
    if pool_file.exists():
        try:
            with open(pool_file, "r", encoding="utf-8") as f:
                pool = json.load(f)
            images = pool.get(industry, [])
            if len(images) >= count:
                return random.sample(images, count)
            elif len(images) > 0:
                return random.choices(images, k=count)
        except Exception:
            pass
            
    # Default fallbacks if file not found or error
    defaults = {
        "architects & interior design studios": [
            "https://images.unsplash.com/photo-1618221195710-dd6b41faaea6",
            "https://images.unsplash.com/photo-1600585154340-be6161a56a0c",
            "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9",
            "https://images.unsplash.com/photo-1512917774080-9991f1c4c750"
        ],
        "wedding & luxury event planners": [
            "https://images.unsplash.com/photo-1545232979-fbf34fe37b38",
            "https://images.unsplash.com/photo-1519741497674-611481863552",
            "https://images.unsplash.com/photo-1511285560929-80b456fea0bc",
            "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3"
        ],
        "custom furniture & woodwork studios": [
            "https://images.unsplash.com/photo-1617806118233-18e1de247200",
            "https://images.unsplash.com/photo-1538688525198-9b88f6f53126",
            "https://images.unsplash.com/photo-1555041469-a586c61ea9bc",
            "https://images.unsplash.com/photo-1540518614846-7eded433c457"
        ],
        "industrial machinery & tool suppliers": [
            "https://images.unsplash.com/photo-1581092160607-ee22621dd758",
            "https://images.unsplash.com/photo-1581092335397-9583fe92d232",
            "https://images.unsplash.com/photo-1504917599217-d4dc5ebe6122",
            "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158"
        ],
        "chartered accountants & tax advisory firms": [
            "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c",
            "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab",
            "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40",
            "https://images.unsplash.com/photo-1450133064473-71024230f91b"
        ]
    }
    
    niche_defaults = defaults.get(industry, defaults["architects & interior design studios"])
    return random.choices(niche_defaults, k=count)

def generate_owner_name(business_name, industry):
    """
    Generates a realistic Indian owner name matching the industry type and context.
    """
    import random
    import re
    
    first_names_male = [
        "Rajesh", "Anand", "Suresh", "Vikram", "Aniket", "Siddharth", "Vijay",
        "Karan", "Ravi", "Amit", "Arjun", "Hitesh", "Sunil", "Manish", "Nikhil", "Paresh"
    ]
    first_names_female = [
        "Priya", "Meera", "Ritu", "Nandini", "Shreya", "Lakshmi", "Sneha", "Ananya"
    ]
    last_names = [
        "Sharma", "Verma", "Mehta", "Patel", "Shah", "Joshi", "Rao", "Nair", "Malhotra",
        "Kumar", "Reddy", "Singh", "Kapoor", "Jain", "Deshmukh", "Desai", "Gupta", "Iyer"
    ]
    
    # Check if business name has a person's name in it
    words = business_name.split()
    matched_last = None
    matched_first = None
    
    for word in words:
        word_clean = re.sub(r'[^a-zA-Z]', '', word)
        if word_clean in last_names:
            matched_last = word_clean
            break
        if word_clean in first_names_male or word_clean in first_names_female:
            matched_first = word_clean
            break
            
    first = matched_first if matched_first else random.choice(first_names_male + first_names_female)
    last = matched_last if matched_last else random.choice(last_names)
    owner = f"{first} {last}"
    
    ind = industry.lower()
    if "architect" in ind or "interior" in ind:
        return f"Architect {owner} (Principal Architect)"
    elif "chartered" in ind or "tax" in ind:
        return f"CA {owner} (Senior Partner & FCA)"
    elif "furniture" in ind or "woodwork" in ind:
        return f"{owner} (Founder & Master Craftsman)"
    elif "machinery" in ind or "tool" in ind:
        return f"{owner} (Managing Director)"
    else:
        return f"{owner} (Founder)"

def scrape_google_maps_playwright(niche, city, max_results=10):
    """
    Scrapes Google Maps for a query like "{niche} in {city}" using Playwright direct links.
    """
    from playwright.sync_api import sync_playwright
    import urllib.parse
    import random

    def sanitize_scraped_text(text):
        if not text:
            return ""
        # Remove private use area characters (like Google Map custom icons)
        clean = "".join(c for c in text if not (0xE000 <= ord(c) <= 0xF8FF))
        # Keep ASCII characters to be console-friendly on Windows
        clean = clean.encode('ascii', errors='ignore').decode('ascii')
        return clean.strip()
    
    # Refine niche text for maps query
    query_niche = niche
    if "architects" in niche:
        query_niche = "architects interior design"
    elif "wedding" in niche:
        query_niche = "wedding event planners"
    elif "furniture" in niche:
        query_niche = "custom furniture woodwork"
    elif "machinery" in niche:
        query_niche = "industrial machinery tool suppliers"
    elif "chartered" in niche:
        query_niche = "chartered accountants tax advisors"
        
    query = f"{query_niche} in {city}"
    query_encoded = urllib.parse.quote_plus(query)
    search_url = f"https://www.google.com/maps/search/{query_encoded}"
    
    leads = []
    print(f"\n[Search] Searching Google Maps for: '{query}'...")
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = context.new_page()
        
        try:
            page.goto(search_url, timeout=45000)
            page.wait_for_timeout(4000)
            
            # Handle cookie consent if visible
            for consent_text in ["Accept all", "Agree", "I agree", "Accept", "Consent"]:
                try:
                    btn = page.get_by_role("button", name=consent_text).first
                    if btn.count() > 0 and btn.is_visible():
                        btn.click()
                        page.wait_for_timeout(2000)
                        break
                except Exception:
                    pass

            # Check if there is a results sidebar
            feed_selector = 'div[role="feed"]'
            try:
                page.wait_for_selector(feed_selector, timeout=10000)
                feed = page.locator(feed_selector).first
                # Scroll a few times to load more places
                for _ in range(4):
                    feed.evaluate("el => el.scrollBy(0, 5000)")
                    page.wait_for_timeout(1500)
            except Exception:
                # If feed is not found, we might have been redirected to a single result
                pass
                
            # Get place links
            links = page.locator('a[href*="/maps/place/"]').all()
            place_urls = []
            for link in links:
                href = link.get_attribute("href")
                if href and href not in place_urls:
                    place_urls.append(href)
                    
            print(f"[Search] Discovered {len(place_urls)} place links. Navigating directly to extract details...")
            
            # Navigating directly to each place page is extremely stable
            for url in place_urls[:max_results]:
                try:
                    page.goto(url, timeout=30000)
                    page.wait_for_timeout(2000)
                    
                    # Extract name
                    name_locator = page.locator('h1').first
                    if name_locator.count() == 0:
                        continue
                    name = sanitize_scraped_text(name_locator.text_content())
                    
                    # Skip generic names or duplicates
                    if not name:
                        continue
                        
                    # Extract address (button[data-item-id="address"])
                    address = ""
                    addr_elem = page.locator('button[data-item-id="address"]').first
                    if addr_elem.count() > 0:
                        address = sanitize_scraped_text(addr_elem.text_content())
                        
                    # Extract phone number (button[data-item-id^="phone:tel:"])
                    phone = ""
                    phone_elem = page.locator('button[data-item-id^="phone:tel:"]').first
                    if phone_elem.count() > 0:
                        data_id = phone_elem.get_attribute("data-item-id")
                        phone = sanitize_scraped_text(data_id.replace("phone:tel:", ""))
                    else:
                        # Fallback for link selector
                        tel_link = page.locator('a[href^="tel:"]').first
                        if tel_link.count() > 0:
                            phone = sanitize_scraped_text(tel_link.get_attribute("href").replace("tel:", ""))
                            
                    # Extract website (a[data-item-id="authority"])
                    website = ""
                    web_elem = page.locator('a[data-item-id="authority"]').first
                    if web_elem.count() > 0:
                        website = sanitize_scraped_text(web_elem.get_attribute("href"))
                        
                    # Only save leads that have a phone number and DO NOT have a website
                    if name and phone and not website:
                        lead = {
                            "name": name,
                            "phone": phone,
                            "website": website,
                            "address": address,
                            "city": city,
                            "industry": niche
                        }
                        leads.append(lead)
                        print(f"    [+] Extracted: '{name}' | Phone: '{phone}'")
                    else:
                        print(f"    [-] Skipped '{name}' (No phone or already has website: '{website}')")
                except Exception as ex:
                    print(f"    [!] Error extracting place: {ex}")
                    
        except Exception as e:
            print(f"[!] Error loading search results: {e}")
            # Try single page parsing
            try:
                name_locator = page.locator('h1').first
                if name_locator.count() > 0:
                    name = sanitize_scraped_text(name_locator.text_content())
                    phone = ""
                    phone_elem = page.locator('button[data-item-id^="phone:tel:"]').first
                    if phone_elem.count() > 0:
                        phone = sanitize_scraped_text(phone_elem.get_attribute("data-item-id").replace("phone:tel:", ""))
                    website = ""
                    web_elem = page.locator('a[data-item-id="authority"]').first
                    if web_elem.count() > 0:
                        website = sanitize_scraped_text(web_elem.get_attribute("href"))
                    address = ""
                    addr_elem = page.locator('button[data-item-id="address"]').first
                    if addr_elem.count() > 0:
                        address = sanitize_scraped_text(addr_elem.text_content())
                        
                    if name and phone and not website:
                        lead = {
                            "name": name,
                            "phone": phone,
                            "website": website,
                            "address": address,
                            "city": city,
                            "industry": niche
                        }
                        leads.append(lead)
                        print(f"    [+] Single place extracted: '{name}' | Phone: '{phone}'")
                    else:
                        if website:
                            print(f"    [-] Skipped single place '{name}' (Already has website: '{website}')")
            except Exception as single_ex:
                print(f"[!] Single result extraction failed: {single_ex}")
                
        browser.close()
        
    return leads

def check_domain_available(domain_name):
    try:
        socket.gethostbyname(domain_name)
        return 0  # Resolves -> Taken
    except socket.gaierror:
        return 1  # Does not resolve -> Available
    except Exception:
        return 0

def sanitize_domain_prefix(business_name):
    clean = re.sub(r'[^a-zA-Z0-9]', '', business_name).lower()
    return clean if clean else "business"

def get_github_pages_url(lead_id):
    """
    Returns direct 24/7 permanent GitHub Pages HTTPS URL for a lead's mockup.
    GitHub Pages renders the full visual animated website with 100% proper text/html headers!
    """
    return f"https://obeygaming035-pixel.github.io/lead-finder/mockups/lead_{lead_id}.html"

def push_mockups_to_github():
    """Pushes generated mockups to GitHub repo to keep GitHub Pages live 24/7."""
    try:
        git_path = BASE_DIR / "git_portable" / "cmd" / "git.exe"
        if git_path.exists():
            subprocess.run([str(git_path), "add", "-f", "mockups/"], cwd=str(BASE_DIR), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([str(git_path), "commit", "-m", "Auto-update mockups for GitHub Pages"], cwd=str(BASE_DIR), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([str(git_path), "push", "origin", "main"], cwd=str(BASE_DIR), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"  [!] GitHub push note: {e}")

def shorten_url(long_url):
    """Returns direct clean HTTPS URL without any URL shortener redirect pages."""
    return long_url

def generate_mockup_html(business_name, industry, city, owner_name, phone="+91 98201 55667"):
    """
    Generates a top-tier institutional/agency-grade enterprise website.
    Features professional typography (Syne + Inter + Playfair Display),
    asymmetrical layout grids, interactive project matrices with detailed specs,
    live investment calculators, photo lightbox modals, and direct phone/WhatsApp links.
    """
    ind = industry.lower()
    biz_lower = business_name.lower()
    clean_phone = re.sub(r'\D', '', str(phone))

    if "architect" in ind or "interior" in ind:
        primary_color = "#0f172a"    # Slate Noir
        accent_color = "#3b82f6"     # Sapphire Azure
        accent_warm = "#d97706"      # Champagne Gold
        bg_surface = "#f8fafc"       # Porcelain Light
        card_bg = "#ffffff"
        border_color = "#e2e8f0"
        tagline = f"Architectural Planning, Structural Engineering & Luxury Interior Fit-Outs in {city}"
        
        if "interior" in biz_lower or "space" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1400&q=85"
        elif "blueprint" in biz_lower or "atelier" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1400&q=85"
        else:
            hero_img = "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1400&q=85"

        services = [
            {"title": f"{business_name.split()[0]} Luxury Villa Estates", "category": "residential", "location": f"Bandra West, {city}", "area": "8,500 Sq. Ft", "year": "2025 Handover", "desc": "Photorealistic 4K architectural elevations, Vastu-compliant structural planning, and bespoke interior execution.", "badge": "CoA License No. CA/2012/58914", "img": "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=800&q=80"},
            {"title": f"{city} Corporate Headquarters", "category": "commercial", "location": f"BKC Financial Center, {city}", "area": "25,000 Sq. Ft", "year": "2026 Active Build", "desc": "Turnkey commercial workspace layout, acoustic glass partitioning, modular workstations, and boardroom acoustic control.", "badge": "100% On-Time Completion SLA", "img": "https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80"},
            {"title": "Penthouse Sky Deck & Pool Villa", "category": "outdoor", "desc": "Teak wood decking, weather-resistant outdoor lounge joinery, automated facade illumination, and custom infinity plunge pools.", "location": f"Worli Sea Face, {city}", "area": "4,200 Sq. Ft", "year": "2025 Handover", "badge": "Custom VR 3D Walkthrough", "img": "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=80"}
        ]
        categories = [("all", "All Case Studies"), ("residential", "Luxury Residential"), ("commercial", "Corporate Workspaces"), ("outdoor", "Penthouses & Decks")]
        stat_1, stat_2, stat_3 = "150+ Built Landmark Projects", "Council of Architecture Accredited", "4.96 ★ Peer Rating"
        owner_title = f"Principal Architect {owner_name}"
        owner_bio = f"Lead Architect & Founder at {business_name}, {city}. Registered Member of the Council of Architecture (CoA) with 14+ years crafting iconic private residences and corporate headquarters in {city}."
        testimonial = f"\"{owner_name} designed our luxury bungalow in {city} with incredible precision. The 3D VR simulation was identical to the final handed-over build!\" — Ananya & Rahul Sharma"

        interactive_tool_html = f"""
        <div class="estimator-container reveal">
            <div style="display:flex; justify-content:space-between; align-items:flex-start; flex-wrap:wrap; gap:1rem; margin-bottom: 1.8rem;">
                <div>
                    <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.5rem; font-weight: 800;">Turnkey Investment & Area Estimator</h3>
                    <p style="color: #64748b; font-size: 0.95rem; margin-top: 0.3rem;">Calculate estimated turnkey architectural planning and fit-out budget in {city}.</p>
                </div>
                <div style="background:#e0e7ff; color:#3730a3; padding:0.4rem 1rem; border-radius:20px; font-weight:700; font-size:0.8rem;">Live Pricing Engine v4.2</div>
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem;">
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Property Classification:</label>
                    <select id="propType" onchange="calcArchCost()" class="input-field" style="margin-top: 0.5rem;">
                        <option value="4200">Luxury Independent Bungalow / Villa</option>
                        <option value="2900">Premium Penthouse Apartment</option>
                        <option value="3400">Corporate Office Fit-Out</option>
                    </select>
                </div>
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Built-Up Area: <span id="areaVal" style="color: var(--accent); font-weight: 800;">2,500 Sq. Ft</span></label>
                    <input type="range" id="areaRange" min="1000" max="10000" step="250" value="2500" oninput="calcArchCost()" style="width: 100%; margin-top: 1rem; accent-color: var(--accent);">
                </div>
            </div>
            <div style="margin-top: 2rem; background: #f1f5f9; padding: 1.6rem 2rem; border-radius: 16px; border: 1px solid #cbd5e1; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.2rem;">
                <div>
                    <div style="font-size: 0.85rem; color: #64748b; font-weight: 700; text-transform: uppercase;">Estimated Turnkey Capital Budget:</div>
                    <div id="estResult" style="font-size: 2.2rem; font-weight: 800; color: #0f172a; font-family: 'Syne', sans-serif;">₹1.05 Crore</div>
                </div>
                <button onclick="toggleModal()" class="btn-dark" style="border: none; cursor: pointer;">Schedule Technical Consultation &rarr;</button>
            </div>
        </div>
        """

    elif "wedding" in ind or "event" in ind:
        primary_color = "#1e1b4b"    # Deep Royal Indigo
        accent_color = "#be123c"     # Rose Crimson
        accent_warm = "#d97706"      # Imperial Gold
        bg_surface = "#faf7f5"       # Pearl Soft Ivory
        card_bg = "#ffffff"
        border_color = "#e2e8f0"
        tagline = f"Bespoke Destination Weddings, Palace Scenography & Royal Events in {city}"
        
        if "royal" in biz_lower or "grandeur" in biz_lower or "regal" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1545232979-fbf34fe37b38?auto=format&fit=crop&w=1400&q=85"
        elif "bliss" in biz_lower or "divine" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1400&q=85"
        else:
            hero_img = "https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1400&q=85"

        services = [
            {"title": f"{business_name.split()[0]} Rajasthan Palace Curation", "category": "palace", "location": f"Udaipur & {city}", "area": "3-Day Royal Gala", "year": "2025 Curation", "desc": "Turnkey heritage palace bookings, royal elephant welcome processions, and multi-day hospitality for prominent families.", "badge": "5-Star Heritage Partner", "img": "https://images.unsplash.com/photo-1545232979-fbf34fe37b38?auto=format&fit=crop&w=800&q=80"},
            {"title": "Bespoke Floral Scenography & Mandap", "category": "decor", "location": f"South {city} Lawns", "area": "60ft LED Stage", "year": "2025 Curation", "desc": "Custom 60ft LED backdrop stages, imported orchid mandap setups, ambient warm lighting, and pyrotechnic entries.", "badge": "Custom Scenography", "img": "https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=800&q=80"},
            {"title": "Celebrity Artists & Gourmet Royal Feast", "category": "catering", "location": f"Grand Hyatt, {city}", "area": "1,200 Guests", "year": "2025 Curation", "desc": "A-list Bollywood singer bookings, live Sufi bands, and 7-course multi-cuisine gourmet catering curation.", "badge": "5-Star Gourmet Catering", "img": "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?auto=format&fit=crop&w=800&q=80"}
        ]
        categories = [("all", "All Celebrations"), ("palace", "Palace Destinations"), ("decor", "Floral Scenography"), ("catering", "Royal Feasts")]
        stat_1, stat_2, stat_3 = "250+ Royal Weddings", "Exclusive Palace Partners", "100% Flawless Execution"
        owner_title = f"Lead Event Director {owner_name}"
        owner_bio = f"Founder & Principal Curator at {business_name}, {city}. Specializing in grand luxury destination weddings, royal galas, and bespoke scenography."
        testimonial = f"\"{owner_name} and the team curated our dream destination wedding in {city}. Every single function was executed with royal perfection!\" — Vikramaditya & Priya Kapoor"

        interactive_tool_html = f"""
        <div class="estimator-container reveal">
            <div style="display:flex; justify-content:space-between; align-items:flex-start; flex-wrap:wrap; gap:1rem; margin-bottom: 1.8rem;">
                <div>
                    <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.5rem; font-weight: 800;">Royal Wedding Guest & Budget Estimator</h3>
                    <p style="color: #64748b; font-size: 0.95rem; margin-top: 0.3rem;">Estimate total destination wedding curation budget in {city}.</p>
                </div>
                <div style="background:#ffe4e6; color:#9f1239; padding:0.4rem 1rem; border-radius:20px; font-weight:700; font-size:0.8rem;">Royal Estimator v4.2</div>
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem;">
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Venue Category:</label>
                    <select id="weddingType" onchange="calcWeddingCost()" class="input-field" style="margin-top: 0.5rem;">
                        <option value="6000">Heritage Palace / 5-Star Luxury Resort</option>
                        <option value="3500">Luxury Banquet & Royal Lawns</option>
                        <option value="9000">International / Island Destination</option>
                    </select>
                </div>
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Expected Guests: <span id="guestVal" style="color: var(--accent); font-weight: 800;">400 Guests</span></label>
                    <input type="range" id="guestRange" min="100" max="1500" step="50" value="400" oninput="calcWeddingCost()" style="width: 100%; margin-top: 1rem; accent-color: var(--accent);">
                </div>
            </div>
            <div style="margin-top: 2rem; background: #fff1f2; padding: 1.6rem 2rem; border-radius: 16px; border: 1px solid #fecdd3; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.2rem;">
                <div>
                    <div style="font-size: 0.85rem; color: #9f1239; font-weight: 700; text-transform: uppercase;">Estimated Full Curation Budget:</div>
                    <div id="weddingResult" style="font-size: 2.2rem; font-weight: 800; color: #be123c; font-family: 'Syne', sans-serif;">₹24.00 Lakhs</div>
                </div>
                <button onclick="toggleModal()" class="btn-dark" style="border: none; cursor: pointer; background: #be123c;">Reserve Dates with {owner_name.split()[0]} &rarr;</button>
            </div>
        </div>
        """

    elif "furniture" in ind or "woodwork" in ind:
        primary_color = "#064e3b"    # Deep Forest Teak
        accent_color = "#047857"     # Emerald Green
        accent_warm = "#d97706"      # Amber Teak
        bg_surface = "#f4f8f6"       # Mint Porcelain
        card_bg = "#ffffff"
        border_color = "#e2e8f0"
        tagline = f"Handcrafted Solid Teak Furniture & Custom Architectural Joinery in {city}"
        
        if "teak" in biz_lower or "wood" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1617806118233-18e1de247200?auto=format&fit=crop&w=1400&q=85"
        elif "oak" in biz_lower or "maharaja" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1538688525198-9b88f6f53126?auto=format&fit=crop&w=1400&q=85"
        else:
            hero_img = "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=1400&q=85"

        services = [
            {"title": f"{business_name.split()[0]} Solid Teak Dining Sets", "category": "dining", "location": f"Workshop Studio, {city}", "area": "8-Seater Set", "year": "2025 Build", "desc": "8-seater CP Teak wood dining tables with velvet upholstered chairs and PU matte finish, built directly in {city}.", "badge": "Lifetime Wood Warranty", "img": "https://images.unsplash.com/photo-1617806118233-18e1de247200?auto=format&fit=crop&w=800&q=80"},
            {"title": "Custom L-Shape Velvet Lounges", "category": "living", "location": f"Showroom, {city}", "area": "Custom Size", "year": "2025 Build", "desc": "Solid Sheesham hardwood internal framing, 40D Sleepwell foam, and stain-resistant imported upholstery fabrics.", "badge": "Custom Dimensions", "img": "https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=800&q=80"},
            {"title": "Executive Mahogany Office Desks", "category": "office", "location": f"Corporate Fit-Out, {city}", "area": "Managerial Desk", "year": "2025 Build", "desc": "Bespoke managerial desks with integrated wire grommets, leatherette inlays, and lockable storage drawers.", "badge": "Direct Workshop Price", "img": "https://images.unsplash.com/photo-1538688525198-9b88f6f53126?auto=format&fit=crop&w=800&q=80"}
        ]
        categories = [("all", "All Craftworks"), ("dining", "Teak Dining Sets"), ("living", "Velvet Lounges"), ("office", "Executive Desks")]
        stat_1, stat_2, stat_3 = "2,500+ Crafted Pieces", "100% Solid Teak Wood", "Direct Workshop Rates"
        owner_title = f"Master Craftsman {owner_name}"
        owner_bio = f"Proprietor & Master Craftsman at {business_name}, {city}. Handcrafting solid teak and mahogany furniture directly from our workshop with zero retail markup."
        testimonial = f"\"{owner_name}'s workshop built a customized teak dining table for our home in {city}. The grain texture and PU polish are divine!\" — Col. Alok Mathur"

        interactive_tool_html = f"""
        <div class="estimator-container reveal">
            <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.5rem; font-weight: 800; margin-bottom: 0.4rem;">🛋️ Interactive Wood & Polish Finish Selector</h3>
            <p style="color: #64748b; font-size: 0.95rem; margin-bottom: 1.6rem;">Select a premium polish to preview wood texture & protective topcoat finish.</p>
            <div style="display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.6rem;">
                <button onclick="setWood('CP Teak Wood (Natural Gold Polish)', '#d97706')" class="tab-btn active">Natural Teak Gold</button>
                <button onclick="setWood('Dark Walnut Matte Polish', '#451a03')" class="tab-btn">Dark Walnut Matte</button>
                <button onclick="setWood('Imperial Mahogany Red Satin', '#7f1d1d')" class="tab-btn">Imperial Mahogany</button>
            </div>
            <div style="background: #ecfdf5; padding: 1.5rem 1.8rem; border-radius: 16px; border-left: 5px solid #047857;">
                <div style="color: #0f172a; font-weight: 800; font-size: 1.15rem;" id="selectedWood">Active Finish: CP Teak Wood (Natural Gold Polish)</div>
                <div style="color: #475569; font-size: 0.9rem; margin-top: 0.4rem;">Seasoned against termites & moisture | Hand-buffed PU lacquer finish</div>
            </div>
        </div>
        """

    elif "machinery" in ind or "tool" in ind:
        primary_color = "#0f172a"
        accent_color = "#0284c7"
        accent_warm = "#2563eb"
        bg_surface = "#f4f8fb"
        card_bg = "#ffffff"
        border_color = "#e2e8f0"
        tagline = f"High-Precision CNC Machining Centers, Industrial Tools & Equipment in {city}"
        
        if "precision" in biz_lower or "cnc" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1400&q=85"
        elif "tool" in biz_lower or "indotech" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1581092335397-9583fe92d232?auto=format&fit=crop&w=1400&q=85"
        else:
            hero_img = "https://images.unsplash.com/photo-1504917599217-d4dc5ebe6122?auto=format&fit=crop&w=1400&q=85"

        services = [
            {"title": f"{business_name.split()[0]} 5-Axis CNC VMC Centers", "category": "cnc", "location": f"Industrial Area, {city}", "area": "5-Axis Machine", "year": "2025 Dispatch", "desc": "Heavy-duty slant bed CNC lathes and 5-axis vertical machining centers engineered for {city} industrial plants.", "badge": "ISO 9001 Certified", "img": "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=800&q=80"},
            {"title": "Hydraulic Sheet Metal Presses", "category": "hydraulic", "location": f"Manufacturing Plant, {city}", "area": "500T Capacity", "year": "2025 Dispatch", "desc": "100T to 500T hydraulic presses, CNC shearing machines, and press brakes engineered for metal fabrication.", "badge": "Pan-India Installation", "img": "https://images.unsplash.com/photo-1504917599217-d4dc5ebe6122?auto=format&fit=crop&w=800&q=80"},
            {"title": "Carbide Cutting Tooling & Inserts", "category": "tooling", "location": f"Warehouse, {city}", "area": "Stock Ready", "year": "Same-Day Dispatch", "desc": "High-speed steel carbide inserts, digital micrometers, and precision height gauges for workshop QC.", "badge": "ISO Certified", "img": "https://images.unsplash.com/photo-1581092335397-9583fe92d232?auto=format&fit=crop&w=800&q=80"}
        ]
        categories = [("all", "All Machinery"), ("cnc", "CNC VMC Centers"), ("hydraulic", "Hydraulic Presses"), ("tooling", "Carbide Tooling")]
        stat_1, stat_2, stat_3 = "1,000+ CNC Machines Sold", "24/7 Field Engineers", "Direct Importer"
        owner_title = f"Managing Director {owner_name}"
        owner_bio = f"Managing Director at {business_name}, {city}. Mechanical Engineer supplying high-precision industrial CNC machinery and tooling across India."
        testimonial = f"\"{owner_name}'s firm supplied all our VMC machines in {city}. Prompt installation, genuine controllers, and outstanding technical support.\" — Rajesh Mehta, Works Director"

        interactive_tool_html = f"""
        <div class="estimator-container reveal">
            <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.5rem; font-weight: 800; margin-bottom: 0.4rem;">⚙️ Interactive CNC Machine Technical Specs</h3>
            <p style="color: #64748b; font-size: 0.95rem; margin-bottom: 1.6rem;">Technical specification parameters for industrial manufacturing in {city}.</p>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.2rem;">
                <div style="background: #f0f9ff; padding: 1.4rem; border-radius: 14px; border-top: 4px solid #0284c7;">
                    <div style="color: #64748b; font-size: 0.8rem; font-weight: 700;">Spindle Speed:</div>
                    <div style="color: #0f172a; font-weight: 800; font-size: 1.4rem;">12,000 RPM</div>
                </div>
                <div style="background: #f0f9ff; padding: 1.4rem; border-radius: 14px; border-top: 4px solid #0284c7;">
                    <div style="color: #64748b; font-size: 0.8rem; font-weight: 700;">CNC Controller:</div>
                    <div style="color: #0f172a; font-weight: 800; font-size: 1.4rem;">Siemens / Fanuc</div>
                </div>
                <div style="background: #f0f9ff; padding: 1.4rem; border-radius: 14px; border-top: 4px solid #0284c7;">
                    <div style="color: #64748b; font-size: 0.8rem; font-weight: 700;">ATC Tool Capacity:</div>
                    <div style="color: #0f172a; font-weight: 800; font-size: 1.4rem;">24 Tools Arm-Type</div>
                </div>
            </div>
        </div>
        """

    elif "chartered" in ind or "tax" in ind or "accountant" in ind:
        primary_color = "#047857"
        accent_color = "#059669"
        accent_warm = "#1e3a8a"
        bg_surface = "#f4f8f6"
        card_bg = "#ffffff"
        border_color = "#e2e8f0"
        tagline = f"Statutory Financial Audit, Corporate GST & Income Tax Advisory in {city}"
        
        if "tax" in biz_lower or "agrawal" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1400&q=85"
        elif "kapoor" in biz_lower or "jain" in biz_lower:
            hero_img = "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1400&q=85"
        else:
            hero_img = "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1400&q=85"

        services = [
            {"title": f"{business_name.split()[0]} Corporate Tax & GST", "category": "gst", "location": f"Corporate Office, {city}", "area": "Annual Retainer", "year": "2025 Compliance", "desc": "GST registration, monthly GSTR-1 & 3B filings, annual GST audits, and tax litigation representation in {city}.", "badge": "100% Compliance SLA", "img": "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=800&q=80"},
            {"title": "Pvt Ltd & LLP Incorporation", "category": "setup", "location": f"ROC {city}", "area": "Fast Setup", "year": "2025 Execution", "desc": "Fast company incorporation, ROC filings, secretarial compliance, and startup valuation certifications.", "badge": "3-Day Fast Setup", "img": "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80"},
            {"title": "Statutory Financial Audits", "category": "audit", "location": f"Practice Office, {city}", "area": "Statutory Audit", "year": "2025 Certification", "desc": "Balance sheet audit certification, internal financial controls audit, and corporate M&A due diligence.", "badge": "ICAI Certified", "img": "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=800&q=80"}
        ]
        categories = [("all", "All Practices"), ("gst", "Corporate Tax & GST"), ("setup", "Company Setup"), ("audit", "Statutory Audits")]
        stat_1, stat_2, stat_3 = "500+ Corporate Retainers", "15+ Years Practice", "ICAI Certified Firm"
        owner_title = f"Senior Partner CA {owner_name}"
        owner_bio = f"Senior Partner & FCA at {business_name}, {city}. Fellow Member of the ICAI specializing in corporate taxation, GST audits, and corporate restructuring."
        testimonial = f"\"CA {owner_name} has managed our corporate tax filings and GST audits in {city} for 6 years. Proactive, reliable, and highly knowledgeable.\" — Suresh Patel, CFO"

        interactive_tool_html = f"""
        <div class="estimator-container reveal">
            <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.5rem; font-weight: 800; margin-bottom: 0.4rem;">📊 Interactive Corporate Retainer Calculator</h3>
            <p style="color: #64748b; font-size: 0.95rem; margin-bottom: 1.6rem;">Estimate annual corporate compliance & retainer fees for your business in {city}.</p>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem;">
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Annual Turnover Range:</label>
                    <select id="caTurnover" onchange="calcCATax()" class="input-field" style="margin-top: 0.5rem;">
                        <option value="2500">Up to ₹50 Lakhs (GST + IT Filing)</option>
                        <option value="5000">₹50 Lakhs to ₹2 Crore (Full Retainer)</option>
                        <option value="12000">Above ₹2 Crore (Statutory Audit + GST)</option>
                    </select>
                </div>
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Monthly Invoices: <span id="invVal" style="color: var(--accent); font-weight: 800;">100 Invoices</span></label>
                    <input type="range" id="invRange" min="20" max="500" step="20" value="100" oninput="calcCATax()" style="width: 100%; margin-top: 1rem; accent-color: var(--accent);">
                </div>
            </div>
            <div style="margin-top: 2rem; background: #f0fdf4; padding: 1.6rem 2rem; border-radius: 16px; border: 1px solid #bbf7d0; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.2rem;">
                <div>
                    <div style="font-size: 0.85rem; color: #047857; font-weight: 700; text-transform: uppercase;">Estimated Monthly Retainer Fee:</div>
                    <div id="caResult" style="font-size: 2.2rem; font-weight: 800; color: #047857; font-family: 'Syne', sans-serif;">₹6,000 / Month</div>
                </div>
                <button onclick="toggleModal()" class="btn-dark" style="border: none; cursor: pointer; background: #047857;">Consult CA {owner_name.split()[0]} &rarr;</button>
            </div>
        </div>
        """

    else:  # Generic fallback theme (tailored dynamically to any industry/genre!)
        primary_color = "#1e293b"    # Charcoal Slate
        accent_color = "#0f766e"     # Deep Teal
        accent_warm = "#b45309"      # Rich Amber
        bg_surface = "#f8fafc"
        card_bg = "#ffffff"
        border_color = "#e2e8f0"
        
        clean_ind = industry.title()
        tagline = f"Premium {clean_ind} & Professional Turnkey Operations in {city}"
        hero_img = "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1400&q=85"
        
        services = [
            {
                "title": f"Bespoke {clean_ind} Solutions", 
                "category": "consulting", 
                "location": f"Main District, {city}", 
                "area": "Full Turnkey", 
                "year": "2026 Season", 
                "desc": f"Tailored planning and end-to-end execution of professional {industry} services for premium clients in {city}.", 
                "badge": "Top Rated Provider", 
                "img": "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=800&q=80"
            },
            {
                "title": f"Premium {clean_ind} Maintenance", 
                "category": "support", 
                "location": f"Regional Area, {city}", 
                "area": "Annual Support", 
                "year": "2026 Execution", 
                "desc": f"Round-the-clock support, quality control checks, and certified executive management of your {industry} requirements.", 
                "badge": "Premium Quality SLA", 
                "img": "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80"
            },
            {
                "title": f"Executive {clean_ind} Consulting", 
                "category": "strategy", 
                "location": f"Corporate Desk, {city}", 
                "area": "Audited Operations", 
                "year": "2026 Certification", 
                "desc": f"Technical audit and expert advisory to optimize and certify all parameters of your {industry} systems.", 
                "badge": "Certified Advisory", 
                "img": "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=800&q=80"
            }
        ]
        
        categories = [
            ("all", "All Operations"), 
            ("consulting", "Bespoke Solutions"), 
            ("support", "Premium Support"), 
            ("strategy", "Executive Advisory")
        ]
        
        stat_1, stat_2, stat_3 = "500+ Local Projects", "Certified Partners", "100% Satisfaction Guarantee"
        owner_title = f"Principal Director {owner_name}"
        owner_bio = f"Director & Chief Advisor at {business_name}, {city}. Leading certified {industry} operations with 12+ years of local execution experience."
        testimonial = f"\"The team at {business_name} delivered outstanding {industry} results. Highly professional and seamless communication throughout!\" — Rajesh Sharma, Director"
        
        interactive_tool_html = f"""
        <div class="estimator-container reveal">
            <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.5rem; font-weight: 800; margin-bottom: 0.4rem;">📊 Turnkey {clean_ind} Service Calculator</h3>
            <p style="color: #64748b; font-size: 0.95rem; margin-bottom: 1.6rem;">Estimate monthly or turnkey service budgets in {city}.</p>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem;">
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Service Scope:</label>
                    <select id="genericService" onchange="calcGenericCost()" class="input-field" style="margin-top: 0.5rem;">
                        <option value="1500">Essential Planning & Setup</option>
                        <option value="4500">Premium Comprehensive Plan</option>
                        <option value="9500">Enterprise Turnkey Operations</option>
                    </select>
                </div>
                <div>
                    <label style="color: #334155; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">Estimated Size: <span id="genericSize" style="color: var(--accent); font-weight: 800;">10 Units</span></label>
                    <input type="range" id="genericRange" min="2" max="100" step="2" value="10" oninput="calcGenericCost()" style="width: 100%; margin-top: 1rem; accent-color: var(--accent);">
                </div>
            </div>
            <div style="margin-top: 2rem; background: #f0fdf4; padding: 1.6rem 2rem; border-radius: 16px; border: 1px solid #99f6e4; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.2rem;">
                <div>
                    <div style="font-size: 0.85rem; color: #0f766e; font-weight: 700; text-transform: uppercase;">Estimated Project Budget:</div>
                    <div id="genericResult" style="font-size: 2.2rem; font-weight: 800; color: #0f766e; font-family: 'Syne', sans-serif;">₹15,000</div>
                </div>
                <button onclick="toggleModal()" class="btn-dark" style="border: none; cursor: pointer; background: #0f766e;">Request Full Quote &rarr;</button>
            </div>
        </div>
        
        <script>
            function calcGenericCost() {{
                var base = parseFloat(document.getElementById("genericService").value);
                var size = parseFloat(document.getElementById("genericRange").value);
                document.getElementById("genericSize").innerText = size + " Units";
                var total = base * size;
                document.getElementById("genericResult").innerText = "₹" + total.toLocaleString('en-IN');
            }}
        </script>
        """

    # Inject dynamic images from pool if available
    try:
        target_niche = industry
        # Ensure it matches one of our target niches
        valid_niches = [
            "architects & interior design studios",
            "wedding & luxury event planners",
            "custom furniture & woodwork studios",
            "industrial machinery & tool suppliers",
            "chartered accountants & tax advisory firms"
        ]
        if target_niche in valid_niches:
            imgs = get_random_images(target_niche, count=len(services) + 1)
            if imgs and len(imgs) >= len(services) + 1:
                hero_img = imgs[0] + "?auto=format&fit=crop&w=1400&q=85"
                for idx in range(len(services)):
                    services[idx]["img"] = imgs[idx+1] + "?auto=format&fit=crop&w=800&q=80"
    except Exception as img_err:
        print(f"  [!] Dynamic image injection note: {img_err}")

    # Pre-compute complex HTML loops to avoid Python f-string backslash/quote limitations in older versions (e.g. 3.11)
    category_buttons = "".join([f'<button onclick="filterCategory(\'{cat[0]}\')" class="filter-tab {"active" if i==0 else ""}" data-cat="{cat[0]}">{cat[1]}</button>' for i, cat in enumerate(categories)])
    
    services_html = "".join([f'''
    <div class="card reveal" data-category="{s["category"]}" onclick="openLightbox(\'{s["img"]}\')">
        <img src="{s["img"]}" class="card-img" alt="{s["title"]}" loading="lazy">
        <div class="card-content">
            <div>
                <div class="spec-list">
                    <span class="spec-item">📍 {s["location"]}</span>
                    <span class="spec-item">📐 {s["area"]}</span>
                    <span class="spec-item">🗓️ {s["year"]}</span>
                </div>
                <h3>{s["title"]}</h3>
                <p>{s["desc"]}</p>
            </div>
            <div class="card-badge">{s["badge"]} &bull; Zoom 🔍</div>
        </div>
    </div>
    ''' for s in services])

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>{business_name} | Enterprise {industry.title()} in {city}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {{
            --primary: {primary_color};
            --accent: {accent_color};
            --accent-warm: {accent_warm};
            --bg: {bg_surface};
            --card: {card_bg};
            --border: {border_color};
        }}

        *, *:before, *:after {{ margin: 0; padding: 0; box-sizing: border-box !important; }}
        html, body {{ 
            width: 100% !important; 
            max-width: 100% !important; 
            margin: 0 !important; 
            padding: 0 !important; 
            overflow-x: hidden !important; 
            background-color: var(--bg); 
            color: #0f172a; 
            line-height: 1.45; 
            font-family: 'Plus Jakarta Sans', 'Inter', system-ui, -apple-system, sans-serif;
            scroll-behavior: smooth;
        }}

        h1, h2, h3, h4, .brand-text {{ font-family: 'Plus Jakarta Sans', sans-serif; letter-spacing: normal !important; font-stretch: normal !important; word-break: break-word !important; overflow-wrap: break-word !important; }}

        /* SMOOTH SCROLL REVEAL CLASS */
        .reveal {{
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.5s ease-out, transform 0.5s ease-out;
        }}
        .reveal.active {{
            opacity: 1;
            transform: translateY(0px);
        }}

        #scroll-progress {{ position: fixed; top: 0; left: 0; height: 3px; background: linear-gradient(90deg, var(--accent), var(--accent-warm)); width: 0%; z-index: 1000; transition: width 0.1s linear; }}

        nav {{ background: rgba(255, 255, 255, 0.96); backdrop-filter: blur(16px); padding: 0.75rem 1.2rem; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; border-bottom: 1px solid var(--border); width: 100%; box-shadow: 0 2px 10px rgba(0,0,0,0.03); gap: 0.5rem; box-sizing: border-box; }}
        .brand-text {{ font-size: clamp(0.9rem, 3.5vw, 1.15rem); font-weight: 800; color: #0f172a; display: flex; align-items: center; gap: 0.4rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 70%; }}
        .brand-text span {{ color: var(--accent); }}

        .btn-dark {{ background: #0f172a; color: #ffffff; padding: 0.5rem 0.95rem; border-radius: 25px; font-weight: 700; font-size: clamp(0.72rem, 2.2vw, 0.82rem); text-decoration: none; transition: all 0.2s ease; white-space: nowrap; display: inline-flex; align-items: center; gap: 0.3rem; border: none; cursor: pointer; flex-shrink: 0; box-shadow: 0 3px 10px rgba(15,23,42,0.12); }}
        .btn-dark:hover {{ background: var(--accent); }}

        /* HERO SECTION */
        .hero {{ padding: 2rem 1.2rem 1.8rem; display: grid; grid-template-columns: 1fr; gap: 1.8rem; align-items: center; border-bottom: 1px solid var(--border); max-width: 1140px; margin: 0 auto; width: 100%; box-sizing: border-box; overflow: hidden; }}
        .hero-text {{ width: 100%; max-width: 100%; min-width: 0; }}
        .hero-badge {{ display: inline-flex; align-items: center; gap: 0.4rem; background: #ffffff; border: 1px solid var(--border); padding: 0.3rem 0.75rem; border-radius: 20px; font-size: clamp(0.7rem, 2vw, 0.78rem); font-weight: 700; color: var(--accent); margin-bottom: 0.8rem; max-width: 100%; box-shadow: 0 2px 6px rgba(0,0,0,0.02); line-height: 1.3; }}
        .live-dot {{ width: 7px; height: 7px; background: #22c55e; border-radius: 50%; display: inline-block; box-shadow: 0 0 6px #22c55e; flex-shrink: 0; }}

        .hero h1 {{ font-size: clamp(1.4rem, 4vw, 2.3rem); font-weight: 800; line-height: 1.2; color: #0f172a; margin-bottom: 0.8rem; word-break: break-word; overflow-wrap: break-word; max-width: 100%; }}
        .hero h1 span {{ color: var(--accent); }}
        .hero p {{ font-size: clamp(0.88rem, 2.2vw, 1rem); color: #475569; margin-bottom: 1.2rem; max-width: 600px; line-height: 1.5; }}

        .hero-img-card {{ position: relative; border-radius: 14px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 10px 25px rgba(0,0,0,0.05); width: 100%; cursor: pointer; max-width: 100%; box-sizing: border-box; }}
        .hero-img-card img {{ width: 100%; height: auto; max-height: 320px; object-fit: cover; display: block; }}
        .hero-img-overlay {{ position: absolute; bottom: 0; left: 0; right: 0; background: linear-gradient(transparent, rgba(15, 23, 42, 0.94)); padding: 0.9rem; color: #ffffff; }}

        .stats-ribbon {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; margin-top: 1.2rem; width: 100%; box-sizing: border-box; }}
        .stat-card {{ background: #ffffff; padding: 0.7rem 0.4rem; border-radius: 10px; border: 1px solid var(--border); text-align: center; box-shadow: 0 2px 6px rgba(0,0,0,0.02); }}
        .stat-card .val {{ font-size: clamp(0.9rem, 2.5vw, 1.2rem); font-weight: 800; color: #0f172a; font-family: 'Plus Jakarta Sans', sans-serif; line-height: 1.2; }}
        .stat-card .lbl {{ font-size: clamp(0.62rem, 1.8vw, 0.72rem); color: #64748b; font-weight: 700; margin-top: 0.2rem; line-height: 1.2; }}

        /* INFINITE MARQUEE BAR */
        .marquee-bar {{ overflow: hidden !important; white-space: nowrap !important; padding: 0.5rem 0; background: #ffffff; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); margin-top: 1.2rem; width: 100% !important; max-width: 100% !important; position: relative; contain: content; }}
        @keyframes marqueeScroll {{ 0% {{ transform: translateX(0%); }} 100% {{ transform: translateX(-50%); }} }}
        .marquee-track {{ display: inline-flex; gap: 1.5rem; animation: marqueeScroll 25s linear infinite; }}
        .marquee-item {{ font-size: 0.72rem; font-weight: 800; color: #475569; letter-spacing: 0.5px; text-transform: uppercase; display: flex; align-items: center; gap: 0.3rem; }}

        /* SECTION STYLING */
        .section {{ padding: 2.2rem 1.2rem; max-width: 1140px; margin: 0 auto; width: 100%; box-sizing: border-box; overflow: hidden; }}
        .sec-header {{ text-align: center; margin-bottom: 1.8rem; }}
        .sec-header h2 {{ font-size: clamp(1.3rem, 3.5vw, 1.9rem); font-weight: 800; color: #0f172a; margin-bottom: 0.3rem; }}
        .sec-header p {{ color: #64748b; font-size: clamp(0.85rem, 2.2vw, 0.95rem); }}

        .filter-tabs {{ display: flex; justify-content: center; gap: 0.4rem; flex-wrap: wrap; margin-bottom: 1.5rem; }}
        .filter-tab {{ background: #ffffff; border: 1px solid #cbd5e1; color: #475569; padding: 0.4rem 0.85rem; border-radius: 20px; font-weight: 700; font-size: 0.78rem; cursor: pointer; transition: all 0.2s ease; }}
        .filter-tab.active, .filter-tab:hover {{ background: #0f172a; color: #ffffff; border-color: #0f172a; }}

        /* FLUID CASE STUDY GRID */
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(min(260px, 100%), 1fr)); gap: 1.2rem; width: 100%; box-sizing: border-box; }}
        .card {{ background: #ffffff; border: 1px solid var(--border); border-radius: 14px; overflow: hidden; transition: transform 0.2s ease, border-color 0.3s ease; display: flex; flex-direction: column; box-shadow: 0 4px 15px rgba(0,0,0,0.03); width: 100%; max-width: 100%; box-sizing: border-box; cursor: pointer; }}
        .card:hover {{ border-color: var(--accent); }}
        .card-img {{ width: 100%; height: 180px; object-fit: cover; }}
        .card-content {{ padding: 1.1rem; flex-grow: 1; display: flex; flex-direction: column; justify-content: space-between; }}
        .card h3 {{ font-size: clamp(1rem, 2.5vw, 1.18rem); color: #0f172a; margin-bottom: 0.4rem; font-weight: 800; }}
        .card p {{ color: #475569; font-size: 0.85rem; margin-bottom: 0.9rem; line-height: 1.45; }}
        
        .spec-list {{ display: flex; gap: 0.4rem; flex-wrap: wrap; margin-bottom: 0.8rem; padding-bottom: 0.5rem; border-bottom: 1px solid #f1f5f9; font-size: 0.7rem; color: #64748b; font-weight: 700; }}
        .spec-item {{ display: flex; align-items: center; gap: 0.2rem; background: #f8fafc; padding: 0.2rem 0.45rem; border-radius: 4px; border: 1px solid #e2e8f0; }}

        .card-badge {{ background: #f1f5f9; border: 1px solid #cbd5e1; color: #0f172a; padding: 0.28rem 0.65rem; border-radius: 14px; font-size: 0.72rem; font-weight: 800; width: fit-content; }}

        .estimator-container {{ background: #ffffff; border: 1px solid var(--border); border-radius: 14px; padding: 1.1rem; margin-top: 1.8rem; width: 100%; max-width: 100%; box-sizing: border-box; }}
        .input-field {{ background: #ffffff; border: 1px solid #cbd5e1; color: #0f172a; padding: 0.75rem 0.85rem; border-radius: 8px; font-size: 0.85rem; outline: none; transition: border-color 0.3s; width: 100%; font-family: inherit; box-sizing: border-box; }}
        .input-field:focus {{ border-color: var(--accent); }}
        .tab-btn {{ background: #ffffff; border: 1px solid #cbd5e1; color: #475569; padding: 0.45rem 0.85rem; border-radius: 18px; font-weight: 700; font-size: 0.75rem; cursor: pointer; transition: all 0.2s ease; }}
        .tab-btn.active, .tab-btn:hover {{ background: #0f172a; color: #ffffff; border-color: #0f172a; }}

        .owner-card {{ background: #ffffff; border: 1px solid var(--border); border-left: 4px solid #0f172a; padding: 1.1rem; border-radius: 12px; margin-top: 1.8rem; display: flex; align-items: center; gap: 0.9rem; flex-wrap: wrap; width: 100%; box-sizing: border-box; }}
        .owner-avatar {{ background: #0f172a; color: #ffffff; width: 52px; height: 52px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; font-weight: 800; flex-shrink: 0; font-family: 'Plus Jakarta Sans', sans-serif; }}
        .owner-info h4 {{ font-size: clamp(1rem, 2.8vw, 1.2rem); color: #0f172a; font-weight: 800; }}
        .owner-info p {{ color: #475569; font-size: 0.85rem; margin-top: 0.2rem; line-height: 1.4; }}

        .whatsapp-float {{ position: fixed; bottom: 14px; right: 14px; background: #25d366; color: white; padding: 0.6rem 1rem; border-radius: 35px; text-decoration: none; font-weight: 800; font-size: 0.78rem; display: flex; align-items: center; gap: 0.35rem; box-shadow: 0 4px 15px rgba(37, 211, 102, 0.4); z-index: 1000; max-width: calc(100% - 28px); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; box-sizing: border-box; }}

        /* LIGHTBOX IMAGE MODAL */
        .lightbox-modal {{ position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(15, 23, 42, 0.92); backdrop-filter: blur(10px); display: none; align-items: center; justify-content: center; z-index: 3000; padding: 1rem; }}
        .lightbox-content {{ max-width: 800px; width: 100%; max-height: 80vh; border-radius: 12px; overflow: hidden; background: #fff; position: relative; }}
        .lightbox-img {{ width: 100%; height: 100%; max-height: 70vh; object-fit: cover; display: block; }}

        .modal-overlay {{ position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(10px); display: none; align-items: center; justify-content: center; z-index: 2000; padding: 1rem; }}
        .modal-box {{ background: #ffffff; border: 1px solid #cbd5e1; border-radius: 14px; padding: 1.3rem; max-width: 420px; width: 100%; position: relative; text-align: left; box-sizing: border-box; }}
        .close-btn {{ position: absolute; top: 0.7rem; right: 0.9rem; color: #64748b; font-size: 1.3rem; cursor: pointer; font-weight: 700; }}

        footer {{ background: #ffffff; padding: 1.8rem 1.2rem; text-align: center; border-top: 1px solid var(--border); color: #64748b; font-size: 0.8rem; margin-top: 2.5rem; width: 100%; box-sizing: border-box; }}

        @media (min-width: 900px) {{
            .hero {{ grid-template-columns: 1fr 1fr; padding: 3rem 1.2rem 2.5rem; gap: 2.5rem; }}
        }}
    </style>
</head>
<body>

    <div id="scroll-progress"></div>

    <nav>
        <div class="brand-text"><span>{business_name[:2].upper()}</span> {business_name}</div>
        <a href="tel:{phone}" class="btn-dark">Call CA</a>
    </nav>

    <section class="hero">
        <div class="hero-text reveal">
            <span class="hero-badge"><span class="live-dot"></span> Head Office: {city} &bull; Accepting New Engagements</span>
            <h1><span>{business_name}</span></h1>
            <p>{tagline}</p>

            <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                <button onclick="toggleModal()" class="btn-dark" style="padding: 0.65rem 1.2rem; cursor: pointer;">Explore Case Studies &rarr;</button>
                <a href="tel:{phone}" style="color: #0f172a; border: 1px solid var(--border); background: #ffffff; padding: 0.65rem 1.1rem; border-radius: 25px; text-decoration: none; font-weight: 700; font-size: 0.82rem; display: inline-flex; align-items: center; gap: 0.3rem;">Direct Call: {phone}</a>
            </div>

            <div class="stats-ribbon">
                <div class="stat-card">
                    <div class="val">{stat_1}</div>
                    <div class="lbl">Track Record</div>
                </div>
                <div class="stat-card">
                    <div class="val">{stat_2}</div>
                    <div class="lbl">Verified License</div>
                </div>
                <div class="stat-card">
                    <div class="val">{stat_3}</div>
                    <div class="lbl">Client Rating</div>
                </div>
            </div>

            <div class="marquee-bar">
                <div class="marquee-track">
                    <div class="marquee-item">🏆 ARCHITECTURAL DIGEST ACCREDITED</div>
                    <div class="marquee-item">⭐ FORBES TOP 100 FIRM</div>
                    <div class="marquee-item">💎 VOGUE LIVING FEATURED</div>
                    <div class="marquee-item">🏛️ COUNCIL CERTIFIED GOVERNANCE</div>
                    <div class="marquee-item">⚡ 100% ON-TIME EXECUTION SLA</div>
                    <div class="marquee-item">🏆 ARCHITECTURAL DIGEST ACCREDITED</div>
                    <div class="marquee-item">⭐ FORBES TOP 100 FIRM</div>
                    <div class="marquee-item">💎 VOGUE LIVING FEATURED</div>
                    <div class="marquee-item">🏛️ COUNCIL CERTIFIED GOVERNANCE</div>
                    <div class="marquee-item">⚡ 100% ON-TIME EXECUTION SLA</div>
                </div>
            </div>
        </div>

        <div class="hero-img-card reveal" onclick="openLightbox('{hero_img}')">
            <img src="{hero_img}" alt="{business_name}" loading="lazy">
            <div class="hero-img-overlay">
                <div style="font-weight: 800; font-size: 1rem; font-family:'Plus Jakarta Sans', sans-serif;">{business_name} ({city})</div>
                <div style="font-size: 0.78rem; color: #fbbf24; font-weight: 700; margin-top:0.15rem;">Supervised by {owner_name} | {phone}</div>
                <div style="font-size: 0.72rem; opacity: 0.85; margin-top: 0.15rem;">Click to expand photo lightbox 🔍</div>
            </div>
        </div>
    </section>

    <section class="section" id="services">
        <div class="sec-header reveal">
            <h2>Featured Case Studies</h2>
            <p>Bespoke execution tailored specifically for clients in {city}.</p>
        </div>

        <div class="filter-tabs reveal">
            {category_buttons}
        </div>

        <div class="grid" id="portfolioGrid">
            {services_html}
        </div>

        {interactive_tool_html}

        <div class="owner-card reveal">
            <div class="owner-avatar">{owner_name[0]}</div>
            <div class="owner-info">
                <h4>{owner_title}</h4>
                <p>{owner_bio}</p>
                <p style="margin-top:0.4rem; font-weight:800; color:#0f172a;">Direct Executive Desk: {phone}</p>
            </div>
        </div>

        <div class="reveal" style="background: #ffffff; border: 1px solid var(--border); padding: 1.4rem; border-radius: 16px; margin-top: 2rem; font-style: italic; color: #334155; font-size: 0.95rem; line-height: 1.6; box-shadow: 0 4px 15px rgba(0,0,0,0.02);">
            {testimonial}
        </div>
    </section>

    <a href="https://wa.me/{clean_phone}" target="_blank" class="whatsapp-float">
        WhatsApp {owner_name.split()[0]} ({phone})
    </a>

    <!-- LIGHTBOX IMAGE MODAL -->
    <div id="lightboxModal" class="lightbox-modal" onclick="closeLightbox()">
        <div class="lightbox-content" onclick="event.stopPropagation()">
            <span class="close-btn" onclick="closeLightbox()" style="position:absolute; top:0.6rem; right:1rem; color:#fff; z-index:10; background:rgba(0,0,0,0.6); width:34px; height:34px; border-radius:50%; display:flex; align-items:center; justify-content:center;">&times;</span>
            <img id="lightboxImg" class="lightbox-img" src="" alt="Full Preview">
        </div>
    </div>

    <!-- INQUIRY MODAL -->
    <div id="quoteModal" class="modal-overlay">
        <div class="modal-box">
            <span class="close-btn" onclick="toggleModal()">&times;</span>
            <h3 style="font-family:'Syne', sans-serif; color: #0f172a; font-size: 1.25rem; font-weight: 800; margin-bottom: 0.3rem;">Direct Executive Consultation</h3>
            <p style="color: #64748b; font-size: 0.88rem; margin-bottom: 1.2rem;">Connect directly with {owner_name} ({phone}) regarding your project in {city}.</p>
            <form onsubmit="handleModalSubmit(event)">
                <div style="margin-bottom: 0.9rem;">
                    <input type="text" class="input-field" placeholder="Your Full Name / Firm Name" required>
                </div>
                <div style="margin-bottom: 0.9rem;">
                    <input type="tel" class="input-field" placeholder="Your Direct Phone Number" required>
                </div>
                <div style="margin-bottom: 1.2rem;">
                    <textarea class="input-field" rows="3" placeholder="Project specifications in {city}..." required></textarea>
                </div>
                <button type="submit" class="btn-dark" style="width: 100%; border: none; cursor: pointer; font-size: 0.9rem; padding: 0.8rem; justify-content: center;">Submit Technical Request to {phone} &rarr;</button>
            </form>
            <div id="modalSuccess" style="display: none; margin-top: 1rem; color: #047857; text-align: center; font-weight: 800; font-size: 0.88rem;">
                ✓ Inquiry registered! {owner_name.split()[0]} will reply directly on WhatsApp ({phone}) within 2 hours.
            </div>
        </div>
    </div>

    <footer>
        <p>&copy; 2026 {business_name} ({city}). All rights reserved.</p>
        <p style="margin-top:0.3rem;">Direct Executive Line: {owner_name} | {phone} | {city}, India</p>
    </footer>

    <script>
        document.addEventListener("DOMContentLoaded", function() {{
            var observer = new IntersectionObserver(function(entries) {{
                entries.forEach(function(entry) {{
                    if (entry.isIntersecting) {{
                        entry.target.classList.add('active');
                    }}
                }});
            }}, {{ threshold: 0.1 }});

            document.querySelectorAll('.reveal').forEach(function(el) {{
                observer.observe(el);
            }});
        }});

        window.onscroll = function() {{
            var winScroll = document.body.scrollTop || document.documentElement.scrollTop;
            var height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
            var scrolled = (winScroll / height) * 100;
            document.getElementById("scroll-progress").style.width = scrolled + "%";
        }};

        function filterCategory(cat) {{
            var tabs = document.querySelectorAll('.filter-tab');
            tabs.forEach(function(t) {{ t.classList.remove('active'); }});
            var activeTab = document.querySelector('.filter-tab[data-cat="' + cat + '"]');
            if (activeTab) activeTab.classList.add('active');

            var cards = document.querySelectorAll('#portfolioGrid .card');
            cards.forEach(function(card) {{
                if (cat === 'all' || card.getAttribute('data-category') === cat) {{
                    card.style.display = 'flex';
                }} else {{
                    card.style.display = 'none';
                }}
            }});
        }}

        function openLightbox(imgSrc) {{
            document.getElementById("lightboxImg").src = imgSrc;
            document.getElementById("lightboxModal").style.display = "flex";
        }}

        function closeLightbox() {{
            document.getElementById("lightboxModal").style.display = "none";
        }}

        function toggleModal() {{
            var modal = document.getElementById("quoteModal");
            if (modal.style.display === "flex") {{
                modal.style.display = "none";
            }} else {{
                modal.style.display = "flex";
            }}
        }}

        function handleModalSubmit(e) {{
            e.preventDefault();
            document.getElementById("modalSuccess").style.display = "block";
            setTimeout(function() {{
                toggleModal();
                document.getElementById("modalSuccess").style.display = "none";
            }}, 2500);
        }}

        function calcArchCost() {{
            var rate = parseFloat(document.getElementById("propType").value);
            var area = parseFloat(document.getElementById("areaRange").value);
            document.getElementById("areaVal").innerText = area.toLocaleString('en-IN') + " Sq. Ft";
            var total = (rate * area) / 10000000;
            document.getElementById("estResult").innerText = "₹" + total.toFixed(2) + " Crore";
        }}

        function calcWeddingCost() {{
            var rate = parseFloat(document.getElementById("weddingType").value);
            var guests = parseFloat(document.getElementById("guestRange").value);
            document.getElementById("guestVal").innerText = guests + " Guests";
            var total = (rate * guests) / 100000;
            document.getElementById("weddingResult").innerText = "₹" + total.toFixed(2) + " Lakhs";
        }}

        function setWood(name, color) {{
            document.getElementById("selectedWood").innerText = "Active Finish: " + name;
        }}

        function calcCATax() {{
            var base = parseFloat(document.getElementById("caTurnover").value);
            var inv = parseFloat(document.getElementById("invRange").value);
            document.getElementById("invVal").innerText = inv + " Invoices";
            var total = base + (inv * 35);
            document.getElementById("caResult").innerText = "₹" + total.toLocaleString('en-IN') + " / Month";
        }}
    </script>

</body>
</html>"""
    return html

def create_pitches(lead_id, business_name, proposed_domain, city, owner_name, public_url=None):
    raw_url = public_url if public_url else f"{get_preview_url()}/lead_{lead_id}.html"
    live_url = shorten_url(raw_url)
    
    first_name = owner_name.split()[0] if owner_name else "there"
    
    initial_pitch = (
        f"Hey {first_name} 👋\n\n"
        f"I was researching top firms in {city} and built a custom animated website preview specifically for {business_name}:\n"
        f"👉 {live_url}\n\n"
        f"The matching domain ({proposed_domain}) and complete website design are ready to launch for your firm.\n\n"
        f"Would you be interested in taking this live this week? Let me know!"
    )
    
    followup_pitch = (
        f"Hey {first_name}, just following up on the website design preview I put together for {business_name}:\n"
        f"👉 {live_url}\n\n"
        f"The domain and full layout are available if you'd like to get it live. Let me know if you're interested!"
    )
    
    return initial_pitch, followup_pitch

def generate_dynamic_lead(idx):
    prefixes = [
        "Apex", "Vanguard", "Zenith", "Pinnacle", "Urban Craft", "Monarch",
        "Matrix", "Velocity", "Radiant", "Prism", "Titan", "Imperial",
        "Nexus", "Solace", "Horizon", "Element", "Forma", "Kratos",
        "Vivid", "Oasis", "Sterling", "Aura", "Starlight", "Nova",
        "Veritas", "Quantum", "Signature", "Prestige", "Elite", "Optima"
    ]
    cities = [
        "Mumbai", "Delhi", "Bangalore", "Pune", "Ahmedabad", "Surat",
        "Chennai", "Hyderabad", "Kolkata", "Jaipur", "Chandigarh", "Lucknow",
        "Indore", "Coimbatore", "Vadodara", "Kochi"
    ]
    
    niches_config = [
        ("architects & interior design studios", "Architecture Studio", [
            "Architect Anand Verma (Principal Architect)", "Architect Ritu Sharma (Lead Designer)",
            "Architect Siddharth Rao (Managing Partner)", "Architect Meera Nair (Founder)"
        ]),
        ("wedding & luxury event planners", "Luxury Events", [
            "Karan Malhotra (Founder & Event Director)", "Priya Sharma (Creative Director)",
            "Nandini Reddy (Event Curator)", "Arun Kumar (Event Director)"
        ]),
        ("custom furniture & woodwork studios", "Teak Woodworks", [
            "Dharmesh Shah (Master Craftsman)", "Vikram Joshi (Founder)",
            "Hitesh Patel (Proprietor)", "Arjun Singh (Master Woodcraftsman)"
        ]),
        ("industrial machinery & tool suppliers", "CNC Automation", [
            "Rajesh Mehta (Managing Director)", "Srinivas Rao (Technical Director)",
            "Sunil Deshmukh (Works Director)", "Nikhil Desai (Managing Director)"
        ]),
        ("chartered accountants & tax advisory firms", "Tax Advisors & CA", [
            "CA Suresh Verma (Senior Partner & FCA)", "CA Anil Kapoor (Senior Partner & FCA)",
            "CA Darshan Shah (FCA Partner)", "CA Manish Jain (Senior Tax Partner)"
        ])
    ]
    
    prefix = prefixes[idx % len(prefixes)]
    city = cities[(idx // len(prefixes)) % len(cities)]
    niche_info = niches_config[idx % len(niches_config)]
    
    industry = niche_info[0]
    suffix = niche_info[1]
    owner = niche_info[2][idx % len(niche_info[2])]
    
    name = f"{prefix} {suffix}"
    clean_prefix = re.sub(r'[^a-zA-Z0-9]', '', prefix).lower()
    clean_city = re.sub(r'[^a-zA-Z0-9]', '', city).lower()
    
    phone = f"+91 {random.randint(94000, 99999)} {random.randint(10000, 99999)}"
    email = f"contact@{clean_prefix}{clean_city}.in"
    
    return {
        "name": name,
        "industry": industry,
        "city": city,
        "phone": phone,
        "email": email,
        "owner": owner
    }

def run_crawler_loop():
    init_db()
    print("[+] Leads database initialized successfully.")

    # Wait for tunnel_url.txt so we never generate pitches with localhost
    tunnel_file = BASE_DIR / "tunnel_url.txt"
    print("[+] Waiting for public tunnel URL (run_tunnel.py must be running)...")
    for _ in range(120):
        if tunnel_file.exists() and tunnel_file.stat().st_size > 10:
            url = tunnel_file.read_text(encoding="utf-8").strip()
            if url.startswith("https://"):
                print(f"[+] Using public URL: {url}")
                break
        time.sleep(1)
    else:
        print("[!] WARNING: tunnel_url.txt not found. Pitches will use localhost fallback.")

    print("[+] Starting Live Google Maps lead generation loop...")

    # Cycle through target niches and cities
    niche_idx = 0
    city_idx = 0
    
    while True:
        current_niche = TARGET_NICHES[niche_idx % len(TARGET_NICHES)]
        current_city = TARGET_CITIES[city_idx % len(TARGET_CITIES)]
        
        print(f"\n" + "="*70)
        print(f"[Target] CRAWLER TARGET: Niche: '{current_niche}' | City: '{current_city}'")
        print("="*70)
        
        # Scrape leads dynamically based on configuration settings
        settings = load_settings()
        max_res = settings.get("max_results", 100)
        scraped_leads = scrape_google_maps_playwright(current_niche, current_city, max_results=max_res)
        
        if not scraped_leads:
            print("[!] No leads found on Google Maps. Moving to next target...")
            niche_idx += 1
            if niche_idx % len(TARGET_NICHES) == 0:
                city_idx += 1
            time.sleep(10)
            continue
            
        print(f"\n[+] Harvested {len(scraped_leads)} leads. Processing and deduplicating...")
        
        for lead_data in scraped_leads:
            biz_name = f"{lead_data['name']} ({lead_data['city']})"
            industry = lead_data['industry']
            city = lead_data['city']
            phone = lead_data['phone']
            website = lead_data['website']
            address = lead_data['address']
            
            # Generate owner name dynamically based on business name and niche
            owner_name = generate_owner_name(lead_data['name'], industry)
            
            # Generate email placeholder
            clean_biz_name = re.sub(r'[^a-zA-Z0-9]', '', lead_data['name']).lower()
            clean_city = re.sub(r'[^a-zA-Z0-9]', '', city).lower()
            email = f"contact@{clean_biz_name}.in" if not website else f"info@{clean_biz_name}.in"
            
            print(f"\n[Telemetry {datetime.now().strftime('%H:%M:%S')}] Processing Lead: '{biz_name}' | Phone: '{phone}'")
            
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            
            # De-duplicate by business name OR phone number to avoid hitting same client
            cursor.execute("SELECT id FROM leads WHERE business_name = ? OR phone = ?", (biz_name, phone))
            existing = cursor.fetchone()
            
            if not existing:
                domain_prefix = sanitize_domain_prefix(lead_data['name'])
                proposed_domain = f"{domain_prefix}.in"
                
                # Check domain availability
                available = check_domain_available(proposed_domain)
                status_text = "AVAILABLE" if available == 1 else "TAKEN"
                print(f"  -> Proposed Domain '{proposed_domain}': [{status_text}]")
                
                # 1. Generate Local Mockup HTML
                mockup_html = generate_mockup_html(biz_name, industry, city, owner_name, phone=phone)
                
                cursor.execute('''
                    INSERT INTO leads (business_name, industry, city, current_website, proposed_domain, domain_available, email, phone, owner_name)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (biz_name, industry, city, website if website else f"http://{domain_prefix}.co.in", proposed_domain, available, email, phone, owner_name))
                
                lead_id = cursor.lastrowid
                
                mockup_filename = f"lead_{lead_id}.html"
                mockup_filepath = MOCKUPS_DIR / mockup_filename
                with open(mockup_filepath, "w", encoding="utf-8") as f:
                    f.write(mockup_html)
                print(f"  -> Saved Local Mockup HTML: {mockup_filename}")
                
                # 2. Upload to GitHub Pages 24/7 Permanent Cloud Host & Create Pitches
                pub_url = get_github_pages_url(lead_id)
                import whatsapp_automation
                init_pitch = whatsapp_automation.generate_spintax_pitch(owner_name, biz_name, city, pub_url, proposed_domain)
                _, follow_pitch = create_pitches(lead_id, biz_name, proposed_domain, city, owner_name, public_url=pub_url)
                
                cursor.execute('''
                    UPDATE leads SET initial_pitch = ?, followup_pitch = ? WHERE id = ?
                ''', (init_pitch, follow_pitch, lead_id))
                conn.commit()
                push_mockups_to_github()
                
                # 3. Dynamic WhatsApp Outreach Dispatcher (controlled from web dashboard)
                whatsapp_dispatched = False
                settings = load_settings()
                whatsapp_enabled = settings.get("whatsapp_enabled", False)
                min_del = settings.get("min_delay", 90)
                max_del = settings.get("max_delay", 180)
                
                try:
                    if not whatsapp_enabled:
                        print(f"  -> [Outreach] Auto-WhatsApp is disabled in settings. Lead #{lead_id} status set to 'New'.")
                        whatsapp_automation.update_lead_status(lead_id, "New")
                    elif whatsapp_automation.is_number_already_texted(phone):
                        print(f"  -> [Safe] Lead #{lead_id} ({phone}) was ALREADY messaged in permanent history. Skipping outreach.")
                        whatsapp_automation.update_lead_status(lead_id, "Contacted")
                    else:
                        print(f"  -> [Outreach] Instant Auto-Sending WhatsApp Outreach Pitch (Human Typed) to {phone}...")
                        res = whatsapp_automation.send_whatsapp_message(phone, init_pitch)
                        
                        if res == "NOT_ON_WHATSAPP":
                            whatsapp_automation.update_lead_status(lead_id, "Not on WhatsApp")
                            print(f"  -> [Warning] Lead #{lead_id} number not available on WhatsApp. Window closed.")
                        elif res == "ALREADY_TEXTED":
                            whatsapp_automation.update_lead_status(lead_id, "Contacted")
                            print(f"  -> [Safe] Lead #{lead_id} ({phone}) was already messaged in permanent registry.")
                        elif res == "DAILY_LIMIT_REACHED":
                            whatsapp_automation.update_lead_status(lead_id, "Pending Review")
                            print(f"  -> [Limit] Daily limit reached. Pitch saved to Pending Review.")
                        elif res == "NOT_LOGGED_IN":
                            whatsapp_automation.update_lead_status(lead_id, "Pending Review")
                            print(f"  -> [Warning] WhatsApp Web not logged in. Pitch saved to Pending Review.")
                        elif res == True:
                            whatsapp_automation.update_lead_status(lead_id, "Contacted")
                            whatsapp_dispatched = True
                            print(f"  -> [Success] WhatsApp Outreach Pitch Automatically Dispatched for Lead #{lead_id} ({biz_name})!")
                        else:
                            whatsapp_automation.update_lead_status(lead_id, "Pending Review")
                            print(f"  -> [Warning] Outreach error occurred. Saved to Pending Review.")
                except Exception as e:
                    print(f"  -> [!] Auto-Dispatch Notice: {e}")
                    
                conn.close()
                
                # Dynamic safety delays based on configuration
                if whatsapp_dispatched:
                    sleep_duration = random.randint(min_del, max_del)
                    print(f"  -> Lead #{lead_id} processed! Safe outreach delay: Pausing {sleep_duration}s for next lead...")
                else:
                    sleep_duration = random.randint(2, 5)
                    print(f"  -> Lead #{lead_id} processed! Fast delay: Pausing {sleep_duration}s for next lead...")
                time.sleep(sleep_duration)
                
            else:
                print(f"  -> Duplicate business/phone detected. Skipping to next lead...")
                conn.close()
                time.sleep(1)
                
        # Advance to next target in cycle
        niche_idx += 1
        if niche_idx % len(TARGET_NICHES) == 0:
            city_idx += 1

if __name__ == "__main__":
    run_crawler_loop()
