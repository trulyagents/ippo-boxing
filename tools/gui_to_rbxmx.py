"""Turns a GUI dump from tools/export_gui.luau into an .rbxmx you can commit or Insert from File.

  python tools/gui_to_rbxmx.py dump.txt ui/BoxingHUD.rbxmx

the dump is what export_gui.luau returns (it starts with "<length>|" then json). used when studio's
right click > Save to File isn't an option (no window focus)."""
import json, sys
from xml.sax.saxutils import escape

INTS = {"ZIndex", "LayoutOrder", "BorderSizePixel", "MaxTextSize", "MinTextSize", "DisplayOrder"}


CONTENT = {"Image"}


def num(x):
    # studio's JSONEncode turns math.huge into {"t": "numeric", "v": "inf"}
    if isinstance(x, dict):
        v = str(x.get("v", "")).lower()
        return "-INF" if v.startswith("-") else ("NAN" if "nan" in v else "INF")
    return x


def prop(name, kind, v):
    if name in CONTENT:
        return f'<Content name="{name}"><url>{escape(str(v[0]))}</url></Content>'
    if kind == "string":
        return f'<string name="{name}">{escape(v[0])}</string>'
    if kind == "boolean":
        return f'<bool name="{name}">{"true" if v[0] else "false"}</bool>'
    if kind == "number":
        tag = "int" if name in INTS else "float"
        n = num(v[0])
        if tag == "int" and not isinstance(n, str):
            n = int(n)
        return f'<{tag} name="{name}">{n}</{tag}>'
    if kind == "UDim2":
        xs, xo, ys, yo = v
        return f'<UDim2 name="{name}"><XS>{xs}</XS><XO>{int(xo)}</XO><YS>{ys}</YS><YO>{int(yo)}</YO></UDim2>'
    if kind == "UDim":
        return f'<UDim name="{name}"><S>{v[0]}</S><O>{int(v[1])}</O></UDim>'
    if kind == "Vector2":
        return f'<Vector2 name="{name}"><X>{num(v[0])}</X><Y>{num(v[1])}</Y></Vector2>'
    if kind == "Color3":
        return f'<Color3 name="{name}"><R>{v[0]}</R><G>{v[1]}</G><B>{v[2]}</B></Color3>'
    if kind == "Enum":
        return f'<token name="{name}">{int(v[0])}</token>'
    if kind == "Font":
        return (f'<Font name="{name}"><Family><url>{escape(v[0])}</url></Family>'
                f'<Weight>{int(v[1])}</Weight><Style>{v[2]}</Style></Font>')
    if kind == "Content":
        return f'<Content name="{name}"><url>{escape(v[0])}</url></Content>'
    return ""


def main(src, out):
    raw = open(src, encoding="utf-8").read().strip()
    if "|" in raw[:20]:
        raw = raw.split("|", 1)[1]
    nodes = json.loads(raw)
    kids = {}
    for n in nodes:
        kids.setdefault(n["parent"], []).append(n)

    def emit(n, depth):
        pad = "\t" * depth
        lines = [f'{pad}<Item class="{n["class"]}" referent="RBX{n["id"]:05d}">', f"{pad}\t<Properties>"]
        for name, val in sorted(n["props"].items()):
            # Transparency on gui objects is just the old alias for BackgroundTransparency
            if name == "Transparency" and n["class"] != "UIStroke":
                continue
            p = prop(name, val[0], val[1:])
            if p:
                lines.append(f"{pad}\t\t{p}")
        lines.append(f"{pad}\t</Properties>")
        for c in kids.get(n["id"], []):
            lines += emit(c, depth + 1)
        lines.append(f"{pad}</Item>")
        return lines

    body = ['<roblox version="4">']
    for root in kids.get(0, []):
        body += emit(root, 1)
    body.append("</roblox>")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(body) + "\n")
    print("wrote", out, len(nodes), "instances")


main(sys.argv[1], sys.argv[2])
