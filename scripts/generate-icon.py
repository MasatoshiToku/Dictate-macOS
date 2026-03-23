#!/usr/bin/env python3
"""Generate Dictate app icon using Pillow."""
from PIL import Image, ImageDraw
import os
import tempfile
import shutil

SIZE = 1024
PADDING = 80

def create_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: rounded rectangle with orange gradient
    for y in range(SIZE):
        ratio = y / SIZE
        r = int(255 * (1 - ratio * 0.3))  # 255 -> 178
        g = int(140 + (184 - 140) * ratio)  # 140 -> 184
        b = int(0 + (0) * ratio)
        draw.line([(PADDING, y), (SIZE - PADDING, y)], fill=(r, g, b, 255))

    # Mask to rounded rectangle
    mask = Image.new('L', (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = 200
    mask_draw.rounded_rectangle(
        [PADDING, PADDING, SIZE - PADDING, SIZE - PADDING],
        radius=corner_radius,
        fill=255
    )

    bg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    bg.paste(img, mask=mask)
    img = bg
    draw = ImageDraw.Draw(img)

    # Microphone icon (white)
    cx, cy = SIZE // 2, SIZE // 2 - 40
    mic_color = (255, 255, 255, 240)

    # Mic body (rounded rectangle)
    mic_w, mic_h = 120, 200
    mic_r = 60
    draw.rounded_rectangle(
        [cx - mic_w//2, cy - mic_h//2, cx + mic_w//2, cy + mic_h//2],
        radius=mic_r,
        fill=mic_color
    )

    # Arc around mic
    arc_w = 200
    arc_top = cy - mic_h//2 + 30
    arc_bottom = cy + mic_h//2 + 20
    draw.arc(
        [cx - arc_w//2, arc_top, cx + arc_w//2, arc_bottom + 40],
        start=0, end=180,
        fill=mic_color, width=16
    )

    # Stand (vertical line + horizontal base)
    stand_top = arc_bottom + 30
    stand_bottom = stand_top + 80
    draw.line([(cx, stand_top), (cx, stand_bottom)], fill=mic_color, width=16)
    draw.line([(cx - 60, stand_bottom), (cx + 60, stand_bottom)], fill=mic_color, width=16)

    return img

if __name__ == '__main__':
    icon = create_icon()
    icon.save('Dictate/Resources/AppIcon.png')

    # Generate sized PNGs and .icns in a temp directory to avoid SPM conflicts
    tmpdir = tempfile.mkdtemp(prefix='dictate-icon-')
    iconset_dir = os.path.join(tmpdir, 'AppIcon.iconset')
    os.makedirs(iconset_dir)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    size_map = {
        16: 'icon_16x16.png',
        32: 'icon_16x16@2x.png',  # Also icon_32x32.png
        64: 'icon_32x32@2x.png',
        128: 'icon_128x128.png',
        256: 'icon_128x128@2x.png',  # Also icon_256x256.png
        512: 'icon_256x256@2x.png',  # Also icon_512x512.png
        1024: 'icon_512x512@2x.png',
    }
    # Additional entries for the iconset
    extra_map = {
        32: 'icon_32x32.png',
        256: 'icon_256x256.png',
        512: 'icon_512x512.png',
    }

    for size in sizes:
        resized = icon.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(iconset_dir, size_map[size]))
        if size in extra_map:
            resized.save(os.path.join(iconset_dir, extra_map[size]))

    # Build .icns using iconutil
    icns_path = os.path.join(tmpdir, 'icon.icns')
    os.system(f'iconutil -c icns "{iconset_dir}" -o "{icns_path}"')

    # Copy final .icns to Resources
    shutil.copy2(icns_path, 'Dictate/Resources/icon.icns')

    # Clean up temp
    shutil.rmtree(tmpdir)

    print("Generated AppIcon.png and icon.icns")
