-- Two practice opponents in the ring: a bag that only covers up, and a sparring
-- partner that throws back, guards and slips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Fighters = require(script.Parent.Fighters)
local Gear = require(script.Parent.Gear)

local ring = workspace:WaitForChild("Ring")
local spawns = ring:WaitForChild("FighterSpawns")
local random = Random.new()

local PUNCHES = { "Jab", "Jab", "Jab", "Cross", "Cross", "Hook", "Body", "Uppercut" }

local function makeDummy(name: string, spawnPart: BasePart, shirt: Color3)
	local description = Instance.new("HumanoidDescription")
	description.TorsoColor = shirt
	description.HeadColor = Color3.fromRGB(205, 160, 125)
	description.LeftArmColor, description.RightArmColor = description.HeadColor, description.HeadColor
	description.LeftLegColor, description.RightLegColor = Color3.fromRGB(30, 30, 35), Color3.fromRGB(30, 30, 35)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	model.Name = name
	model:PivotTo(spawnPart.CFrame)
	model.Parent = workspace
	Gear.gloves(model)
	Gear.trunks(model)
	-- the server simulates them, a nearby client can't shove them around
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end
	local f = Fighters.register(model, nil)
	return model, f
end

local function nearestPlayer(f: Fighters.Fighter): (Fighters.Fighter?, number)
	local best, bestDistance = nil, math.huge
	for model, other in Fighters.all() do
		if other.Player and model.Parent and other.State ~= "KO" then
			local d = (other.Root.Position - f.Root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = other, d
			end
		end
	end
	return best, bestDistance
end

local function face(f: Fighters.Fighter, target: Fighters.Fighter)
	local from = f.Root.Position
	local to = Vector3.new(target.Root.Position.X, from.Y, target.Root.Position.Z)
	if (to - from).Magnitude > 0.1 then
		f.Root.CFrame = CFrame.lookAt(from, to)
	end
end

local function brain(model: Model, f: Fighters.Fighter, spars: boolean)
	f.Humanoid.AutoRotate = false
	local nextPunch = 0
	local home = f.Root.Position
	while model.Parent do
		task.wait(0.12)
		local target, distance = nearestPlayer(f)
		if f.State == "KO" then
			task.wait(3)
			Fighters.reset(f)
			model:PivotTo(CFrame.new(home))
		elseif f.State == "Down" then
			-- dummies always beat the count, a bit slower each time
			Fighters.mash(f)
		elseif target and distance < 14 then
			face(f, target)
			local targetState = target.Model:GetAttribute("State")
			if spars then
				-- keep about a punch away
				if distance > 5 then
					f.Humanoid:MoveTo(target.Root.Position)
				elseif distance < 3.5 then
					f.Humanoid:MoveTo(f.Root.Position - f.Root.CFrame.LookVector * 3)
				else
					f.Humanoid:Move(Vector3.zero)
				end
				if targetState == "Windup" and random:NextNumber() < 0.3 then
					local dirs = { "Left", "Right", "Duck" }
					Fighters.slip(f, dirs[random:NextInteger(1, #dirs)])
				elseif targetState == "Windup" and random:NextNumber() < 0.35 then
					Fighters.setGuard(f, true)
					task.delay(0.6, function()
						Fighters.setGuard(f, false)
					end)
				elseif distance < 6 and os.clock() > nextPunch and not f.Guarding then
					-- easy enough to learn on, it throws about one punch a second and a half
					Fighters.punch(f, PUNCHES[random:NextInteger(1, #PUNCHES)])
					nextPunch = os.clock() + random:NextNumber(1.1, 2.2)
				end
			else
				-- the bag just covers up when you get going
				Fighters.setGuard(f, targetState == "Windup" and random:NextNumber() < 0.4)
			end
		else
			Fighters.setGuard(f, false)
		end
	end
end

local bagModel, bag = makeDummy("Punching Bag Dummy", spawns:WaitForChild("Spawn1") :: BasePart, Color3.fromRGB(120, 120, 125))
local sparModel, spar = makeDummy("Sparring Partner", spawns:WaitForChild("Spawn2") :: BasePart, Color3.fromRGB(170, 35, 40))
if bag then
	task.spawn(brain, bagModel, bag, false)
end
if spar then
	task.spawn(brain, sparModel, spar, true)
end
