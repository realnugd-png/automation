"""
AI YouTube Channel Pipeline — Full + Shorts
─────────────────────────────────────────────────────────
Run once:    python main.py
Test run:    python main.py --dry-run
"""
import json
import logging
import sys
import time
from datetime import datetime
from pathlib import Path


def _setup_logging(output_dir: Path) -> logging.Logger:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(levelname)-8s  %(message)s",
        handlers=[
            logging.FileHandler(output_dir / "pipeline.log"),
            logging.StreamHandler(sys.stdout),
        ],
    )
    return logging.getLogger("pipeline")


def _retry(fn, retries=3, delay=5.0, label=""):
    for attempt in range(retries):
        try:
            return fn()
        except Exception as e:
            if attempt == retries - 1:
                raise
            wait = delay * (attempt + 1)
            print(f"  [{label}] attempt {attempt + 1} failed: {e}. Retrying in {wait:.0f}s...")
            time.sleep(wait)


def run_pipeline(dry_run: bool = False) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = Path("output") / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)

    log = _setup_logging(output_dir)
    log.info(f"Pipeline started  |  output: {output_dir}")

    # ── 1. Script ────────────────────────────────────────────────────────────
    log.info("[1/8] Generating script...")
    from generator import generate_script
    script = _retry(generate_script, retries=3, delay=5, label="script")
    (output_dir / "script.json").write_text(
        json.dumps(script, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    log.info(f"      Format: {script.get('format','unknown')} | Title: {script['title']}")

    # ── 2. Music ─────────────────────────────────────────────────────────────
    log.info("[2/8] Fetching background music...")
    from music import get_music_path
    music_path = _retry(get_music_path, retries=2, delay=3, label="music")
    log.info(f"      Music: {music_path}")

    # ── 3. Scene images ──────────────────────────────────────────────────────
    log.info("[3/8] Generating scene images...")
    from image_gen import generate_images
    image_paths = _retry(
        lambda: generate_images(script["scenes"], output_dir),
        retries=2, delay=10, label="images"
    )
    log.info(f"      {len(image_paths)} images generated")

    # ── 4. Thumbnail ─────────────────────────────────────────────────────────
    log.info("[4/8] Generating thumbnail...")
    from thumbnail import generate_thumbnail
    thumb_path = _retry(
        lambda: generate_thumbnail(script["title"], output_dir, script.get("format", "")),
        retries=2, delay=10, label="thumbnail"
    )
    log.info(f"      Thumbnail: {thumb_path}")

    # ── 5. Voiceover ─────────────────────────────────────────────────────────
    log.info("[5/8] Generating voiceover...")
    from tts import generate_audio
    from moviepy.editor import AudioFileClip
    audio_paths = _retry(
        lambda: generate_audio(script["scenes"], output_dir),
        retries=2, delay=5, label="tts"
    )
    # Get audio durations for chapter timestamps
    audio_durations = []
    for ap in audio_paths:
        try:
            a = AudioFileClip(str(ap))
            audio_durations.append(a.duration)
            a.close()
        except Exception:
            audio_durations.append(15.0)

    log.info(f"      {len(audio_paths)} audio files generated")

    # ── 6. SEO optimize with chapters ────────────────────────────────────────
    log.info("[6/8] Applying SEO optimization...")
    from seo import optimize_script
    script = optimize_script(script, audio_durations)
    log.info(f"      Chapters added, tags optimized")

    # ── 7. Video assembly ────────────────────────────────────────────────────
    log.info("[7/8] Assembling full video + Short...")
    from video_builder import build_video
    from shorts_builder import build_short

    video_path = build_video(
        script["scenes"], image_paths, audio_paths, output_dir, music_path
    )
    log.info(f"      Full video: {video_path}")

    short_path = None
    try:
        short_path = build_short(script["scenes"], image_paths, audio_paths, output_dir)
        log.info(f"      Short: {short_path}")
    except Exception as e:
        log.warning(f"      Short skipped: {e}")

    if dry_run:
        log.info("[8/8] DRY RUN — upload skipped")
        log.info(f"      Full video: {video_path}")
        if short_path:
            log.info(f"      Short: {short_path}")
        return str(video_path)

    # ── 8. Upload ────────────────────────────────────────────────────────────
    log.info("[8/8] Uploading to YouTube...")
    from uploader import upload_video, upload_short, upload_thumbnail, add_end_screen
    from analytics import log_upload

    video_id = _retry(
        lambda: upload_video(video_path, script["title"], script["description"], script["tags"]),
        retries=2, delay=15, label="upload"
    )
    log.info(f"      Full video live: https://youtube.com/watch?v={video_id}")

    try:
        upload_thumbnail(video_id, thumb_path)
        log.info("      Thumbnail uploaded")
    except Exception as e:
        log.warning(f"      Thumbnail skipped: {e}")

    try:
        add_end_screen(video_id)
        log.info("      End screen added")
    except Exception as e:
        log.warning(f"      End screen skipped: {e}")

    if short_path and short_path.exists():
        try:
            short_id = _retry(
                lambda: upload_short(short_path, script["title"], script["description"], script["tags"]),
                retries=2, delay=10, label="short-upload"
            )
            log.info(f"      Short live: https://youtube.com/shorts/{short_id}")
        except Exception as e:
            log.warning(f"      Short upload skipped: {e}")

    log_upload(video_id, script, video_path, thumb_path)
    return video_id


if __name__ == "__main__":
    run_pipeline(dry_run="--dry-run" in sys.argv)
