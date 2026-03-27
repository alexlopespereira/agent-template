#!/usr/bin/env python3
"""Blog server for ETL Salesforce agent heartbeat visualization."""

import os
import re
from datetime import datetime
from pathlib import Path

import markdown
import yaml
from flask import Flask, jsonify, request

BASE_DIR = Path(__file__).parent
ENTRIES_DIR = BASE_DIR / "entries"

app = Flask(__name__)


def parse_entry(filepath: Path) -> dict | None:
    """Parse a markdown blog entry with YAML frontmatter."""
    text = filepath.read_text(encoding="utf-8")
    match = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)", text, re.DOTALL)
    if not match:
        return None
    meta = yaml.safe_load(match.group(1)) or {}
    body_md = match.group(2)
    body_html = markdown.markdown(body_md, extensions=["tables", "fenced_code"])
    return {
        "slug": filepath.stem,
        "title": meta.get("title", filepath.stem),
        "date": str(meta.get("date", "")),
        "tags": meta.get("tags", []),
        "type": meta.get("type", "note"),
        "status": meta.get("status", ""),
        "body_html": body_html,
        "body_md": body_md,
        "meta": meta,
    }


def load_entries() -> list[dict]:
    """Load all entries sorted by date descending."""
    entries = []
    for f in sorted(ENTRIES_DIR.glob("*.md"), reverse=True):
        entry = parse_entry(f)
        if entry:
            entries.append(entry)
    entries.sort(key=lambda e: e["date"], reverse=True)
    return entries


COLORS = {
    "primary": "#2b6cb0",
    "green": "#38a169",
    "yellow": "#ed8936",
    "bg": "#0f172a",
    "card": "#1e293b",
    "text": "#e2e8f0",
    "muted": "#94a3b8",
    "border": "#334155",
}

TYPE_BADGES = {
    "heartbeat": ("&#x1f4a1;", COLORS["primary"]),
    "diagnosis": ("&#x1f50d;", COLORS["yellow"]),
    "implementation": ("&#x2699;&#xfe0f;", COLORS["green"]),
    "investigation": ("&#x1f50e;", COLORS["yellow"]),
    "note": ("&#x1f4dd;", COLORS["muted"]),
}


def render_page(title: str, body: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — ETL Salesforce</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace;
    background: {COLORS['bg']}; color: {COLORS['text']};
    line-height: 1.6; max-width: 900px; margin: 0 auto; padding: 2rem 1rem;
  }}
  a {{ color: {COLORS['primary']}; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  h1 {{ font-size: 1.8rem; margin-bottom: 0.5rem; }}
  h2 {{ font-size: 1.3rem; margin: 1.5rem 0 0.5rem; color: {COLORS['text']}; }}
  h3 {{ font-size: 1.1rem; margin: 1rem 0 0.3rem; }}
  .subtitle {{ color: {COLORS['muted']}; margin-bottom: 2rem; font-size: 0.9rem; }}
  .card {{
    background: {COLORS['card']}; border: 1px solid {COLORS['border']};
    border-radius: 8px; padding: 1.2rem; margin-bottom: 1rem;
    transition: border-color 0.2s;
  }}
  .card:hover {{ border-color: {COLORS['primary']}; }}
  .card-title {{ font-size: 1.1rem; font-weight: 600; margin-bottom: 0.3rem; }}
  .card-meta {{ color: {COLORS['muted']}; font-size: 0.8rem; margin-bottom: 0.5rem; }}
  .badge {{
    display: inline-block; padding: 2px 8px; border-radius: 4px;
    font-size: 0.75rem; font-weight: 600; margin-right: 0.3rem;
  }}
  .tag {{ background: {COLORS['border']}; color: {COLORS['muted']}; }}
  pre {{
    background: {COLORS['bg']}; border: 1px solid {COLORS['border']};
    border-radius: 6px; padding: 1rem; overflow-x: auto;
    font-size: 0.85rem; margin: 0.5rem 0;
  }}
  code {{ font-family: 'JetBrains Mono', 'Fira Code', monospace; font-size: 0.85rem; }}
  p {{ margin: 0.5rem 0; }}
  table {{ border-collapse: collapse; width: 100%; margin: 0.5rem 0; }}
  th, td {{
    border: 1px solid {COLORS['border']}; padding: 0.5rem 0.8rem;
    text-align: left; font-size: 0.85rem;
  }}
  th {{ background: {COLORS['bg']}; font-weight: 600; }}
  ul, ol {{ margin: 0.5rem 0 0.5rem 1.5rem; }}
  .back {{ margin-bottom: 1.5rem; }}
  .status-ok {{ color: {COLORS['green']}; }}
  .status-warn {{ color: {COLORS['yellow']}; }}
  hr {{ border: none; border-top: 1px solid {COLORS['border']}; margin: 1.5rem 0; }}
  .empty {{ text-align: center; padding: 3rem; color: {COLORS['muted']}; }}
</style>
</head>
<body>
{body}
</body>
</html>"""


@app.route("/")
@app.route("/blog/")
def index():
    entries = load_entries()
    if not entries:
        body = """
        <h1>ETL Salesforce — Blog</h1>
        <p class="subtitle">Heartbeat insights, diagnostics, and implementation notes</p>
        <div class="empty">
            <p>Nenhuma entrada ainda.</p>
            <p>Execute o heartbeat para gerar a primeira entrada.</p>
        </div>"""
        return render_page("Blog", body)

    cards = ""
    for e in entries:
        icon, color = TYPE_BADGES.get(e["type"], TYPE_BADGES["note"])
        tags_html = "".join(f'<span class="badge tag">{t}</span>' for t in e["tags"])
        status_class = "status-ok" if e["status"] in ("done", "ok", "completed") else "status-warn"
        status_html = f' <span class="{status_class}">[{e["status"]}]</span>' if e["status"] else ""
        cards += f"""
        <a href="/blog/{e['slug']}" style="text-decoration:none;color:inherit;">
        <div class="card">
            <div class="card-title">{icon} {e['title']}{status_html}</div>
            <div class="card-meta">{e['date']} &middot;
                <span class="badge" style="background:{color};color:#fff;">{e['type']}</span>
                {tags_html}
            </div>
        </div>
        </a>"""

    body = f"""
    <h1>ETL Salesforce — Blog</h1>
    <p class="subtitle">Heartbeat insights, diagnostics, and implementation notes &middot; {len(entries)} entries</p>
    {cards}"""
    return render_page("Blog", body)


@app.route("/blog/<slug>")
def entry(slug):
    filepath = ENTRIES_DIR / f"{slug}.md"
    if not filepath.exists():
        return "Not found", 404
    e = parse_entry(filepath)
    if not e:
        return "Parse error", 500

    icon, color = TYPE_BADGES.get(e["type"], TYPE_BADGES["note"])
    tags_html = "".join(f'<span class="badge tag">{t}</span>' for t in e["tags"])
    body = f"""
    <div class="back"><a href="/blog/">&larr; All entries</a></div>
    <h1>{icon} {e['title']}</h1>
    <div class="card-meta" style="margin-bottom:1.5rem;">
        {e['date']} &middot;
        <span class="badge" style="background:{color};color:#fff;">{e['type']}</span>
        {tags_html}
    </div>
    <div>{e['body_html']}</div>"""
    return render_page(e["title"], body)


@app.route("/api/entries")
def api_entries():
    entries = load_entries()
    for e in entries:
        del e["body_html"]
    return jsonify(entries)


@app.route("/api/chat", methods=["GET", "POST"])
def api_chat():
    if request.method == "GET":
        return jsonify({"messages": [], "status": "ok"})
    data = request.get_json(silent=True) or {}
    return jsonify({"received": data, "status": "ok"})


if __name__ == "__main__":
    ENTRIES_DIR.mkdir(parents=True, exist_ok=True)
    port = int(os.environ.get("BLOG_PORT", 8766))
    print(f"Blog server starting on http://localhost:{port}/blog/")
    app.run(host="127.0.0.1", port=port, debug=False)
