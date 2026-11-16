#!/bin/zsh
# Dial-only view of one clock. Usage: ./render_face.sh <clock> "<lighting sets>" [RES] [SAMPLES]
# Lens 110: the 262 mm track fills ~70% of the frame. Hand sprites are the centre 70%.
set -e
cd "${0:A:h}"
ID=$1; SETS=(${=2:-day}); RES=${3:-3200}; SMP=${4:-48}
for LT in $SETS; do
  OUT=player/clocks/$ID/face/$LT; mkdir -p $OUT
  FACE=1 LENS=110 LIGHTING=$LT LAYER=noglass RES=$RES SAMPLES=$SMP blender -b -P rig.py -- $ID $PWD/$OUT/noglass.png 2>&1 | grep -E "Traceback|WROTE" || true
  for H in hour minute second cap; do
    EXTRA=0; [[ $H == second || $H == cap ]] && EXTRA=${RED_EV:-0}
    FACE=1 LENS=110 CROP=1 CROPM=0.15 LIGHTING=$LT LAYER=$H RES=$RES SAMPLES=$((SMP*3/4)) EV_EXTRA=$EXTRA blender -b -P rig.py -- $ID $PWD/$OUT/$H.png 2>&1 | grep -E "Traceback|WROTE" || true
  done
  ( cd $OUT
    magick noglass.png -quality 92 noglass.jpg && rm -f noglass.png
    for H in hour minute second; do
      magick $H.png -alpha extract -blur 0x12 -background black -alpha shape ${H}_s.png
      magick $H.png -alpha extract -blur 0x3 -background black -alpha shape ${H}_c.png
    done
    echo "$ID face $LT wall: $(magick noglass.jpg -gravity center -crop 300x300+0+0 -resize 1x1\! -format '#%[hex:p{0,0}]' info: | cut -c1-7) edge: $(magick noglass.jpg -crop 200x200+0+0 -resize 1x1\! -format '#%[hex:p{0,0}]' info: | cut -c1-7)" )
done
echo "$ID FACE DONE"
