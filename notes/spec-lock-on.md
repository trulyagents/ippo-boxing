# spec: lock-on camera

step 3 of best-of-both. the camera that scales with distance is g1's idea (zoom 5 to 8, side offset distance/2 capped at 1.75). g2's lock-on was a 2015-style scriptable cam with fixed offsets, nothing to take from it

## how it works now
- T toggles lock on the nearest fighter in 30 studs, breaks past 39 or when they're KO
- camera fixed at 8.5 back, 4.5 to the side, 3.4 up, looking at the midpoint, lerp 0.25 a frame
- the body snaps to face the target every frame
- mouse locked to center, mouse up/down is a pretend pitch for high/low guard

## changes

### distance-scaled framing (g1)
- close (2-4 studs, trading): camera tighter, about 6 back and 2 to the side, so punches fill the screen
- mid (5-8, footwork range): about 8 back and 3.5 to the side
- far (8+): pulls back to about 10 so you can see them walk in
- height eases between 2.6 close and 3.4 far
- all of it smoothed by distance, no hard steps

### smoother follow
- lerp 0.25 a frame changes with fps. switch to a spring that uses dt, so 30fps and 240fps feel the same
- slow-mo and hitstop keep working because they don't touch the camera spring

### turn speed
- the body turns toward the target at up to 720 degrees a second instead of snapping
- so if someone circles behind you, you have to turn round and can get caught. still fast enough that normal footwork never feels laggy

### shoulder swap
- V swaps the camera to your other shoulder. handy when you're pinned on the ropes and the post is in the way

### switching targets
- scroll wheel while locked = next / previous fighter in range, sorted by angle from where you're facing
- T still turns it off

### walls and ropes
- raycast from the focus point to the camera. if a post, rope wall or the light rig is in the way, the camera pulls in in front of it
- ropes are thin enough that i'll ignore them, only posts and rope walls block

### lock marker
- small chevron over the locked target's head so you know who you're on, fades in when you lock

### small extras
- fov tightens a little (70 to 64) when you're within 3.5 studs, gives close trading more punch
- while you're down or ko the lock pauses, the knockdown cinematic still takes over like now

## not doing
- g1 writes the character cframe from the client too. that's normal on roblox for your own character, the server still checks the 63 degree hit cone, so i'm leaving facing on the client
- mobile lock button comes with the mobile controls pass later

## decided
- V and scroll kept, numbers meet in the middle of g1 and mine, auto lock waits for matchmaking
- built and tested, see combat.md
