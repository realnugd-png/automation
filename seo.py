"""
SEO optimizer: chapters, keywords, titles, descriptions.
Chapters alone can boost watch time 20-40% by making videos feel structured.
"""
import random

POWER_WORDS = [
    "Brutal", "Raw", "Powerful", "Unstoppable", "Hidden", "Shocking",
    "Dangerous", "Real", "Dark", "Ruthless", "Uncomfortable", "Honest",
]

KEYWORD_CLUSTERS = {
    "motivation": ["daily motivation", "motivational video", "motivation speech", "morning motivation"],
    "mindset": ["mindset", "growth mindset", "winning mindset", "success mindset", "mental strength"],
    "success": ["success habits", "how to be successful", "keys to success", "success principles"],
    "self_improvement": ["self improvement", "personal development", "self discipline", "level up"],
    "inspiration": ["inspirational speech", "inspiration", "life changing", "life advice"],
}

HASHTAG_SETS = [
    "#motivation #mindset #success #dailymotivation #motivational #growthmindset #mentalstrength #inspiration #selfimprovement #nevergiveup",
    "#motivation #inspiration #mindset #personaldevelopment #selfdiscipline #success #motivationalquotes #positivethinking #hustle #grind",
    "#motivationaldaily #mindset #successhabits #growthmindset #levelup #selfgrowth #hustle #dailyinspiration #lifeadvice #powerful",
]

# Chapter titles matched to scene positions
CHAPTER_TEMPLATES = [
    ["The Wake-Up Call", "Why Most People Fail", "The Turning Point",
     "What You Must Understand", "The Hard Truth", "The Path Forward",
     "What Winners Do Differently", "Your Time Is Now"],
    ["The Hook", "The Problem", "The Agitation", "The Insight",
     "The Reframe", "The Method", "The Challenge", "The Close"],
    ["The Opening", "The Story Begins", "The Struggle", "The Discovery",
     "The Shift", "The Growth", "The Transformation", "Your Next Step"],
]


def build_chapters(audio_durations: list) -> str:
    """
    Build YouTube chapter timestamps from audio clip durations.
    audio_durations: list of float (seconds per scene audio)
    """
    # Account for intro clip (~3.5s)
    INTRO_DURATION = 3.5
    SCENE_PAUSE = 0.2
    FADE = 0.4

    templates = random.choice(CHAPTER_TEMPLATES)
    chapters = ["0:00 Introduction"]

    current_time = INTRO_DURATION
    for i, dur in enumerate(audio_durations):
        mins = int(current_time // 60)
        secs = int(current_time % 60)
        label = templates[i] if i < len(templates) else f"Part {i + 1}"
        chapters.append(f"{mins}:{secs:02d} {label}")
        current_time += dur + SCENE_PAUSE + FADE * 2

    return "\n".join(chapters)


def optimize_title(raw_title: str) -> str:
    title = raw_title.strip()
    if len(title) > 100:
        title = title[:97] + "..."
    return title


def optimize_description(raw_desc: str, title: str, chapters: str = "", video_format: str = "") -> str:
    lines = [l.strip() for l in raw_desc.strip().split("\n") if l.strip()]
    parts = []

    # First line — shown in search results (most important)
    first = lines[0] if lines else f"If you're ready to change your life — this is the video you need. {title}"
    if len(first) < 100:
        first += " Watch until the end."
    parts.append(first)
    parts.append("")

    # Second paragraph — value
    if len(lines) > 1:
        parts.append(lines[1])
    else:
        parts.append("Every day, we upload raw and real motivation to help you build the mindset of a champion. No fluff. No fake positivity. Just the truth.")
    parts.append("")

    # Chapters section — HUGE for watch time
    if chapters:
        parts.append("📌 CHAPTERS")
        parts.append(chapters)
        parts.append("")

    # Subscribe CTA
    parts.append("🔔 New video every 4 hours. Subscribe + turn on notifications so you never miss a video.")
    parts.append("")
    parts.append("─" * 40)
    parts.append("")

    # Hashtags
    parts.append(random.choice(HASHTAG_SETS))

    return "\n".join(parts)


def build_tags(script_tags: list) -> list:
    tags = set(t.lower().strip() for t in script_tags[:8])
    for cluster in random.sample(list(KEYWORD_CLUSTERS.values()), 3):
        for kw in cluster[:2]:
            tags.add(kw)
    core = ["daily motivation", "motivation", "mindset", "success", "inspiration",
            "self improvement", "motivational speech", "growth mindset",
            "positive thinking", "mental strength", "never give up", "hustle"]
    tags.update(core)
    return list(tags)[:15]


def optimize_script(script: dict, audio_durations: list = None) -> dict:
    script["title"] = optimize_title(script["title"])
    chapters = build_chapters(audio_durations) if audio_durations else ""
    script["description"] = optimize_description(
        script.get("description", ""),
        script["title"],
        chapters,
        script.get("format", ""),
    )
    script["tags"] = build_tags(script.get("tags", []))
    return script
