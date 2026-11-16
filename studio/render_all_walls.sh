#!/bin/zsh
cd "${0:A:h}"
for id in station bill rams jacobsen orsay ball; do ./render_wall.sh $id day; done
for id in station bill rams jacobsen orsay ball; do ./render_wall.sh $id "dusk night"; done
echo ALL WALLS DONE
