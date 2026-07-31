"""Get edited art into the running game.

Repacks tilesets, rebuilds character SpriteFrames, reimports, and regenerates the
Godot resources. The reimport is the part that matters: without it Godot keeps
serving its cached texture and the game shows the old sprite with nothing anywhere
to say why.

For tiles, paint either the atlas or the raw tiles - whichever was touched last is
treated as the truth and pushed to the other side.

Character art is downloaded once and then owned locally; pass --fetch to pull new
animations from PixelLab. Which characters exist is read from characters.json, so
a new one needs an entry there rather than a remembered UUID.

Usage:  python rebuild.py [--all | <set_or_character>...] [--fetch]
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "cat-game"
TILES = PROJECT / "assets" / "tiles"
CHARACTERS = PROJECT / "assets" / "characters"
MANIFEST = ROOT / "characters.json"

GODOT = Path(os.environ.get(
    "GODOT_BIN",
    r"D:\GODOT GAME\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
))


def run(args, label: str) -> str:
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        raise SystemExit(f"[{label}] failed with exit {result.returncode}")
    return result.stdout


def godot(*args, label: str) -> str:
    return run([GODOT, "--headless", "--path", PROJECT, *args], label)


def newest(paths) -> float:
    times = [p.stat().st_mtime for p in paths if p.exists()]
    return max(times) if times else 0.0


def tile_sets():
    raw = TILES / "raw"
    if not raw.is_dir():
        return []
    return sorted(p.name for p in raw.iterdir() if p.is_dir())


def character_names():
    if not CHARACTERS.is_dir():
        return []
    return sorted(p.name for p in CHARACTERS.iterdir()
                  if p.is_dir() and (p / "rotations").is_dir())


def sync_tiles(set_name: str) -> None:
    raw_dir = TILES / "raw" / set_name
    atlas = TILES / f"{set_name}_atlas.png"
    if not raw_dir.is_dir():
        raise SystemExit(f"no such tile set: {raw_dir}")

    if atlas.exists() and atlas.stat().st_mtime > newest(raw_dir.glob("tile_*.png")):
        # build_atlas.py always writes the atlas last, so it is normally the newer
        # file even when nothing was hand-edited. Report what actually moved rather
        # than which timestamp won, or every rebuild claims an edit that never happened.
        out = run([sys.executable, ROOT / "tools" / "split_atlas.py", atlas, raw_dir], "split")
        print(f"[{set_name}] atlas -> raw: {out.strip().rsplit('  ', 1)[-1]}")
    else:
        print(f"[{set_name}] raw -> atlas: raw tiles edited more recently")

    run([sys.executable, ROOT / "tools" / "build_atlas.py", raw_dir, atlas], "build_atlas")


def fetch_character(name: str) -> None:
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    character_id = manifest.get(name)
    if not character_id:
        print(f"[{name}] no id in {MANIFEST.name}, skipping fetch")
        return
    out = run([sys.executable, ROOT / "tools" / "fetch_character.py", character_id, name], "fetch")
    print(f"[{name}] {out.strip().split('  ')[-1]}")


def main() -> int:
    if not GODOT.exists():
        raise SystemExit(f"Godot not found at {GODOT} - set GODOT_BIN")

    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}

    all_tiles = tile_sets()
    all_characters = character_names()
    if not args or "--all" in flags:
        targets = all_tiles + all_characters
    else:
        targets = args

    for name in targets:
        if name in all_tiles:
            sync_tiles(name)
        elif name in all_characters:
            if "--fetch" in flags:
                fetch_character(name)
        else:
            raise SystemExit(f"unknown target: {name}")

    # One reimport for everything, then build the resources that depend on it.
    godot("--import", label="godot import")

    for name in targets:
        if name in all_tiles:
            print(godot("--script", "res://tools/make_tileset.gd", "--", name,
                        label="make_tileset").strip().splitlines()[-1])
        elif name in all_characters:
            print(godot("--script", "res://tools/make_spriteframes.gd", "--", name, "10",
                        label="make_spriteframes").strip().splitlines()[-1])

    print("ready")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
