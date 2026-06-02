"""
Script generation using Groq (Llama 3.3 70B).
Modeled after top viral motivational channels: Motiversity, Fearless Motivation, Ben Lionel Scott.
"""
import json
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
    if "```" in raw:
        parts = raw.split("```")
        raw = parts[1] if len(parts) > 1 else raw
        if raw.startswith("json"):
            raw = raw[4:]
    start = raw.find("{")
    end = raw.rfind("}") + 1
    if start >= 0 and end > start:
        raw = raw[start:end]
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
    return f"""You are the head scriptwriter for Motiversity — the most-watched motivational channel on YouTube with 10 million subscribers.

Today's format: {fmt['name']}
Topic: {fmt['niche']}
Hook style: {fmt['hook_style']}

FRAMEWORK:
{fmt['framework_instructions']}

VIRAL DNA — how the best channels write:
{fmt['viral_dna']}

IMAGE STYLE FOR THIS VIDEO:
{fmt['image_style']}

SCRIPT RULES:
1. Scene 1 MUST hook in under 4 words or with one punch-to-the-gut question. No intro. No warmup.
2. Each scene: 2-5 sentences. Short. Sharp. Rhythm matters. Read it out loud — it must FEEL right.
3. Vary sentence length within each scene. Short sentences for impact. Longer ones to build.
4. Use repetition and rhythm: "You have to want it. You have to chase it. You have to EARN it."
5. Language: raw, real, visceral. Words that make people feel something in their chest.
6. NO generic advice. No "stay positive." Say things people haven't heard before.
7. Scene {config.NUM_SCENES} must END the video perfectly — a line they'll remember for days.

IMAGE PROMPT RULES:
- Every image prompt must look like a shot from a $50M Hollywood film or Nike ad
- Specify: lighting, atmosphere, camera angle, cinematic style, color grade
- Include: "photorealistic", "8K", "cinematic", "shot on ARRI" or "shot on RED"
- NO generic landscapes. Every image must be SPECIFIC and VISCERAL
- Match the emotional tone of that scene exactly

Generate exactly {config.NUM_SCENES} scenes. Return ONLY this JSON:
{{
  "title": "YouTube title — bold, specific, 50-65 chars, front-loaded keyword",
  "description": "First line hooks hard (this shows in search). Second paragraph explains the value. Third paragraph: new video every 4 hours, subscribe + notifications.\\n\\n#motivation #mindset #success #dailymotivation #motivational #growthmindset #successmindset #mentalstrength #inspiration #selfimprovement",
  "tags": ["daily motivation", "motivation", "mindset", "success", "inspiration", "self improvement", "motivational speech", "growth mindset", "mental strength", "positive thinking", "motivational video", "life advice", "never give up", "hustle", "grind"],
  "format": "{fmt['name']}",
  "scenes": [
    {{
      "text": "The narration. Raw. Punchy. Real.",
      "image_prompt": "Hyper-specific cinematic image prompt. Shot description. Lighting. Atmosphere. Color grade. Technical specs."
    }}
  ]
}}"""


def generate_script(retries: int = 3) -> dict:
    client = _get_client()
    fmt = get_todays_format()

    for attempt in range(retries):
        try:
            response = client.chat.completions.create(
                model="llama-3.3-70b-versatile",
                messages=[{"role": "user", "content": _build_prompt(fmt)}],
                max_tokens=3000,
                temperature=0.9,
            )
            raw = _clean_json(response.choices[0].message.content)
            script = json.loads(raw)

            assert "title" in script
            assert "scenes" in script
            assert len(script["scenes"]) == config.NUM_SCENES

            if isinstance(script.get("tags"), str):
                script["tags"] = [t.strip() for t in script["tags"].split(",")]

            script["format"] = fmt["name"]
            return script

        except Exception as e:
            if attempt == retries - 1:
                raise RuntimeError(f"Script generation failed: {e}")
            print(f"  Attempt {attempt + 1} failed ({e}), retrying...")

    raise RuntimeError("Script generation failed")
