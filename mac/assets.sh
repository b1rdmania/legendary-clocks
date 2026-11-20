#!/bin/zsh
# Render folders -> app resources. Full 3000 px plates: sharp on 5K and 6K displays.
# A clock's art-direction study (player/clocks/<id>/study/<look>) replaces its wall renders when present.
set -e
cd "${0:A:h}"
P=../studio/player/clocks; R=Resources/Clocks
for id in station bill jacobsen rams cifra ball; do
  V=wall; [[ -d $P/$id/study ]] && V=study
  for lk in day dusk night; do
    S=$P/$id/$V/$lk; [[ -f $S/noglass.jpg ]] || continue
    D=$R/$id/$lk; rm -rf $D; mkdir -p $D
    magick $S/noglass.jpg -quality 92 $D/plate.jpg
    [[ -f $S/glass.jpg ]] && magick $S/glass.jpg -quality 85 $D/glass.jpg
    for f in hour minute second cap hour_s minute_s second_s hour_c minute_c second_c; do
      [[ -f $S/$f.png ]] && magick $S/$f.png -define webp:alpha-quality=95 -quality 92 $D/$f.webp
    done
    echo "$id $lk <- $V"
  done
done
cp ../studio/fonts/InterDisplay-Medium.ttf Resources/
du -sh $R
