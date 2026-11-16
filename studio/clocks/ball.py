# After the George Nelson studio ball clock, 1948. Twelve lacquered balls on brass rods,
# a brass hub, black spade hands. No dial and no glass: the wall is the face.
import math
COLS = ["#c62a1e", "#e8ae10", "#1d55a0", "#e06d12", "#2a8048", "#151515"] * 2
def spade(length, shaft, leaf):
    """Shaft plus a convex leaf: concave outlines fill badly as one face."""
    leaf_pts = []
    for k in range(0, 13):
        t = k / 12; y = length * (0.52 + 0.48 * t)
        x = (leaf / 2 * math.sin(math.pi / 2 * t / 0.4)) if t < 0.4 else leaf / 2 * (1 - (t - 0.4) / 0.6) ** 1.1
        leaf_pts.append((max(x, 1e-5), y))
    leaf_pts = leaf_pts[:-1] + [(0, length)] + [(-x, y) for x, y in reversed(leaf_pts[1:-1])]
    leaf_pts = [(0.0, length * 0.52)] + leaf_pts[1:]
    return [("taper", length * 0.62, length * 0.16, shaft, shaft), ("poly", leaf_pts)]
def build(r, hms):
    BRASS = r.mat("brass", "#b8913f", rough=0.3, metal=1.0)
    HAND = r.mat("hand", "#111111", rough=0.45)
    Z0 = 0.012
    import bmesh
    for i in range(12):
        a = (i + 1) * math.tau / 12
        x, y = math.sin(a), math.cos(a)
        rod = r.disc(f"rod{i}", 0.0022, 0.104, 0, BRASS, 24)      # a thin cylinder, then laid along the spoke
        rod.rotation_euler = (-math.pi / 2, 0, -a); rod.location = (x * 0.022, y * 0.022, Z0 + 0.008)
        bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=32, radius=0.0175)
        ball = r.smooth(r.obj(f"ball{i}", bm, r.mat(f"lac{i}", COLS[i], rough=0.22, coat=0.35)), 80)
        ball.location = (x * 0.130, y * 0.130, Z0 + 0.008)
    hub = r.disc("hub", 0.024, 0.016, 0.0, BRASS, 96); r.bevel(hub, 0.003, 3)
    Z = 0.016
    r.hand("hour",   Z + 0.0010, HAND, 0.0012, spade(0.084, 0.0060, 0.026))
    r.hand("minute", Z + 0.0030, HAND, 0.0010, spade(0.116, 0.0050, 0.021))
    r.bevel(r.disc("arbor", 0.0050, 0.0050, Z, BRASS, 48), 0.0012)
    return {"wall": "#d4d8cf", "exposure": -1.25,
            "hands": {"hour": ["hour"], "minute": ["minute"], "second": [], "cap": ["arbor"]}}
