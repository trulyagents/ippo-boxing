--!strict
-- The card that pops when training opens up a new stance or special, and the daily streak
-- reward (StarterGui.UnlockCard, built in studio). The server sends Fx "Unlocked" with the name,
-- or Fx "Daily" with the streak day, the stat, how much, and what tomorrow pays.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("UnlockCard") :: ScreenGui
local root = gui:WaitForChild("Root") :: Frame
local card = root:WaitForChild("Card") :: ImageLabel
local scale = card:WaitForChild("UIScale") :: UIScale

-- one line on what it's for
local BLURBS: { [string]: string } = {
	PeekABoo = "HANDS HIGH, BOB AND WEAVE IN CLOSE",
	StepCounter = "SLIP THEIR PUNCH, STEP IN AND MAKE THEM PAY",
	WeaveRoll = "ROLL UNDER AND COME UP SWINGING",
	LungeUppercut = "LEAP IN FROM RANGE WITH A RISING UPPERCUT",
	OutBoxer = "LONG FAST JAB, LIGHT FEET, BOX FROM RANGE",
	FlickerJab = "THREE LIGHTNING JABS FROM THE OUTSIDE",
	PivotHook = "STEP OFF THE LINE AND HOOK FROM THE NEW ANGLE",
	Slugger = "SLOW, HEAVY, EVERY PUNCH CAN END IT",
	Haymaker = "LOAD UP AND THROW THE WHOLE BODY OVER THE TOP",
	HookBarrage = "THREE HOOKS BACK TO BACK, NO BREATHING ROOM",
	PhillyShell = "LEAD HAND LOW, ROLL PUNCHES OFF THE SHOULDER",
	RollCounter = "ROLL THEIR PUNCH OFF YOUR SHOULDER, CROSS BACK",
	CheckHook = "PIVOT OUT AS THEY CHARGE AND HOOK ON THE TURN",
}

local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SHOW_FOR = 4

local function text(name: string): TextLabel
	return card:WaitForChild(name) :: TextLabel
end

-- unlocks can land together (one stat gain opens two things), show them one after another.
-- each entry is the four lines of the card
type Card = { Kind: string, Title: string, Blurb: string, Hint: string }
local queue: { Card } = {}
local showing = false

local function showNext()
	local card = table.remove(queue, 1)
	if not card then
		showing = false
		return
	end
	showing = true
	text("Kind").Text = card.Kind
	text("Title").Text = card.Title
	text("Blurb").Text = card.Blurb
	text("Hint").Text = card.Hint
	scale.Scale = 0
	root.Visible = true
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	task.delay(SHOW_FOR, function()
		local t = TweenService:Create(scale, OUT, { Scale = 0 })
		t:Play()
		t.Completed:Wait()
		root.Visible = false
		showNext()
	end)
end

local function push(card: Card)
	table.insert(queue, card)
	if not showing then
		showNext()
	end
end

fx.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "Unlocked" and typeof(a) == "string" then
		local stance = Config.Stances[a]
		local special = Config.Specials[a]
		push({
			Kind = if stance then "NEW STYLE UNLOCKED" else "NEW SPECIAL UNLOCKED",
			Title = if stance then stance.Name elseif special then special.Name else string.upper(a),
			Blurb = BLURBS[a] or "",
			Hint = if stance
				then (if UserInputService.TouchEnabled then "MENU - STYLES TO EQUIP IT" else "M - STYLES TO EQUIP IT")
				else "READY ON ITS STANCE'S SPECIAL BUTTON",
		})
	elseif kind == "Daily" and typeof(a) == "number" and typeof(b) == "string" then
		push({
			Kind = "DAY " .. a .. " STREAK",
			Title = "+" .. tostring(c) .. " " .. string.upper(b),
			Blurb = "YOUR WEAKEST STAT GETS THE WORK",
			Hint = "COME BACK TOMORROW FOR +" .. tostring(d) .. ". MISS A DAY AND IT STARTS OVER",
		})
	end
end)
