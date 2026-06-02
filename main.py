"""
AI YouTube Channel Pipeline
─────────────────────────────────────────────────────────
Run once:    python main.py
Test run:    python main.py --dry-run   (skips upload, saves video locally)
"""
import json
import logging
import sys
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


def run_pipeline(dry_run: bool = False) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = Path("output") / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)

    log = _setup_logging(output_dir)
    log.info(f"Pipeline started  |  output: {output_dir}")

    # ── 1. Script ────────────────────────────────────────────────────────────
    log.info("[1/7] Generating script...")
    from generator import generate_script
    script = generate_script()
    (output_dir / "script.json").write_text(json.dumps(script, indent=2, ensure_ascii=False))
    log.info(f"      Title: {script['title']}")

    # ── 2. Background music ──────────────────────────────────────────────────
    log.info("[2/7] Fetching background music...")
    from music import get_music_path
    music_path = get_music_path()
    log.info(f"      Music: {music_path}")

    # ── 3. Images ────────────────────────────────────────────────────────────
    log.info("[3/7] Generating scene images...")
    from image_gen import generate_images
    image_paths = generate_images(script["scenes"], output_dir)
    log.info(f"      {len(image_paths)} images generated")

    # ── 4. Thumbnail ─────────────────────────────────────────────────────────
    log.info("[4/7] Generating thumbnail...")
    from thumbnail import generate_thumbnail
    thumb_path = generate_thumbnail(script["title"], output_dir)
    log.info(f"      Thumbnail: {thumb_path}")

    # ── 5. Audio ─────────────────────────────────────────────────────────────
    log.info("[5/7] Generating voiceover...")
    from tts import generate_audio
    audio_paths = generate_audio(script["scenes"], output_dir)
    log.info(f"      {len(audio_paths)} audio files generated")

    # ── 6. Video ─────────────────────────────────────────────────────────────
    log.info("[6/7] Assembling video...")
    from video_builder import build_video
    video_path = build_video(script["scenes"], image_paths, audio_paths, output_dir, music_path)
    log.info(f"      Video: {video_path}")

    if dry_run:
        log.info("[7/7] DRY RUN — upload skipped")
        log.info(f"      Done. Video saved to: {video_path}")
        return str(video_path)

    # ── 7. Upload ────────────────────────────────────────────────────────────
    log.info("[7/7] Uploading to YouTube...")
    from uploader import upload_video, upload_thumbnail
    video_id = upload_video(video_path, script["title"], script["description"], script["tags"])
    log.info(f"      Video live → https://youtube.com/watch?v={video_id}")

    try:
        upload_thumbnail(video_id, thumb_path)
        log.info("      Thumbnail uploaded")
    except Exception as e:
        log.warning(f"      Thumbnail upload skipped ({e})")

    return video_id


if __name__ == "__main__":
    run_pipeline(dry_run="--dry-run" in sys.argv)
