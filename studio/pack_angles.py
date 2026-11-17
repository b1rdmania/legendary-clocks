"""Pack angular hand samples into one strip atlas per hand, plus metadata the page reads.
Usage: python3 pack_angles.py <dir with <hand>_000.png ... and <hand>_sh.png> <out dir> <N>
Each sample is turned back to twelve o'clock (exact: the camera is on the clock axis), then cut to a tight
vertical strip around the pivot. Strip k carries the lighting the hand gets at k * 360/N degrees."""
import json, subprocess, sys
from pathlib import Path
src, out, N = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)
run = lambda *a: subprocess.run(["magick", *map(str, a)], check=True, capture_output=True, text=True).stdout
meta = {"angles": N}
for hand in ("hour", "minute", "second"):
    frames = [src / f"{hand}_{k:03d}.png" for k in range(N)]
    if not frames[0].exists(): continue
    S = int(run("identify", "-format", "%w", frames[0]))
    tmp = out / f".{hand}"; tmp.mkdir(exist_ok=True)
    for k, f in enumerate(frames):   # undo the clockwise turn, keep the canvas centred on the pivot
        run(f, "-background", "none", "-virtual-pixel", "transparent", "-distort", "SRT", f"{-k * 360 / N}", tmp / f"{k:03d}.png")
    # tight box over all upright samples, symmetric in x about the pivot
    run(*[tmp / f"{k:03d}.png" for k in range(N)], "-background", "none", "-compose", "lighten", "-flatten", tmp / "union.png")
    w, h, x, y = map(int, run(tmp / "union.png", "-alpha", "extract", "-threshold", "1%", "-format", "%@", "info:").replace("x", "+").split("+"))
    c = S / 2; half = int(max(c - x, x + w - c)) + 4; top, bot = max(0, y - 4), min(S, y + h + 4)
    W, H = 2 * half, bot - top
    run(*[tmp / f"{k:03d}.png" for k in range(N)], "-crop", f"{W}x{H}+{int(c - half)}+{top}", "+repage", "-append",
        "-define", "webp:alpha-quality=95", "-quality", "90", out / f"{hand}_a.webp")
    meta[hand] = {"w": W, "h": H, "pivot": [half, c - top], "src": S}
    sh = src / f"{hand}_sh.png"
    if sh.exists(): run(sh, "-quality", "88", out / f"{hand}_sh.webp")
    for f in tmp.iterdir(): f.unlink()
    tmp.rmdir()
(out / "angles.json").write_text(json.dumps(meta, indent=1))
print(json.dumps(meta))
