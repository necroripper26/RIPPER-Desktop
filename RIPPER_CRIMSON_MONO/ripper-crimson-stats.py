#!/usr/bin/env python3
"""Read-only local telemetry; never sends information across a network."""
import json
import subprocess
import time
from pathlib import Path

try:
    import psutil
except ImportError:
    psutil = None


def run(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=1.0,
                              check=False).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def load_gpu():
    for i in range(16):
        path = Path(f"/sys/class/drm/card{i}/device/gpu_busy_percent")
        try:
            value = int(path.read_text().strip())
            if 0 <= value <= 100:
                return value
        except (OSError, ValueError):
            pass
    return None


def cpu_temp():
    if psutil is None:
        return None
    try:
        groups = psutil.sensors_temperatures()
        for entries in groups.values():
            for sensor in entries:
                key = str(sensor.label).lower()
                if any(x in key for x in ("package", "tdie", "tctl", "cpu", "core 0")) and 0 < sensor.current < 120:
                    return round(sensor.current)
    except (AttributeError, OSError):
        return None
    return None


def media():
    status = run("playerctl", "status")
    if status not in ("Playing", "Paused"):
        return {"status": "", "title": "", "artist": "", "progress": 0}
    title = run("playerctl", "metadata", "--format", "{{title}}")[:120]
    artist = run("playerctl", "metadata", "--format", "{{artist}}")[:100]
    position = run("playerctl", "position")
    duration = run("playerctl", "metadata", "--format", "{{mpris:length}}")
    progress = 0
    try:
        seconds = float(duration) / 1000000
        if seconds > 0:
            progress = max(0, min(1, float(position) / seconds))
    except (ValueError, ZeroDivisionError):
        pass
    return {"status": status, "title": title, "artist": artist, "progress": progress}


def main():
    data = {"cpu": None, "ram": None, "gpu": load_gpu(), "disk": None,
            "temp": cpu_temp(), "uptime": None, "memoryText": "", "diskText": "",
            "ssid": "", "down": None, "up": None}
    if psutil:
        try:
            mem = psutil.virtual_memory()
            disk = psutil.disk_usage("/")
            data.update(cpu=round(psutil.cpu_percent(interval=0.12)),
                        ram=round(mem.percent), disk=round(disk.percent),
                        uptime=int((time.time() - psutil.boot_time()) / 3600),
                        memoryText=f"{mem.used/2**30:.1f} / {mem.total/2**30:.1f} GiB",
                        diskText=f"{disk.used/2**30:.1f} / {disk.total/2**30:.1f} GiB")
            a = psutil.net_io_counters()
            start = time.monotonic()
            time.sleep(0.12)
            b = psutil.net_io_counters()
            delta = max(0.01, time.monotonic() - start)
            data["down"] = round(max(0, b.bytes_recv - a.bytes_recv) * 8 / 1e6 / delta, 2)
            data["up"] = round(max(0, b.bytes_sent - a.bytes_sent) * 8 / 1e6 / delta, 2)
        except (OSError, ValueError):
            pass
    # Active connection label; never pretend a scan result is measured internet speed.
    active = run("nmcli", "-t", "-f", "NAME", "connection", "show", "--active")
    data["ssid"] = next((line for line in active.splitlines() if line.strip()), "")[:80]
    data.update(media())
    print(json.dumps(data, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
