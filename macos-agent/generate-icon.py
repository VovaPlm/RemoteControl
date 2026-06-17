#!/usr/bin/env python3
from PIL import Image, ImageDraw
import os, subprocess

SIZE = 1024
DARK = (30, 35, 41, 255)
GOLD = (240, 185, 11, 255)

img = Image.new('RGBA', (SIZE, SIZE), DARK)
draw = ImageDraw.Draw(img)

# Outer gold circle
draw.ellipse([SIZE*0.08, SIZE*0.08, SIZE*0.92, SIZE*0.92], fill=GOLD)

# Inner dark circle
draw.ellipse([SIZE*0.16, SIZE*0.16, SIZE*0.84, SIZE*0.84], fill=DARK)

# Try to load a bold font
font = None
for path in [
    '/System/Library/Fonts/Helvetica.ttc',
    '/System/Library/Fonts/AppleSDGothicNeo.ttc',
    '/Library/Fonts/Arial.ttf',
]:
    try:
        from PIL import ImageFont
        font = ImageFont.truetype(path, SIZE * 45 // 100)
        break
    except:
        continue

if font is None:
    font = ImageFont.load_default()

# Draw "R" in gold
bbox = draw.textbbox((0, 0), 'R', font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
pos = ((SIZE - tw) // 2, (SIZE - th) // 2 + SIZE * 3 // 100)
draw.text(pos, 'R', fill=GOLD, font=font)

out_dir = 'AppIcon.iconset'
os.makedirs(out_dir, exist_ok=True)

# Save all required sizes
sizes = {
    'icon_16x16.png': 16,
    'icon_16x16@2x.png': 32,
    'icon_32x32.png': 32,
    'icon_32x32@2x.png': 64,
    'icon_64x64.png': 64,
    'icon_128x128.png': 128,
    'icon_128x128@2x.png': 256,
    'icon_256x256.png': 256,
    'icon_256x256@2x.png': 512,
    'icon_512x512.png': 512,
    'icon_512x512@2x.png': 1024,
}

for name, sz in sizes.items():
    resized = img.resize((sz, sz), Image.LANCZOS)
    resized.save(os.path.join(out_dir, name))

subprocess.run(['iconutil', '-c', 'icns', out_dir], check=True)
subprocess.run(['rm', '-rf', out_dir])
print('✅ AppIcon.icns created')
