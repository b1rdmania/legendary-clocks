# After Max Bill, 1956. 300 mm satin aluminium case, domed glass, thin numerals, red seconds hand.
def build(r, hms):
    ALU = r.mat("alu", "#c4c7ca", rough=0.32, metal=1.0, aniso=0.6)
    DIAL = r.mat("dial", "#fbfaf6", rough=0.55)
    HAND = r.mat("hand", "#0a0a0a", rough=0.5)
    RED = r.mat("red", "#940a1c", rough=0.4)
    Z = 0.030
    r.lathe("case", [(0.0, 0.0), (0.146, 0.0), (0.1495, 0.002), (0.150, 0.006), (0.150, 0.037),
        (0.1494, 0.0405), (0.1478, 0.0418), (0.1455, 0.042), (0.1432, 0.0415), (0.1420, 0.0400),
        (0.1415, 0.0365), (0.1409, Z + 0.001), (0.1385, Z + 0.0004)], ALU)
    r.disc("dial", 0.1405, 0.002, Z - 0.002, DIAL)
    r.ring_marks("ticks", r.PRINT, Z, lambda i: (0.0017, 0.011, 0.1335) if i % 5 == 0 else (0.0008, 0.0058, 0.1335))
    r.numerals(r.PRINT, Z + 0.00004, 0.1055, 0.0215, __import__("os").path.expanduser("~/Library/Fonts/ABCDiatype-Light-Trial.otf"))
    r.hand("hour",   Z + 0.0012, HAND, 0.0007, [("stadium", 0.074, 0.019, 0.0056)])
    r.hand("minute", Z + 0.0024, HAND, 0.0006, [("stadium", 0.118, 0.019, 0.0040)])
    r.hand("second", Z + 0.0034, RED,  0.0004, [("stadium", 0.128, 0.032, 0.0011)])
    r.bevel(r.disc("arbor", 0.0042, 0.0030, Z, HAND, 48), 0.0009)
    r.bevel(r.disc("seccap", 0.0026, 0.0009, Z + 0.0034, RED, 48), 0.0003)
    r.dome_glass(0.1425, 0.005, 0.0368, r.GLASS)
    return {"dial_z": 0.030, "wall": "#c6c3bd", "exposure": -0.95, "hands": {"hour": ["hour"], "minute": ["minute"], "second": ["second"], "cap": ["arbor", "seccap"]}}
