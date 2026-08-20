// kit_preview.scad — assembled sample scene for kit thumbnails.
// Driven per kit via -D: CONNECTOR/FIT/TEXTURE plus the kit's matched
// styles. Shows both storeys: walls and mosaic below, a deck resting
// on the wall tops and a column, with stairs rising to deck level.
include <../src/lib/grid.scad>
include <../src/lib/connectors.scad>
include <../src/lib/pieces.scad>

DOOR_STYLE   = "door_arch";
WINDOW_STYLE = "window_arch";
MOSAIC_STYLE = "compass";
DECOR_STYLE  = "sconce";
SCENE        = "room";   // "room" | "tower"

ft = floor_t();

// Two-storey turret: floor, doored ring, hatch deck, battlement ring.
module tower_scene() {
    color("BurlyWood") tower_floor(false, false);
    color("LightSlateGray") translate([0, 0, ft]) {
        curved_wall(90, "none", false);
        rotate([0, 0, 90]) curved_wall(90, WINDOW_STYLE, false);
        rotate([0, 0, 180]) curved_wall(90, "none", false);
        rotate([0, 0, 270]) curved_wall(90, DOOR_STYLE, false);
    }
    color("RosyBrown") translate([0, 0, ft + wall_h()])
        tower_floor(true, true);
    color("SlateGray")
        translate([0, 0, ft + wall_h() + floor_t() + FOOT_GROOVE_D]) {
            curved_wall(90, "none", true);
            rotate([0, 0, 90]) curved_wall(90, "none", true);
            rotate([0, 0, 180]) curved_wall(90, WINDOW_STYLE, true);
            rotate([0, 0, 270]) curved_wall(90, "none", true);
        }
}

module room_scene() {

color("BurlyWood") {
    // Mosaic in the open SE quarter; the column then stands at the
    // (2,2) grid crossing where four full channels meet.
    translate([grid(2), 0, 0]) mosaic_tile(2, 2, MOSAIC_STYLE);
    for (i = [0 : 3], j = [0 : 3])
        if (!(i >= 2 && j <= 1)                  // mosaic footprint
            && !(i == 1 && j >= 2))              // staircase footprint
            translate([grid(i), grid(j), 0]) floor_tile(1, 1);
}

// Staircase replaces two floor cells, climbing to deck level.
color("Tan") translate([grid(1), grid(2), 0]) stairs_straight(1, 2);

color("LightSlateGray") translate([0, 0, ft]) {
    wall_corner(false);
    translate([grid(1), 0, 0]) wall_straight(2, DOOR_STYLE);
    translate([grid(3), 0, 0]) wall_straight(1);
    translate([0, grid(1), 0]) rotate([0, 0, 90]) mirror([1, 0, 0])
        wall_straight(1, WINDOW_STYLE);
    translate([0, grid(2), 0]) rotate([0, 0, 90]) mirror([1, 0, 0])
        wall_straight(1);
    translate([0, grid(3), 0]) rotate([0, 0, 90]) mirror([1, 0, 0])
        wall_straight(1, "none", DECOR_STYLE);
}

// Second storey: deck over the SW corner walls, its free corner on a
// column seated at the (2,2) channel crossing.
color("Peru") translate([grid(2), grid(2), ft]) column();
color("RosyBrown") translate([0, 0, ft + wall_h()]) deck_tile(2, 2);
}

if (SCENE == "tower") tower_scene();
else room_scene();
