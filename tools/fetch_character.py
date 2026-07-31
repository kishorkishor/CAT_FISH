"""Download a PixelLab character and lay its frames out for the SpriteFrames builder.

The export zip nests everything under a state folder:
    <State>/rotations/<direction>.png
    <State>/animations/<anim>/<direction>/frame_000.png
which is flattened here to
    assets/characters/<name>/rotations/<direction>.png
    assets/characters/<name>/<anim>/<direction>/frame_000.png

Only writes files whose bytes actually changed, so repainting a frame by hand and
re-running to pick up a newly finished animation does not silently revert it.

Usage:  python fetch_character.py <character_id> <name>
"""
import io
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHARACTERS = ROOT / "cat-game" / "assets" / "characters"

URL = "https://api.pixellab.ai/mcp/characters/{}/download"


def main() -> int:
    character_id = sys.argv[1]
    name = sys.argv[2]
    out_dir = CHARACTERS / name

    try:
        with urllib.request.urlopen(URL.format(character_id)) as response:
            payload = response.read()
    except urllib.error.HTTPError as exc:
        if exc.code == 423:
            print("still generating - some jobs have not finished yet")
            return 1
        raise

    archive = zipfile.ZipFile(io.BytesIO(payload))

    written = 0
    skipped = 0
    for entry in archive.namelist():
        if not entry.endswith(".png"):
            continue
        parts = entry.split("/")
        # Drop the state folder, and the "animations" level if present.
        rest = parts[1:]
        if rest and rest[0] == "animations":
            rest = rest[1:]
        target = out_dir.joinpath(*rest)

        data = archive.read(entry)
        if target.exists() and target.read_bytes() == data:
            skipped += 1
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        written += 1

    print(f"{out_dir}  {written} written, {skipped} unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
