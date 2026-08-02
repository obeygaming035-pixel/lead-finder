import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from local .env
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

GLM_API_KEY = os.getenv("GLM_API_KEY", "your_glm_api_key_here")

# Database & Storage
DB_PATH = BASE_DIR / "leads.db"
MOCKUPS_DIR = BASE_DIR / "mockups"
MOCKUPS_DIR.mkdir(exist_ok=True)

def get_preview_url():
    tunnel_file = BASE_DIR / "tunnel_url.txt"
    if tunnel_file.exists():
        try:
            url = tunnel_file.read_text().strip()
            if url.startswith("http"):
                return url
        except Exception:
            pass
    return os.getenv("BASE_PREVIEW_URL", "http://localhost:8501")

BASE_PREVIEW_URL = get_preview_url()

# Target Markets
TARGET_CITIES = [
    "Mumbai", "Pune", "Nagpur", "Nashik",
    "Bengaluru", "Mysuru", "Mangaluru",
    "Delhi", "Gurugram", "Noida", "Ghaziabad",
    "Ahmedabad", "Surat", "Vadodara",
    "Jaipur", "Udaipur", "Jodhpur",
    "Chandigarh", "Mohali", "Ludhiana", "Amritsar",
    "Hyderabad",
    "Lucknow", "Kanpur", "Agra", "Varanasi",
    "Panaji", "Calangute", "Candolim", "Margao",
    "Chennai", "Coimbatore", "Madurai"
]

TARGET_NICHES = [
    "salons & hair studios",
    "beauty / makeup studios",
    "wedding photographers",
    "wedding planners & decorators",
    "interior designers",
    "cafes",
    "restaurants",
    "boutique hotels / guesthouses",
    "travel agencies",
    "event management companies",
    "party/event decorators",
    "cake shops / custom bakeries",
    "florists / wedding floral businesses",
    "boutiques / designer clothing stores",
    "jewellery boutiques",
    "furniture & home-decor stores"
]


