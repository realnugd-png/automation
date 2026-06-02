"""
Generates YouTube thumbnails (1280x720) in 3 rotating styles for variety and A/B testing.
Style rotates daily to prevent visual fatigue.
"""
import io
import random
import urllib.parse
from datetime import datetime
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFont, ImageFilter


def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "C:/Windows/Fonts/impact.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/ariblk.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _outlined_text(draw, x, y, text, font, fill, stroke=6):
    for dx in range(-stroke, stroke + 1):
        for dy in range(-stroke, stroke + 1):
            if dx or dy:
                draw.text((x + dx, y + dy), text, font=font, fill=(0, 0, 0))
    draw.text((x, y), text, font=font, fill=fill)


def _fetch_image(prompt: str, W: int, H: int) -> Image.Image:
    seed = random.randint(1, 999_999)
    encoded = urllib.parse.quote(prompt, safe="")
    url = f"https://image.pollinations.ai/prompt/{encoded}?width={W}&height={H}&seed={seed}&nologo=true&model=flux"
    resp = requests.get(url, timeout=90)
    resp.raise_for_status()
    if len(resp.content) < 5000:
        raise ValueError("Image too small — likely an error response")
    return Image.open(io.BytesIO(resp.content)).convert("RGB").resize((W, H), Image.LANCZOS)


def _style_bold_impact(img: Image.Image, title: str) -> Image.Image:
    """Style 1: Bold text, dark overlay, yellow title — classic viral style."""
    W, H = img.size
    draw_ov = ImageDraw.Draw(img.convert("RGBA"))

    # Dark gradient overlay
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for y in range(H):
        alpha = int(160 * (1 - (min(y, H - y) / (H / 2)) ** 0.5))
        d.rectangle([0, y, W, y + 1], fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    draw = ImageDraw.Draw(img)
    words = title.upper().split()
    mid = max(1, len(words) // 2)
    line1 = " ".join(words[:mid])
    line2 = " ".join(words[mid:])

    font = _load_font(112, bold=True)
    font_sm = _load_font(72, bold=True)

    for i, (line, f) in enumerate([(line1, font), (line2, font_sm)]):
        if not line:
            continue
        bbox = draw.textbbox((0, 0), line, font=f)
        x = (W - (bbox[2] - bbox[0])) // 2
        y = H // 2 - 130 + i * 120
        _outlined_text(draw, x, y, line, f, fill=(255, 220, 0))

    # Gold bar
    draw.rectangle([(W // 2 - 200, H // 2 + 8), (W // 2 + 200, H // 2 + 13)], fill=(212, 175, 55))
    return img


def _style_minimal_text(img: Image.Image, title: str) -> Image.Image:
    """Style 2: Clean minimal — white text on strong gradient, premium feel."""
    W, H = img.size

    # Heavy bottom gradient
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    grad_h = int(H * 0.55)
    for y in range(grad_h):
        alpha = int(240 * (y / grad_h) ** 1.2)
        d.rectangle([0, H - grad_h + y, W, H - grad_h + y + 1], fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    draw = ImageDraw.Draw(img)
    font_big = _load_font(80, bold=True)
    font_sm = _load_font(40)

    # Wrap title to 2 lines
    words = title.split()
    mid = max(1, len(words) // 2)
    line1 = " ".join(words[:mid])
    line2 = " ".join(words[mid:])

    for i, (line, f) in enumerate([(line1, font_big), (line2, font_big)]):
        if not line:
            continue
        bbox = draw.textbbox((0, 0), line, font=f)
        x = (W - (bbox[2] - bbox[0])) // 2
        y = H - 200 + i * 95
        _outlined_text(draw, x, y, line, f, fill=(255, 255, 255), stroke=4)

    # Thin gold accent
    draw.rectangle([(40, H - 220), (W - 40, H - 216)], fill=(212, 175, 55))
    return img


def _style_split_panel(img: Image.Image, title: str) -> Image.Image:
    """Style 3: Left dark panel with text + right vivid image — editorial feel."""
    W, H = img.size

    # Create composite: dark panel on left 45%
    panel_w = int(W * 0.45)
    panel = Image.new("RGB", (panel_w, H), (8, 8, 12))

    # Subtle gradient edge
    for x in range(60):
        alpha = int(255 * (1 - x / 60))
        for y in range(H):
            r, g, b = img.getpixel((panel_w + x, y))
            blend = alpha / 255
            panel_r = int(8 * blend + r * (1 - blend))
            panel_g = int(8 * blend + g * (1 - blend))
            panel_b = int(12 * blend + b * (1 - blend))
            if panel_w + x < W:
                img.putpixel((panel_w + x, y), (panel_r, panel_g, panel_b))

    # Paste panel
    img.paste(panel, (0, 0))
    draw = ImageDraw.Draw(img)

    # Gold left accent bar
    draw.rectangle([(28, H // 2 - 120), (32, H // 2 + 120)], fill=(212, 175, 55))

    # Title text in panel
    words = title.split()
    font = _load_font(62, bold=True)
    lines = []
    current = []
    max_w = panel_w - 80
    for word in words:
        test = " ".join(current + [word])
        if draw.textbbox((0, 0), test, font=font)[2] <= max_w or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))

    total_h = len(lines) * 75
    y = H // 2 - total_h // 2
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        x = 48
        _outlined_text(draw, x, y, line, font, fill=(255, 255, 255), stroke=3)
        y += 75

    # "Daily Motivation" label at bottom of panel
    f_sm = _load_font(28)
    draw.text((48, H - 70), "DAILY MOTIVATION", font=f_sm, fill=(212, 175, 55))

    return img


STYLES = [_style_bold_impact, _style_minimal_text, _style_split_panel]
STYLE_NAMES = ["bold_impact", "minimal_text", "split_panel"]


def _get_thumbnail_prompt(title: str, video_format: str) -> str:
    """Generate a background image prompt based on video format."""
    format_prompts = {
        "Monday Momentum": "person running at sunrise, dramatic city skyline, golden light, energy and power",
        "Truth Tuesday": "single person standing on cliff edge overlooking vast landscape, contemplative, dramatic clouds",
        "Midweek Mindset": "mountain climber reaching summit, epic aerial view, golden hour, achievement",
        "Top 5 Thursday": "clean modern workspace with success symbols, books, trophies, golden light",
        "Friday Fire": "dramatic fire and light trails, energy and motion, dark background, powerful",
        "Saturday Wisdom": "peaceful library or nature scene, golden afternoon light, wisdom and calm",
        "Sunday Reset": "serene morning scene, coffee and journal, soft golden light, new beginning",
    }
    base = format_prompts.get(video_format, "dramatic cinematic landscape, golden hour, inspirational, epic")
    return (
        f"{base}. Photorealistic, 8k, cinematic lighting, "
        f"no text, no words, no people's faces clearly visible, "
        f"emotionally powerful composition"
    )


def generate_thumbnail(title: str, output_dir: Path, video_format: str = "") -> Path:
    """Generate a YouTube thumbnail (1280x720) and return its path."""
    W, H = 1280, 720
    thumb_path = output_dir / "thumbnail.jpg"

    # Rotate style daily
    style_idx = datetime.now().weekday() % len(STYLES)
    style_fn = STYLES[style_idx]
    style_name = STYLE_NAMES[style_idx]

    print(f"  Thumbnail style: {style_name}")

    prompt = _get_thumbnail_prompt(title, video_format)
    img = _fetch_image(prompt, W, H)
    img = style_fn(img, title)
    img.save(str(thumb_path), "JPEG", quality=95)

    return thumb_path
