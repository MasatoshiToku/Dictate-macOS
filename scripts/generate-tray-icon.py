#!/usr/bin/env python3
"""Generate tray icon for menu bar (mic symbol on transparent background)."""
from PIL import Image, ImageDraw

SIZE = 36  # @2x
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
# Simple mic shape
cx, cy = SIZE // 2, SIZE // 2 - 2
draw.rounded_rectangle([cx - 4, cy - 8, cx + 4, cy + 8], radius=4, fill=(0, 0, 0, 255))
draw.arc([cx - 8, cy - 2, cx + 8, cy + 12], 0, 180, fill=(0, 0, 0, 255), width=2)
draw.line([(cx, cy + 12), (cx, cy + 16)], fill=(0, 0, 0, 255), width=2)
draw.line([(cx - 4, cy + 16), (cx + 4, cy + 16)], fill=(0, 0, 0, 255), width=2)
img.save('Dictate/Resources/tray-icon.png')
# @1x version
img.resize((18, 18), Image.LANCZOS).save('Dictate/Resources/tray-icon@1x.png')
print("Generated tray icons (18x18 @1x and 36x36 @2x)")
