@echo off
echo Initializing environment setup...
python -m pip install --upgrade pip
pip install playwright streamlit requests beautifulsoup4 python-dotenv
playwright install chromium
echo Environment setup complete.
