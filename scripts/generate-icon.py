#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
ICONSET = RESOURCES / "AppIcon.iconset"
SCALE = 3
SIZE = 1024
W = SIZE * SCALE


def scaled_box(box):
    return tuple(int(value * SCALE) for value in box)


canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# Soft shadow behind the macOS-style rounded tile.
shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.rounded_rectangle(
    scaled_box((58, 70, 966, 978)),
    radius=210 * SCALE,
    fill=(4, 8, 28, 155),
)
shadow = shadow.filter(ImageFilter.GaussianBlur(30 * SCALE))
canvas.alpha_composite(shadow)

# Diagonal navy-to-violet gradient clipped to a rounded square.
gradient = Image.new("RGBA", canvas.size)
gradient_pixels = gradient.load()
for y in range(W):
    for x in range(W):
        t = min(1.0, max(0.0, (x * 0.62 + y * 0.38) / W))
        gradient_pixels[x, y] = (
            int(19 + 53 * t),
            int(35 + 23 * t),
            int(82 + 92 * t),
            255,
        )
mask = Image.new("L", canvas.size, 0)
ImageDraw.Draw(mask).rounded_rectangle(
    scaled_box((48, 48, 976, 976)),
    radius=205 * SCALE,
    fill=255,
)
canvas.alpha_composite(Image.composite(gradient, Image.new("RGBA", canvas.size), mask))

draw = ImageDraw.Draw(canvas)

# Subtle highlight around the tile.
draw.rounded_rectangle(
    scaled_box((56, 56, 968, 968)),
    radius=197 * SCALE,
    outline=(255, 255, 255, 38),
    width=5 * SCALE,
)

# Back window.
draw.rounded_rectangle(
    scaled_box((178, 206, 718, 592)),
    radius=58 * SCALE,
    fill=(113, 101, 241, 230),
    outline=(213, 218, 255, 225),
    width=12 * SCALE,
)
draw.line(scaled_box((190, 300, 706, 300)), fill=(225, 229, 255, 190), width=10 * SCALE)
for x, color in [(234, (255, 112, 137, 255)), (278, (255, 207, 91, 255)), (322, (105, 232, 178, 255))]:
    draw.ellipse(scaled_box((x - 13, 245, x + 13, 271)), fill=color)

# Front window with a darker surface.
draw.rounded_rectangle(
    scaled_box((304, 376, 850, 770)),
    radius=62 * SCALE,
    fill=(18, 39, 91, 246),
    outline=(119, 223, 255, 245),
    width=13 * SCALE,
)
draw.line(scaled_box((317, 468, 837, 468)), fill=(118, 214, 255, 180), width=9 * SCALE)
for x, color in [(361, (255, 112, 137, 255)), (405, (255, 207, 91, 255)), (449, (105, 232, 178, 255))]:
    draw.ellipse(scaled_box((x - 13, 415, x + 13, 441)), fill=color)

# Two clean Tab-like switching arrows.
draw.line(
    [tuple(v * SCALE for v in p) for p in [(406, 552), (696, 552)]],
    fill=(255, 255, 255, 255),
    width=30 * SCALE,
)
draw.polygon(
    [tuple(v * SCALE for v in p) for p in [(696, 510), (758, 552), (696, 594)]],
    fill=(255, 255, 255, 255),
)
draw.line(
    [tuple(v * SCALE for v in p) for p in [(746, 654), (456, 654)]],
    fill=(100, 225, 255, 255),
    width=30 * SCALE,
)
draw.polygon(
    [tuple(v * SCALE for v in p) for p in [(456, 612), (394, 654), (456, 696)]],
    fill=(100, 225, 255, 255),
)

source = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
RESOURCES.mkdir(parents=True, exist_ok=True)
source.save(RESOURCES / "AppIcon.png")
ICONSET.mkdir(parents=True, exist_ok=True)

for points in (16, 32, 128, 256, 512):
    source.resize((points, points), Image.Resampling.LANCZOS).save(
        ICONSET / f"icon_{points}x{points}.png"
    )
    source.resize((points * 2, points * 2), Image.Resampling.LANCZOS).save(
        ICONSET / f"icon_{points}x{points}@2x.png"
    )

print(ICONSET)
