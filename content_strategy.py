"""
Content strategy: 7 rotating video formats, one per weekday.
Each format uses a different storytelling framework for maximum variety.
"""
from datetime import datetime

# Day-based content themes (0=Monday, 6=Sunday)
DAILY_FORMATS = {
    0: {  # Monday
        "name": "Monday Momentum",
        "framework": "AIDA",
        "style": "high_energy",
        "niche": "overcoming Monday resistance and starting the week with unstoppable momentum",
        "hook_style": "bold statement",
        "duration_target": 90,
        "image_style": "dramatic sunrise, city skyline, people running or working hard",
    },
    1: {  # Tuesday
        "name": "Truth Tuesday",
        "framework": "PAS",
        "style": "thought_provoking",
        "niche": "a single uncomfortable truth that successful people understand and others ignore",
        "hook_style": "controversial question",
        "duration_target": 75,
        "image_style": "single person in contemplation, dramatic lighting, minimalist",
    },
    2: {  # Wednesday
        "name": "Midweek Mindset",
        "framework": "HERO",
        "style": "storytelling",
        "niche": "a powerful story of transformation from struggle to success",
        "hook_style": "story opening",
        "duration_target": 100,
        "image_style": "cinematic journey scenes, mountains, roads, transformation",
    },
    3: {  # Thursday
        "name": "Top 5 Thursday",
        "framework": "LISTICLE",
        "style": "educational",
        "niche": "5 powerful habits, mindset shifts, or success principles",
        "hook_style": "numbered promise",
        "duration_target": 90,
        "image_style": "clean professional environments, success symbols, achievement",
    },
    4: {  # Friday
        "name": "Friday Fire",
        "framework": "DIRECT",
        "style": "intense_motivation",
        "niche": "finishing the week strong and never settling for mediocrity",
        "hook_style": "call to action",
        "duration_target": 80,
        "image_style": "fire, energy, victory, finish line, celebration",
    },
    5: {  # Saturday
        "name": "Saturday Wisdom",
        "framework": "QUOTE_DEEP_DIVE",
        "style": "reflective",
        "niche": "a profound quote from a great mind, deeply explored and applied to modern life",
        "hook_style": "quote reveal",
        "duration_target": 85,
        "image_style": "peaceful nature, golden light, books, wisdom symbols",
    },
    6: {  # Sunday
        "name": "Sunday Reset",
        "framework": "FUTURE_SELF",
        "style": "gentle_powerful",
        "niche": "preparing mentally and emotionally for the week ahead with intention and clarity",
        "hook_style": "visualization",
        "duration_target": 95,
        "image_style": "calm morning light, journal, coffee, new beginnings, hope",
    },
}

FRAMEWORKS = {
    "AIDA": """
ATTENTION: Open with a shocking stat, bold claim, or question that stops scrolling.
INTEREST: Build curiosity — why does this matter to their life specifically?
DESIRE: Paint the vivid picture of what their life looks like when they apply this.
ACTION: End with a specific, energizing call to action they can do TODAY.
""",
    "PAS": """
PROBLEM: Clearly name the pain point they feel every day but never talk about.
AGITATE: Dig deeper — what happens if this problem continues? Make it real.
SOLUTION: Deliver the reframe or insight that changes everything.
Close with hope and momentum.
""",
    "HERO": """
ORDINARY WORLD: Introduce someone just like the viewer — struggling, doubting, stuck.
THE CALL: The moment everything changed. One decision, one realization.
THE JOURNEY: The challenges faced and overcome. Be specific and emotional.
TRANSFORMATION: Who they became. What the viewer can take from this story.
""",
    "LISTICLE": """
HOOK: Promise the 5 things upfront — create urgency to watch all the way through.
ITEMS 1-5: Each point should be a surprising insight, not generic advice.
Build intensity — save the most powerful for last.
CLOSE: Tie them together into one unified message.
""",
    "DIRECT": """
STATE THE TRUTH: No fluff. Say exactly what needs to be said.
CHALLENGE: Directly challenge their excuses and limiting beliefs.
PROOF: Why this matters, right now, today — not someday.
CHARGE: Send them off with pure energy and conviction.
""",
    "QUOTE_DEEP_DIVE": """
REVEAL THE QUOTE: State it powerfully. Let it land.
CONTEXT: Who said it, when, and why it matters more today than ever.
UNPACK: Break down every word and its deeper meaning.
APPLICATION: Exactly how to live this quote starting today.
""",
    "FUTURE_SELF": """
VISUALIZATION: Paint a vivid picture of their best possible future self.
THE GAP: What stands between now and that future. Be honest and compassionate.
THE BRIDGE: The mindset and actions that close the gap.
INTENTION: Send them into their week with a clear, powerful intention.
""",
}


def get_todays_format() -> dict:
    """Return today's content format based on the day of the week."""
    weekday = datetime.now().weekday()
    fmt = DAILY_FORMATS[weekday].copy()
    fmt["framework_instructions"] = FRAMEWORKS[fmt["framework"]]
    return fmt
