const fs = require('fs');
const path = require('path');

const srcDir = 'C:/Users/Death/.gemini/antigravity/scratch/the-cake-stop';
const targetFile = 'C:/Users/Death/.gemini/antigravity/scratch/b2b_lead_gen/mockups/thecakestop.html';

let html = fs.readFileSync(path.join(srcDir, 'index.html'), 'utf8');
const css = fs.readFileSync(path.join(srcDir, 'style.css'), 'utf8');
const js = fs.readFileSync(path.join(srcDir, 'script.js'), 'utf8');

html = html.replace('<link rel="stylesheet" href="style.css">', `<style>\n${css}\n</style>`);
html = html.replace('<script src="script.js"></script>', `<script>\n${js}\n</script>`);

fs.writeFileSync(targetFile, html, 'utf8');
console.log('✅ Combined thecakestop.html created successfully!');
