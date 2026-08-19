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

## Piece library (Phase 1)

| Piece | Variants |
|---|---|
| `fit_coupon` | one mating test pair per connector type — print first to dial in fit |
| `floor_tile` | any W x L grid footprint; wall-foot grooves on edges and interior grid lines |
| `wall_straight` | any length; heights: parapet (1u) / standard (2u) / tower (3u); openings below |
| `wall_corner` | 90°, right/left-handed (tab chains are chiral) |

Wall openings (`OPENING` parameter): `door_arch`, `door_rect`,
`door_portcullis` (2-unit walls), `window_slit` (splayed embrasure),
`window_arch`, `window_barred` (1-unit walls). Cutout sizes, arch
rise, sill heights, and bar pitch are all parameters.

Floors fill grid cells; walls run along grid lines, centered on them.
Walls carry a tenon rail underfoot that drops into the floor groove
channel, registering wall lines to the grid (print walls lying flat).
Tab gender convention: floors are male on +X/+Y edges, female on
-X/-Y; wall chains alternate male-into-female, and corners pass the
chain through (male out one arm, female in the other).

## Layout

```
src/lib/        shared OpenSCAD libraries (grid, connectors, pieces)
src/pieces/     one entry .scad per piece type
config/         build manifest: pieces, parameter sets, fit tests
scripts/        build.py — render, validate mesh, emit descriptions
tests/          fit_test.scad — boolean-intersection snap-fit checks
generated/      output .stl + .txt (rebuilt by CI)
```

## Build locally

```
sudo apt-get install openscad
python3 scripts/build.py
```

Renders every piece in `config/build_manifest.json` into `generated/`,
runs mesh QA (non-empty, no degenerate faces, manifold), writes a
matching `.txt` description per STL, then runs the snap-fit tests:
each mated piece pair is boolean-intersected and must produce zero
overlap volume. Fails loudly if any piece breaks.

## CI

`.github/workflows/render.yml` runs the same build on every push that
touches sources, uploads the bundle as a workflow artifact, and commits
the regenerated `generated/` files back to the branch.

## Roadmap

See the phase plan; extension ideas and priorities live in
[docs/EXTENSIONS.md](docs/EXTENSIONS.md).
