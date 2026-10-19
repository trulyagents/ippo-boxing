--!strict
-- The card that pops when training opens up a new stance or special (StarterGui.UnlockCard,
-- built in studio). The server sends Fx "Unlocked" with the name.
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
}

local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SHOW_FOR = 4

local function text(name: string): TextLabel
	return card:WaitForChild(name) :: TextLabel
end

-- unlocks can land together (one stat gain opens two things), show them one after another
local queue: { string } = {}
local showing = false

local function showNext()
	local name = table.remove(queue, 1)
	if not name then
		showing = false
		return
	end
	showing = true
	local stance = Config.Stances[name]
	local special = Config.Specials[name]
	text("Kind").Text = if stance then "NEW STYLE UNLOCKED" else "NEW SPECIAL UNLOCKED"
	text("Title").Text = if stance then stance.Name elseif special then special.Name else string.upper(name)
	text("Blurb").Text = BLURBS[name] or ""
	text("Hint").Text = if stance
		then (if UserInputService.TouchEnabled then "MENU - STYLES TO EQUIP IT" else "M - STYLES TO EQUIP IT")
		else "READY ON ITS STANCE'S SPECIAL BUTTON"
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

fx.OnClientEvent:Connect(function(kind, name)
	if kind ~= "Unlocked" or typeof(name) ~= "string" then
		return
	end
	table.insert(queue, name)
	if not showing then
		showNext()
	end
end)
