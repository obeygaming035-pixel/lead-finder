import json
import time
import random
import re
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE_DIR = Path(__file__).resolve().parent
POOL_FILE = BASE_DIR / "image_pool.json"

# Define industries and search terms
NICHES_TERMS = {
    "architects & interior design studios": [
        "luxury-interior-design",
        "modern-villa-architecture",
        "luxury-penthouse"
    ],
    "wedding & luxury event planners": [
        "luxury-wedding-decor",
        "indian-wedding-stage",
        "royal-banquet-hall"
    ],
    "custom furniture & woodwork studios": [
        "teak-dining-table",
        "custom-wood-furniture",
        "luxury-living-room-sofa"
    ],
    "industrial machinery & tool suppliers": [
        "cnc-machine-industrial",
        "lathe-tool-factory",
        "precision-metal-manufacturing"
    ],
    "chartered accountants & tax advisory firms": [
        "corporate-office-boardroom",
        "financial-advisory-business",
        "modern-accounting-office"
    ],
    "cake shops / custom bakeries": [
        "wedding-cake-artisan",
        "bakery-pastry-croissant",
        "gourmet-dessert-table"
    ],
    "cafes": [
        "specialty-coffee-barista",
        "cozy-cafe-interior",
        "artisan-latte-art"
    ],
    "restaurants": [
        "fine-dining-restaurant",
        "gourmet-food-plating",
        "wood-fired-bistro"
    ],
    "florists / wedding floral businesses": [
        "wedding-floral-arch",
        "luxury-flower-bouquet",
        "botanical-florist-shop"
    ],
    "boutiques / designer clothing stores": [
        "designer-lehenga-bridal",
        "boutique-fashion-store",
        "luxury-couture-gowns"
    ],
    "jewellery boutiques": [
        "fine-diamond-jewellery",
        "kundan-gold-necklace",
        "luxury-jewelry-display"
    ],
    "boutique hotels / guesthouses": [
        "boutique-hotel-suite",
        "luxury-resort-pool",
        "heritage-villa-stay"
    ],
    "travel agencies": [
        "luxury-travel-resort",
        "tropical-island-vacation",
        "scenic-destination-flight"
    ],
    "wedding photographers": [
        "indian-bridal-photography",
        "wedding-couple-portrait",
        "cinematic-wedding-camera"
    ],
    "party/event decorators": [
        "event-stage-decoration",
        "balloon-arch-party",
        "reception-backdrop-lighting"
    ]
}

def scrape_unsplash():
    print("=" * 60)
    print("  Scraping Image Pools from Unsplash (Playwright)")
    print("=" * 60)
    
    image_pool = {}
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        # Create a browser context with a realistic User-Agent
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = context.new_page()
        
        for niche, terms in NICHES_TERMS.items():
            print(f"\n[+] Harvesting images for niche: '{niche}'")
            niche_images = []
            
            for term in terms:
                url = f"https://unsplash.com/s/photos/{term}"
                print(f"    -> Searching Unsplash: {url}")
                try:
                    page.goto(url, timeout=30000)
                    page.wait_for_timeout(3000)
                    
                    # Scroll down several times to load dynamic contents
                    for scroll_idx in range(6):
                        page.mouse.wheel(0, 3000)
                        page.wait_for_timeout(1500)
                    
                    # Select images starting with the Unsplash photo CDN URL
                    img_elements = page.query_selector_all('img[src*="images.unsplash.com/photo-"]')
                    term_count = 0
                    for img in img_elements:
                        src = img.get_attribute("src")
                        if src:
                            # Clean the URL to get the base photo URL without query parameters
                            match = re.match(r'(https://images\.unsplash\.com/photo-[a-zA-Z0-9\-]+)', src)
                            if match:
                                base_url = match.group(1)
                                if base_url not in niche_images:
                                    niche_images.append(base_url)
                                    term_count += 1
                    print(f"       Found {term_count} images for query '{term}'")
                except Exception as e:
                    print(f"       [!] Error scraping search term '{term}': {e}")
            
            # De-duplicate and save
            image_pool[niche] = niche_images
            print(f"[OK] Gathered total {len(niche_images)} unique images for '{niche}'")
            
        browser.close()
        
    # Write image pool to json
    try:
        with open(POOL_FILE, "w", encoding="utf-8") as f:
            json.dump(image_pool, f, indent=2)
        print("\n" + "=" * 60)
        print(f"SUCCESS: Saved {sum(len(v) for v in image_pool.values())} image URLs to {POOL_FILE}")
        print("=" * 60)
    except Exception as e:
        print(f"[ERROR] Failed to save image pool JSON: {e}")

if __name__ == "__main__":
    scrape_unsplash()
