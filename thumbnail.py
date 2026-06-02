"""
Generates a YouTube thumbnail (1280x720):
- Dramatic cinematic image from Pollinations.ai
- Bold title text with outline and gold accent bar
"""
import io
import random
import urllib.parse
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFont


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in [
        "C:/Windows/Fonts/impact.ttf",
        "C:/Windows/Fonts/ariblk.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _outlined_text(draw, x, y, text, font, fill, stroke=5):
    for dx in range(-stroke, stroke + 1):
        for dy in range(-stroke, stroke + 1):
            if dx or dy:
                draw.text((x + dx, y + dy), text, font=font, fill=(0, 0, 0))
    draw.text((x, y), text, font=font, fill=fill)


def generate_thumbnail(title: str, output_dir: Path) -> Path:
    """Generate and return path to thumbnail.jpg (1280x720)."""
    W, H = 1280, 720
    thumb_path = output_dir / "thumbnail.jpg"

    prompt = (
        "Cinematic close-up of a determined person standing at a mountain peak at golden hour, "
        "sun rays breaking through clouds, dramatic sky, ultra-detailed, 8k, inspirational, "
        "warm orange and gold tones, professional photography, no text, no words"
    )
    seed = random.randint(1, 999_999)
    encoded = urllib.parse.quote(prompt, safe="")
    url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width={W}&height={H}&seed={seed}&nologo=true&model=flux"
    )

    resp = requests.get(url, timeout=90)
    resp.raise_for_status()
    img = Image.open(io.BytesIO(resp.content)).convert("RGB").resize((W, H), Image.LANCZOS)

    # Dark vignette overlay for text contrast
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d_ov = ImageDraw.Draw(overlay)
    for y in range(H):
        alpha = int(155 * (1 - (min(y, H - y) / (H / 2)) ** 0.6))
        d_ov.rectangle([0, y, W, y + 1], fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    draw = ImageDraw.Draw(img)
    font = _load_font(108)
    font_sm = _load_font(52)

    # Split title into two lines
    words = title.split()
    mid = max(1, len(words) // 2)
    line1 = " ".join(words[:mid]).upper()
    line2 = " ".join(words[mid:]).upper()

    for i, line in enumerate([line1, line2]):
        if not line:
            continue
        f = font if i == 0 else font_sm
        bbox = draw.textbbox((0, 0), line, font=f)
        x = (W - (bbox[2] - bbox[0])) // 2
        y = H // 2 - 130 + i * 120
        _outlined_text(draw, x, y, line, f, fill=(255, 225, 40), stroke=5)

    # Gold divider
    bar_w = 220
    draw.rectangle([(W // 2 - bar_w // 2, H // 2 + 8), (W // 2 + bar_w // 2, H // 2 + 13)],
                   fill=(212, 175, 55))

    img.save(thumb_path, "JPEG", quality=95)
    return thumb_path
