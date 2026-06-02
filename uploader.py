"""
YouTube upload via OAuth 2.0.
Handles both full videos and Shorts.
"""
import json
from pathlib import Path

import google.oauth2.credentials
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.http
from google.auth.transport.requests import Request

import config

SCOPES = ["https://www.googleapis.com/auth/youtube.upload",
          "https://www.googleapis.com/auth/youtube.force-ssl"]


def _get_service():
    token_path = Path(config.YOUTUBE_TOKEN_PATH)
    creds = None
    if token_path.exists():
        creds = google.oauth2.credentials.Credentials.from_authorized_user_info(
            json.loads(token_path.read_text()), SCOPES
        )
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = google_auth_oauthlib.flow.InstalledAppFlow.from_client_secrets_file(
                config.YOUTUBE_CLIENT_SECRETS_PATH, SCOPES
            )
            creds = flow.run_local_server(port=0)
        token_path.write_text(creds.to_json())
    return googleapiclient.discovery.build("youtube", "v3", credentials=creds)


def _upload(video_path: Path, title: str, description: str, tags: list,
            category: str = "26", is_short: bool = False) -> str:
    service = _get_service()

    if is_short:
        # Shorts: add #Shorts to title and description
        if "#Shorts" not in title:
            title = title[:90] + " #Shorts"
        if "#Shorts" not in description:
            description = "#Shorts\n\n" + description

    body = {
        "snippet": {
            "title": title[:100],
            "description": description[:5000],
            "tags": (tags + ["shorts", "#shorts"])[:15] if is_short else tags[:15],
            "categoryId": category,
            "defaultLanguage": "en",
        },
        "status": {
            "privacyStatus": config.UPLOAD_PRIVACY,
            "selfDeclaredMadeForKids": False,
        },
    }

    media = googleapiclient.http.MediaFileUpload(
        str(video_path), mimetype="video/mp4",
        chunksize=4 * 1024 * 1024, resumable=True,
    )
    request = service.videos().insert(
        part=",".join(body.keys()), body=body, media_body=media,
    )
    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            print(f"\r  Upload: {int(status.progress() * 100)}%", end="", flush=True)
    print()
    return response["id"]


def upload_video(video_path: Path, title: str, description: str, tags: list) -> str:
    return _upload(video_path, title, description, tags, is_short=False)


def upload_short(short_path: Path, title: str, description: str, tags: list) -> str:
    short_title = title.replace(" #Shorts", "").strip()
    # Make Short title snappier
    words = short_title.split()
    if len(words) > 6:
        short_title = " ".join(words[:6]) + "..."
    return _upload(short_path, short_title, description, tags, is_short=True)


def upload_thumbnail(video_id: str, thumb_path: Path) -> None:
    service = _get_service()
    service.thumbnails().set(
        videoId=video_id,
        media_body=googleapiclient.http.MediaFileUpload(str(thumb_path), mimetype="image/jpeg"),
    ).execute()


def add_end_screen(video_id: str, channel_id: str = None) -> None:
    """
    Add end screen elements to a video.
    Adds 'Subscribe' button + 'Best for viewer' video recommendation.
    Requires video to be at least 25 seconds long.
    """
    service = _get_service()
    try:
        # End screen starts at video_duration - 20 seconds
        # We use a relative offset approach
        body = {
            "videoId": video_id,
            "items": [
                {
                    "type": "subscribe",
                    "offsetMs": 0,  # Will be set to last 20s by YouTube
                    "durationMs": 20000,
                    "position": {
                        "type": "corner",
                        "cornerPosition": "bottomRight"
                    }
                },
                {
                    "type": "video",
                    "offsetMs": 0,
                    "durationMs": 20000,
                    "videoId": "best_for_viewer",
                    "position": {
                        "type": "corner",
                        "cornerPosition": "bottomLeft"
                    }
                }
            ]
        }
        service.videoEndscreens().insert(part="items", body=body).execute()
    except Exception as e:
        # End screens API may not be available for all channels
        print(f"  End screen skipped: {e}")
