// furniture.scad — scatter furniture for 28mm terrain.
// Requires grid.scad (for scaled() and EPS). No connector system —
// these are loose set-dressing pieces.
//
// Every piece is designed for ONE support-free print orientation:
//   inverted (legs up):  table, bench, stool
//   upright:             bed, wardrobe, throne, chest
//   on its back:         bookshelf (shelves/books become vertical walls)
//   flat:                ladder
// Crowns and ledges stay within 45 degrees; underside gaps are avoided
// by solid plinths.

FURNITURE = "table";
FURN_SEED = 3;
LADDER_L  = 58;   // scaled; default reaches a deck resting on walls

// Shallow plank grooves cut down from a top surface at z = 0.
module plank_etch(w, l, plank = 4, depth = 0.4) {
    for (x = [scaled(plank) : scaled(plank) : w - 1])
        translate([x - 0.25, -EPS, -depth])
            cube([0.5, l + 2 * EPS, depth + EPS]);
}

// ---- tables & seating (print inverted: top on the bed, legs up) ----
module f_table() {
    tw = scaled(24); td = scaled(14); th = scaled(15);
    tt = scaled(2);  leg = scaled(3); in = scaled(1.2);
    difference() {
        union() {
            translate([0, 0, th - tt]) cube([tw, td, tt]);
            translate([in, in, th - tt - scaled(2.2)])
                cube([tw - 2 * in, td - 2 * in, scaled(2.2) + EPS]);
            for (x = [in, tw - leg - in], y = [in, td - leg - in])
                translate([x, y, 0]) cube([leg, leg, th]);
        }
        translate([0, 0, th]) plank_etch(tw, td);
    }
}

module f_bench() {
    bw = scaled(20); bd = scaled(5); bh = scaled(10); tt = scaled(1.8);
    difference() {
        union() {
            translate([0, 0, bh - tt]) cube([bw, bd, tt]);
            for (x = [scaled(1), bw - scaled(3)])
                translate([x, scaled(0.5), 0])
                    cube([scaled(2), bd - scaled(1), bh]);
        }
        translate([0, 0, bh]) plank_etch(bw, bd);
    }
}

module f_stool() {
    sd = scaled(7); sh = scaled(8); tt = scaled(1.6); leg = scaled(1.8);
    translate([sd / 2, sd / 2, sh - tt]) cylinder(h = tt, d = sd);
    for (x = [scaled(0.8), sd - leg - scaled(0.8)],
         y = [scaled(0.8), sd - leg - scaled(0.8)])
        translate([x, y, 0]) cube([leg, leg, sh - tt + EPS]);
}

// ---- bed (print upright; solid base, wedge pillow) -----------------
module f_bed() {
    bw = scaled(16); bl = scaled(32); base = scaled(6);
    hb = scaled(16); fb = scaled(10); bt = scaled(2);
    difference() {
        union() {
            cube([bw, bl, base]);
            cube([bw, bt, hb]);
            translate([0, bl - bt, 0]) cube([bw, bt, fb]);
        }
        // blanket seam across the mattress top
        translate([-EPS, bl * 0.42, base - 0.4])
            cube([bw + 2 * EPS, 0.6, 0.4 + EPS]);
    }
    // pillow: 55-degree wedge, printable without support
    translate([scaled(2), scaled(3), base - EPS])
        hull() {
            cube([scaled(12), scaled(6), EPS]);
            translate([scaled(1.5), scaled(1.5), scaled(2.2)])
                cube([scaled(9), scaled(3), EPS]);
        }
}

// ---- wardrobe (print upright; 45-degree crown, etched doors) -------
module f_wardrobe() {
    w = scaled(22); d = scaled(11); h = scaled(36); ch = scaled(1.2);
    difference() {
        union() {
            cube([w, d, h - ch]);
            translate([0, 0, h - ch])
                hull() {
                    cube([w, d, EPS]);
                    translate([-scaled(1), -scaled(1), ch - EPS])
                        cube([w + scaled(2), d + scaled(2), EPS]);
                }
        }
        // recessed door panels and center split, front face y = 0
        for (x = [scaled(2), w / 2 + scaled(1)])
            translate([x, -EPS, scaled(4)])
                cube([w / 2 - scaled(3), 0.5 + EPS, h - scaled(10)]);
        translate([w / 2 - 0.3, -EPS, scaled(1.5)])
            cube([0.6, 0.5 + EPS, h - scaled(5)]);
    }
    for (x = [w / 2 - scaled(1.8), w / 2 + scaled(1.8)])
        translate([x, 0.3, h * 0.52]) sphere(d = scaled(1.5));
}

// ---- bookshelf (print ON ITS BACK: everything becomes a wall) ------
module f_bookshelf() {
    w = scaled(20); d = scaled(8); h = scaled(30); p = scaled(1.5);
    shelves = 3;
    cube([w, p, h]);                                   // back panel
    for (x = [0, w - p]) translate([x, 0, 0]) cube([p, d, h]);
    cube([w, d, p]);
    translate([0, 0, h - p]) cube([w, d, p]);
    gap = (h - 2 * p - shelves * p) / (shelves + 1);
    for (s = [1 : shelves])
        translate([0, 0, p + s * gap + (s - 1) * p])
            cube([w, d - scaled(0.5), p]);
    // seeded rows of books standing on each level
    for (s = [0 : shelves]) {
        z0 = p + s * (gap + p);
        hts = rands(gap * 0.45, gap * 0.8, 12, FURN_SEED * 7 + s);
        wds = rands(1.2, 2.6, 12, FURN_SEED * 11 + s);
        xacc = p + scaled(0.6);
        for (i = [0 : 9]) {
            x0 = xacc + i * (w - 2 * p - scaled(1.2)) / 10;
            if (x0 + scaled(wds[i]) < w - p - scaled(0.6))
                translate([x0, p - EPS, z0 - EPS])
                    cube([scaled(wds[i]), d - scaled(2.5), hts[s == 0 ? i : 11 - i]]);
        }
    }
}

// ---- throne / king's chair (print upright; all-solid masses) -------
module f_throne() {
    w = scaled(11); d = scaled(10); seat = scaled(9);
    bt = scaled(2.5); H = scaled(28); arm = scaled(2);
    difference() {
        union() {
            cube([w, d, seat]);                        // solid plinth
            cube([w, bt, H]);                          // tall back
            for (x = [0, w - arm])
                translate([x, 0, 0])
                    cube([arm, d - scaled(1.5), seat + scaled(6)]);
            for (x = [0, w - arm])                     // finials
                translate([x, 0, H]) cube([arm, bt, scaled(2.5)]);
        }
        // diamond etch on the backrest's front face
        translate([w / 2, bt + 0.4, (seat + H) / 2])
            rotate([90, 45, 0])
                linear_extrude(height = 0.5)
                    square(scaled(4.6), center = true);
    }
}

// ---- chest (print upright; barrel lid domes gradually) -------------
module f_chest() {
    w = scaled(12); d = scaled(8); h = scaled(6);
    difference() {
        union() {
            cube([w, d, h]);
            translate([0, 0, h]) intersection() {
                translate([0, d / 2, 0]) rotate([0, 90, 0])
                    cylinder(h = w, d = d);
                cube([w, d, d / 2]);
            }
        }
        // lid seam ring around the body just below the lid
        translate([-EPS, -EPS, h - 0.5])
            difference() {
                cube([w + 2 * EPS, d + 2 * EPS, 0.5]);
                translate([0.4 + EPS, 0.4 + EPS, -EPS])
                    cube([w - 0.8, d - 0.8, 0.5 + 2 * EPS]);
            }
    }
    // hasp on the front face
    translate([w / 2 - scaled(0.9), -0.3, h - scaled(1.6)])
        cube([scaled(1.8), 0.7, scaled(2.6)]);
}

// ---- ladder (print flat) --------------------------------------------
module f_ladder(len = 0) {
    L  = len > 0 ? len : scaled(LADDER_L);
    rw = scaled(2.2); rt = scaled(2); w = scaled(9);
    for (x = [0, w - rw]) translate([x, 0, 0]) cube([rw, L, rt]);
    for (y = [scaled(4) : scaled(6) : L - scaled(3)])
        translate([0, y, 0]) cube([w, scaled(1.8), rt]);
}

module furniture_piece(kind = FURNITURE) {
    if (kind == "table")     f_table();
    if (kind == "bench")     f_bench();
    if (kind == "stool")     f_stool();
    if (kind == "bed")       f_bed();
    if (kind == "wardrobe")  f_wardrobe();
    if (kind == "bookshelf") f_bookshelf();
    if (kind == "throne")    f_throne();
    if (kind == "chest")     f_chest();
    if (kind == "ladder")    f_ladder();
}
