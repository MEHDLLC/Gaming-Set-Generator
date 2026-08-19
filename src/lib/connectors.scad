// connectors.scad — shared connector geometry.
// Requires grid.scad to be included first.
//
// Convention: a connector lives on an edge face lying in the YZ plane
// at x = 0, centered on y = 0, with the piece's material on the -X
// side for male parts and the +X side for female parts. Pieces
// translate/rotate these modules into position.
//
// All fit-critical dimensions here are ABSOLUTE (see grid.scad).

// Connector type used by all pieces: "tab" | "magnet" | "dowel" | "none".
// Tab & slot is gendered (a piece has male and female edges); magnet,
// dowel, and none are genderless, so tiles can be rotated freely.
CONNECTOR = "tab";

// Tab & slot (puzzle-style dovetail, full piece thickness). Defaults
// suit flat tiles; walls pass smaller dims that fit inside their
// thickness (see pieces.scad).
TAB_NECK  = 6;    // width at the edge face
TAB_HEAD  = 10;   // width at the tip
TAB_DEPTH = 6;    // how far the tab projects

// Dowel pin (1.75mm filament offcuts make free pins).
DOWEL_D     = 1.85;
DOWEL_DEPTH = 6;

// Magnet pocket. Named size "DxH" in mm.
MAGNET = "5x2";
function magnet_d(m = MAGNET) =
    m == "3x2" ? 3 : m == "6x2" ? 6 : m == "8x3" ? 8 : 5;
function magnet_h(m = MAGNET) =
    m == "8x3" ? 3 : 2;

// Dovetail profile, projecting toward +X. grow > 0 loosens the female.
module tab_profile(grow = 0, neck = TAB_NECK, head = TAB_HEAD,
                   depth = TAB_DEPTH) {
    polygon([
        [-EPS,         -(neck / 2 + grow)],
        [depth + grow, -(head / 2 + grow)],
        [depth + grow,   head / 2 + grow],
        [-EPS,           neck / 2 + grow]
    ]);
}

// Male tab: union onto a piece whose edge face is at x = 0, material
// on -X. The tab projects +X into the neighboring piece's slot.
module tab_male(thickness, neck = TAB_NECK, head = TAB_HEAD,
                depth = TAB_DEPTH) {
    linear_extrude(height = thickness)
        tab_profile(0, neck, head, depth);
}

// Female slot: subtract from a piece whose edge face is at x = 0,
// material on +X. The cut extends +X into the material, opening at the
// edge face so the mating tab enters from -X.
module tab_female(thickness, clearance = fit_clearance(),
                  neck = TAB_NECK, head = TAB_HEAD, depth = TAB_DEPTH) {
    translate([0, 0, -EPS])
        linear_extrude(height = thickness + 2 * EPS)
            tab_profile(clearance, neck, head, depth);
}

// Cylindrical pocket bored into an edge face at x = 0, material on +X,
// axis along +X, centered at height z.
module edge_pocket(d, depth, z) {
    translate([-EPS, 0, z])
        rotate([0, 90, 0])
            cylinder(h = depth + EPS, d = d);
}

// Magnet pocket (female on both mating pieces). Slight extra depth so
// the magnet seats flush after glue.
module magnet_pocket(z, m = MAGNET, clearance = fit_clearance()) {
    edge_pocket(magnet_d(m) + clearance, magnet_h(m) + 0.1, z);
}

// Dowel hole (female on both mating pieces).
module dowel_hole(z, clearance = fit_clearance()) {
    edge_pocket(DOWEL_D + clearance, DOWEL_DEPTH, z);
}
