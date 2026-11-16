# After Arne Jacobsen's Roman clock, 1942 (Aarhus City Hall). Slim steel bezel, white dial,
# slender bar indices with longer quarters, fine minute ticks, thin black hands.
def build(r, hms):
    STEEL = r.mat("steel", "#c9cbcd", rough=0.28, metal=1.0, aniso=0.5)
    DIAL = r.mat("dial", "#f8f8f5", rough=0.45, coat=0.2, coat_rough=0.2, bump=(5200, 0.01))
    INK = r.mat("ink", "#111111", rough=0.5)
    HAND = r.mat("hand", "#0d0d0d", rough=0.38, coat=0.3, coat_rough=0.25)
    AR = r.mat("arglass", "#ffffff", rough=0.0, transmit=1.0, ior=1.52, spec=0.35)
    Z = 0.030
    r.lathe("case", [(0.0, 0.0), (0.147, 0.0), (0.1497, 0.003), (0.150, 0.008), (0.150, 0.036),
        (0.1494, 0.0392), (0.1478, 0.0402), (0.1450, 0.0404), (0.1430, 0.0396), (0.1424, 0.0380),
        (0.1424, Z + 0.001), (0.1404, Z + 0.0004)], STEEL, steps=256)
    r.disc("dial", 0.1424, 0.002, Z - 0.002, DIAL, 256)
    def marks(i):
        if i % 15 == 0: return (0.0021, 0.034, 0.1330)     # quarters
        if i % 5 == 0: return (0.0017, 0.024, 0.1330)      # hours
        return (0.0006, 0.0045, 0.1330)                    # minutes
    r.ring_marks("ticks", INK, Z, marks, t=0.00015, bev=0.00006)
    r.hand("hour",   Z + 0.0012, HAND, 0.0008, [("taper", 0.078, 0.020, 0.0018, 0.0052)])
    r.hand("minute", Z + 0.0024, HAND, 0.0007, [("taper", 0.124, 0.022, 0.0014, 0.0040)])
    r.hand("second", Z + 0.0034, HAND, 0.0004, [("taper", 0.128, 0.034, 0.0008, 0.0010), ("circle", -0.026, 0.0038)])
    r.bevel(r.disc("arbor", 0.0040, 0.0036, Z, HAND, 64), 0.0008, 3)
    r.flat_glass(0.1428, 0.0372, AR)
    return {"dial_z": Z, "wall": "#cfd0cf", "exposure": -0.9,
            "hands": {"hour": ["hour"], "minute": ["minute"], "second": ["second"], "cap": ["arbor"]}}
