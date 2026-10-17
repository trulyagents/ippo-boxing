"""Publish KeyframeSequence .rbxmx files as animations.

  python tools/publish_anims.py path/to/Jab.rbxmx path/to/Hook.rbxmx ...

prints Role = "rbxassetid://..." lines ready to paste into src/shared/AnimIds.luau
(the role is the file name without .rbxmx)."""
import os, sys
from opencloud import upload

for path in sys.argv[1:]:
    role = os.path.splitext(os.path.basename(path))[0]
    asset, state = upload(path, "Animation", "Boxing " + role, "model/x-rbxm")
    print(f'\t{role} = "rbxassetid://{asset}", -- {state}')
