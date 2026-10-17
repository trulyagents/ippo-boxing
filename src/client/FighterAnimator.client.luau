-- Procedural boxing poses for every R6 fighter, driven by the attributes the server sets.
-- Arms and torso only; the default walk still moves the legs.
-- These are starter animations until real keyframed ones are made.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Feel = require(script.Parent:WaitForChild("Feel"))

local rad = math.rad

type Pose = { RS: CFrame, LS: CFrame, Root: CFrame, Neck: CFrame }

-- right shoulder: +z raises the arm forward, +y swings it in toward the chest
local function right(raise: number, inward: number, pull: number?, drop: number?): CFrame
	return CFrame.new(-(pull or 0), -(drop or 0), 0) * CFrame.Angles(0, rad(inward), 0) * CFrame.Angles(0, 0, rad(raise))
end
-- left shoulder is mirrored
local function left(raise: number, inward: number, pull: number?, drop: number?): CFrame
	return CFrame.new(pull or 0, -(drop or 0), 0) * CFrame.Angles(0, rad(-inward), 0) * CFrame.Angles(0, 0, rad(-raise))
end
-- root joint: z is up, so z rotation twists the body; x tilts forward/back, -y is forward
local function body(twist: number, lean: number?, duck: number?, side: number?, step: number?): CFrame
	return CFrame.new(side or 0, -(step or 0), -(duck or 0)) * CFrame.Angles(rad(lean or 0), 0, rad(twist))
end
local function head(tilt: number?, turn: number?): CFrame
	return CFrame.Angles(rad(tilt or 0), 0, rad(turn or 0))
end

local STANCE: Pose = {
	RS = right(118, 38, 0.35, 0.1), LS = left(112, 30, 0.1, 0),
	Root = body(-12, -6), Neck = head(4, 8),
}
local GUARD: Pose = {
	RS = right(140, 48, 0.55, 0), LS = left(140, 48, 0.55, 0),
	Root = body(0, -10, 0.15), Neck = head(10),
}

-- the extended frame of each punch
local PUNCH: { [string]: Pose } = {
	Jab = { RS = right(116, 38, 0.4), LS = left(94, 4, -1.05), Root = body(-26, -10, 0, 0, 0.35), Neck = head(6, 16) },
	Cross = { RS = right(94, 2, -1.25), LS = left(128, 46, 0.5), Root = body(34, -16, 0.1, 0, 0.55), Neck = head(8, -22) },
	Hook = { RS = right(96, 84, -0.35), LS = left(128, 46, 0.5), Root = body(48, -10, 0.15, 0, 0.3), Neck = head(6, -28) },
	Uppercut = { RS = right(158, 18, -0.45, -0.5), LS = left(128, 46, 0.5), Root = body(22, 12, 0.1, 0, 0.3), Neck = head(-12, -12) },
	Body = { RS = right(62, 22, -1.0, 0.35), LS = left(128, 46, 0.5), Root = body(20, -24, 0.85, 0, 0.45), Neck = head(14, -12) },
}
-- the chambered frame (pulled back) before the punch fires
local CHAMBER: { [string]: Pose } = {
	Jab = { RS = right(124, 40, 0.5), LS = left(108, 26, 0.35), Root = body(-8, -6), Neck = head(4, 8) },
	Cross = { RS = right(124, 40, 0.5), LS = left(118, 36, 0.3), Root = body(-26, -8), Neck = head(4, 16) },
	Hook = { RS = right(110, 20, 0.2), LS = left(126, 44, 0.45), Root = body(-30, -6), Neck = head(4, 16) },
	Uppercut = { RS = right(70, 20, 0.2, 0.3), LS = left(126, 44, 0.45), Root = body(-12, -10, 0.6), Neck = head(6, 8) },
	Body = { RS = right(100, 30, 0.3), LS = left(126, 44, 0.45), Root = body(-14, -10, 0.4), Neck = head(6, 8) },
}
local SLIP: { [string]: Pose } = {
	Left = { RS = GUARD.RS, LS = GUARD.LS, Root = body(10, -14, 0.25, 0.9) * CFrame.Angles(0, rad(-18), 0), Neck = head(6) },
	Right = { RS = GUARD.RS, LS = GUARD.LS, Root = body(-10, -14, 0.25, -0.9) * CFrame.Angles(0, rad(18), 0), Neck = head(6) },
	Duck = { RS = GUARD.RS, LS = GUARD.LS, Root = body(0, -30, 1.3), Neck = head(18) },
	Back = { RS = GUARD.RS, LS = GUARD.LS, Root = body(0, 14, 0.1), Neck = head(-6) },
}
local STUNNED: Pose = { RS = right(70, 10, 0, 0.2), LS = left(70, 10, 0, 0.2), Root = body(6, 16), Neck = head(-26, 10) }
local DOWN: Pose = { RS = right(160, -10), LS = left(160, -10), Root = CFrame.new(0, 0, -2.6) * CFrame.Angles(rad(80), 0, 0), Neck = head(-10) }

type Rig = { RS: Motor6D, LS: Motor6D, Root: Motor6D, Neck: Motor6D, Current: Pose, Model: Model }
local rigs: { [Model]: Rig } = {}

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	task.spawn(function()
		local torso = model:WaitForChild("Torso", 10)
		local root = model:WaitForChild("HumanoidRootPart", 10)
		if not (torso and root) then
			return
		end
		local rs = torso:WaitForChild("Right Shoulder", 5)
		local ls = torso:WaitForChild("Left Shoulder", 5)
		local neck = torso:WaitForChild("Neck", 5)
		local rj = root:WaitForChild("RootJoint", 5)
		if not (rs and ls and neck and rj) then
			return
		end
		rigs[model] = {
			RS = rs :: Motor6D, LS = ls :: Motor6D, Root = rj :: Motor6D, Neck = neck :: Motor6D,
			Current = table.clone(STANCE), Model = model,
		}
	end)
end

local function blend(a: Pose, b: Pose, t: number): Pose
	return { RS = a.RS:Lerp(b.RS, t), LS = a.LS:Lerp(b.LS, t), Root = a.Root:Lerp(b.Root, t), Neck = a.Neck:Lerp(b.Neck, t) }
end

local function targetPose(model: Model, now: number): (Pose, number)
	local state = model:GetAttribute("State")
	if state == "Down" or state == "KO" then
		return DOWN, 8
	end
	if state == "Stunned" then
		return STUNNED, 30
	end
	local action = model:GetAttribute("Action")
	local started = model:GetAttribute("ActionStart") or 0
	local elapsed = now - started
	if typeof(action) == "string" then
		local punch = PUNCH[action]
		if punch then
			local startup = model:GetAttribute("ActionLength") or Config.Moves[action].Startup
			local chamberEnd = startup * 0.55
			if elapsed < chamberEnd then
				return CHAMBER[action], 20
			elseif elapsed < startup + 0.09 then
				return punch, 70 -- snap out fast so it reads as a punch, not a push
			elseif elapsed < startup + 0.34 then
				return STANCE, 11 -- slower pull back sells the weight
			end
		end
		local slipDir = action:match("^Slip(%a+)")
		if slipDir and SLIP[slipDir] and elapsed < Config.SlipTime + 0.1 then
			return SLIP[slipDir], 30
		end
	end
	if model:GetAttribute("Guarding") then
		return GUARD, 22
	end
	-- a little bounce on the toes so idle fighters don't look frozen
	local bob = math.sin(now * 6 + (model:GetAttribute("ActionToken") or 0)) * 0.06
	local idle = table.clone(STANCE)
	idle.Root = idle.Root * CFrame.new(0, 0, bob)
	return idle, 12
end

-- what getting hit looks like, layered on whatever pose the fighter is in
local REACT_TIME = 0.32
local function reaction(model: Model): (CFrame, CFrame, CFrame)
	local r = Feel.reactions[model]
	if not r then
		return CFrame.identity, CFrame.identity, CFrame.identity
	end
	local t = (os.clock() - r.Started) / REACT_TIME
	if t >= 1 then
		Feel.reactions[model] = nil
		return CFrame.identity, CFrame.identity, CFrame.identity
	end
	-- sharp hit, slow recover
	local k = (if t < 0.15 then t / 0.15 else 1 - (t - 0.15) / 0.85) ^ 1.4
	k *= if r.Result == "Counter" then 1.6 elseif r.Result == "Blocked" or r.Result == "Chip" then 0.45 else 1
	local side = r.Side
	local neck, root, arms = CFrame.identity, CFrame.identity, CFrame.identity
	if r.Result == "Blocked" or r.Result == "Chip" then
		root = body(0, 10 * k, 0, 0, -0.35 * k)
		-- gloves get knocked back toward the face (-x is back for the right arm, mirrored on the left)
		arms = CFrame.new(-0.35 * k, 0, 0)
	elseif r.Move == "Hook" then
		neck = head(-8 * k, 40 * side * k)
		root = body(22 * side * k, 6 * k, 0, 0.25 * side * k)
	elseif r.Move == "Uppercut" then
		neck = head(-50 * k, 6 * side * k)
		root = body(0, 22 * k, 0, 0, -0.4 * k)
	elseif r.Move == "Body" then
		neck = head(18 * k)
		root = body(0, -26 * k, 0.5 * k, 0, -0.15 * k)
	else
		neck = head(-30 * k, 12 * side * k)
		root = body(6 * side * k, 14 * k, 0, 0, -0.3 * k)
	end
	return neck, root, arms
end

RunService.PreSimulation:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local scale = Feel.scale()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local target, speed = targetPose(model, now)
		local alpha = 1 - math.exp(-dt * speed * scale)
		rig.Current = blend(rig.Current, target, alpha)
		local neck, root, arms = reaction(model)
		rig.RS.Transform = arms * rig.Current.RS
		rig.LS.Transform = arms:Inverse() * rig.Current.LS
		rig.Root.Transform = rig.Current.Root * root
		rig.Neck.Transform = rig.Current.Neck * neck
	end
end)

CollectionService:GetInstanceAddedSignal("Fighter"):Connect(track)
for _, model in CollectionService:GetTagged("Fighter") do
	track(model)
end
