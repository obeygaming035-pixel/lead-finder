import sqlite3
import os
from config import DB_PATH, MOCKUPS_DIR, get_preview_url
import crawler

def seed_live():
    crawler.init_db()
    try:
        conn_init = sqlite3.connect(DB_PATH)
        conn_init.execute("DELETE FROM leads")
        conn_init.execute("UPDATE sqlite_sequence SET seq = 0 WHERE name = 'leads'")
        conn_init.commit()
        conn_init.close()
    except Exception:
        pass

    leads = [
        {"name": "Studio Atelier Architects", "industry": "architects & interior design studios", "city": "Mumbai", "phone": "+91 98201 55667", "email": "contact@studioatelier.in", "owner": "Architect Aniket Verma (Principal Architect)"},
        {"name": "Royal Crown Weddings & Events", "industry": "wedding & luxury event planners", "city": "Delhi", "phone": "+91 98112 44556", "email": "events@royalcrown.co.in", "owner": "Karan Malhotra (Founder & Event Director)"},
        {"name": "Heritage Teak Woodworks Studio", "industry": "custom furniture & woodwork studios", "city": "Surat", "phone": "+91 98254 77889", "email": "info@heritageteak.in", "owner": "Dharmesh Shah (Founder & Master Craftsman)"},
        {"name": "Precision CNC Machinery & Tools", "industry": "industrial machinery & tool suppliers", "city": "Ahmedabad", "phone": "+91 97122 33445", "email": "sales@precisioncnc.in", "owner": "Rajesh Mehta (Managing Director)"},
        {"name": "Verma & Associates Chartered Accountants", "industry": "chartered accountants & tax advisory firms", "city": "Pune", "phone": "+91 94225 88990", "email": "ca.verma@vermaassociates.in", "owner": "CA Suresh Verma (Senior Partner & FCA)"}
    ]

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    for l in leads:
        biz_name = f"{l['name']} ({l['city']})"
        domain_prefix = crawler.sanitize_domain_prefix(l['name'])
        proposed_domain = f"{domain_prefix}.in"

        cursor.execute('''
            INSERT INTO leads (business_name, industry, city, current_website, proposed_domain, domain_available, email, phone, owner_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (biz_name, l['industry'], l['city'], f"http://{domain_prefix}.co.in", proposed_domain, 1, l['email'], l['phone'], l['owner']))

        lead_id = cursor.lastrowid

        mockup_html = crawler.generate_mockup_html(biz_name, l['industry'], l['city'], l['owner'], phone=l['phone'])
        mockup_filepath = MOCKUPS_DIR / f"lead_{lead_id}.html"
        with open(mockup_filepath, "w", encoding="utf-8") as f:
            f.write(mockup_html)

        pub_url = crawler.get_github_pages_url(lead_id)
        init_pitch, follow_pitch = crawler.create_pitches(lead_id, biz_name, proposed_domain, l['city'], l['owner'], public_url=pub_url)
        cursor.execute('''
            UPDATE leads SET initial_pitch = ?, followup_pitch = ? WHERE id = ?
        ''', (init_pitch, follow_pitch, lead_id))

    crawler.push_mockups_to_github()

    conn.commit()
    conn.close()
    print("Seed with StrictHTMLHandler visual preview links complete!")

if __name__ == "__main__":
    seed_live()
