"""Pull the fight anims out of the bought place files into one .rbxmx per role.

  python tools/pull_anims.py --game2 "path/to/sold to trulyagents (2).rbxlx" --game1 "path/to/clean game 1.rbxlx" --out build/anims

game 1's file has a bad byte in it, use the cleaned copy. then publish with tools/publish_anims.py."""
import argparse, copy, os, re
import xml.etree.ElementTree as ET

# role: (file, rig folder or None, sequence name, loop, priority 0 idle / 1 movement / 2 action / 3 action2)
ROLES = {
    "Idle": ("game2", None, "OrthodoxStanceIdle", True, 0),
    "Guard": ("game2", None, "OrthodoxStance_Block", True, 2),
    "LowGuard": ("game1", "yeniohadiyorum", "low guard", True, 2),
    "Weave": ("game2", None, "Peek A Boo Stance", True, 1),
    "WalkForward": ("game2", None, "OrthodoxMove_Forward", True, 1),
    "WalkBack": ("game2", None, "OrthodoxMove_Backwards", True, 1),
    "WalkLeft": ("game2", None, "OrthodoxMove_Left", True, 1),
    "WalkRight": ("game2", None, "OrthodoxMove_Right", True, 1),
    "Jab": ("game2", None, "OrthodoxStance_Jab_Head", False, 3),
    "Cross": ("game2", None, "OrthodoxStance_RightStraight_Head", False, 3),
    "Hook": ("game2", None, "OrthodoxStance_RightHook", False, 3),
    "Uppercut": ("game2", None, "OrthodoxStance_UppercutRight", False, 3),
    "Body": ("game2", None, "OrthodoxStance_RightBodyBlow", False, 3),
    "SlipLeft": ("game2", None, "Orthodox_InfighterDash_Left", False, 3),
    "SlipRight": ("game2", None, "Orthodox_InfighterDash_Right", False, 3),
    "SlipDuck": ("game2", None, "OrthodoxStance_Weaves", False, 3),
    "SlipBack": ("game2", None, "OutboxerDash_Backwards", False, 3),
    "HitHeadLeft": ("game2", None, "HitHead_Left", False, 3),
    "HitHeadRight": ("game2", None, "HitHead_Right", False, 3),
    "HitHeadTop": ("game2", None, "HitHead_Top", False, 3),
    "HitBody": ("game2", None, "HitTorso_Bottom", False, 3),
    "BlockLeft": ("game2", None, "BlockHit_LeftArm_Left", False, 3),
    "BlockRight": ("game2", None, "BlockHit_RightArm_Right", False, 3),
    "Stunned": ("game2", None, "HitTorso_Top", False, 3),
    "DownFall": ("game2", None, "KnockDown_FallBackward", False, 3),
    "DownLoop": ("game2", None, "KnockDown_LoopBackward", True, 3),
    "KOFall": ("game2", None, "KnockOut_FallBackward", False, 3),
    "KOLoop": ("game2", None, "KnockOut_LoopBackward", True, 3),
}


def prop(it, n):
    p = it.find("Properties")
    for c in (p if p is not None else []):
        if c.get("name") == n:
            return c


def name_of(it):
    c = prop(it, "Name")
    return (c.text or "") if c is not None else ""


def find(root, rig, name):
    def walk(it, trail):
        for ch in it.findall("Item"):
            n = name_of(ch)
            if ch.get("class") == "KeyframeSequence" and n == name and (rig is None or rig in trail):
                return ch
            r = walk(ch, trail + [n])
            if r is not None:
                return r

    return walk(root, [])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game2", required=True)
    ap.add_argument("--game1")
    ap.add_argument("--out", default="build/anims")
    ap.add_argument("roles", nargs="*", help="only these roles (default all)")
    a = ap.parse_args()
    trees = {"game2": ET.parse(a.game2).getroot()}
    if a.game1:
        trees["game1"] = ET.parse(a.game1).getroot()
    os.makedirs(a.out, exist_ok=True)
    for role, (src, rig, seq, loop, prio) in ROLES.items():
        if a.roles and role not in a.roles:
            continue
        if src not in trees:
            print("skip", role, "(needs --" + src + ")")
            continue
        found = find(trees[src], rig, seq)
        if found is None:
            print("missing", role, seq)
            continue
        ks = copy.deepcopy(found)
        prop(ks, "Name").text = role
        for n, tag, val in (("Loop", "bool", "true" if loop else "false"), ("Priority", "token", str(prio))):
            c = prop(ks, n)
            if c is None:
                c = ET.SubElement(ks.find("Properties"), tag, {"name": n})
            c.text = val
        root = ET.Element("roblox", {"version": "4"})
        root.append(ks)
        text = ET.tostring(root, encoding="unicode")
        counter = [0]

        def ref(_):
            counter[0] += 1
            return f'referent="R{counter[0]}"'

        text = re.sub(r'referent="[^"]+"', ref, text)
        open(os.path.join(a.out, role + ".rbxmx"), "w", encoding="utf-8").write(text)
        print("wrote", role)


main()
