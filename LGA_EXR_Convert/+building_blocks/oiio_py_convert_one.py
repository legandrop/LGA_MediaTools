#!/usr/bin/env python3
"""Convert one EXR to DWAA using OpenImageIO Python bindings."""

from __future__ import annotations

import sys
from pathlib import Path

import OpenImageIO as oiio


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: oiio_py_convert_one.py input.exr output.exr", file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    image = oiio.ImageBuf(str(src))
    if image.has_error:
        print(f"Could not read input: {src}: {image.geterror()}", file=sys.stderr)
        return 1

    spec = image.specmod()
    spec.attribute("compression", "dwaa:quality=60")
    spec.erase_attribute("Software")
    spec.erase_attribute("Exif:ImageHistory")
    image.set_write_format(spec.format)

    dst.parent.mkdir(parents=True, exist_ok=True)
    ok = image.write(str(dst), spec.format, "openexr")
    if not ok:
        print(f"Could not write output: {dst}: {image.geterror()}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
