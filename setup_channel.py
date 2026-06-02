"""
One-time channel setup script.
Generates a professional banner + description and uploads them to your channel.
Run: python setup_channel.py
"""
import io
import json
import random
import urllib.parse
from pathlib import Path

import requests
from PIL import Image, ImageDraw, ImageFont
import google.oauth2.credentials
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.http
from google.auth.transport.requests import Request
from groq import Groq

import config

# Broader scope needed for channel management (separate from upload token)
_SCOPES = ["https://www.googleapis.com/auth/youtube"]
_TOKEN_PATH = "channel_token.json"

CHANNEL_NAME = "Daily Motivation"
CHANNEL_TAGLINE = "Fuel your mind. Every single day."
UPLOAD_SCHEDULE = "New video every day"


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def _get_service():
    token_path = Path(_TOKEN_PATH)
    creds = None
    if token_path.exists():
        creds = google.oauth2.credentials.Credentials.from_authorized_user_info(
            json.loads(token_path.read_text()), _SCOPES
        )
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = google_auth_oauthlib.flow.InstalledAppFlow.from_client_secrets_file(
                config.YOUTUBE_CLIENT_SECRETS_PATH, _SCOPES
            )
            creds = flow.run_local_server(port=0)
        token_path.write_text(creds.to_json())
    return googleapiclient.discovery.build("youtube", "v3", credentials=creds)


# ---------------------------------------------------------------------------
# Description generation
# ---------------------------------------------------------------------------

def _generate_description() -> str:
    client = Groq(api_key=config.GROQ_API_KEY)
    resp = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{
            "role": "user",
            "content": (
                f'Write a professional YouTube channel description for "{CHANNEL_NAME}".\n'
                "Requirements:\n"
                "- 3 short paragraphs\n"
                "- First line: bold hook about what viewers gain\n"
                "- What the channel is about\n"
                "- Mention new video every day + subscribe CTA\n"
                f'- Last line: "{CHANNEL_TAGLINE}"\n'
                "- Under 900 characters total\n"
                "- No hashtags\n"
                "Return only the description text."
            )
        }],
        max_tokens=512,
        temperature=0.7,
    )
    return resp.choices[0].message.content.strip()


# ---------------------------------------------------------------------------
# Banner generation
# ---------------------------------------------------------------------------

def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in [
        "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _generate_banner() -> Path:
    """Generate a 2560x1440 YouTube channel banner."""
    W, H = 2560, 1440
    out = Path("output/channel_banner.jpg")
    out.parent.mkdir(exist_ok=True)

    # Background image from Pollinations
    prompt = (
        "Cinematic aerial view of mountain peaks at golden hour, dramatic sun rays through clouds, "
        "deep orange gold sky, epic landscape, ultra-wide, 8k, photorealistic, no text, no people"
    )
    encoded = urllib.parse.quote(prompt, safe="")
    seed = random.randint(1, 999_999)
    url = (
        f"https://image.pollinations.ai/prompt/{encoded}"
        f"?width=1920&height=1080&seed={seed}&nologo=true&model=flux"
    )
    print("    Generating banner background image...")
    resp = requests.get(url, timeout=90)
    resp.raise_for_status()

    bg = Image.open(io.BytesIO(resp.content)).convert("RGB").resize((W, H), Image.LANCZOS)

    # Dark vignette overlay — heavier on sides so center text pops
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for x in range(W):
        edge_dist = abs(x - W // 2) / (W // 2)
        alpha = int(70 + 150 * edge_dist ** 0.7)
        d.rectangle([x, 0, x + 1, H], fill=(0, 0, 0, min(alpha, 220)))
    # Overall darkening
    d.rectangle([0, 0, W, H], fill=(0, 0, 0, 90))

    bg = Image.alpha_composite(bg.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(bg)

    # ── Center safe zone: 1546x423 centred at (1280, 720) ──────────────────
    cx, cy = W // 2, H // 2

    # Top gold rule
    lw = 560
    draw.rectangle([(cx - lw // 2, cy - 148), (cx + lw // 2, cy - 144)], fill=(212, 175, 55))

    # Channel name
    f_big = _load_font(168)
    bbox = draw.textbbox((0, 0), CHANNEL_NAME, font=f_big)
    tw = bbox[2] - bbox[0]
    x0 = cx - tw // 2
    draw.text((x0 + 4, cy - 134 + 4), CHANNEL_NAME, font=f_big, fill=(0, 0, 0))       # shadow
    draw.text((x0, cy - 134), CHANNEL_NAME, font=f_big, fill=(255, 255, 255))

    # Bottom gold rule
    draw.rectangle([(cx - lw // 2, cy + 58), (cx + lw // 2, cy + 62)], fill=(212, 175, 55))

    # Tagline
    f_tag = _load_font(58)
    bbox2 = draw.textbbox((0, 0), CHANNEL_TAGLINE, font=f_tag)
    tw2 = bbox2[2] - bbox2[0]
    draw.text((cx - tw2 // 2, cy + 80), CHANNEL_TAGLINE, font=f_tag, fill=(225, 225, 210))

    # Upload schedule — gold
    f_sch = _load_font(44)
    bbox3 = draw.textbbox((0, 0), UPLOAD_SCHEDULE, font=f_sch)
    tw3 = bbox3[2] - bbox3[0]
    draw.text((cx - tw3 // 2, cy + 162), UPLOAD_SCHEDULE, font=f_sch, fill=(212, 175, 55))

    bg.save(str(out), "JPEG", quality=92)
    return out


# ---------------------------------------------------------------------------
# YouTube channel update
# ---------------------------------------------------------------------------

def _upload_banner(service, banner_path: Path) -> str:
    """Upload banner image and apply it. Returns channel_id."""
    print("    Uploading banner to YouTube...")
    banner_resp = service.channelBanners().insert(
        media_body=googleapiclient.http.MediaFileUpload(
            str(banner_path), mimetype="image/jpeg", resumable=True
        )
    ).execute()

    # Fetch existing branding settings so we don't overwrite unrelated fields
    ch = service.channels().list(part="id,brandingSettings", mine=True).execute()
    item = ch["items"][0]
    channel_id = item["id"]
    branding = item.get("brandingSettings", {})
    branding.setdefault("image", {})["bannerExternalUrl"] = banner_resp["url"]

    service.channels().update(
        part="brandingSettings",
        body={"id": channel_id, "brandingSettings": branding},
    ).execute()
    return channel_id


def _update_info(service, channel_id: str, description: str) -> None:
    """Update channel description and keywords."""
    ch = service.channels().list(part="id,brandingSettings", mine=True).execute()
    item = ch["items"][0]
    branding = item.get("brandingSettings", {})
    branding.setdefault("channel", {}).update({
        "description": description,
        "keywords": (
            "motivation inspiration mindset success daily motivation "
            "positive thinking self improvement mental strength confidence"
        ),
        "defaultLanguage": "en",
    })

    service.channels().update(
        part="brandingSettings",
        body={"id": channel_id, "brandingSettings": branding},
    ).execute()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def setup():
    print("Setting up YouTube channel profile...\n")

    print("[1/4] Generating channel description...")
    description = _generate_description()
    print(f"  Preview: {description[:100]}...\n")

    print("[2/4] Generating channel banner (2560x1440)...")
    banner_path = _generate_banner()
    print(f"  Saved: {banner_path}\n")

    print("[3/4] Authenticating with YouTube (channel management)...")
    service = _get_service()
    print("  Authenticated\n")

    print("[4/4] Uploading banner and updating channel info...")
    channel_id = _upload_banner(service, banner_path)
    _update_info(service, channel_id, description)

    print(f"\nDone! Channel updated: https://youtube.com/channel/{channel_id}")
    print("\nDescription set to:\n")
    print(description)


if __name__ == "__main__":
    setup()
