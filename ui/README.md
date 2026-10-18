# ui

copies of the GUIs that live in the place. the real thing is in Studio (StarterGui), these are just so it's in git.

- BoxingHUD.rbxmx = StarterGui.BoxingHUD, the fight hud (manga ink look)
- BoxingMenu.rbxmx = StarterGui.BoxingMenu, the M menu (stats radar, style cards, +1 training popup). art in art/menu
- art for it is in art/hud (make_hud_art.py draws it, uploaded as decals with the api key)
- after changing a gui in Studio: right click it > Save / Export > Save to File, XML (.rbxmx), over the file here
- or without clicking: run tools/export_gui.luau in studio (claude does it through mcp), save what it returns to a file, then `python tools/gui_to_rbxmx.py that_file ui/BoxingHUD.rbxmx`
- to restore one: right click StarterGui > Insert from File
