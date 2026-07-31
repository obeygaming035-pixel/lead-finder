import requests

def test_catbox():
    html_content = """<!DOCTYPE html>
<html>
<head><title>Live Public Website</title></head>
<body style="background:#0b0e14; color:#fff; font-family:sans-serif; text-align:center; padding:50px;">
    <h1 style="color:#f59e0b;">🟢 Live Public Website Working!</h1>
    <p>This is a 100% live, publicly accessible website hosted on the web.</p>
</body>
</html>"""
    
    files = {
        'fileToUpload': ('website.html', html_content, 'text/html'),
        'reqtype': (None, 'fileupload')
    }
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    
    r = requests.post('https://catbox.moe/user/api.php', files=files, headers=headers, timeout=10)
    print("Catbox Upload Status:", r.status_code)
    url = r.text.strip()
    print("Catbox Public URL:", url)
    return url

if __name__ == "__main__":
    test_catbox()
