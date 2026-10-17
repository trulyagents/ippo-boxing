"""Pull one model/folder out of a place file into its own .rbxmx, carrying the SharedStrings
(union and mesh data) it needs and dropping any scripts.

  python tools/pull_model.py "place.rbxlx" Workspace/Map/EnterableBuildings/KamogawaGym build/Gym.rbxmx [NewName]"""
import re, sys
import xml.etree.ElementTree as ET

SCRIPTS = {"Script", "LocalScript", "ModuleScript"}


def prop(it, n):
    p = it.find("Properties")
    for c in (p if p is not None else []):
        if c.get("name") == n:
            return c


def name_of(it):
    c = prop(it, "Name")
    return (c.text or "") if c is not None else ""


src, path, out = sys.argv[1], sys.argv[2].split("/"), sys.argv[3]
new_name = sys.argv[4] if len(sys.argv) > 4 else None
root = ET.parse(src).getroot()
node = root
for part in path:
    node = next(ch for ch in node.findall("Item") if name_of(ch) == part)

removed = 0
for parent in list(node.iter("Item")):
    for ch in list(parent.findall("Item")):
        if ch.get("class") in SCRIPTS:
            parent.remove(ch)
            removed += 1
if new_name:
    prop(node, "Name").text = new_name

text = ET.tostring(node, encoding="unicode")
needed = set(re.findall(r'<SharedString name="[^"]*">([^<]+)</SharedString>', text))
shared = root.find("SharedStrings")
strings = []
if shared is not None:
    for s in shared.findall("SharedString"):
        if s.get("md5") in needed:
            strings.append(ET.tostring(s, encoding="unicode"))
doc = '<roblox version="4">\n' + text + "\n<SharedStrings>\n" + "\n".join(strings) + "\n</SharedStrings>\n</roblox>\n"
open(out, "w", encoding="utf-8").write(doc)
print(f"wrote {out}: {len(list(node.iter('Item')))} instances, {len(strings)}/{len(needed)} shared strings, {removed} scripts removed")
