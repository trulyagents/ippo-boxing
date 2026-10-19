# Seven segment LED digits for the gym's interval timer (yellow on black like g2's 0).
# Run: python make_digits.py, writes digit_0.png .. digit_9.png next to it
import os
from PIL import Image, ImageDraw

OUT = os.path.dirname(os.path.abspath(__file__))
W, H = 228, 200  # same shape as the digit parts (2.32 x 2.03)
LIT = (255, 214, 40, 255)
DIM = (0, 0, 0, 0)  # unlit segments off, the gym lights brighten decals so even faint ones read as lit
SEGMENTS = {  # a top, b top right, c bottom right, d bottom, e bottom left, f top left, g middle
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
    "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}


def shapes():
    t = 22  # segment thickness
    x0, x1 = 60, 168
    y0, ym, y1 = 18, H // 2, H - 18
    s = 6  # slant to the right going up
    def horiz(y):
        return [(x0 + 8, y - t / 2), (x1 - 8, y - t / 2), (x1 + 4, y), (x1 - 8, y + t / 2), (x0 + 8, y + t / 2), (x0 - 4, y)]
    def vert(x, ya, yb):
        return [(x, ya + 6), (x + t / 2, ya + 16), (x + t / 2, yb - 16), (x, yb - 6), (x - t / 2, yb - 16), (x - t / 2, ya + 16)]
    def lean(pts):
        return [(px + s * (1 - py / H) * 2, py) for px, py in pts]
    return {
        "a": lean(horiz(y0)), "g": lean(horiz(ym)), "d": lean(horiz(y1)),
        "f": lean(vert(x0, y0, ym)), "b": lean(vert(x1, y0, ym)),
        "e": lean(vert(x0, ym, y1)), "c": lean(vert(x1, ym, y1)),
    }


def main():
    seg = shapes()
    for digit, lit in SEGMENTS.items():
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for name, pts in seg.items():
            d.polygon(pts, fill=LIT if name in lit else DIM)
        img.save(os.path.join(OUT, f"digit_{digit}.png"))
    print("done")


if __name__ == "__main__":
    main()
