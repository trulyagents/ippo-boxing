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
- guard (F) has a height from camera pitch: looking down past -25 deg = low, else high. while locked on the mouse moves a pretend pitch (and tips the cam a bit)
- high guard: blocks head shots (straights fully, hooks chip 40%). low guard: blocks body shots fully, half stamina drain. wrong height = "Open" hit, clean, head shots +10% on a low guard
- switching heights takes 0.12s with no block, raising from nothing is instant
- weave mode: hold space (walk 6). A/D slip left/right, W duck, S pull back. slips only work in weave mode for players, dummies skip that
- slips 0.35s i-frames, 0.45s cooldown in weave mode, 10 stamina +3 per chained slip inside 1.5s. left/right dodge straights, duck dodges hooks, back dodges almost everything. uppercut punishes a duck. body shots only get dodged by back
- guard bobbing: slip with F held = 0.12s i-frames, keeps the guard, 6 stamina, no counter window
- sparring partner and bag guard high or low depending on where they got hit last
- clean slip = 0.7s counter window, next punch x1.6

knockdowns
- health 0 = down, 10 count, mash Space to get up (8/14/20 presses). get up with 60/40/25 health
- 3rd knockdown or counted out = KO. Enter resets you

client
- LowGuard anim is g1's "low guard" (one pose, i added an end keyframe so it loops), Weave is g2's peek a boo stance bob
- FighterAnimator: plays keyframed anims from ReplicatedStorage.BoxingAnims (bought game 2's set, renamed by role: Idle, Guard, Walk*, Jab, Cross, Hook, Uppercut, Body, Slip*, HitHead*, HitBody, Block*, Stunned, DownFall/Loop, KOFall/Loop). code poses are gone
- each punch anim has an Impact attribute (when the hand is furthest out). track speed = Impact / startup so the anim lands when the server lands the hit, and it skips ahead by however late the attribute arrived
- i animate my own character and the dummies. other players' tracks replicate from their own client, so i don't touch them
- hit reactions come from Feel.reactions, played at 1.8x since their hit anims are a second long
- walk anims blend by velocity in the fighter's facing space. the default Animate script gets disabled
- published ids go in Shared.AnimIds (one line per role). empty = registered on the fly, studio only
- all 28 published to my account through open cloud (assets api, assetType Animation, rbxmx file). they work in live servers now
- OriginalIds attribute on AnimIds: any id listed there is someone else's and gets skipped. empty now
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

gear
- gloves: copied the second example game's setup, not their meshes. each glove is 5 separate mesh parts (Glove fist, Thumb, Base cuff, Band_Upper and Band_Down laces) welded flat onto the arm with no rotation, barely wider than the arm. made in blender (models/glove/glove.blend), imported as ReplicatedStorage.BoxingGear.GloveParts. Gear.gloves sets sizes, offsets and colors in code, thumb mirrors to the body side on each arm
- the old one-piece ai glove looked bulky and weird, dont go back to it
- trunks: real catalog pants, "J. Parker Red White & Gold Boxing Shorts" by Ro-Boxing Apparel (template 17137655469). everyone wears them, players and dummies
- R6AnimRig in the ring wears both, for animating in the Animation Editor

animations
- no code-driven poses going forward, everything gets keyframed. both example games use R6 so we stay R6
- Jab KeyframeSequence in ServerStorage.BoxingAnimations and RBX_ANIMSAVES.R6AnimRig (Animation Editor > Load). lead (left) hand, impact marker at 0.05s, done at 0.2s. old slow one kept as Jab_v1
- what i took from the bought games' jabs (timing and ideas only, poses are mine): whole jab is 0.2s, impact on frame 3, 1 frame of anticipation, linear snap out then eased pull back. the arm translates forward from the shoulder, not just rotates. torso turns about 35 degrees into it and the head turns back the other way so the eyes stay on the target. a tiny over-extension right after impact
- CombatConfig Jab startup still needs matching to the 0.05 impact once anims are hooked in
- needs publishing from the Animation Editor before it works in a live server

bought anims
- the two bought games' anims are in ServerStorage.ReferenceAnims (BoxingGame2 = the clean boxing one, 99 anims. BoxingGame1 = its boxing rig plus the m1 chain, 29). copies in RBX_ANIMSAVES.R6AnimRig as G2_ / G1_ so they show in Animation Editor > Load
- renamed the ones named after ippo characters or moves to plain names (LungeUppercut, WeaveRoll, StepCounter, LeftBodyHook and so on)
- they're R6 and play fine on our rig. their rig also keys face parts we don't have, those just get ignored
- skipped junk (Automatic Save, tests, jump rope, mitts)
- still need publishing from the Animation Editor before they work in a live server
