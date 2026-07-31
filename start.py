"""
Master launcher for the B2B Lead Generation Engine.
Run this ONE script and it handles everything:
  1. Deletes old tunnel URL
  2. Starts the static HTML web server + Cloudflare tunnel (new window)
  3. Waits for the new tunnel URL to appear
  4. Seeds the database with the CORRECT live URL
  5. Starts Streamlit dashboard (new window)
  6. Starts the crawler worker (new window)
"""
import subprocess
import sys
import time
import os
import shutil
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
TUNNEL_FILE = BASE_DIR / "tunnel_url.txt"

print("=" * 60)
print("  B2B Lead Generation Engine - Master Launcher")
print("=" * 60)

# Step 0: Clean up old tunnel URL so we don't read a stale one
if TUNNEL_FILE.exists():
    os.remove(TUNNEL_FILE)
    print("[0/5] Deleted old tunnel_url.txt")

# Step 1: Launch run_tunnel.py in its own CMD window
print("[1/5] Starting HTML Web Server + Cloudflare Public Tunnel...")
subprocess.Popen(
    ['cmd', '/k', f'cd /d {BASE_DIR} && python run_tunnel.py'],
    creationflags=subprocess.CREATE_NEW_CONSOLE
)

# Step 2: Wait for the tunnel URL to be captured
print("[2/5] Waiting for Cloudflare to assign a live public URL...", end="", flush=True)
tunnel_url = None
for i in range(90):  # Wait up to 90 seconds
    if TUNNEL_FILE.exists() and TUNNEL_FILE.stat().st_size > 10:
        url = TUNNEL_FILE.read_text(encoding="utf-8").strip()
        if url.startswith("https://") and "trycloudflare.com" in url:
            tunnel_url = url
            break
    print(".", end="", flush=True)
    time.sleep(1)

if not tunnel_url:
    print("\n[ERROR] Could not get tunnel URL after 90 seconds. Check run_tunnel.py window.")
    sys.exit(1)

print(f"\n[2/5] Live public URL captured: {tunnel_url}")

# Step 3: Seed the database with correct live URLs
print("[3/5] Seeding database with live public preview links...")
result = subprocess.run(
    [sys.executable, 'seed_live.py'],
    cwd=str(BASE_DIR),
    capture_output=True, text=True
)
print(f"      {result.stdout.strip()}")

# Step 4: Launch Streamlit dashboard in its own CMD window
print("[4/5] Starting Streamlit iOS Dashboard...")
subprocess.Popen(
    ['cmd', '/k', f'cd /d {BASE_DIR} && streamlit run app.py'],
    creationflags=subprocess.CREATE_NEW_CONSOLE
)

# Step 5: Launch crawler in its own CMD window
print("[5/5] Starting Lead Generation Crawler...")
subprocess.Popen(
    ['cmd', '/k', f'cd /d {BASE_DIR} && python crawler.py'],
    creationflags=subprocess.CREATE_NEW_CONSOLE
)

print()
print("=" * 60)
print("  ALL SERVICES LAUNCHED SUCCESSFULLY!")
print("=" * 60)
print()
dash_url_file = BASE_DIR / "dashboard_url.txt"
short_dash = dash_url_file.read_text().strip() if dash_url_file.exists() else tunnel_url

print(f"  Local Dashboard:   http://localhost:8501")
print(f"  Public Dashboard:  {short_dash}")
print(f"  Full Cloud Tunnel: {tunnel_url}")
print()
print("  All pitches now use shortened links (e.g. https://is.gd/...)")
print()
print("  You can close this window now.")
print("  The 3 service windows will keep running.")
print("=" * 60)

# Keep window open so user can see the output
input("\nPress Enter to close this launcher window...")
