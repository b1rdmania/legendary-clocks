#!/bin/zsh
# Render every layer of one clock and turn them into player assets.
# Usage: ./render.sh <clock id> [RES] [SAMPLES]
set -e
cd "${0:A:h}"
ID=$1; RES=${2:-3000}; SMP=${3:-160}
OUT=player/clocks/$ID; mkdir -p $OUT
for L in noglass plate hour minute second cap; do
  S=$SMP; [[ $L == hour || $L == minute || $L == second || $L == cap ]] && S=$((SMP*2/3))
  LAYER=$L RES=$RES SAMPLES=$S blender -b -P rig.py -- $ID $PWD/$OUT/$L.png 2>&1 | grep -E "Traceback|Error|WROTE" || true
done
cd $OUT
magick noglass.png -quality 90 noglass.jpg
magick plate.png noglass.png -compose minus_dst -composite -alpha off -quality 92 glass.jpg
for h in hour minute second cap; do magick $h.png -gravity center -crop 1440x1440+0+0 +repage $h.png; done
for h in hour minute second; do magick $h.png -alpha extract -blur 0x9 -background black -alpha shape ${h}_s.png; done
rm -f plate.png noglass.png
echo "$ID wall: $(magick noglass.jpg \( -clone 0 -crop 200x200+0+0 \) \( -clone 0 -gravity southeast -crop 200x200+0+0 \) -delete 0 -append -resize 1x1\! -format '#%[hex:p{0,0}]' info: | cut -c1-7)"
