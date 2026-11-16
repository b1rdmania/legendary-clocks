# Shared studio rig: scene, materials, mesh helpers, lights, camera, layer split, render.
# Usage: LAYER=plate|noglass|hour|minute|second|cap RES=3000 SAMPLES=160 \
#        blender -b -P rig.py -- <clock id> <out.png>
import bpy, bmesh, math, sys, os, importlib.util
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:]
CLOCK, OUT = argv[0], argv[1]
LAYER = os.environ.get("LAYER")
RES = int(os.environ.get("RES", 1400))
SAMPLES = int(os.environ.get("SAMPLES", 128))
HMS = [int(x) for x in os.environ.get("HMS", "0:00:00").split(":")]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
TAU = math.tau

# ---------- materials
def srgb(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + .055) / 1.055) ** 2.4 for x in c)

def mat(name, hexcol, rough=0.5, metal=0.0, aniso=0.0, transmit=0.0, ior=1.5, coat=0.0,
        bump=None, spec=None, coat_rough=None, emit=None):
    """bump=(scale, strength[, scale2, strength2]): procedural micro-surface (lacquer, powder coat, plaster)."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    nt = m.node_tree
    if bump:
        bn = nt.nodes.new("ShaderNodeBump"); bn.inputs["Strength"].default_value = bump[1]
        tc = nt.nodes.new("ShaderNodeTexCoord")
        n1 = nt.nodes.new("ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = bump[0]; n1.inputs["Detail"].default_value = 6
        nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
        h = n1.outputs["Fac"]
        if len(bump) > 2:
            n2 = nt.nodes.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = bump[2]; n2.inputs["Detail"].default_value = 3
            nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
            mx = nt.nodes.new("ShaderNodeMath"); mx.operation = "MULTIPLY_ADD"
            nt.links.new(n2.outputs["Fac"], mx.inputs[0]); mx.inputs[1].default_value = bump[3] / bump[1]
            nt.links.new(n1.outputs["Fac"], mx.inputs[2]); h = mx.outputs[0]
        nt.links.new(h, bn.inputs["Height"]); nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
        if coat: nt.links.new(bn.outputs["Normal"], b.inputs["Coat Normal"])
    if spec is not None: b.inputs["Specular IOR Level"].default_value = spec
    if emit: b.inputs["Emission Color"].default_value = (*srgb(emit[0]), 1); b.inputs["Emission Strength"].default_value = emit[1]
    if coat_rough is not None: b.inputs["Coat Roughness"].default_value = coat_rough
    b.inputs["Base Color"].default_value = (*srgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if aniso: b.inputs["Anisotropic"].default_value = aniso
    if transmit:
        b.inputs["Transmission Weight"].default_value = transmit
        b.inputs["IOR"].default_value = ior
    if coat: b.inputs["Coat Weight"].default_value = coat
    return m

# ---------- mesh helpers
def obj(name, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    o.data.materials.append(m); return o

def smooth(o, angle=35):
    for p in o.data.polygons: p.use_smooth = True
    bpy.context.view_layer.objects.active = o
    try: bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception: pass
    return o

def bevel(o, w, seg=2):
    b = o.modifiers.new("bev", "BEVEL"); b.width = w; b.segments = seg; return o

def lathe(name, prof, m, steps=192):
    """Spin an (r, z) profile around the clock axis."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in prof]
    for a, b in zip(vs, vs[1:]): bm.edges.new((a, b))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=(0, 0, 0), axis=(0, 0, 1), angle=TAU, steps=steps)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    return smooth(obj(name, bm, m), 40)

def disc(name, r, t, z, m, seg=192):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=t)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z + t / 2))
    return smooth(obj(name, bm, m), 30)

def _box(bm, w, l, t, y0, rot, z):
    g = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(w, l, t), verts=g)
    bmesh.ops.translate(bm, vec=(0, y0 + l / 2, z + t / 2), verts=g)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(rot, 3, "Z"), verts=g)

def ring_marks(name, m, z, spec, t=0.00006, bev=None):
    """spec(i) -> (width, length, outer radius) or None, for i in 0..59. t > 0.0001 makes them raised."""
    bm = bmesh.new()
    for i in range(60):
        s = spec(i)
        if s: w, l, r = s; _box(bm, w, l, t, r - l, -i * TAU / 60, z)
    o = obj(name, bm, m)
    if bev: b = o.modifiers.new("bev", "BEVEL"); b.width = bev; b.segments = 3; b.limit_method = "ANGLE"
    return o

def numerals(m, z, r, size, font_path, labels=None, radial=False, extrude=0.00003):
    font = bpy.data.fonts.load(font_path)
    labels = labels or [str(n) for n in range(1, 13)]
    for n, txt in enumerate(labels, start=1):
        if not txt: continue
        a = n * TAU / 12
        cu = bpy.data.curves.new(f"n{n}", "FONT"); cu.body = txt; cu.font = font
        cu.size = size; cu.align_x = "CENTER"; cu.align_y = "CENTER"; cu.extrude = extrude
        o = bpy.data.objects.new(f"n{n}", cu); sc.collection.objects.link(o)
        o.location = (math.sin(a) * r, math.cos(a) * r, z); o.data.materials.append(m)
        if radial: o.rotation_euler.z = -a

def _extrude_outline(bm, pts, t):
    f = bm.faces.new([bm.verts.new((x, y, 0)) for x, y in pts])
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0, t), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])

def _stadium_pts(front, back, w, seg=16):
    r = w / 2; pts = []
    for k in range(seg + 1):
        th = math.pi * k / seg; pts.append((r * math.cos(th), front - r + r * math.sin(th)))
    for k in range(seg + 1):
        th = math.pi + math.pi * k / seg; pts.append((r * math.cos(th), -back + r + r * math.sin(th)))
    return pts

def _circle_pts(cy, r, seg=48):
    return [(r * math.cos(TAU * k / seg), cy + r * math.sin(TAU * k / seg)) for k in range(seg)]

def hand(name, z, m, t, shapes):
    """shapes: list of ('stadium', front, back, w) | ('taper', front, back, wf, wb) | ('circle', cy, r)."""
    bm = bmesh.new()
    for s in shapes:
        if s[0] == "stadium": pts = _stadium_pts(*s[1:])
        elif s[0] == "taper":
            _, f, b, wf, wb = s; pts = [(-wb / 2, -b), (wb / 2, -b), (wf / 2, f), (-wf / 2, f)]
        elif s[0] == "poly": pts = s[1]
        else: pts = _circle_pts(*s[1:])
        _extrude_outline(bm, pts, t)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = obj(name, bm, m); o.location = (0, 0, z)
    return bevel(o, t * 0.3)

def rounded_rect_pts(w, h, r, seg=12):
    pts = []
    for cx, cy, a0 in ((w/2-r, h/2-r, 0), (-w/2+r, h/2-r, 90), (-w/2+r, -h/2+r, 180), (w/2-r, -h/2+r, 270)):
        for k in range(seg + 1):
            a = math.radians(a0 + 90 * k / seg); pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def slab(name, pts, t, z, m):
    bm = bmesh.new(); _extrude_outline(bm, pts, t)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = obj(name, bm, m); o.location.z = z; return o

def cut_hole(o, r, depth, z):
    """Boolean a round recess into o from the front."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=192, radius1=r, radius2=r, depth=depth)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z))
    me = bpy.data.meshes.new("cutter"); bm.to_mesh(me); bm.free()
    cutter = bpy.data.objects.new("cutter", me); sc.collection.objects.link(cutter); cutter.hide_render = True
    b = o.modifiers.new("hole", "BOOLEAN"); b.operation = "DIFFERENCE"; b.object = cutter; b.solver = "EXACT"
    return o

def dome_glass(r, rise, z_base, m, t=0.0016):
    Rs = (r ** 2 + rise ** 2) / (2 * rise)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=192, v_segments=384, radius=Rs)
    cut = Rs - rise
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut), plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z_base - cut))
    o = smooth(obj("glass", bm, m), 80)
    s = o.modifiers.new("sol", "SOLIDIFY"); s.thickness = t; s.offset = -1
    return o

def flat_glass(r, z, m, t=0.002):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=192, radius1=r, radius2=r, depth=t)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z + t / 2))
    return obj("glass", bm, m)            # flat shaded: a smoothed slab refracts like a lens

# ---------- common materials
GLASS = mat("glass", "#ffffff", rough=0.0, transmit=1.0)
PRINT = mat("print", "#0b0b0b", rough=0.6)

# ---------- build the clock
spec = importlib.util.spec_from_file_location("clock", os.path.join(HERE, "clocks", CLOCK + ".py"))
clock = importlib.util.module_from_spec(spec); spec.loader.exec_module(clock)
info = clock.build(sys.modules[__name__], HMS)     # returns {"wall": hex, "hands": {...}}

# ---------- test renders: pose the hands at HMS (layer renders keep them at 12)
if not LAYER and any(HMS):
    h, mi, se = HMS
    ang = {"hour": ((h % 12) + mi / 60) * TAU / 12, "minute": (mi + se / 60) * TAU / 60, "second": se * TAU / 60}
    for k, names in info["hands"].items():
        for n in names:
            if k in ang: sc.objects[n].rotation_euler.z = -ang[k]

# ---------- wall. FACE=1: dial-only view. No case, glass or dial edge: the dial surface runs to the frame edge.
FACE = os.environ.get("FACE")
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=2.0)
if FACE and "dial_z" in info:
    for n in ("case", "glass", "dial"):
        if n in sc.objects: sc.objects[n].hide_render = True
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, info["dial_z"]))
    obj("wall", bm, sc.objects["dial"].data.materials[0])
else:
    obj("wall", bm, mat("wall", info.get("wall", "#c9c4ba"), rough=0.92, bump=info.get("wall_bump")))

# ---------- lights: big soft key upper left (window), faint cool fill, soft round highlight
def area(name, loc, size, power, color=(1, 1, 1), shape="SQUARE"):
    l = bpy.data.lights.new(name, "AREA"); l.size = size; l.energy = power; l.color = color; l.shape = shape
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 0.03)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o
LIGHTING = os.environ.get("LIGHTING", "day")
SETS = {   # key (loc, size, power, colour), fill, highlight, world (colour, strength), exposure offset
  "day":   dict(key=((-0.9, 1.1, 1.3), 0.5, 330, (1.0, 0.97, 0.92)), fill=((1.4, -0.6, 1.0), 2.0, 40, (0.9, 0.95, 1.0)),
                strip=((-0.5, 0.9, 0.9), 0.35, 30, (1, 1, 1)), world=((0.6, 0.6, 0.62), 0.22), ev=0.0),
  "dusk":  dict(key=((1.35, 0.45, 0.62), 0.28, 300, (1.0, 0.66, 0.38)), fill=((-1.4, 0.2, 1.0), 2.0, 22, (0.55, 0.65, 1.0)),
                strip=((0.9, 0.7, 0.8), 0.3, 18, (1.0, 0.8, 0.6)), world=((0.35, 0.38, 0.5), 0.14), ev=-0.1),
  "night": dict(key=((-0.75, -0.7, 0.85), 0.45, 75, (1.0, 0.74, 0.48)), fill=((1.2, 1.0, 1.2), 2.0, 6, (0.5, 0.6, 1.0)),
                strip=((-0.6, -0.4, 0.9), 0.3, 6, (1.0, 0.8, 0.6)), world=((0.12, 0.14, 0.22), 0.05), ev=0.1),
}
L = SETS[LIGHTING]
key = area("key", *L["key"]); key.visible_glossy = False
area("fill", *L["fill"])
area("strip", *L["strip"], shape="DISK")
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (*L["world"][0], 1)
world.node_tree.nodes["Background"].inputs[1].default_value = L["world"][1]
kx, ky, kz = L["key"][0]
print("SHADOW", LIGHTING, "dir", round(-kx / math.hypot(kx, ky), 3), round(ky / math.hypot(kx, ky), 3), "slope", round(math.hypot(kx, ky) / kz, 3))

# ---------- camera on the clock axis: rotating a hand sprite in 2D is then exact
cam = bpy.data.cameras.new("cam"); cam.lens = float(os.environ.get("LENS", 72))
co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
co.location = (0, 0, 1.15)

# ---------- layer split
HANDS = info["hands"]          # {"hour": [...names], "minute": [...], "second": [...], "cap": [...]}
if LAYER:
    moving = sum(HANDS.values(), [])
    for o in sc.objects:
        if o.type in ("LIGHT", "CAMERA") or o.name.startswith("cutter") or (FACE and o.name in ("case", "glass", "dial")): continue
        if LAYER in ("plate", "noglass"):
            o.hide_render = o.name in moving or (LAYER == "noglass" and o.name == "glass")
        else:
            o.hide_render = o.name not in HANDS.get(LAYER, [])
    sc.render.film_transparent = LAYER not in ("plate", "noglass")

# ---------- render
sc.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "METAL"; prefs.get_devices()
    for d in prefs.devices: d.use = True
    sc.cycles.device = "GPU"
except Exception: pass
sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
try: sc.view_settings.view_transform = "Khronos PBR Neutral"   # keeps reds red
except TypeError: sc.view_settings.view_transform = "AgX"
sc.view_settings.exposure = float(os.environ.get("EXPOSURE", info.get("exposure", -0.45))) + L["ev"] + float(os.environ.get("EV_EXTRA", 0)) + (info.get("face_ev", -0.6) if FACE and "EXPOSURE" not in os.environ else 0)
if LAYER and LAYER not in ("plate", "noglass") and os.environ.get("CROP"):
    m = float(os.environ.get("CROPM", 0.26))   # hand sprites: centre (1 - 2m) of the frame
    sc.render.use_border = True; sc.render.use_crop_to_border = True
    sc.render.border_min_x = sc.render.border_min_y = m; sc.render.border_max_x = sc.render.border_max_y = 1 - m
sc.render.resolution_x = sc.render.resolution_y = RES
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("WROTE", OUT)
