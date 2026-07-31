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
    "Mumbai", "Delhi", "Bangalore", "Ahmedabad",
    "Surat", "Pune", "Chennai", "Hyderabad"
]

TARGET_NICHES = [
    "architects & interior design studios",
    "wedding & luxury event planners",
    "custom furniture & woodwork studios",
    "industrial machinery & tool suppliers",
    "chartered accountants & tax advisory firms",
    "dental clinics & orthodontists",
    "fitness gyms & training centers",
    "beauty salons & wellness spas",
    "law firms & independent lawyers",
    "auto repair garages & car services",
    "boutique hotels & homestays",
    "construction contractors & builders",
    "coaching classes & private tutors",
    "organic food shops & grocery stores",
    "pest control services & fumigation",
    "diagnostic labs & medical clinics",
    "real estate brokers & property agents",
    "commercial printing press & packaging",
    "catering services & food suppliers",
    "dry cleaners & laundry services",
    "pet clinics & veterinary doctors"
]


