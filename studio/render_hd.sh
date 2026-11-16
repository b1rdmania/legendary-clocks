#!/bin/zsh
# Full-quality render of one clock in all lighting sets. Usage: ./render_hd.sh <clock> [RES] [SAMPLES]
set -e
cd "${0:A:h}"
ID=$1; RES=${2:-4000}; SMP=${3:-128}
for LT in day dusk night; do
  OUT=player/clocks/$ID/$LT; mkdir -p $OUT
  for P in noglass plate; do LIGHTING=$LT LAYER=$P RES=$RES SAMPLES=$SMP blender -b -P rig.py -- $ID $PWD/$OUT/$P.png 2>&1 | grep -E "Traceback|WROTE" || true; done
  for H in hour minute second cap; do
    EXTRA=0; [[ $H == second || $H == cap ]] && EXTRA=${RED_EV:-0}
    CROP=1 LIGHTING=$LT LAYER=$H RES=$RES SAMPLES=$((SMP*3/4)) EV_EXTRA=$EXTRA blender -b -P rig.py -- $ID $PWD/$OUT/$H.png 2>&1 | grep -E "Traceback|WROTE" || true
  done
  ( cd $OUT
    magick noglass.png -quality 90 noglass.jpg
    magick plate.png noglass.png -compose minus_dst -composite -alpha off -quality 92 glass.jpg
    for H in hour minute second; do
      magick $H.png -alpha extract -blur 0x14 -background black -alpha shape ${H}_s.png
      magick $H.png -alpha extract -blur 0x4 -background black -alpha shape ${H}_c.png
    done
    rm -f plate.png noglass.png
    echo "$ID $LT wall: $(magick noglass.jpg \( -clone 0 -crop 260x260+0+0 \) \( -clone 0 -gravity southeast -crop 260x260+0+0 \) \( -clone 0 -gravity northeast -crop 260x260+0+0 \) \( -clone 0 -gravity southwest -crop 260x260+0+0 \) -delete 0 -append -resize 1x1\! -format '#%[hex:p{0,0}]' info: | cut -c1-7)" )
done
echo "$ID HD DONE"
