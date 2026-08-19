// fit_coupon.scad — Phase 0 pipeline proof + Phase 6 tolerance tester.
// Two 1x1 grid plates that mate with the selected connector. Print a
// coupon per connector type to dial in FIT before printing full kits.

include <../lib/grid.scad>
include <../lib/connectors.scad>

// "tab" | "magnet" | "dowel" | "none"
CONNECTOR = "tab";

// Gap between the two plates on the print bed.
COUPON_GAP = 5;

// Magnet coupons need enough edge height to swallow the magnet.
t = (CONNECTOR == "magnet")
    ? max(scaled(FLOOR_THICKNESS), magnet_d() + 2.4)
    : scaled(FLOOR_THICKNESS);

module plate() {
    cube([grid(1), grid(1), t]);
}

module label(txt) {
    translate([grid(1) / 2, grid(1) / 2, t - 0.4])
        linear_extrude(height = 0.4 + EPS)
            text(txt, size = 3, halign = "center", valign = "center",
                 font = "Liberation Sans:style=Bold");
}

// Plate A: edge face at x = 0, material on -X. Carries the male tab.
module coupon_a() {
    difference() {
        union() {
            translate([-grid(1), -grid(1) / 2, 0]) plate();
            if (CONNECTOR == "tab") tab_male(t);
        }
        if (CONNECTOR == "magnet")
            mirror([1, 0, 0]) magnet_pocket(t / 2);
        if (CONNECTOR == "dowel")
            mirror([1, 0, 0]) dowel_hole(t / 2);
        translate([-grid(1), -grid(1) / 2, 0]) label(str(CONNECTOR));
    }
}

// Plate B: edge face at x = 0, material on +X. Carries the female side.
module coupon_b() {
    difference() {
        translate([0, -grid(1) / 2, 0]) plate();
        if (CONNECTOR == "tab")    tab_female(t);
        if (CONNECTOR == "magnet") magnet_pocket(t / 2);
        if (CONNECTOR == "dowel")  dowel_hole(t / 2);
        translate([0, -grid(1) / 2, 0]) label(str(FIT));
    }
}

coupon_a();
translate([COUPON_GAP + (CONNECTOR == "tab" ? TAB_DEPTH : 0), 0, 0])
    coupon_b();
