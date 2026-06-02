"""
Content strategy: 7 rotating formats, one per weekday.
Visual style modeled after top viral channels:
- Motiversity: dark, cinematic, moody, intense
- Fearless Motivation: athletes, hustle, fast cuts
- Ben Lionel Scott: philosophical, cinematic landscapes, slow burn
"""
from datetime import datetime

DAILY_FORMATS = {
    0: {  # Monday
        "name": "Monday Momentum",
        "framework": "AIDA",
        "style": "intense",
        "niche": "destroying excuses and starting the week with an unstoppable burning desire to win",
        "hook_style": "shocking statement",
        "image_style": (
            "lone figure standing at the top of a skyscraper at 4am, city lights below, "
            "dark stormy sky breaking into dawn, cinematic fog, ultra-dramatic lighting, "
            "photorealistic, shot on RED camera, 8K"
        ),
    },
    1: {  # Tuesday
        "name": "Truth Tuesday",
        "framework": "PAS",
        "style": "raw",
        "niche": "the brutal uncomfortable truth about why most people never achieve their dreams",
        "hook_style": "brutal question",
        "image_style": (
            "dark dramatic silhouette of a man standing alone in heavy rain under a streetlight, "
            "reflections in wet pavement, film noir atmosphere, cinematic grain, "
            "photorealistic, shot on ARRI, desaturated with warm highlights"
        ),
    },
    2: {  # Wednesday
        "name": "Midweek Mindset",
        "framework": "HERO",
        "style": "epic",
        "niche": "a true story of someone who had nothing and built everything through sheer will",
        "hook_style": "story drop",
        "image_style": (
            "person climbing steep mountain in storm clouds breaking apart to reveal golden light, "
            "epic aerial drone shot, cinematic color grade, dramatic God rays, "
            "photorealistic, National Geographic quality, 8K"
        ),
    },
    3: {  # Thursday
        "name": "Top 5 Thursday",
        "framework": "LISTICLE",
        "style": "authoritative",
        "niche": "5 brutal habits that separate the top 1% from everyone else",
        "hook_style": "bold promise",
        "image_style": (
            "successful person alone in a dark modern penthouse office at night, "
            "city lights through floor-to-ceiling windows, single desk lamp, focused, "
            "cinematic shadows, ultra-realistic, moody atmosphere"
        ),
    },
    4: {  # Friday
        "name": "Friday Fire",
        "framework": "DIRECT",
        "style": "aggressive",
        "niche": "why you cannot afford to waste another weekend and what to do instead",
        "hook_style": "direct challenge",
        "image_style": (
            "athlete sprinting on track at sunset, motion blur, fire-toned sky, "
            "sweat catching light, ultra-dynamic composition, cinematic, "
            "Nike ad quality, dramatic low angle, 8K"
        ),
    },
    5: {  # Saturday
        "name": "Saturday Wisdom",
        "framework": "QUOTE_DEEP_DIVE",
        "style": "philosophical",
        "niche": "a timeless wisdom that the greatest minds in history knew but schools never teach",
        "hook_style": "mystery reveal",
        "image_style": (
            "ancient library with shafts of golden light through tall windows, "
            "dust particles floating, leather books, solitary candle, "
            "painterly realism, old masters lighting, cinematic, ultra-detailed"
        ),
    },
    6: {  # Sunday
        "name": "Sunday Reset",
        "framework": "FUTURE_SELF",
        "style": "powerful_calm",
        "niche": "the Sunday mindset ritual that will completely transform your life in 90 days",
        "hook_style": "vivid future",
        "image_style": (
            "person meditating on cliff edge at sunrise above clouds, "
            "golden mist below, perfect stillness, cinematic wide shot, "
            "ethereal light, photorealistic, 8K, National Geographic"
        ),
    },
}

FRAMEWORKS = {
    "AIDA": """
ATTENTION — Scene 1-2: Hit them with a statement so bold it stops the scroll. No pleasantries.
INTEREST — Scene 3-4: Why does this matter to THEIR life, right now, today?
DESIRE — Scene 5-6: Paint the picture. What does their life look like when they GET this?
ACTION — Scene 7-8: Fire them up. Send them out ready to conquer. Pure energy.
""",
    "PAS": """
PROBLEM — Scene 1-2: Name the exact pain they feel every day but never admit. Be specific.
AGITATE — Scene 3-4: Twist the knife. Make it real. What happens if nothing changes?
SOLUTION — Scene 5-6: The reframe. The insight. The thing that changes everything.
CLOSE — Scene 7-8: Hope. Power. A clear next step. Leave them better than you found them.
""",
    "HERO": """
THE FALL — Scene 1-2: Start at rock bottom. Make it visceral and real.
THE TURNING POINT — Scene 3-4: The single moment. The decision. The spark.
THE CLIMB — Scene 5-6: The struggle. The sacrifice. The growth.
THE TRANSFORMATION — Scene 7-8: Who they became. What the viewer must take from this.
""",
    "LISTICLE": """
HOOK — Scene 1: Promise the 5 things. Create FOMO. Make them need to watch every second.
POINT 1 & 2 — Scene 2-3: Strong openers — surprising, counterintuitive insights.
POINT 3 & 4 — Scene 4-5: Build intensity. Each point more powerful than the last.
POINT 5 — Scene 6: Save the most powerful for last. Make it hit hard.
CLOSE — Scene 7-8: Tie it together. Send them off fired up.
""",
    "DIRECT": """
STATE THE TRUTH — Scene 1-2: No warm-up. Say the hard thing right away.
CONFRONT — Scene 3-4: Call out the excuses directly. No sugarcoating.
CHALLENGE — Scene 5-6: Dare them. Push them. Make them feel something.
IGNITE — Scene 7-8: Light the fire. Pure raw energy. Unforgettable close.
""",
    "QUOTE_DEEP_DIVE": """
THE QUOTE — Scene 1: Drop the quote cold. Let it land in silence (in the listener's mind).
CONTEXT — Scene 2-3: The story behind it. When was it said? Why does it matter now?
UNPACK — Scene 4-5: Go word by word. Every layer of meaning.
MODERN APPLICATION — Scene 6-7: How to live this TODAY — concrete and real.
CLOSE — Scene 8: Send them off with the quote ringing in their head.
""",
    "FUTURE_SELF": """
VISION — Scene 1-2: The most vivid picture of their best possible future. Make them see it.
THE GAP — Scene 3-4: What stands between now and that future. Honest and direct.
THE METHOD — Scene 5-6: The exact mindset and ritual that closes the gap.
THE COMMITMENT — Scene 7-8: A challenge. A promise they make to themselves. Right now.
""",
}

# Viral video script DNA from top channels
VIRAL_DNA = """
PHRASING RULES (from Motiversity, Fearless Motivation, Ben Lionel Scott):
- Short sentences hit harder than long ones. Mix them.
- Repeat key phrases for rhythm: "Work. Every day. No excuses. Work."
- Use second person: "YOU chose this." "YOUR future is being written right now."
- Contrast past vs future: "You were not born to be average. You were born for MORE."
- Time pressure: "Every second you wait, someone else takes your spot."
- Visceral language: "burn", "forge", "bleed", "rise", "destroy", "unleash"
- End sentences on power words: "...is GREATNESS." "...is YOUR time." "...is ENOUGH."
- No clichés. No "believe in yourself." Say something NEW and REAL.
"""


def get_todays_format() -> dict:
    weekday = datetime.now().weekday()
    fmt = DAILY_FORMATS[weekday].copy()
    fmt["framework_instructions"] = FRAMEWORKS[fmt["framework"]]
    fmt["viral_dna"] = VIRAL_DNA
    return fmt
