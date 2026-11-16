# After Hans Hilfiker, 1944 (red seconds disc 1953). 300 mm, powder-coated anthracite case,
# lacquered dial with pad-printed raised bars, satin black hands, lacquered red seconds hand,
# flat anti-reflective mineral glass.
def build(r, hms):
    CASE = r.mat("case", "#24272a", rough=0.5, coat=0.18, coat_rough=0.35, bump=(2600, 0.05, 180, 0.012))
    DIAL = r.mat("dial", "#f9f9f5", rough=0.42, coat=0.25, coat_rough=0.18, bump=(5200, 0.012))
    INK = r.mat("ink", "#0a0a0a", rough=0.52, bump=(7000, 0.02))
    HAND = r.mat("hand", "#0b0b0b", rough=0.36, coat=0.3, coat_rough=0.25)
    RED = r.mat("red", "#9c000c", rough=0.3, coat=0.6, coat_rough=0.12)
    AR = r.mat("arglass", "#ffffff", rough=0.0, transmit=1.0, ior=1.52, spec=0.35)
    Z = 0.030
    r.lathe("case", [(0.0, 0.0), (0.146, 0.0), (0.1497, 0.003), (0.150, 0.008), (0.150, 0.040),
        (0.1497, 0.0436), (0.1486, 0.0452), (0.1466, 0.0460), (0.1412, 0.0460), (0.1395, 0.0454),
        (0.1386, 0.0440), (0.1384, 0.0420), (0.1384, Z + 0.001), (0.1365, Z + 0.0004)], CASE, steps=256)
    r.disc("dial", 0.1384, 0.002, Z - 0.002, DIAL, 256)
    r.ring_marks("ticks", INK, Z, lambda i: (0.0076, 0.0330, 0.1310) if i % 5 == 0 else (0.0025, 0.0095, 0.1310),
                 t=0.0003, bev=0.00012)
    r.hand("hour",   Z + 0.0012, HAND, 0.0012, [("taper", 0.085, 0.028, 0.0094, 0.0118)])
    r.hand("minute", Z + 0.0026, HAND, 0.0010, [("taper", 0.123, 0.030, 0.0068, 0.0100)])
    r.hand("second", Z + 0.0040, RED,  0.0006, [("taper", 0.080, 0.041, 0.0024, 0.0024), ("circle", 0.0835, 0.0108)])
    r.bevel(r.disc("arbor", 0.0050, 0.0040, Z, HAND, 64), 0.0010, 3)
    r.bevel(r.disc("seccap", 0.0040, 0.0008, Z + 0.0046, RED, 64), 0.0003, 3)
    g = r.flat_glass(0.1390, 0.0400, AR); g.data.materials[0] = AR
    return {"dial_z": 0.030, "wall": "#3d464c", "wall_bump": (40, 0.18, 400, 0.05),
            "hands": {"hour": ["hour"], "minute": ["minute"], "second": ["second"], "cap": ["arbor", "seccap"]}}
