// pieces.scad — the core piece library (Phase 1).
// Requires grid.scad and connectors.scad to be included first.
//
// Grid convention: floors fill grid cells; walls run along grid lines,
// centered on them. Chains of gendered (tab) pieces alternate
// male-into-female; magnet/dowel/none pieces are genderless.

// Wall-end dovetail, sized to fit inside the wall thickness (absolute).
WALL_TAB_NECK  = 3;
WALL_TAB_HEAD  = 4.8;
WALL_TAB_DEPTH = 4;

// -- Phase 2: openings ------------------------------------------------
// OPENING: "none" | "door_arch" | "door_rect" | "door_portcullis" |
//          "window_slit" | "window_arch" | "window_barred"
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

// Arrow slit (scaled). The slit splays open toward the -Y (interior)
// face by SLIT_SPLAY x width and +/-2mm vertically (embrasure).
SLIT_W     = 3;
SLIT_H     = 24;
SLIT_SILL  = 14;
SLIT_SPLAY = 3.5;

// Bars for portcullis doors / barred windows (scaled).
BAR_PITCH = 5.5;
BAR_SIZE  = 2;

// -- Phase 2: wall-to-floor registration -------------------------------
// Walls carry a tenon rail under their base that drops into a groove
// cut along the floor tiles' top edges (and along interior grid lines
// of multi-cell tiles). Two adjacent tiles each contribute half the
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
module floor_tile(w = 1, l = 1) {
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
        if (FLOOR_GROOVES) floor_grooves(w, l, t);
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
module floor_grooves(w, l, t) {
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
    for (i = [1 : 1 : w - 1])
        translate([grid(i) - gw, -EPS, t - gd])
            cube([2 * gw, grid(l) + 2 * EPS, gd + EPS]);
    for (j = [1 : 1 : l - 1])
        translate([-EPS, grid(j) - gw, t - gd])
            cube([grid(w) + 2 * EPS, 2 * gw, gd + EPS]);
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
// fasteners per end face.
module wall_straight(units = 1) {
    h  = wall_h();
    wt = wall_t();
    len = grid(units);
    assert(OPENING == "none" ||
           opening_width() + 2 * (WALL_TAB_DEPTH + 2) <= len,
           str("opening too wide for a ", units, "-unit wall"));
    assert(OPENING == "none" || opening_top() <= h - scaled(4),
           "opening too tall for this wall height");
    union() {
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
            opening_void(len / 2);
        }
        opening_bars(len / 2);
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
// Openings (Phase 2). Profiles are drawn in 2D (x = along wall,
// y = height) and extruded through the wall thickness.

function opening_width() =
    (OPENING == "door_arch" || OPENING == "door_rect" ||
     OPENING == "door_portcullis") ? scaled(DOOR_W) :
    OPENING == "window_slit" ? scaled(SLIT_W * SLIT_SPLAY) :
    OPENING == "none" ? 0 : scaled(WIN_W);

function opening_top() =
    (OPENING == "door_arch" || OPENING == "door_rect" ||
     OPENING == "door_portcullis") ? scaled(DOOR_H) :
    OPENING == "window_slit" ? scaled(SLIT_SILL + SLIT_H) + 2 :
    OPENING == "none" ? 0 : scaled(WIN_SILL + WIN_H);

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

module opening_void(cx) {
    if (OPENING == "door_rect" || OPENING == "door_portcullis")
        thru_wall(cx) profile_rect(scaled(DOOR_W), scaled(DOOR_H), -EPS);
    if (OPENING == "door_arch")
        thru_wall(cx) profile_arch(scaled(DOOR_W), scaled(DOOR_H),
                                   scaled(ARCH_RISE), -EPS);
    if (OPENING == "window_barred")
        thru_wall(cx) profile_rect(scaled(WIN_W), scaled(WIN_H),
                                   scaled(WIN_SILL));
    if (OPENING == "window_arch")
        thru_wall(cx) profile_arch(scaled(WIN_W), scaled(WIN_H),
                                   scaled(WIN_ARCH_RISE),
                                   scaled(WIN_SILL));
    if (OPENING == "window_slit") slit_void(cx);
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

// Bars left standing in portcullis doors and barred windows. Unioned
// after the void is cut; they anchor by overlapping the wall above
// (and below, for windows) the opening.
// Bar x-offsets, symmetric about the opening center.
function bar_offsets(w) =
    let (n = floor((w - scaled(BAR_SIZE)) / scaled(BAR_PITCH)))
    [for (i = [0 : 1 : n - 1]) (i - (n - 1) / 2) * scaled(BAR_PITCH)];

module opening_bars(cx) {
    bs = scaled(BAR_SIZE);
    if (OPENING == "door_portcullis")
        for (x = bar_offsets(scaled(DOOR_W)))
            translate([cx + x - bs / 2, -bs / 2, 0])
                cube([bs, bs, scaled(DOOR_H) + 2]);
    if (OPENING == "window_barred")
        for (x = bar_offsets(scaled(WIN_W)))
            translate([cx + x, 0, scaled(WIN_SILL) - 2])
                cylinder(h = scaled(WIN_H) + 4, d = bs);
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
