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
        ],
        "cake shops / custom bakeries": [
            "https://images.unsplash.com/photo-1578985545062-69928b1d9587",
            "https://images.unsplash.com/photo-1509440159596-0249088772ff",
            "https://images.unsplash.com/photo-1555507036-ab1f4038808a",
            "https://images.unsplash.com/photo-1517433670267-08bbd4be890f"
        ],
        "cafes": [
            "https://images.unsplash.com/photo-1554118811-1e0d58224f24",
            "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb",
            "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
            "https://images.unsplash.com/photo-1559925393-8be0ec4767c8"
        ],
        "restaurants": [
            "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
            "https://images.unsplash.com/photo-1555396273-367ea4eb4db5",
            "https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c",
            "https://images.unsplash.com/photo-1544025162-d76694265947"
        ],
        "florists / wedding floral businesses": [
            "https://images.unsplash.com/photo-1561181286-d3fee7d55364",
            "https://images.unsplash.com/photo-1526047932273-341f2a7631f9",
            "https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11",
            "https://images.unsplash.com/photo-1563241527-3004b7be0ffd"
        ],
        "boutiques / designer clothing stores": [
            "https://images.unsplash.com/photo-1441986300917-64674bd600d8",
            "https://images.unsplash.com/photo-1490481651871-ab68de25d43d",
            "https://images.unsplash.com/photo-1558769132-cb1aea458c5e",
            "https://images.unsplash.com/photo-1489987707025-afc232f7ea0f"
        ],
        "jewellery boutiques": [
            "https://images.unsplash.com/photo-1535632066927-ab7c9ab60908",
            "https://images.unsplash.com/photo-1605100804763-247f67b3557e",
            "https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f",
            "https://images.unsplash.com/photo-1515562141207-7a88fb7ce338"
        ],
        "boutique hotels / guesthouses": [
            "https://images.unsplash.com/photo-1566073771259-6a8506099945",
            "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b",
            "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4",
            "https://images.unsplash.com/photo-1571896349842-33c89424de2d"
        ],
        "travel agencies": [
            "https://images.unsplash.com/photo-1488646953014-85cb44e25828",
            "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800",
            "https://images.unsplash.com/photo-1507525428034-b723cf961d3e",
            "https://images.unsplash.com/photo-1476514525535-ce74f45814d2"
        ]
    }
    
    # Try exact match or keyword match
    niche_defaults = None
    if industry in defaults:
        niche_defaults = defaults[industry]
    else:
        for k, v in defaults.items():
            if any(w in industry.lower() for w in k.lower().split()):
                niche_defaults = v
                break
                
    if not niche_defaults:
        niche_defaults = defaults["architects & interior design studios"]
        
    return random.choices(niche_defaults, k=count)


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
    Generates a top-tier, structurally and visually unique premium HTML website mockup.
    Each of the 5 main industries is custom-designed with its own DOM structure,
    navigation style, grid layouts, and color tokens so they look completely distinct.
    """
    ind = industry.lower()
    biz_lower = business_name.lower()
    clean_phone = re.sub(r'\D', '', str(phone))

    glow_bg_styles = """
        /* Multi-directional Smooth Scroll Reveals */
        .scroll-reveal, .scroll-reveal-left, .scroll-reveal-right, .scroll-reveal-scale {
            opacity: 0;
            will-change: transform, opacity;
            transition: opacity 0.7s cubic-bezier(0.16, 1, 0.3, 1), transform 0.7s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .scroll-reveal { transform: translateY(30px); }
        .scroll-reveal-left { transform: translateX(-40px); }
        .scroll-reveal-right { transform: translateX(40px); }
        .scroll-reveal-scale { transform: scale(0.92) translateY(20px); }
        
        .scroll-reveal.visible, .scroll-reveal-left.visible, .scroll-reveal-right.visible, .scroll-reveal-scale.visible {
            opacity: 1;
            transform: translateY(0) translateX(0) scale(1);
        }

        /* Interactive Hover Card Lift & Shimmer */
        .hover-card {
            transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.4s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.4s ease;
        }
        .hover-card:hover {
            transform: translateY(-8px);
        }

        /* Image Zoom Container */
        .img-zoom {
            overflow: hidden;
            position: relative;
        }
        .img-zoom img {
            transition: transform 0.8s cubic-bezier(0.16, 1, 0.3, 1);
            width: 100%;
            height: 100%;
            object-fit: cover;
            display: block;
        }
        .img-zoom:hover img {
            transform: scale(1.06);
        }

        /* Glowing CTA Shimmer Effect */
        .btn-shimmer {
            position: relative;
            overflow: hidden;
            transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .btn-shimmer::after {
            content: '';
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: linear-gradient(60deg, transparent, rgba(255, 255, 255, 0.3), transparent);
            transform: rotate(30deg) translateX(-100%);
            transition: transform 0.8s ease;
        }
        .btn-shimmer:hover::after {
            transform: rotate(30deg) translateX(100%);
        }
        .btn-shimmer:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.2);
        }
        
        /* Morphing mesh background glow */
        body {
            position: relative;
        }
        body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            z-index: -2;
            pointer-events: none;
            background-image: 
                radial-gradient(circle at 20% 20%, var(--glow-primary, rgba(59, 130, 246, 0.08)) 0%, transparent 40%),
                radial-gradient(circle at 80% 80%, var(--glow-secondary, rgba(217, 119, 6, 0.06)) 0%, transparent 40%);
            background-size: 200% 200%;
            animation: bgMeshShift 25s ease infinite alternate;
        }
        
        @keyframes bgMeshShift {
            0% { background-position: 0% 0%, 100% 100%; }
            50% { background-position: 50% 100%, 0% 50%; }
            100% { background-position: 100% 100%, 0% 0%; }
        }
    """

    glow_bg_js = """
    <script>

        // IntersectionObserver for Multi-Directional Scroll Reveal
        document.addEventListener("DOMContentLoaded", () => {
            const reveals = document.querySelectorAll(".scroll-reveal, .scroll-reveal-left, .scroll-reveal-right, .scroll-reveal-scale");
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add("visible");
                    }
                });
            }, { threshold: 0.05, rootMargin: "0px 0px -50px 0px" });
            reveals.forEach(el => observer.observe(el));
        });

        // Optimized Interactive Mouse Trail (Canvas Particles)
        (function() {
            const canvas = document.createElement("canvas");
            canvas.style.position = "fixed";
            canvas.style.top = "0";
            canvas.style.left = "0";
            canvas.style.width = "100vw";
            canvas.style.height = "100vh";
            canvas.style.pointerEvents = "none";
            canvas.style.zIndex = "999999";
            canvas.style.opacity = "0.7";
            document.body.prepend(canvas);

            const ctx = canvas.getContext("2d");
            let particles = [];
            
            function resize() {
                canvas.width = window.innerWidth;
                canvas.height = window.innerHeight;
            }
            window.addEventListener("resize", resize);
            resize();

            // Resolve accent color or fallback
            const style = getComputedStyle(document.documentElement);
            const trailColor = style.getPropertyValue('--accent').trim() || "#3b82f6";

            class Particle {
                constructor(x, y) {
                    this.x = x;
                    this.y = y;
                    this.size = Math.random() * 4 + 1.5;
                    this.speedX = Math.random() * 1.5 - 0.75;
                    this.speedY = Math.random() * -1 - 0.3;
                    this.color = trailColor;
                    this.alpha = 1;
                    this.decay = Math.random() * 0.02 + 0.015;
                }
                update() {
                    this.x += this.speedX;
                    this.y += this.speedY;
                    this.alpha -= this.decay;
                    if (this.size > 0.2) this.size -= 0.08;
                }
                draw() {
                    ctx.beginPath();
                    ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
                    ctx.fillStyle = this.color;
                    ctx.globalAlpha = this.alpha;
                    ctx.fill();
                }
            }

            let lastTime = 0;
            window.addEventListener("mousemove", (e) => {
                const now = performance.now();
                if (now - lastTime < 16) return; // Throttle to ~60fps
                lastTime = now;
                particles.push(new Particle(e.clientX, e.clientY));
            });

            function animate() {
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                for (let i = 0; i < particles.length; i++) {
                    particles[i].update();
                    particles[i].draw();
                    if (particles[i].alpha <= 0) {
                        particles.splice(i, 1);
                        i--;
                    }
                }
                requestAnimationFrame(animate);
            }
            animate();
        })();
    </script>
    """

    # Pre-fetch dynamic images from local scraper pool
    hero_img = "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab"
    services_imgs = []
    try:
        imgs = get_random_images(industry, count=4)
        if imgs:
            hero_img = imgs[0]
            services_imgs = imgs[1:]
    except Exception:
        pass

    # Ensure we have at least 3 fallback image URLs
    while len(services_imgs) < 3:
        services_imgs.append("https://images.unsplash.com/photo-1486406146926-c627a92ad1ab")

    # ==========================================
    # TEMPLATE 1: ARCHITECTS & INTERIOR DESIGN
    # ==========================================
    if "architect" in ind or "interior" in ind:
        if not services_imgs[0].startswith("http"):
            services_imgs = [
                "https://images.unsplash.com/photo-1600585154340-be6161a56a0c",
                "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9",
                "https://images.unsplash.com/photo-1512917774080-9991f1c4c750"
            ]
            hero_img = "https://images.unsplash.com/photo-1618221195710-dd6b41faaea6"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{business_name} | Principal Architects in {city}</title>
    <link href="https://fonts.googleapis.com/css2?family=Syne:wght@700;800&family=Plus+Jakarta+Sans:wght@500;700;800&display=swap" rel="stylesheet">
    <style>
        :root {{ 
            --bg: #0b0f19; 
            --primary: #ffffff; 
            --accent: #d4af37; 
            --card-bg: #131a2b; 
            --text-muted: #8e9bb3; 
            --glow-primary: rgba(212, 175, 55, 0.12);
            --glow-secondary: rgba(59, 130, 246, 0.08);
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: var(--bg); color: var(--primary); font-family: 'Plus Jakarta Sans', sans-serif; overflow-x: hidden; }}
        
        {glow_bg_styles}

        /* Modern Side Navigation */
        nav {{ display: flex; justify-content: space-between; align-items: center; padding: 1.5rem 2rem; border-bottom: 1px solid rgba(255,255,255,0.08); background: rgba(11,15,25,0.85); backdrop-filter: blur(15px); position: sticky; top: 0; z-index: 100; }}
        .brand {{ font-family: 'Syne', sans-serif; font-size: 1.3rem; font-weight: 800; color: #fff; text-transform: uppercase; }}
        .brand span {{ color: var(--accent); }}
        .nav-links {{ display: flex; gap: 2rem; list-style: none; }}
        .nav-links a {{ color: var(--text-muted); text-decoration: none; font-weight: 700; font-size: 0.9rem; transition: color 0.3s; }}
        .nav-links a:hover {{ color: #fff; }}
        .btn-cta {{ background: var(--accent); color: #000; padding: 0.6rem 1.2rem; border-radius: 4px; text-decoration: none; font-weight: 800; font-size: 0.85rem; border: none; cursor: pointer; }}

        /* Full Screen Hero with Text Overlay */
        .hero {{ position: relative; height: 85vh; display: flex; align-items: center; justify-content: center; text-align: center; background: linear-gradient(rgba(11,15,25,0.6), rgba(11,15,25,0.95)), url('{hero_img}') no-repeat center center/cover; padding: 0 1rem; }}
        .hero-content {{ max-width: 900px; }}
        .hero-content h1 {{ font-family: 'Syne', sans-serif; font-size: clamp(2rem, 5vw, 4rem); line-height: 1.1; margin-bottom: 1.5rem; text-transform: uppercase; letter-spacing: -1px; }}
        .hero-content h1 span {{ color: var(--accent); }}
        .hero-content p {{ color: var(--text-muted); font-size: 1.1rem; margin-bottom: 2rem; line-height: 1.6; max-width: 650px; margin-inline: auto; }}

        /* Bento Grid Layout Portfolio */
        .section {{ padding: 5rem 2rem; max-width: 1200px; margin: 0 auto; }}
        .section-header {{ margin-bottom: 3rem; text-align: center; }}
        .section-header h2 {{ font-family: 'Syne', sans-serif; font-size: 2.2rem; margin-bottom: 0.5rem; text-transform: uppercase; }}
        .section-header p {{ color: var(--text-muted); }}

        .bento-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1.5rem; }}
        .bento-card {{ background: var(--card-bg); border-radius: 8px; overflow: hidden; border: 1px solid rgba(255,255,255,0.05); transition: transform 0.3s; position: relative; cursor: pointer; }}
        .bento-card:hover {{ transform: translateY(-5px); }}
        .bento-card img {{ width: 100%; height: 260px; object-fit: cover; filter: grayscale(30%); transition: filter 0.3s; }}
        .bento-card:hover img {{ filter: grayscale(0%); }}
        .bento-content {{ padding: 1.5rem; }}
        .bento-tag {{ font-size: 0.75rem; color: var(--accent); font-weight: 800; text-transform: uppercase; margin-bottom: 0.5rem; display: block; }}
        .bento-content h3 {{ font-size: 1.25rem; font-weight: 700; margin-bottom: 0.5rem; }}
        .bento-content p {{ color: var(--text-muted); font-size: 0.85rem; line-height: 1.5; }}

        /* Interactive 3D Budget Estimator */
        .calc-box {{ background: var(--card-bg); border-radius: 8px; padding: 2.5rem; border: 1px solid rgba(255,255,255,0.05); margin-top: 3rem; }}
        .calc-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 2rem; margin-bottom: 2rem; }}
        .calc-field {{ display: flex; flex-direction: column; gap: 0.5rem; }}
        .calc-field label {{ font-size: 0.85rem; text-transform: uppercase; font-weight: 700; color: var(--text-muted); }}
        select, input[type="range"] {{ width: 100%; padding: 0.8rem; background: #0b0f19; border: 1px solid rgba(255,255,255,0.1); color: #fff; border-radius: 4px; outline: none; }}
        .calc-result {{ background: #0b0f19; padding: 1.5rem; border-radius: 4px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; border-left: 4px solid var(--accent); }}
        .calc-val {{ font-family: 'Syne', sans-serif; font-size: 1.8rem; color: var(--accent); font-weight: 800; }}

        /* Footer contact */
        footer {{ padding: 4rem 2rem; border-top: 1px solid rgba(255,255,255,0.08); text-align: center; background: #070a12; }}
        .footer-logo {{ font-family: 'Syne', sans-serif; font-size: 1.8rem; font-weight: 800; color: #fff; margin-bottom: 1rem; }}
        .footer-owner {{ font-size: 0.95rem; color: var(--text-muted); margin-bottom: 1.5rem; }}
        .footer-buttons {{ display: flex; justify-content: center; gap: 1rem; flex-wrap: wrap; }}
        .btn-call {{ background: transparent; color: #fff; border: 1px solid rgba(255,255,255,0.2); padding: 0.6rem 1.5rem; text-decoration: none; font-weight: 700; border-radius: 4px; }}
        .btn-call:hover {{ background: rgba(255,255,255,0.05); }}
    </style>
</head>
<body>

    <nav>
        <div class="brand">{business_name.split()[0]} <span>Studio</span></div>
        <ul class="nav-links">
            <li><a href="#projects">Portfolio</a></li>
            <li><a href="#about">About</a></li>
            <li><a href="#estimator">Estimator</a></li>
        </ul>
        <a href="https://wa.me/{clean_phone}" class="btn-cta">Consult Architect</a>
    </nav>

    <section class="hero">
        <div class="hero-content scroll-reveal">
            <h1>Crafting Iconic <span>Landmarks</span> in {city}</h1>
            <p>Architectural Planning, Structural Engineering & Luxury Interior Fit-Outs built to elevate modern spatial experiences.</p>
            <a href="#estimator" class="btn-cta">Start Project Planner</a>
        </div>
    </section>

    <section class="section scroll-reveal" id="projects">
        <div class="section-header">
            <h2>Featured Built Estates</h2>
            <p>Selected architectural blueprints and turnkey fit-outs successfully handed over in {city}.</p>
        </div>
        <div class="bento-grid">
            <div class="bento-card">
                <img src="{services_imgs[0]}" alt="Luxury Estates">
                <div class="bento-content">
                    <span class="bento-tag">Residential</span>
                    <h3>Premium Villa Estate</h3>
                    <p>Vastu-compliant architectural plans and luxury interior joinery curation.</p>
                </div>
            </div>
            <div class="bento-card">
                <img src="{services_imgs[1]}" alt="Commercial">
                <div class="bento-content">
                    <span class="bento-tag">Commercial</span>
                    <h3>Corporate Headquarters</h3>
                    <p>Acoustic glass partitioning, modular layouts, and executive suites execution.</p>
                </div>
            </div>
            <div class="bento-card">
                <img src="{services_imgs[2]}" alt="Urban Layouts">
                <div class="bento-content">
                    <span class="bento-tag">Outdoor</span>
                    <h3>Penthouse Sky Deck</h3>
                    <p>Solid teak wood decking, weather-resistant joinery, and infinity plunge pool layouts.</p>
                </div>
            </div>
        </div>
    </section>

    <section class="section scroll-reveal" id="estimator">
        <div class="section-header">
            <h2>Spatial Project Planner</h2>
            <p>Calculate custom turnkey architectural planning and fit-out budget in {city}.</p>
        </div>
        <div class="calc-box">
            <div class="calc-grid">
                <div class="calc-field">
                    <label>Property Classification</label>
                    <select id="propType" onchange="calcArchCost()">
                        <option value="4200">Luxury Independent Bungalow / Villa</option>
                        <option value="2900">Premium Penthouse Apartment</option>
                        <option value="3400">Corporate Office Fit-Out</option>
                    </select>
                </div>
                <div class="calc-field">
                    <label>Built-Up Area: <span id="areaVal" style="color:var(--accent); font-weight:800;">2,500 Sq. Ft</span></label>
                    <input type="range" id="areaRange" min="1000" max="10000" step="250" value="2500" oninput="calcArchCost()">
                </div>
            </div>
            <div class="calc-result">
                <div>
                    <p style="font-size:0.8rem; text-transform:uppercase; color:var(--text-muted); font-weight:700;">Estimated Turnkey Capital Budget:</p>
                    <div id="estResult" class="calc-val">₹1.05 Crore</div>
                </div>
                <button onclick="window.location.href='https://wa.me/{clean_phone}'" class="btn-cta">Lock Spec & Schedule Meeting &rarr;</button>
            </div>
        </div>
    </section>

    <footer>
        <div class="footer-logo">{business_name}</div>
        <p class="footer-owner">{owner_name} &bull; Principal Architect</p>
        <p style="color:var(--text-muted); font-size:0.85rem; margin-bottom: 2rem;">Registered Member of the Council of Architecture (CoA) &bull; {city}</p>
        <div class="footer-buttons">
            <a href="tel:{phone}" class="btn-call">Direct Call</a>
            <a href="https://wa.me/{clean_phone}" class="btn-cta">WhatsApp Consultation</a>
        </div>
    </footer>

    <script>
        function calcArchCost() {{
            var rate = parseFloat(document.getElementById("propType").value);
            var area = parseFloat(document.getElementById("areaRange").value);
            document.getElementById("areaVal").innerText = area.toLocaleString('en-IN') + " Sq. Ft";
            var total = (rate * area) / 10000000;
            document.getElementById("estResult").innerText = "₹" + total.toFixed(2) + " Crore";
        }}
    </script>
    {glow_bg_js}
</body>
</html>"""

    elif "wedding" in ind or "event" in ind:
        if not services_imgs[0].startswith("http"):
            services_imgs = [
                "https://images.unsplash.com/photo-1545232979-fbf34fe37b38",
                "https://images.unsplash.com/photo-1511285560929-80b456fea0bc",
                "https://images.unsplash.com/photo-1464366400600-7168b8af9bc3"
            ]
            hero_img = "https://images.unsplash.com/photo-1519741497674-611481863552"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{business_name} | Palace Weddings & Curation</title>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,600;0,700;1,400&family=Inter:wght@500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {{ 
            --bg: #faf7f5; 
            --primary: #2d1b2d; 
            --accent: #be123c; 
            --accent-light: #fecdd3; 
            --card: #ffffff; 
            --glow-primary: rgba(190, 18, 60, 0.08);
            --glow-secondary: rgba(254, 205, 211, 0.12);
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: var(--bg); color: var(--primary); font-family: 'Inter', sans-serif; overflow-x: hidden; }}
        
        {glow_bg_styles}

        /* Elegant Top Navigation */
        nav {{ display: flex; justify-content: space-between; align-items: center; padding: 1.5rem 3rem; background: #fff; border-bottom: 1px solid #eae2db; position: sticky; top: 0; z-index: 100; }}
        .brand {{ font-family: 'Playfair Display', serif; font-size: 1.5rem; font-weight: 700; font-style: italic; }}
        .nav-links {{ display: flex; gap: 2.5rem; list-style: none; }}
        .nav-links a {{ color: var(--primary); text-decoration: none; font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1px; }}
        .btn-book {{ background: var(--primary); color: #fff; padding: 0.6rem 1.4rem; border-radius: 20px; text-decoration: none; font-weight: 700; font-size: 0.8rem; }}

        /* Split Screen Hero */
        .hero {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); min-height: 80vh; align-items: center; padding: 4rem 3rem; gap: 3rem; max-width: 1200px; margin: 0 auto; }}
        .hero-text h1 {{ font-family: 'Playfair Display', serif; font-size: clamp(2.5rem, 4vw, 3.8rem); line-height: 1.1; margin-bottom: 1.5rem; }}
        .hero-text h1 span {{ color: var(--accent); font-style: italic; font-weight: 400; }}
        .hero-text p {{ color: #5a4b5a; font-size: 1rem; line-height: 1.7; margin-bottom: 2rem; }}
        .hero-img {{ position: relative; border-radius: 120px 120px 0 0; overflow: hidden; height: 500px; box-shadow: 0 15px 30px rgba(0,0,0,0.05); border: 8px solid #fff; }}
        .hero-img img {{ width: 100%; height: 100%; object-fit: cover; }}

        /* Cards Grid */
        .section {{ padding: 6rem 2rem; max-width: 1200px; margin: 0 auto; }}
        .sec-title {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; text-align: center; margin-bottom: 4rem; }}
        .services-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }}
        .service-card {{ background: var(--card); border-radius: 12px; overflow: hidden; border: 1px solid #eae2db; transition: box-shadow 0.3s; }}
        .service-card:hover {{ box-shadow: 0 10px 25px rgba(45,27,45,0.06); }}
        .service-card img {{ width: 100%; height: 240px; object-fit: cover; }}
        .service-info {{ padding: 2rem; }}
        .service-tag {{ color: var(--accent); font-size: 0.8rem; font-weight: 700; text-transform: uppercase; margin-bottom: 0.5rem; display: block; }}
        .service-info h3 {{ font-family: 'Playfair Display', serif; font-size: 1.4rem; margin-bottom: 0.8rem; }}
        .service-info p {{ color: #5a4b5a; font-size: 0.88rem; line-height: 1.6; }}

        /* Luxury Estimator Tool */
        .calc-wrapper {{ background: #fff; border-radius: 16px; padding: 3rem; border: 1px solid #eae2db; }}
        .calc-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 2rem; margin-bottom: 2rem; }}
        .calc-field label {{ font-size: 0.8rem; text-transform: uppercase; font-weight: 700; letter-spacing: 0.5px; color: #5a4b5a; display: block; margin-bottom: 0.5rem; }}
        select, input[type="range"] {{ width: 100%; padding: 0.8rem; background: var(--bg); border: 1px solid #cbd5e1; border-radius: 4px; outline: none; }}
        .calc-result {{ background: #fff1f2; padding: 2rem; border-radius: 8px; border: 1px solid var(--accent-light); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.5rem; }}
        .calc-val {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; color: var(--accent); font-weight: 700; }}

        /* Footer */
        footer {{ padding: 5rem 2rem; background: var(--primary); color: #fff; text-align: center; }}
        .footer-logo {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; font-style: italic; margin-bottom: 1rem; }}
        .footer-owner {{ font-size: 0.95rem; color: #bcaebc; margin-bottom: 2rem; }}
        .footer-buttons {{ display: flex; justify-content: center; gap: 1.5rem; flex-wrap: wrap; }}
        .btn-direct {{ border: 1px solid rgba(255,255,255,0.3); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 20px; font-weight: 600; font-size: 0.85rem; }}
        .btn-wa {{ background: var(--accent); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 20px; font-weight: 700; font-size: 0.85rem; }}
    </style>
</head>
<body>

    <nav>
        <div class="brand">{business_name.split()[0]} <span>Events</span></div>
        <ul class="nav-links">
            <li><a href="#curations">Curations</a></li>
            <li><a href="#estimator">Estimator</a></li>
        </ul>
        <a href="https://wa.me/{clean_phone}" class="btn-book">Consult Curator</a>
    </nav>

    <section class="hero scroll-reveal">
        <div class="hero-text">
            <h1>Palace Destination <span>Weddings</span> & Royal Curation</h1>
            <p>Bespoke palace scenography, floral styling, Bollywood artist curations, and 5-star royal hospitality planned flawlessly in {city}.</p>
            <a href="#estimator" class="btn-book">Start Wedding Curation Planner</a>
        </div>
        <div class="hero-img">
            <img src="{hero_img}" alt="Luxury weddings">
        </div>
    </section>

    <section class="section scroll-reveal" id="curations">
        <h2 class="sec-title">Bespoke Royal Celebrations</h2>
        <div class="services-grid">
            <div class="service-card">
                <img src="{services_imgs[0]}" alt="Palace bookings">
                <div class="service-info">
                    <span class="service-tag">Heritage Palaces</span>
                    <h3>Palace Curation</h3>
                    <p>Complete multi-day palace booking, luxury transfers, and royal elephant welcome entries.</p>
                </div>
            </div>
            <div class="service-card">
                <img src="{services_imgs[1]}" alt="Stage decor">
                <div class="service-info">
                    <span class="service-tag">Scenography</span>
                    <h3>Floral Styling & Mandap</h3>
                    <p>Custom floral backdrops, imported orchids mandap, and ambient warm projection layouts.</p>
                </div>
            </div>
            <div class="service-card">
                <img src="{services_imgs[2]}" alt="Royal feast">
                <div class="service-info">
                    <span class="service-tag">Gourmet Catering</span>
                    <h3>Gourmet Royal Feast</h3>
                    <p>Live Sufi band booking, Bollywood artists management, and curated 7-course royal menu.</p>
                </div>
            </div>
        </div>
    </section>

    <section class="section scroll-reveal" id="estimator">
        <h2 class="sec-title">Curation Budget Planner</h2>
        <div class="calc-wrapper">
            <div class="calc-grid">
                <div class="calc-field">
                    <label>Palace & Venue Category</label>
                    <select id="weddingType" onchange="calcWeddingCost()">
                        <option value="6000">Heritage Palace / 5-Star Luxury Resort</option>
                        <option value="3500">Luxury Banquet & Royal Lawns</option>
                        <option value="9000">International / Island Destination</option>
                    </select>
                </div>
                <div class="calc-field">
                    <label>Expected Guests: <span id="guestVal" style="color:var(--accent); font-weight:800;">400 Guests</span></label>
                    <input type="range" id="guestRange" min="100" max="1500" step="50" value="400" oninput="calcWeddingCost()">
                </div>
            </div>
            <div class="calc-result">
                <div>
                    <p style="font-size:0.75rem; text-transform:uppercase; color:#5a4b5a; font-weight:700;">Estimated Turnkey Curation Budget:</p>
                    <div id="weddingResult" class="calc-val">₹24.00 Lakhs</div>
                </div>
                <button onclick="window.location.href='https://wa.me/{clean_phone}'" class="btn-book" style="background:var(--accent); border:none; cursor:pointer;">Secure Booking Date &rarr;</button>
            </div>
        </div>
    </section>

    <footer>
        <div class="footer-logo">{business_name}</div>
        <p class="footer-owner">{owner_name} &bull; Lead Curator</p>
        <p style="color:#bcaebc; font-size:0.85rem; margin-bottom: 2rem;">Bespoke Luxury Events &bull; Udaipur &bull; Udaipur &bull; {city}</p>
        <div class="footer-buttons">
            <a href="tel:{phone}" class="btn-direct">Direct Line</a>
            <a href="https://wa.me/{clean_phone}" class="btn-wa">WhatsApp Inquiry</a>
        </div>
    </footer>

    <script>
        function calcWeddingCost() {{
            var rate = parseFloat(document.getElementById("weddingType").value);
            var guests = parseFloat(document.getElementById("guestRange").value);
            document.getElementById("guestVal").innerText = guests + " Guests";
            var total = (rate * guests) / 100000;
            document.getElementById("weddingResult").innerText = "₹" + total.toFixed(2) + " Lakhs";
        }}
    </script>
    {glow_bg_js}
</body>
</html>"""

    # ==========================================
    # TEMPLATE 3: CUSTOM FURNITURE & WOODWORK
    # ==========================================
    elif "furniture" in ind or "woodwork" in ind:
        if not services_imgs[0].startswith("http"):
            services_imgs = [
                "https://images.unsplash.com/photo-1617806118233-18e1de247200",
                "https://images.unsplash.com/photo-1555041469-a586c61ea9bc",
                "https://images.unsplash.com/photo-1538688525198-9b88f6f53126"
            ]
            hero_img = "https://images.unsplash.com/photo-1617806118233-18e1de247200"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{business_name} | Custom Solid Teak Woodwork</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&family=Playfair+Display:ital,wght@0,600;0,700;1,400&display=swap" rel="stylesheet">
    <style>
        :root {{ 
            --bg: #FAF9F6; 
            --primary: #1c1917; 
            --accent: #b45309; 
            --accent-warm: #d97706;
            --card: #ffffff; 
            --border: #f2efe9; 
            --glow-primary: rgba(180, 83, 9, 0.12);
            --glow-secondary: rgba(6, 78, 59, 0.08);
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: var(--bg); color: var(--primary); font-family: 'Plus Jakarta Sans', sans-serif; overflow-x: hidden; }}
        
        {glow_bg_styles}

        /* Elegant Luxury Navigation */
        nav {{ display: flex; justify-content: space-between; align-items: center; padding: 1.5rem 3rem; background: rgba(250, 249, 246, 0.9); backdrop-filter: blur(12px); border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 100; }}
        .brand {{ font-family: 'Playfair Display', serif; font-size: 1.35rem; font-weight: 700; letter-spacing: -0.5px; }}
        .brand span {{ color: var(--accent); font-style: italic; }}
        .nav-links {{ display: flex; gap: 2rem; list-style: none; }}
        .nav-links a {{ color: var(--primary); text-decoration: none; font-weight: 700; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.5px; }}
        .btn-consult {{ background: var(--primary); color: #fff; padding: 0.6rem 1.4rem; border-radius: 30px; text-decoration: none; font-weight: 700; font-size: 0.8rem; transition: background 0.3s; }}
        .btn-consult:hover {{ background: var(--accent); }}

        /* Split-screen Immersive Hero */
        .hero {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 4rem; align-items: center; padding: 5rem 3rem; max-width: 1200px; margin: 0 auto; }}
        .hero-info h1 {{ font-family: 'Playfair Display', serif; font-size: clamp(2.2rem, 4vw, 3.8rem); line-height: 1.1; margin-bottom: 1.5rem; }}
        .hero-info h1 span {{ color: var(--accent); font-style: italic; font-weight: 400; }}
        .hero-info p {{ color: #57534e; font-size: 1.05rem; line-height: 1.7; margin-bottom: 2rem; }}
        .hero-img {{ border-radius: 16px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 15px 30px rgba(0, 0, 0, 0.02); }}
        .hero-img img {{ width: 100%; height: 100%; object-fit: cover; display: block; }}

        /* Crafts Showcase Grid */
        .section {{ padding: 6rem 3rem; max-width: 1200px; margin: 0 auto; }}
        .sec-title {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; text-align: center; margin-bottom: 4rem; }}
        .craft-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 2.5rem; }}
        .craft-card {{ background: var(--card); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; transition: all 0.3s ease; }}
        .craft-card:hover {{ transform: translateY(-5px); box-shadow: 0 20px 40px rgba(180, 83, 9, 0.06); border-color: var(--accent); }}
        .craft-card img {{ width: 100%; height: 260px; object-fit: cover; }}
        .craft-info {{ padding: 2rem; }}
        .craft-info h3 {{ font-family: 'Playfair Display', serif; font-size: 1.35rem; font-weight: 700; margin-bottom: 0.6rem; }}
        .craft-info p {{ color: #57534e; font-size: 0.9rem; line-height: 1.6; }}

        /* Timber finish calculator widget */
        .wood-selector {{ background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 3rem; box-shadow: 0 10px 25px rgba(0,0,0,0.02); }}
        .selector-row {{ display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 2rem; }}
        .select-btn {{ background: var(--bg); border: 1px solid var(--border); color: var(--primary); padding: 0.7rem 1.4rem; border-radius: 30px; font-weight: 700; font-size: 0.8rem; cursor: pointer; transition: all 0.2s; }}
        .select-btn.active {{ background: var(--accent); color: #fff; border-color: var(--accent); }}
        .selector-output {{ border-left: 4px solid var(--accent); background: var(--bg); padding: 2rem; border-radius: 6px; }}

        /* Footer */
        footer {{ padding: 5rem 3rem; background: var(--primary); color: #fff; text-align: center; }}
        .footer-logo {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; font-style: italic; margin-bottom: 1rem; }}
        .footer-buttons {{ display: flex; justify-content: center; gap: 1.5rem; flex-wrap: wrap; margin-top: 2rem; }}
        .btn-call {{ border: 1px solid rgba(255,255,255,0.3); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 30px; font-weight: 700; font-size: 0.85rem; transition: background 0.3s; }}
        .btn-call:hover {{ background: rgba(255,255,255,0.05); }}
        .btn-wa {{ background: var(--accent); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 30px; font-weight: 800; font-size: 0.85rem; transition: background 0.3s; }}
        .btn-wa:hover {{ background: var(--accent-warm); }}
    </style>
</head>
<body>

    <nav>
        <div class="brand">{business_name.split()[0]} <span>Studios</span></div>
        <ul class="nav-links">
            <li><a href="#showcase">Showcase</a></li>
            <li><a href="#selector">Finishes</a></li>
        </ul>
        <a href="https://wa.me/{clean_phone}" class="btn-consult">Direct Inquiry</a>
    </nav>

    <section class="hero scroll-reveal">
        <div class="hero-info">
            <h1>Artisanal Solid <span>Teak Woodwork</span> & Handcrafted Joinery</h1>
            <p>Bespoke interior fit-outs, luxury teakwood dining collections, and heritage architectural partitions crafted directly to order by Principal Craftsman {owner_name} in {city}.</p>
            <a href="https://wa.me/{clean_phone}" class="btn-consult" style="padding: 0.75rem 2rem;">Consult Master Craftsman</a>
        </div>
        <div class="hero-img">
            <img src="{hero_img}" alt="Artisan Woodwork">
        </div>
    </section>

    <section class="section scroll-reveal" id="showcase">
        <h2 class="sec-title">Workshop Custom Curations</h2>
        <div class="craft-grid">
            <div class="craft-card">
                <img src="{services_imgs[0]}" alt="Solid Teak Dining">
                <div class="craft-info">
                    <h3>Solid Teak Dining Collections</h3>
                    <p>Premium grade CP teakwood dining tables with hand-buffered matte finish and bespoke joinery details.</p>
                </div>
            </div>
            <div class="craft-card">
                <img src="{services_imgs[1]}" alt="Velvet Lounges">
                <div class="craft-info">
                    <h3>Bespoke Living Suites</h3>
                    <p>Hand-selected Sheesham structural framework combined with high-density foam and raw linen upholstery.</p>
                </div>
            </div>
            <div class="craft-card">
                <img src="{services_imgs[2]}" alt="Corporate Desks">
                <div class="craft-info">
                    <h3>Executive Managerial Suites</h3>
                    <p>Mahogany veneer desk setups with integrated hidden wire channels, custom compartments, and satin finishes.</p>
                </div>
            </div>
        </div>
    </section>

    <section class="section scroll-reveal" id="selector">
        <h2 class="sec-title">Premium Timber Finishes</h2>
        <div class="wood-selector">
            <p style="color:#57534e; font-size:0.95rem; margin-bottom: 1.8rem; line-height:1.6;">Select a premium polish to preview wood texture & protective topcoat finish:</p>
            <div class="selector-row">
                <button onclick="setWood('CP Teak Wood (Natural Gold Polish)', '#d97706')" class="select-btn active">CP Teak Natural</button>
                <button onclick="setWood('Dark Walnut Matte Polish', '#451a03')" class="select-btn">Walnut Matte</button>
                <button onclick="setWood('Imperial Mahogany Red Satin', '#7f1d1d')" class="select-btn">Imperial Mahogany</button>
            </div>
            <div class="selector-output">
                <div style="font-weight: 800; font-size: 1.15rem; color:var(--primary);" id="selectedWood">Active Finish: CP Teak Wood (Natural Gold Polish)</div>
                <p style="color:#78716c; font-size:0.88rem; margin-top:0.4rem; line-height:1.5;">Seasoned against termites & moisture | Hand-buffed PU protective lacquer coating</p>
            </div>
        </div>
    </section>

    <footer>
        <div class="footer-logo">{business_name}</div>
        <p style="font-size:0.9rem; color:#a8a29e; margin-top:0.3rem;">Master Joinery &bull; Workshop Direct Registry &bull; {city}</p>
        <div class="footer-buttons">
            <a href="tel:{phone}" class="btn-call">Call Workshop</a>
            <a href="https://wa.me/{clean_phone}" class="btn-wa">WhatsApp Inquiry</a>
        </div>
    </footer>

    <script>
        function setWood(name, color) {{
            document.getElementById("selectedWood").innerText = "Active Finish: " + name;
        }}
    </script>
    {glow_bg_js}
</body>
</html>"""

    # ==========================================
    # TEMPLATE 4: INDUSTRIAL MACHINERY & CNC
    # ==========================================
    elif "machinery" in ind or "tool" in ind:
        if not services_imgs[0].startswith("http"):
            services_imgs = [
                "https://images.unsplash.com/photo-1581092160607-ee22621dd758",
                "https://images.unsplash.com/photo-1504917599217-d4dc5ebe6122",
                "https://images.unsplash.com/photo-1581092335397-9583fe92d232"
            ]
            hero_img = "https://images.unsplash.com/photo-1581092160607-ee22621dd758"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{business_name} | CNC vertical Machining Centers & Tooling</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800&display=swap" rel="stylesheet">
    <style>
        :root {{ 
            --bg: #030712; 
            --primary: #f8fafc; 
            --accent: #38bdf8; 
            --accent-sec: #0284c7; 
            --card-bg: #0f172a; 
            --border: rgba(255, 255, 255, 0.08); 
            --glow-primary: rgba(56, 189, 248, 0.15);
            --glow-secondary: rgba(99, 102, 241, 0.08);
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: var(--bg); color: var(--primary); font-family: 'Plus Jakarta Sans', sans-serif; overflow-x: hidden; }}
        
        {glow_bg_styles}

        /* Modern Glassmorphic Navigation */
        nav {{ display: flex; justify-content: space-between; align-items: center; padding: 1.2rem 2.5rem; background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(12px); border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 100; }}
        .logo {{ font-size: 1.25rem; font-weight: 800; text-transform: uppercase; letter-spacing: -0.5px; color: #fff; }}
        .logo span {{ color: var(--accent); }}
        .btn-quote {{ background: var(--accent); color: #fff; text-decoration: none; padding: 0.6rem 1.4rem; font-size: 0.8rem; font-weight: 800; border-radius: 4px; text-transform: uppercase; transition: all 0.3s; }}
        .btn-quote:hover {{ background: var(--accent-sec); box-shadow: 0 0 15px rgba(56, 189, 248, 0.4); }}

        /* Technical Hero Header Grid */
        .hero {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 3rem; padding: 5rem 2.5rem; align-items: center; max-width: 1200px; margin: 0 auto; }}
        .hero-info {{ display: flex; flex-direction: column; justify-content: center; }}
        .hero-info h1 {{ font-size: clamp(2rem, 4vw, 3.2rem); font-weight: 800; line-height: 1.1; margin-bottom: 1rem; text-transform: uppercase; color: #fff; }}
        .hero-info p {{ color: #94a3b8; font-size: 1rem; line-height: 1.6; margin-bottom: 2rem; }}
        .hero-img {{ border-radius: 12px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5); }}
        .hero-img img {{ width: 100%; height: 100%; object-fit: cover; display: block; }}

        /* Rigid Specification Cards Grid */
        .section {{ padding: 6rem 2.5rem; max-width: 1200px; margin: 0 auto; }}
        .sec-title {{ font-size: 1.8rem; font-weight: 800; text-transform: uppercase; margin-bottom: 3.5rem; text-align: center; color: #fff; letter-spacing: 0.5px; }}
        .spec-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }}
        .spec-card {{ background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 2.5rem; transition: all 0.3s ease; }}
        .spec-card:hover {{ border-color: var(--accent); box-shadow: 0 10px 30px rgba(56, 189, 248, 0.12); transform: translateY(-5px); }}
        .spec-card h3 {{ font-size: 1.25rem; text-transform: uppercase; margin-bottom: 1rem; color: #fff; font-weight: 800; }}
        .spec-card p {{ font-size: 0.88rem; color: #94a3b8; line-height: 1.6; margin-bottom: 1.5rem; }}
        .spec-table {{ width: 100%; font-size: 0.8rem; border-collapse: collapse; }}
        .spec-table td {{ padding: 0.6rem 0; border-bottom: 1px solid rgba(255, 255, 255, 0.05); color: #94a3b8; }}
        .spec-table td:nth-child(even) {{ text-align: right; font-weight: 700; color: #fff; }}

        /* Footer */
        footer {{ padding: 5rem 2rem; background: #070a12; color: #fff; text-align: center; border-top: 1px solid var(--border); }}
        .footer-logo {{ font-size: 1.5rem; font-weight: 800; text-transform: uppercase; margin-bottom: 1rem; }}
        .footer-buttons {{ display: flex; justify-content: center; gap: 1.5rem; flex-wrap: wrap; margin-top: 2rem; }}
        .btn-call {{ border: 1px solid rgba(255,255,255,0.2); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 4px; font-weight: 700; font-size: 0.85rem; transition: all 0.3s; }}
        .btn-call:hover {{ background: rgba(255,255,255,0.05); }}
        .btn-wa {{ background: var(--accent); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 4px; font-weight: 800; font-size: 0.85rem; transition: all 0.3s; }}
        .btn-wa:hover {{ background: var(--accent-sec); box-shadow: 0 0 15px rgba(56, 189, 248, 0.3); }}
    </style>
</head>
<body>

    <nav>
        <div class="logo">{business_name.split()[0]} <span>CNC</span></div>
        <a href="https://wa.me/{clean_phone}" class="btn-quote">Consult Director</a>
    </nav>

    <section class="hero scroll-reveal">
        <div class="hero-info">
            <span style="font-size:0.75rem; text-transform:uppercase; color:var(--accent); font-weight:800; margin-bottom:0.8rem; letter-spacing: 1px;">ISO 9001:2026 Certified Supplier</span>
            <h1>High Precision CNC VMC Machinery</h1>
            <p>Direct importer of heavy-duty slant bed lathes, 5-axis vertical machining centers, and high-performance workshop cutting tooling in {city}. Managed by {owner_name}.</p>
            <a href="https://wa.me/{clean_phone}" class="btn-quote" style="width:fit-content;">Download Specs Catalogue</a>
        </div>
        <div class="hero-img">
            <img src="{hero_img}" alt="CNC Machining">
        </div>
    </section>

    <section class="section scroll-reveal">
        <h2 class="sec-title">VMC Machinery Specifications</h2>
        <div class="spec-grid">
            <div class="spec-card">
                <h3>5-Axis VMC CNC Center</h3>
                <p>Heavy duty casting bed with linear guide rails and ARM-type ATC 24 tool changer.</p>
                <table class="spec-table">
                    <tr><td>Spindle speed</td><td>12,000 RPM</td></tr>
                    <tr><td>X/Y/Z travel</td><td>800 / 500 / 550 mm</td></tr>
                    <tr><td>Controller</td><td>Fanuc / Siemens 828D</td></tr>
                </table>
            </div>
            <div class="spec-card">
                <h3>Hydraulic Press Brake</h3>
                <p>Equipped with DA-53T graphic controller and multi-axis backgauge system.</p>
                <table class="spec-table">
                    <tr><td>Bending force</td><td>100 Tons to 500 Tons</td></tr>
                    <tr><td>Table length</td><td>3200 mm</td></tr>
                    <tr><td>Control axis</td><td>Y1, Y2, X, R Crowning</td></tr>
                </table>
            </div>
            <div class="spec-card">
                <h3>Carbide Milling Tooling</h3>
                <p>Solid carbide inserts, indexing cutters, and digital QC inspection toolings.</p>
                <table class="spec-table">
                    <tr><td>Hardness grade</td><td>HRC 55 to 65</td></tr>
                    <tr><td>Milling diameter</td><td>1.0 mm to 20.0 mm</td></tr>
                    <tr><td>Coating finish</td><td>TiAlN / AlTiN coating</td></tr>
                </table>
            </div>
        </div>
    </section>

    <footer>
        <div class="footer-logo">{business_name}</div>
        <p style="font-size:0.85rem; color:#94a3b8; margin-top:0.3rem;">Mechanical Industrial Supplier &bull; Managing Director: {owner_name} &bull; {city}</p>
        <div class="footer-buttons">
            <a href="tel:{phone}" class="btn-call">Direct Line</a>
            <a href="https://wa.me/{clean_phone}" class="btn-wa">Request Technical Specs &rarr;</a>
        </div>
    </footer>
    {glow_bg_js}
</body>
</html>"""

    elif "chartered" in ind or "tax" in ind or "accountant" in ind:
        if not services_imgs[0].startswith("http"):
            services_imgs = [
                "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40",
                "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab",
                "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c"
            ]
            hero_img = "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{business_name} | ICAI Certified Chartered Accountants</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@700;800&display=swap" rel="stylesheet">
    <style>
        :root {{ 
            --bg: #f8fafc; 
            --primary: #064e3b; 
            --accent: #059669; 
            --card: #ffffff; 
            --border: #e2e8f0; 
            --glow-primary: rgba(5, 150, 105, 0.12);
            --glow-secondary: rgba(6, 78, 59, 0.08);
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: var(--bg); color: #1e293b; font-family: 'Plus Jakarta Sans', sans-serif; overflow-x: hidden; }}
        
        {glow_bg_styles}

        /* Clean corporate navigation */
        nav {{ display: flex; justify-content: space-between; align-items: center; padding: 1.2rem 2.5rem; background: #fff; border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 100; }}
        .brand {{ color: var(--primary); font-size: 1.2rem; font-weight: 800; text-transform: uppercase; }}
        .btn-consult {{ background: var(--primary); color: #fff; padding: 0.5rem 1.2rem; border-radius: 4px; text-decoration: none; font-weight: 700; font-size: 0.8rem; }}

        /* Centered Trust Hero Header */
        .hero {{ text-align: center; padding: 5rem 1.5rem 4rem; background: #fff; border-bottom: 1px solid var(--border); }}
        .trust-badge {{ display: inline-block; background: #d1fae5; color: #065f46; padding: 0.35rem 0.85rem; border-radius: 20px; font-size: 0.72rem; font-weight: 800; text-transform: uppercase; margin-bottom: 1rem; }}
        .hero h1 {{ font-size: clamp(2rem, 4vw, 3.2rem); font-weight: 800; color: var(--primary); margin-bottom: 0.8rem; line-height: 1.1; }}
        .hero p {{ max-width: 650px; margin: 0 auto 2rem; color: #475569; font-size: 1rem; line-height: 1.6; }}

        /* Corporate Services Grid */
        .section {{ padding: 5rem 2rem; max-width: 1100px; margin: 0 auto; }}
        .sec-title {{ font-size: 1.6rem; font-weight: 800; color: var(--primary); margin-bottom: 2.5rem; text-align: center; text-transform: uppercase; }}
        .service-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }}
        .service-card {{ background: var(--card); border: 1px solid var(--border); border-radius: 6px; padding: 2rem; transition: transform 0.2s; }}
        .service-card:hover {{ transform: translateY(-3px); }}
        .service-card h3 {{ font-size: 1.2rem; color: var(--primary); margin-bottom: 0.8rem; font-weight: 800; }}
        .service-card p {{ color: #475569; font-size: 0.85rem; line-height: 1.55; }}

        /* Calculator section */
        .calc-container {{ background: #fff; border: 1px solid var(--border); border-radius: 6px; padding: 2.5rem; }}
        .calc-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 2rem; margin-bottom: 2rem; }}
        select, input[type="range"] {{ width: 100%; padding: 0.8rem; background: var(--bg); border: 1px solid var(--border); border-radius: 4px; outline: none; }}
        .calc-result {{ background: #ecfdf5; padding: 1.8rem; border-radius: 4px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; border-left: 4px solid var(--accent); }}
        .calc-val {{ font-size: 1.8rem; color: var(--primary); font-weight: 800; }}

        /* Footer */
        footer {{ padding: 4rem 2rem; background: var(--primary); color: #fff; text-align: center; }}
        .footer-buttons {{ display: flex; justify-content: center; gap: 1rem; flex-wrap: wrap; margin-top: 1.5rem; }}
        .btn-call {{ border: 1px solid rgba(255,255,255,0.3); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 4px; font-weight: 700; font-size: 0.85rem; }}
        .btn-wa {{ background: var(--accent); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 4px; font-weight: 800; font-size: 0.85rem; }}
    </style>
</head>
<body>

    <nav>
        <div class="brand">{business_name.split()[0]} &bull; CAs</div>
        <a href="https://wa.me/{clean_phone}" class="btn-consult">Direct Consultation</a>
    </nav>

    <section class="hero scroll-reveal">
        <span class="trust-badge">ICAI Certified Firm</span>
        <h1>Corporate Taxation & Compliance</h1>
        <p>Expert statutory financial audits, Private Limited company incorporation, ROC secretarial compliance, and income tax advisory in {city}.</p>
        <a href="https://wa.me/{clean_phone}" class="btn-consult" style="padding:0.7rem 1.8rem;">Consult CA {owner_name.split()[0]}</a>
    </section>

    <section class="section scroll-reveal">
        <h2 class="sec-title">Chartered Practices</h2>
        <div class="service-grid">
            <div class="service-card">
                <h3>Corporate GST & Income Tax</h3>
                <p>Complete GST filings, tax returns audit, GST litigation support, and corporate tax structuring built for local businesses in {city}.</p>
            </div>
            <div class="service-card">
                <h3>Pvt Ltd Incorporation</h3>
                <p>Fast ROC incorporation setup, LLP setup, startup valuation certifications, and share capital registration advisory.</p>
            </div>
            <div class="service-card">
                <h3>Statutory Audits</h3>
                <p>Balance sheet audits certification, internal control reviews, M&A due diligence, and financial statement certifications.</p>
            </div>
        </div>
    </section>

    <section class="section scroll-reveal">
        <h2 class="sec-title">GST & Compliance Retainer Planner</h2>
        <div class="calc-container">
            <div class="calc-grid">
                <div>
                    <label style="font-size:0.8rem; font-weight:700; color:#475569; display:block; margin-bottom:0.5rem; text-transform:uppercase;">Annual Business Turnover</label>
                    <select id="caTurnover" onchange="calcCATax()">
                        <option value="2500">Up to ₹50 Lakhs (GST + IT Filing)</option>
                        <option value="5000">₹50 Lakhs to ₹2 Crore (Full Retainer)</option>
                        <option value="12000">Above ₹2 Crore (Statutory Audit + GST)</option>
                    </select>
                </div>
                <div>
                    <label style="font-size:0.8rem; font-weight:700; color:#475569; display:block; margin-bottom:0.5rem; text-transform:uppercase;">Monthly Invoice Volume: <span id="invVal" style="color:var(--accent); font-weight:800;">100 Invoices</span></label>
                    <input type="range" id="invRange" min="20" max="500" step="20" value="100" oninput="calcCATax()">
                </div>
            </div>
            <div class="calc-result">
                <div>
                    <p style="font-size:0.75rem; text-transform:uppercase; color:#475569; font-weight:700;">Estimated Monthly Retainer Fee:</p>
                    <div id="caResult" class="calc-val">₹6,000 / Month</div>
                </div>
                <button onclick="window.location.href='https://wa.me/{clean_phone}'" class="btn-consult" style="background:var(--accent); border:none; cursor:pointer;">Consult CA Senior Partner &rarr;</button>
            </div>
        </div>
    </section>

    <footer>
        <p style="font-weight:800;">{business_name}</p>
        <p style="font-size:0.8rem; color:#94a3b8; margin-top:0.3rem;">ICAI Member Practice &bull; Senior Partner: {owner_name} &bull; {city}</p>
        <div class="footer-buttons">
            <a href="tel:{phone}" class="btn-call">Direct Call</a>
            <a href="https://wa.me/{clean_phone}" class="btn-wa">WhatsApp Retainer Inquiry</a>
        </div>
    </footer>

    <script>
        function calcCATax() {{
            var base = parseFloat(document.getElementById("caTurnover").value);
            var inv = parseFloat(document.getElementById("invRange").value);
            document.getElementById("invVal").innerText = inv + " Invoices";
            var total = base + (inv * 35);
            document.getElementById("caResult").innerText = "₹" + total.toLocaleString('en-IN') + " / Month";
        }}
    </script>
    {glow_bg_js}
</body>
</html>"""

    # ==========================================
    # TEMPLATE 6: DYNAMIC INDUSTRY SOLUTION
    # ==========================================
    else:
        # Dynamic content customization based on industry keywords
        if "cake" in ind or "bakery" in ind or "bakeries" in ind:
            hero_tag = "Artisan Bakery & Cake Studio"
            hero_headline = f"Handcrafted <span>Artisan Cakes</span> & Fresh Daily Bakes"
            hero_subtitle = f"Bespoke wedding cakes, custom celebration tiers, and gourmet viennoiserie baked fresh daily in {city}."
            sec_title = "Handcrafted Bakery Specialties"
            s1_title, s1_desc = "🎂 Custom Tier & Wedding Cakes", f"Bespoke fondant & cream tier cake designs handcrafted for weddings, anniversaries, and galas in {city}."
            s2_title, s2_desc = "🥐 Fresh Viennoiserie & Breads", f"Flaky butter croissants, artisan sourdough loaves, and French pastries baked fresh every morning."
            s3_title, s3_desc = "🧁 Gourmet Dessert Tables & Gifts", f"Custom dessert tables, macaron towers, and curated bakery hampers for corporate and family events."
            calc_title = "Custom Cake & Order Estimator"
            calc_label1 = "Cake Tiers / Event Type"
            calc_opt1 = '<option value="2000">1-Tier Celebration Cake (10-15 Guests)</option><option value="4500">2-Tier Custom Cake (25-40 Guests)</option><option value="9000">3-Tier Luxury Wedding Cake (50+ Guests)</option>'
            calc_label2 = "Weight / Order Quantity: <span id='unitVal' style='color:var(--accent); font-weight:800;'>2 kg</span>"
            calc_unit_text = " kg"
            btn_text = "Reserve Custom Bakery Order"
            if not services_imgs[0].startswith("http"):
                services_imgs = [
                    "https://images.unsplash.com/photo-1578985545062-69928b1d9587",
                    "https://images.unsplash.com/photo-1509440159596-0249088772ff",
                    "https://images.unsplash.com/photo-1555507036-ab1f4038808a"
                ]
                hero_img = "https://images.unsplash.com/photo-1517433670267-08bbd4be890f"

        elif "cafe" in ind or "restaurant" in ind or "dining" in ind:
            hero_tag = "Boutique Cafe & Culinary Bistro"
            hero_headline = f"Artisan Coffee & <span>Gourmet Culinary</span> Dining"
            hero_subtitle = f"Specialty single-origin coffee, artisanal all-day dining, and private chef specials in {city}."
            sec_title = "Culinary & Espresso Offerings"
            s1_title, s1_desc = "☕ Specialty Brew Bar & Espresso", f"Hand-poured pour-overs, cold brews, and signature espresso beverages in {city}."
            s2_title, s2_desc = "🍽️ Chef's Seasonal Tasting Menu", f"Fresh farm-to-table artisanal dishes, wood-fired sourdough pizzas, and gourmet entrees."
            s3_title, s3_desc = "🎉 Private Table & Event Dining", f"Reserved dining booths, chef's table experiences, and private party hosting."
            calc_title = "Table Reservation & Dining Estimator"
            calc_label1 = "Dining Experience"
            calc_opt1 = '<option value="1500">Bistro High-Tea / Breakfast (Per Head)</option><option value="2800">4-Course Chef Dinner Tasting (Per Head)</option><option value="5000">VIP Private Dining Room Experience</option>'
            calc_label2 = "Number of Guests: <span id='unitVal' style='color:var(--accent); font-weight:800;'>4 Guests</span>"
            calc_unit_text = " Guests"
            btn_text = "Reserve Dining Table"
            if not services_imgs[0].startswith("http"):
                services_imgs = [
                    "https://images.unsplash.com/photo-1554118811-1e0d58224f24",
                    "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb",
                    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4"
                ]
                hero_img = "https://images.unsplash.com/photo-1559925393-8be0ec4767c8"

        elif "flor" in ind or "floral" in ind or "flower" in ind:
            hero_tag = "Luxury Botanical & Floral Studio"
            hero_headline = f"Exquisite Floral Curation & <span>Wedding Blooms</span>"
            hero_subtitle = f"Grand wedding floral installations, exotic flower arches, and luxury gift bouquets in {city}."
            sec_title = "Floral Design Services"
            s1_title, s1_desc = "💐 Wedding Floral Installations", f"Grand floral arches, stage backdrops, and aisle bloom styling in {city}."
            s2_title, s2_desc = "🌹 Exotic Bouquets & Gift Hampers", f"Premium imported roses, lilies, orchids, and custom luxury floral boxes."
            s3_title, s3_desc = "🌿 Corporate & Hotel Floral Styling", f"Weekly fresh floral lobby arrangements and luxury venue transformations."
            calc_title = "Floral Installation Budget Estimator"
            calc_label1 = "Design Scope"
            calc_opt1 = '<option value="8000">Boutique Bouquet & Table Styling</option><option value="25000">Full Venue Floral Entrance Archways</option><option value="60000">Grand Luxury Wedding Floral Curation</option>'
            calc_label2 = "Arrangement Scale: <span id='unitVal' style='color:var(--accent); font-weight:800;'>50 Units</span>"
            calc_unit_text = " Units"
            btn_text = "Consult Floral Designer"
            if not services_imgs[0].startswith("http"):
                services_imgs = [
                    "https://images.unsplash.com/photo-1561181286-d3fee7d55364",
                    "https://images.unsplash.com/photo-1526047932273-341f2a7631f9",
                    "https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11"
                ]
                hero_img = "https://images.unsplash.com/photo-1563241527-3004b7be0ffd"

        elif "boutique" in ind or "jewel" in ind or "clothing" in ind or "fashion" in ind:
            hero_tag = "Haute Couture & Jewellery Atelier"
            hero_headline = f"Bespoke Couture & <span>Fine Jewellery</span> Atelier"
            hero_subtitle = f"Handcrafted bridal lehengas, heritage Kundan & Polki jewellery, and custom fashion styling in {city}."
            sec_title = "Atelier Collections"
            s1_title, s1_desc = "💎 Handcrafted Fine Jewellery", f"Intricate bridal sets, heritage Kundan, Polki, and certified solitaire jewellery in {city}."
            s2_title, s2_desc = "👗 Bespoke Designer Couture", f"Hand-embroidered bridal lehengas, sherwanis, and couture evening gowns."
            s3_title, s3_desc = "🧵 Private Styling Appointments", f"One-on-one bridal consultations and custom couture tailor fittings."
            calc_title = "Bespoke Couture & Ensemble Estimator"
            calc_label1 = "Ensemble Category"
            calc_opt1 = '<option value="15000">Designer Festive Trousseau</option><option value="45000">Bespoke Bridal Lehenga / Sherwani</option><option value="120000">Heritage Bridal Jewellery & Couture</option>'
            calc_label2 = "Ensemble Count: <span id='unitVal' style='color:var(--accent); font-weight:800;'>1 Piece</span>"
            calc_unit_text = " Piece"
            btn_text = "Book Private Fitting"
            if not services_imgs[0].startswith("http"):
                services_imgs = [
                    "https://images.unsplash.com/photo-1535632066927-ab7c9ab60908",
                    "https://images.unsplash.com/photo-1441986300917-64674bd600d8",
                    "https://images.unsplash.com/photo-1490481651871-ab68de25d43d"
                ]
                hero_img = "https://images.unsplash.com/photo-1605100804763-247f67b3557e"

        elif "hotel" in ind or "guesthouse" in ind or "travel" in ind:
            hero_tag = "Boutique Hospitality & Stays"
            hero_headline = f"Curated Stays & <span>Luxury Hospitality</span>"
            hero_subtitle = f"Boutique heritage suites, organic dining, and private curated local travel itineraries in {city}."
            sec_title = "Guest & Travel Experiences"
            s1_title, s1_desc = "🏨 Heritage Suites & Luxury Stay", f"Elegantly appointed suites featuring local craftsmanship and modern amenities in {city}."
            s2_title, s2_desc = "🍽️ In-House Gourmet Dining & Spa", f"Organic farm-to-table breakfasts and holistic wellness experiences."
            s3_title, s3_desc = "✈️ Tailored Private Itineraries", f"Guided heritage walks, private airport transfers, and bespoke local experiences."
            calc_title = "Stay & Experience Rate Calculator"
            calc_label1 = "Accommodation Category"
            calc_opt1 = '<option value="4500">Deluxe Heritage Room (Per Night)</option><option value="9000">Executive Luxury Suite (Per Night)</option><option value="18000">Private Royal Villa (Per Night)</option>'
            calc_label2 = "Duration of Stay: <span id='unitVal' style='color:var(--accent); font-weight:800;'>2 Nights</span>"
            calc_unit_text = " Nights"
            btn_text = "Check Availability & Book"
            if not services_imgs[0].startswith("http"):
                services_imgs = [
                    "https://images.unsplash.com/photo-1566073771259-6a8506099945",
                    "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b",
                    "https://images.unsplash.com/photo-1488646953014-85cb44e25828"
                ]
                hero_img = "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4"

        else:
            hero_tag = f"Premium {industry.title()}"
            hero_headline = f"Bespoke <span>{industry.title()}</span> Curation"
            hero_subtitle = f"Professional bespoke services and custom execution delivered for local clients in {city}."
            sec_title = "Core Capabilities"
            s1_title, s1_desc = "Custom Services Curation", f"Bespoke service solutions and high-standard operational setup in {city}."
            s2_title, s2_desc = "Quality Assurance & Supervision", f"Turnkey supervision, quality material sourcing, and execution control."
            s3_title, s3_desc = "Turnkey Management", f"Guaranteed compliance with quality standards and complete delivery."
            calc_title = "Project Budget Estimator"
            calc_label1 = "Project Scope"
            calc_opt1 = '<option value="5000">Standard Scope</option><option value="15000">Premium Bespoke Scope</option><option value="35000">Turnkey Curation</option>'
            calc_label2 = "Project Scale: <span id='unitVal' style='color:var(--accent); font-weight:800;'>100 Units</span>"
            calc_unit_text = " Units"
            btn_text = "Request Direct Consultation"
            if not services_imgs[0].startswith("http"):
                services_imgs = [
                    "https://images.unsplash.com/photo-1464938050520-ef2270bb8ce8",
                    "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab",
                    "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40"
                ]
                hero_img = "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab"

        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{business_name} | {hero_tag} in {city}</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&family=Playfair+Display:ital,wght@0,600;0,700;1,400&display=swap" rel="stylesheet">
    <style>
        :root {{ 
            --bg: #fafaf9; 
            --primary: #1c1917; 
            --accent: #0f766e; 
            --accent-hover: #115e59;
            --card: #ffffff; 
            --border: #e7e5e4; 
            --glow-primary: rgba(15, 118, 110, 0.12);
            --glow-secondary: rgba(180, 83, 9, 0.08);
        }}
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ background: var(--bg); color: var(--primary); font-family: 'Plus Jakarta Sans', sans-serif; overflow-x: hidden; }}
        
        {glow_bg_styles}

        nav {{ display: flex; justify-content: space-between; align-items: center; padding: 1.5rem 3rem; background: rgba(250, 250, 249, 0.9); backdrop-filter: blur(12px); border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 100; }}
        .brand {{ font-family: 'Playfair Display', serif; font-size: 1.35rem; font-weight: 700; letter-spacing: -0.5px; }}
        .brand span {{ color: var(--accent); }}
        .btn-consult {{ background: var(--primary); color: #fff; padding: 0.6rem 1.4rem; border-radius: 30px; text-decoration: none; font-weight: 700; font-size: 0.8rem; transition: background 0.3s; }}
        .btn-consult:hover {{ background: var(--accent); }}

        .hero {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 4rem; align-items: center; padding: 5rem 3rem; max-width: 1200px; margin: 0 auto; }}
        .hero-tag-badge {{ font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px; color: var(--accent); font-weight: 800; margin-bottom: 0.8rem; display: inline-block; background: #f0fdfa; padding: 0.3rem 0.8rem; border-radius: 20px; border: 1px solid rgba(15, 118, 110, 0.2); }}
        .hero-info h1 {{ font-family: 'Playfair Display', serif; font-size: clamp(2.2rem, 4vw, 3.6rem); line-height: 1.15; margin-bottom: 1.2rem; }}
        .hero-info h1 span {{ color: var(--accent); font-style: italic; font-weight: 400; }}
        .hero-info p {{ color: #57534e; font-size: 1.05rem; line-height: 1.7; margin-bottom: 2rem; }}
        .hero-img {{ border-radius: 16px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 15px 30px rgba(0, 0, 0, 0.04); height: 420px; }}
        .hero-img img {{ width: 100%; height: 100%; object-fit: cover; display: block; }}

        .section {{ padding: 6rem 3rem; max-width: 1200px; margin: 0 auto; }}
        .sec-title {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; text-align: center; margin-bottom: 4rem; }}
        .services-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2.5rem; }}
        .service-card {{ background: var(--card); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; transition: all 0.3s ease; }}
        .service-card:hover {{ transform: translateY(-5px); box-shadow: 0 20px 40px rgba(15, 118, 110, 0.06); border-color: var(--accent); }}
        .service-card img {{ width: 100%; height: 240px; object-fit: cover; }}
        .service-info {{ padding: 2rem; }}
        .service-info h3 {{ font-family: 'Playfair Display', serif; font-size: 1.35rem; font-weight: 700; margin-bottom: 0.6rem; }}
        .service-info p {{ color: #57534e; font-size: 0.9rem; line-height: 1.6; }}

        .calc-wrapper {{ background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 3rem; box-shadow: 0 10px 25px rgba(0,0,0,0.02); }}
        .calc-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 2rem; margin-bottom: 2rem; }}
        .calc-field label {{ font-size: 0.8rem; text-transform: uppercase; font-weight: 700; letter-spacing: 0.5px; color: #57534e; display: block; margin-bottom: 0.5rem; }}
        select, input[type="range"] {{ width: 100%; padding: 0.8rem; background: var(--bg); border: 1px solid var(--border); border-radius: 4px; outline: none; }}
        .calc-result {{ background: #f0fdfa; padding: 2rem; border-radius: 8px; border: 1px solid rgba(15, 118, 110, 0.2); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.5rem; }}
        .calc-val {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; color: var(--accent); font-weight: 700; }}

        footer {{ padding: 5rem 3rem; background: var(--primary); color: #fff; text-align: center; }}
        .footer-logo {{ font-family: 'Playfair Display', serif; font-size: 2.2rem; font-style: italic; margin-bottom: 1rem; }}
        .footer-buttons {{ display: flex; justify-content: center; gap: 1.5rem; flex-wrap: wrap; margin-top: 2rem; }}
        .btn-call {{ border: 1px solid rgba(255,255,255,0.3); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 30px; font-weight: 700; font-size: 0.85rem; }}
        .btn-wa {{ background: var(--accent); color: #fff; padding: 0.6rem 2rem; text-decoration: none; border-radius: 30px; font-weight: 800; font-size: 0.85rem; }}
    </style>
</head>
<body>

    <nav>
        <div class="brand">{business_name.split()[0]} <span>Studio</span></div>
        <a href="https://wa.me/{clean_phone}" class="btn-consult">Direct Inquiry</a>
    </nav>

    <section class="hero scroll-reveal">
        <div class="hero-info">
            <span class="hero-tag-badge">{hero_tag} &bull; {city}</span>
            <h1>{hero_headline}</h1>
            <p>{hero_subtitle}</p>
            <a href="#estimator" class="btn-consult" style="padding: 0.75rem 2rem;">{btn_text} &rarr;</a>
        </div>
        <div class="hero-img">
            <img src="{hero_img}" alt="{business_name}">
        </div>
    </section>

    <section class="section scroll-reveal">
        <h2 class="sec-title">{sec_title}</h2>
        <div class="services-grid">
            <div class="service-card">
                <img src="{services_imgs[0]}" alt="{s1_title}">
                <div class="service-info">
                    <h3>{s1_title}</h3>
                    <p>{s1_desc}</p>
                </div>
            </div>
            <div class="service-card">
                <img src="{services_imgs[1]}" alt="{s2_title}">
                <div class="service-info">
                    <h3>{s2_title}</h3>
                    <p>{s2_desc}</p>
                </div>
            </div>
            <div class="service-card">
                <img src="{services_imgs[2]}" alt="{s3_title}">
                <div class="service-info">
                    <h3>{s3_title}</h3>
                    <p>{s3_desc}</p>
                </div>
            </div>
        </div>
    </section>

    <section class="section scroll-reveal" id="estimator">
        <h2 class="sec-title">{calc_title}</h2>
        <div class="calc-wrapper">
            <div class="calc-grid">
                <div class="calc-field">
                    <label>{calc_label1}</label>
                    <select id="projectScale" onchange="calcProjectCost()">
                        {calc_opt1}
                    </select>
                </div>
                <div class="calc-field">
                    <label>{calc_label2}</label>
                    <input type="range" id="unitRange" min="1" max="100" step="1" value="10" oninput="calcProjectCost()">
                </div>
            </div>
            <div class="calc-result">
                <div>
                    <p style="font-size:0.75rem; text-transform:uppercase; color:#57534e; font-weight:700;">Estimated Budget / Quote:</p>
                    <div id="projectResult" class="calc-val">₹4,500</div>
                </div>
                <button onclick="window.location.href='https://wa.me/{clean_phone}'" class="btn-consult" style="background:var(--accent); border:none; cursor:pointer;">{btn_text} &rarr;</button>
            </div>
        </div>
    </section>

    <footer>
        <div class="footer-logo">{business_name}</div>
        <p style="font-size:0.9rem; opacity:0.8; margin-top:0.3rem;">{hero_tag} &bull; {city}</p>
        <div class="footer-buttons">
            <a href="tel:{phone}" class="btn-call">Direct Phone</a>
            <a href="https://wa.me/{clean_phone}" class="btn-wa">WhatsApp Inquiry &rarr;</a>
        </div>
    </footer>

    <script>
        function calcProjectCost() {{
            var base = parseFloat(document.getElementById("projectScale").value);
            var units = parseFloat(document.getElementById("unitRange").value);
            var uText = "{calc_unit_text}";
            document.getElementById("unitVal").innerText = units + uText;
            var total = base + (units * (base > 10000 ? 500 : 150));
            document.getElementById("projectResult").innerText = "₹" + total.toLocaleString('en-IN');
        }}
    </script>
    {glow_bg_js}
</body>
</html>"""

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

    # Duplicate scrape_google_maps_playwright removed to use the original, robust, details-extracting version.

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
            
            # No fake owner names - only real data from Google Maps
            owner_name = "Business Owner"
            
            # Do not generate fake/placeholder emails
            email = ""
            
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
