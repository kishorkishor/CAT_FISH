# Cat Fish

An isometric fishing game. You are a cat with a rod, a boat, and a home island.

Built with Godot 4.7.

## Running it

Double-click `run.bat`, or from a terminal:

    run.bat            # the grass island
    run.bat shore      # the sandbar and the sea
    run.bat editor     # open the Godot editor

`run.bat` rebuilds the art before it launches, so whatever you last painted is what you see.

| Control | |
|---|---|
| WASD / arrows | move |
| Shift | sprint — the cat drops onto four legs |
| Space | hop |

Speeds, the hop height and the sprite sets are all exported, so they can be tuned from the
Inspector while the game runs rather than by editing the scripts.

## Editing the art

Tiles live in `cat-game/assets/tiles/`. Two ways in, both fine:

- paint the packed atlas, `<set>_atlas.png` — one canvas, easiest for palette work
- paint the individual tiles in `raw/<set>/tile_0.png` … `tile_15.png`

Character frames live in `cat-game/assets/characters/<name>/` as individual PNGs, one folder
per animation and direction, so a single frame can be repainted without unpacking a sheet.

Then run `run.bat`, or just the rebuild on its own:

    python tools/rebuild.py --all
    python tools/rebuild.py --all --fetch   # also pull new animations from PixelLab

For tiles it works out which side you edited and syncs the other, so the two can't fight.
`characters.json` maps a character name to its PixelLab id; `--fetch` reads it.

## Why the rebuild step exists

Godot caches imported textures. Launching the game does not re-read a changed PNG — it keeps
serving the cached copy, so you see the old art with no error to tell you why. `rebuild.py`
forces the reimport. If a sprite ever looks stale, that's the reason.

## Layout

    cat-game/             the Godot project
      assets/tiles/       atlases, TileSets, and the raw per-tile art
      assets/characters/  frames, SpriteFrames, and the reference sprites
      scenes/             test scenes
      scripts/            gameplay
      tools/              headless build, screenshot and probe scripts
    tools/                art pipeline (python)
    backups/              hand-edited atlases, kept outside the project on purpose

Anything inside `cat-game/` gets imported by Godot, which is why backups live outside it, and
why `assets/characters/reference/` and `assets/tiles/raw/` carry a `.gdignore` — the game never
loads those, only the pipeline reads them.

## Tile geometry

64x48 art canvas: a 64x32 isometric diamond plus 16px of side wall. Sixteen tiles per set,
indexed by which corners are the primary terrain (`NW<<3 | NE<<2 | SW<<1 | SE`). The importer
measures this off the art rather than assuming it, so changing tile size doesn't need a code
change.

## Things that were not obvious

Ground is drawn *below* the entities rather than y-sorted against them. Every cell is at the
same elevation, so the floor has no reason to occlude anything standing on it — sorting the two
together made tiles clip the cat's feet near a cell boundary.

The hop is cosmetic. The body stays on the ground and only the sprite arcs upward, so collision
and sorting keep working mid-air while the shadow stays planted.

Sprinting swaps to a different sprite set, because a cat on four legs is a separate rig rather
than another animation of the upright one. The two sit on different canvas sizes, so each
carries its own offset to keep the feet planted through the swap.

`window/stretch/scale_mode` is `integer`. On `fractional` the art lands on non-integer pixel
sizes at real phone resolutions and shimmers as the camera moves.

Run `tools/check_dirs.gd` after touching the facing code — the input-to-direction mapping is
easy to mirror, and a mirrored one still plays a correct-looking walk cycle in the wrong
direction:

    godot --headless --path . --script res://tools/check_dirs.gd
