"""Comic finish for the store art: the blender renders (render_icon.png, render_thumb.png, both
with a see-through background) go over a red speed-line burst with halftone dots, then the title
in Bangers. Same ink + cream look as the hud.

  python art/promo/make_promo.py <path to Bangers-Regular.ttf>
"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = sys.argv[1]
INK = (20, 16, 14)
CREAM = (245, 236, 214)
random.seed(4)


def burst(w, h, centre, inner, outer):
    """dark red background with speed lines out from the centre and a halftone fade"""
    im = Image.new("RGB", (w, h), inner)
    d = ImageDraw.Draw(im)
    cx, cy = centre
    reach = math.hypot(w, h)
    for i in range(72):
        a = i / 72 * math.tau + random.uniform(-0.02, 0.02)
        spread = random.uniform(0.012, 0.03)
        pts = [(cx, cy), (cx + math.cos(a - spread) * reach, cy + math.sin(a - spread) * reach), (cx + math.cos(a + spread) * reach, cy + math.sin(a + spread) * reach)]
        d.polygon(pts, fill=outer if i % 2 else inner)
    # halftone dots that grow toward the edges
    dots = Image.new("L", (w, h), 0)
    dd = ImageDraw.Draw(dots)
    step = max(10, w // 70)
    for y in range(0, h, step):
        for x in range(0, w, step):
            r = (math.hypot(x - cx, y - cy) / reach) * step * 0.9
            if r > 1:
                dd.ellipse([x - r / 2, y - r / 2, x + r / 2, y + r / 2], fill=110)
    im.paste((0, 0, 0), mask=dots)
    # soft light behind the boxer
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([cx - w * 0.28, cy - h * 0.38, cx + w * 0.28, cy + h * 0.38], fill=170)
    glow = glow.filter(ImageFilter.GaussianBlur(w // 12))
    im = Image.composite(Image.new("RGB", (w, h), (255, 120, 60)), im, glow.point(lambda v: v // 2))
    return im


def outlined(d, xy, text, font, fill, stroke, anchor="mm"):
    d.text(xy, text, font=font, fill=fill, stroke_width=stroke, stroke_fill=INK, anchor=anchor)


def boxer(path, w, h, scale, offset):
    b = Image.open(os.path.join(HERE, path)).convert("RGBA")
    b = b.resize((int(b.width * scale), int(b.height * scale)), Image.LANCZOS)
    # ink outline around the boxer: a dilated black copy underneath
    a = b.split()[3]
    edge = a.filter(ImageFilter.MaxFilter(int(9 * scale) | 1))
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ink = Image.new("RGBA", b.size, INK + (255,))
    layer.paste(ink, offset, edge)
    layer.paste(b, offset, a)
    return layer


def icon():
    S = 1024
    im = burst(S, S, (S * 0.55, S * 0.45), (150, 18, 22), (95, 8, 14)).convert("RGBA")
    im.alpha_composite(boxer("render_icon.png", S, S, 1.15, (-90, -40)))
    d = ImageDraw.Draw(im)
    big = ImageFont.truetype(FONT, 190)
    small = ImageFont.truetype(FONT, 120)
    # title stacked bottom left, tilted a touch like a comic caption
    cap = Image.new("RGBA", (S, 420), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cap)
    outlined(cd, (S // 2, 120), "SECOND WIND", big, CREAM, 14)
    outlined(cd, (S // 2, 285), "BOXING", small, (255, 70, 50), 12)
    cap = cap.rotate(4, resample=Image.BICUBIC)
    im.alpha_composite(cap, (0, S - 430))
    # frame
    ImageDraw.Draw(im).rectangle([0, 0, S - 1, S - 1], outline=INK, width=26)
    im.convert("RGB").save(os.path.join(HERE, "icon.png"))


def thumbnail():
    W, H = 1920, 1080
    im = burst(W, H, (W * 0.42, H * 0.45), (150, 18, 22), (95, 8, 14)).convert("RGBA")
    im.alpha_composite(boxer("render_thumb.png", W, H, 1.0, (-120, 0)))
    d = ImageDraw.Draw(im)
    title = ImageFont.truetype(FONT, 230)
    sub = ImageFont.truetype(FONT, 110)
    tag = ImageFont.truetype(FONT, 62)
    outlined(d, (1450, 300), "SECOND", title, CREAM, 16)
    outlined(d, (1450, 520), "WIND", title, CREAM, 16)
    outlined(d, (1450, 700), "BOXING", sub, (255, 70, 50), 12)
    # a slanted "RANKED" tag
    t = Image.new("RGBA", (620, 150), (0, 0, 0, 0))
    td = ImageDraw.Draw(t)
    td.polygon([(20, 10), (600, 0), (590, 140), (0, 150)], fill=CREAM, outline=INK, width=8)
    outlined(td, (305, 76), "TRAIN. FIGHT. RANK UP.", tag, INK, 0)
    t = t.rotate(-4, resample=Image.BICUBIC, expand=True)
    im.alpha_composite(t, (1130, 820))
    ImageDraw.Draw(im).rectangle([0, 0, W - 1, H - 1], outline=INK, width=24)
    im.convert("RGB").save(os.path.join(HERE, "thumbnail.png"))


def pass_icon(name, title, sub, colour, draw):
    S = 512
    im = burst(S, S, (S / 2, S * 0.42), colour, tuple(max(0, c - 60) for c in colour)).convert("RGBA")
    d = ImageDraw.Draw(im)
    draw(d, S)
    outlined(d, (S / 2, S * 0.78), title, ImageFont.truetype(FONT, 92), CREAM, 9)
    if sub:
        outlined(d, (S / 2, S * 0.91), sub, ImageFont.truetype(FONT, 48), (255, 210, 90), 6)
    d.rectangle([0, 0, S - 1, S - 1], outline=INK, width=16)
    im.convert("RGB").save(os.path.join(HERE, name + ".png"))


def glove(d, cx, cy, r, colour):
    d.rounded_rectangle([cx - r, cy - r, cx + r, cy + r * 0.9], radius=int(r * 0.45), fill=colour, outline=INK, width=10)
    d.rounded_rectangle([cx + r * 0.55, cy - r * 0.35, cx + r * 1.05, cy + r * 0.45], radius=int(r * 0.25), fill=colour, outline=INK, width=8)
    d.rectangle([cx - r * 0.9, cy + r * 0.9, cx + r * 0.9, cy + r * 1.35], fill=colour, outline=INK, width=8)
    d.rectangle([cx - r * 0.9, cy + r * 1.0, cx + r * 0.9, cy + r * 1.1], fill=CREAM)


def passes():
    def gloves(d, S):
        for i, c in enumerate([(150, 18, 18), (25, 60, 150), (28, 26, 26), (196, 150, 40)]):
            glove(d, 95 + i * 108, 165 + (i % 2) * 30, 48, c)

    def ko(d, S):
        pts = []
        for i in range(24):
            a = i / 24 * math.tau
            r = 190 if i % 2 else 120
            pts.append((S / 2 + math.cos(a) * r, S * 0.38 + math.sin(a) * r))
        d.polygon(pts, fill=(255, 210, 60), outline=INK, width=10)
        outlined(d, (S / 2, S * 0.38), "K.O.!", ImageFont.truetype(FONT, 130), (230, 30, 30), 10)

    def vip(d, S):
        crown = [(130, 280), (150, 130), (210, 210), (256, 100), (302, 210), (362, 130), (382, 280)]
        d.polygon(crown, fill=(230, 180, 40), outline=INK, width=12)
        for x in (150, 256, 362):
            d.ellipse([x - 18, 112 if x != 256 else 82, x + 18, 148 if x != 256 else 118], fill=(230, 30, 30), outline=INK, width=6)

    def respec(d, S):
        f = ImageFont.truetype(FONT, 150)
        outlined(d, (S / 2 - 70, S * 0.36), "+", f, (120, 230, 120), 10)
        outlined(d, (S / 2 + 70, S * 0.36), "-", f, (255, 120, 90), 10)

    pass_icon("pass_gloves", "GLOVE COLORS", "", (150, 18, 22), gloves)
    pass_icon("pass_ko", "KO EFFECT", "", (40, 40, 110), ko)
    pass_icon("pass_vip", "VIP", "GOLD NAME + DAILY BONUS", (120, 80, 10), vip)
    pass_icon("product_respec", "STAT RESPEC", "MOVE YOUR POINTS", (20, 90, 60), respec)


if __name__ == "__main__":
    icon()
    thumbnail()
    passes()
    print("icon.png, thumbnail.png, 4 pass icons")
