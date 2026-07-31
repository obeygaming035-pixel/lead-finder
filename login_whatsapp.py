"""
One-Time WhatsApp Web Session Authenticator
Run this script ONCE to log into WhatsApp Web.
The authenticated session is saved permanently in wa_browser_profile.
Future automated runs will reuse this logged-in session automatically!
"""

import time
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE_DIR = Path(__file__).resolve().parent
PROFILE_DIR = BASE_DIR / "wa_browser_profile"

def authenticate_whatsapp():
    PROFILE_DIR.mkdir(exist_ok=True)
    print("=" * 60)
    print("  WhatsApp Web One-Time Session Authenticator")
    print("=" * 60)
    print("\n[+] Opening browser window for WhatsApp Web login...")
    
    with sync_playwright() as p:
        browser = p.chromium.launch_persistent_context(
            user_data_dir=str(PROFILE_DIR),
            headless=False,
            channel="chrome",
            args=['--no-sandbox', '--disable-setuid-sandbox']
        )
        page = browser.pages[0] if browser.pages else browser.new_page()
        page.goto("https://web.whatsapp.com")
        
        print("\n👉 SCAN THE QR CODE in the opened Chrome browser window if asked.")
        print("👉 Once your chats appear and you are logged into WhatsApp Web, press ENTER below!")
        input("\n[PRESS ENTER HERE WHEN YOU ARE LOGGED IN] -> ")
        
        print("\n[✅] WhatsApp Web login session saved successfully into wa_browser_profile!")
        browser.close()

if __name__ == "__main__":
    authenticate_whatsapp()
