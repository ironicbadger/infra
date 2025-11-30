from flask import Flask, Response
from collections import deque
from dataclasses import dataclass
import threading
import subprocess
import socket
import time
import os

app = Flask(__name__)


def parse_duration(s: str) -> int:
    """Parse duration string like '30s', '5m', '1h' to seconds."""
    s = s.strip().lower()
    if s.endswith("s"):
        return int(s[:-1])
    elif s.endswith("m"):
        return int(s[:-1]) * 60
    elif s.endswith("h"):
        return int(s[:-1]) * 3600
    elif s.endswith("d"):
        return int(s[:-1]) * 86400
    return int(s)  # assume seconds if no unit


# Config from environment
INTERVAL = parse_duration(os.environ.get("INTERVAL", "60s"))
HISTORY = parse_duration(os.environ.get("HISTORY", "1h")) // max(INTERVAL, 1)
BASE_URL = os.environ.get("BASE_URL", "")


@dataclass
class Target:
    host: str
    probe_type: str  # icmp, tcp, dns
    port: int = 443  # for tcp
    display_name: str = ""

    def __post_init__(self):
        if not self.display_name:
            if self.probe_type == "icmp":
                self.display_name = self.host
            elif self.probe_type == "tcp":
                self.display_name = f"{self.host}:{self.port}"
            elif self.probe_type == "dns":
                self.display_name = f"{self.host} (dns)"


def parse_targets(targets_str: str) -> list[Target]:
    """Parse target string like 'Cloudflare=1.1.1.1:icmp,Google=google.com:tcp:443'"""
    targets = []
    for part in targets_str.split(","):
        part = part.strip()
        if not part:
            continue

        # Check for display name: "Name=host:type:port"
        display_name = ""
        if "=" in part:
            display_name, part = part.split("=", 1)

        pieces = part.split(":")
        host = pieces[0]
        probe_type = pieces[1] if len(pieces) > 1 else "icmp"
        port = int(pieces[2]) if len(pieces) > 2 else 443
        targets.append(Target(host=host, probe_type=probe_type, port=port, display_name=display_name))
    return targets


TARGETS = parse_targets(os.environ.get("TARGETS", "8.8.8.8:icmp,1.1.1.1:icmp"))

# Per-target history: {display_name: deque of (timestamp, latency_ms or None)}
history = {t.display_name: deque(maxlen=HISTORY) for t in TARGETS}


def probe_icmp(host: str) -> float | None:
    """ICMP ping - returns latency in ms or None if failed."""
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-W", "2", host],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            for part in result.stdout.split():
                if part.startswith("time="):
                    return float(part.split("=")[1])
    except Exception:
        pass
    return None


def probe_tcp(host: str, port: int) -> float | None:
    """TCP connect - returns latency in ms or None if failed."""
    try:
        start = time.perf_counter()
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect((host, port))
        elapsed = (time.perf_counter() - start) * 1000
        sock.close()
        return elapsed
    except Exception:
        pass
    return None


def probe_dns(host: str) -> float | None:
    """DNS lookup - returns latency in ms or None if failed."""
    try:
        start = time.perf_counter()
        socket.gethostbyname(host)
        elapsed = (time.perf_counter() - start) * 1000
        return elapsed
    except Exception:
        pass
    return None


def probe(target: Target) -> float | None:
    """Run the appropriate probe for the target."""
    if target.probe_type == "icmp":
        return probe_icmp(target.host)
    elif target.probe_type == "tcp":
        return probe_tcp(target.host, target.port)
    elif target.probe_type == "dns":
        return probe_dns(target.host)
    return None


def ping_worker():
    while True:
        for target in TARGETS:
            latency = probe(target)
            history[target.display_name].append((time.time(), latency))
        time.sleep(INTERVAL)


def svg_smooth_path(values: list[float | None], width: float = 100, height: float = 30) -> str:
    """Generate smooth SVG path using cubic bezier curves."""
    # Build list of (x, y) points, skipping None values
    valid_values = [v for v in values if v is not None]
    if len(valid_values) < 2:
        return ""

    padding = height * 0.1
    h = height - padding * 2
    min_v, max_v = min(valid_values), max(valid_values)
    if max_v == min_v:
        max_v = min_v + 1

    step = width / (len(values) - 1) if len(values) > 1 else width
    points = []
    for i, v in enumerate(values):
        if v is not None:
            x = i * step
            y = ((max_v - v) / (max_v - min_v)) * h + padding
            points.append((x, y))

    if len(points) < 2:
        return ""

    # Build smooth path using cubic bezier curves
    path = [f"M {points[0][0]:.1f},{points[0][1]:.1f}"]

    for i in range(1, len(points)):
        x0, y0 = points[i - 1]
        x1, y1 = points[i]

        # Control point offset (smoothing factor)
        tension = 0.3
        dx = (x1 - x0) * tension

        # Cubic bezier: C cp1x,cp1y cp2x,cp2y x,y
        cp1x = x0 + dx
        cp1y = y0
        cp2x = x1 - dx
        cp2y = y1

        path.append(f"C {cp1x:.1f},{cp1y:.1f} {cp2x:.1f},{cp2y:.1f} {x1:.1f},{y1:.1f}")

    return " ".join(path)


def render_html() -> str:
    html = ['<div style="font-family: system-ui, sans-serif;">']

    for name, data in history.items():
        values = [d[1] for d in data]
        valid = [v for v in values if v is not None]

        current = valid[-1] if valid else None
        min_v = min(valid) if valid else 0
        max_v = max(valid) if valid else 0
        avg_v = sum(valid) / len(valid) if valid else 0
        loss = (len(values) - len(valid)) / len(values) * 100 if values else 0

        path_d = svg_smooth_path(values)
        loss_html = (
            f'<span style="color: #ff6b6b;">loss: {loss:.0f}%</span>' if loss > 0 else ""
        )

        html.append(f"""
        <div style="margin-bottom: 1rem;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span style="font-weight: 500;">{name}</span>
            <span style="opacity: 0.7;">{f"{current:.1f}ms" if current else "—"}</span>
          </div>
          <svg viewBox="0 0 100 30" style="width: 100%; height: 40px; background: rgba(255,255,255,0.05); border-radius: 4px;">
            <line x1="0" y1="10" x2="100" y2="10" stroke="currentColor" stroke-opacity="0.1" stroke-dasharray="2,2"/>
            <line x1="0" y1="20" x2="100" y2="20" stroke="currentColor" stroke-opacity="0.1" stroke-dasharray="2,2"/>
            <path fill="none" stroke="#00cc00" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"
                  d="{path_d}" vector-effect="non-scaling-stroke"/>
          </svg>
          <div style="display: flex; justify-content: space-between; font-size: 0.75rem; opacity: 0.6;">
            <span>min: {min_v:.0f}ms</span>
            <span>avg: {avg_v:.0f}ms</span>
            <span>max: {max_v:.0f}ms</span>
            {loss_html}
          </div>
        </div>
        """)

    html.append("</div>")
    return "".join(html)


@app.route("/")
def index():
    html = render_html()
    resp = Response(html, mimetype="text/html")
    resp.headers["Widget-Title"] = "Network Latency"
    resp.headers["Widget-Title-URL"] = f"{BASE_URL}/detail" if BASE_URL else "/detail"
    resp.headers["Widget-Content-Type"] = "html"
    return resp


def format_duration(seconds: int) -> str:
    """Format seconds into human readable duration."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m"
    elif seconds < 86400:
        h = seconds // 3600
        m = (seconds % 3600) // 60
        return f"{h}h {m}m" if m else f"{h}h"
    else:
        d = seconds // 86400
        h = (seconds % 86400) // 3600
        return f"{d}d {h}h" if h else f"{d}d"


@app.route("/detail")
def detail():
    """Full page detail view with larger graphs."""
    # Calculate timeframe
    total_seconds = INTERVAL * HISTORY
    timeframe = format_duration(total_seconds)
    interval_str = format_duration(INTERVAL)

    html = [f"""<!DOCTYPE html>
<html>
<head>
    <title>Network Latency</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * {{ box-sizing: border-box; }}
        body {{
            font-family: system-ui, sans-serif;
            background: #111;
            color: #eee;
            margin: 0;
            padding: 1.5rem;
        }}
        .header {{
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            margin-bottom: 1.5rem;
        }}
        h1 {{ margin: 0; font-size: 1.5rem; font-weight: 500; }}
        .legend {{
            font-size: 0.85rem;
            opacity: 0.6;
        }}
        .target {{ margin-bottom: 2rem; }}
        .target-header {{
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            margin-bottom: 0.5rem;
        }}
        .target-name {{ font-weight: 500; font-size: 1.1rem; }}
        .target-current {{ opacity: 0.7; }}
        .graph-container {{
            background: rgba(255,255,255,0.05);
            border-radius: 6px;
            padding: 0.5rem;
            position: relative;
        }}
        .time-axis {{
            display: flex;
            justify-content: space-between;
            font-size: 0.75rem;
            opacity: 0.4;
            margin-top: 0.25rem;
        }}
        .stats {{
            display: flex;
            justify-content: space-between;
            font-size: 0.85rem;
            opacity: 0.6;
            margin-top: 0.5rem;
        }}
        .loss {{ color: #ff6b6b; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Network Latency</h1>
        <div class="legend">Last {timeframe} &bull; {interval_str} intervals</div>
    </div>
"""]

    for name, data in history.items():
        values = [d[1] for d in data]
        valid = [v for v in values if v is not None]

        current = valid[-1] if valid else None
        min_v = min(valid) if valid else 0
        max_v = max(valid) if valid else 0
        avg_v = sum(valid) / len(valid) if valid else 0
        loss = (len(values) - len(valid)) / len(values) * 100 if values else 0

        path_d = svg_smooth_path(values, width=800, height=120)
        loss_html = f'<span class="loss">loss: {loss:.0f}%</span>' if loss > 0 else ""

        html.append(f"""
    <div class="target">
        <div class="target-header">
            <span class="target-name">{name}</span>
            <span class="target-current">{f"{current:.1f}ms" if current else "—"}</span>
        </div>
        <div class="graph-container">
            <svg viewBox="0 0 800 120" style="width: 100%; height: 120px;">
                <line x1="0" y1="30" x2="800" y2="30" stroke="currentColor" stroke-opacity="0.1" stroke-dasharray="4,4"/>
                <line x1="0" y1="60" x2="800" y2="60" stroke="currentColor" stroke-opacity="0.1" stroke-dasharray="4,4"/>
                <line x1="0" y1="90" x2="800" y2="90" stroke="currentColor" stroke-opacity="0.1" stroke-dasharray="4,4"/>
                <path fill="none" stroke="#00cc00" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                      d="{path_d}" vector-effect="non-scaling-stroke"/>
            </svg>
            <div class="time-axis">
                <span>{timeframe} ago</span>
                <span>now</span>
            </div>
        </div>
        <div class="stats">
            <span>min: {min_v:.1f}ms</span>
            <span>avg: {avg_v:.1f}ms</span>
            <span>max: {max_v:.1f}ms</span>
            {loss_html}
        </div>
    </div>
""")

    html.append("</body></html>")
    return "".join(html)


if __name__ == "__main__":
    threading.Thread(target=ping_worker, daemon=True).start()
    app.run(host="0.0.0.0", port=8080)
