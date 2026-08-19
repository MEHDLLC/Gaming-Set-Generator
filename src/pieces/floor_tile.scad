// floor_tile.scad — flat floor tile, FLOOR_W x FLOOR_L grid squares.
include <../lib/grid.scad>
include <../lib/connectors.scad>
include <../lib/pieces.scad>

FLOOR_W = 1;
FLOOR_L = 1;

floor_tile(FLOOR_W, FLOOR_L);
