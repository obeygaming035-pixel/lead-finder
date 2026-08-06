const fs = require('fs');
const path = require('path');

async function deploy() {
    const token = process.env.GITHUB_TOKEN || process.argv[2];
    const repoName = process.argv[3] || 'the-cake-stop-mumbai';

    if (!token) {
        console.error('Error: Please provide a GitHub Personal Access Token.');
        console.log('Usage: node deploy-github.js <YOUR_GITHUB_TOKEN> [REPO_NAME]');
        process.exit(1);
    }

    const headers = {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Node-Deploy-Script'
    };

    try {
        // 1. Get User Info
        console.log('🔍 Authenticating with GitHub...');
        const userRes = await fetch('https://api.github.com/user', { headers });
        if (!userRes.ok) throw new Error(`Auth failed: ${userRes.statusText}`);
        const userData = await userRes.json();
        const username = userData.login;
        console.log(`✅ Authenticated as GitHub user: ${username}`);

        // 2. Create Repository if it doesn't exist
        console.log(`📁 Creating repository "${repoName}"...`);
        const createRepoRes = await fetch('https://api.github.com/user/repos', {
            method: 'POST',
            headers,
            body: JSON.stringify({
                name: repoName,
                description: 'The Cake Stop - Premium Bakery Website (Vile Parle East, Mumbai)',
                homepage: `https://${username}.github.io/${repoName}/`,
                auto_init: true
            })
        });

        if (createRepoRes.status === 422) {
            console.log(`ℹ️ Repository "${repoName}" already exists. Proceeding with update...`);
        } else if (!createRepoRes.ok) {
            const err = await createRepoRes.json();
            throw new Error(`Repo creation failed: ${err.message}`);
        } else {
            console.log(`✅ Repository created successfully!`);
        }

        // Helper to get file SHA if exists
        async function getSha(filePath) {
            const res = await fetch(`https://api.github.com/repos/${username}/${repoName}/contents/${filePath}`, { headers });
            if (res.ok) {
                const data = await res.json();
                return data.sha;
            }
            return null;
        }

        // 3. Upload Files
        const files = ['index.html', 'style.css', 'script.js'];
        for (const file of files) {
            console.log(`⬆️ Uploading ${file}...`);
            const content = fs.readFileSync(path.join(__dirname, file), 'utf8');
            const base64Content = Buffer.from(content).toString('base64');
            const sha = await getSha(file);

            const payload = {
                message: `Update ${file} for The Cake Stop`,
                content: base64Content,
                branch: 'main'
            };
            if (sha) payload.sha = sha;

            const uploadRes = await fetch(`https://api.github.com/repos/${username}/${repoName}/contents/${file}`, {
                method: 'PUT',
                headers,
                body: JSON.stringify(payload)
            });

            if (!uploadRes.ok) {
                const err = await uploadRes.json();
                console.error(`❌ Failed to upload ${file}: ${err.message}`);
            } else {
                console.log(`  └─ ${file} uploaded.`);
            }
        }

        // 4. Enable GitHub Pages
        console.log('🌐 Enabling GitHub Pages...');
        const pagesRes = await fetch(`https://api.github.com/repos/${username}/${repoName}/pages`, {
            method: 'POST',
            headers: {
                ...headers,
                'Accept': 'application/vnd.github.mysterio-preview+json'
            },
            body: JSON.stringify({
                source: { branch: 'main', path: '/' }
            })
        });

        if (pagesRes.ok || pagesRes.status === 409) {
            console.log(`\n🎉 SUCCESS! Website is deploying to GitHub Pages.`);
            console.log(`\n📍 Live URL: https://${username}.github.io/${repoName}/`);
            console.log(`📍 Repo URL: https://github.com/${username}/${repoName}\n`);
        } else {
            const pagesErr = await pagesRes.json();
            console.log(`ℹ️ GitHub Pages notice: ${pagesErr.message || 'Pages may already be enabled or building.'}`);
            console.log(`\n📍 Expected Live URL: https://${username}.github.io/${repoName}/`);
        }

    } catch (err) {
        console.error('❌ Deployment error:', err.message);
    }
}

deploy();
