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
    "texture": ["ashlar", "brick", "rubble"],
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
    "ashlar": "coursed ashlar stone", "brick": "brick masonry",
    "rubble": "rough flagstone",
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
    """Basic mesh QA. Returns (error, triangles)."""
    tris = load_stl_triangles(path)
    if not tris:
        return "no triangles in mesh", tris
    edge_count = {}
    for tri in tris:
        if len(set(tri)) < 3:
            return "degenerate triangle (repeated vertex)", tris
        for a, b in ((0, 1), (1, 2), (2, 0)):
            key = frozenset((tri[a], tri[b]))
            edge_count[key] = edge_count.get(key, 0) + 1
    
    bad = sum(1 for n in edge_count.values() if n != 2)
    if bad:
        return f"non-manifold: {bad} edges not shared by exactly 2 faces", tris
    return None, tris


def seeded_styles(kit_id, seed):
    """Deterministic style pick per slot; reroll by changing the seed."""
    def pick(slot):
        h = int(hashlib.md5(f"{kit_id}:{seed}:{slot}".encode())
                .hexdigest(), 16)
        return STYLE_POOLS[slot][h % len(STYLE_POOLS[slot])]
    return {slot: pick(slot) for slot in STYLE_POOLS}


BASE_TAGS = ["dungeon terrain", "castle terrain", "tabletop terrain",
             "dnd terrain", "modular dungeon", "28mm terrain",
             "3d printed terrain", "rpg dungeon tiles"]

STYLE_TAGS = {
    "door_arch": ["castle door", "arched door"],
    "door_rect": ["castle door", "dungeon door"],
    "door_portcullis": ["portcullis", "castle gate"],
    "window_slit": ["arrow slit", "castle window"],
    "window_arch": ["castle window"],
    "window_barred": ["castle window", "prison window"],
    "sconce": ["torch sconce"],
    "banner_peg": ["castle banner"],
    "gargoyle_socket": ["gargoyle"],
    "compass": ["compass rose"],
    "shield": ["heraldry"],
    "knotwork": ["celtic knot"],
    "blank": ["paintable tile"],
    "ashlar": ["stone wall"],
    "brick": ["brick wall"],
    "rubble": ["flagstone"],
}


def suggest_tags(piece, params):
    """Etsy-style tag list: max 13 tags, each 20 characters or less."""
    tags = list(BASE_TAGS)
    scad = piece["scad"]
    if "stairs" in scad:
        tags += ["dungeon stairs", "castle stairs"]
    elif "column" in scad:
        tags += ["stone column", "pillar", "multi level"]
    elif "deck_tile" in scad:
        tags += ["second floor", "multi level", "dnd tiles"]
    elif "curved_wall" in scad:
        tags += ["castle tower", "turret", "round tower"]
    elif "tower_floor" in scad:
        tags += ["castle tower", "turret", "multi level"]
    elif "hatch_lid" in scad:
        tags += ["trapdoor", "hatch"]
    elif "floor_tile" in scad:
        tags += ["dungeon floor tile", "dnd tiles"]
    elif "mosaic" in scad:
        tags += ["dungeon floor tile", "mosaic tile"]
    elif "wall_corner" in scad:
        tags += ["dungeon wall", "corner wall"]
    elif "wall_straight" in scad:
        tags += ["dungeon wall"]
    elif "fit_coupon" in scad:
        tags += ["calibration", "test print"]
    for key in ("OPENING", "DECOR", "MOSAIC", "TEXTURE"):
        tags += STYLE_TAGS.get(params.get(key, ""), [])
    if params.get("CRENELLATED"):
        tags.append("battlements")
    if params.get("RUIN", 0):
        tags += ["ruins", "ruined wall"]
    if params.get("CONNECTOR") == "magnet":
        tags.append("magnetic terrain")
    seen, out = set(), []
    for tag in tags:
        if tag not in seen and len(tag) <= 20:
            seen.add(tag)
            out.append(tag)
    return out[:13]


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
        # --render: full CGAL evaluation. The OpenCSG preview path
        # aborts normalization (empty image) on texture-heavy scenes.
        cmd = (["xvfb-run", "-a"] + cmd
               + ["--render", "--imgsize=1000,750",
                  f"--camera={png_camera}"])
    for k, v in params.items():
        cmd += ["-D", f"{k}={scad_value(v)}"]
    cmd.append(str(scad_path))
    return subprocess.run(cmd, capture_output=True, text=True)


def kit_code(kit):
    initials = "".join(w[0] for w in kit["kit_id"].split("_")).upper()
    return kit.get("code", f"{initials}{kit.get('seed', 0)}")


def magnet_count(piece, params):
    """Pockets a piece needs filled, for the kit shopping list."""
    if params.get("CONNECTOR") != "magnet":
        return 0
    scad = piece["scad"]
    if "floor_tile" in scad or "mosaic" in scad:
        return 2 * (params.get("FLOOR_W", 1) + params.get("FLOOR_L", 1))
    if "wall_straight" in scad:
        return 2 * (2 if params.get("WALL_HEIGHT_UNITS", 2) > 1 else 1)
    if "wall_corner" in scad:
        return 2 * (2 if params.get("WALL_HEIGHT_UNITS", 2) > 1 else 1)
    if "fit_coupon" in scad:
        return 2
    return 0


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
    manifest_rows = []
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
        if not calibration:
            params["PART_ID"] = f"{kit_code(kit)} {name}"
            params.setdefault("TEXTURE", styles.get("texture", "none"))
            params.setdefault("TEXTURE_SEED", kit.get("seed", 0))

        stl = kit_dir / f"{name}.stl"
        proc = render_scad(stl, ROOT / piece["scad"], params)
        if proc.returncode != 0 or not stl.exists():
            failures.append(f"{kit_id}/{name}: render failed\n{proc.stderr}")
            continue
        err, tris = validate_stl(stl)
        if err:
            failures.append(f"{kit_id}/{name}: {err}")
            continue
        xs = [v[0] for tri in tris for v in tri]
        ys = [v[1] for tri in tris for v in tri]
        zs = [v[2] for tri in tris for v in tri]
        vol_cm3 = abs(mesh_volume(tris)) / 1000
        manifest_rows.append({
            "name": name, "piece_type": piece["piece_type"],
            "file": f"{name}.stl", "triangles": len(tris),
            "bbox_x_mm": round(max(xs) - min(xs), 2),
            "bbox_y_mm": round(max(ys) - min(ys), 2),
            "bbox_z_mm": round(max(zs) - min(zs), 2),
            "solid_volume_cm3": round(vol_cm3, 2),
            "solid_pla_g": round(vol_cm3 * 1.24, 1),
            "magnets_needed": magnet_count(piece, params),
        })

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
        nice = re.sub(r"(\d)X(\d)", r"\1x\2",
                      fields["piece_type"].title())
        title = (f"{nice} - {kit['kit_name']} | "
                 f"Modular Dungeon Terrain STL")
        (kit_dir / f"{name}.tags.txt").write_text(
            f"Suggested listing title:\n{title}\n\n"
            "Suggested tags (13 max, 20 characters each):\n"
            + "\n".join(suggest_tags(piece, params)) + "\n")
        print(f"[ok]     {kit_id}/{name}")

    if manifest_rows:
        import csv
        with (kit_dir / "manifest.csv").open("w", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(manifest_rows[0]))
            wr.writeheader()
            wr.writerows(manifest_rows)
            total_mag = sum(r["magnets_needed"] for r in manifest_rows)
            f.write(f"# kit totals: {len(manifest_rows)} pieces, "
                    f"{sum(r['solid_pla_g'] for r in manifest_rows):.0f}g "
                    f"solid PLA, {total_mag} magnets"
                    + (f" ({kit.get('shared', {}).get('MAGNET', '')}mm)"
                       if total_mag else "") + "\n")

    if kit.get("preview") and not calibration:
        render_previews(kit, styles, kit_dir, failures)


def render_previews(kit, styles, kit_dir, failures):
    if not shutil.which("xvfb-run"):
        print(f"[skip]   {kit['kit_id']}: no xvfb, previews not rendered")
        return
    style_params = {
        "SCENE":        kit.get("preview_scene", "room"),
        "TEXTURE":      styles.get("texture", "none"),
        "TEXTURE_SEED": kit.get("seed", 0),
        "DOOR_STYLE":   styles.get("door", "door_arch"),
        "WINDOW_STYLE": styles.get("window", "window_arch"),
        "MOSAIC_STYLE": styles.get("mosaic", "compass"),
        "DECOR_STYLE":  styles.get("decor", "sconce"),
        **kit.get("shared", {}),
    }
    if kit.get("preview_scene") == "tower":
        views = {
            "preview_iso": "0,0,60,62,0,155,380",
            "preview_top": "0,0,0,0,0,0,260",
        }
    else:
        views = {
            "preview_iso": "51,51,25,55,0,110,330",
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

    # Every .stl must have a matching .txt and vice versa — the
    # zero-mismatch guarantee for shipped bundles.
    for kit_dir in sorted(d for d in OUT.iterdir()
                          if d.is_dir() and d.name != ".fit"):
        stls = {f.stem for f in kit_dir.glob("*.stl")}
        txts = {f.name[:-4] for f in kit_dir.glob("*.txt")
                if not f.name.endswith(".tags.txt")}
        if stls != txts:
            failures.append(
                f"{kit_dir.name}: stl/txt mismatch — "
                f"missing txt for {sorted(stls - txts)}, "
                f"missing stl for {sorted(txts - stls)}")

    if failures:
        print("\nBUILD FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print(f"\nAll {n_pieces} pieces across {len(kit_files)} kits rendered "
          f"and validated; {n_tests} fit tests passed.")


if __name__ == "__main__":
    main()
