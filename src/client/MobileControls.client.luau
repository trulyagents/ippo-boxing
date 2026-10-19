--!strict
-- Touch buttons for boxing (StarterGui.MobileControls, built in studio). Only on touch devices
-- and only while in fight mode, out on the street roblox's normal controls are enough. Sends the
-- same Action messages as the keyboard (CombatInput), the server checks all of it.
--   punches bottom right, hold GUARD (look down for low guard, same as pc)
--   slip arrows on the left: a tap is weave on, slip, weave off. hold WEAVE to stay in weave mode
--   knocked down: any punch button mashes to get up. KO'd outside a match: JAB goes again
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local LockOn = require(script.Parent:WaitForChild("LockOn"))

if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local action = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Action") :: RemoteEvent
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("MobileControls") :: ScreenGui
local root = gui:WaitForChild("Root") :: Frame
local punches = root:WaitForChild("Punches") :: Frame
local slips = root:WaitForChild("Slips") :: Frame
local extras = root:WaitForChild("Extras") :: Frame

-- the keyboard card means nothing on a phone
local controls = playerGui:WaitForChild("BoxingHUD"):FindFirstChild("Controls")
if controls and controls:IsA("GuiObject") then
	controls.Visible = false
end

local PRESS = 0.9

local function state(): string?
	local character = player.Character
	return character and character:GetAttribute("State") :: string?
end

local function button(parent: Instance, name: string): TextButton
	return parent:WaitForChild(name) :: TextButton
end

-- press and release, with a squish so a tap feels like a tap
local function bind(b: TextButton, down: () -> (), up: (() -> ())?)
	local scale = b:FindFirstChildOfClass("UIScale") :: UIScale
	local held = 0
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held += 1
			scale.Scale = PRESS
			down()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held = math.max(0, held - 1)
			if held == 0 then
				scale.Scale = 1
				if up then
					up()
				end
			end
		end
	end)
end

-- punches, or getting up / going again when you're on the floor
for _, move in { "Jab", "Cross", "Hook", "Uppercut", "Body" } do
	bind(button(punches, move), function()
		local s = state()
		if s == "Down" then
			action:FireServer("GetUp")
		elseif s == "KO" then
			if move == "Jab" then
				action:FireServer("Reset")
			end
		else
			action:FireServer("Punch", move)
		end
	end)
end

-- guard height comes from the camera pitch, same rule as the keyboard
local guardHeld = false
local sentHeight: string? = nil
local function pitch(): number
	if LockOn.target() then
		return LockOn.pitch()
	end
	return math.deg(math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y, -1, 1)))
end
local function sendGuard(height: string?)
	if height ~= sentHeight then
		sentHeight = height
		action:FireServer("Guard", height or false)
	end
end
local function wantedHeight(): string
	local line = Config.LowGuardPitch + (if sentHeight == "Low" then 3 else -3)
	return if pitch() < line then "Low" else "High"
end
bind(button(punches, "Guard"), function()
	guardHeld = true
	sendGuard(wantedHeight())
end, function()
	guardHeld = false
	sendGuard(nil)
end)

-- weave and slips
local weaveHeld = false
bind(button(slips, "Weave"), function()
	weaveHeld = true
	action:FireServer("Weave", true)
end, function()
	weaveHeld = false
	action:FireServer("Weave", false)
end)
for _, dir in { "Left", "Right", "Duck", "Back" } do
	bind(button(slips, dir), function()
		if state() == "Down" then
			return
		end
		if weaveHeld then
			action:FireServer("Slip", dir)
		else
			action:FireServer("Weave", true)
			action:FireServer("Slip", dir)
			action:FireServer("Weave", false)
		end
	end)
end

-- specials, lock on, side, stance
bind(button(extras, "Special1"), function()
	action:FireServer("Special", 1)
end)
bind(button(extras, "Special2"), function()
	action:FireServer("Special", 2)
end)
bind(button(extras, "Lock"), function()
	LockOn.toggle()
end)
bind(button(extras, "Swap"), function()
	LockOn.swapShoulder()
end)
bind(button(extras, "Stance"), function()
	action:FireServer("Stance")
end)

-- special buttons say what they are for the stance you're in
local function nameSpecials()
	local character = player.Character
	local stance = Config.Stances[character and character:GetAttribute("Stance") :: string? or "Orthodox"]
	for i = 1, 2 do
		local sp = stance and Config.Specials[stance.Specials[i]]
		local label = button(extras, "Special" .. i):FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = if sp then string.upper(sp.Name) else (if i == 1 then "Z" else "X")
		end
	end
end

-- only up while boxing. the guard follows the camera while it's held
local lastStance: string? = nil
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local on = character ~= nil and character:GetAttribute("FightMode") ~= false
	root.Visible = on
	if guardHeld then
		sendGuard(wantedHeight())
	end
	local stance = character and character:GetAttribute("Stance") :: string?
	if stance ~= lastStance then
		lastStance = stance
		nameSpecials()
	end
end)
