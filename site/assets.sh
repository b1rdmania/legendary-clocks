#!/bin/zsh
# Copy player renders into the site as web assets, and composite 10:09 stills.
# Wall views:  player/clocks/<id>/*            -> assets/<id>/wall/day/
# Dial views:  player/clocks/<id>/face/<look>/ -> assets/<id>/dial/<look>/
set -e
cd "${0:A:h}"
P=../studio/player/clocks
conv() {  # src dir -> dst dir [plate px]. Hands scale by the same factor as the plate.
  local W=${3:-2400}
  mkdir -p $2
  [[ -f $1/noglass.jpg ]] || return 0
  local S=$(magick identify -format %w $1/noglass.jpg); local PCT=$(( W * 100 / S ))
  magick $1/noglass.jpg -resize ${W}x${W} -quality 86 $2/plate.jpg
  [[ -f $1/glass.jpg ]] && magick $1/glass.jpg -resize ${W}x${W} -quality 80 $2/glass.jpg
  for f in hour minute second cap hour_s minute_s second_s hour_c minute_c second_c; do
    [[ -f $1/$f.png ]] && magick $1/$f.png -resize ${PCT}% -define webp:alpha-quality=90 -quality 88 $2/$f.webp
  done
  return 0
}
# assets/ for large screens, assets-sm/ (1200 px plates, a quarter of the memory) for phones
for id in station bill rams ball jacobsen orsay; do
  conv $P/$id assets/$id/wall/day; conv $P/$id assets-sm/$id/wall/day 1200
  for lk in day dusk night; do [[ -d $P/$id/face/$lk ]] && { conv $P/$id/face/$lk assets/$id/dial/$lk; conv $P/$id/face/$lk assets-sm/$id/dial/$lk 1200; }; done
done
# stills: plate + hands at 10:09:36, centre crop
still() {  # dir out size crop_fraction
  local d=$1; [[ -f $d/plate.jpg ]] || return 0
  local S=$(magick identify -format %w $d/plate.jpg); local H=$(magick identify -format %w $d/hour.webp)
  local args=($d/plate.jpg)
  for pair in "hour_s:304.8" "minute_s:57.6" "second_s:216" "hour:304.8" "minute:57.6" "second:216" "cap:0"; do
    local f=${pair%%:*} a=${pair##*:}
    [[ -f $d/$f.webp ]] && args+=( \( $d/$f.webp -background none -rotate $a \) -gravity center -composite )
  done
  local C=$(( S * $4 / 100 ))
  magick "${args[@]}" -gravity center -crop ${C}x${C}+0+0 +repage -resize ${3}x${3} -quality 86 $2
}
mkdir -p stills
for id in station bill rams ball jacobsen orsay; do still assets/$id/wall/day stills/$id-wall.jpg 1000 62; done
for id in station bill rams jacobsen orsay; do for lk in day dusk night; do still assets/$id/dial/$lk stills/$id-dial-$lk.jpg 1000 80; done; done
# macro: full-resolution crop around twelve o'clock, hands included
if [[ -f assets/station/dial/day/plate.jpg ]]; then
  d=assets/station/dial/day
  magick $d/plate.jpg \( $d/hour_s.webp -background none -rotate 304.8 \) -gravity center -composite \( $d/minute_s.webp -background none -rotate 57.6 \) -gravity center -composite \
    \( $d/hour.webp -background none -rotate 304.8 \) -gravity center -composite \( $d/minute.webp -background none -rotate 57.6 \) -gravity center -composite \
    \( $d/second.webp -background none -rotate 216 \) -gravity center -composite \( $d/cap.webp -background none \) -gravity center -composite \
    -gravity center -crop 820x820+0-330 +repage -resize 900x900 -quality 88 stills/station-macro.jpg
fi
du -sh assets assets-sm stills; ls stills
