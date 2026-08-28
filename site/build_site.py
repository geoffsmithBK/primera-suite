#!/usr/bin/env python3
"""Generate index.html's body copy from README.md.

README.md is the single source for all prose. index.html stays the one
deployed artifact: this script rewrites only the regions between the
BEGIN/END GENERATED markers, in place. Everything else in index.html
(head, CSS, hero image, CTA buttons, version strip, footer) is hand-owned.

Run via `make site`. The pre-commit hook installed by `make hooks` runs it
automatically whenever README.md is staged.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
INDEX = ROOT / "index.html"

BLOB = "https://github.com/geoffsmithBK/primera-suite/blob/main/"

CREDITS_P_STYLE = (
    "color: var(--text-dim); font-size: 0.9375rem; "
    "margin-bottom: 0.5rem; max-width: 64ch;"
)


# ── inline markdown ──────────────────────────────────────────────────────────

def rewrite_url(url):
    """README links are relative to the repo; the site needs absolute ones."""
    if url.startswith(("http://", "https://", "#", "mailto:")):
        return url
    return BLOB + url.lstrip("./")


def link_attrs(url):
    return ' target="_blank" rel="noopener"' if rewrite_url(url).startswith("http") else ""


def render_inline(text):
    """Markdown subset: raw HTML, `code`, [links](url), **bold**, *em*/_em_."""
    stash = []

    def park(html):
        stash.append(html)
        return "\x00%d\x00" % (len(stash) - 1)

    # Raw inline HTML (e.g. 2<sup>n</sup>) passes through untouched.
    text = re.sub(r"<[^>\n]+>", lambda m: park(m.group(0)), text)
    text = re.sub(r"`([^`]+)`", lambda m: park("<code>%s</code>" % m.group(1)), text)

    # Park only the <a> tags, so **bold** inside a link label still renders.
    def link(m):
        label, url = m.group(1), m.group(2)
        open_tag = '<a href="%s"%s>' % (rewrite_url(url), link_attrs(url))
        return park(open_tag) + label + park("</a>")

    text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*([^*\n]+?)\*(?![\w*])", r"<em>\1</em>", text)
    text = re.sub(r"(?<![\w_])_([^_\n]+?)_(?![\w_])", r"<em>\1</em>", text)

    return re.sub(r"\x00(\d+)\x00", lambda m: stash[int(m.group(1))], text)


# ── block parsing ────────────────────────────────────────────────────────────

def parse_blocks(lines):
    """Group a section's lines into ('img', src) / ('list', items) / ('para', text).

    A '- ' line starts a list even with no blank line before it, matching how
    GitHub renders a list that interrupts a paragraph.
    """
    blocks, para, items = [], [], []

    def flush_para():
        if not para:
            return
        raw = [ln.rstrip() for ln in para]
        joined = " ".join(ln.strip() for ln in raw)
        if raw[0].lstrip().startswith("<p align"):
            src = re.search(r'src="([^"]+)"', joined)
            if src:
                blocks.append(("img", src.group(1)))
        else:
            blocks.append(("para", joined))
        para.clear()

    def flush_list():
        if items:
            blocks.append(("list", list(items)))
            items.clear()

    for line in lines:
        stripped = line.strip()
        if not stripped:
            flush_para()
            flush_list()
        elif stripped.startswith("- "):
            flush_para()
            items.append(stripped[2:].strip())
        elif items:
            items[-1] += " " + stripped
        else:
            para.append(line)

    flush_para()
    flush_list()
    return blocks


def parse_sections(md):
    """Everything from '## Primera Suite' on, split by heading."""
    lines = md.splitlines()
    start = next(i for i, ln in enumerate(lines) if ln.startswith("## "))

    sections, current = [], None
    for line in lines[start:]:
        m = re.match(r"^(#{2,3})\s+(.*?)\s*$", line)
        if m:
            current = {"level": len(m.group(1)), "title": m.group(2), "lines": []}
            sections.append(current)
        elif current is not None:
            current["lines"].append(line)

    for s in sections:
        s["blocks"] = parse_blocks(s["lines"])
    return sections


# ── emission ─────────────────────────────────────────────────────────────────

def img_tag(src, alt, cls):
    site_src = "/" + src.lstrip("./") if not src.startswith(("http", "/")) else src
    return ('        <img class="%s" src="%s" alt="%s" loading="lazy">'
            % (cls, site_src, alt))


def emit_hero(root):
    paras = [b for k, b in root["blocks"] if k == "para"]
    tagline = render_inline(paras[0]) if paras else ""
    return ["        <h1>%s</h1>" % root["title"],
            '        <p class="tagline">%s</p>' % tagline]


def emit_intro(root):
    paras = [b for k, b in root["blocks"] if k == "para"][1:]
    out = ['  <div class="container">', '    <section class="intro reveal">']
    out += ["      <p>%s</p>" % render_inline(p) for p in paras]
    out += ["    </section>", "  </div>"]
    return out


def emit_tool(sec):
    out = ['      <section class="tool-section reveal">',
           "        <h2>%s</h2>" % sec["title"]]
    seen_list = False
    for kind, block in sec["blocks"]:
        if kind == "img":
            out.append(img_tag(block, "%s controls" % sec["title"], "tool-img"))
        elif kind == "para":
            cls = "tool-desc tool-note" if seen_list else "tool-desc"
            out.append('        <p class="%s">%s</p>' % (cls, render_inline(block)))
        else:
            seen_list = True
            out.append('        <ul class="feature-list">')
            out += ["          <li><span>%s</span></li>" % render_inline(i)
                    for i in block]
            out.append("        </ul>")
    out.append("      </section>")
    return out


def emit_notes(sec):
    out = ['  <div class="container">',
           '    <section class="notes-section reveal">',
           "      <h3>%s</h3>" % sec["title"]]
    for kind, block in sec["blocks"]:
        if kind == "para":
            out.append("      <p>%s</p>" % render_inline(block))
        elif kind == "list":
            out.append('      <ul class="notes-list">')
            out += ["        <li><span>%s</span></li>" % render_inline(i)
                    for i in block]
            out.append("      </ul>")
    out += ["    </section>", "  </div>"]
    return out


def emit_credits(sec):
    out = ['  <div class="container">',
           '    <section class="credits reveal">',
           "      <h3>%s</h3>" % sec["title"]]
    for kind, block in sec["blocks"]:
        if kind == "para":
            out.append('      <p style="%s">%s</p>'
                       % (CREDITS_P_STYLE, render_inline(block)))
        elif kind == "list":
            out.append('      <div class="credits-grid">')
            out += ["        %s" % render_inline(i) for i in block]
            out.append("      </div>")
    out += ["    </section>", "  </div>"]
    return out


def build_body(sections):
    root = sections[0]
    out = emit_intro(root)
    out += ['', '  <hr class="rule">', '',
            '  <div class="container">', '    <div class="tools">']
    tail = []
    for sec in sections[1:]:
        if sec["title"].lower().startswith("notes"):
            tail += [""] + emit_notes(sec)
        elif sec["title"].lower().startswith("inspiration"):
            tail += [""] + emit_credits(sec)
        else:
            out += [""] + emit_tool(sec)
    out += ["", "    </div>", "  </div>"]
    return out + tail


# ── splice ───────────────────────────────────────────────────────────────────

def splice(html, name, lines):
    begin, end = "<!-- BEGIN GENERATED:%s -->" % name, "<!-- END GENERATED:%s -->" % name
    pattern = re.compile(
        r"([ \t]*)%s\n(?:.*?\n)??([ \t]*)%s" % (re.escape(begin), re.escape(end)),
        re.DOTALL,
    )
    if not pattern.search(html):
        sys.exit("error: missing %s ... %s markers in index.html" % (begin, end))
    body = "\n".join(lines)
    return pattern.sub(lambda m: "%s%s\n%s\n%s%s" % (m.group(1), begin, body,
                                                     m.group(2), end), html)


def main():
    sections = parse_sections(README.read_text(encoding="utf-8"))
    html = INDEX.read_text(encoding="utf-8")
    html = splice(html, "hero", emit_hero(sections[0]))
    html = splice(html, "body", build_body(sections))
    INDEX.write_text(html, encoding="utf-8")
    tools = [s["title"] for s in sections[1:]
             if not s["title"].lower().startswith(("notes", "inspiration"))]
    print("index.html regenerated from README.md (%d tool sections: %s)"
          % (len(tools), ", ".join(tools)))


if __name__ == "__main__":
    main()
