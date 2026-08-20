// curved_wall.scad — arc wall segment for towers and silos.
// SEG_DEGREES segments close a ring of centerline radius
// TOWER_R_UNITS grid units. OPENING and CRENELLATED apply.
include <../lib/grid.scad>
include <../lib/connectors.scad>
include <../lib/pieces.scad>

curved_wall(SEG_DEGREES, OPENING, CRENELLATED);
