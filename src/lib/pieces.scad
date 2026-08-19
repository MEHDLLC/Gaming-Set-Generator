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
    difference() {
        union() {
            cube([grid(w), grid(l), t]);
            if (CONNECTOR == "tab") {
                for (j = [0 : l - 1])
                    translate([grid(w), grid(j + 0.5), 0]) tab_male(t);
                for (i = [0 : w - 1])
                    translate([grid(i + 0.5), grid(l), 0])
                        rotate([0, 0, 90]) tab_male(t);
            }
        }
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
    difference() {
        union() {
            translate([0, -wt / 2, 0]) cube([grid(units), wt, h]);
            if (CONNECTOR == "tab")
                translate([grid(units), 0, 0])
                    tab_male(h, WALL_TAB_NECK, WALL_TAB_HEAD,
                             WALL_TAB_DEPTH);
        }
        if (CONNECTOR == "tab")
            tab_female(h, fit_clearance(), WALL_TAB_NECK, WALL_TAB_HEAD,
                       WALL_TAB_DEPTH);
        for (z = wall_fastener_heights()) {
            edge_fastener(z);
            translate([grid(units), 0, 0]) mirror([1, 0, 0])
                edge_fastener(z);
        }
    }
}

function wall_fastener_heights() =
    (CONNECTOR == "magnet" || CONNECTOR == "dowel")
        ? [grid(0.5), wall_h() - grid(0.5)] : [];

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
