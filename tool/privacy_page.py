"""Builds invite_site/privacy.html from docs/privacy.md (the public privacy
policy link for Google Play). Run after editing docs/privacy.md:
    python3 tool/privacy_page.py
"""
import html
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
md = (root / 'docs' / 'privacy.md').read_text(encoding='utf-8')


def inline(t: str) -> str:
    t = html.escape(t, quote=False)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'`(.+?)`', r'<code>\1</code>', t)
    t = re.sub(r'(?<![\w/])_(.+?)_(?!\w)', r'<i>\1</i>', t)
    t = re.sub(r'([\w.+-]+@[\w-]+\.[\w.]+)', r'<a href="mailto:\1">\1</a>', t)
    t = re.sub(r'(https://[^\s<]+)', r'<a href="\1">\1</a>', t)
    return t


out, depth, para = [], 0, []


def close_lists(to=0):
    global depth
    while depth > to:
        out.append('</ul>')
        depth -= 1


def flush_para():
    if para:
        out.append('<p>' + inline(' '.join(para)) + '</p>')
        para.clear()


for line in md.splitlines():
    m = re.match(r'^(\s*)- (.*)$', line)
    if m:
        flush_para()
        level = len(m.group(1)) // 2 + 1
        while depth < level:
            out.append('<ul>')
            depth += 1
        close_lists(level)
        out.append('<li>' + inline(m.group(2)) + '</li>')
        continue
    close_lists()
    if not line.strip():
        flush_para()
    elif line.startswith('# '):
        flush_para()
        out.append('<h1>' + inline(line[2:]) + '</h1>')
    elif line.startswith('## '):
        flush_para()
        out.append('<h2 id="' + ('delete' if 'מחיקה' in line else '') + '">' + inline(line[3:]) + '</h2>')
    elif line.strip() == '---':
        flush_para()
        out.append('<hr>')
    else:
        para.append(line.strip())
flush_para()
close_lists()

page = f'''<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DriveBond — מדיניות פרטיות / Privacy Policy</title>
<link rel="stylesheet" href="style.css">
<style>
main {{ max-width: 720px; line-height: 1.6; }}
h1 {{ text-align: start; }}
h2 {{ margin-top: 28px; }}
ul {{ padding-inline-start: 22px; }}
li {{ margin-bottom: 6px; }}
code {{ background:#EAF2FA; border-radius:6px; padding:0 4px; }}
</style>
</head>
<body>
<main>
<!-- Generated from docs/privacy.md by tool/privacy_page.py — edit that file. -->
{chr(10).join(out)}
</main>
</body>
</html>
'''
(root / 'invite_site' / 'privacy.html').write_text(page, encoding='utf-8')
print('wrote invite_site/privacy.html')
