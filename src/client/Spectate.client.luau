--!strict
-- K or the WATCH stamp cycles live rings, past the last one it stops. tells the server
-- which ring (Watch) so its shouts and screens reach you
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Rings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rings"))
local Watch = require(script.Parent:WaitForChild("Watch"))

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Spectate") :: ScreenGui
local button = gui:WaitForChild("WatchButton") :: GuiButton
local banner = gui:WaitForChild("Banner") :: Frame
local title = banner:WaitForChild("Title") :: TextLabel
local remote = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Watch") :: RemoteEvent
local camera = workspace.CurrentCamera

local function live(): { Model }
	local out = {}
	for _, ring in Rings.all() do
		if ring:GetAttribute("MatchOn") then
			table.insert(out, ring)
		end
	end
	table.sort(out, function(a: Model, b: Model): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	return out
end

local function inMatch(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("InMatch") == true
end

local function watch(ring: Model?)
	Watch.Spectating = ring
	remote:FireServer(ring)
	banner.Visible = ring ~= nil
	if ring then
		title.Text = "WATCHING " .. tostring(ring:GetAttribute("Label") or "A RING")
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		camera.CameraSubject = character and character:FindFirstChildOfClass("Humanoid")
	end
end

local function next()
	local rings = live()
	local current = Watch.Spectating
	local index = if current then table.find(rings, current) else nil
	watch(rings[(index or 0) + 1])
end

button.Activated:Connect(next)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.K and (button.Visible or Watch.Spectating) then
		next()
	end
end)

-- the two boxers in a ring: characters marked InMatch closest to it
local function boxers(ring: Model): (Vector3?, number)
	local center = ring:GetPivot().Position
	local sum, n, spread = Vector3.zero, 0, 0
	local spots = {}
	for _, other in Players:GetPlayers() do
		local c = other.Character
		local root = c and c:GetAttribute("InMatch") and c:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Rings.nearest(root.Position) == ring then
			table.insert(spots, root.Position)
		end
	end
	-- ai boxers aren't players, find them in the workspace by the same mark
	for _, model in workspace:GetChildren() do
		local root = model:IsA("Model") and model:GetAttribute("InMatch") and not Players:GetPlayerFromCharacter(model) and model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Rings.nearest(root.Position) == ring then
			table.insert(spots, root.Position)
		end
	end
	for _, p in spots do
		sum += p
		n += 1
	end
	if n == 0 then
		return center, 0
	end
	local mid = sum / n
	for _, p in spots do
		spread = math.max(spread, (p - mid).Magnitude)
	end
	return mid, spread
end

local angle = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace:WaitForChild("Map"):WaitForChild("Gym") }
local checkAt = 0
RunService:BindToRenderStep("Spectate", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	if now > checkAt then
		checkAt = now + 0.25
		button.Visible = not inMatch() and #live() > 0
		local ring = Watch.Spectating
		-- the fight ended, or you got into one yourself
		if ring and (not ring:GetAttribute("MatchOn") or inMatch() or not ring.Parent) then
			watch(nil)
		end
	end
	local ring = Watch.Spectating
	if not ring then
		return
	end
	local mid, spread = boxers(ring)
	if not mid then
		return
	end
	angle += dt * 0.18
	local distance = math.min(11 + spread, 20)
	local target = mid + Vector3.new(0, 1, 0)
	local eye = mid + Vector3.new(math.cos(angle) * distance, math.min(5 + spread * 0.2, 7), math.sin(angle) * distance)
	-- basement rings sit close to walls and a low ceiling, pull in in front of whatever's in the way
	local hit = workspace:Raycast(target, eye - target, rayParams)
	if hit then
		eye = hit.Position + (target - eye).Unit * 1
	end
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, target), math.min(1, dt * 4))
end)

player.CharacterAdded:Connect(function()
	if Watch.Spectating then
		watch(nil)
	end
end)
