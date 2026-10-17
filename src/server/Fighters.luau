--!strict
-- Every boxer (player or dummy) is a Fighter. The server owns all of this; the character
-- just carries attributes so clients can animate it and draw the HUD.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

export type Fighter = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Player: Player?,
	Health: number,
	Stamina: number,
	Guard: number,
	State: string, -- Idle, Windup, Recovery, Stunned, Down, KO
	Guarding: boolean,
	BusyUntil: number,
	Slip: string?,
	SlipUntil: number,
	NextSlip: number,
	CounterUntil: number,
	LastHit: number,
	Knockdowns: number,
	GetUpPresses: number,
	DownToken: number,
	ActionToken: number,
	Opponent: Model?,
}

local Fighters = {}
local byModel: { [Model]: Fighter } = {}

local fx: RemoteEvent? = nil
function Fighters.setFxRemote(remote: RemoteEvent)
	fx = remote
end
local function broadcast(...: any)
	if fx then
		fx:FireAllClients(...)
	end
end

local function publish(f: Fighter)
	local m = f.Model
	m:SetAttribute("Health", math.floor(f.Health + 0.5))
	m:SetAttribute("Stamina", math.floor(f.Stamina + 0.5))
	m:SetAttribute("Guard", math.floor(f.Guard + 0.5))
	m:SetAttribute("State", f.State)
	m:SetAttribute("Guarding", f.Guarding)
	m:SetAttribute("Knockdowns", f.Knockdowns)
end

local function setWalk(f: Fighter)
	local busy = f.State ~= "Idle"
	f.Humanoid.WalkSpeed = if f.State == "Down" or f.State == "KO" or f.State == "Stunned" then 0
		elseif f.Guarding or busy then Config.GuardWalkSpeed
		else Config.WalkSpeed
	f.Humanoid.JumpHeight = 0
end

function Fighters.register(model: Model, player: Player?): Fighter?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return nil
	end
	local f: Fighter = {
		Model = model, Root = root, Humanoid = humanoid, Player = player,
		Health = Config.MaxHealth, Stamina = Config.MaxStamina, Guard = Config.MaxGuard,
		State = "Idle", Guarding = false, BusyUntil = 0,
		Slip = nil, SlipUntil = 0, NextSlip = 0, CounterUntil = 0, LastHit = 0,
		Knockdowns = 0, GetUpPresses = 0, DownToken = 0, ActionToken = 0, Opponent = nil,
	}
	byModel[model] = f
	-- Roblox health isn't used for boxing, keep the humanoid alive
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	CollectionService:AddTag(model, "Fighter")
	model.Destroying:Once(function()
		byModel[model] = nil
	end)
	publish(f)
	setWalk(f)
	return f
end

function Fighters.get(model: Instance?): Fighter?
	return if model and model:IsA("Model") then byModel[model] else nil
end

function Fighters.all(): { [Model]: Fighter }
	return byModel
end

function Fighters.reset(f: Fighter)
	f.Health, f.Stamina, f.Guard = Config.MaxHealth, Config.MaxStamina, Config.MaxGuard
	f.State, f.Guarding, f.Slip, f.Knockdowns = "Idle", false, nil, 0
	f.DownToken += 1
	publish(f)
	setWalk(f)
	f.Model:SetAttribute("DownCount", nil)
end

local function canAct(f: Fighter): boolean
	return f.State == "Idle" and os.clock() >= f.BusyUntil
end

local function setState(f: Fighter, state: string, untilTime: number?)
	f.State = state
	if untilTime then
		f.BusyUntil = untilTime
	end
	publish(f)
	setWalk(f)
end

local function playAction(f: Fighter, action: string)
	f.ActionToken += 1
	f.Model:SetAttribute("Action", action)
	f.Model:SetAttribute("ActionStart", workspace:GetServerTimeNow())
	f.Model:SetAttribute("ActionToken", f.ActionToken)
end

-- closest fighter in front of the attacker within range
local function findTarget(f: Fighter, range: number): Fighter?
	local best, bestDistance = nil, math.huge
	local look = f.Root.CFrame.LookVector
	for model, other in byModel do
		if other ~= f and model.Parent and other.State ~= "KO" then
			local offset = other.Root.Position - f.Root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if distance <= range and math.abs(offset.Y) < 4 and distance > 0.01 then
				local facing = flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit)
				if facing >= Config.HitCone and distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

local function knockDown(target: Fighter, attacker: Fighter)
	target.Knockdowns += 1
	target.Guarding = false
	target.Slip = nil
	if target.Knockdowns >= Config.MaxKnockdowns then
		setState(target, "KO")
		broadcast("KO", target.Model, attacker.Model)
		return
	end
	setState(target, "Down")
	target.GetUpPresses = 0
	target.DownToken += 1
	local token = target.DownToken
	broadcast("Down", target.Model, attacker.Model)
	task.spawn(function()
		for count = 1, Config.DownCount do
			target.Model:SetAttribute("DownCount", count)
			task.wait(1)
			if target.DownToken ~= token or target.State ~= "Down" then
				return
			end
		end
		-- counted out
		target.Model:SetAttribute("DownCount", nil)
		setState(target, "KO")
		broadcast("KO", target.Model, attacker.Model)
	end)
end

local function getUp(f: Fighter)
	f.DownToken += 1
	f.Model:SetAttribute("DownCount", nil)
	f.Health = Config.HealthAfterDown[math.min(f.Knockdowns, #Config.HealthAfterDown)]
	f.Guard = Config.MaxGuard * 0.5
	f.Stamina = math.max(f.Stamina, Config.MaxStamina * 0.5)
	setState(f, "Recovery", os.clock() + 0.6)
	playAction(f, "GetUp")
	broadcast("GetUp", f.Model)
	task.delay(0.6, function()
		if f.State == "Recovery" then
			setState(f, "Idle")
		end
	end)
end

local function stun(target: Fighter, seconds: number)
	local untilTime = os.clock() + seconds
	-- getting hit cancels a punch you were winding up
	setState(target, "Stunned", untilTime)
	task.delay(seconds, function()
		if target.State == "Stunned" and os.clock() >= target.BusyUntil - 0.01 then
			setState(target, "Idle")
		end
	end)
end

local function resolveHit(attacker: Fighter, moveName: string, counter: boolean)
	local move = Config.Moves[moveName]
	local target = findTarget(attacker, move.Range)
	if not target or target.State == "Down" or target.State == "KO" then
		broadcast("Whiff", attacker.Model, moveName)
		return
	end
	local now = os.clock()
	target.LastHit = now
	attacker.Opponent = target.Model
	target.Opponent = attacker.Model

	-- slips
	if target.Slip and now < target.SlipUntil then
		if move.BeatsSlip and move.BeatsSlip[target.Slip] then
			counter = true
		elseif move.DodgedBy[target.Slip] then
			target.CounterUntil = now + Config.CounterWindow
			target.Model:SetAttribute("CounterUntil", workspace:GetServerTimeNow() + Config.CounterWindow)
			broadcast("Slipped", target.Model, attacker.Model, moveName)
			return
		end
	end

	local damage = move.Damage
	if counter then
		damage *= if move.BeatsSlip and target.Slip and move.BeatsSlip[target.Slip] then Config.SlipPunishBonus else Config.CounterBonus
	end

	local result = if counter then "Counter" else "Clean"
	if target.Guarding and target.State ~= "Stunned" then
		target.Guard -= move.GuardDamage * (if counter then 1.5 else 1)
		if target.Guard <= 0 then
			target.Guard = 0
			target.Guarding = false
			result = "GuardBreak"
			damage *= 0.5
			stun(target, Config.GuardBreakStun)
		elseif move.ThroughGuard > 0 then
			result = "Chip"
			damage *= move.ThroughGuard
		else
			result = "Blocked"
			damage = 0
		end
	end

	if move.BodyDrain then
		target.Stamina = math.max(0, target.Stamina - move.BodyDrain * (if result == "Blocked" then 0.5 else 1))
	end
	target.Health -= damage

	if result == "Clean" or result == "Counter" then
		stun(target, move.Hitstun * (if counter then 1.4 else 1))
	end
	broadcast("Hit", attacker.Model, target.Model, moveName, result, math.floor(damage + 0.5))

	if target.Health <= 0 then
		target.Health = 0
		knockDown(target, attacker)
	end
	publish(target)
end

local buffered: { [Fighter]: number } = setmetatable({}, { __mode = "k" }) :: any

function Fighters.punch(f: Fighter, moveName: string)
	local move = Config.Moves[moveName]
	if not move or f.Guarding then
		return
	end
	if not canAct(f) then
		-- pressed a little early (end of a slip or punch): hold it and throw it the moment you're free
		local wait = f.BusyUntil - os.clock()
		if (f.State == "Recovery" or f.State == "Windup") and wait > 0 and wait <= Config.InputBuffer and not buffered[f] then
			local token = f.ActionToken
			buffered[f] = token
			task.delay(wait + 0.01, function()
				if buffered[f] == token then
					buffered[f] = nil
					Fighters.punch(f, moveName)
				end
			end)
		end
		return
	end
	buffered[f] = nil
	if f.Stamina < move.Stamina then
		return
	end
	local now = os.clock()
	local counter = now < f.CounterUntil
	f.CounterUntil = 0
	f.Model:SetAttribute("CounterUntil", nil)
	f.Stamina -= move.Stamina
	local slow = if f.Stamina < Config.GassedBelow then Config.GassedSlowdown else 1
	local startup, recovery = move.Startup * slow, move.Recovery * slow
	setState(f, "Windup", now + startup + recovery)
	playAction(f, moveName)
	f.Model:SetAttribute("ActionLength", startup)
	local token = f.ActionToken
	task.delay(startup, function()
		-- a hit during wind up interrupts the punch
		if f.ActionToken ~= token or f.State ~= "Windup" then
			return
		end
		setState(f, "Recovery")
		resolveHit(f, moveName, counter)
		task.delay(recovery, function()
			if f.ActionToken == token and f.State == "Recovery" then
				setState(f, "Idle")
			end
		end)
	end)
end

function Fighters.setGuard(f: Fighter, on: boolean)
	if on and (f.State == "Down" or f.State == "KO" or f.State == "Stunned") then
		return
	end
	if f.Guarding ~= on then
		f.Guarding = on
		publish(f)
		setWalk(f)
	end
end

function Fighters.slip(f: Fighter, direction: string)
	local now = os.clock()
	if not canAct(f) or now < f.NextSlip or f.Stamina < Config.SlipCost then
		return
	end
	if direction ~= "Left" and direction ~= "Right" and direction ~= "Duck" and direction ~= "Back" then
		return
	end
	f.Stamina -= Config.SlipCost
	f.Slip = direction
	f.SlipUntil = now + Config.SlipTime
	f.NextSlip = now + Config.SlipCooldown
	f.Guarding = false
	setState(f, "Recovery", now + Config.SlipTime)
	playAction(f, "Slip" .. direction)
	if direction == "Back" then
		-- step back out of range
		f.Root.AssemblyLinearVelocity = -f.Root.CFrame.LookVector * 40
	end
	task.delay(Config.SlipTime, function()
		if f.Slip == direction then
			f.Slip = nil
		end
		if f.State == "Recovery" and os.clock() >= f.BusyUntil - 0.01 then
			setState(f, "Idle")
		end
	end)
end

function Fighters.mash(f: Fighter)
	if f.State ~= "Down" then
		return
	end
	f.GetUpPresses += 1
	local needed = Config.GetUpPresses[math.min(f.Knockdowns, #Config.GetUpPresses)]
	f.Model:SetAttribute("GetUpProgress", f.GetUpPresses / needed)
	if f.GetUpPresses >= needed then
		f.Model:SetAttribute("GetUpProgress", nil)
		getUp(f)
	end
end

-- stamina and guard come back over time
function Fighters.tick(dt: number)
	local now = os.clock()
	for _, f in byModel do
		if f.State ~= "Down" and f.State ~= "KO" then
			local changed = false
			local regen = Config.StaminaRegen * (if f.Guarding then 0.5 else 1) * dt
			if f.Stamina < Config.MaxStamina and f.State == "Idle" then
				f.Stamina = math.min(Config.MaxStamina, f.Stamina + regen)
				changed = true
			end
			if f.Guard < Config.MaxGuard and now - f.LastHit > Config.GuardRegenDelay then
				f.Guard = math.min(Config.MaxGuard, f.Guard + Config.GuardRegen * dt)
				changed = true
			end
			if changed then
				publish(f)
			end
		end
	end
end

return Fighters
