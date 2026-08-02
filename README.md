# 🚀 B2B Lead Generation & Automated WhatsApp Outreach Engine

An end-to-end autonomous B2B lead generation, website mockup generator, 24/7 cloud hosting, and stealth WhatsApp outreach platform.

---

## 🌟 Key Features

### 1. 🗺️ Strict Google Maps Live Scraping (`crawler.py`)
- Live Playwright Chrome automation targeting Google Maps search listings (`https://www.google.com/maps/search/...`).
- Extracts verified SMB business names, phone numbers, addresses, ratings, and websites.

### 2. 🎨 Agency-Grade Website Mockup Generator
- Generates high-converting, fully responsive, animated HTML websites for every discovered business.
- Includes fluid typography (`clamp()`), industry photo assets (`image_pool.json`), interactive calculators, and modal booking popups.

### 3. 🌐 24/7 Permanent Cloud Hosting (GitHub Pages)
- Auto-commits and pushes all website mockups to GitHub Pages.
- Prospective clients can view their custom website preview **24/7/365 from any phone or PC worldwide** with zero local server/PC dependency!

### 4. 🛡️ Unbannable Anti-Spam WhatsApp Engine (`whatsapp_automation.py`)
- **Keystroke-by-Keystroke Human Typing Simulation**: Character-by-character typing (`40ms - 110ms` per letter) with micro-pauses for punctuation and `Shift+Enter` multi-line support.
- **Spintax Text Randomization (`generate_spintax_pitch`)**: Rotates greetings, intros, and call-to-actions so no two outgoing messages are byte-for-byte identical.
- **Business Hours Enforcement**: Strictly operates between 9:30 AM and 6:30 PM local time.
- **Daily Outreach Safety Cap**: Configurable limit (e.g. 30–50 messages/24h).
- **Permanent Deduplication Registry (`texted_numbers.json`)**: Prevents messaging any client twice across restarts.

### 5. 📊 Central Streamlit Web Dashboard (`app.py`)
- Real-time lead management, pipeline analytics, lead deletion, crawler delay controls, and live WhatsApp session status.

---

## 🛠️ Quick Start Guide

### Step 1: Install Dependencies
```bash
pip install -r requirements.txt
playwright install chromium
```

### Step 2: One-Time WhatsApp Web Login
Log into WhatsApp Web ONCE to permanently save your browser profile session:
```bash
python login_whatsapp.py
```
*Scan the QR code in the browser window, then press ENTER in your terminal.*

### Step 3: Launch the Master System
```bash
python start.py
```
This launches:
1. **Streamlit Web Dashboard** (`http://localhost:8501`)
2. **Google Maps Lead Crawler & Auto-Outreach Loop**

---

## ⚙️ Configuration (`crawler_settings.json`)

Customize crawler behavior directly or via the web dashboard:
```json
{
  "whatsapp_enabled": true,
  "min_delay": 90,
  "max_delay": 180,
  "max_results": 100
}
```

---

## 📁 Project Structure

```text
├── app.py                   # Streamlit Web Dashboard UI
├── crawler.py               # Google Maps Scraper & Mockup Generator
├── whatsapp_automation.py   # Stealth WhatsApp Automation Engine
├── login_whatsapp.py        # 1-Time Session Authenticator
├── config.py                # System Paths & Configurations
├── crawler_settings.json    # Crawler & Outreach Settings
├── image_pool.json          # Industry Photo Asset Registry
├── mockups/                 # Generated Website HTML Files
├── texted_numbers.json      # Permanent Contacted Numbers Log
├── start.py                 # System Orchestrator
├── setup.bat                # Windows 1-Click Setup Script
└── start.bat                # Windows 1-Click Launch Script
```

---

## 🌐 GitHub Repository
Pushed live at: **[https://github.com/obeygaming035-pixel/lead-finder](https://github.com/obeygaming035-pixel/lead-finder)**
