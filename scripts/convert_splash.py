#!/usr/bin/env python3
"""
convert_splash.py — Convert a PNG image to C64 multicolor bitmap data.

Resizes to 160x200 (multicolor resolution), maps pixels to the C64
16-color palette, then encodes bitmap, screen RAM, and color RAM
suitable for VIC-II multicolor bitmap mode.

Usage:
    python scripts/convert_splash.py docs/c64_tutor_splash_main.png.png assets/

Outputs:
    assets/splash_bitmap.bin  (8000 bytes)
    assets/splash_screen.bin  (1000 bytes)
    assets/splash_color.bin   (1000 bytes)

Also prints the background color index for use in constants.asm.
"""

import sys
import os
from PIL import Image
from collections import Counter

# VICE default palette (RGB values for C64 colors 0-15)
C64_PALETTE = [
    (0x00, 0x00, 0x00),  # 0  Black
    (0xFF, 0xFF, 0xFF),  # 1  White
    (0x9F, 0x4E, 0x44),  # 2  Red
    (0x6A, 0xBF, 0xC6),  # 3  Cyan
    (0xA0, 0x57, 0xA3),  # 4  Purple
    (0x5C, 0xAB, 0x5E),  # 5  Green
    (0x50, 0x45, 0x9B),  # 6  Blue
    (0xC9, 0xD4, 0x87),  # 7  Yellow
    (0xA1, 0x68, 0x3C),  # 8  Orange
    (0x6D, 0x54, 0x12),  # 9  Brown
    (0xCB, 0x7E, 0x75),  # 10 Light Red
    (0x62, 0x62, 0x62),  # 11 Dark Grey
    (0x89, 0x89, 0x89),  # 12 Medium Grey
    (0x9A, 0xE2, 0x9B),  # 13 Light Green
    (0x88, 0x7E, 0xCB),  # 14 Light Blue
    (0xAD, 0xAD, 0xAD),  # 15 Light Grey
]


def color_distance(c1, c2):
    """Euclidean RGB distance squared."""
    return sum((a - b) ** 2 for a, b in zip(c1, c2))


def nearest_c64_color(rgb):
    """Find nearest C64 palette index for an RGB tuple."""
    best_idx = 0
    best_dist = float('inf')
    for i, pal in enumerate(C64_PALETTE):
        d = color_distance(rgb, pal)
        if d < best_dist:
            best_dist = d
            best_idx = i
    return best_idx


def convert(input_path, output_dir):
    img = Image.open(input_path).convert('RGB')
    # Resize to 160x200 (multicolor pixel resolution)
    img = img.resize((160, 200), Image.LANCZOS)

    # Map every pixel to nearest C64 color index
    pixels = []
    all_colors = []
    for y in range(200):
        row = []
        for x in range(160):
            rgb = img.getpixel((x, y))
            idx = nearest_c64_color(rgb)
            row.append(idx)
            all_colors.append(idx)
        pixels.append(row)

    # Pick global background color (most frequent)
    freq = Counter(all_colors)
    bg_color = freq.most_common(1)[0][0]
    print(f"Background color index: {bg_color} ({C64_PALETTE[bg_color]})")

    # Encode per 4x8 cell (40 columns x 25 rows = 1000 cells)
    bitmap = bytearray(8000)
    screen = bytearray(1000)
    color = bytearray(1000)

    for cell_row in range(25):
        for cell_col in range(40):
            cell_idx = cell_row * 40 + cell_col
            # Collect all pixel color indices in this 4x8 cell
            # Each multicolor pixel is 2 hires pixels wide,
            # so cell_col covers 4 multicolor pixels (= 8 hires pixels)
            cell_colors = []
            for cy in range(8):
                py = cell_row * 8 + cy
                for cx in range(4):
                    px = cell_col * 4 + cx
                    if py < 200 and px < 160:
                        cell_colors.append(pixels[py][px])
                    else:
                        cell_colors.append(bg_color)

            # Count non-bg colors in this cell
            non_bg = [c for c in cell_colors if c != bg_color]
            non_bg_freq = Counter(non_bg)

            # Pick top 3 most frequent non-bg colors
            top3 = [c for c, _ in non_bg_freq.most_common(3)]
            # Pad to 3 entries if fewer unique colors
            while len(top3) < 3:
                top3.append(bg_color)

            color1 = top3[0]  # screen RAM hi nybble (pair 01)
            color2 = top3[1]  # screen RAM lo nybble (pair 10)
            color3 = top3[2]  # color RAM (pair 11)

            screen[cell_idx] = (color1 << 4) | color2
            color[cell_idx] = color3

            # Encode bitmap: 8 rows, each row = 1 byte
            # Each row has 4 multicolor pixels = 4 x 2-bit pairs = 8 bits
            # Pair encoding: 00=bg, 01=color1, 10=color2, 11=color3
            color_map = {bg_color: 0, color1: 1, color2: 2, color3: 3}

            for cy in range(8):
                py = cell_row * 8 + cy
                byte_val = 0
                for cx in range(4):
                    px = cell_col * 4 + cx
                    if py < 200 and px < 160:
                        c = pixels[py][px]
                    else:
                        c = bg_color
                    # Map to nearest available color in cell
                    if c in color_map:
                        pair = color_map[c]
                    else:
                        # Find closest among the 4 cell colors
                        best_pair = 0
                        best_dist = float('inf')
                        for cc, pp in color_map.items():
                            d = color_distance(C64_PALETTE[c], C64_PALETTE[cc])
                            if d < best_dist:
                                best_dist = d
                                best_pair = pp
                        pair = best_pair
                    byte_val = (byte_val << 2) | pair
                bitmap[cell_idx * 8 + cy] = byte_val

    # Write output files
    os.makedirs(output_dir, exist_ok=True)

    bitmap_path = os.path.join(output_dir, 'splash_bitmap.bin')
    screen_path = os.path.join(output_dir, 'splash_screen.bin')
    color_path = os.path.join(output_dir, 'splash_color.bin')

    with open(bitmap_path, 'wb') as f:
        f.write(bitmap)
    with open(screen_path, 'wb') as f:
        f.write(screen)
    with open(color_path, 'wb') as f:
        f.write(color)

    print(f"Written: {bitmap_path} ({len(bitmap)} bytes)")
    print(f"Written: {screen_path} ({len(screen)} bytes)")
    print(f"Written: {color_path} ({len(color)} bytes)")
    print(f"\nSet SPLASH_BG_COLOR = {bg_color} in constants.asm")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.png> <output_dir>")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
