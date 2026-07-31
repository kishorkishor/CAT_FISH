# Cat Fish

An isometric fishing game. You are a cat with a rod, a boat, and a home island.

Built with Godot 4.7.

## Running it

Double-click `run.bat`, or from a terminal:

    run.bat            # the grass island
    run.bat shore      # the sandbar and the sea
    run.bat editor     # open the Godot editor

`run.bat` rebuilds the art before it launches, so whatever you last painted is what you see.

Move with WASD or the arrow keys.

## Editing the art

Tiles live in `cat-game/assets/tiles/`. Two ways in, both fine:

- paint the packed atlas, `<set>_atlas.png` — one canvas, easiest for palette work
- paint the individual tiles in `raw/<set>/tile_0.png` … `tile_15.png`

Then run `run.bat`, or just the rebuild on its own:

    python tools/rebuild.py --all

It works out which side you edited and syncs the other, so the two can't fight.

## Why the rebuild step exists

Godot caches imported textures. Launching the game does not re-read a changed PNG — it keeps
serving the cached copy, so you see the old art with no error to tell you why. `rebuild.py`
forces the reimport. If a sprite ever looks stale, that's the reason.

## Layout

    cat-game/           the Godot project
      assets/tiles/     atlases, TileSets, and the raw per-tile art
      scenes/           test scenes
      scripts/          gameplay
      tools/            headless build and screenshot scripts
    tools/              art pipeline (python)
    backups/            hand-edited atlases, kept outside the project on purpose

Anything inside `cat-game/` gets imported by Godot, which is why backups live outside it.

## Tile geometry

64x48 art canvas: a 64x32 isometric diamond plus 16px of side wall. Sixteen tiles per set,
indexed by which corners are the primary terrain (`NW<<3 | NE<<2 | SW<<1 | SE`). The importer
measures this off the art rather than assuming it, so changing tile size doesn't need a code
change.
