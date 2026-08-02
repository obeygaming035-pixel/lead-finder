import sqlite3
import pandas as pd
import streamlit as st
import streamlit.components.v1 as components
from pathlib import Path
from config import BASE_DIR, DB_PATH, MOCKUPS_DIR, TARGET_CITIES, TARGET_NICHES

import json

SETTINGS_FILE = BASE_DIR / "crawler_settings.json"

def load_settings():
    default_settings = {
        "whatsapp_enabled": False,  # Turned off by default as requested
        "min_delay": 90,
        "max_delay": 180,
        "max_results": 100
    }
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                return {**default_settings, **json.load(f)}
        except Exception:
            pass
    return default_settings

def save_settings(settings):
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)

st.set_page_config(
    page_title="Lead Engine - iOS Dashboard",
    page_icon="🍎",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom iOS Aesthetic CSS Injection
st.markdown("""
<style>
    /* iOS San Francisco / Inter Font & Core Variables */
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
    
    html, body, [class*="css"] {
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Inter", sans-serif;
    }
    
    .stApp {
        background-color: #0b0e14;
    }

    /* iOS Glassmorphism Card Widget */
    .ios-card {
        background: rgba(23, 31, 48, 0.7);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 20px;
        padding: 1.5rem;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
        margin-bottom: 1.2rem;
    }

    /* iOS Control Center Metric Tile */
    .ios-metric {
        background: rgba(30, 41, 64, 0.6);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 18px;
        padding: 1.2rem;
        text-align: center;
        transition: transform 0.2s ease, border-color 0.2s ease;
    }
    .ios-metric:hover {
        transform: translateY(-3px);
        border-color: #007aff;
    }
    .ios-metric-val {
        font-size: 2.2rem;
        font-weight: 800;
        letter-spacing: -0.5px;
        color: #ffffff;
    }
    .ios-metric-lbl {
        font-size: 0.82rem;
        font-weight: 600;
        color: #94a3b8;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        margin-top: 0.3rem;
    }

    /* iOS Badges */
    .ios-badge-avail {
        background: rgba(52, 199, 89, 0.15);
        color: #30d158;
        border: 1px solid rgba(52, 199, 89, 0.3);
        padding: 0.35rem 0.9rem;
        border-radius: 20px;
        font-weight: 700;
        font-size: 0.82rem;
        display: inline-block;
    }
    .ios-badge-taken {
        background: rgba(255, 69, 58, 0.15);
        color: #ff453a;
        border: 1px solid rgba(255, 69, 58, 0.3);
        padding: 0.35rem 0.9rem;
        border-radius: 20px;
        font-weight: 700;
        font-size: 0.82rem;
        display: inline-block;
    }
    .ios-badge-status {
        background: rgba(10, 132, 255, 0.15);
        color: #0a84ff;
        border: 1px solid rgba(10, 132, 255, 0.3);
        padding: 0.35rem 0.9rem;
        border-radius: 20px;
        font-weight: 600;
        font-size: 0.82rem;
        display: inline-block;
    }

    /* Outreach Copy Box */
    .ios-copy-box {
        background: #0f172a;
        border: 1px solid #1e293b;
        border-radius: 14px;
        padding: 1.2rem;
        font-family: inherit;
        color: #e2e8f0;
        font-size: 0.92rem;
        line-height: 1.6;
        margin-top: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Standalone Lead Mockup Direct URL Route (e.g. http://localhost:8501/?lead_id=1)
if "lead_id" in st.query_params:
    query_lead_id = st.query_params.get("lead_id")
    mockup_path = MOCKUPS_DIR / f"lead_{query_lead_id}.html"
    if mockup_path.exists():
        with open(mockup_path, "r", encoding="utf-8") as f:
            html_content = f.read()
        components.html(html_content, height=1000, scrolling=True)
        st.stop()

def load_leads():
    if not DB_PATH.exists():
        return pd.DataFrame()
    conn = sqlite3.connect(DB_PATH)
    try:
        df = pd.read_sql_query("SELECT * FROM leads ORDER BY id DESC", conn)
    except Exception:
        df = pd.DataFrame()
    conn.close()
    return df

def update_lead_status(lead_id, new_status):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("UPDATE leads SET status = ? WHERE id = ?", (new_status, lead_id))
    conn.commit()
    conn.close()

def delete_lead(lead_id):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM leads WHERE id = ?", (lead_id,))
    conn.commit()
    conn.close()
    # Also delete mockup file
    mockup_file = MOCKUPS_DIR / f"lead_{lead_id}.html"
    if mockup_file.exists():
        mockup_file.unlink()

def clear_all_leads():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM leads")
    conn.commit()
    conn.close()
    # Clear all mockup files
    import shutil
    if MOCKUPS_DIR.exists():
        shutil.rmtree(MOCKUPS_DIR)
        MOCKUPS_DIR.mkdir(exist_ok=True)

# HEADER BAR & PUBLIC DASHBOARD LINK
dash_url_file = BASE_DIR / "dashboard_url.txt"
short_dash_url = dash_url_file.read_text().strip() if dash_url_file.exists() else None

dash_badge_html = f'''
    <div style="background: rgba(48, 209, 88, 0.15); border: 1px solid rgba(48, 209, 88, 0.4); padding: 0.6rem 1.2rem; border-radius: 30px; text-align: right;">
        <span style="color: #30d158; font-weight: 700; font-size: 0.85rem;">🌐 Live Public Dashboard:</span><br>
        <a href="{short_dash_url}" target="_blank" style="color: #ffffff; font-weight: 800; font-size: 1rem; text-decoration: underline;">{short_dash_url}</a>
    </div>
''' if short_dash_url else ''

st.markdown(f"""
<div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
    <div>
        <h1 style="font-size: 2.2rem; font-weight: 800; color: #fff; margin: 0;">🍎 B2B Lead Hub</h1>
        <p style="color: #94a3b8; margin: 0; font-size: 0.95rem;">iOS Clean Lead Generation & Outreach Portal</p>
    </div>
    {dash_badge_html}
</div>
""", unsafe_allow_html=True)

@st.fragment(run_every=5)
def render_live_dashboard():
    df = load_leads()
    
    # METRICS CONTROL CENTER
    col1, col2, col3, col4 = st.columns(4)
    total_leads = len(df) if not df.empty else 0
    available_domains = len(df[df['domain_available'] == 1]) if not df.empty else 0
    mockups_count = len([f for f in MOCKUPS_DIR.glob("*.html")]) if MOCKUPS_DIR.exists() else 0
    pending_count = len(df[df['status'] == 'Pending Review']) if not df.empty else 0

    with col1:
        st.markdown(f"""
        <div class="ios-metric">
            <div class="ios-metric-val">{total_leads}</div>
            <div class="ios-metric-lbl">Total Leads Captured</div>
        </div>
        """, unsafe_allow_html=True)

    with col2:
        st.markdown(f"""
        <div class="ios-metric">
            <div class="ios-metric-val" style="color: #30d158;">{available_domains}</div>
            <div class="ios-metric-lbl">Available Domains</div>
        </div>
        """, unsafe_allow_html=True)

    with col3:
        st.markdown(f"""
        <div class="ios-metric">
            <div class="ios-metric-val" style="color: #0a84ff;">{mockups_count}</div>
            <div class="ios-metric-lbl">Animated Mockups</div>
        </div>
        """, unsafe_allow_html=True)

    with col4:
        st.markdown(f"""
        <div class="ios-metric">
            <div class="ios-metric-val" style="color: #ff9f0a;">{pending_count}</div>
            <div class="ios-metric-lbl">Pending Review</div>
        </div>
        """, unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    if df.empty:
        st.markdown("""
        <div class="ios-card" style="text-align: center; padding: 3rem;">
            <h3 style="color: #fff; font-weight: 700;">✨ Clean Slate — Dashboard Reset</h3>
            <p style="color: #94a3b8; max-width: 500px; margin: 0.5rem auto 1.5rem;">The leads database has been wiped clean. Start your crawler worker loop to discover fresh high-intent SMB leads!</p>
            <code style="background: #0f172a; padding: 0.6rem 1.2rem; border-radius: 8px; color: #38bdf8;">python crawler.py</code>
        </div>
        """, unsafe_allow_html=True)

    else:
        tab1, tab2, tab3 = st.tabs(["📱 Leads Register", "⚙️ Quick Controls", "📦 Leads Batches"])

        with tab1:
            # Search & Filters
            search_col, filter_city, filter_status = st.columns([2, 1, 1])
            with search_col:
                search_query = st.text_input("🔍 Search Business or Owner", "")
            with filter_city:
                selected_city = st.selectbox("Filter City", ["All Cities"] + list(df['city'].unique()))
            with filter_status:
                selected_status = st.selectbox("Filter Status", ["All Statuses"] + list(df['status'].unique()))

            filtered_df = df.copy()
            if search_query:
                filtered_df = filtered_df[filtered_df['business_name'].str.contains(search_query, case=False, na=False) | filtered_df['owner_name'].str.contains(search_query, case=False, na=False)]
            if selected_city != "All Cities":
                filtered_df = filtered_df[filtered_df['city'] == selected_city]
            if selected_status != "All Statuses":
                filtered_df = filtered_df[filtered_df['status'] == selected_status]

            st.markdown("### 📋 Clean Lead Records")
            
            display_df = filtered_df[['id', 'business_name', 'owner_name', 'city', 'industry', 'proposed_domain', 'domain_available', 'phone', 'status']].copy()
            display_df['domain_available'] = display_df['domain_available'].apply(lambda x: "🟢 AVAILABLE" if x == 1 else "🔴 TAKEN")
            st.dataframe(display_df, use_container_width=True, height=220)

            st.markdown("---")
            
            # Lead Inspector Panel
            lead_options = filtered_df.apply(lambda row: f"#{row['id']} - {row['business_name']} ({row['owner_name']})", axis=1).tolist() if not filtered_df.empty else []
            
            if lead_options:
                selected_lead_str = st.selectbox("Select Lead to Inspect:", lead_options)
                selected_id = int(selected_lead_str.split(" - ")[0].replace("#", ""))
                lead = filtered_df[filtered_df['id'] == selected_id].iloc[0]

                left_panel, right_panel = st.columns([1, 1])

                with left_panel:
                    st.markdown(f"### 👤 {lead['business_name']}")
                    
                    domain_status_html = '<span class="ios-badge-avail">🟢 DOMAIN AVAILABLE</span>' if lead['domain_available'] == 1 else '<span class="ios-badge-taken">🔴 DOMAIN TAKEN</span>'
                    st.markdown(f"**Proposed Domain:** `{lead['proposed_domain']}` &nbsp; {domain_status_html}", unsafe_allow_html=True)
                    
                    st.markdown(f"""
                    <div style="margin-top: 1rem; line-height: 1.8;">
                        <strong>Owner / Decision Maker:</strong> {lead['owner_name']}<br>
                        <strong>Industry:</strong> {lead['industry'].title()}<br>
                        <strong>City:</strong> {lead['city']}<br>
                        <strong>Phone / WhatsApp:</strong> <code>{lead['phone']}</code><br>
                        <strong>Email:</strong> <code>{lead['email']}</code>
                    </div>
                    """, unsafe_allow_html=True)

                    # Status Updater
                    st.markdown("<br>", unsafe_allow_html=True)
                    status_list = ["Pending Review", "Contacted", "Interested", "Not Interested"]
                    curr_idx = status_list.index(lead['status']) if lead['status'] in status_list else 0
                    new_st = st.selectbox("Update Lead Status:", status_list, index=curr_idx)
                    
                    if st.button("Save iOS Status Update"):
                        update_lead_status(selected_id, new_st)
                        st.success(f"Status for Lead #{selected_id} updated to '{new_st}'")
                        st.rerun()

                    # WhatsApp Automation Integration
                    import whatsapp_automation
                    wa_link = whatsapp_automation.generate_wa_link(lead['phone'], lead['initial_pitch']) if pd.notna(lead['initial_pitch']) else "#"
                    
                    st.markdown(f"""
                    <div style="margin-top: 1rem; margin-bottom: 1.5rem;">
                        <a href="{wa_link}" target="_blank" style="background: #25d366; color: #ffffff; padding: 0.75rem 1.4rem; border-radius: 30px; text-decoration: none; font-weight: 800; font-size: 0.92rem; display: inline-flex; align-items: center; gap: 0.5rem; box-shadow: 0 4px 15px rgba(37,211,102,0.3);">
                            💬 Launch Pre-Filled WhatsApp Pitch to {lead['phone']} &rarr;
                        </a>
                    </div>
                    """, unsafe_allow_html=True)

                    st.markdown("#### 💬 Outreach Pitch Messages")
                    st.write("**Initial WhatsApp / Email Pitch:**")
                    st.code(lead['initial_pitch'] if pd.notna(lead['initial_pitch']) else "Generating pitch...", language="text")

                    st.write("**48-Hour Follow-Up Pitch:**")
                    st.code(lead['followup_pitch'] if pd.notna(lead['followup_pitch']) else "Generating pitch...", language="text")

                with right_panel:
                    st.markdown("### 🌐 Live HTML Website Mockup")
                    mockup_file = MOCKUPS_DIR / f"lead_{selected_id}.html"
                    
                    if mockup_file.exists():
                        with open(mockup_file, "r", encoding="utf-8") as f:
                            html_code = f.read()
                        components.html(html_code, height=650, scrolling=True)
                    else:
                        st.warning("Mockup file is currently generating...")

        with tab2:
            st.markdown("### Quick Controls & Configuration")
            st.write(f"**Database Location:** `{DB_PATH}`")
            st.write(f"**Mockups Storage:** `{MOCKUPS_DIR}`")
            st.write(f"**Target Cities:** `{', '.join(TARGET_CITIES)}`")
            st.write(f"**Target Niches:** `{', '.join(TARGET_NICHES)}`")

            st.markdown("---")
            st.markdown("### ⚙️ Crawler & Auto-Outreach Settings")
            
            # Load and show current settings
            curr_settings = load_settings()
            
            auto_wa = st.toggle(
                "Enable Automatic WhatsApp Outreach Dispatcher", 
                value=curr_settings["whatsapp_enabled"],
                help="If enabled, newly harvested leads will automatically be messaged immediately by the crawler process."
            )
            
            col_set1, col_set2, col_set3 = st.columns(3)
            with col_set1:
                max_res = st.number_input(
                    "Max Maps Search Results to Parse", 
                    min_value=5, max_value=500, 
                    value=curr_settings["max_results"],
                    help="Increases the limit of results targeted per Google Maps search query."
                )
            with col_set2:
                min_del = st.number_input(
                    "Min Cooldown between messages (s)", 
                    min_value=5, max_value=600, 
                    value=curr_settings["min_delay"],
                    help="Min randomized sleep duration between auto-outreach messages."
                )
            with col_set3:
                max_del = st.number_input(
                    "Max Cooldown between messages (s)", 
                    min_value=5, max_value=600, 
                    value=curr_settings["max_delay"],
                    help="Max randomized sleep duration between auto-outreach messages."
                )
                
            if st.button("Apply and Save Settings", type="secondary"):
                save_settings({
                    "whatsapp_enabled": auto_wa,
                    "max_results": int(max_res),
                    "min_delay": int(min_del),
                    "max_delay": int(max_del)
                })
                st.success("Crawler settings saved! Changes are picked up dynamically by the crawler loop.")
                st.rerun()

            st.markdown("---")
            st.markdown("### 🚀 Meta-Compliant WhatsApp Campaign Engine")
            st.info("ℹ️ **WhatsApp Safety Mode Enabled**: Messages are sent with a randomized cooldown of 1.5 to 4 minutes and human-like typing simulation to comply with Meta rules and prevent account bans.")
            
            import whatsapp_automation
            sent_today = whatsapp_automation.get_sent_count_last_24h()
            is_bh = whatsapp_automation.is_within_business_hours()
            bh_status = "🟢 Within Business Hours (9:00 AM - 6:30 PM)" if is_bh else "❌ Outside Business Hours (Will auto-sleep overnight)"
            
            st.write(f"**Campaign Status:** {bh_status}")
            st.metric(
                label="WhatsApp Outreach (Last 24h)",
                value=f"{sent_today} / 50",
                delta=f"{50 - sent_today} Remaining",
                help="Meta-compliant warming limit. Max 50 dispatches per day to avoid spam triggers."
            )
            
            if st.button("Run Safe WhatsApp Outreach Campaign (All Pending Leads)", type="primary"):
                with st.spinner("Dispatching automated WhatsApp messages with human-like delays..."):
                    sent = whatsapp_automation.run_whatsapp_bulk_campaign()
                    st.success(f"Campaign Complete! Successfully dispatched WhatsApp outreach to {sent} leads.")
                    st.rerun()

            st.markdown("---")
            st.markdown("### Lead Management")

            # Delete individual lead
            if not df.empty:
                del_options = df.apply(lambda row: f"#{row['id']} - {row['business_name']}", axis=1).tolist()
                selected_del = st.selectbox("Select Lead to Delete:", del_options, key="del_lead")
                if st.button("Delete Selected Lead", type="secondary"):
                    del_id = int(selected_del.split(" - ")[0].replace("#", ""))
                    delete_lead(del_id)
                    st.success(f"Lead {selected_del} deleted successfully!")
                    st.rerun()

            # Clear all leads
            st.markdown("---")
            st.markdown("### Danger Zone")
            if st.button("Clear ALL Leads & Reset Dashboard", type="primary"):
                clear_all_leads()
                st.success("All leads cleared! Dashboard reset to 0 leads.")
                st.rerun()

        with tab3:
            st.markdown("### 📦 Leads Copyable Batches (Groups of 50)")
            st.markdown("Easily copy leads in bulk formatted strictly with **Phone Number**, **Business Name**, and **Location (City)**.")
            
            if not df.empty:
                # Divide leads into batches of 50
                batch_size = 50
                total_leads = len(df)
                num_batches = (total_leads + batch_size - 1) // batch_size
                
                batch_options = [f"Batch {i+1} (Leads {i*batch_size + 1} - {min((i+1)*batch_size, total_leads)})" for i in range(num_batches)]
                selected_batch_idx = st.selectbox("Select Batch to Copy:", range(num_batches), format_func=lambda x: batch_options[x])
                
                # Get leads in the selected batch
                start_idx = selected_batch_idx * batch_size
                end_idx = min(start_idx + batch_size, total_leads)
                batch_df = df.iloc[start_idx:end_idx]
                
                # Format leads
                formatted_leads = []
                for _, row in batch_df.iterrows():
                    phone_clean = str(row['phone']).strip()
                    biz_name_clean = str(row['business_name']).split(' (')[0].strip() # strip city from name
                    city_clean = str(row['city']).strip()
                    formatted_leads.append(f"{phone_clean} | {biz_name_clean} | {city_clean}")
                
                batch_text = "\n".join(formatted_leads)
                
                # Display text area
                st.text_area(
                    label=f"Copyable Leads - {batch_options[selected_batch_idx]}",
                    value=batch_text,
                    height=350,
                    help="Click the copy button in the top-right corner of the text box to copy the entire batch to your clipboard."
                )
            else:
                st.info("No leads available in database yet.")

render_live_dashboard()
