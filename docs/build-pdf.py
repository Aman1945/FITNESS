#!/usr/bin/env python3
"""
Render the project docs to PDF.

The markdown files stay the source of truth -- the PDFs are generated from them,
so there is no second copy of the content to drift out of date.

    python3 docs/build-pdf.py

Requires: `pip3 install markdown` and Google Chrome (used headless to print).
"""
import html
import re
import subprocess
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / 'docs'
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

# doc source -> (output name, cover title, cover subtitle)
JOBS = [
    (
        '04-features-and-functionality.md',
        'GoalFlow-Features-and-Functionality.pdf',
        'Features &amp; Functionality',
        'What the product does, and why each part exists',
    ),
    (
        '03-tech-doc.md',
        'GoalFlow-Technical-Architecture.pdf',
        'Technical Architecture',
        'How the system is built and what every piece is used for',
    ),
]

CSS = """
@page { size: A4; margin: 18mm 16mm 20mm; }

*  { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Roboto, sans-serif;
  font-size: 10.2pt;
  line-height: 1.62;
  color: #1D1D2B;
  margin: 0;
}

/* ---------- cover ---------- */
.cover { page-break-after: always; padding-top: 52mm; }
.cover .mark { width: 74px; height: 74px; margin-bottom: 26px; }
.cover h1 {
  font-size: 33pt; line-height: 1.1; letter-spacing: -1.1px;
  margin: 0 0 10px; color: #16162B; border: 0; padding: 0;
}
.cover .sub { font-size: 12.5pt; color: #62627A; margin: 0 0 40px; max-width: 118mm; }
.cover .meta { border-top: 2px solid #EDEDF2; padding-top: 16px; font-size: 9.4pt; color: #7A7A90; }
.cover .meta b { color: #16162B; font-weight: 600; }
.cover .meta div { margin-bottom: 5px; }

/* ---------- headings ---------- */
h1 {
  font-size: 19pt; letter-spacing: -0.5px; color: #16162B;
  margin: 0 0 16px; padding-bottom: 9px; border-bottom: 2.5px solid #5B5BD6;
  page-break-after: avoid;
}
h2 {
  font-size: 14pt; letter-spacing: -0.3px; color: #16162B;
  margin: 26px 0 10px; padding-top: 4px;
  page-break-after: avoid; page-break-before: auto;
}
h3 { font-size: 11.4pt; color: #33334A; margin: 18px 0 7px; page-break-after: avoid; }
h2 + p, h3 + p { margin-top: 0; }

p { margin: 0 0 10px; }
strong { color: #16162B; font-weight: 600; }
em { color: #4A4A63; }

ul, ol { margin: 0 0 12px; padding-left: 19px; }
li { margin-bottom: 4px; }

hr { border: 0; border-top: 1px solid #EDEDF2; margin: 22px 0; }

a { color: #5B5BD6; text-decoration: none; }

/* ---------- code ---------- */
code {
  font-family: "SF Mono", ui-monospace, Menlo, Consolas, monospace;
  font-size: 8.9pt; background: #F3F3F8; color: #3C3C5C;
  padding: 1.5px 5px; border-radius: 4px;
}
pre {
  background: #F7F7FB; border: 1px solid #E7E7F0; border-left: 3px solid #5B5BD6;
  border-radius: 7px; padding: 12px 14px; margin: 0 0 14px;
  overflow: hidden; page-break-inside: avoid;
}
pre code {
  background: none; padding: 0; font-size: 8.4pt; line-height: 1.5;
  color: #34344E; white-space: pre-wrap; word-break: break-word;
}

/* ---------- tables ---------- */
table {
  width: 100%; border-collapse: collapse; margin: 0 0 16px;
  font-size: 9.2pt; page-break-inside: avoid;
}
th {
  background: #F3F3FA; color: #16162B; font-weight: 600; text-align: left;
  padding: 8px 10px; border-bottom: 1.5px solid #D8D8E8;
}
td { padding: 7px 10px; border-bottom: 1px solid #EDEDF2; vertical-align: top; }
tr:nth-child(even) td { background: #FBFBFD; }
td code, th code { font-size: 8.4pt; }

blockquote {
  margin: 0 0 14px; padding: 9px 15px;
  background: #F5F5FC; border-left: 3px solid #8B8BF0;
  color: #4A4A63; border-radius: 0 6px 6px 0;
}
blockquote p:last-child { margin-bottom: 0; }
"""

MARK_SVG = """
<svg class="mark" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#6C6CE8"/><stop offset="1" stop-color="#8B5CF6"/>
  </linearGradient></defs>
  <rect width="100" height="100" rx="27" fill="url(#g)"/>
  <circle cx="50" cy="50" r="26" fill="none" stroke="#fff" stroke-opacity=".28" stroke-width="7"/>
  <path d="M 50 24 A 26 26 0 1 1 27 62" fill="none" stroke="#fff"
        stroke-width="7" stroke-linecap="round"/>
  <path d="M 38 51 L 46 60 L 63 40" fill="none" stroke="#fff"
        stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""


def build(md_name: str, out_name: str, title: str, subtitle: str) -> Path:
    src = DOCS / md_name
    if not src.exists():
        sys.exit(f'missing source: {src}')

    text = src.read_text()

    # The markdown files open with their own H1 + intro; the cover replaces it.
    text = re.sub(r'\A#\s.*?\n', '', text, count=1)

    body = markdown.markdown(
        text,
        extensions=['tables', 'fenced_code', 'sane_lists', 'attr_list'],
    )

    cover = f"""
    <div class="cover">
      {MARK_SVG}
      <h1>GoalFlow<br>{title}</h1>
      <p class="sub">{subtitle}</p>
      <div class="meta">
        <div><b>Stack</b> &nbsp; Flutter · Node.js + TypeScript + Express · MongoDB Atlas
             · FCM · Email</div>
        <div><b>Demo login</b> &nbsp; demo@goalflow.app / Demo1234</div>
      </div>
    </div>
    """

    doc = (
        '<!doctype html><html><head><meta charset="utf-8">'
        f'<title>{html.escape(out_name)}</title><style>{CSS}</style></head>'
        f'<body>{cover}{body}</body></html>'
    )

    tmp = DOCS / f'.{out_name}.html'
    tmp.write_text(doc)

    out = DOCS / out_name
    subprocess.run(
        [CHROME, '--headless', '--disable-gpu', '--no-pdf-header-footer',
         f'--print-to-pdf={out}', tmp.as_uri()],
        check=True, capture_output=True,
    )
    tmp.unlink()
    return out


if __name__ == '__main__':
    for md, out, title, sub in JOBS:
        p = build(md, out, title, sub)
        print(f'  {p.name}  ({p.stat().st_size // 1024} KB)')
