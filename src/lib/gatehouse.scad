// gatehouse.scad — gate doors, securing beam, drawbridge, and door
// props sized to the wall openings. Requires grid.scad,
// connectors.scad, and pieces.scad (for DOOR_*/GATE_* dimensions).
// All pieces print flat, support-free.

GATE_PIECE = "gate_doors";

// Vertical plank grooves cut down from a panel top surface at z = 0.
module gh_planks(w, l, pitch = 3.4) {
    for (x = [scaled(pitch) : scaled(pitch) : w - 1])
        translate([x - 0.2, -EPS, -0.4]) cube([0.4, l + 2 * EPS, 0.5]);
}

// One door panel: 2D outline profile passed as a child, planked with
// raised straps and a handle boss. Lies flat, outline in XY.
module door_panel(w, h) {
    difference() {
        union() {
            linear_extrude(height = scaled(2.6)) children();
            for (z = [h * 0.22, h * 0.72])
                translate([0, z - scaled(0.9), scaled(2.6) - EPS])
                    intersection() {
                        cube([w, scaled(1.8), 0.6]);
                        translate([0, -z + scaled(0.9), -scaled(2.6)])
                            linear_extrude(height = scaled(4))
                                children();
                    }
        }
        translate([0, 0, scaled(2.6)]) gh_planks(w, h);
    }
}

// Loose door prop for standard doorway openings ("arch" or "rect").
module door_prop(style = "arch") {
    w = scaled(DOOR_W) - 0.6;
    h = scaled(DOOR_H) - 0.4;
    translate([w / 2, 0, 0]) door_panel(w, h)
        if (style == "arch")
            profile_arch(w, h, scaled(ARCH_RISE));
        else
            profile_rect(w, h);
    // handle boss
    translate([w * 0.82, h * 0.5, scaled(2.6)])
        cylinder(h = 0.9, d = scaled(2));
}

// Double gate doors: the gate arch split into two leaves with a
// center gap, printed side by side.
module gate_doors() {
    w = scaled(GATE_W) - 0.6;
    h = scaled(GATE_H) - 0.4;
    for (side = [0, 1])
        translate([side * (w / 2 + scaled(3)), 0, 0])
            door_panel(w, h)
                intersection() {
                    translate([w / 2 - side * (w / 2 + scaled(3)), 0])
                        profile_arch(w, h, scaled(GATE_RISE));
                    translate([side == 0 ? 0 : scaled(3) + 0.3, 0])
                        square([w / 2 - 0.3, h]);
                }
}

// Securing beam: drops into the gate_wall brackets behind the doors.
module gate_beam() {
    bs = scaled(GATE_BEAM_SQ);
    len = scaled(GATE_W) + 2 * scaled(4) + scaled(10);
    cube([len, bs, bs]);
    for (x = [0, len - scaled(1.2)])
        translate([x, -scaled(0.5), 0])
            cube([scaled(1.2), bs + scaled(1), bs]);
}

// Drawbridge: planked deck, 45-degree approach chamfer at the free
// end, rope holes at the pivot end. Prints flat.
module drawbridge() {
    w = grid(2) - scaled(6);
    l = grid(2);
    t = scaled(3);
    difference() {
        union() {
            cube([w, l - scaled(3), t]);
            translate([0, l - scaled(3), 0])
                hull() {
                    cube([w, EPS, t]);
                    translate([0, scaled(3) - EPS, 0]) cube([w, EPS, t / 2]);
                }
            // side rub rails
            for (x = [0, w - scaled(2)])
                translate([x, 0, t - EPS])
                    cube([scaled(2), l - scaled(4), scaled(1.2)]);
        }
        translate([0, 0, t]) gh_planks(w, l, 4.2);
        for (x = [scaled(4), w - scaled(4)])
            translate([x, scaled(4), -EPS])
                cylinder(h = t + scaled(1.2) + 2 * EPS, d = scaled(2.6));
    }
}

module gate_piece(kind = GATE_PIECE) {
    if (kind == "gate_doors") gate_doors();
    if (kind == "gate_beam")  gate_beam();
    if (kind == "drawbridge") drawbridge();
    if (kind == "door_arch")  door_prop("arch");
    if (kind == "door_rect")  door_prop("rect");
}
