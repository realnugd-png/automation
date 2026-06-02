"""
YouTube upload via OAuth 2.0.
First run opens a browser to authenticate; token is cached in token.json.
"""
import json
from pathlib import Path

import google.oauth2.credentials
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.http
from google.auth.transport.requests import Request

import config

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]


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


def upload_video(video_path: Path, title: str, description: str, tags: list) -> str:
    """Upload video to YouTube. Returns the new video ID."""
    service = _get_service()

    body = {
        "snippet": {
            "title": title[:100],
            "description": description[:5000],
            "tags": tags[:15],
            "categoryId": "26",
            "defaultLanguage": "en",
        },
        "status": {
            "privacyStatus": config.UPLOAD_PRIVACY,
            "selfDeclaredMadeForKids": False,
        },
    }

    media = googleapiclient.http.MediaFileUpload(
        str(video_path),
        mimetype="video/mp4",
        chunksize=4 * 1024 * 1024,
        resumable=True,
    )

    request = service.videos().insert(
        part=",".join(body.keys()),
        body=body,
        media_body=media,
    )

    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            print(f"\rUpload: {int(status.progress() * 100)}%", end="", flush=True)
    print()

    return response["id"]


def upload_thumbnail(video_id: str, thumb_path: Path) -> None:
    """Upload a custom thumbnail. Requires channel verification on YouTube."""
    service = _get_service()
    service.thumbnails().set(
        videoId=video_id,
        media_body=googleapiclient.http.MediaFileUpload(str(thumb_path), mimetype="image/jpeg"),
    ).execute()
