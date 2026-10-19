-- Plays the keyframed boxing anims (ReplicatedStorage.BoxingAnims) on fighters, driven by
-- the attributes the server sets. Runs on my own character and on dummies. Other players
-- animate their own characters and those tracks replicate to me, so I leave them alone.
local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimIds = require(ReplicatedStorage.Shared.AnimIds)
-- ids that are still the bought game's own and won't load here until the spoofer swaps them
local original: { [string]: boolean } = {}
for id in string.gmatch(ReplicatedStorage.Shared.AnimIds:GetAttribute("OriginalIds") or "", "%d+") do
	original[id] = true
end
local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Feel = require(script.Parent:WaitForChild("Feel"))

local player = Players.LocalPlayer
local animFolder = ReplicatedStorage:WaitForChild("BoxingAnims")

-- published ids live in Shared.AnimIds. without one, register the sequence so it still
-- plays in studio
local animations: { [string]: Animation } = {}
local function animation(role: string): Animation?
	if animations[role] then
		return animations[role]
	end
	local ks = animFolder:FindFirstChild(role)
	if not (ks and ks:IsA("KeyframeSequence")) then
		return nil
	end
	local id = AnimIds[role]
	if id and id ~= "" and not original[id:match("%d+") or ""] then
		id = if id:match("^%d+$") then "rbxassetid://" .. id else id
	else
		local ok, temp = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, ks)
		if not ok then
			warn("[FighterAnimator] no id in AnimIds and can't register " .. role)
			return nil
		end
		id = temp
	end
	local a = Instance.new("Animation")
	a.AnimationId = id
	animations[role] = a
	return a
end

local function impact(role: string): number
	local ks = animFolder:FindFirstChild(role)
	return ks and ks:GetAttribute("Impact") or 0.1
end

-- track.Length is 0 until the anim has loaded, so read it off the keyframes
local function length(role: string): number
	local ks = animFolder:FindFirstChild(role)
	local last = 0
	if ks and ks:IsA("KeyframeSequence") then
		for _, k in ks:GetKeyframes() do
			last = math.max(last, (k :: Keyframe).Time)
		end
	end
	return if last > 0 then last else 0.5
end

-- which anim plays for a base role: the move's own Anim if it borrows one, then the
-- fighter's stance version if the stance has one
local function roleFor(model: Model, role: string): string
	local move = Config.Moves[role]
	local base = (move and move.Anim) or role
	local stance = Config.Stances[model:GetAttribute("Stance") or ""]
	return (stance and stance.Anims[base]) or base
end

type Rig = {
	Model: Model,
	Animator: Animator,
	Tracks: { [string]: AnimationTrack },
	Speeds: { [AnimationTrack]: number },
	Token: number?,
	State: string?,
	Reaction: number?,
	Hurt: boolean?,
	Gassed: boolean?,
	Stance: string?,
}
local rigs: { [Model]: Rig } = {}

local function load(rig: Rig, role: string): AnimationTrack?
	local t = rig.Tracks[role]
	if t then
		return t
	end
	local a = animation(role)
	if not a then
		return nil
	end
	t = rig.Animator:LoadAnimation(a)
	rig.Tracks[role] = t
	return t
end

local function play(rig: Rig, role: string, speed: number?, fade: number?): AnimationTrack?
	local t = load(rig, role)
	if not t then
		return nil
	end
	rig.Speeds[t] = speed or 1
	t:Play(fade or 0.08, 1, (speed or 1) * Feel.scale())
	return t
end

local function stop(rig: Rig, role: string, fade: number?)
	local t = rig.Tracks[role]
	if t and t.IsPlaying then
		t:Stop(fade or 0.15)
	end
end

local function ownedByOtherPlayer(model: Model): boolean
	local owner = Players:GetPlayerFromCharacter(model)
	return owner ~= nil and owner ~= player
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] or ownedByOtherPlayer(model) then
		return
	end
	task.spawn(function()
		local humanoid = model:WaitForChild("Humanoid", 10)
		if not (humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		-- the default walk/idle would fight the boxing anims
		local animate = model:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			animate.Enabled = false
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		for _, t in (animator :: Animator):GetPlayingAnimationTracks() do
			t:Stop(0)
		end
		local rig: Rig = { Model = model, Animator = animator :: Animator, Tracks = {}, Speeds = {} }
		-- load everything up front so the first punch isn't late
		for _, ks in animFolder:GetChildren() do
			load(rig, ks.Name)
		end
		rig.Token = model:GetAttribute("ActionToken")
		rig.Stance = model:GetAttribute("Stance")
		rig.FightMode = true
		rigs[model] = rig
		play(rig, roleFor(model, "Idle"))
	end)
end

local function onAction(rig: Rig)
	local model = rig.Model
	local action = model:GetAttribute("Action")
	if typeof(action) ~= "string" then
		return
	end
	local move = Config.Moves[action]
	if move then
		-- stretch the anim so its impact frame lands when the server says the punch lands
		local startup = model:GetAttribute("ActionLength") or move.Startup
		local role = roleFor(model, action)
		local speed = impact(role) / math.max(startup, 0.05)
		local t = play(rig, role, speed, 0.05)
		-- catch up on the time the attribute spent crossing the network
		local late = workspace:GetServerTimeNow() - (model:GetAttribute("ActionStart") or 0)
		if t and late > 0 and late < 0.3 then
			t.TimePosition = late * speed
		end
		return
	end
	local dir = action:match("^Slip(%a+)")
	if dir then
		play(rig, "Slip" .. dir, length("Slip" .. dir) / (Config.SlipTime + 0.15), 0.05)
	end
end

local function onState(rig: Rig, state: string?)
	local was = rig.State
	rig.State = state
	if state == was then
		return
	end
	if was == "Down" then
		stop(rig, "DownFall")
		stop(rig, "DownLoop", 0.3)
	elseif was == "KO" then
		stop(rig, "KOFall")
		stop(rig, "KOLoop", 0.3)
	elseif was == "Stunned" then
		stop(rig, roleFor(rig.Model, "Stunned"), 0.2)
	end
	if state == "Down" or state == "KO" then
		local fall = play(rig, if state == "KO" then "KOFall" else "DownFall", 1, 0.05)
		local loopRole = if state == "KO" then "KOLoop" else "DownLoop"
		if fall then
			fall.Stopped:Once(function()
				if rig.State == state then
					play(rig, loopRole, 1, 0.1)
				end
			end)
		end
	elseif state == "Stunned" then
		play(rig, roleFor(rig.Model, "Stunned"), 1, 0.08)
	end
end

local function onReaction(rig: Rig)
	local r = Feel.reactions[rig.Model]
	if not r or r.Started == rig.Reaction then
		return
	end
	rig.Reaction = r.Started
	local role
	if r.Result == "Blocked" or r.Result == "Chip" then
		role = if r.Side > 0 then "BlockRight" else "BlockLeft"
	elseif r.Move == "Body" then
		role = "HitBody"
	elseif r.Move == "Uppercut" then
		role = "HitHeadTop"
	else
		role = if r.Side > 0 then "HitHeadRight" else "HitHeadLeft"
	end
	-- half a second at normal speed, a counter plays a bit slower so it lands heavier
	play(rig, roleFor(rig.Model, role), if r.Result == "Counter" then 0.8 else 1, 0.03)
end

local WALKS = { "WalkForward", "WalkBack", "WalkLeft", "WalkRight" }

-- new stance: drop every looped anim from the old one so the new set takes over
local function onStance(rig: Rig)
	local stance = rig.Model:GetAttribute("Stance")
	if stance == rig.Stance then
		return
	end
	local old = rig.Stance
	rig.Stance = stance
	for _, role in { "Idle", "Guard", "WalkForward", "WalkBack", "WalkLeft", "WalkRight" } do
		local was = Config.Stances[old or ""]
		stop(rig, (was and was.Anims[role]) or role, 0.25)
	end
	play(rig, roleFor(rig.Model, "Idle"), 1, 0.25)
end

local function updateLoops(rig: Rig)
	local model = rig.Model
	local state = model:GetAttribute("State")
	local free = state ~= "Down" and state ~= "KO" and state ~= "Stunned"

	-- high guard, low guard and the weave bob are all held loops
	local height = if free then model:GetAttribute("GuardHeight") else nil
	local loops = {
		Guard = height == "High",
		LowGuard = height == "Low",
		Weave = free and model:GetAttribute("Weaving") == true,
		-- on the corner stool between rounds
		CornerSit = model:GetAttribute("Sitting") == true,
	}
	for role, want in loops do
		local t = load(rig, roleFor(model, role))
		if t then
			if want and not t.IsPlaying then
				t:Play(0.12)
			elseif not want and t.IsPlaying then
				t:Stop(0.15)
			end
		end
	end

	-- tells instead of bars: hurt fighters wobble, gassed ones heave. both replace the idle
	local health = model:GetAttribute("Health") or Config.MaxHealth
	local stamina = model:GetAttribute("Stamina") or Config.MaxStamina
	-- a gap between going in and coming out, or it flickers on and off as stamina or health
	-- regens across the line
	rig.Hurt = if rig.Hurt
		then health < Config.MaxHealth * (Config.HurtBelow + 0.08)
		else health < Config.MaxHealth * Config.HurtBelow
	rig.Gassed = if rig.Gassed then stamina < Config.GassedBelow + 10 else stamina < Config.GassedBelow
	local hurt = free and not loops.CornerSit and rig.Hurt == true
	local gassed = free and not hurt and not loops.CornerSit and rig.Gassed == true
	local idle = load(rig, roleFor(model, "Idle"))
	if idle then
		idle:AdjustWeight(if hurt or gassed or loops.CornerSit then 0.001 else 1, 0.3)
	end
	for role, want in { Hurt = hurt, Gassed = gassed } do
		local t = load(rig, role)
		if t then
			if want and not t.IsPlaying then
				t:Play(0.3)
			elseif not want and t.IsPlaying then
				t:Stop(0.4)
			end
		end
	end

	-- walk anims by which way the fighter is moving relative to where it faces
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local v = if root then root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity) else Vector3.zero
	v = Vector3.new(v.X, 0, v.Z)
	local moving = free and v.Magnitude > 1.5
	local weights = { 0, 0, 0, 0 }
	if moving then
		local u = v.Unit
		weights = { math.max(-u.Z, 0), math.max(u.Z, 0), math.max(-u.X, 0), math.max(u.X, 0) }
	end
	for i, role in WALKS do
		local t = load(rig, roleFor(model, role))
		if t then
			local w = weights[i]
			if w > 0.05 then
				if not t.IsPlaying then
					t:Play(0.15, w)
				else
					t:AdjustWeight(w, 0.1)
				end
			elseif t.IsPlaying then
				t:Stop(0.2)
			end
		end
	end
end

-- out of a fight zone the default roblox walk and idle take over, back in it the boxing anims do
local function setFightMode(rig: Rig, on: boolean)
	rig.FightMode = on
	local animate = rig.Model:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = not on
	end
	for _, t in rig.Animator:GetPlayingAnimationTracks() do
		t:Stop(0.2)
	end
	if on then
		play(rig, roleFor(rig.Model, "Idle"), 1, 0.2)
	end
end

RunService.PreSimulation:Connect(function()
	local scale = Feel.scale()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local fightMode = model:GetAttribute("FightMode") ~= false
		if fightMode ~= rig.FightMode then
			setFightMode(rig, fightMode)
		end
		local token = model:GetAttribute("ActionToken")
		if token ~= rig.Token then
			rig.Token = token
			onAction(rig)
		end
		if not fightMode then
			-- only training punches play out here
			continue
		end
		onState(rig, model:GetAttribute("State"))
		onStance(rig)
		onReaction(rig)
		updateLoops(rig)
		-- hitstop and slow-mo
		for t, speed in rig.Speeds do
			if t.IsPlaying then
				t:AdjustSpeed(speed * scale)
			end
		end
	end
end)

CollectionService:GetInstanceAddedSignal("Fighter"):Connect(track)
for _, model in CollectionService:GetTagged("Fighter") do
	track(model)
end
