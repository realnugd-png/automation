"""
Analytics logger: tracks every uploaded video with metadata.
Saves to analytics.json — review to see what's working.
"""
import json
from datetime import datetime
from pathlib import Path

ANALYTICS_FILE = Path("analytics.json")


def _load() -> list:
    if ANALYTICS_FILE.exists():
        try:
            return json.loads(ANALYTICS_FILE.read_text(encoding="utf-8"))
        except Exception:
            return []
    return []


def log_upload(video_id: str, script: dict, video_path: Path, thumb_path: Path) -> None:
    """Log a successful upload with all relevant metadata."""
    records = _load()

    entry = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "time": datetime.now().strftime("%H:%M:%S"),
        "video_id": video_id,
        "url": f"https://youtube.com/watch?v={video_id}",
        "title": script.get("title", ""),
        "format": script.get("format", "unknown"),
        "tags": script.get("tags", []),
        "video_size_mb": round(video_path.stat().st_size / 1_048_576, 1) if video_path.exists() else 0,
        "scenes": len(script.get("scenes", [])),
        "description_chars": len(script.get("description", "")),
    }

    records.append(entry)
    ANALYTICS_FILE.write_text(json.dumps(records, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  Analytics logged: {len(records)} total uploads tracked")


def print_summary() -> None:
    """Print a summary of all uploads."""
    records = _load()
    if not records:
        print("No uploads tracked yet.")
        return

    print(f"\n{'='*50}")
    print(f"CHANNEL ANALYTICS — {len(records)} videos uploaded")
    print(f"{'='*50}")

    format_counts = {}
    for r in records:
        fmt = r.get("format", "unknown")
        format_counts[fmt] = format_counts.get(fmt, 0) + 1

    print("\nVideos per format:")
    for fmt, count in sorted(format_counts.items(), key=lambda x: -x[1]):
        print(f"  {fmt}: {count}")

    print(f"\nFirst upload: {records[0]['date']}")
    print(f"Latest upload: {records[-1]['date']}")
    print(f"Latest video: {records[-1]['url']}")
    print(f"{'='*50}\n")
