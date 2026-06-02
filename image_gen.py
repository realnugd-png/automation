"""
Image generation via Pollinations.ai — completely free, no account or API key needed.
Uses the Flux model. Expect 15-45 seconds per image.
"""
import random
import time
import urllib.parse
from pathlib import Path

import requests
import config


def generate_image(prompt: str, output_path: Path, retries: int = 4) -> Path:
    """Fetch one image from Pollinations.ai and save it."""
    seed = random.randint(1, 999_999)
    encoded = urllib.parse.quote(prompt, safe="")
    url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width={config.VIDEO_WIDTH}&height={config.VIDEO_HEIGHT}"
        f"&seed={seed}&nologo=true&model=flux"
    )

    for attempt in range(retries):
        try:
            resp = requests.get(url, timeout=90)
            resp.raise_for_status()
            # Pollinations occasionally returns a tiny error payload instead of an image
            if len(resp.content) < 5_000:
                raise ValueError("Response too small — likely an error page")
            output_path.write_bytes(resp.content)
            return output_path
        except Exception as exc:
            if attempt == retries - 1:
                raise
            wait = 10 * (attempt + 1)
            print(f"  Image attempt {attempt + 1} failed ({exc}), retrying in {wait}s...")
            time.sleep(wait)


def generate_images(scenes: list, output_dir: Path) -> list:
    """Generate one image per scene. Returns list of Paths."""
    paths = []
    for i, scene in enumerate(scenes):
        path = output_dir / f"image_{i:02d}.png"
        print(f"  Generating image {i + 1}/{len(scenes)}...")
        generate_image(scene["image_prompt"], path)
        paths.append(path)
        time.sleep(2)  # be a polite guest on the free service
    return paths
