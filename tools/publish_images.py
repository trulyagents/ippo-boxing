"""Publish PNGs as decals.

  python tools/publish_images.py art/hud/panel.png art/hud/tip.png ...

these are DECAL ids. an ImageLabel needs the image inside the decal, get it in studio with:
  game:GetService("InsertService"):LoadAsset(DECAL_ID):FindFirstChildWhichIsA("Decal", true).Texture"""
import os, sys
from opencloud import upload

for path in sys.argv[1:]:
    name = os.path.splitext(os.path.basename(path))[0]
    asset, state = upload(path, "Decal", "Boxing " + name, "image/png")
    print(f"{name}: decal {asset} ({state})")
