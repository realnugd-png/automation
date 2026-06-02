import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

YOUTUBE_CLIENT_SECRETS_PATH = os.getenv("YOUTUBE_CLIENT_SECRETS_PATH", "client_secrets.json")
YOUTUBE_TOKEN_PATH = os.getenv("YOUTUBE_TOKEN_PATH", "token.json")
UPLOAD_PRIVACY = os.getenv("UPLOAD_PRIVACY", "public")

CHANNEL_NICHE = os.getenv("CHANNEL_NICHE", "motivational and inspirational")
NUM_SCENES = int(os.getenv("NUM_SCENES", "8"))  # More scenes = faster pacing = more viral

VIDEO_WIDTH = 1920
VIDEO_HEIGHT = 1080
VIDEO_FPS = 24
SCENE_PAUSE_SECONDS = 0.2  # Tight cuts, no dead air

# "onyx" = deep authoritative male voice (like viral motivation channels)
# Alternatives: "echo" (male), "fable" (British male), "nova" (female)
TTS_VOICE = os.getenv("TTS_VOICE", "en-US-GuyNeural")

BACKGROUND_MUSIC_PATH = os.getenv("BACKGROUND_MUSIC_PATH", "")
MUSIC_VOLUME = float(os.getenv("MUSIC_VOLUME", "0.18"))  # Slightly louder for impact

DAILY_UPLOAD_TIME = os.getenv("DAILY_UPLOAD_TIME", "09:00")

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)
