--!strict
-- Computer boxers: the bag and sparring partner upstairs, and ring opponents when nobody else
-- shows up. One brain for all of them, ticking every 0.12s. Skill sets how often it punches,
-- how well it reads punches and how fast it beats the count.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Fighters = require(script.Parent.Fighters)
local Gear = require(script.Parent.Gear)

local random = Random.new()

local PUNCHES = { "Jab", "Jab", "Jab", "Cross", "Cross", "Hook", "Body", "Uppercut" }

export type Skill = {
	Gap: { number }, -- seconds between punches, min and max
	Parry: number, -- chance to time a guard on a straight
	Slip: number, -- chance to slip a punch it sees coming
	Cover: number, -- chance to cover up where it got hit last
	Mash: number, -- chance per tick to press to get up when down
	Bag: boolean?, -- only covers up, never throws
	Chase: boolean?, -- walks in from anywhere (a ring opponent), the upstairs ones wait for you
}

local AIBoxer = {}

-- the sparring partner's numbers. easy enough to learn on
AIBoxer.Easy = { Gap = { 1.1, 2.2 }, Parry = 0.2, Slip = 0.3, Cover = 0.35, Mash = 1 } :: Skill

-- ring opponents get harder with your rank (1 rookie .. 6 champion)
function AIBoxer.ringSkill(level: number): Skill
	local t = math.clamp((level - 1) / 5, 0, 1)
	return {
		Gap = { 1.3 - 0.7 * t, 2.2 - 1.1 * t },
		Parry = 0.15 + 0.3 * t,
		Slip = 0.2 + 0.3 * t,
		Cover = 0.3 + 0.2 * t,
		Mash = 0.35 + 0.45 * t,
		Chase = true,
	}
end

AIBoxer.Names = { "BIG TONY", "KID VEGA", "SMOKEY BLAKE", "EL TORO", "IRON OKAFOR", "DANNY REYES", "THE BUTCHER", "LUCKY NAKAMURA" }
AIBoxer.Shirts = { Color3.fromRGB(40, 70, 160), Color3.fromRGB(30, 120, 60), Color3.fromRGB(200, 140, 20), Color3.fromRGB(90, 40, 120), Color3.fromRGB(20, 20, 25) }

function AIBoxer.make(name: string, at: CFrame, shirt: Color3): (Model, Fighters.Fighter?)
	local description = Instance.new("HumanoidDescription")
	description.TorsoColor = shirt
	description.HeadColor = Color3.fromRGB(205, 160, 125)
	description.LeftArmColor, description.RightArmColor = description.HeadColor, description.HeadColor
	description.LeftLegColor, description.RightLegColor = Color3.fromRGB(30, 30, 35), Color3.fromRGB(30, 30, 35)
	local model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	model.Name = name
	model:PivotTo(at)
	model.Parent = workspace
	Gear.gloves(model)
	Gear.trunks(model)
	-- the server simulates them, a nearby client can't shove them around
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end
	return model, Fighters.register(model, nil)
end

-- the brain only thinks every 0.12s, so turning goes through a constraint that eases the
-- body round every frame instead of snapping it
local function turner(f: Fighters.Fighter): AlignOrientation
	local existing = f.Root:FindFirstChild("AITurn")
	if existing and existing:IsA("AlignOrientation") then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AITurnAttachment"
	attachment.Parent = f.Root
	local align = Instance.new("AlignOrientation")
	align.Name = "AITurn"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 25
	align.MaxTorque = math.huge
	align.CFrame = f.Root.CFrame.Rotation
	align.Parent = f.Root
	return align
end

local function face(f: Fighters.Fighter, target: Fighters.Fighter)
	local from = f.Root.Position
	local to = Vector3.new(target.Root.Position.X, from.Y, target.Root.Position.Z)
	if (to - from).Magnitude > 0.1 then
		turner(f).CFrame = CFrame.lookAt(from, to).Rotation
	end
end

-- turn to face a point right now (placed in a corner)
function AIBoxer.faceNow(f: Fighters.Fighter)
	turner(f).CFrame = f.Root.CFrame.Rotation
end

-- runs until the model is gone. target picks who to box each tick. onKO, if given, runs when
-- it's knocked out (the upstairs ones get back up at home), otherwise it stays down
function AIBoxer.run(f: Fighters.Fighter, skill: Skill, target: () -> Fighters.Fighter?, onKO: (() -> ())?)
	local model = f.Model
	f.Humanoid.AutoRotate = false
	local nextPunch = 0
	local decided: any = nil -- the last punch (by ActionToken) it already chose a reaction to
	while model.Parent do
		task.wait(0.12)
		if model:GetAttribute("TestFreeze") then
			continue
		end
		local other = target()
		local distance = if other then (other.Root.Position - f.Root.Position).Magnitude else math.huge
		if f.State == "KO" then
			if onKO then
				task.wait(3)
				onKO()
				turner(f).CFrame = f.Root.CFrame.Rotation
			end
		elseif f.State == "Down" then
			if random:NextNumber() < skill.Mash then
				Fighters.mash(f)
			end
		elseif other and distance < 14 then
			face(f, other)
			local targetState = other.Model:GetAttribute("State")
			if skill.Bag then
				-- the bag just covers up when you get going
				local cover = targetState == "Windup" and random:NextNumber() < 0.4
				Fighters.setGuard(f, if cover then (if f.LastTaken == "Body" then "Low" else "High") else nil, false)
				continue
			end
			-- keep about a punch away
			if distance > 5 then
				f.Humanoid:MoveTo(other.Root.Position)
			elseif distance < 3.5 then
				f.Humanoid:MoveTo(f.Root.Position - f.Root.CFrame.LookVector * 3)
			else
				f.Humanoid:Move(Vector3.zero)
			end
			local action = other.Model:GetAttribute("Action") :: string?
			local token = other.Model:GetAttribute("ActionToken")
			local fresh = targetState == "Windup" and token ~= decided
			if fresh then
				decided = token
			end
			if fresh and action and Config.ParryMoves[action] and not f.Guarding and random:NextNumber() < skill.Parry then
				-- time the guard to go up right before the straight lands
				local startup = (other.Model:GetAttribute("ActionLength") :: number?) or Config.Moves[action].Startup
				local started = (other.Model:GetAttribute("ActionStart") :: number?) or workspace:GetServerTimeNow()
				local raiseIn = started + startup - 0.07 - workspace:GetServerTimeNow()
				task.delay(math.max(raiseIn, 0), function()
					Fighters.setGuard(f, "High")
					task.delay(0.4, function()
						Fighters.setGuard(f, nil)
					end)
				end)
			elseif fresh and random:NextNumber() < skill.Slip then
				local dirs = { "Left", "Right", "Duck" }
				Fighters.slip(f, dirs[random:NextInteger(1, #dirs)])
			elseif fresh and random:NextNumber() < skill.Cover then
				-- guards where you hit it last, so switching levels opens it up
				Fighters.setGuard(f, if f.LastTaken == "Body" then "Low" else "High", false)
				task.delay(0.6, function()
					Fighters.setGuard(f, nil)
				end)
			elseif distance < 6 and os.clock() > nextPunch and not f.Guarding then
				Fighters.punch(f, PUNCHES[random:NextInteger(1, #PUNCHES)])
				nextPunch = os.clock() + random:NextNumber(skill.Gap[1], skill.Gap[2])
			end
		else
			Fighters.setGuard(f, nil)
			if skill.Chase and other then
				f.Humanoid:MoveTo(other.Root.Position)
			end
		end
	end
end

return AIBoxer
