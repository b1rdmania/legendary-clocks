# After Gino Valle, Solari Cifra 3, 1965. A matte black cylinder lying on its side; the front is cut flat
# and holds two flap units, hours and minutes. Blank cards here; the page draws the numerals and the flips.
import math, os
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def build(r, hms):
    bm_ = r.bmesh
    BODY = r.mat("body", "#141517", rough=0.58, coat=0.12, coat_rough=0.4, bump=(3000, 0.02))
    CAP = r.mat("cap", "#1c1d1f", rough=0.45)
    CARD = r.mat("card", "#1d1e20", rough=0.42, coat=0.25, coat_rough=0.3)
    SLOT = r.mat("slot", "#050505", rough=0.8)
    R, LEN, AX = 0.055, 0.196, 0.075            # radius, length, axis height off the wall
    CUT = 0.79 * R                              # flat front: chord height 2 * sqrt(R^2 - CUT^2) = 0.067
    bm = bm_.new()
    bm_.ops.create_cone(bm, cap_ends=True, segments=160, radius1=R, radius2=R, depth=LEN)
    bm_.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=r.Matrix.Rotation(math.pi / 2, 3, "Y"))
    cut = bm_.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, CUT), plane_no=(0, 0, 1), clear_outer=True)
    edges = [e for e in cut["geom_cut"] if isinstance(e, bm_.types.BMEdge)]
    bm_.ops.edgeloop_fill(bm, edges=edges)
    bm_.ops.translate(bm, verts=bm.verts, vec=(0, 0, AX))
    for f in bm.faces: f.smooth = abs(f.normal.x) < 0.5 and f.normal.z < 0.99   # round sides smooth, flat ends and front flat
    for e in bm.edges: e.smooth = all(f.smooth for f in e.link_faces)           # sharp where round meets flat
    body = r.obj("case", bm, BODY)
    for sx in (-1, 1):                          # end rings, a hair proud
        bm = bm_.new(); bm_.ops.create_cone(bm, cap_ends=True, segments=160, radius1=R + 0.0008, radius2=R + 0.0008, depth=0.004)
        bm_.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=r.Matrix.Rotation(math.pi / 2, 3, "Y"))
        c = bm_.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, CUT), plane_no=(0, 0, 1), clear_outer=True)
        bm_.ops.edgeloop_fill(bm, edges=[e for e in c["geom_cut"] if isinstance(e, bm_.types.BMEdge)])
        bm_.ops.translate(bm, verts=bm.verts, vec=(sx * (LEN / 2 - 0.0015), 0, AX))
        for f in bm.faces: f.smooth = abs(f.normal.x) < 0.5
        for e in bm.edges: e.smooth = all(f.smooth for f in e.link_faces)
        r.obj(f"cap{sx}", bm, CAP)
    FZ = AX + CUT
    # a shallow recess panel and two flap units, each a top and bottom card split by a thin gap
    r.slab("slot", r.rounded_rect_pts(0.154, 0.063, 0.004), 0.0004, FZ, SLOT)
    W, H, G = 0.0705, 0.0585, 0.0012
    for cx in (-0.036, 0.036):
        for sy in (1, -1):
            pts = [(x + cx, y + sy * (H / 4 + G / 4)) for x, y in r.rounded_rect_pts(W, H / 2 - G / 2, 0.0025)]
            o = r.slab(f"card{cx}{sy}", pts, 0.0016, FZ + 0.0004, CARD); r.bevel(o, 0.0004, 2)
    if os.environ.get("DIGITS"):                # stills only: numerals on the cards, e.g. DIGITS=10:09
        INK = r.mat("ink", "#efede6", rough=0.5); font = r.bpy.data.fonts.load(os.path.join(HERE, "fonts", "InterDisplay-Medium.ttf"))
        for cx, txt in zip((-0.036, 0.036), os.environ["DIGITS"].split(":")):
            cu = r.bpy.data.curves.new("d" + txt, "FONT"); cu.body = txt; cu.font = font; cu.size = H * 0.92
            cu.align_x = "CENTER"; cu.align_y = "CENTER"; cu.extrude = 0.00002
            o = r.bpy.data.objects.new("d" + txt, cu); r.sc.collection.objects.link(o); o.location = (cx, 0, FZ + 0.0021); o.data.materials.append(INK)
        r.slab("split", r.rounded_rect_pts(0.150, G, 0.0002), 0.0003, FZ + 0.0021, SLOT)
    return {"dial_z": FZ + 0.002, "wall": "#d8d6d1", "exposure": -1.0, "hands": {}}
