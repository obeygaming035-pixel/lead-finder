import os
import re
import sys
import time
import requests
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

def shorten_url(long_url):
    """Shorten URL via free is.gd API"""
    try:
        r = requests.get(f'https://is.gd/create.php?format=simple&url={long_url}', timeout=6)
        if r.status_code == 200 and r.text.startswith('http'):
            return r.text.strip()
    except Exception:
        pass
    return long_url

print("========================================================")
print("  Starting Live Public Web Dashboard & Pitch Tunnel     ")
print("========================================================")

# Start static mockup HTTP server in background
subprocess.Popen([sys.executable, str(BASE_DIR / "serve_mockups.py")])
time.sleep(1)

# Start Cloudflare Tunnel for direct static HTML file server on port 8000
cmd = ["npx.cmd" if sys.platform == "win32" else "npx", "-y", "cloudflared", "tunnel", "--url", "http://localhost:8000"]

try:
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        encoding="utf-8",
        errors="replace"
    )

    url_captured = False

    for line in proc.stdout:
        print(line, end="")
        sys.stdout.flush()

        if not url_captured:
            match = re.search(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com', line)
            if match:
                raw_tunnel_url = match.group(0)
                short_dashboard_url = shorten_url(raw_tunnel_url)
                
                with open(BASE_DIR / "tunnel_url.txt", "w", encoding="utf-8") as f:
                    f.write(raw_tunnel_url)

                with open(BASE_DIR / "dashboard_url.txt", "w", encoding="utf-8") as f:
                    f.write(short_dashboard_url)

                print("\n" + "="*65)
                print(f"  [+] LIVE PUBLIC DASHBOARD ONLINE:")
                print(f"      Full URL:      {raw_tunnel_url}")
                print(f"      Shortened URL: {short_dashboard_url}")
                print("="*65 + "\n")
                url_captured = True

    proc.wait()
except KeyboardInterrupt:
    print("\nStopping services...")
