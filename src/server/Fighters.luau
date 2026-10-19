--!strict
-- Every boxer (player or dummy) is a Fighter. The server owns all of this; the character
-- just carries attributes so clients can animate it and draw the HUD.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Stats = require(ReplicatedStorage.Shared.Stats)
local PlayerData = require(script.Parent.PlayerData)
local Career = require(script.Parent.Career)

export type Fighter = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Player: Player?,
	Health: number,
	Stamina: number,
	Guard: number,
	State: string, -- Idle, Windup, Recovery, Stunned, Switching, Down, KO
	Guarding: boolean,
	GuardHeight: string?, -- "High" or "Low" while guarding
	GuardReadyAt: number, -- hands are still moving until this
	Weaving: boolean,
	SlipChain: number,
	LastSlip: number,
	Bobbing: boolean, -- current slip was done with the guard up
	LastTaken: string?, -- "Head" or "Body", where the last punch at this fighter went
	GuardPressedAt: number, -- when the guard last went up from nothing after being down a while (parry timing)
	GuardDroppedAt: number,
	Whiffed: boolean, -- the punch being recovered from hit nothing
	CounterMult: number, -- bonus for the open counter window (slip or parry)
	GassedToldAt: number,
	MaxHealthNow: number, -- max health left this fight, clean head shots wear it down
	Courage: number,
	SecondWindUsed: boolean,
	FiredUpUntil: number, -- os.clock(), second wind boost
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
	Stance: string,
	NextSwitch: number,
	SpecialReady: { [string]: number },
	Stats: { [string]: number }, -- the saved stats for players, empty for dummies
	Match: string?, -- fighters in a match only hit each other
	FightMode: boolean, -- players only box inside a fight zone (the ring, upstairs), dummies always
	Drilling: boolean, -- on a training drill: boxing stance, planted feet
}

local Fighters = {}

-- anyone who wants to know about landed hits and knockdowns (Matches scores fights with these).
-- a list, so two rings running at once each keep their own score
type HitListener = (attacker: Fighter, target: Fighter, damage: number, result: string) -> ()
type DownListener = (target: Fighter, attacker: Fighter) -> ()
local hitListeners: { HitListener } = {}
local downListeners: { DownListener } = {}
local function listen<T>(list: { T }, fn: T): () -> ()
	table.insert(list, fn)
	return function()
		local i = table.find(list, fn)
		if i then
			table.remove(list, i)
		end
	end
end
-- each returns a function that stops listening
function Fighters.onHit(fn: HitListener): () -> ()
	return listen(hitListeners, fn)
end
function Fighters.onDown(fn: DownListener): () -> ()
	return listen(downListeners, fn)
end
local byModel: { [Model]: Fighter } = {}

local fx = require(script.Parent.Remotes).Fx
local function broadcast(...: any)
	fx:FireAllClients(...)
end

-- just to the fighter's own player, for things only they need to see
local function tell(f: Fighter, ...: any)
	if f.Player then
		fx:FireClient(f.Player, ...)
	end
end

local function publish(f: Fighter)
	local m = f.Model
	m:SetAttribute("Health", math.floor(f.Health + 0.5))
	m:SetAttribute("Stamina", math.floor(f.Stamina + 0.5))
	m:SetAttribute("Guard", math.floor(f.Guard + 0.5))
	m:SetAttribute("State", f.State)
	m:SetAttribute("Guarding", f.Guarding)
	m:SetAttribute("GuardHeight", f.GuardHeight)
	m:SetAttribute("Weaving", f.Weaving)
	m:SetAttribute("Knockdowns", f.Knockdowns)
	m:SetAttribute("MaxHealthNow", math.floor(f.MaxHealthNow + 0.5))
	m:SetAttribute("Courage", math.floor(f.Courage + 0.5))
	m:SetAttribute("Stance", f.Stance)
end

local function firedUp(f: Fighter): boolean
	return os.clock() < f.FiredUpUntil
end

local function addCourage(f: Fighter, reason: string)
	local gain = Config.CourageGain[reason] or 0
	if gain > 0 then
		gain *= 1 + Stats.bonus(f.Stats, "Willpower")
	end
	f.Courage = math.clamp(f.Courage + gain, 0, Config.MaxCourage)
end

local function setWalk(f: Fighter)
	if f.Drilling then
		f.Humanoid.WalkSpeed = 0
		f.Humanoid.AutoRotate = false
		return
	end
	f.Humanoid.AutoRotate = true
	if not f.FightMode then
		f.Humanoid.WalkSpeed = Config.StreetWalkSpeed
		-- set both, the character can be on either jump mode
		f.Humanoid.JumpHeight = Config.StreetJumpHeight
		f.Humanoid.JumpPower = Config.StreetJumpPower
		return
	end
	local busy = f.State ~= "Idle"
	f.Humanoid.WalkSpeed = if f.State == "Down"
			or f.State == "KO"
			or f.State == "Stunned"
		then 0
		elseif f.Weaving then Config.WeaveWalkSpeed
		elseif
			(f.State == "Windup" or f.State == "Recovery") and Config.Moves[f.Model:GetAttribute("Action")]
		then Config.Moves[f.Model:GetAttribute("Action")].MoveSpeed
		elseif f.Guarding or busy then Config.GuardWalkSpeed
		else Config.WalkSpeed
	-- stances tweak how fast you move, but never wake up a planted fighter
	if f.Humanoid.WalkSpeed > 0 then
		f.Humanoid.WalkSpeed = math.max(1, f.Humanoid.WalkSpeed + Config.Stances[f.Stance].WalkBonus)
	end
	f.Humanoid.JumpHeight = 0
	f.Humanoid.JumpPower = 0
end

function Fighters.register(model: Model, player: Player?, stats: { [string]: number }?): Fighter?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return nil
	end
	local f: Fighter = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Player = player,
		Health = Config.MaxHealth,
		Stamina = Config.MaxStamina,
		Guard = Config.MaxGuard,
		State = "Idle",
		Guarding = false,
		GuardHeight = nil,
		GuardReadyAt = 0,
		BusyUntil = 0,
		Weaving = false,
		SlipChain = 0,
		LastSlip = 0,
		Bobbing = false,
		LastTaken = nil,
		GuardPressedAt = 0,
		GuardDroppedAt = 0,
		Whiffed = false,
		CounterMult = Config.CounterBonus,
		GassedToldAt = 0,
		MaxHealthNow = Config.MaxHealth,
		Courage = 0,
		SecondWindUsed = false,
		FiredUpUntil = 0,
		Slip = nil,
		SlipUntil = 0,
		NextSlip = 0,
		CounterUntil = 0,
		LastHit = 0,
		Knockdowns = 0,
		GetUpPresses = 0,
		DownToken = 0,
		ActionToken = 0,
		Opponent = nil,
		Stance = Config.Loadout[1],
		NextSwitch = 0,
		SpecialReady = {},
		Stats = stats or {},
		Match = nil,
		FightMode = true,
		Drilling = false,
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
	f.State, f.Guarding, f.GuardHeight, f.Slip, f.Knockdowns = "Idle", false, nil, nil, 0
	f.Weaving = false
	f.MaxHealthNow, f.Courage, f.SecondWindUsed, f.FiredUpUntil = Config.MaxHealth, 0, false, 0
	f.Model:SetAttribute("FiredUpUntil", nil)
	f.DownToken += 1
	publish(f)
	setWalk(f)
	f.Model:SetAttribute("DownCount", nil)
end

local function canAct(f: Fighter): boolean
	return f.FightMode and f.State == "Idle" and os.clock() >= f.BusyUntil
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
		if other ~= f and model.Parent and other.State ~= "KO" and other.Match == f.Match then
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

local getUp: (f: Fighter, secondWind: boolean?) -> ()

local function secondWindChance(courage: number): number
	for _, tier in Config.SecondWindChance do
		if courage >= tier.At then
			return tier.Chance
		end
	end
	return 0
end

local function knockDown(target: Fighter, attacker: Fighter)
	target.Knockdowns += 1
	target.Guarding = false
	target.GuardHeight = nil
	target.Weaving = false
	target.Slip = nil
	for _, fn in table.clone(downListeners) do
		task.spawn(fn, target, attacker)
	end
	if target.Knockdowns >= Config.MaxKnockdowns then
		setState(target, "KO")
		broadcast("KO", target.Model, attacker.Model)
		return
	end
	addCourage(target, "KnockedDown")
	setState(target, "Down")
	target.GetUpPresses = 0
	target.DownToken += 1
	local token = target.DownToken
	broadcast("Down", target.Model, attacker.Model)
	-- once a fight, enough courage drags you back up on its own
	if not target.SecondWindUsed and math.random() < secondWindChance(target.Courage) then
		target.SecondWindUsed = true
		task.delay(Config.SecondWindDelay, function()
			if target.DownToken == token and target.State == "Down" then
				getUp(target, true)
			end
		end)
	end
	task.spawn(function()
		for count = 1, Config.DownCount do
			target.Model:SetAttribute("DownCount", count)
			broadcast("Count", target.Model, count)
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

function getUp(f: Fighter, secondWind: boolean?)
	f.DownToken += 1
	f.Model:SetAttribute("DownCount", nil)
	f.Model:SetAttribute("GetUpProgress", nil)
	f.Guard = Config.MaxGuard * 0.5
	f.Stamina = math.max(f.Stamina, Config.MaxStamina * 0.5)
	if secondWind then
		f.MaxHealthNow += Config.SecondWindMaxHealth
		f.Health = f.MaxHealthNow * Config.SecondWindHealth
		f.Stamina = Config.MaxStamina
		f.Courage = 0
		f.FiredUpUntil = os.clock() + Config.FiredUpTime
		f.Model:SetAttribute("FiredUpUntil", workspace:GetServerTimeNow() + Config.FiredUpTime)
	else
		f.Health = math.min(Config.HealthAfterDown[math.min(f.Knockdowns, #Config.HealthAfterDown)], f.MaxHealthNow)
		addCourage(f, "GotUp")
		if f.Player then
			PlayerData.add(f.Player, "Willpower", Stats.FightGain.Willpower)
		end
	end
	setState(f, "Recovery", os.clock() + 0.6)
	playAction(f, "GetUp")
	if secondWind then
		broadcast("SecondWind", f.Model, math.random(1, #Config.SecondWindLines))
	else
		broadcast("GetUp", f.Model)
	end
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

local function openCounter(f: Fighter, seconds: number, mult: number)
	f.CounterUntil = os.clock() + seconds
	f.CounterMult = mult
	f.Model:SetAttribute("CounterUntil", workspace:GetServerTimeNow() + seconds)
end

-- straight into a guard that went up in the last moment, after being down a while
local function parried(target: Fighter, moveName: string, now: number): boolean
	return Config.ParryMoves[moveName] == true
		and target.GuardHeight == "High"
		and target.State ~= "Stunned"
		and now - target.GuardPressedAt <= Config.ParryWindow
		and target.Stamina >= Config.ParryCost
end

-- slipBonus is set when the attacker threw this out of an open counter window
local function resolveHit(attacker: Fighter, moveName: string, slipBonus: number?)
	local move = Config.Moves[moveName]
	local target = findTarget(attacker, move.Range)
	if not target or target.State == "Down" or target.State == "KO" then
		attacker.Whiffed = true
		broadcast("Whiff", attacker.Model, moveName)
		return
	end
	local now = os.clock()
	target.LastHit = now
	target.LastTaken = move.Target
	attacker.Opponent = target.Model
	target.Opponent = attacker.Model

	local mult, hitstun, counterName = 1, 1, nil
	if slipBonus then
		mult, hitstun, counterName = slipBonus, 1.4, "COUNTER"
	end

	-- slips
	if target.Slip and now < target.SlipUntil then
		if move.BeatsSlip and move.BeatsSlip[target.Slip] then
			mult, hitstun, counterName = math.max(mult, Config.SlipPunishBonus), 1.4, "COUNTER"
		elseif move.DodgedBy[target.Slip] then
			-- a slip with the guard up is safer but doesn't set up a counter
			if not target.Bobbing then
				openCounter(target, Config.CounterWindow, Config.CounterBonus)
			end
			attacker.Whiffed = true
			addCourage(target, "Slipped")
			broadcast("Slipped", target.Model, attacker.Model, moveName)
			return
		end
	end

	if parried(target, moveName, now) then
		target.Stamina -= Config.ParryCost
		addCourage(target, "Parried")
		openCounter(target, Config.ParryCounterWindow, Config.ParryCounterBonus)
		stun(attacker, Config.ParryStun)
		broadcast("Parried", target.Model, attacker.Model, moveName)
		publish(target)
		return
	end

	-- read counters: what you hit them with against what they were throwing
	local theirs = target.Model:GetAttribute("Action")
	if target.State == "Windup" and typeof(theirs) == "string" and Config.Moves[theirs] then
		local c = (Config.Counters[moveName] and Config.Counters[moveName][theirs]) or Config.StopCounter
		if c.Damage > mult then
			mult, hitstun, counterName = c.Damage, c.Hitstun, c.Name
		end
	elseif target.State == "Recovery" and target.Whiffed and Config.PunishBonus > mult then
		mult, hitstun, counterName = Config.PunishBonus, 1.2, "PUNISHED"
	end
	local counter = counterName ~= nil
	local damage = move.Damage
		* mult
		* (1 + Stats.bonus(attacker.Stats, "Power"))
		* (1 - Stats.bonus(target.Stats, "Endurance"))

	local result = if counter then "Counter" else "Clean"
	local covering = target.Guarding and target.State ~= "Stunned" and now >= target.GuardReadyAt
	local bodyShot = move.Target == "Body"
	if covering and (target.GuardHeight == "Low") ~= bodyShot then
		-- guarding the wrong place, it lands clean
		covering = false
		if not counter then
			result = "Open"
		end
		if not bodyShot then
			damage *= Config.LowGuardHeadBonus
		end
	end
	if covering then
		counterName = nil
		target.Guard -= move.GuardDamage * (if counter then 1.5 else 1) * (if firedUp(target)
			then Config.FiredUpGuard
			else 1) * Config.Stances[target.Stance].GuardTaken * (1 + Stats.bonus(attacker.Stats, "Technique"))
		if target.Guard <= 0 then
			target.Guard = 0
			target.Guarding = false
			target.GuardHeight = nil
			result = "GuardBreak"
			damage *= 0.5
			stun(target, Config.GuardBreakStun)
		elseif move.ThroughGuard > 0 and not bodyShot then
			result = "Chip"
			damage *= move.ThroughGuard
		else
			result = "Blocked"
			damage = 0
		end
	end

	if move.BodyDrain then
		local drain = move.BodyDrain
			* (if result == "Blocked" then 0.5 else 1)
			* (if counterName == "BODY COUNTER" then 2 else 1)
		target.Stamina = math.max(0, target.Stamina - drain)
	end
	-- a cross counter on someone already hurt puts them down
	if counterName == "CROSS COUNTER" and target.Health < Config.CrossCounterKnockdownBelow then
		damage = math.max(damage, target.Health)
	end
	target.Health -= damage
	for _, fn in table.clone(hitListeners) do
		task.spawn(fn, attacker, target, damage, result)
	end

	if result == "Clean" or result == "Counter" or result == "Open" then
		stun(target, move.Hitstun * hitstun)
		addCourage(attacker, if result == "Counter" then "CounterLanded" else "CleanLanded")
		addCourage(target, "CleanTaken")
		if attacker.Player then
			PlayerData.landed(attacker.Player)
			Career.event(attacker.Player, "Hit")
		end
		if target.Player and PlayerData.foughtRecently(target.Player) then
			PlayerData.add(target.Player, "Endurance", Stats.FightGain.Endurance)
		end
		-- clean head shots stick for the rest of the fight
		if not bodyShot then
			target.MaxHealthNow =
				math.max(Config.MinMaxHealth, target.MaxHealthNow - damage * Config.LastingDamageShare)
			target.Health = math.min(target.Health, target.MaxHealthNow)
		end
		publish(attacker)
	end
	broadcast("Hit", attacker.Model, target.Model, moveName, result, math.floor(damage + 0.5), counterName)

	if target.Health <= 0 then
		target.Health = 0
		knockDown(target, attacker)
	end
	publish(target)
end

local buffered: { [Fighter]: number } = setmetatable({}, { __mode = "k" }) :: any

-- winds up and lands one move. onDone runs at the end of recovery instead of going back to
-- Idle, that's how specials chain hits. a hit during wind up breaks the chain
local function throw(f: Fighter, moveName: string, counter: number?, onDone: (() -> ())?)
	local move = Config.Moves[moveName]
	local now = os.clock()
	local slow = (if f.Stamina < Config.GassedBelow then Config.GassedSlowdown else 1)
		* (if firedUp(f) then Config.FiredUpSpeed else 1)
	local startup = move.Startup
		* slow
		* (Config.Stances[f.Stance].StartupMult[moveName] or 1)
		* (1 - Stats.bonus(f.Stats, "Speed"))
	local recovery = move.Recovery * slow
	setState(f, "Windup", now + startup + recovery)
	-- set before playAction so clients reading the new ActionToken see this punch's length
	f.Model:SetAttribute("ActionLength", startup)
	playAction(f, moveName)
	-- plant the feet now that Action is set
	setWalk(f)
	local token = f.ActionToken
	task.delay(startup, function()
		if f.ActionToken ~= token or f.State ~= "Windup" then
			return
		end
		setState(f, "Recovery")
		-- dummies get their step-in here, players push themselves on their own client (they own the physics)
		if not f.Player then
			local look = f.Root.CFrame.LookVector
			local ends = os.clock() + 0.12
			local push: RBXScriptConnection
			push = RunService.Heartbeat:Connect(function(dt)
				if os.clock() > ends or not f.Root.Parent then
					push:Disconnect()
					return
				end
				f.Root.CFrame += look * move.Step * dt
			end)
		end
		resolveHit(f, moveName, counter)
		task.delay(recovery, function()
			if f.ActionToken == token and f.State == "Recovery" then
				if onDone then
					onDone()
				else
					setState(f, "Idle")
				end
			end
		end)
	end)
end

-- the open counter window gets spent on whatever you throw next
local function takeCounter(f: Fighter): number?
	local counter = if os.clock() < f.CounterUntil then f.CounterMult else nil
	f.CounterUntil = 0
	f.Model:SetAttribute("CounterUntil", nil)
	return counter
end

local function tellGassed(f: Fighter)
	-- otherwise the punch just silently doesn't come out
	if os.clock() - f.GassedToldAt > 0.6 then
		f.GassedToldAt = os.clock()
		tell(f, "Gassed")
	end
end

function Fighters.punch(f: Fighter, moveName: string)
	local move = Config.Moves[moveName]
	if not move or move.Special or f.Guarding then
		return
	end
	if not canAct(f) then
		-- pressed a little early (end of a slip or punch): hold it and throw it the moment you're free
		local wait = f.BusyUntil - os.clock()
		if
			(f.State == "Recovery" or f.State == "Windup")
			and wait > 0
			and wait <= Config.InputBuffer
			and not buffered[f]
		then
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
		tellGassed(f)
		return
	end
	f.Whiffed = false
	local counter = takeCounter(f)
	f.Stamina -= move.Stamina * (1 - Stats.bonus(f.Stats, "Stamina"))
	throw(f, moveName, counter)
end

-- slot 1 is Z, slot 2 is X. which special that is depends on your stance
function Fighters.special(f: Fighter, slot: number)
	local name = Config.Stances[f.Stance].Specials[slot]
	local sp = name and Config.Specials[name]
	if not sp or f.Guarding or not canAct(f) or (f.Player and not Stats.unlocked(f.Stats, name)) then
		return
	end
	local now = os.clock()
	if now < (f.SpecialReady[name] or 0) or (sp.OnlyInCounter and now >= f.CounterUntil) then
		return
	end
	if f.Stamina < sp.Stamina then
		tellGassed(f)
		return
	end
	buffered[f] = nil
	f.Whiffed = false
	local counter = takeCounter(f)
	f.Stamina -= sp.Stamina * (1 - Stats.bonus(f.Stats, "Stamina"))
	f.SpecialReady[name] = now + sp.Cooldown
	f.Model:SetAttribute("Ready" .. name, workspace:GetServerTimeNow() + sp.Cooldown)
	broadcast("Special", f.Model, name)
	local i = 0
	local function nextHit()
		i += 1
		-- only the first hit cashes in the counter window
		throw(f, sp.Chain[i], if i == 1 then counter else nil, if i < #sp.Chain then nextHit else nil)
	end
	nextHit()
end

-- G cycles through your loadout. a short beat where you can't punch or guard, then a cooldown
function Fighters.switchStance(f: Fighter)
	local now = os.clock()
	if not canAct(f) or now < f.NextSwitch then
		return
	end
	-- next stance in the loadout this fighter has unlocked, dummies have them all
	local at = table.find(Config.Loadout, f.Stance) or 0
	local nextStance = f.Stance
	for i = 1, #Config.Loadout - 1 do
		local s = Config.Loadout[(at + i - 1) % #Config.Loadout + 1]
		if not f.Player or Stats.unlocked(f.Stats, s) then
			nextStance = s
			break
		end
	end
	if nextStance == f.Stance then
		return
	end
	f.Stance = nextStance
	f.NextSwitch = now + Config.StanceSwitchCooldown
	f.Model:SetAttribute("StanceReady", workspace:GetServerTimeNow() + Config.StanceSwitchCooldown)
	f.Guarding, f.GuardHeight = false, nil
	setState(f, "Switching", now + Config.StanceSwitchTime)
	task.delay(Config.StanceSwitchTime, function()
		if f.State == "Switching" then
			setState(f, "Idle")
		end
	end)
end

-- height is "High", "Low", or nil to drop the guard. canParry false is for dummies covering
-- up on reflex, otherwise every reactive guard against a fast jab would count as a parry
function Fighters.setGuard(f: Fighter, height: string?, canParry: boolean?)
	if height ~= nil and height ~= "High" and height ~= "Low" then
		return
	end
	if
		height
		and (not f.FightMode or f.State == "Down" or f.State == "KO" or f.State == "Stunned" or f.State == "Switching")
	then
		return
	end
	if f.GuardHeight == height then
		return
	end
	local now = os.clock()
	-- raising the guard from nothing is instant, moving it between heights takes a moment
	if height and f.GuardHeight then
		f.GuardReadyAt = now + Config.GuardSwitchTime
	elseif height and not f.GuardHeight then
		-- only a fresh guard press can parry, so holding and tapping does nothing
		f.GuardPressedAt = if canParry ~= false and now - f.GuardDroppedAt >= Config.ParryRearm then now else 0
	elseif not height then
		f.GuardDroppedAt = now
	end
	f.GuardHeight = height
	f.Guarding = height ~= nil
	publish(f)
	setWalk(f)
end

function Fighters.setWeave(f: Fighter, on: boolean)
	if on and (not f.FightMode or f.State == "Down" or f.State == "KO") then
		return
	end
	if f.Weaving ~= on then
		f.Weaving = on
		publish(f)
		setWalk(f)
	end
end

function Fighters.slip(f: Fighter, direction: string)
	local now = os.clock()
	if
		not f.FightMode
		or (direction ~= "Left" and direction ~= "Right" and direction ~= "Duck" and direction ~= "Back")
	then
		return
	end
	-- players slip out of weave mode, dummies don't bother with it
	if f.Player and not f.Weaving then
		return
	end
	if not canAct(f) or now < f.NextSlip then
		return
	end
	local bob = f.Guarding
	f.SlipChain = if now - f.LastSlip < Config.SlipChainWindow then f.SlipChain + 1 else 0
	local cost = math.max(
		0,
		(if bob then Config.BobSlipCost else Config.SlipCost)
			+ f.SlipChain * Config.SlipChainCost
			- Config.Stances[f.Stance].SlipDiscount
	)
	if f.Stamina < cost then
		return
	end
	f.Stamina -= cost
	f.LastSlip = now
	f.Bobbing = bob
	f.Slip = direction
	f.SlipUntil = now + (if bob then Config.BobSlipTime else Config.SlipTime)
	f.NextSlip = now + (if f.Weaving then Config.WeaveSlipCooldown else Config.SlipCooldown)
	if not bob then
		f.Guarding = false
		f.GuardHeight = nil
	end
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

-- studio only (CombatServer checks): drop the fighter at full courage so the second wind fires
function Fighters.testSecondWind(f: Fighter)
	if f.State == "Down" or f.State == "KO" then
		return
	end
	f.Knockdowns = 0
	f.SecondWindUsed = false
	f.Courage = Config.MaxCourage
	f.Health = 0
	knockDown(f, f)
	publish(f)
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

-- can't throw anything until then (corners before a round)
function Fighters.freeze(f: Fighter, seconds: number)
	f.BusyUntil = os.clock() + seconds
	f.Guarding, f.GuardHeight, f.Weaving = false, nil, false
	publish(f)
	setWalk(f)
end

-- just the punch animation, no hit. for training on the bags and mitts
function Fighters.show(f: Fighter, moveName: string)
	local move = Config.Moves[moveName]
	if move then
		f.Model:SetAttribute("ActionLength", move.Startup)
		playAction(f, moveName)
	end
end

-- between rounds: the guard comes back, the rest is the corner pick
function Fighters.rest(f: Fighter)
	f.Guard = Config.MaxGuard
	publish(f)
end

-- the corner pick between rounds. Hydrate is wind, Treatment wins back some lasting damage,
-- Pep Talk is courage. returns false for anything else
function Fighters.corner(f: Fighter, pick: string): boolean
	local c = Config.Match.Corner[pick]
	if not c then
		return false
	end
	if pick == "Hydrate" then
		f.Stamina = Config.MaxStamina
	elseif pick == "Treatment" then
		f.MaxHealthNow = math.max(f.MaxHealthNow, math.min(Config.MaxHealth, f.MaxHealthNow + c.MaxHealth))
		f.Health = math.min(f.MaxHealthNow, f.Health + (f.MaxHealthNow - f.Health) * c.Heal)
	else
		f.Courage = math.min(Config.MaxCourage, f.Courage + c.Courage)
	end
	publish(f)
	return true
end

-- the ring and the upstairs room, everywhere else players just walk around
local zones = workspace:WaitForChild("Map"):WaitForChild("FightZones")
local function inZone(position: Vector3): boolean
	for _, zone in zones:GetChildren() do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function updateFightMode(f: Fighter)
	-- a match keeps you boxing even if you get knocked into the ropes
	local on = f.Player == nil or f.Match ~= nil or f.Drilling or inZone(f.Root.Position)
	if on == f.FightMode then
		return
	end
	f.FightMode = on
	f.Model:SetAttribute("FightMode", on)
	if not on then
		f.Guarding, f.GuardHeight, f.Weaving = false, nil, false
		publish(f)
	end
	setWalk(f)
end

-- training drills plant you in a boxing stance until they're done
function Fighters.setDrilling(f: Fighter, on: boolean)
	f.Drilling = on
	updateFightMode(f)
	setWalk(f)
end

-- stamina and guard come back over time
function Fighters.tick(dt: number)
	local now = os.clock()
	for _, f in byModel do
		updateFightMode(f)
		if f.State ~= "Down" and f.State ~= "KO" then
			local changed = false
			local regen = Config.StaminaRegen
				* (if f.Guarding then 0.5 else 1)
				* (if firedUp(f) then Config.FiredUpStamina else 1)
				* dt
			if f.Stamina < Config.MaxStamina and f.State == "Idle" then
				f.Stamina = math.min(Config.MaxStamina, f.Stamina + regen)
				changed = true
			end
			-- health only creeps back up to what's left of your max
			if f.Health < f.MaxHealthNow and f.Health > 0 and now - f.LastHit > Config.HealthRegenDelay then
				f.Health = math.min(f.MaxHealthNow, f.Health + Config.HealthRegen * dt)
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
