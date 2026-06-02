import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# Free: get key at https://aistudio.google.com
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")

YOUTUBE_CLIENT_SECRETS_PATH = os.getenv("YOUTUBE_CLIENT_SECRETS_PATH", "client_secrets.json")
YOUTUBE_TOKEN_PATH = os.getenv("YOUTUBE_TOKEN_PATH", "token.json")
UPLOAD_PRIVACY = os.getenv("UPLOAD_PRIVACY", "public")

CHANNEL_NICHE = os.getenv("CHANNEL_NICHE", "motivational and inspirational")
NUM_SCENES = int(os.getenv("NUM_SCENES", "5"))

VIDEO_WIDTH = 1920
VIDEO_HEIGHT = 1080
VIDEO_FPS = 24
SCENE_PAUSE_SECONDS = 0.5

# Free Microsoft neural voice — no account needed
TTS_VOICE = os.getenv("TTS_VOICE", "en-US-AriaNeural")

BACKGROUND_MUSIC_PATH = os.getenv("BACKGROUND_MUSIC_PATH", "")
MUSIC_VOLUME = float(os.getenv("MUSIC_VOLUME", "0.12"))

DAILY_UPLOAD_TIME = os.getenv("DAILY_UPLOAD_TIME", "09:00")

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)
