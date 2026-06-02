"""
Script generation using Groq (Llama 3.3 70B).
Uses day-specific content formats and professional copywriting frameworks.
"""
import json
import re
from groq import Groq
import config
from content_strategy import get_todays_format

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = Groq(api_key=config.GROQ_API_KEY)
    return _client


def _clean_json(raw: str) -> str:
    """Extract and clean JSON from model output."""
    # Strip markdown fences
    if "```" in raw:
        parts = raw.split("```")
        raw = parts[1] if len(parts) > 1 else raw
        if raw.startswith("json"):
            raw = raw[4:]

    # Extract JSON object boundaries
    start = raw.find("{")
    end = raw.rfind("}") + 1
    if start >= 0 and end > start:
        raw = raw[start:end]

    # Fix literal control characters inside JSON strings
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

    return "".join(cleaned).strip()


def _build_prompt(fmt: dict) -> str:
    """Build a highly optimized generation prompt."""
    return f"""You are a world-class YouTube scriptwriter for a viral motivational channel.
Today's format: {fmt['name']} ({fmt['framework']} framework)
Topic: {fmt['niche']}
Hook style: {fmt['hook_style']}

FRAMEWORK TO FOLLOW:
{fmt['framework_instructions']}

CRITICAL RULES:
- First sentence of scene 1 MUST hook within 3 seconds — no slow builds
- Each scene: 2-4 punchy sentences (15-20 seconds when spoken)
- Language: simple, powerful, direct — no corporate fluff
- Speak directly to "you" — personal and visceral
- Vary sentence length: short punches mixed with longer flowing lines
- End scene 5 with energy, not a generic "subscribe" request

SEO RULES for title:
- Include a number OR a power word (Powerful, Brutal, Raw, Unstoppable, Hidden)
- 50-65 characters ideal
- Front-load the main keyword

Generate exactly {config.NUM_SCENES} scenes. Return ONLY this JSON (no markdown, no extra text):
{{
  "title": "SEO-optimized YouTube title (50-65 chars)",
  "description": "YouTube description paragraph 1 (hook + value)\\n\\nParagraph 2 (what they learn)\\n\\nParagraph 3 (subscribe CTA + upload schedule)\\n\\n#motivation #mindset #success #inspiration #selfimprovement #dailymotivation #motivational #mindsetshift #growthmindset #successmindset",
  "tags": ["daily motivation", "motivation", "mindset", "success", "inspiration", "self improvement", "motivational speech", "growth mindset", "positive thinking", "mental strength", "confidence", "success habits", "life advice", "mindset shift", "motivational video"],
  "format": "{fmt['name']}",
  "scenes": [
    {{
      "text": "Scene narration — punchy, emotional, direct",
      "image_prompt": "Cinematic photorealistic scene. {fmt['image_style']}. Golden hour or dramatic lighting. 8K quality. No text, no words in the image. Emotional and visually striking."
    }}
  ]
}}"""


def generate_script(retries: int = 3) -> dict:
    """Generate a complete video script using today's content format."""
    client = _get_client()
    fmt = get_todays_format()

    for attempt in range(retries):
        try:
            response = client.chat.completions.create(
                model="llama-3.3-70b-versatile",
                messages=[{"role": "user", "content": _build_prompt(fmt)}],
                max_tokens=2048,
                temperature=0.85,
            )

            raw = response.choices[0].message.content
            raw = _clean_json(raw)
            script = json.loads(raw)

            assert "title" in script, "Missing title"
            assert "description" in script, "Missing description"
            assert "tags" in script, "Missing tags"
            assert len(script["scenes"]) == config.NUM_SCENES, (
                f"Expected {config.NUM_SCENES} scenes, got {len(script['scenes'])}"
            )

            # Ensure tags is a list of strings
            if isinstance(script["tags"], str):
                script["tags"] = [t.strip() for t in script["tags"].split(",")]

            script["format"] = fmt["name"]
            return script

        except (json.JSONDecodeError, AssertionError) as e:
            if attempt == retries - 1:
                raise RuntimeError(f"Script generation failed after {retries} attempts: {e}")
            print(f"  Attempt {attempt + 1} failed ({e}), retrying...")

    raise RuntimeError("Script generation failed")
