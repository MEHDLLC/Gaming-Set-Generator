# Extension Ideas — Dungeon/Castle Modular STL Generator

Companion to the Phase 0–7 project plan. Everything here is additive: options,
piece types, and outputs that fall out naturally from the same parametric engine.
Ordered roughly by value-per-unit-of-work.

---

## 0. Three decisions to lock before Phase 1

These are cheap now and expensive later, because every piece inherits them.

### 0.1 Reconsider the 32mm module

32mm is a *miniature scale* (eye-height of the figure), not a terrain grid unit.
The tabletop grid square is 1 inch / 25.4mm, and the established modular terrain
systems build on multiples of it — most commonly 2 inch / 50.8mm tiles
(2x2 grid squares) so that pieces span a usable footprint.

A 32mm module aligns with neither battlemats nor any existing terrain ecosystem,
which means pieces will visibly drift out of register when laid over a printed map.

Suggested fix: make `GRID_UNIT` a top-level parameter, default it to 25.4mm, and
express every piece as an integer multiple (1x, 2x, 3x, 4x). Anyone who wants 32mm
changes one value. This costs nothing to build in on day one.

### 0.2 Decide where the wall sits relative to the grid line

Three conventions, and they are not interchangeable:

- **Wall centered on the line** — interior floor area shrinks by half a wall thickness per side.
- **Wall outside the line** — interior stays a true N x N squares, footprint grows.
- **Wall occupies its own sliver between tiles** (the OpenLOCK approach) — cleanest for
  snap-together systems, but the wall is then a separate footprint from the floor.

Pick one, document it, and derive the wall-to-floor lip in Phase 2.3 from it.

### 0.3 Tolerance must not scale

When you add a global scale multiplier (15mm / 28mm / 54mm variants), clearances,
magnet pockets, and connector gaps must stay **absolute**. A 0.15mm clip clearance
scaled to 54mm becomes 0.29mm and the joint goes loose; scaled down to 15mm it
becomes 0.07mm and won't assemble. Keep two number classes in the code —
`scaled()` for aesthetic dimensions, `absolute()` for fit dimensions — and never
mix them.

---

## 1. Piece library additions

### 1.1 Structural gaps in the current MVP

The plan has straight wall, corner, and floor. A room needs more than that:

| Piece | Why it's needed |
|---|---|
| T-junction wall | Interior partition meeting an exterior wall |
| 4-way cross wall | Corridor intersections |
| Half-module and quarter-module fillers | Grids never divide evenly against a real floorplan |
| End cap / wall terminus | A wall that just stops (doorway jamb, ruin edge) |
| Column / freestanding pillar | Room dividers, hall supports |
| Pilaster (half-column on wall face) | Decorative, and hides seams between wall segments |
| Two-module archway | Open passage without a door |

### 1.2 Vertical circulation

The single biggest thing missing from the plan — multi-level is where modular sets
sell, and it reuses all the same connector math.

- Straight stair flight (parametric rise per module)
- Step-up transition tile between two floor elevations
- Spiral stair sized to sit inside a round tower core
- Ramp (mini-friendly and rubble-ramp variants)
- Landing / half-landing tile
- Second-storey floor plate that rests on wall tops (needs a wall-top registration notch)
- Balcony / wall-walk that clips to the top of a standard wall
- Catwalk / bridge spanning a gap

### 1.3 Round tower kit

Curved walls parameterised by radius and segment count, with the constraint that
N segments close exactly. Yields a whole product line from one function:

- Base ring segment, mid ring segment, crenellated top ring
- Conical roof (single piece or segmented for bed size)
- Arrow-loop variant of the curved segment
- Tower-to-straight-wall junction piece

### 1.4 Ruined variants — high value, low cost

A procedural break-line applied to any existing piece, driven by the same seed:
a noise-perturbed cut plane plus a few missing blocks at the edge. This roughly
doubles your catalogue without a single new base model, and "ruins" is one of the
most requested terrain styles.

Parameters: `damage_level` (0–100%), `break_height`, `rubble_at_base` (bool).

### 1.5 Floor tile variants

Trapdoor, pit (with removable insert), grate/drain, stairs-down hatch, water or
sewer channel, lava crack, cracked/collapsed, raised dais.

---

## 2. Connector options (extends Phase 1.4)

Additions to the four already planned:

- **OpenLOCK-style clip slot.** The single highest-leverage compatibility decision —
  it plugs your set into an existing ecosystem of thousands of pieces. Model the clip
  socket yourself from the published dimensions rather than importing anyone's mesh,
  and check the current license terms before advertising compatibility; some adjacent
  libraries (OpenForge and friends) carry share-alike licenses that would propagate
  to your output if you derived from their geometry.
- **Peg-board base plate.** Floor tiles peg into a universal underlay grid. Very stable
  for large layouts, and the base plate itself is a sellable item.
- **Printed-in-place dovetail / spring clip.** No hardware, no magnets.
- **Captive magnet pocket.** Pocket with a bridged-over ceiling so the magnet is
  invisible from the finished face. Add a glue-relief channel and a lead-in chamfer.
- **Magnet polarity keying.** Auto-emboss a tiny orientation mark (or make the pocket
  asymmetric) so magnets can't be installed backwards. This is the #1 assembly
  complaint in magnetic terrain sets.
- **Dual connector mode.** Generate both a clip slot and a magnet pocket so one piece
  works in either system.
- **Tolerance presets** rather than a raw number: `tight / normal / loose`, plus
  per-technology defaults (FDM 0.4 nozzle, FDM 0.6, resin — resin needs materially
  less clearance).

Also worth noting: the plan's 6x2mm and 8x3mm magnets are on the large side for
terrain. 3x2mm and 5x2mm are the common terrain sizes; offer the full list.

---

## 3. Surface texture & weathering — the missing pillar

Right now the plan has etched mosaics (Phase 3) but no wall texture at all. A
smooth-walled dungeon reads as a prototype; texture is what makes these look
finished, and it's the same seed-driven generator across the whole set.

**Masonry style dropdown:** coursed ashlar, random rubble, cyclopean, brick,
hewn block, timber frame, smooth plaster, natural cave.

**Parameters:** block size range, mortar gap width, relief depth, edge-wear/bevel
amount, course randomisation.

**Weathering pass:** procedural chips, cracks, missing blocks, moss/vine patches,
scaled by a single `weathering` slider.

**Custom heightmap input:** let a user drop in a PNG and displace the wall face
from it. Cheap to add, and it's the feature that lets buyers commission custom sets.

Store the texture seed in the `.txt` so any piece is exactly reproducible later —
that matters when someone comes back a year on wanting one more matching wall.

> Performance note: high-relief texture will bury OpenSCAD's legacy CSG engine.
> Plan on the Manifold backend, or generate texture as a mesh operation outside
> OpenSCAD, before you commit to the approach.

---

## 4. Print-optimisation options

These belong in the generator, not the slicer, because they're geometry:

- **Support-free mode.** Auto-chamfer every overhang past 45 degrees so nothing
  needs supports. Make this a headline selling point.
- **Elephant-foot compensation.** First-layer XY inset parameter.
- **Resin mode.** Hollow with automatic drain holes and internal ribbing.
- **Bed-size awareness.** Take bed dimensions as a parameter; auto-split oversized
  pieces along a clean plane with alignment pins, rather than silently emitting
  something unprintable.
- **Pre-arranged plate export.** Emit a multi-piece plate STL laid out and spaced
  for a given bed — saves buyers the arranging step.
- **Multi-material split.** Separate mesh per colour region (block vs mortar) so
  multi-colour printers can use the set directly.
- **Draft / standard / high detail levels** to keep CI render times sane.

---

## 5. Kit & set logic (extends Phase 4)

### 5.1 Style DNA

The strongest version of the "matching set" idea: one seed drives a *style vector* —
block size, mortar width, damage level, arch curvature, trim profile, corner
treatment — that every piece in the kit reads from. Family resemblance becomes a
property of the system rather than something you police piece by piece.

### 5.2 Floorplan importer

Feed the generator an ASCII or JSON grid map of a dungeon; it emits the exact piece
list and quantities needed, plus a build sheet showing where each piece goes.

This is the feature that turns a file generator into a tool people talk about, and
it's the natural bridge to a paid/custom-order service.

### 5.3 Kit manifest

Auto-generate a CSV/JSON per kit: piece name, quantity, estimated grams, estimated
print time, magnets required. From that, derive:

- A magnet shopping list for the whole kit
- A total filament cost estimate
- A completeness check ("this floorplan needs a T-junction you haven't generated")

### 5.4 Piece identification

Emboss a small part ID and set ID on the underside of every piece. After a 40-piece
print job, buyers cannot tell near-identical walls apart, and this solves it for the
cost of one text extrusion. Optionally add a version stamp so you can tell v1 from v2
pieces at a glance.

### 5.5 Bundle tiers

Starter room, corridor pack, tower pack, boss room, GM's full set — defined as
manifests over the same piece library, no new geometry.

---

## 6. Output files beyond .stl + .txt

- **3MF alongside STL.** STL carries no units and no metadata; 3MF carries both plus
  colour, and every current slicer prefers it. Low effort, real quality-of-life win.
- **STEP export** if you ever move to a CAD kernel — lets customers modify pieces.
- **Per-marketplace description variants.** Etsy, Cults3D, MyMiniFactory, Printables
  and Thingiverse have different field limits and tag systems. Same template engine,
  different renderers.
- **SEO tag generator** for the Etsy listing fields.
- **License file** emitted per kit (personal-use vs commercial-print tiers).
- **Assembly instructions** PDF for kits that need magnets or multi-part glue-ups.
- **Changelog** per kit so returning customers know what changed.

Check your marketplace's per-file size and file-count limits before designing the
bundle step — digital listings are usually capped, and a full kit will exceed a
naive single-zip approach.

> Minor: the fixed closing line in the Phase 5 template reads
> "Hit me up if you'd something custom!" — missing a word. Since it's hard-coded
> into every generated file, worth fixing before the first batch ships.

---

## 7. Renders & presentation (extends Phase 4.4)

- Turntable GIF/MP4 per piece (OpenSCAD camera sweep, or headless Blender for quality)
- Assembled hero render — several pieces snapped into a finished room
- Scale-reference render with a miniature silhouette next to the piece
- Dimension-annotated technical view
- A consistent square render set sized for marketplace thumbnails, with the
  "what's included" contact sheet as a second image
- Watermarked preview renders vs clean paid files

---

## 8. Automation & QA (extends Phase 0 / Phase 6)

- **OpenSCAD customizer parameter sets** (`.json`) driving a GitHub Actions build
  matrix — one file defines the whole catalogue.
- **Render only what changed**, with a nightly full regeneration as the backstop.
- **Mesh validation gate.** Fail CI on non-manifold output, inverted normals, or
  zero-volume shells. A broken STL that reaches a customer costs more than the check.
- **Dimensional assertions.** Assert the bounding box actually equals N x GRID_UNIT.
  Catches a whole class of silent parametric breakage.
- **Automated fit test.** Boolean-intersect two mating pieces in code and assert the
  intersection volume is ~0 and the gap falls inside tolerance. This is Phase 1.5's
  "check it in slicer preview" turned into a test that runs on every push — and it's
  the single QA item most likely to save you a bad print batch.
- **Geometry regression hashing.** Hash the mesh of a fixed-seed reference piece;
  fail if it changes unexpectedly.
- **Auto-generated README gallery** of every piece with thumbnails.
- **GitHub Release per kit** with the zip attached.

---

## 9. Theme expansion (extends Phase 7.4)

Same engine, new texture + trim profiles:

Cave/cavern, sewer, crypt/catacomb, wizard's tower, tavern/village interior,
ship deck & dock, ice, volcanic, swamp, ruins, sci-fi corridor, post-apocalyptic.

### Scatter terrain & furniture

Separate small product line, same set ID and style DNA, no connector system needed —
so it's fast to produce and it makes kits feel complete:

Crates, barrels, braziers, torches, altars, statues, chests, rubble piles, wells,
sarcophagi, bookshelves, tables, beds, thrones, fireplaces, doors as standalone props.

---

## 10. Web configurator (extends Phase 7.1)

- Live 3D preview (three.js) with the same dropdowns as the generator
- **Shareable config permalink** — parameters encoded in the URL. Customers can send
  you their exact config, which is the whole custom-order workflow in one feature.
- "Surprise me" randomiser with per-parameter lock toggles
- Preset gallery of previously published kits
- Download single piece, or download kit as zip

---

## Suggested priority

If you want the shortest path to a set that looks and sells like a finished product:

1. Lock the grid unit and the wall-placement convention (Section 0)
2. Wall texture + weathering system (Section 3) — biggest visual return
3. T-junction, cross, and half-module fillers (Section 1.1) — makes rooms actually buildable
4. Stairs and a second-storey floor plate (Section 1.2) — unlocks multi-level
5. Automated fit test in CI (Section 8) — stops bad geometry reaching print
6. Ruined variants via damage seed (Section 1.4) — doubles the catalogue nearly free
7. Part-ID embossing + kit manifest (Sections 5.3, 5.4) — solves post-print confusion
8. 3MF output (Section 6) — small change, immediate usability win
