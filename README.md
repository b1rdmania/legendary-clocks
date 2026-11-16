# Legendary Clocks

3D-rendered clocks after famous designs: Hilfiker's station clock, Max Bill, Rams/Lubs for Braun, Jacobsen's Roman, the Gare d'Orsay and the Nelson ball clock. Working concept for a macOS screensaver and an iOS app. The clocks are approximations, not official or licensed products.

## Layout

- `studio/rig.py`: Blender rig (scene, materials, mesh helpers, lighting sets, camera, layer split).
- `studio/clocks/*.py`: one model per clock. `build(r, hms)` returns dial height, wall colour and hand groups.
- `studio/render_wall.sh <id> "<sets>"`: full-clock view. `studio/render_face.sh`: dial-only view.
- `site/`: product page. `site/assets.sh` turns renders into web assets.
- `maxbill/`: first sculpt.

## Render

```sh
cd studio
./render_wall.sh station "day dusk night"
cd ../site && ./assets.sh
```

Needs Blender 4.2+ (Cycles) and ImageMagick. Each clock renders as a plate plus separate hand sprites, so the page turns real hands over a still render.

Lighting sets: `day`, `dusk`, `night`. The Bill numerals use ABC Diatype Light from `~/Library/Fonts`; supply your own font there.
