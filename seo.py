"""
SEO optimizer: enhances titles, descriptions, and tags for maximum discoverability.
Uses proven YouTube SEO patterns without paid APIs.
"""
import re
import random

# High-performing title patterns for motivational content
POWER_WORDS = [
    "Brutal", "Raw", "Powerful", "Unstoppable", "Hidden", "Shocking",
    "Dangerous", "Secret", "Real", "Dark", "Ultimate", "Rare",
    "Uncomfortable", "Honest", "Hard", "Proven", "Ruthless",
]

TITLE_PATTERNS = [
    "The {power} Truth About {topic}",
    "{number} {power} Lessons About {topic} Nobody Tells You",
    "Why {topic} Is Not What You Think",
    "This Is Why You're {problem} (And How To Fix It)",
    "The {power} Secret To {outcome} Nobody Talks About",
    "{number} Signs You Have a {trait} Mindset",
    "Stop {bad_habit}. Start {good_habit}.",
    "The {power} Truth Most People Never Learn About Success",
    "If You Feel Lost, Watch This",
    "This Will Change How You Think About {topic}",
    "You Need To Hear This If You Want To {outcome}",
    "{number} {power} Habits of People Who Never Give Up",
]

# Core keyword clusters (high search volume)
KEYWORD_CLUSTERS = {
    "motivation": [
        "daily motivation", "motivational video", "motivation speech",
        "morning motivation", "powerful motivation", "best motivation",
    ],
    "mindset": [
        "mindset", "growth mindset", "winning mindset", "success mindset",
        "mindset shift", "positive mindset", "mental strength",
    ],
    "success": [
        "success habits", "how to be successful", "success motivation",
        "keys to success", "success principles", "path to success",
    ],
    "self_improvement": [
        "self improvement", "personal development", "self discipline",
        "self growth", "become better", "level up your life",
    ],
    "inspiration": [
        "inspirational speech", "inspiration", "inspire",
        "life changing", "change your life", "life advice",
    ],
}

# Hashtag sets (rotate to avoid repetition)
HASHTAG_SETS = [
    "#motivation #mindset #success #inspiration #selfimprovement #dailymotivation #motivational #growthmindset #successmindset #mentalstrength",
    "#motivation #inspiration #mindset #personaldevelopment #selfdiscipline #success #lifemotivation #motivationalquotes #positivethinking #nevergiveup",
    "#motivationaldaily #mindsetcoach #successhabits #growthmindset #levelup #selfgrowth #hustle #motivated #dailyinspiration #lifeadvice",
]


def optimize_title(raw_title: str) -> str:
    """Enhance a title for better CTR while keeping its core message."""
    title = raw_title.strip()

    # Ensure it starts with a hook word if it doesn't already
    starts_with_hook = any(title.lower().startswith(w.lower()) for w in
                           ["the ", "why ", "how ", "stop ", "if ", "this ", "you ", "what "])

    if not starts_with_hook and len(title) < 50:
        power = random.choice(POWER_WORDS)
        title = f"The {power} Truth: {title}"

    # Capitalize properly
    title = title.strip()
    if len(title) > 100:
        title = title[:97] + "..."

    return title


def optimize_description(raw_desc: str, title: str, video_format: str = "") -> str:
    """Enhance description with SEO best practices."""
    # Ensure description has proper structure
    lines = [l.strip() for l in raw_desc.strip().split("\n") if l.strip()]

    # Build optimized description
    parts = []

    # First 125 chars are shown in search results — make them count
    if lines:
        first_para = lines[0]
        if len(first_para) < 80:
            first_para = f"{first_para} This video will change the way you think about life and success."
        parts.append(first_para)
    else:
        parts.append(f"Watch this if you want to unlock your full potential. {title} — a message you need to hear today.")

    parts.append("")

    # Middle paragraphs
    for line in lines[1:3]:
        if line and not line.startswith("#"):
            parts.append(line)

    parts.append("")
    parts.append("New motivational video uploaded EVERY DAY at 9 AM. Subscribe and turn on notifications so you never miss a video that could change your life.")
    parts.append("")
    parts.append("---")
    parts.append("Follow for daily motivation:")
    parts.append("")

    # Rotating hashtags
    parts.append(random.choice(HASHTAG_SETS))

    return "\n".join(parts)


def build_tags(script_tags: list, video_format: str = "") -> list:
    """Build an optimized tag list combining script tags with SEO keywords."""
    tags = set()

    # Add script-provided tags
    for tag in script_tags[:8]:
        tags.add(tag.lower().strip())

    # Add core keyword cluster tags
    for cluster in random.sample(list(KEYWORD_CLUSTERS.values()), 3):
        for kw in cluster[:2]:
            tags.add(kw)

    # Always include these high-volume tags
    core = [
        "daily motivation", "motivation", "mindset", "success",
        "inspiration", "self improvement", "motivational speech",
        "growth mindset", "positive thinking", "mental strength",
    ]
    for tag in core:
        tags.add(tag)

    # Convert to list and trim to YouTube's 500-char total limit
    tag_list = list(tags)[:15]
    return tag_list


def optimize_script(script: dict) -> dict:
    """Apply all SEO optimizations to a generated script."""
    fmt = script.get("format", "")

    script["title"] = optimize_title(script["title"])
    script["description"] = optimize_description(script["description"], script["title"], fmt)
    script["tags"] = build_tags(script.get("tags", []), fmt)

    return script
