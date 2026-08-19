#!/usr/bin/env python3
"""Render every kit in config/kits/ to generated/<kit_id>/.

A kit is a matched set: its `shared` block (connector type, fit,
magnet size...) is merged into every piece, so all pieces in a kit
mate by construction — pieces may not override protected keys. Style
slots (door/window/mosaic/decor) are picked deterministically from the
kit's `seed` unless pinned in `styles`; change the seed to reroll a
whole matching kit.

Per piece: render via OpenSCAD, validate the mesh (non-empty, no
degenerate faces, manifold), and emit a matching .txt description.
Then run the snap-fit tests in config/fit_tests.json (mated pairs are
boolean-intersected; real overlap volume fails) and render kit preview
thumbnails (iso + top-down) when a display or xvfb is available.
Exits non-zero if anything fails, so CI can gate on it.
"""
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "generated"

STYLE_POOLS = {
    "door":    ["door_arch", "door_rect", "door_portcullis"],
    "window":  ["window_slit", "window_arch", "window_barred"],
    "mosaic":  ["compass", "shield", "knotwork"],
    "decor":   ["sconce", "banner_peg", "gargoyle_socket"],
}

STYLE_NAMES = {
    "door_arch": "rounded-arch doorway", "door_rect": "rectangular doorway",
    "door_portcullis": "portcullis gateway",
    "window_slit": "arrow-slit window", "window_arch": "arched window",
    "window_barred": "barred window",
    "compass": "compass rose", "shield": "heraldic shield",
    "knotwork": "knotwork lattice", "blank": "blank ring",
    "sconce": "torch sconce", "banner_peg": "banner peg",
    "gargoyle_socket": "gargoyle mount",
}

# Keys a piece may never override — this is what guarantees every
# piece in a kit shares identical connector geometry.
PROTECTED = {"CONNECTOR", "FIT", "MAGNET", "GRID_UNIT", "SCALE",
             "WALL_FOOT", "FLOOR_GROOVES"}

DESCRIPTION_TEMPLATE = """\
1. Design Concept:
This {piece_type} features a {style} design with {connector_type} connectors, generated
using a {param_summary} configuration. Part of the {kit_name} modular dungeon/castle set.

2. Use Suggestion:
Ideal for tabletop RPG terrain, diorama building, or display alongside matching {kit_name}
floor and wall pieces. Combine with other pieces from this set for a full modular scene.

3. Print Recommendations:
Recommended layer height: 0.2mm | Infill: 15-20% | No supports needed if printed flat-side down |
Connector tolerances designed for {nozzle_size} nozzle, may require light sanding for tight fit.

4. Thanks for looking! I can generate similar items using a program I built. Hit me up if you'd
like something custom! Thanks for liking and following my page!
"""


def scad_value(v):
    """Format a Python value as an OpenSCAD -D literal."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return json.dumps(v)
    return str(v)


def load_stl_triangles(path):
    """Return a list of triangles as ((x,y,z), (x,y,z), (x,y,z)) floats.

    Handles both binary and ASCII STL.
    """
    data = path.read_bytes()
    if len(data) >= 84:
        (count,) = struct.unpack_from("<I", data, 80)
        if len(data) == 84 + 50 * count:
            tris = []
            for i in range(count):
                off = 84 + 50 * i + 12  # skip normal
                tris.append(tuple(
                    struct.unpack_from("<fff", data, off + 12 * j)
                    for j in range(3)))
            return tris
    verts = re.findall(rb"vertex\s+(\S+)\s+(\S+)\s+(\S+)", data)
    return [tuple(tuple(float(c) for c in verts[i + j]) for j in range(3))
            for i in range(0, len(verts) - 2, 3)]


def mesh_volume(tris):
    """Signed mesh volume via the divergence theorem (mm^3)."""
    vol = 0.0
    for (a, b, c) in tris:
        vol += (a[0] * (b[1] * c[2] - b[2] * c[1])
                - a[1] * (b[0] * c[2] - b[2] * c[0])
                + a[2] * (b[0] * c[1] - b[1] * c[0]))
    return vol / 6.0


def validate_stl(path):
    """Basic mesh QA: non-empty, no degenerate faces, manifold edges."""
    tris = load_stl_triangles(path)
    if not tris:
        return "no triangles in mesh"
    edge_count = {}
    for tri in tris:
        if len(set(tri)) < 3:
            return "degenerate triangle (repeated vertex)"
        for a, b in ((0, 1), (1, 2), (2, 0)):
            key = frozenset((tri[a], tri[b]))
            edge_count[key] = edge_count.get(key, 0) + 1
    bad = sum(1 for n in edge_count.values() if n != 2)
    if bad:
        return f"non-manifold: {bad} edges not shared by exactly 2 faces"
    return None


def seeded_styles(kit_id, seed):
    """Deterministic style pick per slot; reroll by changing the seed."""
    def pick(slot):
        h = int(hashlib.md5(f"{kit_id}:{seed}:{slot}".encode())
                .hexdigest(), 16)
        return STYLE_POOLS[slot][h % len(STYLE_POOLS[slot])]
    return {slot: pick(slot) for slot in STYLE_POOLS}


def connector_text(shared):
    c = shared.get("CONNECTOR", "tab")
    if c == "magnet":
        return f"{shared.get('MAGNET', '5x2')}mm magnet pocket"
    return {"tab": "tab & slot", "dowel": "dowel pin (1.75mm filament)",
            "none": "flush butt-joint"}.get(c, c)


def resolve(value, styles):
    """Resolve $slot placeholders in a param value."""
    if isinstance(value, str) and value.startswith("$"):
        return styles[value[1:]]
    return value


def render_scad(out_path, scad_path, params, png_camera=None):
    cmd = ["openscad", "-o", str(out_path)]
    if png_camera:
        cmd = (["xvfb-run", "-a"] + cmd
               + ["--imgsize=1000,750", f"--camera={png_camera}"])
    for k, v in params.items():
        cmd += ["-D", f"{k}={scad_value(v)}"]
    cmd.append(str(scad_path))
    return subprocess.run(cmd, capture_output=True, text=True)


def build_kit(kit, failures):
    kit_id = kit["kit_id"]
    shared = kit.get("shared", {})
    calibration = kit.get("calibration", False)
    styles = {}
    if not calibration:
        styles = seeded_styles(kit_id, kit.get("seed", 0))
        styles.update(kit.get("styles", {}))
    kit_dir = OUT / kit_id
    kit_dir.mkdir(parents=True, exist_ok=True)
    print(f"== kit {kit_id}"
          + (f" (seed {kit.get('seed', 0)}: "
             + ", ".join(f"{k}={v}" for k, v in sorted(styles.items()))
             + ")" if styles else ""))

    for piece in kit["pieces"]:
        name = piece["name"]
        own = {k: resolve(v, styles) for k, v in
               piece.get("params", {}).items()}
        if not calibration:
            clash = set(own) & (PROTECTED | set(shared))
            if clash:
                failures.append(f"{kit_id}/{name}: piece overrides "
                                f"kit-level params {sorted(clash)}")
                continue
        params = {**shared, **own}

        stl = kit_dir / f"{name}.stl"
        proc = render_scad(stl, ROOT / piece["scad"], params)
        if proc.returncode != 0 or not stl.exists():
            failures.append(f"{kit_id}/{name}: render failed\n{proc.stderr}")
            continue
        err = validate_stl(stl)
        if err:
            failures.append(f"{kit_id}/{name}: {err}")
            continue

        summary = (f"GRID_UNIT {shared.get('GRID_UNIT', 25.4)}mm, "
                   f"FIT {shared.get('FIT', 'normal')}")
        if not calibration:
            summary += f", seed {kit.get('seed', 0)}"
        if piece.get("extra"):
            summary += f", {piece['extra']}"
        fields = {
            "kit_name": kit["kit_name"],
            "nozzle_size": kit.get("nozzle_size", "0.4mm"),
            "piece_type": piece["piece_type"].format(**{
                k: STYLE_NAMES.get(v, v) for k, v in styles.items()}),
            "style": piece["style"].format(**{
                k: STYLE_NAMES.get(v, v) for k, v in styles.items()}),
            "connector_type": piece.get("connector_type",
                                        connector_text(shared)),
            "param_summary": piece.get("param_summary", summary),
        }
        (kit_dir / f"{name}.txt").write_text(
            DESCRIPTION_TEMPLATE.format(**fields))
        print(f"[ok]     {kit_id}/{name}")

    if kit.get("preview") and not calibration:
        render_previews(kit, styles, kit_dir, failures)


def render_previews(kit, styles, kit_dir, failures):
    if not shutil.which("xvfb-run"):
        print(f"[skip]   {kit['kit_id']}: no xvfb, previews not rendered")
        return
    style_params = {
        "DOOR_STYLE":   styles.get("door", "door_arch"),
        "WINDOW_STYLE": styles.get("window", "window_arch"),
        "MOSAIC_STYLE": styles.get("mosaic", "compass"),
        "DECOR_STYLE":  styles.get("decor", "sconce"),
        **kit.get("shared", {}),
    }
    views = {
        "preview_iso": "51,51,25,55,0,200,330",
        "preview_top": "51,51,0,0,0,0,300",
    }
    for name, cam in views.items():
        png = kit_dir / f"{name}.png"
        proc = render_scad(png, ROOT / "tests" / "kit_preview.scad",
                           style_params, png_camera=cam)
        if proc.returncode != 0 or not png.exists() or \
                png.stat().st_size == 0:
            failures.append(f"{kit['kit_id']}/{name}.png: preview render "
                            f"failed\n{proc.stderr[-500:]}")
        else:
            print(f"[ok]     {kit['kit_id']}/{name}.png")


def run_fit_tests(failures):
    """Render mated piece pairs' boolean intersection; real volume fails."""
    cfg = ROOT / "config" / "fit_tests.json"
    tests = json.loads(cfg.read_text()) if cfg.exists() else []
    scratch = OUT / ".fit"
    scratch.mkdir(parents=True, exist_ok=True)
    for test in tests:
        name = test["name"]
        stl = scratch / f"{name}.stl"
        stl.unlink(missing_ok=True)
        proc = render_scad(stl, ROOT / "tests" / "fit_test.scad",
                           test.get("params", {}))
        out = proc.stderr + proc.stdout
        if "top level object is empty" in out:
            print(f"[fit ok] {name}: no overlap")
            continue
        if proc.returncode != 0 or not stl.exists():
            failures.append(f"fit test {name}: render failed\n{proc.stderr}")
            continue
        vol = abs(mesh_volume(load_stl_triangles(stl)))
        # Coplanar face contact (a piece resting on another) yields
        # degenerate zero-volume triangles; only real volume fails.
        if vol > 0.01:
            failures.append(f"fit test {name}: pieces OVERLAP by "
                            f"{vol:.2f} mm^3 — connector geometry is wrong")
        else:
            print(f"[fit ok] {name}: no overlap (surface contact only)")
    return len(tests)


def main():
    failures = []
    kit_files = sorted((ROOT / "config" / "kits").glob("*.json"))
    n_pieces = 0
    for f in kit_files:
        kit = json.loads(f.read_text())
        n_pieces += len(kit["pieces"])
        build_kit(kit, failures)
    n_tests = run_fit_tests(failures)

    if failures:
        print("\nBUILD FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print(f"\nAll {n_pieces} pieces across {len(kit_files)} kits rendered "
          f"and validated; {n_tests} fit tests passed.")


if __name__ == "__main__":
    main()
