# setup on a new machine

i work on this from my home pc and my laptop. code goes through github, the place itself goes through roblox.

## once per machine
1. install: git, github cli (`gh`), rokit, python 3 (`pip install pillow` if i'll redraw the hud art), roblox studio
2. `gh auth login`
3. clone it: `gh repo clone trulyagents/ippo-boxing "<Desktop>/Ippo Boxing"`
4. in that folder: `rokit install` (gets rojo, lune, selene, stylua, wally). if it says a tool isn't trusted: `rokit trust rojo-rbx/rojo lune-org/lune JohnnyMorganz/StyLua Kampfkarren/selene UpliftGames/wally` then `rokit install` again
5. studio: install the rojo plugin (`rojo plugin install`)
6. copy `.env` over from the other machine by hand (usb, note to myself, whatever). it's the roblox api key, never in git. `.env.example` shows the format

## every session
1. `git pull`
2. open "Ippo Project" in studio from the cloud (Recent / My Experiences), not a local file
3. `rojo serve` in this folder, connect in the rojo plugin. check the plugin says SecondWindBoxing, not MyGame (that's home invasion)
4. work. commit + push code. in studio ctrl+s saves the place to roblox, do that before leaving
5. if i changed a gui in studio: right click it > Save / Export > Save to File (xml .rbxmx) over the copy in `ui/`, then commit

## switching machines
- push + save to roblox on the one i'm leaving, `git pull` + reopen the place on the other
- don't have studio open on both at once, the last ctrl+s wins

## what lives where
- code, notes, ui copies, art, tools: github
- ring, spawns, anim sequences, hud, glove meshes, sounds: the place on roblox
- api key: `.env`, copied by hand
- the bought place files (for pulling anims): only on the home pc, Downloads
