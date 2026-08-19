# Gaming-Set-Generator

Parametric generator for modular dungeon/castle 3D-printable terrain.
Every piece is generated from OpenSCAD source, snapped to a shared grid,
and shipped as a matching `.stl` + `.txt` description pair.

## Engine & core decisions (Phase 0)

- **Engine:** OpenSCAD (CLI-driven, renders headless in GitHub Actions).
- **Grid unit:** `GRID_UNIT = 25.4mm` (1 inch — one battlemat square).
  All pieces are integer multiples of it. Change one constant in
  `src/lib/grid.scad` to retarget the whole library.
- **Tolerances are absolute:** fit-critical dimensions (clearances,
  magnet pockets, pin holes) never scale with the aesthetic `SCALE`
  multiplier. Presets: `tight` 0.10mm / `normal` 0.15mm / `loose` 0.25mm.
- **Connectors:** tab & slot, magnet pockets (3x2 / 5x2 / 6x2 / 8x3mm),
  dowel pins (1.75mm filament offcuts), or flush butt-joint — shared
  library in `src/lib/connectors.scad` so every piece in a kit mates.

## Layout

```
src/lib/        shared OpenSCAD libraries (grid, connectors)
src/pieces/     one .scad per piece type
config/         build manifest: which pieces + parameter sets to render
scripts/        build.py — render, validate mesh, emit descriptions
generated/      output .stl + .txt (rebuilt by CI)
```

## Build locally

```
sudo apt-get install openscad
python3 scripts/build.py
```

Renders every piece in `config/build_manifest.json` into `generated/`,
runs mesh QA (non-empty, no degenerate faces, manifold), and writes a
matching `.txt` description per STL. Fails loudly if any piece breaks.

## CI

`.github/workflows/render.yml` runs the same build on every push that
touches sources, uploads the bundle as a workflow artifact, and commits
the regenerated `generated/` files back to the branch.

## Roadmap

See the phase plan; extension ideas and priorities live in
[docs/EXTENSIONS.md](docs/EXTENSIONS.md).
