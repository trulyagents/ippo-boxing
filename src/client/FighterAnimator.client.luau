-- Procedural boxing poses for every R6 fighter, driven by the attributes the server sets.
-- Arms and torso only; the default walk still moves the legs.
-- These are starter animations until real keyframed ones are made.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

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
-- root joint: z is up, so z rotation twists the body; x tilts forward/back
local function body(twist: number, lean: number?, duck: number?, side: number?): CFrame
	return CFrame.new(side or 0, 0, -(duck or 0)) * CFrame.Angles(rad(lean or 0), 0, rad(twist))
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
	Jab = { RS = right(110, 35, 0.4), LS = left(92, 6, -0.9), Root = body(-22, -6), Neck = head(4, 14) },
	Cross = { RS = right(92, 4, -1.1), LS = left(126, 44, 0.45), Root = body(26, -10), Neck = head(6, -18) },
	Hook = { RS = right(92, 78, -0.3), LS = left(126, 44, 0.45), Root = body(38, -6), Neck = head(4, -22) },
	Uppercut = { RS = right(150, 20, -0.4, -0.4), LS = left(126, 44, 0.45), Root = body(18, 8, 0.25), Neck = head(-8, -10) },
	Body = { RS = right(60, 20, -0.9, 0.3), LS = left(126, 44, 0.45), Root = body(16, -18, 0.7), Neck = head(10, -10) },
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
				return CHAMBER[action], 18
			elseif elapsed < startup + 0.1 then
				return punch, 45 -- snap out fast
			elseif elapsed < startup + 0.32 then
				return STANCE, 14
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

RunService.PreSimulation:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local target, speed = targetPose(model, now)
		local alpha = 1 - math.exp(-dt * speed)
		rig.Current = blend(rig.Current, target, alpha)
		rig.RS.Transform = rig.Current.RS
		rig.LS.Transform = rig.Current.LS
		rig.Root.Transform = rig.Current.Root
		rig.Neck.Transform = rig.Current.Neck
	end
end)

CollectionService:GetInstanceAddedSignal("Fighter"):Connect(track)
for _, model in CollectionService:GetTagged("Fighter") do
	track(model)
end
