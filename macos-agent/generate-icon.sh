#!/bin/bash
set -euo pipefail

OUT="AppIcon.iconset"
DARK="#1E2329"
GOLD="#F0B90B"
SIZE=1024

magick -size ${SIZE}x${SIZE} "xc:$DARK" \
  -fill "$GOLD" -draw "ellipse $((SIZE/2)),$((SIZE/2)) $((SIZE*45/100)),$((SIZE*45/100)) 0,360" \
  -fill "$DARK" -draw "ellipse $((SIZE/2)),$((SIZE/2)) $((SIZE*35/100)),$((SIZE*35/100)) 0,360" \
  -font Helvetica-Bold -pointsize $((SIZE*45/100)) \
  -fill "$GOLD" -gravity center -annotate +0+$((SIZE*3/100)) 'R' \
  -define icon:auto-resize="256,128,64,48,32,16" \
  "tmp_1024.png"

# Generate all sizes
cp tmp_1024.png "$OUT/icon_512x512@2x.png"

magick tmp_1024.png -resize 512x512 "$OUT/icon_512x512.png"
magick tmp_1024.png -resize 512x512 "$OUT/icon_256x256@2x.png"
magick tmp_1024.png -resize 256x256 "$OUT/icon_256x256.png"
magick tmp_1024.png -resize 256x256 "$OUT/icon_128x128@2x.png"
magick tmp_1024.png -resize 128x128 "$OUT/icon_128x128.png"
magick tmp_1024.png -resize 64x64   "$OUT/icon_64x64.png"
magick tmp_1024.png -resize 32x32   "$OUT/icon_32x32.png"
magick tmp_1024.png -resize 32x32   "$OUT/icon_32x32@2x.png"   # 64 effective
magick tmp_1024.png -resize 16x16   "$OUT/icon_16x16.png"
magick tmp_1024.png -resize 16x16   "$OUT/icon_16x16@2x.png"   # 32 effective

rm tmp_1024.png

iconutil -c icns "$OUT"
rm -rf "$OUT"
echo "✅ AppIcon.icns created"
