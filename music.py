"""
Auto-downloads a royalty-free background music track.
Tracks are cached locally after first download.
"""
import random
from pathlib import Path

import requests

MUSIC_DIR = Path("music")
MUSIC_DIR.mkdir(exist_ok=True)

# Royalty-free instrumental tracks (SoundHelix — free to use without attribution)
_TRACKS = [
    "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
    "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3",
    "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3",
    "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3",
    "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-17.mp3",
]


def get_music_path() -> str:
    """Return local path to a random background track, downloading if needed."""
    url = random.choice(_TRACKS)
    filename = url.split("/")[-1]
    local = MUSIC_DIR / filename

    if not local.exists():
        print(f"  Downloading background music ({filename})...")
        resp = requests.get(url, timeout=60)
        resp.raise_for_status()
        local.write_bytes(resp.content)

    return str(local)
