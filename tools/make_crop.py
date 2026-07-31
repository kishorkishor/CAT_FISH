"""Turn four generated crop stages into a growth sequence.

PixelLab draws whatever it is asked for at the size of the canvas, so a "tiny
seedling" comes back as tall as the ripe plant and the four stages read as four
different plants rather than one plant growing. Scaling each stage against the
last one is what makes growth legible at a glance.

Each stage is cropped to its ink, scaled with nearest-neighbour so the pixel grid
survives, and re-padded bottom-centred onto a common canvas. Bottom-centred
matters: the farm plants a sprite by its base, so every stage has to share one
ground line or the plant hops when it grows.

Usage:  python make_crop.py <crop_dir> [scale0 scale1 scale2 scale3]
"""
import sys
from pathlib import Path

from PIL import Image

# How tall each stage stands relative to the ripe plant.
DEFAULT_SCALES = [0.55, 0.72, 0.88, 1.0]
CANVAS = 48


def main() -> int:
    crop_dir = Path(sys.argv[1])
    scales = [float(a) for a in sys.argv[2:6]] if len(sys.argv) > 5 else DEFAULT_SCALES

    sources = sorted(crop_dir.glob("stage_*.png"))
    if len(sources) != len(scales):
        print(f"{crop_dir}: expected {len(scales)} stages, found {len(sources)}")
        return 1

    inks = []
    for p in sources:
        im = Image.open(p).convert("RGBA")
        box = im.getbbox()
        if box is None:
            print(f"{p} is empty")
            return 1
        inks.append(im.crop(box))

    # The ripe stage sets the size everything else is measured against.
    full_h = inks[-1].height
    out_dir = crop_dir.parent.parent / "crops_built" / crop_dir.name
    out_dir.mkdir(parents=True, exist_ok=True)

    report = []
    for i, (ink, scale) in enumerate(zip(inks, scales)):
        target_h = max(6, int(round(full_h * scale)))
        target_w = max(6, int(round(ink.width * target_h / ink.height)))
        scaled = ink.resize((target_w, target_h), Image.NEAREST)

        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.paste(scaled, ((CANVAS - target_w) // 2, CANVAS - target_h), scaled)
        canvas.save(out_dir / f"stage_{i}.png")
        report.append(f"{target_w}x{target_h}")

    print(f"{crop_dir.name}: " + "  ".join(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
