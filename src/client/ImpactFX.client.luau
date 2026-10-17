-- Makes punches feel like punches: sparks, sweat, a shockwave ring and a white flash on
-- the target, hit-stop on every clean hit, and slow-mo with an impact frame and a camera
-- cut on counters, knockdowns and KOs. All local, the server never slows down.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))
local Feel = require(script.Parent:WaitForChild("Feel"))

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local CINEMATIC_RANGE = 45 -- knockdowns this close to you get the slow-mo cut

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "ImpactEffects"
effectsFolder.Parent = workspace

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "ImpactGrade"
grade.Parent = Lighting

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	e.ZOffset = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function contactPoint(attacker: Model, target: Model, move: string): Vector3?
	local part = target:FindFirstChild(if move == "Body" then "Torso" else "Head")
	local from = attacker:FindFirstChild("HumanoidRootPart")
	if not (part and part:IsA("BasePart") and from and from:IsA("BasePart")) then
		return nil
	end
	local toward = from.Position - part.Position
	toward = Vector3.new(toward.X, 0, toward.Z)
	if toward.Magnitude < 0.01 then
		return part.Position
	end
	return part.Position + toward.Unit * 0.7
end

local function burst(position: Vector3, facing: Vector3, result: string, move: string)
	local heavy = move == "Cross" or move == "Hook" or move == "Uppercut"
	local counter = result == "Counter" or result == "GuardBreak"
	local blocked = result == "Blocked" or result == "Chip"
	local color = if counter
		then Color3.fromRGB(255, 205, 70)
		elseif blocked then Color3.fromRGB(150, 200, 255)
		else Color3.fromRGB(255, 245, 230)

	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(position, position + facing)
	holder.Parent = effectsFolder
	local at = Instance.new("Attachment")
	at.Parent = holder

	-- one big star at the point of contact
	local star = emitter(at, {
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if counter then 6 else if heavy then 4 else 2.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.12),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		Transparency = NumberSequence.new(0),
	})
	star:Emit(if counter then 2 else 1)

	-- sparks flying out the far side
	local sparks = emitter(at, {
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.12, 0.28),
		Speed = NumberRange.new(18, if counter then 46 else 32),
		SpreadAngle = Vector2.new(55, 55),
		Drag = 6,
		EmissionDirection = Enum.NormalId.Back,
	})
	sparks:Emit(if counter then 30 elseif heavy then 18 else 10)

	-- sweat flying off the face on clean head shots
	if not blocked and move ~= "Body" then
		local sweat = emitter(at, {
			Color = ColorSequence.new(Color3.fromRGB(215, 235, 255)),
			LightEmission = 0.3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.05) }),
			Lifetime = NumberRange.new(0.4, 0.7),
			Speed = NumberRange.new(10, 22),
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -45, 0),
			EmissionDirection = Enum.NormalId.Back,
		})
		sweat:Emit(if counter then 26 else 12)
	end

	-- shockwave ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.05, 0.6, 0.6)
	ring.CFrame = holder.CFrame * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = effectsFolder
	local grow = if counter then 7 elseif heavy then 4.5 else 3
	TweenService:Create(ring, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, grow, grow),
		Transparency = 1,
	}):Play()

	task.delay(1, function()
		holder:Destroy()
		ring:Destroy()
	end)
end

local function flash(target: Model, result: string)
	local h = Instance.new("Highlight")
	h.FillColor = if result == "Counter" then Color3.fromRGB(255, 220, 120) else Color3.new(1, 1, 1)
	h.OutlineTransparency = 1
	h.FillTransparency = 0.25
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = target
	TweenService:Create(h, TweenInfo.new(0.14), { FillTransparency = 1 }):Play()
	task.delay(0.16, function()
		h:Destroy()
	end)
end

-- two frames of high contrast black and white, the manga impact panel
local function impactFrame(strong: boolean)
	grade.Saturation = -1
	grade.Contrast = if strong then 1.6 else 0.9
	grade.Brightness = 0.12
	task.delay(if strong then 0.07 else 0.045, function()
		TweenService:Create(grade, TweenInfo.new(0.25), { Saturation = 0, Contrast = 0, Brightness = 0 }):Play()
	end)
end

local function fovKick(amount: number)
	local camera = workspace.CurrentCamera
	local base = camera:GetAttribute("BaseFov") or camera.FieldOfView
	camera:SetAttribute("BaseFov", base)
	camera.FieldOfView = base - amount
	TweenService
		:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		:Play()
end

-- slow-mo camera cut to the side of whoever is going down
local cinematic: { Target: Model, Until: number, Angle: number, Started: number }? = nil
local function startCinematic(target: Model, seconds: number)
	cinematic =
		{ Target = target, Until = os.clock() + seconds, Angle = math.random() < 0.5 and 1 or -1, Started = os.clock() }
end

RunService:BindToRenderStep("BoxingCinematic", Enum.RenderPriority.Camera.Value + 3, function()
	local c = cinematic
	if not c then
		return
	end
	local camera = workspace.CurrentCamera
	local root = c.Target:FindFirstChild("HumanoidRootPart")
	if os.clock() > c.Until or not (root and root:IsA("BasePart")) then
		cinematic = nil
		if not player:GetAttribute("LockTarget") then
			camera.CameraType = Enum.CameraType.Custom
		end
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	-- slow orbit around the falling fighter
	local t = os.clock() - c.Started
	local look = root.CFrame.LookVector
	local side = root.CFrame.RightVector * c.Angle
	local eye = root.Position + side * 7 + look * 3 + Vector3.new(0, 2.2 - t * 0.6, 0)
	eye = CFrame.new(root.Position) * CFrame.Angles(0, t * 0.35 * c.Angle, 0) * CFrame.new(eye - root.Position)
	camera.CFrame = CFrame.lookAt((eye :: any).Position, root.Position + Vector3.new(0, 0.5, 0))
end)

-- second wind: steam and heat coming off the body while fired up
local function aura(model: Model, seconds: number)
	local torso = model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "SecondWindAura"
	at.Parent = torso
	local steam = emitter(at, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 225, 200)),
		LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 4, 0),
		Rate = 26,
		EmissionDirection = Enum.NormalId.Top,
	})
	steam.Enabled = true
	local sparks = emitter(at, {
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 60)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 14,
	})
	sparks.Enabled = true
	task.delay(seconds, function()
		steam.Enabled = false
		sparks.Enabled = false
		task.delay(1.5, function()
			at:Destroy()
		end)
	end)
end

-- gassed fighters drip sweat, part of reading the other guy without bars
local CollectionService = game:GetService("CollectionService")
local drips: { [Model]: ParticleEmitter } = {}
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, model in CollectionService:GetTagged("Fighter") do
			if not model:IsA("Model") then
				continue
			end
			local drip = drips[model]
			-- same gap as the gassed anim so the sweat doesn't blink
			local line = Config.GassedBelow + (if drip then 10 else 0)
			local tired = (model:GetAttribute("Stamina") or 100) < line and model:GetAttribute("State") ~= "KO"
			if tired and not drip then
				local head = model:FindFirstChild("Head")
				if head and head:IsA("BasePart") then
					local at = Instance.new("Attachment")
					at.Name = "SweatDrip"
					at.Position = Vector3.new(0, 0.2, -0.3)
					at.Parent = head
					drip = emitter(at, {
						Color = ColorSequence.new(Color3.fromRGB(210, 235, 255)),
						LightEmission = 0.2,
						Size = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.12),
							NumberSequenceKeypoint.new(1, 0.06),
						}),
						Lifetime = NumberRange.new(0.5, 0.8),
						Speed = NumberRange.new(0.5, 1.5),
						SpreadAngle = Vector2.new(60, 60),
						Acceleration = Vector3.new(0, -30, 0),
						Rate = 10,
					})
					drip.Enabled = true
					drips[model] = drip
				end
			elseif drip and not tired then
				drip.Enabled = false
				local at = drip.Parent
				drips[model] = nil
				task.delay(1, function()
					if at then
						at:Destroy()
					end
				end)
			end
		end
		for model in drips do
			if not model.Parent then
				drips[model] = nil
			end
		end
	end
end)

local function near(model: Model): boolean
	local me = player.Character
	local a = me and me:FindFirstChild("HumanoidRootPart")
	local b = model:FindFirstChild("HumanoidRootPart")
	return a ~= nil and b ~= nil and ((a :: BasePart).Position - (b :: BasePart).Position).Magnitude < CINEMATIC_RANGE
end

fx.OnClientEvent:Connect(function(kind, a, b, move, result, _damage, counterName)
	local me = player.Character
	if kind == "Hit" and typeof(a) == "Instance" and typeof(b) == "Instance" then
		local attacker, target = a :: Model, b :: Model
		local point = contactPoint(attacker, target, move)
		if not point then
			return
		end
		local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		local facing = if attackerRoot then (point - attackerRoot.Position) else Vector3.zAxis
		facing = Vector3.new(facing.X, 0, facing.Z)
		if facing.Magnitude < 0.01 then
			facing = Vector3.zAxis
		end
		burst(point, facing.Unit, result, move)

		-- which way the head snaps: away from the punching hand
		local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		local side = 1
		if targetRoot and attackerRoot then
			side = if targetRoot.CFrame.RightVector:Dot(attackerRoot.Position - targetRoot.Position) > 0 then -1 else 1
		end
		Feel.react(target, move, result, side)

		local involved = attacker == me or target == me
		if result ~= "Blocked" then
			flash(target, result)
		end
		if result == "Counter" and counterName == "CROSS COUNTER" then
			-- the big one gets close to knockdown treatment
			Feel.hitstop(0.12)
			if involved or near(target) then
				Feel.slowmo(0.8, 0.25)
				impactFrame(true)
				fovKick(10)
			end
		elseif result == "Counter" then
			Feel.hitstop(0.09)
			if involved then
				Feel.slowmo(0.45, 0.3)
				impactFrame(false)
				fovKick(8)
			end
		elseif result == "GuardBreak" then
			Feel.hitstop(0.08)
			if involved then
				fovKick(5)
			end
		elseif result == "Clean" or result == "Open" then
			Feel.hitstop(if move == "Jab" then 0.03 else 0.055)
			if involved and move ~= "Jab" then
				fovKick(2.5)
			end
		elseif result == "Chip" then
			Feel.hitstop(0.025)
		end
	elseif kind == "Parried" and typeof(a) == "Instance" and typeof(b) == "Instance" then
		-- a = who parried, b = whose arm got knocked aside
		local parrier, attacker = a :: Model, b :: Model
		local point = contactPoint(attacker, parrier, move)
		if point then
			local from = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
			local facing = if from then point - from.Position else Vector3.zAxis
			facing = Vector3.new(facing.X, 0, facing.Z)
			burst(point, if facing.Magnitude > 0.01 then facing.Unit else Vector3.zAxis, "Blocked", move)
		end
		Feel.hitstop(0.05)
		Feel.react(attacker, move, "Blocked", 1)
	elseif kind == "SecondWind" and typeof(a) == "Instance" then
		local fighter = a :: Model
		aura(fighter, Config.FiredUpTime)
		if fighter == me or near(fighter) then
			Feel.slowmo(0.7, 0.35)
			impactFrame(false)
		end
		if fighter == me then
			-- warm the screen while you're fired up
			grade.TintColor = Color3.fromRGB(255, 225, 195)
			task.delay(Config.FiredUpTime, function()
				TweenService:Create(grade, TweenInfo.new(1), { TintColor = Color3.new(1, 1, 1) }):Play()
			end)
		end
	elseif kind == "Down" and typeof(a) == "Instance" then
		local target = a :: Model
		if near(target) then
			Feel.hitstop(0.12)
			Feel.slowmo(1.1, 0.25)
			impactFrame(true)
			startCinematic(target, 1.4)
		end
	elseif kind == "KO" and typeof(a) == "Instance" then
		local target = a :: Model
		if near(target) then
			Feel.hitstop(0.16)
			Feel.slowmo(1.8, 0.2)
			impactFrame(true)
			startCinematic(target, 2.2)
			TweenService:Create(grade, TweenInfo.new(0.4), { Saturation = -0.6 }):Play()
			task.delay(2.4, function()
				TweenService:Create(grade, TweenInfo.new(0.8), { Saturation = 0 }):Play()
			end)
		end
	end
end)
