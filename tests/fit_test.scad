// fit_test.scad — programmatic snap-fit verification.
// Renders the boolean INTERSECTION of two pieces placed in their mated
// position. A correct fit yields empty geometry (OpenSCAD exits with
// "Current top level object is empty"); any triangles mean the pieces
// physically overlap and the connector geometry is wrong.
include <../src/lib/grid.scad>
include <../src/lib/connectors.scad>
include <../src/lib/pieces.scad>
include <../src/lib/gatehouse.scad>
include <../src/lib/headphone.scad>
include <../src/lib/sculpture.scad>

TEST = "floor_x";

// A typo'd TEST would intersect two empty modules and false-pass.
valid = ["floor_x", "floor_y", "wall_wall", "corner_male",
         "corner_female", "wall_on_floor", "wall_on_floor_interior",
         "stairs_on_floor", "column_on_floor", "deck_on_wall",
         "column_to_deck", "curved_pair", "curved_on_tower_floor",
         "tower_deck_on_curved", "hatch_lid_fit", "ruined_pair",
         "beam_in_brackets", "door_prop_in_doorway",
         "gate_wall_chain", "hp_clamp_mount", "hp_screw_thread",
         "hp_band_channel", "lid_in_box"];
assert(len([for (v = valid) if (v == TEST) v]) == 1,
       str("unknown TEST: ", TEST));

module piece_a() {
    if (TEST == "floor_x" || TEST == "floor_y") floor_tile(1, 1);
    else if (TEST == "wall_wall") wall_straight(1);
    else if (TEST == "corner_male" || TEST == "corner_female")
        wall_corner(false);
    // Wall standing on the grid line shared by two tiles / crossing a
    // 2x2 tile's interior line: foot tenon must clear the groove.
    else if (TEST == "wall_on_floor" || TEST == "wall_on_floor_interior")
        translate([0, grid(1), floor_t()]) wall_straight(1);
    // Stairs' low edge butts the floor tile's +Y male edge.
    else if (TEST == "stairs_on_floor")
        translate([0, grid(1), 0]) stairs_straight(1, 2);
    // Column tenons at a four-tile channel crossing (below) and a
    // four-deck corner (above).
    else if (TEST == "column_on_floor")
        translate([grid(1), grid(1), floor_t()]) column();
    else if (TEST == "column_to_deck")
        translate([grid(1), grid(1), 0]) column();
    // Wall standing under the shared edge of two deck tiles.
    else if (TEST == "deck_on_wall")
        translate([0, grid(1), 0]) wall_straight(1);
    else if (TEST == "curved_pair") curved_wall(90);
    else if (TEST == "curved_on_tower_floor")
        translate([0, 0, floor_t()]) curved_wall(90);
    else if (TEST == "tower_deck_on_curved") curved_wall(90);
    // Lid seated in a tower deck's hatch: plug in the hole, lip on top.
    else if (TEST == "hatch_lid_fit")
        translate([0, 0, floor_t() + FOOT_GROOVE_D - scaled(2)])
            hatch_lid();
    else if (TEST == "ruined_pair") wall_straight(1, ruin = 0.6);
    // Beam laid into the gate wall brackets (assembled position).
    else if (TEST == "beam_in_brackets")
        translate([grid(1) - (scaled(GATE_W) + 2 * scaled(4)
                              + scaled(10)) / 2,
                   -wall_t() / 2 - scaled(2) - scaled(GATE_BEAM_SQ) / 2,
                   scaled(GATE_BEAM_Z)])
            gate_beam();
    // Door prop standing inside the arched doorway.
    else if (TEST == "door_prop_in_doorway")
        translate([grid(1) - (scaled(DOOR_W) - 0.6) / 2, 1.3, 0])
            rotate([90, 0, 0]) door_prop("arch");
    else if (TEST == "gate_wall_chain") gate_wall(2);
    // Stand base seated on the clamp plate, dovetail engaged.
    else if (TEST == "hp_clamp_mount")
        translate([0, 8, CLAMP_PLATE]) hp_base();
    // Thumbscrew threaded into the clamp boss (helix phases aligned:
    // both thread bases sit at the same absolute z).
    else if (TEST == "hp_screw_thread")
        translate([(hp_w() - CLAMP_W) / 2 + CLAMP_W / 2, 22,
                   clamp_thread_z() - 8])
            clamp_screw();
    // Headband-sized prism dropped into the channel above the crest.
    else if (TEST == "hp_band_channel")
        translate([-30, HP_SLAB + 1, hp_crest() + 0.5])
            cube([hp_w() + 60, HP_CORE_D - 2,
                  hp_h() - hp_crest() - 2.5]);
    // Sculpture lid dropped into the box rabbet.
    else if (TEST == "lid_in_box")
        translate([0, 0, BOX_H - LID_T]) sculpture_lid();
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
    else if (TEST == "wall_on_floor") {
        floor_tile(1, 1);
        translate([0, grid(1), 0]) floor_tile(1, 1);
    }
    else if (TEST == "wall_on_floor_interior")
        floor_tile(2, 2);
    else if (TEST == "stairs_on_floor")
        floor_tile(1, 1);
    else if (TEST == "column_on_floor")
        for (i = [0 : 1], j = [0 : 1])
            translate([grid(i), grid(j), 0]) floor_tile(1, 1);
    else if (TEST == "column_to_deck")
        for (i = [0 : 1], j = [0 : 1])
            translate([grid(i), grid(j), wall_h()]) deck_tile(1, 1);
    else if (TEST == "deck_on_wall") {
        translate([0, 0, wall_h()]) deck_tile(1, 1);
        translate([0, grid(1), wall_h()]) deck_tile(1, 1);
    }
    else if (TEST == "curved_pair") rotate([0, 0, 90]) curved_wall(90);
    else if (TEST == "curved_on_tower_floor") tower_floor(false, false);
    else if (TEST == "tower_deck_on_curved")
        translate([0, 0, wall_h()]) tower_floor(true, false);
    else if (TEST == "hatch_lid_fit") tower_floor(true, true);
    else if (TEST == "ruined_pair")
        translate([grid(1), 0, 0]) wall_straight(1, ruin = 0.6);
    else if (TEST == "beam_in_brackets" || TEST == "gate_wall_chain") {
        if (TEST == "beam_in_brackets") gate_wall(2);
        else translate([grid(2), 0, 0]) wall_straight(1);
    }
    else if (TEST == "door_prop_in_doorway")
        wall_straight(2, "door_arch");
    else if (TEST == "hp_clamp_mount")
        translate([(hp_w() - CLAMP_W) / 2, 0, 0]) desk_clamp();
    else if (TEST == "hp_screw_thread")
        translate([(hp_w() - CLAMP_W) / 2, 0, 0]) desk_clamp();
    else if (TEST == "hp_band_channel") hp_tree(42);
    else if (TEST == "lid_in_box") storage_box();
}

intersection() {
    piece_a();
    piece_b();
}
