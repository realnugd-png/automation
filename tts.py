"""
Text-to-speech via Edge TTS — Microsoft neural voices, completely free, no API key needed.
Quality is excellent (same engine as Microsoft Edge's Read Aloud feature).
"""
import asyncio
from pathlib import Path

import edge_tts
import config


async def _speak(text: str, voice: str, output_path: Path) -> None:
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(str(output_path))


def generate_audio(scenes: list, output_dir: Path) -> list:
    """Generate TTS audio for each scene. Returns list of mp3 Paths."""
    paths = []
    for i, scene in enumerate(scenes):
        path = output_dir / f"audio_{i:02d}.mp3"
        asyncio.run(_speak(scene["text"], config.TTS_VOICE, path))
        paths.append(path)
    return paths
