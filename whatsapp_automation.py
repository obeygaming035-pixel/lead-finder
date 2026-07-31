"""
WhatsApp Web Outreach & Automated Inbox Cleanup Engine (Playwright Powered)
Features:
1. Direct WhatsApp Web Links (web.whatsapp.com) - skips Desktop app prompts
2. Playwright Automated Sender: Sends pitch message & automatically Archives/Deletes un-replied chat
3. When client replies, the chat automatically re-appears in your main inbox!
"""

import urllib.parse
import re
import time
import sqlite3
import json
import webbrowser
import random
from datetime import datetime, timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "leads.db"
PROFILE_DIR = BASE_DIR / "wa_browser_profile"
TEXTED_FILE = BASE_DIR / "texted_numbers.json"

# Safety limits configuration
DAILY_OUTREACH_LIMIT = 50
BUSINESS_HOURS_START = 9    # 9:00 AM
BUSINESS_HOURS_END = 18.5   # 6:30 PM

def is_within_business_hours():
    """Checks if the current local time is within business hours (9:00 AM - 6:30 PM)."""
    now = datetime.now()
    hour_fraction = now.hour + now.minute / 60.0
    return BUSINESS_HOURS_START <= hour_fraction < BUSINESS_HOURS_END

def sleep_until_business_hours():
    """Blocks the thread and sleeps until the next business hours window opens."""
    now = datetime.now()
    hour_fraction = now.hour + now.minute / 60.0
    if BUSINESS_HOURS_START <= hour_fraction < BUSINESS_HOURS_END:
        return
        
    target = now.replace(hour=9, minute=0, second=0, microsecond=0)
    if hour_fraction >= BUSINESS_HOURS_END:
        # After business hours, sleep until tomorrow 9:00 AM
        target += timedelta(days=1)
    
    sleep_seconds = (target - now).total_seconds()
    print(f"\n[⏰] Outside business hours ({now.strftime('%H:%M')}). Sleeping for {sleep_seconds:.1f}s until {target.strftime('%Y-%m-%d %H:%M:%S')}...")
    time.sleep(sleep_seconds)
    print("[⏰] Business hours opened. Resuming WhatsApp automation...")

def get_sent_count_last_24h():
    """Counts the number of successfully contacted leads in the last 24 hours."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM leads WHERE status = 'Contacted' AND timestamp >= datetime('now', '-1 day')")
        count = cursor.fetchone()[0]
        conn.close()
        return count
    except Exception as e:
        print(f"[!] Error reading last 24h sent count: {e}")
        return 0

def clean_phone_number(phone):
    """Clean phone number to international format without + or spaces (e.g., 919820155667)."""
    digits = re.sub(r'\D', '', str(phone))
    if len(digits) == 10:
        digits = '91' + digits  # Default India country code if 10 digits
    return digits

def get_texted_numbers():
    """Load dictionary of all permanently contacted phone numbers across dashboard restarts."""
    if TEXTED_FILE.exists():
        try:
            with open(TEXTED_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def record_texted_number(phone, status="Contacted"):
    """Permanently save a messaged phone number so it is NEVER repeated across restarts."""
    clean = clean_phone_number(phone)
    data = get_texted_numbers()
    data[clean] = {
        "status": status,
        "timestamp": datetime.now().isoformat()
    }
    try:
        with open(TEXTED_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"[!] Error saving texted history: {e}")

def is_number_already_texted(phone):
    """Check if number was ever messaged or processed in the past."""
    clean = clean_phone_number(phone)
    data = get_texted_numbers()
    return clean in data

def generate_wa_link(phone, pitch_text):
    """
    Generate a direct WhatsApp Web link (web.whatsapp.com).
    Forces opening in web browser directly without Desktop App prompts.
    """
    clean_phone = clean_phone_number(phone)
    encoded_text = urllib.parse.quote(pitch_text)
    return f"https://web.whatsapp.com/send?phone={clean_phone}&text={encoded_text}"

def send_whatsapp_message(phone, pitch_text, cleanup_action="archive", wait_seconds=5):
    """
    Automates WhatsApp Web sending & immediate chat cleanup via Playwright.
    Reuses your saved WhatsApp Web login session from wa_browser_profile.
    Smoothly types & dispatches messages without premature window closures.
    """
    clean_phone = clean_phone_number(phone)
    
    # 🛑 Rule 1: Check Permanent History - NEVER repeat text across restarts!
    if is_number_already_texted(clean_phone):
        print(f"[🛡️] Number {clean_phone} was ALREADY messaged in permanent history. Skipping!")
        return "ALREADY_TEXTED"
        
    # 🛑 Rule 2: Enforce Business Hours
    sleep_until_business_hours()
    
    # 🛑 Rule 3: Enforce Daily Limits
    sent_today = get_sent_count_last_24h()
    if sent_today >= DAILY_OUTREACH_LIMIT:
        print(f"[🛡️] Daily WhatsApp outreach limit ({DAILY_OUTREACH_LIMIT}) reached! Skipping lead to prevent ban.")
        return "DAILY_LIMIT_REACHED"
        
    wa_url = generate_wa_link(phone, pitch_text)
    
    try:
        from playwright.sync_api import sync_playwright
        PROFILE_DIR.mkdir(exist_ok=True)
        
        with sync_playwright() as p:
            # Launch persistent browser using system Chrome channel & saved profile
            browser = p.chromium.launch_persistent_context(
                user_data_dir=str(PROFILE_DIR),
                headless=False,
                channel="chrome",
                args=['--no-sandbox', '--disable-setuid-sandbox', '--disable-blink-features=AutomationControlled']
            )
            page = browser.pages[0] if browser.pages else browser.new_page()
            
            print(f"[💬] Accessing WhatsApp Web session for {clean_phone}...")
            page.goto(wa_url)
            
            # Wait for text box or invalid number popup to load
            start_time = time.time()
            chat_found = False
            
            while time.sleep(1) or (time.time() - start_time < 25):
                # 1. Check if chat input area is ready
                chat_box = page.query_selector('div[contenteditable="true"][data-tab="10"]') or page.query_selector('footer div[contenteditable="true"]')
                if chat_box:
                    chat_found = True
                    break
                    
                # 2. Check for explicit "Phone number shared via url is invalid" popup
                invalid_dialog = page.query_selector('text="Phone number shared via url is invalid."') or page.query_selector('text="Phone number is invalid"')
                if invalid_dialog:
                    print(f"[⚠️] Number {clean_phone} is NOT on WhatsApp! Closing window...")
                    time.sleep(1)
                    browser.close()
                    record_texted_number(phone, "Not on WhatsApp")
                    return "NOT_ON_WHATSAPP"
 
                # 3. Check if QR code page (user needs to log in)
                if page.query_selector('canvas[aria-label="Scan me!"]') or page.query_selector('text="To use WhatsApp on your computer"'):
                    print("\n[!] NOTICE: WhatsApp Web is not logged in yet!")
                    print("[!] Please run 'python login_whatsapp.py' ONCE to log into WhatsApp Web.")
                    browser.close()
                    return "NOT_LOGGED_IN"
 
            if chat_found:
                # 🛡️ Human-Like Typing Simulation & Delay (Meta Guideline compliance)
                print("  -> Simulating message review...")
                chat_box.focus()
                time.sleep(random.uniform(4.0, 7.0))  # Pause to read/review
                
                # Type a small spacing sequence to trigger WhatsApp's "typing..." status
                page.keyboard.type(" ")
                time.sleep(random.uniform(1.0, 2.5))
                page.keyboard.press("Backspace")
                
                # Dynamic delay before hitting send
                time.sleep(random.uniform(4.0, 8.0))
                
                # Press Enter to send pre-filled pitch text
                page.keyboard.press('Enter')
                print(f"[✅] Pitch sent successfully to {clean_phone}!")
                record_texted_number(phone, "Contacted")
                
                # Post-send pause
                time.sleep(random.uniform(3.0, 5.0))
                
                # Perform Chat Cleanup (Archive or Delete)
                if cleanup_action == "archive":
                    try:
                        page.keyboard.press('Control+Shift+E')  # Archive shortcut on Web
                        print(f"[📦] Auto-Archived chat for {clean_phone} (Will re-appear when they reply!)")
                        time.sleep(1.5)
                    except Exception:
                        pass
                elif cleanup_action == "delete":
                    try:
                        menu_btn = page.query_selector('div[title="Menu"], span[data-icon="menu"]')
                        if menu_btn:
                            menu_btn.click()
                            time.sleep(1)
                            delete_opt = page.query_selector('div[role="button"]:has-text("Delete chat")')
                            if delete_opt:
                                delete_opt.click()
                                time.sleep(1)
                                confirm_btn = page.query_selector('button:has-text("Delete chat")')
                                if confirm_btn:
                                    confirm_btn.click()
                                    print(f"[🗑️] Deleted chat for {clean_phone} to keep inbox 100% clean.")
                                    time.sleep(1.5)
                    except Exception as e:
                        print(f"[!] Cleanup note: {e}")
                
                browser.close()
                return True
            else:
                print(f"[⚠️] Timeout waiting for chat to load for {clean_phone}. Closing window...")
                browser.close()
                record_texted_number(phone, "Not on WhatsApp")
                return "NOT_ON_WHATSAPP"
                
    except Exception as err:
        print(f"[!] Browser automation notice: {err}")
        return "ERROR"

def update_lead_status(lead_id, status_text):
    """Update database status for a lead."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("UPDATE leads SET status = ? WHERE id = ?", (status_text, lead_id))
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"[!] Error updating lead #{lead_id}: {e}")
        return False

def mark_lead_contacted(lead_id):
    """Update database status for a lead to 'Contacted'."""
    return update_lead_status(lead_id, "Contacted")

def run_whatsapp_bulk_campaign(delay_between_messages=120, cleanup_action="archive"):
    """
    Sequential bulk campaign dispatcher with automatic chat archiving/clearing.
    Iterates through all 'Pending Review' leads in leads.db and dispatches pitches via WhatsApp Web.
    Enforces randomized cooldowns of 90-240 seconds by default for anti-spam safety.
    """
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, business_name, owner_name, phone, initial_pitch FROM leads WHERE status = 'Pending Review'")
    leads = cursor.fetchall()
    conn.close()

    if not leads:
        print("[+] No pending leads to contact in WhatsApp campaign.")
        return 0

    print(f"[🚀] Starting Bulk WhatsApp Web Campaign for {len(leads)} Pending Leads...")
    sent_count = 0

    for lead_id, biz_name, owner_name, phone, pitch in leads:
        if not phone or not pitch:
            continue
        
        # Enforce business hours check for each lead
        sleep_until_business_hours()
        
        print(f"\n[💬] Dispatching to Lead #{lead_id}: {biz_name} ({owner_name}) - Phone: {phone}")
        res = send_whatsapp_message(phone, pitch, cleanup_action=cleanup_action)
        
        if res == True:
            mark_lead_contacted(lead_id)
            sent_count += 1
            
            # Anti-spam delay between dispatches (randomized between 90 and 240 seconds)
            cooldown = random.randint(90, 240)
            print(f"[🛡️] Anti-spam cooldown: Pausing for {cooldown}s before next message...")
            time.sleep(cooldown)
        elif res == "DAILY_LIMIT_REACHED":
            print("[🛡️] Daily limit reached. Pausing bulk campaign.")
            break
        elif res == "NOT_LOGGED_IN":
            print("[!] WhatsApp Web session not authenticated. Pausing campaign.")
            break
        else:
            # For invalid numbers, mark contacted or similar and proceed immediately
            mark_lead_contacted(lead_id)

    print(f"[✅] Bulk Campaign Complete! Successfully contacted {sent_count} leads.")
    return sent_count

if __name__ == "__main__":
    test_link = generate_wa_link("+91 98201 55667", "Hello Aniket! Check out your website preview.")
    print("Test WhatsApp Web Link:", test_link)

