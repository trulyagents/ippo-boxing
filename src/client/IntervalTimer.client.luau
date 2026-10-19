--!strict
-- The gym's wall interval timer (Map.GymRing.IntervalTimer, g2's prop). It shows the ring match
-- clock: the round, minutes and seconds left, and the 10 bars going out as the round runs down.
-- Between fights it sits at 0:00. Reads the ring's MatchRound and MatchEndsAt, same as the hud.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

-- art/timer/digit_0.png .. digit_9.png
local DIGITS = {
	[0] = "rbxassetid://115636176398831",
	"rbxassetid://130608881357159",
	"rbxassetid://119577955331606",
	"rbxassetid://125295375531793",
	"rbxassetid://122962182421788",
	"rbxassetid://128736427579514",
	"rbxassetid://105162054120789",
	"rbxassetid://120725115157756",
	"rbxassetid://111563510581153",
	"rbxassetid://91162770582786",
}

-- loaded up front so a digit never shows blank the first time it comes up
task.spawn(function()
	local list = {}
	for i = 0, 9 do
		table.insert(list, DIGITS[i])
	end
	game:GetService("ContentProvider"):PreloadAsync(list)
end)

local ring = workspace:WaitForChild("Ring")
local timer = workspace:WaitForChild("Map"):WaitForChild("GymRing"):WaitForChild("IntervalTimer")
local function decal(name: string): Decal
	return timer:WaitForChild(name):WaitForChild("Decal") :: Decal
end
local round, minutes, tens, ones = decal("Round_Digit1"), decal("Min_Digit1"), decal("Sec_Digit1"), decal("Sec_Digit2")
local bars = timer:WaitForChild("TimerBars")

local shown = -1
RunService.Heartbeat:Connect(function()
	local endsAt = ring:GetAttribute("MatchEndsAt")
	local left = if typeof(endsAt) == "number" then math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) else 0
	local roundNumber = (ring:GetAttribute("MatchRound") :: number?) or 0
	local key = roundNumber * 10000 + left
	if key == shown then
		return
	end
	shown = key
	round.Texture = DIGITS[math.clamp(roundNumber, 0, 9)]
	minutes.Texture = DIGITS[math.clamp(left // 60, 0, 9)]
	tens.Texture = DIGITS[(left % 60) // 10]
	ones.Texture = DIGITS[left % 10]
	-- bars light up for the share of the round still to go
	local lit = math.ceil(math.clamp(left / Config.Match.RoundTime, 0, 1) * 10)
	for _, bar in bars:GetChildren() do
		local n = tonumber(bar.Name)
		local d = bar:FindFirstChildOfClass("Decal")
		if n and d then
			d.Transparency = if n <= lit then 0 else 0.85
		end
	end
end)
