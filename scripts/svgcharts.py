"""Tiny dependency-free SVG chart writer: bars, horizontal bars, lines and a multi-panel dashboard.
Only plain vector shapes (rect/line/polyline/text) - no embedded images."""
from html import escape

PAL = ["#1f6f8b", "#e07a5f", "#81b29a", "#f2cc8f", "#3d405b", "#9c6644", "#6d597a", "#2a9d8f"]


def _f(v, fmt):
    return fmt.format(v) if fmt else (f"{v:,.0f}" if abs(v) >= 100 else f"{v:,.1f}")


def _t(x, y, s, size=10, anchor="start", color="#333", weight=None, rot=None):
    w = f' font-weight="{weight}"' if weight else ""
    r = f' transform="rotate({rot} {x:.0f} {y:.0f})"' if rot else ""
    return f'<text x="{x:.0f}" y="{y:.0f}" font-size="{size}" text-anchor="{anchor}" fill="{color}"{w}{r}>{escape(str(s))}</text>'


def _wrap(body, w, h, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="sans-serif">'
            f'<rect width="{w}" height="{h}" fill="#fff"/>' + _t(10, 20, title, 13, weight="bold") + "".join(body) + "</svg>")


def hbar(labels, values, title, fmt=None, w=560, h=None, color=PAL[0]):
    n = len(labels); h = h or 40 + 22 * n; left = 10 + min(28, max(len(str(l)) for l in labels)) * 6.2
    vmax = max(max(values), 1e-9); span = w - left - 70; b = []
    for i, (l, v) in enumerate(zip(labels, values)):
        y = 34 + i * 22; bw = max(0, v) / vmax * span
        b.append(_t(left - 6, y + 13, str(l)[:28], 10, "end"))
        b.append(f'<rect x="{left:.0f}" y="{y}" width="{bw:.0f}" height="16" fill="{color}"/>')
        b.append(_t(left + bw + 4, y + 13, _f(v, fmt), 9))
    return _wrap(b, w, h, title)


def vbar(labels, values, title, fmt=None, w=560, h=300, color=PAL[0], rot=None):
    n = len(labels); top, bot, left = 34, 50 if rot else 30, 20
    vmax = max(max(values), 1e-9); ph = h - top - bot - 14; step = (w - 2 * left) / n; b = []
    for i, (l, v) in enumerate(zip(labels, values)):
        bh = max(0, v) / vmax * ph; x = left + i * step + step * 0.15; y = h - bot - bh
        b.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{step * 0.7:.0f}" height="{bh:.0f}" fill="{color}"/>')
        b.append(_t(x + step * 0.35, y - 3, _f(v, fmt), 8 if n > 10 else 9, "middle"))
        lx = x + step * 0.35
        b.append(_t(lx, h - bot + 13, str(l)[:16], 9, "end" if rot else "middle", rot=rot))
    b.append(f'<line x1="{left}" y1="{h - bot}" x2="{w - left}" y2="{h - bot}" stroke="#999"/>')
    return _wrap(b, w, h, title)


def line(xs, series, title, fmt=None, w=560, h=300, every=None):
    """series: {name: [values aligned to xs]} (None = gap)."""
    top, bot, left, right = 34, 40, 58, 14 + (110 if len(series) > 1 else 0)
    allv = [v for s in series.values() for v in s if v is not None]
    vmax = max(max(allv), 1e-9); vmin = min(0, min(allv)); pw, ph = w - left - right, h - top - bot
    X = lambda i: left + (i / max(1, len(xs) - 1)) * pw
    Y = lambda v: top + ph - (v - vmin) / (vmax - vmin) * ph
    b = []
    for k in range(5):
        v = vmin + (vmax - vmin) * k / 4; y = Y(v)
        b.append(f'<line x1="{left}" y1="{y:.0f}" x2="{left + pw}" y2="{y:.0f}" stroke="#eee"/>')
        b.append(_t(left - 4, y + 3, _f(v, fmt), 8, "end", "#666"))
    every = every or max(1, len(xs) // 8)
    for i, x in enumerate(xs):
        if i % every == 0 or i == len(xs) - 1:
            b.append(_t(X(i), h - bot + 14, str(x)[:10], 8, "middle", "#666"))
    for j, (name, vals) in enumerate(series.items()):
        c = PAL[j % len(PAL)]; segs, cur = [], []
        for i, v in enumerate(vals):
            if v is None:
                if cur: segs.append(cur); cur = []
            else:
                cur.append(f"{X(i):.0f},{Y(v):.0f}")
        if cur: segs.append(cur)
        for s in segs:
            b.append(f'<polyline points="{" ".join(s)}" fill="none" stroke="{c}" stroke-width="1.6"/>')
        if len(series) > 1:
            ly = top + 4 + j * 15
            b.append(f'<rect x="{w - right + 8}" y="{ly}" width="10" height="10" fill="{c}"/>')
            b.append(_t(w - right + 22, ly + 9, str(name)[:16], 9))
    b.append(f'<line x1="{left}" y1="{top + ph}" x2="{left + pw}" y2="{top + ph}" stroke="#999"/>')
    return _wrap(b, w, h, title)


def dashboard(title, cards, panels, cols=2, pw=560, ph=300):
    """cards: [(label, value_str)], panels: list of SVG strings (rendered at pw x ph)."""
    rows = (len(panels) + cols - 1) // cols; W = cols * pw + (cols + 1) * 10; top = 110; H = top + rows * (ph + 10)
    b = [f'<rect width="{W}" height="{H}" fill="#f6f7f9"/>', _t(14, 30, title, 18, weight="bold")]
    cw = (W - 20) / max(1, len(cards))
    for i, (lab, val) in enumerate(cards):
        x = 10 + i * cw
        b.append(f'<rect x="{x + 4:.0f}" y="44" width="{cw - 8:.0f}" height="56" rx="6" fill="#fff" stroke="#ddd"/>')
        b.append(_t(x + cw / 2, 72, val, 17, "middle", PAL[0], "bold"))
        b.append(_t(x + cw / 2, 90, lab, 10, "middle", "#555"))
    for i, p in enumerate(panels):
        x = 10 + (i % cols) * (pw + 10); y = top + (i // cols) * (ph + 10)
        inner = p.replace('<svg xmlns="http://www.w3.org/2000/svg"', f'<svg x="{x}" y="{y}"', 1)
        b.append(inner)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="sans-serif">'
            + "".join(b) + "</svg>")
