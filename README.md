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
| `mosaic_tile` | centerpiece floor: compass rose, heraldic shield, knotwork lattice, or blank ring; `ETCH_DEPTH` 0.6 = painting guide, 1.2 = shadow relief |
| `stairs_straight` | staircase on a floor-tile footprint, 4 steps per grid unit of run, lands flush with the next storey's deck surface |
| `deck_tile` | upper floor / ceiling plate, groove channels on BOTH faces; optional stairwell opening |
| `column` | storey-height column; cross tenons snap into the groove-channel crossings of the floor below and deck above |
| `curved_wall` | arc segment (`SEG_DEGREES`, default 90 — four close a ring) at `TOWER_R_UNITS` centerline radius; same end dovetails, curved foot/top rails, curved masonry, openings, optional battlements |
| `tower_floor` | round plate with ring channels for curved wall rails; deck variant grooved both faces; optional 1x1-cell hatch |
| `hatch_lid` | drop-in lid with lip and ring pull for any 1x1-cell opening |

Wall openings (`OPENING` parameter): `door_arch`, `door_rect`,
`door_portcullis` (2-unit walls), `window_slit` (splayed embrasure),
`window_arch`, `window_barred` (1-unit walls). Cutout sizes, arch
rise, sill heights, and bar pitch are all parameters.

Wall decor (`DECOR` parameter, one feature per wall): `sconce`
(angled torch socket), `banner_peg` (rod peg with retaining tip),
`gargoyle_socket` (glue pocket for a separately printed figure).

Wall variants: `CRENELLATED` cuts battlements into any wall top
(a half-height crenellated parapet doubles as a deck-edge railing);
`RUIN` (0-1) applies a seeded step-down collapse profile — end
connectors truncate with the profile so partial-height mating still
works.

Surface texture (`TEXTURE` parameter, seeded by `TEXTURE_SEED`):
`ashlar` (coursed stone), `brick` (running bond), `rubble` (rough
flagstone) — mortar grooves plus subtle random block insets, cut into
wall faces, floor tops, and stair sides. Deterministic per seed, so a
kit's look is exactly reproducible; grooves keep clear of connector
ends. Texture is a seeded kit style slot like doors and windows.

Floors fill grid cells; walls run along grid lines, centered on them.
Walls carry a tenon rail underfoot that drops into the floor groove
channel, registering wall lines to the grid (print walls lying flat).

**Storeys stack.** Walls carry the same rail on top; a deck tile's
underside grooves drop onto the wall tops (and onto column tenons),
and its top grooves accept the next storey's walls — so levels stack
indefinitely with no extra connector types. Columns stand at grid
intersections, where four groove channels already cross. Stack pitch:
`floor_t + wall_h` per storey.
Tab gender convention: floors are male on +X/+Y edges, female on
-X/-Y; wall chains alternate male-into-female, and corners pass the
chain through (male out one arm, female in the other).

## Kits (Phase 4)

Pieces are organized into **kits** — matched sets defined in
`config/kits/*.json`. A kit's `shared` block (connector type, fit,
magnet size) is merged into every piece and pieces cannot override it,
so everything in a kit mates by construction. Style slots (door,
window, mosaic, decor) are picked deterministically from the kit's
`seed` — change the seed to **reroll a whole matching kit** — or
pinned explicitly in `styles`. Each kit renders to
`generated/<kit_id>/` along with iso + top-down preview thumbnails.

Current kits: `stonebound_keep` (tab & slot, seed 42),
`stonebound_turret` (matching turret expansion — same seed and
connectors, so it mixes with the Keep), `lodestone_vault` (5x2mm
magnets, seed 7), plus the `calibration` coupon set.

Every piece ships with three files: `<name>.stl`, `<name>.txt`
(the four-section listing description), and `<name>.tags.txt` (a
suggested listing title plus up to 13 marketplace tags, each within
Etsy's 20-character limit, derived from the piece's actual style,
connector, and kit).

Each kit folder also carries a `manifest.csv` (per-piece bounding
box, solid volume/weight, triangle count, magnets needed, plus kit
totals — including the magnet shopping list), and every non-coupon
piece has its part ID embossed into a hidden face (floor undersides,
wall foot rails) so printed pieces stay identifiable.

## Layout

```
src/lib/        shared OpenSCAD libraries (grid, connectors, pieces)
src/pieces/     one entry .scad per piece type
config/kits/    kit definitions (shared params, seed, piece list)
config/fit_tests.json  snap-fit test matrix
scripts/        build.py — render, validate, describe, preview
tests/          fit_test.scad, kit_preview.scad
generated/      output per kit: .stl + .txt + preview .png (CI-built)
```

## Build locally

```
sudo apt-get install openscad
python3 scripts/build.py
```

Renders every kit in `config/kits/` into `generated/<kit_id>/`,
runs mesh QA (non-empty, no degenerate faces, manifold), writes a
matching `.txt` description per STL, then runs the snap-fit tests:
each mated piece pair is boolean-intersected and must produce zero
overlap volume. A final parity gate requires every `.stl` to have its
matching `.txt` and vice versa. Fails loudly if any piece breaks.

## CI

`.github/workflows/render.yml` runs the same build on every push that
touches sources, uploads the outputs and per-kit `.zip` bundles as
workflow artifacts, and commits the regenerated `generated/` files
back to the branch. Pushing a `v*` tag additionally publishes a
GitHub Release with the kit zips attached — ready-to-list digital
bundles.

## Roadmap

See the phase plan; extension ideas and priorities live in
[docs/EXTENSIONS.md](docs/EXTENSIONS.md).
