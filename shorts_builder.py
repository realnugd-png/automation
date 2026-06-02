"""
Generates a YouTube Short (1080x1920 vertical, max 55 seconds).
Takes the 3 most impactful middle scenes from the main video.
Shorts get massive algorithmic reach and drive traffic to full videos.
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from moviepy.editor import (
    AudioFileClip,
    VideoClip,
    concatenate_videoclips,
    CompositeAudioClip,
    concatenate_audioclips,
)

import config

SW, SH = 1080, 1920  # Shorts dimensions (9:16)
MAX_DURATION = 55.0  # YouTube Shorts limit


def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = []
    if bold:
        candidates += [
            "C:/Windows/Fonts/arialbd.ttf",
            "C:/Windows/Fonts/ariblk.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        ]
    candidates += [
        "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()


def _ease_in_out(t: float) -> float:
    return t * t * (3 - 2 * t)


def _color_grade(frame: np.ndarray) -> np.ndarray:
    img = frame.astype(np.float32) / 255.0
    img = img * 0.90 + 0.04
    img[:, :, 0] = np.clip(img[:, :, 0] * 1.07, 0, 1)
    img[:, :, 1] = np.clip(img[:, :, 1] * 1.01, 0, 1)
    img[:, :, 2] = np.clip(img[:, :, 2] * 0.88, 0, 1)
    gray = np.mean(img, axis=2, keepdims=True)
    img = img * 0.83 + gray * 0.17
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


def _wrap_text(draw, text, font, max_width):
    words = text.split()
    lines, current = [], []
    for word in words:
        candidate = " ".join(current + [word])
        if draw.textbbox((0, 0), candidate, font=font)[2] <= max_width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return lines


def _render_shorts_frame(raw: np.ndarray, text: str, progress: float, show_hook: bool = False) -> np.ndarray:
    """Render a vertical Shorts frame with large centered captions."""
    frame = _color_grade(raw)
    img = Image.fromarray(frame).convert("RGBA")
    w, h = img.size

    # Strong bottom gradient for text area
    bar = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(bar)
    bar_h = int(h * 0.40)
    for y in range(bar_h):
        alpha = int(240 * (y / bar_h) ** 0.7)
        d.rectangle([0, h - bar_h + y, w, h - bar_h + y + 1], fill=(0, 0, 0, alpha))

    # Top gradient for channel name
    top_h = int(h * 0.12)
    for y in range(top_h):
        alpha = int(180 * (1 - y / top_h))
        d.rectangle([0, y, w, y + 1], fill=(0, 0, 0, alpha))

    img = Image.alpha_composite(img, bar).convert("RGB")
    draw = ImageDraw.Draw(img)

    # Channel name at top
    f_ch = _load_font(42, bold=True)
    ch_text = "DAILY MOTIVATION"
    bbox = draw.textbbox((0, 0), ch_text, font=f_ch)
    draw.text(((w - (bbox[2] - bbox[0])) // 2, 35), ch_text, font=f_ch, fill=(212, 175, 55))

    # Gold underline
    draw.rectangle([(w // 2 - 120, 90), (w // 2 + 120, 93)], fill=(212, 175, 55))

    # Caption text — large, centered, word highlighting
    font_size = max(52, int(h * 0.038))
    font = _load_font(font_size)
    font_bold = _load_font(font_size, bold=True)

    words = text.split()
    highlighted = max(1, int(len(words) * progress * 1.1))
    lines = _wrap_text(draw, text, font, w - 80)

    line_h = int(font_size * 1.5)
    total_h = len(lines) * line_h
    y_start = h - total_h - int(h * 0.06)

    word_idx = 0
    for line in lines:
        line_words = line.split()
        line_w = draw.textbbox((0, 0), line, font=font)[2]
        cur_x = (w - line_w) // 2

        for word in line_words:
            is_hi = word_idx < highlighted
            f = font_bold if is_hi else font
            color = (255, 245, 150) if is_hi else (190, 185, 170)
            draw.text((cur_x + 2, y_start + 2), word, font=f, fill=(0, 0, 0))
            draw.text((cur_x, y_start), word, font=f, fill=color)
            cur_x += draw.textbbox((0, 0), word + " ", font=f)[2]
            word_idx += 1

        y_start += line_h

    # "FULL VIDEO IN BIO" tag at very bottom
    f_tag = _load_font(32)
    tag = "Full video on channel"
    bbox = draw.textbbox((0, 0), tag, font=f_tag)
    draw.text(((w - (bbox[2] - bbox[0])) // 2, h - 55), tag, font=f_tag, fill=(150, 150, 150))

    return np.array(img)


def _make_shorts_scene(image_path: Path, text: str, duration: float) -> VideoClip:
    """Create one vertical Shorts scene with Ken Burns."""
    SCALE = 1.3
    # For vertical, we crop the landscape image to portrait
    src = Image.open(image_path).convert("RGB")
    src_w, src_h = src.size

    # Crop to 9:16 from center of landscape image
    target_ratio = SW / SH
    src_ratio = src_w / src_h

    if src_ratio > target_ratio:
        # Landscape image: crop width
        new_w = int(src_h * target_ratio)
        x_off = (src_w - new_w) // 2
        src = src.crop((x_off, 0, x_off + new_w, src_h))
    else:
        # Already portrait or square: crop height
        new_h = int(src_w / target_ratio)
        y_off = (src_h - new_h) // 2
        src = src.crop((0, y_off, src_w, y_off + new_h))

    src = src.resize((int(SW * SCALE), int(SH * SCALE)), Image.LANCZOS)
    s_w, s_h = src.size
    src_arr = np.array(src)

    zoom_in = random.choice([True, False])

    def make_frame(t: float) -> np.ndarray:
        p = _ease_in_out(t / duration)
        zoom = (1.0 + (SCALE - 1.0) * p) if zoom_in else (SCALE - (SCALE - 1.0) * p)
        cw, ch = int(SW / zoom), int(SH / zoom)
        x1 = max(0, min((s_w - cw) // 2, s_w - cw))
        y1 = max(0, min((s_h - ch) // 2, s_h - ch))
        cropped = src_arr[y1:y1 + ch, x1:x1 + cw]
        raw = np.array(Image.fromarray(cropped).resize((SW, SH), Image.LANCZOS))
        caption_p = max(0.0, (t / duration - 0.1) / 0.85)
        return _render_shorts_frame(raw, text, caption_p)

    return VideoClip(make_frame, duration=duration).set_fps(config.VIDEO_FPS)


def build_short(scenes: list, image_paths: list, audio_paths: list, output_dir: Path) -> Path:
    """
    Build a vertical Short from the best middle scenes.
    Returns path to the Short video file.
    """
    short_path = output_dir / "short_video.mp4"

    # Pick middle scenes (most impactful content, skip hook and outro)
    n = len(scenes)
    if n <= 3:
        indices = list(range(n))
    else:
        mid = n // 2
        indices = [mid - 1, mid, mid + 1]

    # Collect clips, stopping before MAX_DURATION
    clips = []
    total_dur = 0.0

    for i in indices:
        audio = AudioFileClip(str(audio_paths[i]))
        dur = min(audio.duration + 0.3, MAX_DURATION - total_dur)
        if dur < 3.0:
            audio.close()
            break

        clip = _make_shorts_scene(image_paths[i], scenes[i]["text"], dur)
        clip = clip.set_audio(audio.subclip(0, min(audio.duration, dur)))
        clip = clip.fadein(0.3).fadeout(0.3)
        clips.append(clip)
        total_dur += dur

        if total_dur >= MAX_DURATION:
            break

    if not clips:
        return None

    final = concatenate_videoclips(clips, method="compose")

    final.write_videofile(
        str(short_path),
        fps=config.VIDEO_FPS,
        codec="libx264",
        audio_codec="aac",
        temp_audiofile=str(output_dir / "temp_short_audio.m4a"),
        remove_temp=True,
        threads=4,
        preset="medium",
        ffmpeg_params=["-crf", "22"],
        logger=None,
    )

    for clip in clips:
        clip.close()
    final.close()

    return short_path
