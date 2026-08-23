// kit_preview.scad — assembled sample scene for kit thumbnails.
// Driven per kit via -D: CONNECTOR/FIT/TEXTURE plus the kit's matched
// styles. Shows both storeys: walls and mosaic below, a deck resting
// on the wall tops and a column, with stairs rising to deck level.
include <../src/lib/grid.scad>
include <../src/lib/connectors.scad>
include <../src/lib/pieces.scad>
include <../src/lib/furniture.scad>
include <../src/lib/gatehouse.scad>
include <../src/lib/headphone.scad>
include <../src/lib/sculpture.scad>

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

// Furnished hall: furniture lineup on a textured floor field, fronts
// toward the camera side (-Y).
module furniture_scene() {
    color("BurlyWood") for (i = [0 : 4], j = [0 : 1])
        translate([grid(i), grid(j), 0]) floor_tile(1, 1);
    ft2 = floor_t();
    translate([0, 0, ft2]) {
        color("Tan") {
            translate([4, 12, 0]) f_bed();
            translate([24, 36, 0]) rotate([0, 0, 180])
                translate([-scaled(22), 0, 0]) f_wardrobe();
            translate([50, 28, 0]) f_bookshelf();
            translate([74, 26, 0]) f_throne();
            translate([90, 8, 0]) f_table();
            translate([92, 26, 0]) f_bench();
            translate([118, 12, 0]) f_stool();
            translate([108, 30, 0]) f_chest();
            translate([112, 38, 0]) rotate([0, 0, -75]) f_ladder(40);
        }
    }
}

// Gatehouse: gate wall flanked by plain walls, doors in the arch,
// beam in the brackets, drawbridge lowered in front.
module gatehouse_scene() {
    ftg = floor_t();
    color("BurlyWood") for (i = [-1 : 2], j = [0 : 1])
        translate([grid(i), grid(j), 0]) floor_tile(1, 1);
    color("LightSlateGray") translate([0, grid(1), ftg]) {
        gate_wall(2);
        translate([-grid(1), 0, 0]) wall_straight(1);
        translate([grid(2), 0, 0]) wall_straight(1);
    }
    color("Tan") {
        // doors standing in the arch, slightly ajar look: both closed
        translate([grid(1) - (scaled(GATE_W) - 0.6) / 2,
                   grid(1) + 1.3, ftg])
            rotate([90, 0, 0]) gate_doors_closed();
        // beam resting in the brackets
        translate([grid(1) - (scaled(GATE_W) + 2 * scaled(4)
                              + scaled(10)) / 2,
                   grid(1) - wall_t() / 2 - scaled(2.3)
                   - scaled(GATE_BEAM_SQ) / 2,
                   ftg + scaled(GATE_BEAM_Z)])
            gate_beam();
        // drawbridge lowered outside the gate
        translate([grid(1) - (grid(2) - scaled(6)) / 2,
                   grid(1) + wall_t() / 2 + 1, ftg])
            drawbridge();
    }
}

// Both gate leaves in closed position (no print gap).
module gate_doors_closed() {
    w = scaled(GATE_W) - 0.6;
    h = scaled(GATE_H) - 0.4;
    translate([w / 2, 0, 0]) door_panel(w, h)
        profile_arch(w, h, scaled(GATE_RISE));
}

// Voxel stands on a desk: the tree mounted on the edge clamp, the
// sheep and chicken standing free beside it.
module headphones_scene() {
    color("Tan") translate([-60, 0, -22])
        cube([420, 190, 22]);
    color("DimGray") translate([(hp_w() - CLAMP_W) / 2, 0, 0])
        desk_clamp();
    color("DimGray")
        translate([(hp_w() - CLAMP_W) / 2 + CLAMP_W / 2, 22,
                   clamp_thread_z() - 8]) clamp_screw();
    color("OliveDrab") translate([0, 8, CLAMP_PLATE]) hp_tree(42);
    color("Gainsboro") translate([125, 8, 0]) hp_sheep();
    color("Khaki") translate([250, 8, 0]) hp_chicken();
}

// Assembled stand, and beside it the box open with its lid lifted
// off, showing that the whole sculpture is the handle.
module sculpture_scene() {
    color("Gainsboro") storage_box();
    color("DarkSlateGray") translate([0, 0, BOX_H - LID_T])
        sculpture_lid();
    translate([150, 0, 0]) {
        color("Gainsboro") storage_box();
        color("DarkSlateGray") translate([0, 0, BOX_H + 34])
            sculpture_lid();
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

if (SCENE == "sculpture") sculpture_scene();
else if (SCENE == "headphones") headphones_scene();
else if (SCENE == "tower") tower_scene();
else if (SCENE == "gatehouse") gatehouse_scene();
else if (SCENE == "furniture") furniture_scene();
else room_scene();
