-- Keybinds. Only sends what was pressed; the server decides the rest. Lock-on lives in LockOn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatConfig"))

local player = Players.LocalPlayer
local action = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Action") :: RemoteEvent

local PUNCH_KEYS = {
	[Enum.UserInputType.MouseButton1] = "Jab",
	[Enum.UserInputType.MouseButton2] = "Cross",
	[Enum.KeyCode.E] = "Hook",
	[Enum.KeyCode.R] = "Uppercut",
	[Enum.KeyCode.Q] = "Body",
}

local LockOn = require(script.Parent:WaitForChild("LockOn"))

local function myCharacter(): Model?
	return player.Character
end

local function myState(): string?
	local character = myCharacter()
	return character and character:GetAttribute("State")
end

local SLIP_KEYS = {
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.W] = "Duck",
	[Enum.KeyCode.S] = "Back",
}

-- guard height comes from where you look. the lock-on camera is scripted, so while locked
-- the mouse moves a pretend pitch instead (LockOn.pitch)
local guardHeld = false
local sentHeight: string? = nil

local function pitch(): number
	if LockOn.target() then
		return LockOn.pitch()
	end
	return math.deg(math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y, -1, 1)))
end

local function wantedHeight(): string
	-- a few degrees of slack so it doesn't flicker on the line
	local line = Config.LowGuardPitch + (if sentHeight == "Low" then 3 else -3)
	return if pitch() < line then "Low" else "High"
end

local function sendGuard(height: string | false)
	if (height or nil) ~= sentHeight then
		sentHeight = height or nil
		action:FireServer("Guard", height)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local state = myState()
	local punch = PUNCH_KEYS[input.KeyCode] or PUNCH_KEYS[input.UserInputType]
	if punch then
		action:FireServer("Punch", punch)
	elseif input.KeyCode == Enum.KeyCode.F then
		guardHeld = true
		sendGuard(wantedHeight())
	elseif input.KeyCode == Enum.KeyCode.Space then
		if state == "Down" then
			action:FireServer("GetUp")
		else
			action:FireServer("Weave", true)
			-- already holding a direction, slip right away
			for key, dir in SLIP_KEYS do
				if UserInputService:IsKeyDown(key) then
					action:FireServer("Slip", dir)
					break
				end
			end
		end
	elseif SLIP_KEYS[input.KeyCode] and UserInputService:IsKeyDown(Enum.KeyCode.Space) and state ~= "Down" then
		action:FireServer("Slip", SLIP_KEYS[input.KeyCode])
	-- not Tab, roblox keeps that for the player list
	elseif input.KeyCode == Enum.KeyCode.T then
		LockOn.toggle()
	elseif input.KeyCode == Enum.KeyCode.V then
		LockOn.swapShoulder()
	elseif input.KeyCode == Enum.KeyCode.Return and state == "KO" then
		action:FireServer("Reset")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		guardHeld = false
		sendGuard(false)
	elseif input.KeyCode == Enum.KeyCode.Space then
		action:FireServer("Weave", false)
	end
end)

RunService.RenderStepped:Connect(function()
	if guardHeld then
		sendGuard(wantedHeight())
	end
end)

-- no jumping in a boxing ring, and space is weave mode now
local function noJump(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

player.CharacterAdded:Connect(noJump)
if player.Character then
	task.spawn(noJump, player.Character)
end
