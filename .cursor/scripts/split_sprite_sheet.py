"""Split horizontal sprite sheets into numbered PNG frames for Godot."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def split_sheet(sheet_path: Path, out_dir: Path, prefix: str, frames: int = 6) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(sheet_path).convert("RGBA")
    w, h = img.size
    frame_w = w // frames
    for i in range(frames):
        box = (i * frame_w, 0, (i + 1) * frame_w, h)
        frame = img.crop(box)
        out_path = out_dir / f"{prefix}_{i:03d}.png"
        frame.save(out_path)
        print(out_path)


def duplicate_idle(idle_frame: Path, out_dir: Path, prefix: str, count: int = 6) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(idle_frame).convert("RGBA")
    for i in range(count):
        out_path = out_dir / f"{prefix}_{i:03d}.png"
        img.save(out_path)
        print(out_path)


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: split_sprite_sheet.py <sheet.png> <out_dir> <prefix> [frames]")
        raise SystemExit(1)
    sheet = Path(sys.argv[1])
    out = Path(sys.argv[2])
    prefix = sys.argv[3]
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 6
    split_sheet(sheet, out, prefix, n)
