#!/bin/zsh
# Renders every missing wall look, then darkens Station's red. Safe to re-run: finished looks are skipped.
cd "${0:A:h}"
for LT in day dusk night; do for id in station bill rams jacobsen orsay ball; do
  [[ -f player/clocks/$id/wall/$LT/second_c.png ]] || ./render_wall.sh $id $LT
done; done
echo ALL WALLS DONE
