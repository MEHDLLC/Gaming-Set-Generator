#!/usr/bin/env python3
"""Render every piece in config/build_manifest.json to generated/.

For each piece: run OpenSCAD with the piece's parameter overrides,
validate the resulting STL (non-empty, watertight/manifold), and emit a
matching .txt description file. Exits non-zero if anything fails, so CI
can gate on it.
"""
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "generated"

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
    # ASCII fallback
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


def run_fit_tests(manifest, failures):
    """Render mated piece pairs' boolean intersection; any volume = collision."""
    scratch = ROOT / "generated" / ".fit"
    scratch.mkdir(parents=True, exist_ok=True)
    for test in manifest.get("fit_tests", []):
        name = test["name"]
        stl = scratch / f"{name}.stl"
        stl.unlink(missing_ok=True)
        cmd = ["openscad", "-o", str(stl)]
        for k, v in test.get("params", {}).items():
            cmd += ["-D", f"{k}={scad_value(v)}"]
        cmd.append(str(ROOT / "tests" / "fit_test.scad"))
        proc = subprocess.run(cmd, capture_output=True, text=True)
        out = proc.stderr + proc.stdout
        if "top level object is empty" in out:
            print(f"[fit ok] {name}: no overlap")
            continue
        if proc.returncode != 0 or not stl.exists():
            failures.append(f"fit test {name}: render failed\n{proc.stderr}")
            continue
        tris = load_stl_triangles(stl)
        vol = abs(mesh_volume(tris))
        # Coplanar face contact (a piece resting on another) yields
        # degenerate zero-volume triangles; only real volume fails.
        if vol > 0.01:
            failures.append(
                f"fit test {name}: pieces OVERLAP by {vol:.2f} mm^3 "
                f"— connector geometry is wrong")
        else:
            print(f"[fit ok] {name}: no overlap"
                  + (" (surface contact only)" if tris else ""))


def main():
    manifest = json.loads((ROOT / "config" / "build_manifest.json").read_text())
    OUT.mkdir(exist_ok=True)
    failures = []

    for piece in manifest["pieces"]:
        name = piece["name"]
        stl = OUT / f"{name}.stl"
        cmd = ["openscad", "-o", str(stl)]
        for k, v in piece.get("params", {}).items():
            cmd += ["-D", f"{k}={scad_value(v)}"]
        cmd.append(str(ROOT / piece["scad"]))

        print(f"[render] {name}")
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0 or not stl.exists():
            failures.append(f"{name}: render failed\n{proc.stderr}")
            continue

        err = validate_stl(stl)
        if err:
            failures.append(f"{name}: {err}")
            continue

        fields = dict(manifest.get("defaults", {}))
        fields.update(piece["description"])
        fields["kit_name"] = manifest["kit_name"]
        (OUT / f"{name}.txt").write_text(DESCRIPTION_TEMPLATE.format(**fields))
        print(f"[ok]     {name}.stl + {name}.txt")

    run_fit_tests(manifest, failures)

    if failures:
        print("\nBUILD FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        sys.exit(1)
    print(f"\nAll {len(manifest['pieces'])} pieces rendered and validated; "
          f"{len(manifest.get('fit_tests', []))} fit tests passed.")


if __name__ == "__main__":
    main()
