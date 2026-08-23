// headphone.scad — voxel-scene headphone stands with a desk clamp.
// Requires grid.scad and connectors.scad (the dovetail is reused for
// the clamp mount). All dimensions are absolute mm — this product
// line does not scale with the terrain kits.
//
// Construction: identical blocky pixel-art slabs front and back with
// a smooth rounded core between them, hidden inside the silhouette.
// The headband drops into the channel and rests on the core's domed
// crest; the ear cups hang clear on either side of the trunk.
//
// Silhouette rule (enforced by assert on every design): the trunk is
// narrower than the widest part of the scene above it, the scene is
// at most 4in wide, and the trunk at most 2in.
//
// Print lying on the back face: every silhouette overhang becomes
// flat geometry, so no supports.

HP_PIECE   = "tree";   // tree | sheep | chicken | clamp | screw
STAND_SEED = 42;

HP_PX     = 11;    // voxel pixel size
HP_COLS   = 8;     // scene width in pixels -> 88mm  (<= 4in)
HP_ROWS   = 19;    // 17 scene rows + 2 base rows   -> 209mm tall
HP_SLAB   = 7;     // slab thickness behind the relief
HP_CORE_D = 34;    // band channel width (fits 25-32mm headbands)

// Voxel relief. Each block is pushed out (front) or set back (back)
// by a level 0-3 derived from how enclosed it is, so interior blocks
// bulge and edge blocks step away — the scene reads as a rounded 3D
// voxel mass from both sides rather than a flat plaque.
HP_RELIEF     = 3.4;   // mm of front protrusion per level
HP_MIN_CAP    = 0.9;   // every block stands proud at least this much
HP_BACK_STEP  = 1.2;   // mm of back recess per level
HP_BACK_STYLE = "recessed";  // "recessed" prints flat | "raised" is
                             // fully 3D both sides but needs supports

function hp_w()     = HP_COLS * HP_PX;              // 88
function hp_d()     = 2 * HP_SLAB + HP_CORE_D;      // 48
function hp_h()     = HP_ROWS * HP_PX;              // 209
function hp_base_h()= 2 * HP_PX;                    // 22
function hp_max_w() = 101.6;                        // 4 in
function hp_max_t() = 50.8;                         // 2 in

// ---------------------------------------------------------------------
// Scene maps. A map is a list of rows of booleans, row 0 at the top.

function str_map(m) =
    [for (r = [0 : len(m) - 1])
        [for (c = [0 : len(m[r]) - 1]) m[r][c] == "#"]];

// Silhouette span of one row, in pixels (rightmost minus leftmost).
function row_span(row) =
    let (idx = [for (c = [0 : len(row) - 1]) if (row[c]) c])
    len(idx) == 0 ? 0 : max(idx) - min(idx) + 1;

function span_range(map, r0, r1) =
    max([for (r = [r0 : r1]) row_span(map[r])]);

function top_width(map, trunk_row)   = span_range(map, 0, trunk_row - 1)
                                       * HP_PX;
function trunk_width(map, trunk_row) = span_range(map, trunk_row,
                                                  len(map) - 1) * HP_PX;

// True when a design satisfies every silhouette rule. Pure function,
// so tests/hp_seed_sweep.scad can check seeds without building
// geometry.
function hp_valid(map, trunk_row) =
    let (tw = trunk_width(map, trunk_row), topw = top_width(map, trunk_row))
    tw < topw && topw <= hp_max_w() && tw <= hp_max_t() && tw > 0;

// Filled-neighbour test, false outside the map.
function nb(map, r, c) =
    (r < 0 || r >= len(map) || c < 0 || c >= HP_COLS) ? 0
    : (map[r][c] ? 1 : 0);

// Per-block relief level 0-3: blocks with more filled neighbours sit
// proud, blocks on the silhouette edge step back, plus seeded jitter
// so no two stands have the same surface.
function depth_field(map, seed) =
    let (rnd = rands(0, 1, 200, seed * 37 + 5))
    [for (r = [0 : len(map) - 1])
        [for (c = [0 : HP_COLS - 1])
            let (cnt = nb(map, r - 1, c) + nb(map, r + 1, c)
                     + nb(map, r, c - 1) + nb(map, r, c + 1)
                     + nb(map, r - 1, c - 1) + nb(map, r - 1, c + 1)
                     + nb(map, r + 1, c - 1) + nb(map, r + 1, c + 1),
                 v = rnd[(r * HP_COLS + c) % 200],
                 adj = v > 0.78 ? 1 : (v < 0.22 ? -1 : 0))
            max(0, min(3, floor(cnt * 3.99 / 8) + adj))]];

// Force specific blocks to a chosen relief level, so features are made
// of blocks that sit proud or sunken — a protruding muzzle, sunken
// eye sockets — rather than lines engraved on a flat face.
function apply_overrides(lv, ov) =
    [for (r = [0 : len(lv) - 1])
        [for (c = [0 : HP_COLS - 1])
            let (hit = [for (o = ov) if (o[0] == r && o[1] == c) o[2]])
            len(hit) > 0 ? hit[0] : lv[r][c]]];

// ---------------------------------------------------------------------
// Geometry helpers.

// One scene pixel on the front (face 0) or back (face 1) slab.
module hp_px(c, r, face) {
    translate([c * HP_PX, face * (hp_d() - HP_SLAB),
               hp_h() - (r + 1) * HP_PX])
        cube([HP_PX + 0.01, HP_SLAB, HP_PX + 0.01]);
}

// Pixel boundaries in mm.
function px_x0(c) = c * HP_PX;
function px_x1(c) = (c + 1) * HP_PX;
function px_z0(r) = hp_h() - (r + 1) * HP_PX;
function px_z1(r) = hp_h() - r * HP_PX;

// Free-form recess on a slab's outer face, absolute coordinates.
module hp_etch_box(x0, z0, x1, z1, face, depth = 0.7) {
    translate([x0, face == 0 ? -EPS : hp_d() - depth, z0])
        cube([x1 - x0, depth + EPS, z1 - z0]);
}

// Shallow grid on the pixel boundaries so every block reads as a
// separate cube even where neighbours merge into one flat face.
module hp_voxel_grid(face, depth = 0.5, w = 0.9) {
    for (c = [1 : HP_COLS - 1])
        hp_etch_box(px_x0(c) - w / 2, -EPS, px_x0(c) + w / 2,
                    hp_h() + EPS, face, depth);
    for (r = [1 : HP_ROWS - 1])
        hp_etch_box(-EPS, r * HP_PX - w / 2, hp_w() + EPS,
                    r * HP_PX + w / 2, face, depth);
}

// Shallow etched pixel on the outer surface of a slab.
module hp_etch(c, r, face, inset = 1.6, depth = 0.7) {
    translate([c * HP_PX + inset / 2,
               face == 0 ? -EPS : hp_d() - depth,
               hp_h() - (r + 1) * HP_PX + inset / 2])
        cube([HP_PX - inset, depth + EPS, HP_PX - inset]);
}

// Recess cut into a block's own outer face, wherever the relief has
// placed it.
module hp_relief_etch(c, r, face, level, inset = 3, depth = 1.3) {
    x0 = px_x0(c) + inset / 2;
    z0 = px_z0(r) + inset / 2;
    if (face == 0)
        translate([x0, -max(HP_MIN_CAP, level * HP_RELIEF) - EPS, z0])
            cube([HP_PX - inset, depth + EPS, HP_PX - inset]);
    else
        translate([x0, hp_d() - (3 - level) * HP_BACK_STEP - depth, z0])
            cube([HP_PX - inset, depth + EPS, HP_PX - inset]);
}

// Smooth core: a rounded column running the full height of the stand,
// finished with a domed crest the headband rests on. Narrower than the
// trunk in X and exactly the channel depth in Y, so it is invisible
// from the front and back but fully visible (and smooth) from the side.
module hp_core(crest_z) {
    rr = 8;
    cw = hp_trunk_hint() - 8;
    hull() {
        for (x = [hp_w() / 2 - cw / 2 + rr, hp_w() / 2 + cw / 2 - rr],
             y = [HP_SLAB + rr, hp_d() - HP_SLAB - rr]) {
            translate([x, y, 0]) cylinder(h = 1, r = rr);
            translate([x, y, crest_z - rr]) sphere(rr);
        }
    }
}

// Nominal trunk width used to size the core (4 px on every design).
function hp_trunk_hint() = 4 * HP_PX;

// Stepped base plinth: a wider ground block with a narrower top
// course, blocked out like the rest of the scene. The rear face stays
// flat at y = hp_d() so the stand prints lying on its back.
module hp_base() {
    difference() {
        union() {
            translate([-4, -4, 0])
                cube([hp_w() + 8, hp_d() + 4, HP_PX]);
            translate([0, -1, HP_PX - EPS])
                cube([hp_w(), hp_d() + 1, HP_PX + EPS]);
        }
        translate([hp_w() / 2, hp_d(), -EPS])
            rotate([0, 0, -90]) tab_female(hp_base_h() + 2 * EPS);
        // block out both courses on every exposed face
        for (face = [0, 1]) {
            hp_voxel_grid(face, 0.6);
            hp_etch_box(-EPS, HP_PX - 0.45, hp_w() + EPS,
                        HP_PX + 0.45, face, 0.6);
        }
        for (c = [1 : HP_COLS - 1])
            translate([px_x0(c) - 0.45, -4 - EPS, -EPS])
                cube([0.9, 2, hp_base_h() + 2 * EPS]);
    }
}

// Base + core + both relief scenes, with the silhouette rules
// asserted. Front blocks stand proud by their level; back blocks are
// recessed by the inverse (so the rear plane stays flat and printable)
// or raised, for a display piece printed standing.
module hp_scene(map, trunk_row, crest_z, seed = 0, ov = []) {
    assert(hp_w() + 8 <= hp_max_w(),
           str("base plinth envelope ", hp_w() + 8,
               "mm exceeds the 4in limit"));
    assert(hp_valid(map, trunk_row),
           str("silhouette rule violated: trunk ",
               trunk_width(map, trunk_row), "mm vs top ",
               top_width(map, trunk_row), "mm (trunk must be narrower ",
               "than the top, top <= 101.6, trunk <= 50.8)"));
    lvf = apply_overrides(depth_field(map, seed), ov);
    lvb = apply_overrides(depth_field(map, seed + 991), ov);
    difference() {
        union() {
            hp_base();
            hp_core(crest_z);
            for (r = [0 : len(map) - 1], c = [0 : HP_COLS - 1])
                if (map[r][c]) {
                    // continuous slabs carry the structure
                    translate([px_x0(c), 0, px_z0(r)])
                        cube([HP_PX + 0.01, HP_SLAB, HP_PX + 0.01]);
                    translate([px_x0(c), hp_d() - HP_SLAB, px_z0(r)])
                        cube([HP_PX + 0.01, HP_SLAB, HP_PX + 0.01]);
                    // front cap: inset so each block reads separately
                    let (cap = max(HP_MIN_CAP, lvf[r][c] * HP_RELIEF))
                        translate([px_x0(c) + 0.5, -cap, px_z0(r) + 0.5])
                            cube([HP_PX - 1, cap + EPS, HP_PX - 1]);
                    if (HP_BACK_STYLE == "raised" && lvb[r][c] > 0)
                        translate([px_x0(c) + 0.5, hp_d() - EPS,
                                   px_z0(r) + 0.5])
                            cube([HP_PX - 1,
                                  lvb[r][c] * HP_RELIEF + EPS, HP_PX - 1]);
                }
        }
        if (HP_BACK_STYLE == "recessed")
            for (r = [0 : len(map) - 1], c = [0 : HP_COLS - 1])
                if (map[r][c] && lvb[r][c] < 3)
                    let (rec = (3 - lvb[r][c]) * HP_BACK_STEP)
                        translate([px_x0(c) + 0.5, hp_d() - rec,
                                   px_z0(r) + 0.5])
                            cube([HP_PX - 1, rec + EPS, HP_PX - 1]);
        hp_voxel_grid(1, 0.6);
    }
}

function hp_crest() = hp_h() - 3 * HP_PX;

// ---------------------------------------------------------------------
// Voxel tree: seeded canopy over a 4px trunk. Every seed is a
// different tree; the canopy core is forced wide enough that the
// silhouette rule holds for any seed.
// Canopy silhouette in pixels per row: a stepped crown widening to a
// full-width mass, then a wide underside that overhangs the trunk.
CANOPY_SPAN = [4, 6, 8, 8, 8, 8, 6, 6];

function tree_map(seed) =
    let (rnd = rands(0, 1, 96, seed * 101))
    [for (r = [0 : 16])
        [for (c = [0 : HP_COLS - 1])
            r <= 7
              ? (let (span = CANOPY_SPAN[r],
                      lo = (HP_COLS - span) / 2,
                      hi = lo + span - 1,
                      cc = min(c, HP_COLS - 1 - c))
                 (c >= lo && c <= hi
                  && !((c == lo || c == hi) && rnd[r * 8 + cc] > 0.62))
                 // occasional block poking past the profile
                 || ((c == lo - 1 || c == hi + 1)
                     && rnd[r * 8 + cc + 4] > 0.80))
              : (c >= 2 && c <= 5)]];

module hp_tree(seed = STAND_SEED) {
    // The seeded relief field alone gives the canopy its bulge and the
    // trunk its knots, so the tree needs no engraved detail.
    hp_scene(tree_map(seed), 8, hp_crest(), seed);
}

// ---------------------------------------------------------------------
// Voxel sheep head over a woolly neck.
SHEEP_ROWS = [
    " ###### ",
    "########",
    "########",
    "########",
    " ###### ",
    " ###### ",
    "  ####  ", "  ####  ", "  ####  ", "  ####  ", "  ####  ",
    "  ####  ", "  ####  ", "  ####  ", "  ####  ", "  ####  ",
    "  ####  "
];

SHEEP_OV = concat(
    [[2, 1, 0], [2, 6, 0]],                        // sunken eye blocks
    [for (r = [3 : 4]) for (c = [2 : 5]) [r, c, 3]],  // muzzle stands proud
    [for (r = [1 : 3]) for (c = [0, 7]) [r, c, 1]]);  // ears set back

module hp_sheep(seed = STAND_SEED) {
    difference() {
        hp_scene(str_map(SHEEP_ROWS), 6, hp_crest(), seed, SHEEP_OV);
        for (face = [0, 1], c = [2, 5])            // nostrils on the muzzle
            hp_relief_etch(c, 3, face, 3, 6, 1.6);
    }
}

// ---------------------------------------------------------------------
// Voxel chicken: small head over a broad body, standing on narrow
// legs — the body is the widest mass and the legs are the trunk.
CHICKEN_ROWS = [
    "  ####  ",
    "  ####  ",
    "  ####  ",
    "  ####  ",
    " ###### ",
    "########",
    "########",
    "########",
    "########",
    " ###### ",
    "  ####  ", "  ####  ", "  ####  ", "  ####  ", "  ####  ",
    "  ####  ",
    "  ####  "
];

CHICKEN_OV = concat(
    [[1, 2, 0], [1, 5, 0]],                        // sunken eye blocks
    [[2, 3, 3], [2, 4, 3]],                        // beak stands proud
    [[0, 2, 3], [0, 5, 3]],                        // comb blocks
    [for (r = [5 : 8]) for (c = [0, 7]) [r, c, 1]]);  // wings set back

CHICKEN_LEG_OV = [for (r = [10 : 16]) for (c = [3, 4]) [r, c, 0]];

module hp_chicken(seed = STAND_SEED) {
    // Legs: the inner two columns sit back, so the pair of legs reads
    // as two separate posts instead of one slab.
    hp_scene(str_map(CHICKEN_ROWS), 10, hp_crest(), seed,
             concat(CHICKEN_OV, CHICKEN_LEG_OV));
}

// ---------------------------------------------------------------------
// Desk clamp. Table top at z = 0, table occupies y > 0, edge at y = 0.
// The upper jaw lies on the table, the stand sits on it and slides
// down onto the dovetail rail; the spine wraps the edge and the lower
// jaw carries a printed thumbscrew that bears up on the underside.
CLAMP_W     = 48;
CLAMP_PLATE = 6;
CLAMP_REACH = 56;
CLAMP_SPINE = 12;
CLAMP_GAP   = 40;   // maximum table thickness
CLAMP_JAW   = 10;
CLAMP_POST  = 26;
CLAMP_BOSS  = 12;
SCREW_PITCH = 6;
SCREW_CORE  = 9;
SCREW_LEN   = 55;

// Absolute z where the tapped thread starts (shared with the fit test
// so the screw's helix phase can be aligned).
function clamp_thread_z() = -(CLAMP_GAP + CLAMP_JAW + CLAMP_BOSS);
function clamp_thread_len() = CLAMP_BOSS + CLAMP_JAW;

// Helical thread by twisted extrusion: a round bump swept around a
// core. The female form is grown radially for clearance.
module thread_form(len, core_d, bump_d, off) {
    linear_extrude(height = len, twist = -360 * len / SCREW_PITCH,
                   slices = max(20, len * 3), convexity = 10)
        union() {
            circle(d = core_d);
            translate([off, 0]) circle(d = bump_d);
        }
}

module desk_clamp() {
    difference() {
        union() {
            cube([CLAMP_W, CLAMP_REACH, CLAMP_PLATE]);
            translate([0, CLAMP_REACH, 0])
                cube([CLAMP_W, 10, CLAMP_PLATE + CLAMP_POST]);
            translate([CLAMP_W / 2, CLAMP_REACH, CLAMP_PLATE])
                rotate([0, 0, -90]) tab_male(hp_base_h());
            translate([0, -CLAMP_SPINE, -(CLAMP_GAP + CLAMP_JAW)])
                cube([CLAMP_W, CLAMP_SPINE,
                      CLAMP_GAP + CLAMP_JAW + CLAMP_PLATE]);
            translate([0, -CLAMP_SPINE, -(CLAMP_GAP + CLAMP_JAW)])
                cube([CLAMP_W, CLAMP_SPINE + 40, CLAMP_JAW]);
            translate([CLAMP_W / 2, 22, clamp_thread_z()])
                cylinder(h = CLAMP_BOSS + EPS, d = 22);
        }
        translate([CLAMP_W / 2, 22, clamp_thread_z() - EPS])
            thread_form(clamp_thread_len() + 2 * EPS,
                        SCREW_CORE + 0.8, 5.3, 3.2);
    }
}

module clamp_screw() {
    difference() {
        cylinder(h = 8, d = 26);
        for (a = [0 : 45 : 315]) rotate([0, 0, a])
            translate([15, 0, -EPS]) cylinder(h = 8 + 2 * EPS, d = 7);
    }
    translate([0, 0, 8 - EPS])
        thread_form(SCREW_LEN, SCREW_CORE, 4.6, 3.2);
    translate([0, 0, 8 + SCREW_LEN - EPS])
        scale([1, 1, 0.55]) sphere(d = SCREW_CORE);
}

module hp_piece(kind = HP_PIECE, seed = STAND_SEED) {
    if (kind == "tree")    hp_tree(seed);
    if (kind == "sheep")   hp_sheep(seed);
    if (kind == "chicken") hp_chicken(seed);
    if (kind == "clamp")   desk_clamp();
    if (kind == "screw")   clamp_screw();
}
