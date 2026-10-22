--!strict
-- roblox can't render reflections, so this builds a mirrored copy of the room and every boxer
-- behind the glass, client only, and only while i'm upstairs
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local mirror = map:WaitForChild("Gym"):WaitForChild("Upstairs"):WaitForChild("Mirror") :: BasePart
local zone = map:WaitForChild("FightZones"):WaitForChild("Upstairs") :: BasePart

-- the mirror plane: the glass's front face, pointing into the room
local NORMAL = mirror.CFrame.RightVector -- the mirror is a thin slab along its local X
local PLANE = mirror.Position + NORMAL * mirror.Size.X / 2
local HOLE_Y = { mirror.Position.Y - mirror.Size.Y / 2, mirror.Position.Y + mirror.Size.Y / 2 }
local HOLE_Z = { mirror.Position.Z - mirror.Size.Z / 2, mirror.Position.Z + mirror.Size.Z / 2 }

local function reflectPoint(p: Vector3): Vector3
	return p - 2 * (p - PLANE):Dot(NORMAL) * NORMAL
end
local function reflectVector(v: Vector3): Vector3
	return v - 2 * v:Dot(NORMAL) * NORMAL
end
-- a part's mirror image. blocky parts are symmetric, so a turned copy reads as a reflection
local function reflect(cf: CFrame): CFrame
	local p = reflectPoint(cf.Position)
	return CFrame.lookAt(p, p + reflectVector(cf.LookVector), reflectVector(cf.UpVector))
end

local function inRoom(p: Vector3): boolean
	local local_ = zone.CFrame:PointToObjectSpace(p)
	local half = zone.Size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y and math.abs(local_.Z) <= half.Z
end

local function strip(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local world = Instance.new("Folder")
world.Name = "MirrorWorld"

-- the room, copied once. the mirror wall itself is left out, its copy would sit on the glass
local params = OverlapParams.new()
params.FilterDescendantsInstances = { zone }
params.FilterType = Enum.RaycastFilterType.Exclude
for _, part in workspace:GetPartBoundsInBox(zone.CFrame, zone.Size + Vector3.new(2, 4, 2), params) do
	if part:IsDescendantOf(map) and (part.Position - PLANE):Dot(NORMAL) > 1.5 and part.Transparency < 1 then
		local copy = part:Clone()
		for _, d in copy:GetDescendants() do
			if not (d:IsA("Texture") or d:IsA("Decal") or d:IsA("SurfaceGui") or d:IsA("SpecialMesh") or d:IsA("GuiObject") or d:IsA("UIBase")) then
				d:Destroy()
			end
		end
		strip(copy)
		copy.CFrame = reflect(part.CFrame)
		copy.Parent = world
	end
end

-- the wall behind the glass: hidden while the mirror is on, rebuilt around a mirror-sized hole
local wallParts: { BasePart } = {}
local patches = Instance.new("Folder")
patches.Name = "WallPatches"
patches.Parent = world
do
	local behind = OverlapParams.new()
	behind.FilterDescendantsInstances = { mirror.Parent :: Instance }
	behind.FilterType = Enum.RaycastFilterType.Exclude
	local box = CFrame.new(PLANE - NORMAL * 1.2)
	for _, part in workspace:GetPartBoundsInBox(box, Vector3.new(1.6, mirror.Size.Y, mirror.Size.Z), behind) do
		if part:IsDescendantOf(map) and part.Transparency < 1 then
			table.insert(wallParts, part)
			-- the part's own y and z span, minus the hole (wall runs along world Z)
			local y0, y1 = part.Position.Y - part.Size.Y / 2, part.Position.Y + part.Size.Y / 2
			local z0, z1 = part.Position.Z - part.Size.Z / 2, part.Position.Z + part.Size.Z / 2
			local function patch(ya: number, yb: number, za: number, zb: number)
				if yb - ya < 0.05 or zb - za < 0.05 then
					return
				end
				local p = part:Clone()
				for _, d in p:GetChildren() do
					if not (d:IsA("Texture") or d:IsA("Decal")) then
						d:Destroy()
					end
				end
				strip(p)
				p.Size = Vector3.new(part.Size.X, yb - ya, zb - za)
				p.CFrame = CFrame.new(part.Position.X, (ya + yb) / 2, (za + zb) / 2)
				p.Parent = patches
			end
			local hz0, hz1 = math.max(z0, HOLE_Z[1]), math.min(z1, HOLE_Z[2])
			patch(y0, HOLE_Y[1], z0, z1) -- below the hole
			patch(HOLE_Y[2], y1, z0, z1) -- above it
			if hz1 > hz0 then
				patch(HOLE_Y[1], HOLE_Y[2], z0, hz0) -- either side of it
				patch(HOLE_Y[1], HOLE_Y[2], hz1, z1)
			else
				patch(HOLE_Y[1], HOLE_Y[2], z0, z1)
			end
		end
	end
end

-- anything entirely behind the glass, where the mirrored room is, would show through the hole
-- (the stairwell, the street). parts that cross the glass, like the floor and ceiling, stay
local function behindGlass(part: BasePart): boolean
	local cf, half = part.CFrame, part.Size / 2
	local reach = math.abs(cf.RightVector:Dot(NORMAL)) * half.X
		+ math.abs(cf.UpVector:Dot(NORMAL)) * half.Y
		+ math.abs(cf.LookVector:Dot(NORMAL)) * half.Z
	return (part.Position - PLANE):Dot(NORMAL) + reach < 0.05
end
local intruders: { BasePart } = {}
do
	local centre = reflectPoint(zone.Position)
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(centre), zone.Size + Vector3.new(0, 4, 0)) do
		if not part:IsDescendantOf(world) and part.Transparency < 1 and behindGlass(part) then
			table.insert(intruders, part)
		end
	end
end

-- a twin per boxer in the room: a copy of their body with no joints, posed every frame
type Twin = { Model: Model, Pairs: { { BasePart } } }
local twins: { [Model]: Twin } = {}

local function makeTwin(model: Model): Twin?
	local wasArchivable = model.Archivable
	model.Archivable = true
	local copy = model:Clone()
	model.Archivable = wasArchivable
	if not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if
			d:IsA("BaseScript")
			or d:IsA("JointInstance")
			or d:IsA("Constraint")
			or d:IsA("BillboardGui")
			or d:IsA("Sound")
			or d:IsA("ParticleEmitter")
		then
			d:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- keeps shirts and pants drawing, but no name over the head and nothing breaks
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.EvaluateStateMachine = false
	end
	local list: { { BasePart } } = {}
	local originals: { [string]: { BasePart } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local key = d:GetFullName():sub(#model:GetFullName() + 1)
			originals[key] = originals[key] or {}
			table.insert(originals[key], d)
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			strip(d)
			local key = d:GetFullName():sub(#copy:GetFullName() + 1)
			local from = originals[key] and table.remove(originals[key], 1)
			if from then
				table.insert(list, { from, d })
			else
				d:Destroy()
			end
		end
	end
	copy.Parent = world
	return { Model = copy, Pairs = list }
end

local function dropTwin(model: Model)
	local twin = twins[model]
	if twin then
		twin.Model:Destroy()
		twins[model] = nil
	end
end

local on = false
local function setOn(want: boolean)
	if want == on then
		return
	end
	on = want
	world.Parent = if on then workspace else nil
	for _, part in wallParts do
		part.LocalTransparencyModifier = if on then 1 else 0
	end
	for _, part in intruders do
		part.LocalTransparencyModifier = if on then 1 else 0
	end
	-- clear glass while it works, shiny glass when it doesn't
	mirror.LocalTransparencyModifier = if on then 0.85 else 0
	if not on then
		for model in twins do
			dropTwin(model)
		end
	end
end

-- shortcut: a twin is rebuilt when someone respawns or re-gears; fine for a handful of boxers
-- every fighter and its root, kept up to date by the tag instead of rebuilt every frame
local fighters: { [Model]: BasePart } = {}
local function track(model: Instance)
	if model:IsA("Model") then
		local root = model:WaitForChild("HumanoidRootPart", 5)
		if root and root:IsA("BasePart") and model.Parent then
			fighters[model] = root
		end
	end
end
CollectionService:GetInstanceAddedSignal("Fighter"):Connect(function(model)
	task.spawn(track, model)
end)
CollectionService:GetInstanceRemovedSignal("Fighter"):Connect(function(model)
	fighters[model :: Model] = nil
end)
for _, model in CollectionService:GetTagged("Fighter") do
	task.spawn(track, model)
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	setOn(inRoom(camera.CFrame.Position))
	if not on then
		return
	end
	for model, root in fighters do
		local here = root.Parent ~= nil and inRoom(root.Position)
		if here and not twins[model] then
			twins[model] = makeTwin(model) :: Twin
		elseif not here and twins[model] then
			dropTwin(model)
		end
		local twin = twins[model]
		if twin then
			for _, pair in twin.Pairs do
				pair[2].CFrame = reflect(pair[1].CFrame)
			end
		end
	end
	for model in twins do
		if not model.Parent then
			dropTwin(model)
			fighters[model] = nil
		end
	end
end)
