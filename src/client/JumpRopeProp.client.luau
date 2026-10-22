--!strict
-- the rope during the jump rope drill, a Beam between handles in the gloves.
-- its swing follows the skip anim so it passes under the feet
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimIds = require(ReplicatedStorage.Shared.AnimIds)

local SKIP = 0.5 -- the anim skips every half second
local UNDER_FEET = 0.1 -- seconds into each skip the feet are highest
local REACH = 4.6 -- how far the rope bows out from the hands, enough to clear head and feet
local ROPE_ID = AnimIds.JumpRope:match("%d+") or ""

local rack = workspace:WaitForChild("Map"):WaitForChild("Gym"):WaitForChild("JumpRopeRack")
local source = rack:WaitForChild("JumpRopeBlue")

type Rope = { Folder: Folder, Left: Attachment, Right: Attachment }
local ropes: { [Model]: Rope } = {}

local function weldHandle(arm: BasePart, handle: BasePart, parent: Instance): Attachment
	local h = handle:Clone()
	for _, child in h:GetChildren() do
		child:Destroy()
	end
	h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.Massless = false, false, false, false, true
	-- gripped in the glove, sticking out the bottom of the fist
	local grip = CFrame.new(0, -1.2, 0)
	h.CFrame = arm.CFrame * grip
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = arm, h, grip
	weld.Parent = h
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, -h.Size.Y / 2, 0)
	tip.Parent = h
	h.Parent = parent
	return tip
end

local function build(model: Model): Rope?
	local left, right = model:FindFirstChild("Left Arm"), model:FindFirstChild("Right Arm")
	local handleL, handleR = source:FindFirstChild("HandleL"), source:FindFirstChild("HandleR")
	local beamSource = source:FindFirstChild("BL", true)
	if
		not (left and right and left:IsA("BasePart") and right:IsA("BasePart"))
		or not (handleL and handleR and handleL:IsA("BasePart") and handleR:IsA("BasePart"))
		or not (beamSource and beamSource:IsA("Beam"))
	then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "JumpRope"
	local a = weldHandle(left, handleL, folder)
	local b = weldHandle(right, handleR, folder)
	local beam = beamSource:Clone()
	beam.Attachment0, beam.Attachment1 = a, b
	beam.CurveSize0, beam.CurveSize1 = REACH, REACH
	beam.Segments = 24
	beam.Parent = folder
	folder.Parent = model
	return { Folder = folder, Left = a, Right = b }
end

-- where the skip anim is, from its playing track (other players' anims replicate to me)
local function skipTime(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			if track.Animation and track.Animation.AnimationId:find(ROPE_ID, 1, true) then
				return track.TimePosition
			end
		end
	end
	return os.clock()
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local function update()
		local on = model:GetAttribute("Skipping") == true
		if on and not ropes[model] then
			ropes[model] = build(model)
		elseif not on and ropes[model] then
			ropes[model].Folder:Destroy()
			ropes[model] = nil
		end
	end
	model:GetAttributeChangedSignal("Skipping"):Connect(update)
	update()
end

RunService.RenderStepped:Connect(function()
	for model, rope in ropes do
		local root = model:FindFirstChild("HumanoidRootPart")
		if not (model.Parent and root and root:IsA("BasePart")) then
			rope.Folder:Destroy()
			ropes[model] = nil
			continue
		end
		-- 0 is straight down under the feet, then back, over the head, out front and down again
		local angle = 2 * math.pi * (skipTime(model) - UNDER_FEET) / SKIP
		local body = root.CFrame
		local out = -body.UpVector * math.cos(angle) - body.LookVector * math.sin(angle)
		local across = (rope.Right.WorldPosition - rope.Left.WorldPosition)
		across = if across.Magnitude > 0.01 then across.Unit else body.RightVector
		-- a beam bows out along each end's X axis, the far end the opposite way
		rope.Left.WorldCFrame = CFrame.fromMatrix(rope.Left.WorldPosition, out, across)
		rope.Right.WorldCFrame = CFrame.fromMatrix(rope.Right.WorldPosition, -out, -across)
	end
end)

CollectionService:GetInstanceAddedSignal("Fighter"):Connect(watch)
for _, model in CollectionService:GetTagged("Fighter") do
	watch(model)
end
