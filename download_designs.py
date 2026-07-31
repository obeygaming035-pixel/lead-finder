"""
Downloads all 74 DESIGN.md files from getdesign.md (VoltAgent/awesome-design-md) repository
and stores them in design_systems/
"""
import urllib.request
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DESIGN_DIR = BASE_DIR / "design_systems"
DESIGN_DIR.mkdir(exist_ok=True)

print("=" * 60)
print("  Downloading DESIGN.md Collection from getdesign.md")
print("=" * 60)

url = "https://api.github.com/repos/VoltAgent/awesome-design-md/contents/design-md"
req = urllib.request.Request(url, headers={"User-Agent": "Antigravity-Agent"})

try:
    with urllib.request.urlopen(req) as res:
        items = json.loads(res.read().decode('utf-8'))

    count = 0
    for item in items:
        name = item["name"]
        raw_url = f"https://raw.githubusercontent.com/VoltAgent/awesome-design-md/main/design-md/{name}/DESIGN.md"
        try:
            with urllib.request.urlopen(raw_url) as raw_res:
                content = raw_res.read().decode('utf-8', errors='ignore')
                out_path = DESIGN_DIR / f"{name}.md"
                out_path.write_text(content, encoding="utf-8")
                count += 1
                print(f"  [{count}/{len(items)}] Downloaded: {name}.md ({len(content)} bytes)")
        except Exception as e:
            print(f"  [!] Failed to download {name}: {e}")

    print("=" * 60)
    print(f"  SUCCESS! Downloaded {count} DESIGN.md files into {DESIGN_DIR}")
    print("=" * 60)

except Exception as e:
    print(f"[ERROR] API fetch failed: {e}")
