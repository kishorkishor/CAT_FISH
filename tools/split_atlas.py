"""Slice an atlas back into the raw per-tile PNGs. Inverse of build_atlas.py.

Painting one atlas beats opening sixteen files, but the atlas is generated - the
next pack would overwrite it. Splitting first puts the edit back in raw/, which is
the source of truth, so it survives later rebuilds.

Geometry comes from the .json sidecar when there is one, because an atlas with an
animation row no longer divides evenly into 4x4. Any animation frames in the atlas
are sliced back to raw/anim/ the same way.

Usage:  python split_atlas.py <atlas_png> <raw_dir>
"""
import json
import sys
from pathlib import Path

from PIL import Image

COLS = 4
ROWS = 4


def save_if_changed(tile: Image.Image, out: Path) -> bool:
    if out.exists():
        before = Image.open(out).convert("RGBA")
        if before.size == tile.size and before.tobytes() == tile.tobytes():
            return False
    tile.save(out)
    return True


def main() -> int:
    atlas_png = Path(sys.argv[1])
    raw_dir = Path(sys.argv[2])

    atlas = Image.open(atlas_png).convert("RGBA")
    aw, ah = atlas.size

    sidecar = atlas_png.with_suffix(".json")
    if sidecar.exists():
        geom = json.loads(sidecar.read_text())
        tw, th = geom["tile_width"], geom["tile_height"]
        anim_frames = geom.get("anim_frames", 0)
        anim_row = geom.get("anim_row", ROWS)
    else:
        if aw % COLS or ah % ROWS:
            print(f"atlas {aw}x{ah} does not divide evenly into {COLS}x{ROWS} "
                  f"and there is no {sidecar.name} to say otherwise")
            return 1
        tw, th = aw // COLS, ah // ROWS
        anim_frames = 0
        anim_row = ROWS

    raw_dir.mkdir(parents=True, exist_ok=True)
    changed = 0
    for i in range(COLS * ROWS):
        box = ((i % COLS) * tw, (i // COLS) * th, (i % COLS + 1) * tw, (i // COLS + 1) * th)
        if save_if_changed(atlas.crop(box), raw_dir / f"tile_{i}.png"):
            changed += 1

    if anim_frames:
        (raw_dir / "anim").mkdir(exist_ok=True)
        for i in range(anim_frames):
            box = (i * tw, anim_row * th, (i + 1) * tw, (anim_row + 1) * th)
            if save_if_changed(atlas.crop(box), raw_dir / "anim" / f"frame_{i:02d}.png"):
                changed += 1

    total = COLS * ROWS + anim_frames
    print(f"{atlas_png} -> {raw_dir}  tile={tw}x{th}  {changed}/{total} tiles changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
