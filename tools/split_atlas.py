"""Slice an atlas back into the raw per-tile PNGs. Inverse of build_atlas.py.

Painting one atlas beats opening sixteen files, but the atlas is generated - the
next pack would overwrite it. Splitting first puts the edit back in raw/, which is
the source of truth, so it survives later rebuilds.

Usage:  python split_atlas.py <atlas_png> <raw_dir>
"""
import sys
from pathlib import Path

from PIL import Image

COLS = 4
ROWS = 4


def main() -> int:
    atlas_png = Path(sys.argv[1])
    raw_dir = Path(sys.argv[2])

    atlas = Image.open(atlas_png).convert("RGBA")
    aw, ah = atlas.size
    if aw % COLS or ah % ROWS:
        print(f"atlas {aw}x{ah} does not divide evenly into {COLS}x{ROWS}")
        return 1
    tw, th = aw // COLS, ah // ROWS

    raw_dir.mkdir(parents=True, exist_ok=True)
    changed = 0
    for i in range(COLS * ROWS):
        box = ((i % COLS) * tw, (i // COLS) * th, (i % COLS + 1) * tw, (i // COLS + 1) * th)
        tile = atlas.crop(box)
        out = raw_dir / f"tile_{i}.png"

        if out.exists():
            before = Image.open(out).convert("RGBA")
            if before.size == tile.size and before.tobytes() == tile.tobytes():
                continue
        tile.save(out)
        changed += 1

    print(f"{atlas_png} -> {raw_dir}  tile={tw}x{th}  {changed}/{COLS * ROWS} tiles changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
