// tower_floor.scad — round tower plate with ring channels.
// TOWER_DECK: grooves both faces (upper storey). TOWER_HATCH: 1x1
// cell opening for a ladder or the hatch_lid piece.
include <../lib/grid.scad>
include <../lib/connectors.scad>
include <../lib/pieces.scad>

TOWER_DECK  = false;
TOWER_HATCH = false;

tower_floor(TOWER_DECK, TOWER_HATCH);
