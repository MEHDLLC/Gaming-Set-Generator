// wall_corner.scad — 90-degree corner wall.
// CORNER_MIRRORED selects handedness (tab chains are chiral).
include <../lib/grid.scad>
include <../lib/connectors.scad>
include <../lib/pieces.scad>

CORNER_MIRRORED = false;

wall_corner(CORNER_MIRRORED);
