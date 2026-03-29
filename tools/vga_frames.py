#!/usr/bin/env python3
"""VGA frame tools for simulation output.

Subcommands:
    gallery  - Convert PPM frames to HTML gallery
    export   - Convert vga_frame*.ppm files to PNG files

Usage:
    python tools/vga_frames.py gallery --frames 10 --dir work/gallery
    python tools/vga_frames.py export --frames 10 --dir work/gallery
"""

import argparse
import base64
import io
import os
import struct
import sys
import zlib
from pathlib import Path


def read_ppm(path: str) -> tuple[int, int, bytes]:
    """Read a binary PPM (P6) file. Returns (width, height, rgb_bytes)."""
    with open(path, "rb") as f:
        magic = f.readline().strip()
        if magic != b"P6":
            raise ValueError(f"{path}: not a P6 PPM (got {magic!r})")

        line = f.readline()
        while line.startswith(b"#"):
            line = f.readline()

        w, h = map(int, line.split())
        maxval = int(f.readline().strip())
        if maxval != 255:
            raise ValueError(f"{path}: unsupported maxval {maxval}")

        data = f.read(w * h * 3)
    return w, h, data


def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    c = chunk_type + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)


def rgb_to_png(width: int, height: int, rgb_bytes: bytes) -> bytes:
    """Encode raw RGB bytes into a PNG."""
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw.extend(rgb_bytes[y * stride:(y + 1) * stride])

    compressed = zlib.compress(bytes(raw), 9)

    buf = io.BytesIO()
    buf.write(b"\x89PNG\r\n\x1a\n")
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    buf.write(_png_chunk(b"IHDR", ihdr))
    buf.write(_png_chunk(b"IDAT", compressed))
    buf.write(_png_chunk(b"IEND", b""))
    return buf.getvalue()


def ppm_to_png_file(ppm_path: str, out_path: str | None = None, force: bool = False) -> str:
    """Convert one PPM file to PNG and return output path."""
    in_path = Path(ppm_path)
    png_path = Path(out_path) if out_path else in_path.with_suffix(".png")

    if (not force) and png_path.exists() and png_path.stat().st_mtime >= in_path.stat().st_mtime:
        return str(png_path)

    w, h, rgb = read_ppm(str(in_path))
    png_data = rgb_to_png(w, h, rgb)
    with open(png_path, "wb") as f:
        f.write(png_data)
    return str(png_path)


HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>VGA Frame Gallery</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: system-ui, -apple-system, sans-serif;
    background: #1a1a2e; color: #e0e0e0;
    padding: 2rem;
  }}
  h1 {{
    text-align: center; margin-bottom: 1.5rem;
    font-size: 1.6rem; letter-spacing: .05em;
  }}
  .gallery {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
    gap: 1.2rem;
    max-width: 1400px; margin: 0 auto;
  }}
  .card {{
    background: #16213e; border-radius: 8px;
    overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,.4);
  }}
  .card img {{
    width: 100%; display: block;
    image-rendering: pixelated;
    image-rendering: -moz-crisp-edges;
  }}
  .card .label {{
    padding: .5rem .8rem; font-size: .85rem;
    color: #a0a0c0;
  }}
  .card .label span {{ color: #7ec8e3; font-weight: 600; }}
</style>
</head>
<body>
<h1>VGA Frame Gallery &mdash; {test_name}</h1>
<div class="gallery">
{cards}
</div>
</body>
</html>
"""

CARD_TEMPLATE = """\
<div class="card">
  <img src="data:image/png;base64,{b64}" alt="Frame {idx}">
  <div class="label"><span>Frame {idx}</span> &mdash; {fname}</div>
</div>"""


def cmd_gallery(args):
    cards = []
    for i in range(args.frames):
        path = os.path.join(args.dir, f"vga_frame{i}.ppm")
        if not os.path.isfile(path):
            print(f"warning: {path} not found, skipping", file=sys.stderr)
            continue
        w, h, rgb = read_ppm(path)
        png = rgb_to_png(w, h, rgb)
        b64 = base64.b64encode(png).decode("ascii")
        cards.append(CARD_TEMPLATE.format(b64=b64, idx=i, fname=f"vga_frame{i}.ppm"))

    if not cards:
        print("error: no PPM frames found", file=sys.stderr)
        return 1

    html = HTML_TEMPLATE.format(test_name=args.name, cards="\n".join(cards))
    out = args.output or os.path.join(args.dir, "vga_gallery.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Wrote {out} ({len(html)} bytes, {len(cards)} frames)")
    return 0


def cmd_export(args):
    converted = 0
    for i in range(args.frames):
        ppm = os.path.join(args.dir, f"vga_frame{i}.ppm")
        if not os.path.isfile(ppm):
            continue
        out = os.path.join(args.dir, f"vga_frame{i}.png")
        ppm_to_png_file(ppm, out_path=out, force=args.force)
        converted += 1

    if converted == 0:
        print("error: no PPM frames found", file=sys.stderr)
        return 1

    print(f"Exported {converted} PNG file(s) to {args.dir}")
    return 0


def main():
    parser = argparse.ArgumentParser(description="VGA frame tools for simulation output")
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_gallery = subparsers.add_parser("gallery", help="Generate HTML gallery")
    p_gallery.add_argument("--frames", type=int, default=10, help="Number of frames to include")
    p_gallery.add_argument("--dir", default=".", help="Directory containing vga_frame*.ppm")
    p_gallery.add_argument("-o", "--output", default=None, help="Output HTML path")
    p_gallery.add_argument("--name", default="simulation", help="Test name for gallery title")

    p_export = subparsers.add_parser("export", help="Convert vga_frame*.ppm to PNG")
    p_export.add_argument("--frames", type=int, default=10, help="Max frame count to scan")
    p_export.add_argument("--dir", default=".", help="Directory containing vga_frame*.ppm")
    p_export.add_argument("--force", action="store_true", help="Regenerate PNGs even if up-to-date")

    args = parser.parse_args()

    if args.command == "gallery":
        return cmd_gallery(args)
    if args.command == "export":
        return cmd_export(args)
    return 1


if __name__ == "__main__":
    sys.exit(main() or 0)
