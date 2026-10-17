-- Plays the keyframed boxing anims (ReplicatedStorage.BoxingAnims) on fighters, driven by
-- the attributes the server sets. Runs on my own character and on dummies. Other players
-- animate their own characters and those tracks replicate to me, so I leave them alone.
local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Feel = require(script.Parent:WaitForChild("Feel"))

local player = Players.LocalPlayer
local animFolder = ReplicatedStorage:WaitForChild("BoxingAnims")

-- published anims carry an AnimId attribute. without one, register the sequence so it
-- still plays in studio
local animations: { [string]: Animation } = {}
local function animation(role: string): Animation?
	if animations[role] then
		return animations[role]
	end
	local ks = animFolder:FindFirstChild(role)
	if not (ks and ks:IsA("KeyframeSequence")) then
		return nil
	end
	local id = ks:GetAttribute("AnimId")
	if typeof(id) ~= "string" then
		local ok, temp = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, ks)
		if not ok then
			warn("[FighterAnimator] no AnimId and can't register " .. role)
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

type Rig = {
	Model: Model,
	Animator: Animator,
	Tracks: { [string]: AnimationTrack },
	Speeds: { [AnimationTrack]: number },
	Token: number?,
	State: string?,
	Reaction: number?,
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
		rigs[model] = rig
		play(rig, "Idle")
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
		local speed = impact(action) / math.max(startup, 0.05)
		local t = play(rig, action, speed, 0.05)
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
		stop(rig, "Stunned", 0.2)
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
		play(rig, "Stunned", 1, 0.08)
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
	-- their reactions are a second long, the snap is at the start so play them quick
	play(rig, role, if r.Result == "Counter" then 1.4 else 1.8, 0.03)
end

local WALKS = { "WalkForward", "WalkBack", "WalkLeft", "WalkRight" }
local function updateLoops(rig: Rig)
	local model = rig.Model
	local state = model:GetAttribute("State")
	local free = state ~= "Down" and state ~= "KO" and state ~= "Stunned"

	local guard = load(rig, "Guard")
	if guard then
		local want = free and model:GetAttribute("Guarding") == true
		if want and not guard.IsPlaying then
			guard:Play(0.12)
		elseif not want and guard.IsPlaying then
			guard:Stop(0.15)
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
		local t = load(rig, role)
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

RunService.PreSimulation:Connect(function()
	local scale = Feel.scale()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local token = model:GetAttribute("ActionToken")
		if token ~= rig.Token then
			rig.Token = token
			onAction(rig)
		end
		onState(rig, model:GetAttribute("State"))
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
