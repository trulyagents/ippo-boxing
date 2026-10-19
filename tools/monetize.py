"""Create game passes and developer products on the experience with the Open Cloud key in .env.

  python tools/monetize.py pass "Glove Colors" "Every glove color" 99
  python tools/monetize.py product "Stat Respec" "Move your stat points around" 49

prints the new id. the key needs game-pass:write / developer-product:write on this universe."""
import json, sys
from opencloud import env, _curl

UNIVERSE = "10771287918"  # Second Wind Boxing (place 78626401443666)


def create(kind, name, description, price):
    key = env()["ROBLOX_API_KEY"]
    url = (
        f"https://apis.roblox.com/game-passes/v1/universes/{UNIVERSE}/game-passes"
        if kind == "pass"
        else f"https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE}/developer-products"
    )
    out = _curl([
        "-X", "POST", url,
        "-H", "x-api-key: " + key,
        "-F", "name=" + name,
        "-F", "description=" + description,
        "-F", "price=" + str(price),
        "-F", "isForSale=true",
    ])
    return out


if __name__ == "__main__":
    kind, name, description, price = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
    out = create(kind, name, description, price)
    try:
        data = json.loads(out)
    except ValueError:
        raise SystemExit("unexpected reply: " + out[:400])
    print(json.dumps(data, indent=1)[:800])
