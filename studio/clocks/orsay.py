# After the great clock of the Gare d'Orsay, 1900, seen from inside the museum: a glowing glass
# face crossed by iron glazing bars, gilded Roman numerals, dark iron hands. No seconds hand.
import math
def build(r, hms):
    GLOW = r.mat("dial", "#efe6d2", rough=0.6, emit=("#fff1d6", 2.2), bump=(900, 0.02))
    IRON = r.mat("iron", "#1d1b19", rough=0.55, metal=0.5)
    GILT = r.mat("gilt", "#b9924a", rough=0.32, metal=1.0)
    Z = 0.030
    r.lathe("case", [(0.0, 0.0), (0.150, 0.0), (0.150, 0.040), (0.1488, 0.0418), (0.1440, 0.0420),
        (0.1418, 0.0404), (0.1412, Z + 0.001), (0.1395, Z + 0.0004)], IRON, steps=256)
    r.disc("dial", 0.1412, 0.002, Z - 0.002, GLOW, 256)
    # glazing: concentric rings and radial bars, proud of the glass
    for k, (rr, w) in enumerate(((0.1225, 0.0022), (0.0955, 0.0022), (0.040, 0.0018))):
        t = 0.0012
        r.lathe(f"ring{k}", [(rr - w / 2, Z), (rr - w / 2, Z + t), (rr + w / 2, Z + t), (rr + w / 2, Z)], IRON, steps=256)
    r.ring_marks("bars", IRON, Z, lambda i: (0.0018, 0.0555, 0.0955) if i % 5 == 0 else None, t=0.0012, bev=0.0003)
    r.ring_marks("minutes", GILT, Z, lambda i: (0.0016, 0.0062, 0.1395) if i % 5 else (0.0034, 0.0110, 0.1395), t=0.0006, bev=0.0002)
    r.numerals(GILT, Z + 0.0004, 0.1090, 0.0205, "/System/Library/Fonts/Supplemental/Bodoni 72 Smallcaps Book.ttf",
               ["I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"], radial=True, extrude=0.0004)
    r.bevel(r.disc("rosette", 0.0170, 0.0030, Z, IRON, 96), 0.0008, 3)
    def spade(length, shaft, leaf):
        pts = []
        for k in range(13):
            t = k / 12; y = length * (0.58 + 0.42 * t)
            x = (leaf / 2 * math.sin(math.pi / 2 * t / 0.4)) if t < 0.4 else leaf / 2 * (1 - (t - 0.4) / 0.6) ** 1.1
            pts.append((max(x, 1e-5), y))
        pts = [(0.0, length * 0.58)] + pts[1:-1] + [(0, length)] + [(-x, y) for x, y in reversed(pts[1:-1])]
        return [("taper", length * 0.66, length * 0.18, shaft, shaft * 1.3), ("poly", pts), ("circle", -length * 0.16, shaft * 1.6)]
    r.hand("hour",   Z + 0.0030, IRON, 0.0012, spade(0.082, 0.0042, 0.016))
    r.hand("minute", Z + 0.0046, IRON, 0.0010, spade(0.120, 0.0032, 0.012))
    r.bevel(r.disc("arbor", 0.0060, 0.0060, Z + 0.0030, GILT, 64), 0.0012, 3)
    return {"dial_z": Z, "wall": "#2a2622", "exposure": -1.6,
            "hands": {"hour": ["hour"], "minute": ["minute"], "second": [], "cap": ["arbor"]}}
