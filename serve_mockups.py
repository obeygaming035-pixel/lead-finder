import http.server
import socketserver
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
MOCKUPS_DIR = BASE_DIR / "mockups"
MOCKUPS_DIR.mkdir(exist_ok=True)

os.chdir(MOCKUPS_DIR)

class NoCacheHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

PORT = 8000
print(f"[+] Lightning-Fast Static Web Server running on port {PORT} serving {MOCKUPS_DIR}...")
try:
    with socketserver.TCPServer(("", PORT), NoCacheHTTPRequestHandler) as httpd:
        httpd.serve_forever()
except KeyboardInterrupt:
    print("Server stopped.")
