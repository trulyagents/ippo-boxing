# combat

server decides every hit (Fighters module). client only sends "Punch Jab", "Guard true", "Slip Left", "GetUp", "Reset". rate limited 14/s

fighters
- players and dummies are both Fighters. state lives in attributes on the character: Health, Stamina, Guard, State, Guarding, Action/ActionStart/ActionToken, DownCount, GetUpProgress
- R6 forced: CombatServer builds each player from their avatar with CreateHumanoidModelFromDescription(R6). CharacterAutoLoads is off
- roblox health is set to huge, boxing uses its own Health

moves (CombatConfig)
- jab, cross, hook, uppercut, body. each has startup, recovery, damage, stamina cost, guard damage, range, hitstun
- getting hit during wind up cancels your punch
- under 20 stamina you're gassed, punches 1.4x slower
- input buffer 0.3s, a punch pressed at the end of a slip/punch still comes out

defence
- guard (F): blocks straights fully, hooks chip 40% through, body shots chip 60% and still drain stamina. guard meter breaks at 0 = 1.2s stun
- slips (Space, +A/D left right, +S back, alone = duck): 0.35s. left/right dodge straights, duck dodges hooks, back dodges almost everything. uppercut punishes a duck
- clean slip = 0.7s counter window, next punch x1.6

knockdowns
- health 0 = down, 10 count, mash Space to get up (8/14/20 presses). get up with 60/40/25 health
- 3rd knockdown or counted out = KO. Enter resets you

client
- FighterAnimator: procedural R6 poses from attributes (stance, guard, chamber > punch, slips, stunned, down). starter only, real animations later
- CombatInput: binds + lock-on (T, not Tab, roblox eats Tab)
- CombatHUD: bars, callouts, ref count, sounds (ReplicatedStorage.BoxingSounds, made in studio), screen shake

dummies
- Punching Bag Dummy covers up sometimes, never punches
- Sparring Partner walks in, punches about every 1.1-2.2s, slips 30% / guards 35% when you wind up

ring + dummies spawn points are in the place (workspace.Ring), not in src

feel (all client side, server never slows down)
- Feel module = shared hitstop / slowmo clock + hit reactions. animator multiplies its blend speed by Feel.scale()
- ImpactFX: star + sparks + sweat + shockwave ring + white highlight flash at the contact point. gold on counters, blue on blocks
- hitstop: jab 0.03, other clean hits 0.055, guard break 0.08, counter 0.09
- counter you're in: slowmo 0.45s at 0.3x, black and white impact frame, fov kick
- knockdown within 45 studs: slowmo 1.1s, strong impact frame, orbit camera cut on the fighter going down. KO = longer + desaturated
- reactions: jab/cross head snaps back, hook whips sideways, uppercut throws the head up, body folds you over, blocks knock the gloves back
- punches step forward with body weight and snap out at speed 70, pull back slower so they feel heavy
