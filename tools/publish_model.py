"""Upload .rbxmx models as private Models (gets them into studio with InsertService:LoadAsset,
no clicking, unions and meshes intact).

  python tools/publish_model.py build/Gym.rbxmx ..."""
import os, sys
from opencloud import upload

for path in sys.argv[1:]:
    name = os.path.splitext(os.path.basename(path))[0]
    asset, state = upload(path, "Model", "Boxing " + name, "model/x-rbxm")
    print(f"{name}: model {asset} ({state})")
