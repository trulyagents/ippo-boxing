# Draws the manga ink HUD pieces. Run: python make_hud_art.py (writes PNGs next to it)
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))
CREAM = (237, 228, 207, 255)
INK = (14, 13, 12, 255)
random.seed(7)

def rough_poly(points, jitter, step=14):
    """walks a polygon and wobbles every edge so it looks inked by hand"""
    out = []
    for i in range(len(points)):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % len(points)]
        n = max(1, int(math.dist((x0, y0), (x1, y1)) / step))
        for k in range(n):
            t = k / n
            out.append((x0 + (x1 - x0) * t + random.uniform(-jitter, jitter),
                        y0 + (y1 - y0) * t + random.uniform(-jitter, jitter)))
    return out

def spikes(cx, cy, rx, ry, count, inner, outer, start=0, end=2 * math.pi):
    pts = []
    for i in range(count * 2 + 1):
        a = start + (end - start) * i / (count * 2)
        r = (outer if i % 2 else inner) * random.uniform(0.75, 1.15)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    return pts

def speckle(d, box, n, color, rmax):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y, r = random.uniform(x0, x1), random.uniform(y0, y1), random.uniform(0.6, rmax)
        d.ellipse((x - r, y - r, x + r, y + r), fill=color)

def halftone(d, box, spacing, rmax, fade_to_right=True):
    x0, y0, x1, y1 = box
    y = y0
    row = 0
    while y < y1:
        x = x0 + (spacing / 2 if row % 2 else 0)
        while x < x1:
            t = (x - x0) / (x1 - x0)
            r = rmax * ((1 - t) if fade_to_right else t)
            if r > 0.5:
                d.ellipse((x - r, y - r, x + r, y + r), fill=INK)
            x += spacing
        y += spacing * 0.87
        row += 1

# panel: torn cream splash with spiky ink edges, halftone in the portrait corner
def panel():
    W, H = 1400, 520
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # spiky burst behind everything
    # thin torn-paper spikes poking out round the edge, cream with an ink rim
    for _ in range(70):
        side = random.random()
        # roots sit just inside the panel edge so the body covers them
        if side < 0.45:
            x = random.uniform(120, W - 160)
            y = 120 + (70 - 120) * (x - 70) / (W - 160) + 14
            dx, dy = 0, -1
        elif side < 0.8:
            x = random.uniform(120, W - 160)
            y = (H - 60) + ((H - 50) - (H - 60)) * (x - 40) / (W - 80) - 14
            dx, dy = 0, 1
        elif side < 0.9:
            x, y, dx, dy = 66, random.uniform(150, H - 110), -1, 0
        else:
            x, y, dx, dy = W - 66, random.uniform(110, H - 100), 1, 0
        length = random.uniform(34, 90)
        width = random.uniform(5, 14)
        lean = random.uniform(-0.6, 0.6)
        tipx = x + (dx + lean * dy) * length
        tipy = y + (dy + lean * dx) * length
        spike = [(x - width * (1 - abs(dx)), y - width * (1 - abs(dy))), (tipx, tipy), (x + width * (1 - abs(dx)), y + width * (1 - abs(dy)))]
        d.polygon(spike, fill=CREAM, outline=INK)
        d.line(spike, fill=INK, width=3)
    body = rough_poly([(70, 120), (W - 90, 70), (W - 40, H - 50), (40, H - 60)], 9)
    d.polygon(body, fill=CREAM)
    # ink border, drawn as a thick wobbly line
    d.line(body + [body[0]], fill=INK, width=9, joint="curve")
    halftone(d, (70, 110, 520, H - 70), 15, 6)
    speckle(d, (60, 90, W - 60, H - 60), 260, INK, 2.4)
    # a few dry brush streaks
    for _ in range(18):
        y = random.uniform(100, H - 80)
        x = random.uniform(500, W - 200)
        d.line([(x, y), (x + random.uniform(60, 220), y + random.uniform(-8, 8))], fill=(14, 13, 12, 90), width=random.randint(1, 3))
    img = img.filter(ImageFilter.SMOOTH_MORE)
    img.save(os.path.join(OUT, "panel.png"))

# name banner: black slanted brush stroke
def banner():
    W, H = 1000, 160
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stroke = rough_poly([(60, 18), (W - 20, 6), (W - 70, H - 14), (14, H - 22)], 6, 10)
    d.polygon(stroke, fill=INK)
    # frayed brush ends
    for _ in range(60):
        y = random.uniform(20, H - 25)
        d.line([(W - 60, y), (W - 60 + random.uniform(30, 90), y + random.uniform(-4, 4))], fill=INK, width=random.randint(2, 5))
        d.line([(30, y), (30 - random.uniform(10, 40), y + random.uniform(-3, 3))], fill=INK, width=random.randint(1, 4))
    img.save(os.path.join(OUT, "banner.png"))

# label tag: slanted cream ticket with ink outline
def tag():
    W, H = 320, 96
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shape = [(28, 6), (W - 6, 6), (W - 30, H - 6), (6, H - 6)]
    d.polygon(rough_poly(shape, 1.5, 12), fill=CREAM, outline=INK)
    d.line(shape + [shape[0]], fill=INK, width=7)
    speckle(d, (20, 14, W - 20, H - 14), 40, (14, 13, 12, 140), 1.6)
    img.save(os.path.join(OUT, "tag.png"))

# bar track: dark channel, ink outline, cream inner rim, arrow tip on the right
def track():
    W, H = 1000, 72
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tip = 40
    outer = [(4, 4), (W - tip, 4), (W - 4, H / 2), (W - tip, H - 4), (4, H - 4)]
    d.polygon(outer, fill=INK)
    inner = [(14, 13), (W - tip - 6, 13), (W - 22, H / 2), (W - tip - 6, H - 13), (14, H - 13)]
    d.polygon(inner, fill=(30, 29, 28, 255), outline=CREAM)
    d.line(inner + [inner[0]], fill=CREAM, width=3)
    img.save(os.path.join(OUT, "track.png"))

# bar fill: white with ink grain so the tint gets texture, stretched across the bar
def fill():
    W, H = 512, 48
    img = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    for _ in range(1600):
        x, y = random.uniform(0, W), random.uniform(0, H)
        g = random.randint(150, 225)
        d.point((x, y), fill=(g, g, g, 255))
    for _ in range(70):
        y = random.uniform(0, H)
        x = random.uniform(0, W)
        d.line([(x, y), (x + random.uniform(10, 60), y)], fill=(205, 205, 205, 255), width=1)
    # darker bottom edge for a bit of depth
    for y in range(H - 8, H):
        a = int(70 * (y - (H - 8)) / 8)
        d.line([(0, y), (W, y)], fill=(0, 0, 0, a))
    img.save(os.path.join(OUT, "fill.png"))

# fill tip: the arrow point that rides on the end of each bar, same grain as the fill
def tip():
    W, H = 48, 96
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([(0, 0), (W - 1, H / 2), (0, H - 1)], fill=255)
    grain = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    d = ImageDraw.Draw(grain)
    for _ in range(140):
        x, y = random.uniform(0, W), random.uniform(0, H)
        g = random.randint(150, 225)
        d.point((x, y), fill=(g, g, g, 255))
    img.paste(grain, (0, 0), mask)
    img.save(os.path.join(OUT, "tip.png"))

for f in (panel, banner, tag, track, fill):
    f()
tip()
print("done")
