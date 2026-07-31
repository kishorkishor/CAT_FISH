"""Pack 16 corner tiles into one atlas, 4x4, so tile i is at (i % 4, i // 4).

Also writes the measured tile geometry as JSON beside the atlas. Tile canvas size
changes whenever the generator's tile size or view angle changes, and a hardcoded
guess mis-slices the atlas silently, so it gets measured rather than assumed.

If raw/<set>/anim/frame_*.png exists, those frames are appended as one extra row
below the 16 static tiles and recorded in the sidecar. Godot's tile animation
wants its frames contiguous in the atlas, and a fresh bottom row is the one place
they can sit without moving any of the 16 static cells. Without an anim folder
the output is byte-identical to the old 4x4 atlas.

Usage:  python build_atlas.py <raw_dir> <out_png>
"""
import json
import sys
from pathlib import Path

from PIL import Image

COLS = 4
ROWS = 4
ANIM_FPS = 4


def measure_isometric(im: Image.Image) -> dict:
    """Recover the diamond footprint from a tile's silhouette.

    An isometric tile is a diamond of the full tile width, plus a side wall
    extruded straight down. The silhouette therefore reaches full width at the
    diamond's vertical midpoint and holds it until the wall ends. So the first
    full-width row is half the diamond's height, and whatever is left over at
    the bottom is the wall.
    """
    w, h = im.size
    px = im.load()

    first_full = None
    for y in range(h):
        xs = [x for x in range(w) if px[x, y][3] > 0]
        if xs and (xs[-1] - xs[0] + 1) == w:
            first_full = y
            break
    if first_full is None or first_full == 0:
        raise ValueError("could not find the diamond midpoint - is this an isometric tile?")

    diamond_h = min(2 * first_full, h)
    depth = h - diamond_h
    return {
        "tile_width": w,
        "tile_height": h,
        "cell_width": w,
        "cell_height": diamond_h,
        "depth": depth,
        # Art sits high inside its canvas by half the wall, so the texture is
        # pushed back down to put the diamond centre on the cell centre.
        "texture_origin_y": -(depth // 2),
        "cols": COLS,
        "rows": ROWS,
    }


def main() -> int:
    raw_dir = Path(sys.argv[1])
    out_png = Path(sys.argv[2])

    tiles = []
    for i in range(COLS * ROWS):
        p = raw_dir / f"tile_{i}.png"
        if not p.exists():
            print(f"missing {p}")
            return 1
        tiles.append(Image.open(p).convert("RGBA"))

    sizes = {t.size for t in tiles}
    if len(sizes) != 1:
        print(f"tiles disagree on size: {sizes} - all 16 must share one canvas")
        return 1
    tw, th = tiles[0].size

    frames = []
    for p in sorted((raw_dir / "anim").glob("frame_*.png")):
        frame = Image.open(p).convert("RGBA")
        if frame.size != (tw, th):
            print(f"{p} is {frame.size}, tiles are {tw}x{th} - frames must match")
            return 1
        frames.append(frame)

    cols = max(COLS, len(frames))
    rows = ROWS + (1 if frames else 0)
    atlas = Image.new("RGBA", (cols * tw, rows * th), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        atlas.paste(t, ((i % COLS) * tw, (i // COLS) * th))
    for i, f in enumerate(frames):
        atlas.paste(f, (i * tw, ROWS * th))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out_png)

    geom = measure_isometric(tiles[0])
    if frames:
        geom["anim_frames"] = len(frames)
        geom["anim_row"] = ROWS
        geom["anim_fps"] = ANIM_FPS
    out_json = out_png.with_suffix(".json")
    out_json.write_text(json.dumps(geom, indent=2))

    print(f"{out_png}  atlas={atlas.size}  tile={tw}x{th}  anim_frames={len(frames)}")
    print(f"{out_json}  cell={geom['cell_width']}x{geom['cell_height']}  "
          f"depth={geom['depth']}  origin_y={geom['texture_origin_y']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
