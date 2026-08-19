// fit_test.scad — programmatic snap-fit verification.
// Renders the boolean INTERSECTION of two pieces placed in their mated
// position. A correct fit yields empty geometry (OpenSCAD exits with
// "Current top level object is empty"); any triangles mean the pieces
// physically overlap and the connector geometry is wrong.
include <../src/lib/grid.scad>
include <../src/lib/connectors.scad>
include <../src/lib/pieces.scad>

TEST = "floor_x";

// A typo'd TEST would intersect two empty modules and false-pass.
valid = ["floor_x", "floor_y", "wall_wall", "corner_male",
         "corner_female"];
assert(len([for (v = valid) if (v == TEST) v]) == 1,
       str("unknown TEST: ", TEST));

module piece_a() {
    if (TEST == "floor_x" || TEST == "floor_y") floor_tile(1, 1);
    else if (TEST == "wall_wall") wall_straight(1);
    else if (TEST == "corner_male" || TEST == "corner_female")
        wall_corner(false);
}

module piece_b() {
    if (TEST == "floor_x")
        translate([grid(1), 0, 0]) floor_tile(1, 1);
    else if (TEST == "floor_y")
        translate([0, grid(1), 0]) floor_tile(1, 1);
    else if (TEST == "wall_wall")
        translate([grid(1), 0, 0]) wall_straight(1);
    // Wall continuing the chain off the corner's male (+X) arm.
    else if (TEST == "corner_male")
        translate([grid(1), 0, 0]) wall_straight(1);
    // Wall descending into the corner's female (+Y) arm end.
    else if (TEST == "corner_female")
        translate([0, grid(2), 0]) rotate([0, 0, -90]) wall_straight(1);
}

intersection() {
    piece_a();
    piece_b();
}
