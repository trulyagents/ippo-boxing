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

-- step into my own punches when they fire. i own my character's physics so the push goes here
local function stepIn(character: Model)
	character:GetAttributeChangedSignal("ActionToken"):Connect(function()
		local move = Config.Moves[character:GetAttribute("Action")]
		local root = character:FindFirstChild("HumanoidRootPart")
		if not (move and root and root:IsA("BasePart")) then
			return
		end
		local token = character:GetAttribute("ActionToken")
		-- the punch fires when the server flips me to Recovery, push then
		local changed: RBXScriptConnection
		changed = character:GetAttributeChangedSignal("State"):Connect(function()
			if character:GetAttribute("ActionToken") ~= token then
				changed:Disconnect()
				return
			end
			if character:GetAttribute("State") ~= "Recovery" then
				return
			end
			changed:Disconnect()
			-- impulses and velocity get eaten by the humanoid, so slide the root forward for a beat
			local look = root.CFrame.LookVector
			local ends = os.clock() + 0.12
			local push: RBXScriptConnection
			push = RunService.Heartbeat:Connect(function(dt)
				if os.clock() > ends or not root.Parent then
					push:Disconnect()
					return
				end
				root.CFrame += look * move.Step * dt
			end)
		end)
		task.delay(1, function()
			if changed.Connected then
				changed:Disconnect()
			end
		end)
	end)
end

player.CharacterAdded:Connect(function(character)
	noJump(character)
	stepIn(character)
end)
if player.Character then
	task.spawn(noJump, player.Character)
	stepIn(player.Character)
end
