"""Cold storage's page, GET / (v0.5 master spec 10.4; cold-storage.md 3;
capture W2 item 6): public, the players' "control" of what has been stored
(the owner: "a simple graph of the number of rows shipped per day"). One
chart per data type over the last five weeks, the rows declared against
the rows received each day, drawn on the server as inline SVG: no script.
A day whose rows received differ from those declared is marked (a red
triangle and a line naming it, never colour alone); each column's tooltip
is its SVG title; a table under each chart holds the figures."""

import datetime
import html
import time

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from db import coldstore_page

router = APIRouter()

FIRST = ("wal", "basebackup")                  # the vault's types first, then the data types
SLOT, COL, GAP = 20, 7, 2                      # px: a day's slot, a column, the gap between
LEFT, TOP, PLOT_H, BOTTOM = 56, 22, 140, 26

STYLE = """
:root { --surface: #fcfcfb; --ink: #0b0b0b; --ink-2: #52514e; --muted: #898781;
        --grid: #e1e0d9; --axis: #c3c2b7; --declared: #eb6834; --received: #2a78d6;
        --critical: #d03b3b; }
@media (prefers-color-scheme: dark) {
  :root { --surface: #1a1a19; --ink: #f0efec; --ink-2: #c3c2b7; --muted: #898781;
          --grid: #2c2c2a; --axis: #383835; --declared: #d95926; --received: #3987e5; }
}
body { background: var(--surface); color: var(--ink); margin: 2rem;
       font: 14px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
h1 { font-size: 1.4rem; margin: 0 0 .25rem; } h2 { font-size: 1.1rem; margin: 2rem 0 .25rem; }
p, summary, td, th, .note { color: var(--ink-2); }
.legend { display: flex; gap: 1.25rem; margin: .5rem 0 1rem; color: var(--ink-2); }
.sw { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: .4rem; }
svg text { fill: var(--ink-2); font-size: 11px; }
.grid { stroke: var(--grid); stroke-width: 1; } .axis { stroke: var(--axis); stroke-width: 1; }
.dec { fill: var(--declared); } .rec { fill: var(--received); } .mis { fill: var(--critical); }
table { border-collapse: collapse; margin-top: .5rem; font-variant-numeric: tabular-nums; }
td, th { padding: 2px 10px; text-align: right; border-bottom: 1px solid var(--grid); }
th:first-child, td:first-child { text-align: left; }
"""


def _n(value):
    return f"{value:,}"


def _top(value):
    if value <= 1:
        return 1
    power = 1
    while power * 10 <= value:
        power *= 10
    for m in (1, 2, 5, 10):
        if m * power >= value:
            return m * power
    return 10 * power


def _column(x, value, top, cls, title):
    """A column from the baseline, its data end rounded (2px), its tooltip a title."""
    if value <= 0:
        return ""
    h = max(1.0, PLOT_H * value / top)
    y = TOP + PLOT_H - h
    r = min(2.0, h / 2, COL / 2)
    d = (f"M{x},{TOP + PLOT_H} V{y + r:.1f} Q{x},{y:.1f} {x + r},{y:.1f} H{x + COL - r} "
         f"Q{x + COL},{y:.1f} {x + COL},{y + r:.1f} V{TOP + PLOT_H} Z")
    return f'<path class="{cls}" d="{d}"><title>{html.escape(title)}</title></path>'


def _chart(kind, days, figures):
    top = _top(max([max(d, r) for d, r, _ in figures.values()] or [1]))
    width = LEFT + SLOT * len(days) + 12
    height = TOP + PLOT_H + BOTTOM
    out = [f'<svg role="img" width="{width}" height="{height}" viewBox="0 0 {width} {height}" '
           f'aria-label="{html.escape(kind)}: rows per day, declared and received, last {len(days)} days">']
    for frac in (0, 0.5, 1):
        y = TOP + PLOT_H - PLOT_H * frac
        cls = "axis" if frac == 0 else "grid"
        out.append(f'<line class="{cls}" x1="{LEFT}" x2="{width - 12}" y1="{y:.1f}" y2="{y:.1f}"/>')
        label = _n(int(top * frac)) if frac != 0.5 or top % 2 == 0 else f"{top / 2:g}"
        out.append(f'<text x="{LEFT - 6}" y="{y + 4:.1f}" text-anchor="end">{label}</text>')
    mismatched = []
    for i, day in enumerate(days):
        x = LEFT + SLOT * i + (SLOT - 2 * COL - GAP) // 2
        declared, received, shipments = figures.get(day, (0, 0, 0))
        title = (f"{day}: declared {_n(declared)}, received {_n(received)}, "
                 f"{_n(shipments)} shipment{'s' if shipments != 1 else ''}")
        out.append(_column(x, declared, top, "dec", title))
        out.append(_column(x + COL + GAP, received, top, "rec", title))
        if declared != received:
            mismatched.append((day, declared, received))
            cx = x + COL + GAP / 2
            out.append(f'<path class="mis" d="M{cx - 4},{TOP - 4} L{cx + 4},{TOP - 4} L{cx},{TOP - 11} Z">'
                       f'<title>{html.escape(title)}: received differs from declared</title></path>')
        if i % 7 == 0 or i == len(days) - 1:
            label = "today" if i == len(days) - 1 else day[5:]
            out.append(f'<text x="{LEFT + SLOT * i + SLOT / 2}" y="{TOP + PLOT_H + 16}" '
                       f'text-anchor="middle">{label}</text>')
    out.append("</svg>")
    return "".join(out), mismatched


def _section(kind, days, figures):
    svg, mismatched = _chart(kind, days, figures)
    total = [sum(f[k] for f in figures.values()) for k in range(3)]
    out = [f"<h2>{html.escape(kind)}</h2>",
           f'<p>Last {len(days)} days: {_n(total[2])} shipments, {_n(total[0])} rows declared, '
           f"{_n(total[1])} received.</p>", svg]
    if mismatched:
        items = ", ".join(f"{d} (declared {_n(a)}, received {_n(b)})" for d, a, b in mismatched)
        out.append(f'<p class="note"><span style="color: var(--critical)">&#9650;</span> '
                   f"Received differs from declared: {items}.</p>")
    rows = "".join(f"<tr><td>{d}</td><td>{_n(figures[d][0])}</td><td>{_n(figures[d][1])}</td>"
                   f"<td>{_n(figures[d][2])}</td></tr>" for d in days if d in figures)
    out.append(f"<details><summary>Table</summary><table><tr><th>Day</th><th>Declared</th>"
               f"<th>Received</th><th>Shipments</th></tr>{rows}</table></details>")
    return "".join(out)


@router.get("/", response_class=HTMLResponse)
def page(request: Request):
    hostname = request.headers.get("host", "").rsplit(":", 1)[0].lower()
    delay_ms = int(coldstore_page.state(hostname).get("delay_ms", "0"))
    if delay_ms > 0:
        time.sleep(delay_ms / 1000)
    today, rows = coldstore_page.per_day()
    last = datetime.date.fromisoformat(today)
    days = [(last - datetime.timedelta(days=coldstore_page.DAYS - 1 - i)).isoformat()
            for i in range(coldstore_page.DAYS)]
    by_type = {}
    for kind, day, declared, received, shipments in rows:
        by_type.setdefault(kind, {})[day] = (int(declared), int(received), int(shipments))
    kinds = [k for k in FIRST if k in by_type] + sorted(k for k in by_type if k not in FIRST)
    body = "".join(_section(k, days, by_type[k]) for k in kinds) or \
        f"<p>No shipment received in the last {coldstore_page.DAYS} days.</p>"
    legend = ('<div class="legend"><span><span class="sw" style="background: var(--declared)"></span>'
              'declared</span><span><span class="sw" style="background: var(--received)"></span>'
              'received</span><span><span style="color: var(--critical)">&#9650;</span> '
              "received differs from declared</span></div>")
    return HTMLResponse(f'<!doctype html><html lang="en"><head><meta charset="utf-8">'
                        f"<title>Cold storage: shipments</title><style>{STYLE}</style></head><body>"
                        f"<h1>Cold storage: shipments</h1><p>Rows shipped per day and data type, "
                        f"declared by the sender against received, {days[0]} to {today} (UTC).</p>"
                        f"{legend}{body}</body></html>")
