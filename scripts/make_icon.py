#!/usr/bin/env python3
"""Generate a nano banana app icon for Watchdog and produce an .icns file."""

import math
import os
import subprocess
import tempfile
from PIL import Image, ImageDraw, ImageFilter


def bezier_point(t, p0, p1, p2, p3):
    """Cubic bezier curve point at parameter t."""
    u = 1 - t
    return (
        u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
        u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
    )


def draw_banana_icon(size):
    """Draw a stylized nano banana on a dark rounded-square background."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size

    pad = s * 0.04

    # -- Background: dark rounded square --
    bg_radius = s * 0.22
    draw.rounded_rectangle(
        [pad, pad, s - pad, s - pad],
        radius=bg_radius,
        fill=(15, 15, 15, 255),
    )

    # Subtle border
    draw.rounded_rectangle(
        [pad, pad, s - pad, s - pad],
        radius=bg_radius,
        outline=(52, 211, 153, 35),
        width=max(1, int(s * 0.004)),
    )

    # -- Banana using cubic bezier curves --
    # Classic banana crescent: curved outer edge, flatter inner edge
    cx, cy = s * 0.48, s * 0.48
    scale = s * 0.0038

    # Outer curve of banana (top/back side)
    outer_top = [
        (cx - 95 * scale, cy + 30 * scale),   # left tip
        (cx - 60 * scale, cy - 90 * scale),   # control 1
        (cx + 70 * scale, cy - 100 * scale),  # control 2
        (cx + 105 * scale, cy - 10 * scale),  # right tip
    ]

    # Inner curve of banana (belly side) — less curved
    inner_bottom = [
        (cx + 105 * scale, cy - 10 * scale),  # right tip (same)
        (cx + 50 * scale, cy - 50 * scale),   # control 1
        (cx - 30 * scale, cy - 40 * scale),   # control 2
        (cx - 95 * scale, cy + 30 * scale),   # left tip (same)
    ]

    # Sample points along both curves
    n = 80
    outer_pts = [bezier_point(i / n, *outer_top) for i in range(n + 1)]
    inner_pts = [bezier_point(i / n, *inner_bottom) for i in range(n + 1)]

    banana_shape = outer_pts + inner_pts

    # -- Shadow --
    shadow_offset = s * 0.012
    shadow_pts = [(x + shadow_offset, y + shadow_offset) for x, y in banana_shape]

    # Draw shadow on a separate layer and blur
    shadow_layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_layer)
    shadow_draw.polygon(shadow_pts, fill=(0, 0, 0, 80))
    if s >= 128:
        shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=s * 0.015))
    img = Image.alpha_composite(img, shadow_layer)
    draw = ImageDraw.Draw(img)

    # -- Main banana body --
    banana_yellow = (255, 215, 45, 255)
    draw.polygon(banana_shape, fill=banana_yellow)

    # -- Highlight stripe (lighter yellow along the outer curve) --
    highlight_pts_outer = []
    for i in range(n + 1):
        t = i / n
        px, py = bezier_point(t, *outer_top)
        # Offset inward slightly
        ix, iy = bezier_point(t, *inner_bottom[::-1])  # reverse inner for direction
        dx, dy = ix - px, iy - py
        dist = math.sqrt(dx * dx + dy * dy) or 1
        highlight_pts_outer.append((px + dx / dist * s * 0.015, py + dy / dist * s * 0.015))

    highlight_pts_inner = []
    for i in range(n + 1):
        t = i / n
        px, py = bezier_point(t, *outer_top)
        ix, iy = bezier_point(t, *inner_bottom[::-1])
        dx, dy = ix - px, iy - py
        dist = math.sqrt(dx * dx + dy * dy) or 1
        # 35% of the way toward inner curve
        highlight_pts_inner.append((px + dx / dist * s * 0.06, py + dy / dist * s * 0.06))

    highlight_shape = highlight_pts_outer + highlight_pts_inner[::-1]
    draw.polygon(highlight_shape, fill=(255, 240, 110, 180))

    # -- Brown tips --
    tip_color = (110, 80, 25, 255)
    tip_dark = (80, 55, 15, 255)

    # Left tip (stem end) — small tapered shape
    lx, ly = outer_top[0]  # left tip point
    stem_len = s * 0.05
    stem_w = s * 0.022
    # Stem direction: pointing down-left
    stem_pts = [
        (lx - stem_len * 0.3, ly + stem_len * 0.8),
        (lx - stem_w, ly - stem_w * 0.5),
        (lx + stem_w, ly - stem_w * 0.3),
        (lx + stem_w * 0.5, ly + stem_len * 0.4),
    ]
    draw.polygon(stem_pts, fill=tip_color)

    # Right tip (blossom end)
    rx, ry = outer_top[3]
    tip_sz = s * 0.018
    draw.ellipse(
        [rx - tip_sz, ry - tip_sz * 1.2, rx + tip_sz * 1.5, ry + tip_sz],
        fill=tip_dark,
    )

    # -- Small green Watchdog accent dot (bottom right, subtle) --
    glow_x, glow_y = s * 0.73, s * 0.73
    dot_r = s * 0.032

    # Soft glow behind
    glow_layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    glow_r = dot_r * 3
    glow_draw.ellipse(
        [glow_x - glow_r, glow_y - glow_r, glow_x + glow_r, glow_y + glow_r],
        fill=(52, 211, 153, 40),
    )
    if s >= 128:
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=s * 0.02))
    img = Image.alpha_composite(img, glow_layer)
    draw = ImageDraw.Draw(img)

    # Core dot
    draw.ellipse(
        [glow_x - dot_r, glow_y - dot_r, glow_x + dot_r, glow_y + dot_r],
        fill=(52, 211, 153, 230),
    )

    return img


def main():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # macOS .icns sizes: 16, 32, 128, 256, 512 at 1x and 2x
    icon_entries = {
        'icon_16x16.png': 16,
        'icon_16x16@2x.png': 32,
        'icon_32x32.png': 32,
        'icon_32x32@2x.png': 64,
        'icon_128x128.png': 128,
        'icon_128x128@2x.png': 256,
        'icon_256x256.png': 256,
        'icon_256x256@2x.png': 512,
        'icon_512x512.png': 512,
        'icon_512x512@2x.png': 1024,
    }

    with tempfile.TemporaryDirectory() as tmpdir:
        iconset_dir = os.path.join(tmpdir, 'AppIcon.iconset')
        os.makedirs(iconset_dir)

        # Cache rendered sizes to avoid re-rendering
        cache = {}
        for name, sz in icon_entries.items():
            if sz not in cache:
                cache[sz] = draw_banana_icon(sz)
            cache[sz].save(os.path.join(iconset_dir, name))

        # Generate .icns
        icns_path = os.path.join(project_root, 'Watchdog', 'Assets.xcassets', 'AppIcon.icns')
        result = subprocess.run(
            ['iconutil', '-c', 'icns', iconset_dir, '-o', icns_path],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(f'iconutil error: {result.stderr}')
            fallback = os.path.join(project_root, 'Watchdog', 'Assets.xcassets', 'AppIcon.png')
            draw_banana_icon(1024).save(fallback)
            print(f'Saved fallback PNG to {fallback}')
            return fallback
        else:
            print(f'Created .icns at {icns_path}')
            return icns_path


if __name__ == '__main__':
    path = main()
    print(f'Icon saved: {path}')
