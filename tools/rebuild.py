"""Get edited art into the running game.

Repacks the atlas, reimports it, rebuilds the TileSet. The reimport is the part
that matters: without it Godot keeps serving its cached texture and the game shows
the old sprite with nothing anywhere to say why.

Paint either the atlas or the raw tiles - whichever was touched last is treated as
the truth and pushed to the other side.

Usage:  python rebuild.py <set_name> [more_sets...]
        python rebuild.py --all
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "cat-game"
TILES = PROJECT / "assets" / "tiles"

GODOT = Path(os.environ.get(
    "GODOT_BIN",
    r"D:\GODOT GAME\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
))


def run(args: list[str], label: str) -> str:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        raise SystemExit(f"[{label}] failed with exit {result.returncode}")
    return result.stdout


def newest(paths) -> float:
    times = [p.stat().st_mtime for p in paths if p.exists()]
    return max(times) if times else 0.0


def rebuild(set_name: str) -> None:
    raw_dir = TILES / "raw" / set_name
    atlas = TILES / f"{set_name}_atlas.png"

    if not raw_dir.is_dir():
        raise SystemExit(f"no such set: {raw_dir}")

    raw_time = newest(raw_dir.glob("tile_*.png"))
    atlas_time = atlas.stat().st_mtime if atlas.exists() else 0.0

    if atlas_time > raw_time:
        # build_atlas.py always writes the atlas last, so it is normally the newer
        # file even when nothing was hand-edited. Report what actually moved rather
        # than which timestamp won, or every rebuild claims an edit that never happened.
        out = run([sys.executable, str(ROOT / "tools" / "split_atlas.py"),
                   str(atlas), str(raw_dir)], "split")
        moved = out.strip().rsplit("  ", 1)[-1]
        print(f"[{set_name}] atlas -> raw: {moved}")
    else:
        print(f"[{set_name}] raw -> atlas: raw tiles edited more recently")

    run([sys.executable, str(ROOT / "tools" / "build_atlas.py"), str(raw_dir), str(atlas)],
        "build_atlas")
    # Without this Godot serves the stale cached texture and the game shows old art.
    run([str(GODOT), "--headless", "--path", str(PROJECT), "--import"], "godot import")
    run([str(GODOT), "--headless", "--path", str(PROJECT),
         "--script", "res://tools/make_tileset.gd", "--", set_name], "make_tileset")
    print(f"[{set_name}] ready")


def main() -> int:
    if not GODOT.exists():
        raise SystemExit(f"Godot not found at {GODOT} - set GODOT_BIN")

    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    if args == ["--all"]:
        args = sorted(p.name for p in (TILES / "raw").iterdir() if p.is_dir())

    for set_name in args:
        rebuild(set_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
