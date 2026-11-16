#!/bin/zsh
# Full-clock view (case, glass, wall shadow). Usage: ./render_wall.sh <clock> "<lighting sets>" [RES] [SAMPLES]
# Lens 72. Hand sprites are the centre 48% of the frame.
set -e
cd "${0:A:h}"
ID=$1; SETS=(${=2:-day}); RES=${3:-3000}; SMP=${4:-64}
for LT in $SETS; do
  OUT=player/clocks/$ID/wall/$LT; mkdir -p $OUT
  for L in plate noglass; do
    LIGHTING=$LT LAYER=$L RES=$RES SAMPLES=$SMP blender -b -P rig.py -- $ID $PWD/$OUT/$L.png 2>&1 | grep -E "Traceback|WROTE" || true
  done
  for H in hour minute second cap; do
    EXTRA=0; [[ $H == second || $H == cap ]] && EXTRA=${RED_EV:-0}
    CROP=1 CROPM=0.26 LIGHTING=$LT LAYER=$H RES=$RES SAMPLES=$((SMP*3/4)) EV_EXTRA=$EXTRA blender -b -P rig.py -- $ID $PWD/$OUT/$H.png 2>&1 | grep -E "Traceback|WROTE" || true
  done
  ( cd $OUT
    magick noglass.png -quality 92 noglass.jpg
    magick plate.png noglass.png -compose minus_dst -composite -alpha off -quality 92 glass.jpg
    rm -f plate.png noglass.png
    for H in hour minute second; do
      magick $H.png -alpha extract -blur 0x9 -background black -alpha shape ${H}_s.png
      magick $H.png -alpha extract -blur 0x3 -background black -alpha shape ${H}_c.png
    done
    echo "$ID wall $LT edge: $(magick noglass.jpg \( -clone 0 -crop 200x200+0+0 \) \( -clone 0 -gravity southeast -crop 200x200+0+0 \) -delete 0 -append -resize 1x1\! -format '#%[hex:p{0,0}]' info: | cut -c1-7)" )
done
echo "$ID WALL DONE"
