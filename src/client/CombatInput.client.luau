-- Keybinds and lock-on. Only sends what was pressed; the server decides the rest.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

local function slipDirection(): string
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		return "Left"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		return "Right"
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		return "Back"
	end
	return "Duck"
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
		action:FireServer("Guard", true)
	elseif input.KeyCode == Enum.KeyCode.Space then
		if state == "Down" then
			action:FireServer("GetUp")
		else
			action:FireServer("Slip", slipDirection())
		end
	-- not Tab, roblox keeps that for the player list
	elseif input.KeyCode == Enum.KeyCode.T then
		setLock(if lockTarget then nil else nearestFighter())
	elseif input.KeyCode == Enum.KeyCode.Return and state == "KO" then
		action:FireServer("Reset")
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		action:FireServer("Guard", false)
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
	local eye = root.Position - toTarget * 9 + rightVector * 2.5 + Vector3.new(0, 3.2, 0)
	local focus = (root.Position + targetRoot.Position) / 2 + Vector3.new(0, 1.2, 0)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, focus), 0.25)
end)

player.CharacterAdded:Connect(function()
	setLock(nil)
end)
