# combat

server decides every hit (Fighters module). client only sends "Punch Jab", "Guard true", "Slip Left", "GetUp", "Reset". rate limited 14/s

fighters
- players and dummies are both Fighters. state lives in attributes on the character: Health, Stamina, Guard, State, Guarding, Action/ActionStart/ActionToken, DownCount, GetUpProgress
- R6 forced: CombatServer builds each player from their avatar with CreateHumanoidModelFromDescription(R6). CharacterAutoLoads is off
- roblox health is set to huge, boxing uses its own Health
- walk speed 10, guarding 6, weaving 5 (was 13/8/6, felt too fast)
- no jumping: JumpPower/JumpHeight 0 on the server and the Jumping state off on the client (space is weave mode)

moves (CombatConfig)
- jab, cross, hook, uppercut, body. each has startup, recovery, damage, stamina cost, guard damage, range, hitstun
- getting hit during wind up cancels your punch
- you plant your feet to punch: walk speed while throwing = MoveSpeed per move (jab 6, cross/hook 2, body/uppercut 1). when it fires you slide forward Step for 0.12s (about jab 0.5, cross 1.2, body 1, hook 0.7, uppercut 0.8 studs). players push on their own client when State flips to Recovery, dummies on the server. impulses/velocity got eaten by the humanoid so it moves the root cframe
- under 20 stamina you're gassed, punches 1.4x slower
- under 20 the stamina bar throbs red. a punch you can't afford sends "Gassed" to just you (max every 0.6s): NO STAMINA callout + the bar flashes
- input buffer 0.3s, a punch pressed at the end of a slip/punch still comes out

defence
- guard (F) has a height from camera pitch: looking down past -25 deg = low, else high. while locked on the mouse moves a pretend pitch (and tips the cam a bit)
- high guard: blocks head shots (straights fully, hooks chip 40%). low guard: blocks body shots fully, half stamina drain. wrong height = "Open" hit, clean, head shots +10% on a low guard
- switching heights takes 0.12s with no block, raising from nothing is instant
- weave mode: hold space (walk 5). A/D slip left/right, W duck, S pull back. slips only work in weave mode for players, dummies skip that
- slips 0.35s i-frames, 0.45s cooldown in weave mode, 10 stamina +3 per chained slip inside 1.5s. left/right dodge straights, duck dodges hooks, back dodges almost everything. uppercut punishes a duck. body shots only get dodged by back
- guard bobbing: slip with F held = 0.12s i-frames, keeps the guard, 6 stamina, no counter window
- sparring partner and bag guard high or low depending on where they got hit last
- clean slip = 0.7s counter window, next punch x1.6
- read counters: your punch lands while theirs is winding up. cross into jab/cross = CROSS COUNTER 2x, hook into cross 1.7x, uppercut into hook = INSIDE 1.8x, body into uppercut 1.5x + double drain, anything else = STOP 1.2x. table is CombatConfig.Counters
- cross counter on someone under 35 health = knockdown
- PUNISHED 1.3x: hitting someone recovering from a whiff (or a slipped punch)
- parry: fresh F press (guard down 0.6s first) within 0.15s of a jab/cross landing, high guard. no damage, attacker stunned 0.65s, you get 0.5s counter window at 1.4x, costs 4 stamina. holding guard just blocks
- hit broadcast has the counter name as the 7th arg, hud shouts it, cross counter gets the strong impact frame
- sparring partner parries ~20% of your straights, decides once per punch (ActionToken)
- dummies cover up on reflex with setGuard(f, h, false) so it can't parry. without that every reactive guard vs a jab was a parry (jab wind up 0.12 is inside the 0.15 window), partner parried 20 jabs in 45s
- studio only test hooks on dummies: TestFreeze, TestPunch, TestGuard attributes

knockdowns
- health 0 = down, 10 count, mash Space to get up (8/14/20 presses). get up with 60/40/25 health
- 3rd knockdown or counted out = KO. Enter resets you
- lasting damage: clean head shots and counters take 20% of their damage off MaxHealthNow (floor 50). health regens 2/s after 3s unhit, only up to MaxHealthNow. get-up health is min(60/40/25, MaxHealthNow)
- courage 0-100: +3 clean landed, +8 counter, +4 slip, +6 parry, +15 knocked down, +10 got up, -2 clean taken
- second wind: rolled at the knockdown (not on the 3rd, that's straight KO), once per fight. 5/15/35/70% by courage tiers, 100 = guaranteed. up after 1.2s, +20 max health, 70% of it as health, full stamina, courage to 0, 8s fired up (stamina regen x2, wind up x0.9, guard damage x0.75)
- second wind fx: steam + sparks aura for 8s, slow-mo + impact frame, warm screen tint for you, SECOND WIND! callout, an inner thought line (CombatConfig.SecondWindLines) only for you
- no bars on the opponent, just their name. you read them off their body instead:
  - under 35% health (HurtBelow) = Hurt loop, side to side wobble with the head heavy
  - under 20 stamina = Gassed loop, heavy breathing leaning over with the guard sagging, plus sweat dripping off the head
  - both replace the idle (idle weight drops to ~0), hurt wins if both
  - they come off at a gap (gassed until 30 stamina, hurt until 43% health), first version flickered on and off at the line and looked like shaking
  - legs are counter-rotated against the torso lean so the feet stay exactly in the idle stance. first version leaned the whole body and the feet left the fight stance
- Hurt and Gassed are keyframed by me on top of the idle pose (bought games had no tired/hurt idle). built from a python script so the uploaded file matches studio exactly
- hud: health has a pale ghost that trails the hit and a dark end for max health lost, thin courage bar under guard that glows at 90+
- studio test hook TestCourage sets a dummy's courage
- studio only "TEST SECOND WIND" button bottom right: drops you at 100 courage so it always fires (server checks IsStudio)

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
- CombatInput: binds only. lock-on moved to its own LockOn module
- LockOn: T toggles (not Tab, roblox eats it), V swaps shoulder, scroll switches target by angle. mouse locked to center, set every frame since the camera scripts fight it
- framing by fighter distance, 3 to 9 studs: back 5.5-9, side 1.5-2.75, height 2.4-3.2. halfway between g1 (5-8 back, 1.75 side) and my old fixed 8.5/4.5
- dt spring (14) instead of lerp per frame, body turns at max 720 deg/s (a 180 takes 0.26s), fov 64 under 3.5 studs else 70 (writes BaseFov so the hit fov kick still works)
- camera raycasts focus to eye and pulls in at anything CanCollide, the rope walls are invisible but still count, keeps it inside the ring
- red chevron over the locked target
- auto lock-on (g1 does it when the server pairs you) comes with matchmaking
- CombatHUD: drives StarterGui.BoxingHUD (built in studio, copy in ui/BoxingHUD.rbxmx). never builds ui itself. also sounds (ReplicatedStorage.BoxingSounds) and screen shake
- hud look is manga ink: torn cream panel with ink spikes, halftone portrait corner with your avatar headshot, name on a black brush banner in Bangers, slanted cream tags, arrow-tipped bars with ink grain. art drawn by art/hud/make_hud_art.py
- each fill, the health ghost and the dark lost chunk have an arrow Tip child riding on its end. the clip runs into the track point, the fill body is share * (1 - tip width), so a full bar lands exactly in the point. tip hides at 0 and copies the fill color
- bar colors: health red, stamina orange (throbs red when gassed), guard cyan, courage purple (glows at 90+). health has the pale ghost and the dark lost-max end
- opponent = just their name on a banner, top centre
- panel is bigger (min 460 / max 880 px wide) with more gap between rows after feedback said it was too compact
- controls card (StarterGui.BoxingHUD.Controls, cream card, Bangers) shows for 8s then hides, H toggles. the bottom hint is only state messages now (mash space, ko) or "H - CONTROLS". the old tiny one-line controls text is gone, people couldnt read it
- callout pops through a UIScale since the text is TextScaled

dummies
- Punching Bag Dummy covers up sometimes, never punches
- dummies turn through an AlignOrientation (responsiveness 25), the brain only sets its target every 0.12s. setting root cframe directly looked like 8fps
- Sparring Partner walks in, punches about every 1.1-2.2s, slips 30% / guards 35% when you wind up

ring + spawn points are in the place (workspace.Ring.FighterSpawns), not in src. PlayerCorner (-10,-10) for players, PartnerCorner (10,10) for the sparring partner, BagSpot outside the ring by the steps for the bag. R6AnimRig stands outside the ring at (-24,-24)

feel (all client side, server never slows down)
- Feel module = shared hitstop / slowmo clock + hit reactions. animator multiplies its blend speed by Feel.scale()
- ImpactFX: star + sparks + sweat + shockwave ring + white highlight flash at the contact point. gold on counters, blue on blocks
- hitstop: jab 0.03, other clean hits 0.055, guard break 0.08, counter 0.09
- counter you're in: slowmo 0.45s at 0.3x, black and white impact frame, fov kick
- knockdown within 45 studs: slowmo 1.1s, strong impact frame, orbit camera cut on the fighter going down. KO = longer + desaturated
- reactions: jab/cross head snaps back, hook whips sideways, uppercut throws the head up, body folds you over, blocks knock the gloves back
- punches step forward with body weight and snap out at speed 70, pull back slower so they feel heavy

gear
- Gear.strip runs first on players: drops every accessory except hair, plus shirts and t-shirts, so everyone is shirtless in trunks and gloves
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

blender anims (first ones that aren't from the bought games)
- peek-a-boo uppercut and body shot were keyframed in blender on aeresei's R6 IK + FK rig V2.22 (devforum), working file models/anims/PaBPunches.blend
- that rig has no redistribution license and the repo is public, so the .blend is gitignored. the rig itself is cached by the animate-roblox-characters skill
- the rig exports .rbxanim keyed by its own control names, useless for us. instead i sample the InternalArmature bones every frame in blender (json), then tools/parts_to_keyframes.py works out each R6 Motor6D Transform from where the parts end up, using the stock R6 C0/C1. blender +y forward / z up becomes roblox -z forward / y up
- checked it: at the uppercut impact frame every part in roblox lands exactly where it is in blender
- arms on the rig are FK from the shoulder (R6 arms are one block), legs are IK so the feet stay planted. dropping the hips more than a few hundredths sinks the R6 feet, so the crouch is all lean and twist
- uppercut 21 frames, impact frame 9 (0.267). body shot 18 frames, impact frame 6 (0.167). Impact attributes set on the KeyframeSequences in BoxingAnims
- gif previews in build/anim_preview

polishing the bought anims (tier 1 done: both stances' idle, guard, 4 walks)
- tools/keyframes_to_parts.py reads a KeyframeSequence and works out where each R6 part is every frame (same R6 C0/C1 maths as the exporter, round trip is exact). tools/blender_match_pose.py then poses the rig's controls to match and keys them at the original keyframe spots
- imports need FK legs and head tracking off (blender_match_pose.set_import_mode), the bought anims pose legs and head directly and slide the arms forward from the shoulder, so shoulders get location too. imports land within 0.01 studs on idles and guards, walks within 0.12 between keys
- polish_loop layers life on top: arm breathing that trails the torso a few frames, small sway and twist, head settling late, walks get a bounce per step and a counter twist. every offset is a whole number of cycles over the loop so it stays seamless, last key copies the first, curves are cyclic
- no torso up/down bob on idles and guards. R6 legs have no knee, so the bob moved the feet into and off the floor. the bought idle already sinks the feet about 0.18
- fixed a real hitch: WalkRight (both stances) jumped the left leg 0.21 studs at every loop
- g2's peek-a-boo walks share the orthodox footwork, only the arms differ
- all 12 pass the skill's final loop audit. polished files are in build/anims/polished, the _src actions in the blend are the untouched imports
- tier 2 done: jab, cross, hook both stances + the 4 slips
- fast one-shots import with a key on every frame (sparse keys drifted up to 0.7 studs on punches). the bought punches also push the head off the neck, so the head gets location in the import
- what was wrong and what changed (tools/retime.py, works on the importer json):
  - hooks landed early: Impact was 0.15 but the fist only reaches full extension on frame 7, Impact is now 0.2
  - cross and hook hung at full reach for about 6 frames, cut down to 1 beat, then an eased pull back
  - strikes moved at an even speed, now they speed up into contact (cross peaks about 120 studs/s right before impact)
  - jab snapped home in its very last frame, now it comes back over 3 frames
  - SlipRight ended 54 degrees off the idle and SlipBack started and ended 157 degrees off (it's an outboxer dash with the body turned), both popped. SlipRight's end blends into the stance idle now. SlipBack had both arms dropped and swung back the whole time, blending them up made them swing through the body, so it keeps g2's footwork but the arms hold the idle guard and ride the torso (retime.py GUARD_ARMS)
- peek-a-boo jab Impact moved to 0.067, that's where its fist actually peaks
- tier 3 done: hit reactions and blocks, remade with tools/reactions.py
  - g2's reactions only key the joints they change and the stance idle shows through for the rest. head hits key the head once and hold it a whole second, body hit keys torso and legs, blocks key one arm. that's why they had to play at 1.8x
  - each one is now 15 frames (0.5s) at normal speed: two frame snap to the hit pose, a touch of overshoot, then it settles. counters play at 0.8 so they land heavier
  - head hits use g2's head pose at 80% and drag the torso 25% a frame late
  - blocks start from the guard, not the idle (they only play with the guard up). g2's block swung the arm 35-57 degrees out to the side, which only fit g2's own guard and flung our arms around, so blocks are my own now: the glove pitches 22 degrees up and back toward the face around the shoulder
  - peek-a-boo has its own copy of all six built on its idle and guard, mapped in its stance Anims. the animator picks the stance version for reactions too now (roleFor)
  - previews: build a full body json by layering the reaction over the idle, import that into blender
- tier 4 done: knockdown and ko falls and loops, stunned, the three specials
  - references i went off: the dempsey roll is a figure eight with the head, knees and waist bent, weight shifting side to side, the hook goes as the head comes out to that side. the gazelle punch sinks to load the legs then drives up and forward so the punch lands on the way up. ko falls should be sudden and speed up, no delay or hop first, head goes last
  - falls (tools/falls.py): g2's stood still 7 frames after the punch, drifted, then dropped a stud in 3 frames and ended half a stud under the floor. now a 2 frame hang, an accelerating drop landing on frame 14, a small bounce, and every frame lifted so nothing goes under the canvas. loops got the same lift
  - a knockdown plays in slow mo (Feel), so the fall runs longer than its 0.73s on screen. thats fine
  - stunned: g2 held one torso pose for a second, now it snaps in and sways like youre dazed, peek-a-boo has its own
  - specials are new since g2's popped 96-138 degrees at both ends and barely threw the punch. my first try set the arms by angle off the shoulder in blender and with the torso twisted every punch aimed across the body, looked broken
  - now tools/compose.py builds them from poses that already look right: the arms and body at the impact frame of a good punch (peek-a-boo hook frame 6, my peek-a-boo uppercut, orthodox cross) plus my own torso dips, weaves and sinks, blended joint by joint. legs keep their world angle while the torso moves so a foot doesn't kick out
  - a hook's contact frame is when the fist is in front of the chin, not when it's furthest from the body. g2's right hook is frame 6, left hook frame 5, by 7 they've swung past
  - left roll is the right roll mirrored (g2's left hook flares the other arm out like a shrug), ends put back on the real idle
  - impacts: rolls frame 9, lunge frame 12, step counter frame 8
  - lunge uppercut redone off real refs (patterson, tyson, inoue, an illustrated side view, links in my vault): long split stance load, drive forward into one diagonal with the back leg trailing on the toe. the body leads forward, the game's push carries it after contact
  - compose.py now leans the torso from the hips (it pivoted at the torso's middle, which slid both feet back), swings legs around the world's left-right axis (the torso's own axis tilted them sideways), and settles every key so the lowest foot is on the floor. plant=[leg] nudges a leg until its foot touches too
  - reference pass on the specials (refs in my vault): weave roll now slides the whole body low to one side over a wide stance and comes up out the other side with the hook, step counter slips low off the line then steps in with the lead foot and brings the cross over the top. compose.py got slide (sideways body) and spread (legs out to the side)
  - punch reference pass: jab, cross and hooks already matched the charts. uppercuts and body shots (both stances) got their legs, a split stance load so the hips drop with both feet down, uppercuts rise at impact
  - guards and slips pass: peek-a-boo guard now a wide crouch leaning in (it stood bolt upright), duck bends nearly flat under the punch. orthodox stance and side slips were fine. loops built in compose.py get an exact seam copy
  - falls and hit reactions checked against real ko photos and a head snap shot, they already matched (flat on the back with limp arms and the head turned, head snaps about 46 degrees). refs for every move are in my vault under Pipelines/References
  - lesson: always look at the rendered key frames before calling an anim done, the audit only checks curves and feet
  - weave roll is back on g2's original dempsey roll anims (my call after trying it), impacts 0.6 left / 0.5 right like before. ends blended onto the peek-a-boo guard so it doesn't pop: 3 frames in, 6 frames out (it ends deep in a crouch, 3 frames looked like a jump)

## fight mode
- players only box inside a fight zone: Map.FightZones has Ring (inside the ropes) and Upstairs (the spar room). dummies are always on, and a match keeps you on
- outside: normal roblox walk and idle (the Animate script comes back on), walk 16, space jumps (not during a drill), punches/guard/slips/stance/specials do nothing
- jumping needs JumpPower and JumpHeight both set, the character uses jump power mode
- the server checks your position every tick and sets FightMode on the character, the animator swaps anims off that
- training drills still play the punch anims outside a zone, the bags and mitts are on the ground floor

sound pass
- ReplicatedStorage.BoxingSounds, all roblox creator store audio (mostly Pro Sound Effects, roblox's licensed library, free in public games, no credit needed). numbered copies (Thud1..3, Cheer1..4) and the hud picks a random one
- knockdown and KO: canvas thud + crowd cheer (KO adds the bell). counters, guard breaks, second wind: cheer
- the count: no clean ref voice on roblox (only ripped game/anime clips), so it's a canvas slap per count (a pro sound effects hand smack), pitched up a bit each number. server sends Fx "Count"
- corner picks: hydrate = squirt bottle, treatment = tape rip, pep talk = sergeant shout or "allez allez" + a clap. played on your own client when the server takes the pick
- Crowd (wrestling crowd boos) isn't used anymore, kept in case i want an ambience bed later
