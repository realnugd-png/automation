"""
Script generation using Groq (free tier — Llama 3.3 70B).
Get a free key at https://console.groq.com → API Keys
"""
import json
from groq import Groq
import config

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = Groq(api_key=config.GROQ_API_KEY)
    return _client


def generate_script() -> dict:
    """Use Groq/Llama to generate a complete video script."""
    client = _get_client()

    prompt = f"""Create a compelling {config.CHANNEL_NICHE} YouTube video script.

Split it into exactly {config.NUM_SCENES} scenes. Each scene should take ~20 seconds when spoken aloud.

Return ONLY a valid JSON object — no markdown fences, no extra text:
{{
  "title": "YouTube title — engaging, max 80 chars",
  "description": "YouTube description — 2-3 paragraphs with value, then a blank line, then hashtags",
  "tags": ["tag1", "tag2"],
  "scenes": [
    {{
      "text": "Narration for this scene — 2-4 powerful sentences",
      "image_prompt": "Detailed image generation prompt. Style: cinematic, golden hour lighting, photorealistic, 8k, emotional atmosphere. No text or words in the image."
    }}
  ]
}}

Script arc: hook → story build → insight climax → empowering close
Tags: 12-15 relevant motivational keywords
Image prompts: vivid, specific — each should feel like a movie still"""

    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=2048,
        temperature=0.8,
    )

    raw = response.choices[0].message.content.strip()

    # Strip markdown fences if present
    if raw.startswith("```"):
        parts = raw.split("```")
        raw = parts[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    # Extract the JSON object boundaries
    start = raw.find("{")
    end = raw.rfind("}") + 1
    raw = raw[start:end]

    # Fix literal control characters inside JSON string values (Llama quirk)
    cleaned = []
    in_string = False
    i = 0
    while i < len(raw):
        c = raw[i]
        if c == "\\" and in_string:
            cleaned.append(c)
            i += 1
            if i < len(raw):
                cleaned.append(raw[i])
            i += 1
            continue
        if c == '"':
            in_string = not in_string
        if in_string and ord(c) < 0x20:
            cleaned.append(" ")
        else:
            cleaned.append(c)
        i += 1
    raw = "".join(cleaned)

    script = json.loads(raw)

    assert "title" in script, "Missing title"
    assert "description" in script, "Missing description"
    assert "tags" in script, "Missing tags"
    assert len(script["scenes"]) == config.NUM_SCENES, (
        f"Expected {config.NUM_SCENES} scenes, got {len(script['scenes'])}"
    )

    return script
