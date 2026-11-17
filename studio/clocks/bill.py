# After Max Bill, 1956. 300 mm satin aluminium case, domed glass, thin numerals, red seconds hand.
# TREATMENT=study: the exhibition-catalogue art direction (ivory room, soft key, broad reflections, quiet glass,
# Inter Display Light numerals, SIL OFL, vendored in studio/fonts). Without it: the first treatment, kept for comparison.
import os
STUDY = os.environ.get("TREATMENT") == "study"
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(HERE, "fonts", "InterDisplay-Light.ttf") if STUDY else os.path.expanduser("~/Library/Fonts/ABCDiatype-Light-Trial.otf")

def build(r, hms):
    ALU = r.mat("alu", "#c9cbcd", rough=0.26 if STUDY else 0.32, metal=1.0, aniso=0.55 if STUDY else 0.6)
    DIAL = r.mat("dial", "#fbfaf6", rough=0.55)
    HAND = r.mat("hand", "#0a0a0a", rough=0.5)
    RED = r.mat("red", "#940a1c", rough=0.4)
    GLASS = r.mat("bglass", "#ffffff", rough=0.0, transmit=1.0, spec=0.22) if STUDY else r.GLASS
    Z = 0.030
    r.lathe("case", [(0.0, 0.0), (0.146, 0.0), (0.1495, 0.002), (0.150, 0.006), (0.150, 0.037),
        (0.1494, 0.0405), (0.1478, 0.0418), (0.1455, 0.042), (0.1432, 0.0415), (0.1420, 0.0400),
        (0.1415, 0.0365), (0.1409, Z + 0.001), (0.1385, Z + 0.0004)], ALU)
    r.disc("dial", 0.1405, 0.002, Z - 0.002, DIAL)
    r.ring_marks("ticks", r.PRINT, Z, lambda i: (0.0017, 0.011, 0.1335) if i % 5 == 0 else (0.0008, 0.0058, 0.1335))
    r.numerals(r.PRINT, Z + 0.00004, 0.1055, 0.0215, FONT)
    r.hand("hour",   Z + 0.0012, HAND, 0.0007, [("stadium", 0.074, 0.019, 0.0056)])
    r.hand("minute", Z + 0.0024, HAND, 0.0006, [("stadium", 0.118, 0.019, 0.0040)])
    r.hand("second", Z + 0.0034, RED,  0.0004, [("stadium", 0.128, 0.032, 0.0011)])
    r.bevel(r.disc("arbor", 0.0042, 0.0030, Z, HAND, 48), 0.0009)
    r.bevel(r.disc("seccap", 0.0026, 0.0009, Z + 0.0034, RED, 48), 0.0003)
    r.dome_glass(0.1425, 0.005, 0.0368, GLASS)
    hands = {"hour": ["hour"], "minute": ["minute"], "second": ["second"], "cap": ["arbor", "seccap"]}
    if not STUDY:
        return {"dial_z": 0.030, "wall": "#c6c3bd", "exposure": -0.95, "hands": hands}
    # key positions match the shared sets (the page derives hand shadows from them); size and colour change.
    # low and wide: the rounded bezel catches them, the near-flat dome (tilt < 10 deg) cannot
    BOX = [((-0.95, 0.05, 0.42), 0.24, 1.4, 110, (1.0, 0.98, 0.95)),      # tall window strip, left
           ((0.05, 0.95, 0.40), 1.4, 0.24, 70, (1.0, 0.99, 0.97))]       # long bounce, top
    return {"dial_z": 0.030, "wall": "#e3e0d8", "wall_bump": (60, 0.05, 520, 0.015), "exposure": -1.38, "hands": hands,
            "key_glossy": False,
            "sets": {
              "day":   dict(key=((-0.9, 1.1, 1.3), 1.0, 400, (1.0, 0.975, 0.94)), fill=((1.4, -0.6, 1.0), 2.6, 45, (1.0, 0.98, 0.95)),
                            strip=((-0.5, 0.9, 0.9), 0.35, 12, (1, 1, 1)), world=((0.78, 0.76, 0.72), 0.2), softboxes=BOX),
              "dusk":  dict(key=((1.35, 0.45, 0.62), 0.9, 320, (1.0, 0.70, 0.45)), fill=((-1.4, 0.2, 1.0), 2.6, 26, (0.62, 0.68, 0.95)),
                            strip=((0.9, 0.7, 0.8), 0.3, 8, (1.0, 0.8, 0.6)), world=((0.42, 0.40, 0.46), 0.16),
                            softboxes=[(b[0], b[1], b[2], b[3] * 0.35, (0.85, 0.80, 0.85)) for b in BOX]),
              "night": dict(key=((-0.75, -0.7, 0.85), 0.9, 85, (1.0, 0.76, 0.52)), fill=((1.2, 1.0, 1.2), 2.6, 6, (0.55, 0.62, 0.95)),
                            strip=((-0.6, -0.4, 0.9), 0.3, 4, (1.0, 0.8, 0.6)), world=((0.14, 0.14, 0.2), 0.05),
                            softboxes=[(b[0], b[1], b[2], b[3] * 0.12, (1.0, 0.82, 0.62)) for b in BOX]),
            }}
