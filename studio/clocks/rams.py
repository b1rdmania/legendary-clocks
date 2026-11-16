# After Dieter Rams & Dietrich Lubs (Braun desk clock, 1980s). Soft square black case,
# recessed black dial, white printed track and numerals, white hands, yellow seconds hand.
import math
def build(r, hms):
    CASE = r.mat("case", "#1b1c1d", rough=0.62)
    DIAL = r.mat("dial", "#111213", rough=0.7)
    WHITE = r.mat("white", "#f2f2ee", rough=0.55)
    HANDW = r.mat("handw", "#f4f4f0", rough=0.4)
    YEL = r.mat("yellow", "#c99800", rough=0.4)
    FRONT = 0.050
    case = r.slab("case", r.rounded_rect_pts(0.300, 0.300, 0.060, 16), FRONT, 0.0, CASE)
    r.bevel(case, 0.006, 4); r.cut_hole(case, 0.1255, 0.04, FRONT)
    Z = FRONT - 0.012
    r.disc("dial", 0.1256, 0.002, Z - 0.002, DIAL)
    r.ring_marks("ticks", WHITE, Z, lambda i: (0.0026, 0.013, 0.1205) if i % 5 == 0 else (0.0011, 0.0065, 0.1205))
    r.numerals(WHITE, Z + 0.00004, 0.088, 0.0185, "/System/Library/Fonts/Helvetica.ttc")
    r.hand("hour",   Z + 0.0012, HANDW, 0.0008, [("taper", 0.060, 0.012, 0.0050, 0.0062)])
    r.hand("minute", Z + 0.0022, HANDW, 0.0007, [("taper", 0.098, 0.012, 0.0036, 0.0048)])
    r.hand("second", Z + 0.0032, YEL,   0.0005, [("stadium", 0.108, 0.030, 0.0016)])
    r.bevel(r.disc("arbor", 0.0072, 0.0040, Z, YEL, 64), 0.0008)
    r.flat_glass(0.1262, FRONT - 0.004, r.GLASS)
    return {"dial_z": FRONT - 0.012, "wall": "#d9d7d2", "exposure": -1.15,
            "hands": {"hour": ["hour"], "minute": ["minute"], "second": ["second"], "cap": ["arbor"]}}
