// hp_seed_sweep.scad — silhouette-rule check across many tree seeds
// and the fixed designs. Pure functions only: no geometry is built,
// so this runs in milliseconds and fails the build on any violation.
include <../src/lib/grid.scad>
include <../src/lib/connectors.scad>
include <../src/lib/headphone.scad>

SWEEP_N = 60;

for (s = [1 : SWEEP_N])
    let (m = tree_map(s))
        assert(hp_valid(m, 8),
               str("tree seed ", s, ": trunk ", trunk_width(m, 8),
                   "mm vs top ", top_width(m, 8), "mm"));

assert(hp_valid(str_map(SHEEP_ROWS), 6), "sheep silhouette invalid");
assert(hp_valid(str_map(CHICKEN_ROWS), 10), "chicken silhouette invalid");

echo(str("sweep ok: ", SWEEP_N, " tree seeds + sheep + chicken"));
echo(str("tree   trunk/top = ", trunk_width(tree_map(42), 8), " / ",
         top_width(tree_map(42), 8)));
echo(str("sheep  trunk/top = ", trunk_width(str_map(SHEEP_ROWS), 6), " / ",
         top_width(str_map(SHEEP_ROWS), 6)));
echo(str("chick  trunk/top = ", trunk_width(str_map(CHICKEN_ROWS), 10), " / ",
         top_width(str_map(CHICKEN_ROWS), 10)));
