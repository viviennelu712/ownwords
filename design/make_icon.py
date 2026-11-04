"""Draws the OwnWords app icon: your voice, inside quotation marks.

Run:  python3 design/make_icon.py   → writes design/icon-1024.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SCALE = 2                      # draw large, shrink once for smooth edges
S = 1024 * SCALE
OUT = Path(__file__).with_name("icon-1024.png")

TOP = (61, 138, 99)            # greens from the 自然 palette (#2f6f4f family)
BOTTOM = (36, 90, 64)
BRACKET = (250, 248, 245)      # #faf8f5
WAVE = (243, 201, 105)         # warm amber


def px(v):
    return int(v * SCALE)


def squircle_mask(size, inset, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, size - inset, size - inset), radius=radius, fill=255
    )
    return mask


def main():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Soft drop shadow, like other macOS icons.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (px(100), px(112), px(924), px(936)), radius=px(185), fill=(0, 0, 0, 90)
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(px(14))))

    # Body: vertical green gradient inside the rounded square.
    gradient = Image.new("RGBA", (S, S))
    draw = ImageDraw.Draw(gradient)
    for y in range(S):
        t = y / (S - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        draw.line([(0, y), (S, y)], fill=color + (255,))
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body.paste(gradient, (0, 0), squircle_mask(S, px(100), px(185)))
    canvas.alpha_composite(body)

    draw = ImageDraw.Draw(canvas)
    w = px(54)

    # 「 top-left and 」 bottom-right: the words are yours, quoted as said.
    draw.line([(px(452), px(282)), (px(282), px(282)), (px(282), px(540))],
              fill=BRACKET, width=w, joint="curve")
    draw.line([(px(572), px(742)), (px(742), px(742)), (px(742), px(484))],
              fill=BRACKET, width=w, joint="curve")
    for x, y in [(452, 282), (282, 540), (572, 742), (742, 484)]:
        r = w // 2
        draw.ellipse((px(x) - r, px(y) - r, px(x) + r, px(y) + r), fill=BRACKET)
    for x, y in [(282, 282), (742, 742)]:
        r = w // 2
        draw.rectangle((px(x) - r, px(y) - r, px(x) + r, px(y) + r), fill=BRACKET)

    # The voice in between: five rounded level bars.
    heights = [96, 184, 262, 184, 96]
    bar, gap = 44, 30
    total = len(heights) * bar + (len(heights) - 1) * gap
    x = 512 - total / 2
    for h in heights:
        draw.rounded_rectangle(
            (px(x), px(512 - h / 2), px(x + bar), px(512 + h / 2)),
            radius=px(bar / 2), fill=WAVE,
        )
        x += bar + gap

    canvas.resize((1024, 1024), Image.LANCZOS).save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
