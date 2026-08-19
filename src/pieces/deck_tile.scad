// deck_tile.scad — upper floor / ceiling plate, grooved both faces.
// Optional stairwell hole: DECK_HOLE_W x DECK_HOLE_L cells at
// (DECK_HOLE_X, DECK_HOLE_Y).
include <../lib/grid.scad>
include <../lib/connectors.scad>
include <../lib/pieces.scad>

DECK_W = 2;
DECK_L = 2;
DECK_HOLE_X = 0;
DECK_HOLE_Y = 0;
DECK_HOLE_W = 0;
DECK_HOLE_L = 0;

deck_tile(DECK_W, DECK_L, DECK_HOLE_X, DECK_HOLE_Y,
          DECK_HOLE_W, DECK_HOLE_L);
