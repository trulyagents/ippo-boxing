-- Keybinds and lock-on. Only sends what was pressed; the server decides the rest.
local CollectionService = game:GetService("CollectionService")
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

local LOCK_RANGE = 30
local lockTarget: Model? = nil

local function myCharacter(): Model?
	return player.Character
end

local function myState(): string?
	local character = myCharacter()
	return character and character:GetAttribute("State")
end

local function nearestFighter(): Model?
	local character = myCharacter()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best, bestDistance = nil, LOCK_RANGE
	for _, model in CollectionService:GetTagged("Fighter") do
		if model ~= character and model:IsA("Model") and model:GetAttribute("State") ~= "KO" then
			local other = model:FindFirstChild("HumanoidRootPart")
			if other and other:IsA("BasePart") then
				local d = (other.Position - root.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = model, d
				end
			end
		end
	end
	return best
end

local function setLock(target: Model?)
	lockTarget = target
	player:SetAttribute("LockTarget", target and target.Name or nil)
	local character = myCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = target == nil
	end
	local camera = workspace.CurrentCamera
	if not target then
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local SLIP_KEYS = {
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.W] = "Duck",
	[Enum.KeyCode.S] = "Back",
}

-- guard height comes from where you look. the lock-on camera is scripted, so while locked
-- the mouse moves a pretend pitch instead
local lockPitch = 0
local guardHeld = false
local sentHeight: string? = nil

local function pitch(): number
	if lockTarget then
		return lockPitch
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
		setLock(if lockTarget then nil else nearestFighter())
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

UserInputService.InputChanged:Connect(function(input)
	if lockTarget and input.UserInputType == Enum.UserInputType.MouseMovement then
		lockPitch = math.clamp(lockPitch - input.Delta.Y * 0.3, -45, 20)
	end
end)

RunService.RenderStepped:Connect(function()
	if guardHeld then
		sendGuard(wantedHeight())
	end
end)

-- lock-on camera: over the shoulder, always facing the opponent
RunService:BindToRenderStep("BoxingLockOn", Enum.RenderPriority.Camera.Value + 1, function()
	local character = myCharacter()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = lockTarget
	if not (root and root:IsA("BasePart")) then
		return
	end
	if target and (not target.Parent or target:GetAttribute("State") == "KO") then
		setLock(nil)
		return
	end
	local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
	if not (targetRoot and targetRoot:IsA("BasePart")) then
		return
	end
	if (targetRoot.Position - root.Position).Magnitude > LOCK_RANGE * 1.3 then
		setLock(nil)
		return
	end
	local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
	local state = myState()
	if state ~= "Down" and state ~= "KO" and (flat - root.Position).Magnitude > 0.2 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local toTarget = (flat - root.Position).Unit
	local rightVector = toTarget:Cross(Vector3.yAxis)
	-- far enough to the side that your own body doesn't hide the punches landing
	local eye = root.Position - toTarget * 8.5 + rightVector * 4.5 + Vector3.new(0, 3.4, 0)
	-- looking down for a low guard tips the camera down a little so you can feel it
	local focus = (root.Position + targetRoot.Position) / 2 + Vector3.new(0, 1.2 + lockPitch * 0.05, 0)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, focus), 0.25)
end)

player.CharacterAdded:Connect(function()
	setLock(nil)
end)
