"""
Video assembler:
- Ken Burns zoom/pan with smooth easing per scene
- Cinematic warm color grade + edge vignette
- Word-by-word caption highlighting for engagement
- Branded intro (3.5s) and outro (5.5s)
- Optional background music with auto-fade
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

CHANNEL_NAME = "Daily Motivation"
CHANNEL_TAGLINE = "Fuel your mind. Every single day."


# ---------------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------------

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


def _wrap_text(draw, text, font, max_width):
    words = text.split()
    lines, current = [], []
    for word in words:
        candidate = " ".join(current + [word])
        w = draw.textbbox((0, 0), candidate, font=font)[2]
        if w <= max_width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return lines


# ---------------------------------------------------------------------------
# Visual effects
# ---------------------------------------------------------------------------

def _ease_in_out(t: float) -> float:
    return t * t * (3 - 2 * t)


def _ease_out_cubic(t: float) -> float:
    return 1 - (1 - t) ** 3


def _color_grade(frame: np.ndarray) -> np.ndarray:
    """Warm cinematic grade: lifted blacks, golden highlights, subtle desaturation."""
    img = frame.astype(np.float32) / 255.0
    img = img * 0.90 + 0.04
    img[:, :, 0] = np.clip(img[:, :, 0] * 1.07, 0, 1)
    img[:, :, 1] = np.clip(img[:, :, 1] * 1.01, 0, 1)
    img[:, :, 2] = np.clip(img[:, :, 2] * 0.88, 0, 1)
    gray = np.mean(img, axis=2, keepdims=True)
    img = img * 0.83 + gray * 0.17
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


_vignette_cache: dict = {}

def _add_vignette(frame: np.ndarray) -> np.ndarray:
    h, w = frame.shape[:2]
    if (h, w) not in _vignette_cache:
        Y, X = np.ogrid[:h, :w]
        dist = np.sqrt(((X - w / 2) / (w / 2)) ** 2 + ((Y - h / 2) / (h / 2)) ** 2)
        mask = np.clip(1.0 - (dist - 0.52) * 0.75, 0.50, 1.0)
        _vignette_cache[(h, w)] = mask[:, :, np.newaxis]
    return (frame * _vignette_cache[(h, w)]).astype(np.uint8)


# ---------------------------------------------------------------------------
# Caption rendering with word highlighting
# ---------------------------------------------------------------------------

def _render_caption(frame: np.ndarray, text: str, progress: float = 1.0) -> np.ndarray:
    """
    Render captions with progressive word highlighting.
    Words light up one by one as the narration progresses.
    progress: 0.0 → 1.0 = fraction of audio elapsed
    """
    img = Image.fromarray(frame).convert("RGBA")
    w, h = img.size

    # Gradient bar
    bar = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(bar)
    bar_h = int(h * 0.32)
    for y in range(bar_h):
        alpha = int(230 * (y / bar_h) ** 0.8)
        d.rectangle([0, h - bar_h + y, w, h - bar_h + y + 1], fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img, bar).convert("RGB")
    draw = ImageDraw.Draw(img)

    font_size = max(38, int(h * 0.044))
    font = _load_font(font_size)
    font_bold = _load_font(font_size, bold=True)

    padding = int(w * 0.06)
    words = text.split()
    highlighted_count = max(1, int(len(words) * progress * 1.1))

    # Build lines
    lines = _wrap_text(draw, text, font, w - 2 * padding)
    line_h = int(font_size * 1.45)
    total_h = len(lines) * line_h
    y_start = h - total_h - int(h * 0.045)

    word_idx = 0
    for line in lines:
        line_words = line.split()
        # Calculate x position for each word
        x = padding
        line_w = draw.textbbox((0, 0), line, font=font)[2]
        x = (w - line_w) // 2  # center align

        # Draw word by word
        cur_x = x
        for wi, word in enumerate(line_words):
            is_highlighted = word_idx < highlighted_count
            f = font_bold if is_highlighted else font
            color = (255, 245, 180) if is_highlighted else (180, 175, 160)  # warm white vs dim

            # Shadow
            draw.text((cur_x + 2, y_start + 2), word, font=f, fill=(0, 0, 0))
            draw.text((cur_x, y_start), word, font=f, fill=color)

            word_w = draw.textbbox((0, 0), word + " ", font=f)[2]
            cur_x += word_w
            word_idx += 1

        y_start += line_h

    return np.array(img)


# ---------------------------------------------------------------------------
# Ken Burns clip with caption highlighting
# ---------------------------------------------------------------------------

def _ken_burns_clip(image_path: Path, text: str, duration: float) -> VideoClip:
    fps = config.VIDEO_FPS
    W, H = config.VIDEO_WIDTH, config.VIDEO_HEIGHT
    SCALE = 1.25

    src = Image.open(image_path).convert("RGB").resize(
        (int(W * SCALE), int(H * SCALE)), Image.LANCZOS
    )
    src_w, src_h = src.size
    src_arr = np.array(src)

    zoom_in = random.choice([True, False])
    drift_sign = random.choice([-1, 1])

    def make_frame(t: float) -> np.ndarray:
        progress = _ease_in_out(t / duration)
        zoom = (1.0 + (SCALE - 1.0) * progress) if zoom_in else (SCALE - (SCALE - 1.0) * progress)

        cw, ch = int(W / zoom), int(H / zoom)
        drift = int(src_w * 0.08 * progress * drift_sign)
        x1 = max(0, min(src_w // 2 + drift - cw // 2, src_w - cw))
        y1 = max(0, min(src_h // 2 - ch // 2, src_h - ch))

        cropped = src_arr[y1:y1 + ch, x1:x1 + cw]
        raw = np.array(Image.fromarray(cropped).resize((W, H), Image.LANCZOS))

        # Word highlight progress (start highlighting at 10% into scene)
        caption_progress = max(0.0, (t / duration - 0.1) / 0.85)

        frame = _color_grade(raw)
        frame = _add_vignette(frame)
        return _render_caption(frame, text, caption_progress)

    return VideoClip(make_frame, duration=duration).set_fps(fps)


# ---------------------------------------------------------------------------
# Intro / Outro
# ---------------------------------------------------------------------------

def _make_intro_clip(duration: float = 3.5) -> VideoClip:
    W, H = config.VIDEO_WIDTH, config.VIDEO_HEIGHT

    def make_frame(t: float) -> np.ndarray:
        a = _ease_in_out(min(t / 1.4, 1.0))
        slide = _ease_out_cubic(min(t / 1.0, 1.0))

        img = Image.new("RGB", (W, H), (4, 4, 4))
        draw = ImageDraw.Draw(img)

        # Animated gold line expanding from center
        lw = int(W * 0.30 * a)
        draw.rectangle([(W // 2 - lw // 2, H // 2 - 80), (W // 2 + lw // 2, H // 2 - 77)],
                       fill=(212, 175, 55))

        # Channel name slides in from right
        f1 = _load_font(92, bold=True)
        c = int(255 * a)
        offset_x = int((1 - slide) * 80)
        bbox = draw.textbbox((0, 0), CHANNEL_NAME, font=f1)
        x = (W - (bbox[2] - bbox[0])) // 2 + offset_x
        draw.text((x + 2, H // 2 - 46), CHANNEL_NAME, font=f1, fill=(0, 0, 0))
        draw.text((x, H // 2 - 48), CHANNEL_NAME, font=f1, fill=(c, c, int(c * 0.92)))

        draw.rectangle([(W // 2 - lw // 2, H // 2 + 58), (W // 2 + lw // 2, H // 2 + 61)],
                       fill=(212, 175, 55))

        f2 = _load_font(34)
        c2 = int(185 * a)
        bbox2 = draw.textbbox((0, 0), CHANNEL_TAGLINE, font=f2)
        x2 = (W - (bbox2[2] - bbox2[0])) // 2
        draw.text((x2, H // 2 + 78), CHANNEL_TAGLINE, font=f2, fill=(c2, c2, c2))

        return np.array(img)

    return VideoClip(make_frame, duration=duration).set_fps(config.VIDEO_FPS).fadein(0.3).fadeout(0.4)


def _make_outro_clip(duration: float = 5.5) -> VideoClip:
    W, H = config.VIDEO_WIDTH, config.VIDEO_HEIGHT

    def make_frame(t: float) -> np.ndarray:
        a = _ease_in_out(min(t / 1.0, 1.0))
        c = int(255 * a)

        img = Image.new("RGB", (W, H), (4, 4, 4))
        draw = ImageDraw.Draw(img)

        def centered(text, font, y, fill):
            bbox = draw.textbbox((0, 0), text, font=font)
            x = (W - (bbox[2] - bbox[0])) // 2
            draw.text((x, y), text, font=font, fill=fill)

        f_big = _load_font(74, bold=True)
        f_med = _load_font(44)
        f_sm = _load_font(30)
        f_ch = _load_font(26)

        centered("Subscribe for daily motivation", f_big, H // 2 - 130, (c, c, c))

        lw = int(W * 0.22 * a)
        draw.rectangle([(W // 2 - lw // 2, H // 2 - 24), (W // 2 + lw // 2, H // 2 - 21)],
                       fill=(212, 175, int(55 * a)))

        centered("Turn on notifications", f_med, H // 2 + 8, (c, int(c * 0.82), 0))
        centered("Like this video if it inspired you", f_sm, H // 2 + 88,
                 (int(c * 0.6), int(c * 0.6), int(c * 0.6)))
        centered(CHANNEL_NAME, f_ch, H - 72, (80, 80, 80))

        return np.array(img)

    return VideoClip(make_frame, duration=duration).set_fps(config.VIDEO_FPS).fadein(0.3).fadeout(0.6)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def build_video(
    scenes: list,
    image_paths: list,
    audio_paths: list,
    output_dir: Path,
    music_path: str = "",
) -> Path:
    video_path = output_dir / "final_video.mp4"

    scene_clips = []
    for scene, img_path, aud_path in zip(scenes, image_paths, audio_paths):
        audio = AudioFileClip(str(aud_path))
        duration = audio.duration + config.SCENE_PAUSE_SECONDS
        clip = _ken_burns_clip(img_path, scene["text"], duration)
        clip = clip.set_audio(audio).fadein(0.4).fadeout(0.4)
        scene_clips.append(clip)

    intro = _make_intro_clip()
    outro = _make_outro_clip()
    final = concatenate_videoclips([intro] + scene_clips + [outro], method="compose")

    # Background music
    mp = music_path or config.BACKGROUND_MUSIC_PATH
    if mp and Path(mp).exists():
        music = AudioFileClip(mp).volumex(config.MUSIC_VOLUME)
        if music.duration < final.duration:
            loops = int(final.duration / music.duration) + 1
            music = concatenate_audioclips([music] * loops)
        music = music.subclip(0, final.duration).audio_fadeout(2.5)
        final = final.set_audio(CompositeAudioClip([final.audio, music]))

    final.write_videofile(
        str(video_path),
        fps=config.VIDEO_FPS,
        codec="libx264",
        audio_codec="aac",
        temp_audiofile=str(output_dir / "temp_audio.m4a"),
        remove_temp=True,
        threads=4,
        preset="medium",
        ffmpeg_params=["-crf", "21"],
        logger=None,
    )

    for clip in scene_clips:
        clip.close()
    intro.close()
    outro.close()
    final.close()

    return video_path
