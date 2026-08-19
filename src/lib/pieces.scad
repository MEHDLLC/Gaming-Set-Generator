// pieces.scad — the core piece library.
// Requires grid.scad and connectors.scad to be included first.
//
// Grid convention: floors fill grid cells; walls run along grid lines,
// centered on them. Chains of gendered (tab) pieces alternate
// male-into-female; magnet/dowel/none pieces are genderless.
//
// Style selections (OPENING, DECOR, MOSAIC, ETCH_DEPTH) are globals so
// the CLI can drive single-piece renders, but every module also takes
// them as arguments so one scene can mix styles (kit previews, future
// floorplan compiler).

// Wall-end dovetail, sized to fit inside the wall thickness (absolute).
WALL_TAB_NECK  = 3;
WALL_TAB_HEAD  = 4.8;
WALL_TAB_DEPTH = 4;

// -- Openings -----------------------------------------------------------
// "none" | "door_arch" | "door_rect" | "door_portcullis" |
// "window_slit" | "window_arch" | "window_barred"
OPENING = "none";

// Door cutout (scaled; heights measured from the wall base).
DOOR_W    = 16;
DOOR_H    = 38;   // total height, arch included
ARCH_RISE = 8;    // arch height within DOOR_H

// Window cutout (scaled).
WIN_W         = 10;
WIN_H         = 12;   // total height, arch included
WIN_SILL      = 22;
WIN_ARCH_RISE = 4;

// Arrow slit (scaled). Splays open toward the -Y (interior) face by
// SLIT_SPLAY x width and +/-2mm vertically (embrasure).
SLIT_W     = 3;
SLIT_H     = 24;
SLIT_SILL  = 14;
SLIT_SPLAY = 3.5;

// Bars for portcullis doors / barred windows (scaled).
BAR_PITCH = 5.5;
BAR_SIZE  = 2;

// -- Wall decor ---------------------------------------------------------
// "none" | "sconce" | "banner_peg" | "gargoyle_socket"
DECOR        = "none";
DECOR_H_FRAC = 0.72;
SCONCE_D     = 4;      // torch stem diameter (absolute, fit)
PEG_D        = 3;

// -- Mosaic centerpieces --------------------------------------------------
// "none" | "compass" | "shield" | "knotwork" | "blank"
MOSAIC     = "none";
ETCH_DEPTH = 0.6;   // scaled; ~0.6 painting guide, ~1.2 shadow relief

// -- Wall-to-floor registration -------------------------------------------
// Walls carry a tenon rail under their base that drops into a groove
// cut along floor tiles' top edges (and interior grid lines of
// multi-cell tiles). Two adjacent tiles each contribute half the
// channel. Fit-critical -> absolute mm.
WALL_FOOT     = true;
FLOOR_GROOVES = true;
FOOT_W        = 3;
FOOT_H        = 1.4;
FOOT_GROOVE_D = 1.6;

// Structural thicknesses auto-grow when a magnet must fit in the edge.
function floor_t() = (CONNECTOR == "magnet")
    ? max(scaled(FLOOR_THICKNESS), magnet_d() + 2.4)
    : scaled(FLOOR_THICKNESS);
function wall_t() = (CONNECTOR == "magnet")
    ? max(scaled(WALL_THICKNESS), magnet_d() + 2.4)
    : scaled(WALL_THICKNESS);
function wall_h() = grid(WALL_HEIGHT_UNITS);

// ---------------------------------------------------------------------
// Floor tile: w x l grid cells, one connector centered per grid-square
// edge segment. Tab gender: male on +X and +Y edges, female on -X and
// -Y, so identically-oriented tiles tessellate in both directions.
module floor_tile(w = 1, l = 1, interior_grooves = true) {
    t = floor_t();
    // Male tabs stop below the groove floor so a mated neighbor's tab
    // never pokes up into the wall-foot channel.
    tab_t = FLOOR_GROOVES ? t - FOOT_GROOVE_D : t;
    difference() {
        union() {
            cube([grid(w), grid(l), t]);
            if (CONNECTOR == "tab") {
                for (j = [0 : l - 1])
                    translate([grid(w), grid(j + 0.5), 0]) tab_male(tab_t);
                for (i = [0 : w - 1])
                    translate([grid(i + 0.5), grid(l), 0])
                        rotate([0, 0, 90]) tab_male(tab_t);
            }
        }
        if (FLOOR_GROOVES) floor_grooves(w, l, t, interior_grooves);
        if (CONNECTOR == "tab") {
            for (j = [0 : l - 1])
                translate([0, grid(j + 0.5), 0]) tab_female(t);
            for (i = [0 : w - 1])
                translate([grid(i + 0.5), 0, 0])
                    rotate([0, 0, 90]) tab_female(t);
        }
        if (CONNECTOR == "magnet" || CONNECTOR == "dowel") {
            for (j = [0 : l - 1]) {
                translate([0, grid(j + 0.5), 0]) edge_fastener(t / 2);
                translate([grid(w), grid(j + 0.5), 0])
                    mirror([1, 0, 0]) edge_fastener(t / 2);
            }
            for (i = [0 : w - 1]) {
                translate([grid(i + 0.5), 0, 0])
                    rotate([0, 0, 90]) edge_fastener(t / 2);
                translate([grid(i + 0.5), grid(l), 0])
                    mirror([0, 1, 0]) rotate([0, 0, 90])
                        edge_fastener(t / 2);
            }
        }
    }
}

// Half-channel rebates along the tile's top edges plus full channels
// along interior grid lines, so a wall foot can seat on any grid line.
module floor_grooves(w, l, t, interior = true) {
    gw = (FOOT_W + fit_clearance()) / 2;   // half-channel per tile edge
    gd = FOOT_GROOVE_D;
    translate([-EPS, -EPS, t - gd])
        cube([grid(w) + 2 * EPS, gw + EPS, gd + EPS]);
    translate([-EPS, grid(l) - gw, t - gd])
        cube([grid(w) + 2 * EPS, gw + EPS, gd + EPS]);
    translate([-EPS, -EPS, t - gd])
        cube([gw + EPS, grid(l) + 2 * EPS, gd + EPS]);
    translate([grid(w) - gw, -EPS, t - gd])
        cube([gw + EPS, grid(l) + 2 * EPS, gd + EPS]);
    if (interior) {
        for (i = [1 : 1 : w - 1])
            translate([grid(i) - gw, -EPS, t - gd])
                cube([2 * gw, grid(l) + 2 * EPS, gd + EPS]);
        for (j = [1 : 1 : l - 1])
            translate([-EPS, grid(j) - gw, t - gd])
                cube([grid(w) + 2 * EPS, 2 * gw, gd + EPS]);
    }
}

// Magnet pocket or dowel hole, per the active CONNECTOR.
module edge_fastener(z) {
    if (CONNECTOR == "magnet") magnet_pocket(z);
    if (CONNECTOR == "dowel")  dowel_hole(z);
}

// ---------------------------------------------------------------------
// Straight wall: `units` grid squares long, centered on the grid line
// (y = 0). Tab gender: male at +X end, female at -X end; the tab runs
// the full height as a vertical sliding dovetail. Magnet/dowel: two
// fasteners per end face (one, on short walls).
module wall_straight(units = 1, opening = OPENING, decor = DECOR) {
    h  = wall_h();
    wt = wall_t();
    len = grid(units);
    assert(opening == "none" ||
           opening_width(opening) + 2 * (WALL_TAB_DEPTH + 2) <= len,
           str("opening too wide for a ", units, "-unit wall"));
    assert(opening == "none" || opening_top(opening) <= h - scaled(4),
           "opening too tall for this wall height");
    assert(opening == "none" || decor == "none",
           "one feature per wall: opening or decor, not both");
    union() {
        decor_add(len / 2, decor);
        difference() {
            union() {
                translate([0, -wt / 2, 0]) cube([len, wt, h]);
                if (CONNECTOR == "tab")
                    translate([len, 0, 0])
                        tab_male(h, WALL_TAB_NECK, WALL_TAB_HEAD,
                                 WALL_TAB_DEPTH);
                if (WALL_FOOT) foot_rail(len);
            }
            if (CONNECTOR == "tab")
                tab_female(h, fit_clearance(), WALL_TAB_NECK,
                           WALL_TAB_HEAD, WALL_TAB_DEPTH);
            for (z = wall_fastener_heights()) {
                edge_fastener(z);
                translate([len, 0, 0]) mirror([1, 0, 0])
                    edge_fastener(z);
            }
            opening_void(len / 2, opening);
            decor_cut(len / 2, decor);
        }
        opening_bars(len / 2, opening);
    }
}

function wall_fastener_heights() =
    (CONNECTOR == "magnet" || CONNECTOR == "dowel")
        ? (wall_h() > grid(1)
            ? [grid(0.5), wall_h() - grid(0.5)]
            : [wall_h() / 2])
        : [];

// Tenon rail under the wall base; seats into the floor groove channel.
module foot_rail(len) {
    translate([0, -FOOT_W / 2, -FOOT_H])
        cube([len, FOOT_W, FOOT_H + EPS]);
}

// ---------------------------------------------------------------------
// 90-degree corner: one arm along +X, one along +Y, each one grid
// square long, meeting at the grid-line crossing (origin). Tab gender:
// male at the +X arm end, female at the +Y arm end (opening outward),
// so a chain enters one arm and exits the other. Tab chains are
// chiral: set mirrored = true for the opposite-handed corner.
module wall_corner(mirrored = false) {
    h  = wall_h();
    wt = wall_t();
    mirror([mirrored ? 1 : 0, 0, 0])
        difference() {
            union() {
                translate([-wt / 2, -wt / 2, 0])
                    cube([grid(1) + wt / 2, wt, h]);
                translate([-wt / 2, -wt / 2, 0])
                    cube([wt, grid(1) + wt / 2, h]);
                if (WALL_FOOT) {
                    translate([-FOOT_W / 2, 0, 0])
                        foot_rail(grid(1) + FOOT_W / 2);
                    translate([0, -FOOT_W / 2, 0]) rotate([0, 0, 90])
                        foot_rail(grid(1) + FOOT_W / 2);
                }
                if (CONNECTOR == "tab")
                    translate([grid(1), 0, 0])
                        tab_male(h, WALL_TAB_NECK, WALL_TAB_HEAD,
                                 WALL_TAB_DEPTH);
            }
            if (CONNECTOR == "tab")
                translate([0, grid(1), 0]) rotate([0, 0, -90])
                    tab_female(h, fit_clearance(), WALL_TAB_NECK,
                               WALL_TAB_HEAD, WALL_TAB_DEPTH);
            for (z = wall_fastener_heights()) {
                translate([grid(1), 0, 0]) mirror([1, 0, 0])
                    edge_fastener(z);
                translate([0, grid(1), 0]) mirror([0, 1, 0])
                    rotate([0, 0, 90]) edge_fastener(z);
            }
        }
}

// ---------------------------------------------------------------------
// Openings. Profiles are drawn in 2D (x = along wall, y = height) and
// extruded through the wall thickness.

function opening_width(opening = OPENING) =
    (opening == "door_arch" || opening == "door_rect" ||
     opening == "door_portcullis") ? scaled(DOOR_W) :
    opening == "window_slit" ? scaled(SLIT_W * SLIT_SPLAY) :
    opening == "none" ? 0 : scaled(WIN_W);

function opening_top(opening = OPENING) =
    (opening == "door_arch" || opening == "door_rect" ||
     opening == "door_portcullis") ? scaled(DOOR_H) :
    opening == "window_slit" ? scaled(SLIT_SILL + SLIT_H) + 2 :
    opening == "none" ? 0 : scaled(WIN_SILL + WIN_H);

// Extrude a 2D child profile through the wall thickness at length
// position cx.
module thru_wall(cx) {
    translate([cx, wall_t() / 2 + EPS, 0])
        rotate([90, 0, 0])
            linear_extrude(height = wall_t() + 2 * EPS)
                children();
}

module profile_rect(w, h, sill = 0) {
    translate([-w / 2, sill]) square([w, h]);
}

// Rectangle capped with an elliptical arch; total height h incl. rise.
module profile_arch(w, h, rise, sill = 0) {
    translate([-w / 2, sill]) square([w, max(h - rise, EPS)]);
    translate([0, sill + h - rise])
        scale([1, rise / (w / 2)])
            intersection() {
                circle(d = w);
                translate([-w / 2, 0]) square([w, w / 2]);
            }
}

module opening_void(cx, opening = OPENING) {
    if (opening == "door_rect" || opening == "door_portcullis")
        thru_wall(cx) profile_rect(scaled(DOOR_W), scaled(DOOR_H), -EPS);
    if (opening == "door_arch")
        thru_wall(cx) profile_arch(scaled(DOOR_W), scaled(DOOR_H),
                                   scaled(ARCH_RISE), -EPS);
    if (opening == "window_barred")
        thru_wall(cx) profile_rect(scaled(WIN_W), scaled(WIN_H),
                                   scaled(WIN_SILL));
    if (opening == "window_arch")
        thru_wall(cx) profile_arch(scaled(WIN_W), scaled(WIN_H),
                                   scaled(WIN_ARCH_RISE),
                                   scaled(WIN_SILL));
    if (opening == "window_slit") slit_void(cx);
}

// Arrow slit: narrow on the +Y (exterior) face, splayed embrasure
// opening toward -Y (interior).
module slit_void(cx) {
    wt = wall_t();
    hull() {
        translate([cx - scaled(SLIT_W) / 2, wt / 2 - 0.6,
                   scaled(SLIT_SILL)])
            cube([scaled(SLIT_W), 0.6 + EPS, scaled(SLIT_H)]);
        translate([cx - scaled(SLIT_W * SLIT_SPLAY) / 2, -wt / 2 - EPS,
                   scaled(SLIT_SILL) - 2])
            cube([scaled(SLIT_W * SLIT_SPLAY), 0.6,
                  scaled(SLIT_H) + 4]);
    }
}

// Bar x-offsets, symmetric about the opening center.
function bar_offsets(w) =
    let (n = floor((w - scaled(BAR_SIZE)) / scaled(BAR_PITCH)))
    [for (i = [0 : 1 : n - 1]) (i - (n - 1) / 2) * scaled(BAR_PITCH)];

// Bars left standing in portcullis doors and barred windows. Unioned
// after the void is cut; they anchor by overlapping the wall above
// (and below, for windows) the opening.
module opening_bars(cx, opening = OPENING) {
    bs = scaled(BAR_SIZE);
    if (opening == "door_portcullis")
        for (x = bar_offsets(scaled(DOOR_W)))
            translate([cx + x - bs / 2, -bs / 2, 0])
                cube([bs, bs, scaled(DOOR_H) + 2]);
    if (opening == "window_barred")
        for (x = bar_offsets(scaled(WIN_W)))
            translate([cx + x, 0, scaled(WIN_SILL) - 2])
                cylinder(h = scaled(WIN_H) + 4, d = bs);
}

// ---------------------------------------------------------------------
// Decorative wall features. One feature per wall; walls print lying
// flat so pegs are printable.

module decor_cut(cx, decor = DECOR) {
    wt = wall_t();
    z  = DECOR_H_FRAC * wall_h();
    // Torch socket: bore into the -Y face, tilted 25 degrees up, so a
    // torch stem leans out over the room.
    if (decor == "sconce")
        translate([cx, -wt / 2 - EPS, z])
            rotate([-65, 0, 0])
                cylinder(h = wt + 4, d = SCONCE_D + fit_clearance());
    // Gargoyle glue pocket on the +Y (exterior) face near the top.
    if (decor == "gargoyle_socket")
        translate([cx - 3, wt / 2 - 4, wall_h() - 10])
            cube([6, 4 + EPS, 6]);
}

module decor_add(cx, decor = DECOR) {
    wt = wall_t();
    z  = DECOR_H_FRAC * wall_h();
    // Banner peg out of the -Y face with a retaining tip.
    if (decor == "banner_peg") {
        translate([cx, -wt / 2 + EPS, z])
            rotate([90, 0, 0]) cylinder(h = 5 + EPS, d = PEG_D);
        translate([cx, -wt / 2 - 5, z]) sphere(d = PEG_D + 1.5);
    }
}

// ---------------------------------------------------------------------
// Mosaic centerpiece tiles: a floor tile with a pattern etched into
// the top face. Stroke widths are absolute so fine lines stay
// printable at any kit scale. Centerpiece tiles keep their perimeter
// grooves but skip interior wall channels — the pattern is meant to
// be open floor.
module mosaic_tile(w = 2, l = 2, mosaic = MOSAIC, etch = ETCH_DEPTH) {
    difference() {
        floor_tile(w, l, interior_grooves = false);
        if (scaled(etch) > 0 && mosaic != "none")
            translate([grid(w) / 2, grid(l) / 2,
                       floor_t() - scaled(etch)])
                linear_extrude(height = scaled(etch) + EPS)
                    mosaic_pattern(min(grid(w), grid(l)) / 2 - 5,
                                   mosaic);
    }
}

module mosaic_pattern(R, mosaic = MOSAIC) {
    if (mosaic == "compass")  compass_rose_2d(R);
    if (mosaic == "shield")   shield_2d(R);
    if (mosaic == "knotwork") knot_2d(R);
    if (mosaic == "blank")    ring_2d(R);
}

module ring_2d(R, w = 1.2) {
    difference() { circle(R); circle(R - w); }
}

// Four cardinal points, four shorter intercardinals, double ring.
module compass_rose_2d(R) {
    ring_2d(R);
    ring_2d(R - 2.2, 0.8);
    Rp = R - 4;
    for (a = [0 : 90 : 270]) rotate(a)
        polygon([[0, Rp], [Rp * 0.18, 0], [0, -Rp * 0.18],
                 [-Rp * 0.18, 0]]);
    for (a = [45 : 90 : 315]) rotate(a)
        polygon([[0, Rp * 0.62], [Rp * 0.12, 0], [0, -Rp * 0.12],
                 [-Rp * 0.12, 0]]);
}

// Heater shield: outline groove plus a chevron band.
module shield_solid(w, h) {
    polygon([[-w / 2, h / 2], [w / 2, h / 2], [w / 2, h * 0.05],
             [0, -h / 2], [-w / 2, h * 0.05]]);
}

module shield_2d(R) {
    w = 1.4 * R;
    h = 1.8 * R;
    difference() {
        shield_solid(w, h);
        offset(delta = -1.4) shield_solid(w, h);
    }
    intersection() {
        offset(delta = -2.6) shield_solid(w, h);
        chevron_band(w / 2 - 1, h * 0.05, w * 0.35, 2.6);
    }
}

// Upward-pointing chevron band: outer V from (+/-wv, y1) down to
// (0, y1 - drop), band thickness bt.
module chevron_band(wv, y1, drop, bt) {
    polygon([[-wv, y1], [0, y1 - drop], [wv, y1],
             [wv, y1 + bt], [0, y1 - drop + bt], [-wv, y1 + bt]]);
}

// Interlocking diamond lattice inside a border ring.
module knot_2d(R) {
    ring_2d(R);
    intersection() {
        circle(R - 2.2);
        for (k = [-4 : 4]) {
            rotate(45)  translate([k * 6, 0])
                square([1.4, 4 * R], center = true);
            rotate(-45) translate([k * 6, 0])
                square([1.4, 4 * R], center = true);
        }
    }
}
