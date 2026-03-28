import glob
import os
import sys

FB_WIDTH = 320
FB_HEIGHT = 240
VGA_WIDTH = 640
VGA_HEIGHT = 480


def read_ppm(path):
    with open(path, "rb") as f:
        magic = f.readline().strip()
        dims = f.readline().strip()
        maxval = f.readline().strip()
        data = f.read()

    if magic != b"P6":
        raise ValueError(f"Unsupported PPM magic: {magic!r}")
    if dims != b"640 480":
        raise ValueError(f"Unexpected PPM size: {dims!r}")
    if maxval != b"255":
        raise ValueError(f"Unexpected PPM max value: {maxval!r}")
    return data


def rgb332(r, g, b):
    return ((r & 0x7) << 5) | ((g & 0x7) << 2) | (b & 0x3)


def expected_fb_pixel(x, y):
    if x < 8 or x >= FB_WIDTH - 8 or y < 8 or y >= FB_HEIGHT - 8:
        return rgb332(7, 7, 3)
    if 96 < x < 224 and 72 < y < 168:
        return rgb332(7, 1, 0)
    return rgb332(x >> 5, y >> 5, (x ^ y) >> 7)


def rgb332_to_capture_rgb(pixel):
    r4 = ((pixel >> 5) & 0x7) << 1 | ((pixel >> 7) & 0x1)
    g4 = ((pixel >> 2) & 0x7) << 1 | ((pixel >> 4) & 0x1)
    b2 = pixel & 0x3
    b4 = (b2 << 2) | b2
    return ((r4 << 4) | r4, (g4 << 4) | g4, (b4 << 4) | b4)


def ppm_pixel(data, x, y):
    off = (y * VGA_WIDTH + x) * 3
    return data[off], data[off + 1], data[off + 2]


def check_block(data, fx, fy):
    expected = rgb332_to_capture_rgb(expected_fb_pixel(fx, fy))
    coords = [
        (2 * fx + 0, 2 * fy + 0),
        (2 * fx + 1, 2 * fy + 0),
        (2 * fx + 0, 2 * fy + 1),
        (2 * fx + 1, 2 * fy + 1),
    ]
    for vx, vy in coords:
        actual = ppm_pixel(data, vx, vy)
        if actual != expected:
            raise AssertionError(
                f"Pixel mismatch at VGA({vx},{vy}) for FB({fx},{fy}): "
                f"got={actual} exp={expected}"
            )


def check_diversity(data):
    samples = []
    for fy in range(8, FB_HEIGHT - 8, 24):
        for fx in range(8, FB_WIDTH - 8, 24):
            samples.append(ppm_pixel(data, 2 * fx, 2 * fy))

    unique = len(set(samples))
    dominant = max(samples.count(color) for color in set(samples))
    if unique < 12:
        raise AssertionError(f"Frame has too little colour diversity: unique={unique}")
    if dominant * 100 > len(samples) * 70:
        raise AssertionError(
            f"Frame is too close to a solid colour: dominant={dominant}/{len(samples)}"
        )


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        frames = sorted(
            glob.glob("vga_frame*.ppm"),
            key=lambda path: int(os.path.splitext(os.path.basename(path))[0].split("frame")[1])
        )
        if not frames:
            raise FileNotFoundError("No vga_frame*.ppm files found")
        path = frames[-1]

    data = read_ppm(path)

    sample_points = [
        (1, 1),
        (4, 4),
        (20, 20),
        (50, 50),
        (120, 120),
        (200, 100),
        (280, 40),
    ]

    for fx, fy in sample_points:
        check_block(data, fx, fy)

    check_diversity(data)

    print("Frame validation PASS")
    print(f"Validated file: {os.path.basename(path)}")
    print(f"Validated {len(sample_points)} exact sample blocks and frame diversity checks")


if __name__ == "__main__":
    main()
