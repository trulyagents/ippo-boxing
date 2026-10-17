"""Roblox Open Cloud uploads using the key in the repo's .env (ROBLOX_API_KEY, ROBLOX_USER_ID)."""
import json, os, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def env():
    path = os.path.join(ROOT, ".env")
    if not os.path.exists(path):
        raise SystemExit("no .env in the repo root, copy it over from the other machine (see SETUP.md)")
    values = {}
    for line in open(path, encoding="utf-8"):
        if "=" in line:
            k, v = line.strip().split("=", 1)
            values[k] = v
    return values


def _curl(args):
    return subprocess.run(["curl", "-s"] + args, capture_output=True, text=True).stdout


def upload(path, asset_type, name, content_type):
    """uploads one file and waits for it. returns (asset id, moderation state)"""
    e = env()
    key, user = e["ROBLOX_API_KEY"], e["ROBLOX_USER_ID"]
    request = json.dumps({
        "assetType": asset_type,
        "displayName": name,
        "description": "",
        "creationContext": {"creator": {"userId": user}},
    })
    out = _curl([
        "-X", "POST", "https://apis.roblox.com/assets/v1/assets",
        "-H", "x-api-key: " + key,
        "-F", "request=" + request,
        "-F", "fileContent=@" + path + ";type=" + content_type,
    ])
    try:
        op = json.loads(out)["operationId"]
    except Exception:
        raise SystemExit("upload failed for " + path + ": " + out[:300])
    for _ in range(40):
        time.sleep(2)
        r = json.loads(_curl(["https://apis.roblox.com/assets/v1/operations/" + op, "-H", "x-api-key: " + key]))
        if r.get("done"):
            res = r["response"]
            return res["assetId"], res.get("moderationResult", {}).get("moderationState")
    raise SystemExit("timed out waiting on " + path)
