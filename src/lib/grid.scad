// grid.scad — core grid, scale, and tolerance foundation.
// Every piece in the system includes this file.
//
// Two classes of dimension, never mixed:
//   scaled()  — aesthetic sizes; follow SCALE so kits can be resized.
//   absolute  — fit-critical sizes (clearances, magnet pockets, pin
//               holes); constant regardless of SCALE.

// One tabletop grid square. 25.4mm (1 inch) keeps pieces in register
// with battlemats and standard 2-inch tile systems. Change once to
// retarget the whole library (e.g. 32 for a 32mm module standard).
GRID_UNIT = 25.4;

// Aesthetic scale multiplier (1.0 = 28mm heroic terrain).
SCALE = 1.0;

// Default structural sizes (scaled, mm at SCALE = 1.0).
FLOOR_THICKNESS   = 4;
WALL_THICKNESS    = 6;
WALL_HEIGHT_UNITS = 2;   // wall height in grid units

// Fit preset: "tight" | "normal" | "loose". Absolute mm — never scaled.
FIT = "normal";

function fit_clearance(fit = FIT) =
    fit == "tight" ? 0.10 :
    fit == "loose" ? 0.25 :
                     0.15;

// Helpers.
function scaled(x) = x * SCALE;
function grid(n)   = n * GRID_UNIT * SCALE;

// Boolean-overlap epsilon for clean CSG.
EPS = 0.01;

// Curve quality.
$fa = 4;
$fs = 0.4;
