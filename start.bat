@echo off
title B2B Lead Engine Master Launcher
echo ========================================================
echo   Launching B2B Lead Generation Engine (Indian Market)  
echo ========================================================
echo.
echo [1/3] Starting Streamlit Dashboard Server...
start "Streamlit Dashboard" cmd /k "cd /d %~dp0 && streamlit run app.py"

echo [2/3] Starting Live Cloudflare Public Tunnel...
start "Public Cloudflare Tunnel" cmd /k "cd /d %~dp0 && python run_tunnel.py"

echo [3/3] Starting Lead Generation Crawler Worker...
start "Lead Generation Crawler" cmd /k "cd /d %~dp0 && python crawler.py"

echo.
echo ========================================================
echo  All 3 services have been launched in dedicated windows!
echo  Dashboard: http://localhost:8501
echo ========================================================
