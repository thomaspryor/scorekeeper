#!/usr/bin/env python3
"""Turns raw simulator screenshots into App Store screenshots: a headline on a
palette color above a scaled-down copy of the screen.

Usage: frame_screenshots.py <dir>
Rewrites every <device>-<n>-<scenario>.png in <dir> in place, keeping its pixel
size (App Store sizes are checked before framing). Called by screenshots.sh.
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Scenario -> (headline, background). Headlines describe what the screen shows.
FRAMES = {
    "celebration": ("Crown the winner", "#0074D9"),
    "scoreboard": ("Score any game", "#B10DC9"),
    "history": ("Save every game", "#FF4136"),
}

FONTS = [
    "/System/Library/Fonts/SFNS.ttf",  # San Francisco (macOS CI)
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf",  # local preview on Linux
]


def bold_font(size):
    for path in FONTS:
        if not Path(path).exists():
            continue
        font = ImageFont.truetype(path, size)
        try:
            font.set_variation_by_name("Bold")
        except Exception:
            pass  # not a variable font
        return font
    return ImageFont.load_default(size)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width, img.height], radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, mask=mask)
    return out


def wrap(draw, text, font, max_width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) <= max_width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def frame(path, headline, color):
    shot = Image.open(path).convert("RGB")
    w, h = shot.size
    canvas = Image.new("RGB", (w, h), color)
    draw = ImageDraw.Draw(canvas)

    # Headline: big, white, centered, at most two lines.
    font = bold_font(round(min(w, h) * 0.085))
    lines = wrap(draw, headline, font, w * 0.86)
    line_h = font.size * 1.15
    top = h * 0.055
    for i, line in enumerate(lines):
        x = (w - draw.textlength(line, font=font)) / 2
        draw.text((x, top + i * line_h), line, font=font, fill="white")
    text_bottom = top + len(lines) * line_h

    # Screen: scaled to 82% width with rounded corners; it runs off the bottom
    # edge like a phone held below the frame.
    scale = 0.82
    sw, sh = round(w * scale), round(h * scale)
    screen = rounded(shot.resize((sw, sh), Image.LANCZOS), round(sw * 0.07))
    y = round(text_bottom + h * 0.035)
    canvas.paste(screen, ((w - sw) // 2, y), screen)
    canvas.save(path)


def main():
    folder = Path(sys.argv[1])
    for path in sorted(folder.glob("*.png")):
        match = re.match(r".+-\d+-([a-z]+)\.png$", path.name)
        if not match or match.group(1) not in FRAMES:
            continue
        headline, color = FRAMES[match.group(1)]
        frame(path, headline, color)
        print(f"Framed {path.name}: {headline}")


if __name__ == "__main__":
    main()
