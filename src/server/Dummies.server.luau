--!strict
-- Two practice opponents upstairs: a bag that only covers up, and a sparring
-- partner that throws back, guards and slips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Fighters = require(script.Parent.Fighters)
local Gear = require(script.Parent.Gear)

local random = Random.new()

local PUNCHES = { "Jab", "Jab", "Jab", "Cross", "Cross", "Hook", "Body", "Uppercut" }

local function makeDummy(name: string, spawnPart: BasePart, shirt: Color3)
	local description = Instance.new("HumanoidDescription")
	description.TorsoColor = shirt
	description.HeadColor = Color3.fromRGB(205, 160, 125)
	description.LeftArmColor, description.RightArmColor = description.HeadColor, description.HeadColor
	description.LeftLegColor, description.RightLegColor = Color3.fromRGB(30, 30, 35), Color3.fromRGB(30, 30, 35)
	local model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
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
		if other.Player and model.Parent and other.State ~= "KO" and not other.Match then
			local d = (other.Root.Position - f.Root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = other, d
			end
		end
	end
	return best, bestDistance
end

-- the brain only thinks every 0.12s, so turning goes through a constraint that eases the
-- body round every frame instead of snapping it
local turners: { [Fighters.Fighter]: AlignOrientation } = {}
local function turner(f: Fighters.Fighter): AlignOrientation
	local existing = turners[f]
	if existing then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "TurnAttachment"
	attachment.Parent = f.Root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 25
	align.MaxTorque = math.huge
	align.PrimaryAxisOnly = false
	align.CFrame = f.Root.CFrame.Rotation
	align.Parent = f.Root
	turners[f] = align
	return align
end

local function face(f: Fighters.Fighter, target: Fighters.Fighter)
	local from = f.Root.Position
	local to = Vector3.new(target.Root.Position.X, from.Y, target.Root.Position.Z)
	if (to - from).Magnitude > 0.1 then
		turner(f).CFrame = CFrame.lookAt(from, to).Rotation
	end
end

-- the last punch (by ActionToken) each dummy already chose a reaction to
local decided: { [Fighters.Fighter]: any } = {}

local function brain(model: Model, f: Fighters.Fighter, spars: boolean)
	f.Humanoid.AutoRotate = false
	local nextPunch = 0
	local home = f.Root.CFrame
	-- studio only: tests can freeze the brain and make it punch or guard on cue
	if RunService:IsStudio() then
		model:GetAttributeChangedSignal("TestPunch"):Connect(function()
			local move = model:GetAttribute("TestPunch")
			if typeof(move) == "string" and move ~= "" then
				Fighters.punch(f, move)
			end
		end)
		model:GetAttributeChangedSignal("TestCourage"):Connect(function()
			local c = model:GetAttribute("TestCourage")
			if typeof(c) == "number" then
				f.Courage = c
			end
		end)
		model:GetAttributeChangedSignal("TestGuard"):Connect(function()
			local h = model:GetAttribute("TestGuard")
			Fighters.setGuard(f, if h == "High" or h == "Low" then h else nil)
		end)
	end
	while model.Parent do
		task.wait(0.12)
		if model:GetAttribute("TestFreeze") then
			continue
		end
		local target, distance = nearestPlayer(f)
		if f.State == "KO" then
			task.wait(3)
			Fighters.reset(f)
			model:PivotTo(home)
			turner(f).CFrame = f.Root.CFrame.Rotation
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
				local action = target.Model:GetAttribute("Action") :: string?
				local token = target.Model:GetAttribute("ActionToken")
				local fresh = targetState == "Windup" and token ~= decided[f]
				if fresh then
					decided[f] = token
				end
				if fresh and action and Config.ParryMoves[action] and not f.Guarding and random:NextNumber() < 0.2 then
					-- time the guard to go up right before the straight lands
					local startup = (target.Model:GetAttribute("ActionLength") :: number?) or Config.Moves[action].Startup
					local started = (target.Model:GetAttribute("ActionStart") :: number?) or workspace:GetServerTimeNow()
					local raiseIn = started + startup - 0.07 - workspace:GetServerTimeNow()
					task.delay(math.max(raiseIn, 0), function()
						Fighters.setGuard(f, "High")
						task.delay(0.4, function()
							Fighters.setGuard(f, nil)
						end)
					end)
				elseif fresh and random:NextNumber() < 0.3 then
					local dirs = { "Left", "Right", "Duck" }
					Fighters.slip(f, dirs[random:NextInteger(1, #dirs)])
				elseif fresh and random:NextNumber() < 0.35 then
					-- guards where you hit it last, so switching levels opens it up
					Fighters.setGuard(f, if f.LastTaken == "Body" then "Low" else "High", false)
					task.delay(0.6, function()
						Fighters.setGuard(f, nil)
					end)
				elseif distance < 6 and os.clock() > nextPunch and not f.Guarding then
					-- easy enough to learn on, it throws about one punch a second and a half
					Fighters.punch(f, PUNCHES[random:NextInteger(1, #PUNCHES)])
					nextPunch = os.clock() + random:NextNumber(1.1, 2.2)
				end
			else
				-- the bag just covers up when you get going
				local cover = targetState == "Windup" and random:NextNumber() < 0.4
				Fighters.setGuard(f, if cover then (if f.LastTaken == "Body" then "Low" else "High") else nil, false)
			end
		else
			Fighters.setGuard(f, nil)
		end
	end
end

-- both stand upstairs so the ring stays free for matches and you can only box them in a fight zone
local bagModel, bag = makeDummy(
	"Punching Bag Dummy",
	workspace:WaitForChild("Map"):WaitForChild("Gym"):WaitForChild("BagSpot") :: BasePart,
	Color3.fromRGB(120, 120, 125)
)
local sparModel, spar = makeDummy(
	"Sparring Partner",
	workspace:WaitForChild("Map"):WaitForChild("Gym"):WaitForChild("SparSpot") :: BasePart,
	Color3.fromRGB(170, 35, 40)
)
if bag then
	task.spawn(brain, bagModel, bag, false)
end
if spar then
	task.spawn(brain, sparModel, spar, true)
end
