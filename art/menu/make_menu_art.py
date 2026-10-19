# Draws the menu pieces in the same ink style as the hud. Run: python make_menu_art.py
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hud"))
from make_hud_art import CREAM, INK, rough_poly, speckle, halftone

OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(11)


# the big sheet the menu sits on: torn cream page, thick ink rim, halftone in a corner
def sheet():
    W, H = 1600, 1000
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body = rough_poly([(40, 60), (W - 30, 30), (W - 50, H - 40), (24, H - 30)], 7, 16)
    d.polygon(body, fill=CREAM)
    d.line(body + [body[0]], fill=INK, width=12, joint="curve")
    # halftone sits top left, under the title banner, so it never fights the text
    halftone(d, (50, 50, 560, 200), 16, 6.5)
    speckle(d, (50, 60, W - 60, H - 50), 380, INK, 2.2)
    img.filter(ImageFilter.SMOOTH_MORE).save(os.path.join(OUT, "sheet.png"))


# radar backing: 5 inked hexagon rings and 6 spokes, top spoke is the first stat
def radar():
    S = 900
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c, R = S / 2, S / 2 - 40
    corners = lambda r: [(c + r * math.sin(math.radians(60 * i)), c - r * math.cos(math.radians(60 * i))) for i in range(6)]
    d.polygon(rough_poly(corners(R), 2, 14), fill=(14, 13, 12, 28))
    for k in range(1, 6):
        pts = rough_poly(corners(R * k / 5), 1.2, 14)
        d.line(pts + [pts[0]], fill=INK, width=7 if k == 5 else 3)
    for x, y in corners(R):
        d.line([(c, c), (x, y)], fill=(14, 13, 12, 150), width=3)
    img.save(os.path.join(OUT, "radar.png"))


# style card: slanted cream ticket with a heavy ink rim and a halftone strip on the left
def card():
    W, H = 900, 520
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shape = rough_poly([(40, 12), (W - 10, 12), (W - 40, H - 12), (10, H - 12)], 3, 14)
    d.polygon(shape, fill=CREAM)
    d.line(shape + [shape[0]], fill=INK, width=10, joint="curve")
    halftone(d, (30, 30, 150, H - 30), 12, 4.5)
    speckle(d, (30, 30, W - 40, H - 30), 120, INK, 1.8)
    img.save(os.path.join(OUT, "card.png"))


# the corner menu button: ink burst with a cream square inside
def button():
    S = 256
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(32):
        a = 2 * math.pi * i / 32
        r = (S / 2 - 6) * (1 if i % 2 else random.uniform(0.78, 0.86))
        pts.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r))
    d.polygon(pts, fill=INK)
    inner = rough_poly([(62, 58), (S - 58, 62), (S - 62, S - 58), (58, S - 62)], 2, 10)
    d.polygon(inner, fill=CREAM)
    d.line(inner + [inner[0]], fill=INK, width=6)
    img.save(os.path.join(OUT, "button.png"))


# white right triangles the radar fill is built from, right angle bottom left and top left
def triangles():
    S = 256
    for name, pts in (("tri_bl", [(0, 0), (0, S), (S, S)]), ("tri_tl", [(0, 0), (S, 0), (0, S)])):
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(img).polygon(pts, fill=(255, 255, 255, 255))
        img.save(os.path.join(OUT, name + ".png"))


if __name__ == "__main__":
    triangles()
    for f in (sheet, radar, card, button):
        f()
    print("done")
