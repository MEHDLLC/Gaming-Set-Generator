// kit_preview.scad — assembled sample room for kit listing thumbnails.
// Driven per kit via -D: CONNECTOR/FIT plus the kit's matched styles
// (DOOR_STYLE, WINDOW_STYLE, MOSAIC_STYLE, DECOR_STYLE).
include <../src/lib/grid.scad>
include <../src/lib/connectors.scad>
include <../src/lib/pieces.scad>

DOOR_STYLE   = "door_arch";
WINDOW_STYLE = "window_arch";
MOSAIC_STYLE = "compass";
DECOR_STYLE  = "sconce";

ft = floor_t();

// 4x4 floor field with the 2x2 mosaic centerpiece offset to one side.
color("BurlyWood") {
    translate([grid(1), grid(1), 0]) mosaic_tile(2, 2, MOSAIC_STYLE);
    for (i = [0 : 3], j = [0 : 3])
        if (!(i >= 1 && i <= 2 && j >= 1 && j <= 2))
            translate([grid(i), grid(j), 0]) floor_tile(1, 1);
}

// Walls along the south and west edges: corner, doorway, plain,
// window, and decor walls — one of each matched style.
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
