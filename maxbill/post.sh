#!/bin/zsh
# Turn the Blender layers into web assets. Run from maxbill/.
set -e
cd live
# base plate: clock without hands or glass
magick noglass.png -quality 90 noglass.jpg
# glass reflection only: (with glass) - (without glass), added back on top in the page
magick plate.png noglass.png -compose minus_dst -composite -alpha off -quality 92 glass.jpg
# hands: 1440px square around the arbor, plus a soft black shadow from each alpha
for h in hour minute second cap; do
  magick $h.png -gravity center -crop 1440x1440+0+0 +repage ${h}_c.png
  mv ${h}_c.png $h.png
done
for h in hour minute second; do
  magick $h.png -alpha extract -blur 0x9 -background black -alpha shape ${h}_s.png
done
# wall colour for the page background: mean of the plate's corners
magick noglass.png \( -clone 0 -crop 200x200+0+0 \) \( -clone 0 -gravity southeast -crop 200x200+0+0 \) -delete 0 -append -resize 1x1\! -format '#%[hex:p{0,0}]' info:
