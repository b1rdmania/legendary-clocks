# Legendary Clocks

3D-rendered clocks after famous designs: Hilfiker's station clock, Max Bill, Rams/Lubs for Braun, Jacobsen's Aarhus clock, Gino Valle's Solari Cifra 3 flip clock and the Nelson ball clock. Working concept for a macOS screensaver and an iOS app. The clocks are approximations, not official or licensed products.

## Layout

- `studio/rig.py`: Blender rig (scene, materials, mesh helpers, lighting sets, camera, layer split).
- `studio/clocks/*.py`: one model per clock. `build(r, hms)` returns dial height, wall colour and hand groups.
- `studio/render_view.sh <id> "<sets>"`: full-object view for the live page (`LENS`, `CROPM`, `NAME`, `TREATMENT`). `studio/render_face.sh`: dial-only view.
- `studio/editorial/`: separate stills. Angled cameras (`CAM`, `FSTOP`) are for these only, never for the live layers.
- `site/`: product page. `site/assets.sh` turns renders into web assets.
- `maxbill/`: first sculpt.

## Render

```sh
cd studio
./render_wall.sh station "day dusk night"
cd ../site && ./assets.sh
```

Needs Blender 4.2+ (Cycles) and ImageMagick. Each clock renders as a plate plus separate hand sprites, so the page turns real hands over a still render.

Lighting sets: `day`, `dusk`, `night`. A clock can override a set's light size, power and colour, but not its position: the page derives hand shadows from the key position.

## Art direction

Bill is the first study (`TREATMENT=study`): ivory room, a 50 mm lens with more space around the object, a large soft key for a quiet wall shadow, low softboxes that the rounded bezel catches and the near-flat dome cannot, and low-reflection glass so the numerals stay clear. Without `TREATMENT` the first treatment renders, kept for comparison.

## Fonts

| Clock | Font | Licence |
| --- | --- | --- |
| Bill (study) | Inter Display Light, `studio/fonts/` | SIL Open Font License 1.1 |
| Cifra numerals (render and page) | Inter Display Medium | SIL Open Font License 1.1 |
| Bill (first treatment) | ABC Diatype Light Trial, not included | trial licence, comparison only |
| Rams | Helvetica (macOS system font), not included | to replace |

Inter Display Light was chosen for Bill because its figures are thin, open and evenly spaced, the closest open-licensed match to the numerals on the original.
