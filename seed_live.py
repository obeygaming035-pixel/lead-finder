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
        {"name": "Uours Events", "industry": "wedding planners & decorators", "city": "Mumbai", "phone": "+91 72087 00786", "email": "", "owner": "Ravi Malhotra (Creative Director)"},
        {"name": "Shree Mandap Decoration", "industry": "party/event decorators", "city": "Pune", "phone": "+91 83298 95799", "email": "", "owner": "Aniket Joshi (Founder)"},
        {"name": "Morya Wedding and Events Decoration", "industry": "wedding planners & decorators", "city": "Pune", "phone": "+91 70381 04013", "email": "", "owner": "Suresh Mehta (Managing Partner)"},
        {"name": "Glen's Bakehouse", "industry": "cake shops / custom bakeries", "city": "Bengaluru", "phone": "+91 80 4112 4894", "email": "", "owner": "Nikhil Rao (Managing Partner)"},
        {"name": "Cafe Tesu", "industry": "cafes", "city": "Delhi", "phone": "+91 98737 04704", "email": "", "owner": "Amit Sharma (Founder)"}
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
