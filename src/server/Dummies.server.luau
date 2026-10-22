--!strict
-- two practice opponents upstairs, a bag that covers up and a partner that fights back
local RunService = game:GetService("RunService")

local Fighters = require(script.Parent.Fighters)
local AIBoxer = require(script.Parent.AIBoxer)

-- the nearest player who isn't in a ring match
local function nearestPlayer(f: Fighters.Fighter): Fighters.Fighter?
	local best, bestDistance = nil, math.huge
	for model, other in Fighters.all() do
		if other.Player and model.Parent and other.State ~= "KO" and not other.Match then
			local d = (other.Root.Position - f.Root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = other, d
			end
		end
	end
	return best
end

local function start(name: string, spotName: string, shirt: Color3, skill: AIBoxer.Skill)
	local spot = workspace:WaitForChild("Map"):WaitForChild("Gym"):WaitForChild(spotName) :: BasePart
	local model, f = AIBoxer.make(name, spot.CFrame, shirt)
	if not f then
		return
	end
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
	task.spawn(AIBoxer.run, f, skill, function()
		return nearestPlayer(f)
	end, function()
		Fighters.reset(f)
		model:PivotTo(home)
	end)
end

-- both stand upstairs so the rings stay free for matches and you can only box them in a fight zone
start("Punching Bag Dummy", "BagSpot", Color3.fromRGB(120, 120, 125), { Gap = { 9, 9 }, Parry = 0, Slip = 0, Cover = 0, Mash = 1, Bag = true })
start("Sparring Partner", "SparSpot", Color3.fromRGB(170, 35, 40), AIBoxer.Easy)
