// sculpture.scad — minimalist arch sculpture headphone stand mounted
// on a removable lid over a storage box.
//
// Form: an asymmetric superellipse arch. The outer surface narrows
// monotonically with height, so no layer ever oversails the one below;
// the inner void is a steep rhombus (walls ~76 degrees), so the
// material closing over it is barely 15 degrees off vertical. The
// whole sculpture therefore prints with no supports, lid flat on the
// bed, and the crown is a broad rounded saddle for the headband while
// the ear cups hang clear either side of the 26mm-thin blade.
//
// The lid drops into a rabbet inside the box rim and lifts out by the
// sculpture itself — the box holds cables, adapters and dongles.

SCULPT_PIECE = "lid";   // "lid" (sculpture + lid) | "box"

// Box. Narrow left-right so the ear cups hang past it, deep
// front-back so the arch has a wide stance.
BOX_W     = 95;
BOX_D     = 110;
BOX_H     = 52;
BOX_WALL  = 2.6;
BOX_FLOOR = 2.6;
BOX_R     = 7;

LID_T     = 4;
LID_LEDGE = 2.4;    // rabbet the lid rests on
LID_CLR   = 0.35;   // per side (absolute — a fit dimension)

// Arch. A* are half-spans front/back at the base, H the apex height.
ARCH_H  = 165;
ARCH_AF = 50;
ARCH_AB = 38;
ARCH_N  = 2.5;      // >2 gives a rounded crown
VOID_H  = 143;
VOID_AF = 32;
VOID_AB = 23;       // n = 1 -> straight-sided rhombus void
ARCH_T  = 26;       // blade thickness (left-right)
ARCH_CH = 1.5;      // edge chamfer

// Superellipse point: t sweeps 0..180 from the front foot, over the
// crown, to the back foot.
function arch_pt(Af, Ab, H, n, t) =
    let (c = cos(t), s = sin(t), e = 2 / n)
    [(c >= 0 ? Af : -Ab) * pow(abs(c), e), H * pow(abs(s), e)];

function arch_poly(Af, Ab, H, n, N = 96) =
    [for (i = [0 : N]) arch_pt(Af, Ab, H, n, i * 180 / N)];

// Side profile: outer arch less the void, the void carried below the
// base line so the arch stands on two separate feet.
module arch_profile() {
    difference() {
        polygon(arch_poly(ARCH_AF, ARCH_AB, ARCH_H, ARCH_N));
        offset(r = 2) offset(r = -2)
            polygon(concat(arch_poly(VOID_AF, VOID_AB, VOID_H, 1, 64),
                           [[-VOID_AB, -12], [ARCH_AF, -12]]));
    }
}

// Chamfered blade: nested extrusions, thickest where the profile is
// inset furthest, so the long edges break at roughly 45 degrees.
module arch_blade(steps = 5) {
    for (i = [0 : steps])
        linear_extrude(height = ARCH_T - 2 * ARCH_CH * (i / steps),
                       center = true)
            offset(r = -ARCH_CH * (1 - i / steps))
                arch_profile();
}

module rrect(w, d, r) {
    offset(r = r) square([w - 2 * r, d - 2 * r], center = true);
}

// Lid plate with the sculpture standing on it — printed as one piece.
module sculpture_lid() {
    linear_extrude(LID_T)
        rrect(BOX_W - 2 * BOX_WALL - 2 * LID_CLR,
              BOX_D - 2 * BOX_WALL - 2 * LID_CLR,
              max(1, BOX_R - BOX_WALL));
    translate([0, 0, LID_T - 0.01])
        rotate([90, 0, 90]) arch_blade();
}

// Box: open top with an internal rabbet. Every wall is vertical and
// the rabbet faces upward, so it prints upright with no supports.
module storage_box() {
    difference() {
        linear_extrude(BOX_H) rrect(BOX_W, BOX_D, BOX_R);
        translate([0, 0, BOX_H - LID_T])
            linear_extrude(LID_T + 1)
                rrect(BOX_W - 2 * BOX_WALL, BOX_D - 2 * BOX_WALL,
                      max(1, BOX_R - BOX_WALL));
        translate([0, 0, BOX_FLOOR])
            linear_extrude(BOX_H - LID_T - BOX_FLOOR + 0.01)
                rrect(BOX_W - 2 * (BOX_WALL + LID_LEDGE),
                      BOX_D - 2 * (BOX_WALL + LID_LEDGE),
                      max(1, BOX_R - BOX_WALL - LID_LEDGE));
    }
}

module sculpt_piece(kind = SCULPT_PIECE) {
    if (kind == "lid") sculpture_lid();
    if (kind == "box") storage_box();
}
