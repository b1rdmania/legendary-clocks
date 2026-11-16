# Max Bill wall clock, approximated. Run: blender -b -P build.py -- <out.png> <view: hero|front> [hh:mm:ss]
import bpy, bmesh, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/maxbill.png"
VIEW = argv[1] if len(argv) > 1 else "hero"
HMS = [int(x) for x in (argv[2] if len(argv) > 2 else "10:09:36").split(":")]
FONT = __import__("os").path.expanduser("~/Library/Fonts/ABCDiatype-Light-Trial.otf")

# ---- dimensions (metres). 300 mm case, dial sits 6 mm below the rim.
R_CASE, R_DIAL = 0.150, 0.1405
Z_DIAL = 0.030
Z_RIM = 0.042

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def mat(name, color, rough=0.5, metal=0.0, aniso=0.0, transmit=0.0, ior=1.5, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if aniso: b.inputs["Anisotropic"].default_value = aniso
    if transmit:
        b.inputs["Transmission Weight"].default_value = transmit
        b.inputs["IOR"].default_value = ior
    if coat: b.inputs["Coat Weight"].default_value = coat
    return m

def srgb(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + .055) / 1.055) ** 2.4 for x in c)

M_WALL  = mat("wall",  srgb("#c9c4ba"), rough=0.92)
M_ALU   = mat("alu",   srgb("#c4c7ca"), rough=0.32, metal=1.0, aniso=0.6)
M_DIAL  = mat("dial",  srgb("#fbfaf6"), rough=0.55)
M_PRINT = mat("print", srgb("#0b0b0b"), rough=0.6)
M_HAND  = mat("hand",  srgb("#0a0a0a"), rough=0.5)
M_RED   = mat("red",   srgb("#c0152b"), rough=0.35, coat=0.3)
M_GLASS = mat("glass", (1, 1, 1), rough=0.0, transmit=1.0, ior=1.5)

def obj_from_bm(name, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    o.data.materials.append(m)
    return o

def smooth(o, angle=35):
    for p in o.data.polygons: p.use_smooth = True
    mod = o.modifiers.new("ws", "WEIGHTED_NORMAL") if False else None
    try:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        pass

# ---- wall
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=2.0)
obj_from_bm("wall", bm, M_WALL)

# ---- case: lathe a profile (r, z)
prof = [(0.0, 0.0), (0.146, 0.0), (0.1495, 0.002), (R_CASE, 0.006), (R_CASE, 0.037),
        (0.1494, 0.0405), (0.1478, 0.0418), (0.1455, Z_RIM), (0.1432, 0.0415), (0.1420, 0.0400),
        (0.1415, 0.0365), (R_DIAL + 0.0004, Z_DIAL + 0.001), (R_DIAL - 0.002, Z_DIAL + 0.0004)]
bm = bmesh.new()
verts = [bm.verts.new((r, 0, z)) for r, z in prof]
for a, b in zip(verts, verts[1:]): bm.edges.new((a, b))
bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=192, use_duplicate=False)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
case = obj_from_bm("case", bm, M_ALU); smooth(case, 40)

# ---- dial
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=192, radius1=R_DIAL, radius2=R_DIAL, depth=0.002)
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, Z_DIAL - 0.001))
dial = obj_from_bm("dial", bm, M_DIAL); smooth(dial, 30)

Z_PRINT = Z_DIAL + 0.00005
def box(bm, cx, cy, w, l, t, rot, z):
    g = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, vec=(w, l, t), verts=g)
    bmesh.ops.translate(bm, vec=(0, 0, z + t / 2), verts=g)
    bmesh.ops.translate(bm, vec=(cx, cy, 0), verts=g)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(rot, 3, "Z"), verts=g)

# ---- minute track: 60 printed ticks
bm = bmesh.new()
for i in range(60):
    five = i % 5 == 0
    l = 0.011 if five else 0.0058
    w = 0.0017 if five else 0.0008
    r_out = 0.1335
    box(bm, 0, r_out - l / 2, w, l, 0.00006, -i * math.tau / 60, Z_DIAL)
obj_from_bm("ticks", bm, M_PRINT)

# ---- numerals
font = bpy.data.fonts.load(FONT)
for n in range(1, 13):
    a = n * math.tau / 12
    cu = bpy.data.curves.new(f"n{n}", "FONT"); cu.body = str(n); cu.font = font
    cu.size = 0.0215; cu.align_x = "CENTER"; cu.align_y = "CENTER"; cu.extrude = 0.00003
    o = bpy.data.objects.new(f"n{n}", cu); sc.collection.objects.link(o)
    o.location = (math.sin(a) * 0.1055, math.cos(a) * 0.1055, Z_DIAL + 0.00004)
    o.data.materials.append(M_PRINT)

# ---- hands: stadium outlines, solidified
def stadium(name, front, back, w, t, z, angle, m, seg=16):
    bm = bmesh.new(); pts = []
    r = w / 2
    for k in range(seg + 1):                      # front cap
        th = math.pi * k / seg
        pts.append((r * math.cos(th), front - r + r * math.sin(th)))
    for k in range(seg + 1):                      # back cap
        th = math.pi + math.pi * k / seg
        pts.append((r * math.cos(th), -back + r + r * math.sin(th)))
    vs = [bm.verts.new((x, y, 0)) for x, y in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0, t), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = obj_from_bm(name, bm, m)
    o.location = (0, 0, z); o.rotation_euler = (0, 0, -angle)
    bev = o.modifiers.new("bev", "BEVEL"); bev.width = t * 0.35; bev.segments = 2
    return o

h, mi, s = HMS
a_h = ((h % 12) + mi / 60 + s / 3600) * math.tau / 12
a_m = (mi + s / 60) * math.tau / 60
a_s = s * math.tau / 60
stadium("hour",   0.074, 0.019, 0.0056, 0.0007, Z_DIAL + 0.0012, a_h, M_HAND)
stadium("minute", 0.118, 0.019, 0.0040, 0.0006, Z_DIAL + 0.0024, a_m, M_HAND)
stadium("second", 0.128, 0.032, 0.0011, 0.0004, Z_DIAL + 0.0034, a_s, M_RED)

def cap(name, r, t, z, m):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=r, radius2=r, depth=t)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z + t / 2))
    o = obj_from_bm(name, bm, m); smooth(o)
    bev = o.modifiers.new("bev", "BEVEL"); bev.width = t * 0.3; bev.segments = 2
cap("arbor", 0.0042, 0.0030, Z_DIAL, M_HAND)
cap("seccap", 0.0026, 0.0009, Z_DIAL + 0.0034, M_RED)

# ---- domed mineral glass: spherical cap, 5 mm rise
h_dome, r_glass = 0.005, 0.1425
Rs = (r_glass ** 2 + h_dome ** 2) / (2 * h_dome)
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=192, v_segments=384, radius=Rs)
z_cut = Rs - h_dome
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z_cut), plane_no=(0, 0, 1), clear_inner=True)
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -z_cut + 0.0368))
glass = obj_from_bm("glass", bm, M_GLASS); smooth(glass, 80)
sol = glass.modifiers.new("sol", "SOLIDIFY"); sol.thickness = 0.0016; sol.offset = -1

# ---- lights: one big soft key from upper left (window), a faint fill, grey world
def area(name, loc, size, power, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, "AREA"); l.size = size; l.energy = power; l.color = color
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
    d = Vector((0, 0, 0.03)) - Vector(loc); o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return o
key = area("key", (-0.9, 1.1, 1.3), 0.5, 330, (1.0, 0.97, 0.92)); key.visible_glossy = False
area("fill", (1.4, -0.6, 1.0), 2.0, 40, (0.9, 0.95, 1.0))
st = area("strip", (-0.5, 0.9, 0.9), 0.35, 30); st.data.shape = "DISK"   # soft round highlight for glass and bezel

world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.6, 0.62, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.22

# ---- camera
cam = bpy.data.cameras.new("cam"); co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
if VIEW == "front":
    cam.lens = float(os.environ.get("LENS", 110)); co.location = (0, 0, 1.15)
else:
    cam.lens = 120; co.location = (0.62, -0.46, 1.0)
from mathutils import Matrix
tgt = Vector((0, 0, 0.03)); fwd = (tgt - co.location).normalized()
right = fwd.cross(Vector((0, 1, 0))).normalized(); up = right.cross(fwd)
co.rotation_euler = Matrix((right, up, -fwd)).transposed().to_euler()

# ---- layer split for the live clock: LAYER=plate|noglass|hour|minute|second|cap
LAYER = os.environ.get("LAYER")
HANDS = {"hour": ["hour"], "minute": ["minute"], "second": ["second"], "cap": ["arbor", "seccap"]}
if LAYER:
    moving = sum(HANDS.values(), [])
    for o in sc.objects:
        if o.type in ("LIGHT", "CAMERA"): continue
        if LAYER in ("plate", "noglass"):
            o.hide_render = o.name in moving or (LAYER == "noglass" and o.name == "glass")
        else:
            o.hide_render = o.name not in HANDS[LAYER]
    sc.render.film_transparent = LAYER in HANDS

# ---- render
sc.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "METAL"; prefs.get_devices()
    for d in prefs.devices: d.use = True
    sc.cycles.device = "GPU"
except Exception:
    pass
sc.cycles.samples = int(argv[3]) if len(argv) > 3 else 160
sc.cycles.use_denoising = True
sc.view_settings.view_transform = "AgX"
for lk in ("AgX - Medium High Contrast", "AgX - High Contrast", "AgX - Punchy"):
    try: sc.view_settings.look = lk; break
    except TypeError: pass
sc.view_settings.exposure = 0.45
sc.render.resolution_x = sc.render.resolution_y = int(os.environ.get("RES", 1400))
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("WROTE", OUT)
