--!strict
-- Lock-on camera. Framing scales with how far apart the two fighters are (idea from the
-- bought game 1, numbers in between theirs and mine), follows on a dt spring, turns the body
-- at a capped speed, pulls in past posts and walls, and marks who you're locked on to.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local RANGE = 30 -- studs to pick a target
local BREAK = 39 -- lock drops past this
local TURN_SPEED = math.rad(720) -- per second
local SPRING = 14 -- higher = camera catches up faster
local BASE_FOV = 70
local CLOSE_FOV = 64

-- framing by distance between fighters: close trading, footwork range, far
local function framing(distance: number): (number, number, number)
	local t = math.clamp((distance - 3) / 6, 0, 1)
	local back = 5.5 + t * 3.5 -- 5.5 to 9
	local side = 1.5 + t * 1.25 -- 1.5 to 2.75
	local height = 2.4 + t * 0.8 -- 2.4 to 3.2
	return back, side, height
end

local LockOn = {}

local target: Model? = nil
local shoulder = 1 -- 1 right, -1 left
local pitch = 0 -- pretend camera pitch from the mouse, used for guard height
local camCFrame: CFrame? = nil

-- chevron over the locked target's head
local marker = Instance.new("BillboardGui")
marker.Name = "LockMarker"
marker.Size = UDim2.fromOffset(28, 28)
marker.StudsOffset = Vector3.new(0, 2.6, 0)
marker.AlwaysOnTop = true
marker.Enabled = false
local chevron = Instance.new("TextLabel")
chevron.Size = UDim2.fromScale(1, 1)
chevron.BackgroundTransparency = 1
chevron.Text = "▼"
chevron.TextScaled = true
chevron.TextColor3 = Color3.fromRGB(255, 80, 70)
chevron.TextStrokeTransparency = 0.3
chevron.Parent = marker
marker.Parent = player:WaitForChild("PlayerGui")

local function character(): Model?
	return player.Character
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function candidates(): { Model }
	local me = character()
	local root = rootOf(me)
	local list = {}
	if not root then
		return list
	end
	for _, model in CollectionService:GetTagged("Fighter") do
		if model ~= me and model:IsA("Model") and model:GetAttribute("State") ~= "KO" then
			local other = rootOf(model)
			if other and (other.Position - root.Position).Magnitude <= RANGE then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function set(model: Model?)
	target = model
	player:SetAttribute("LockTarget", model and model.Name or nil)
	local humanoid = character() and (character() :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = model == nil
	end
	local camera = workspace.CurrentCamera
	if model then
		camCFrame = camera.CFrame
		marker.Adornee = rootOf(model)
		marker.Enabled = true
		chevron.TextTransparency = 1
		TweenService:Create(chevron, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	else
		marker.Enabled = false
		marker.Adornee = nil
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = BASE_FOV
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function LockOn.target(): Model?
	return target
end

function LockOn.pitch(): number
	return pitch
end

function LockOn.toggle()
	if target then
		set(nil)
		return
	end
	-- nearest one
	local me = rootOf(character())
	local best, bestDistance = nil, math.huge
	for _, model in candidates() do
		local d = ((rootOf(model) :: BasePart).Position - (me :: BasePart).Position).Magnitude
		if d < bestDistance then
			best, bestDistance = model, d
		end
	end
	set(best)
end

-- step to the next fighter clockwise (1) or anticlockwise (-1) from where you're facing
function LockOn.cycle(direction: number)
	local me = rootOf(character())
	if not (target and me) then
		return
	end
	local look = me.CFrame.LookVector
	local function angle(model: Model): number
		local offset = (rootOf(model) :: BasePart).Position - me.Position
		return math.atan2(look:Cross(offset).Y, look:Dot(offset))
	end
	local list = candidates()
	table.sort(list, function(a, b)
		return angle(a) < angle(b)
	end)
	local index = table.find(list, target :: Model)
	if #list > 1 and index then
		set(list[(index - 1 + direction) % #list + 1])
	end
end

function LockOn.swapShoulder()
	shoulder = -shoulder
end

UserInputService.InputChanged:Connect(function(input, processed)
	if not target then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		pitch = math.clamp(pitch - input.Delta.Y * 0.3, -45, 20)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		LockOn.cycle(if input.Position.Z > 0 then 1 else -1)
	end
end)

local blockParams = RaycastParams.new()
blockParams.FilterType = Enum.RaycastFilterType.Exclude

RunService:BindToRenderStep("BoxingLockOn", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local me = character()
	local root = rootOf(me)
	local model = target
	if not (root and model) then
		return
	end
	local targetRoot = rootOf(model)
	if not model.Parent or not targetRoot or model:GetAttribute("State") == "KO"
		or (targetRoot.Position - root.Position).Magnitude > BREAK then
		set(nil)
		return
	end
	local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
	local offset = flat - root.Position
	local distance = offset.Magnitude
	if distance < 0.05 then
		return
	end
	local toTarget = offset.Unit

	-- turn toward them, but not instantly, so circling behind someone works
	local state = me and (me :: Model):GetAttribute("State")
	if state ~= "Down" and state ~= "KO" then
		local current = root.CFrame.LookVector
		current = Vector3.new(current.X, 0, current.Z).Unit
		local between = math.atan2(current:Cross(toTarget).Y, current:Dot(toTarget))
		local step = math.clamp(between, -TURN_SPEED * dt, TURN_SPEED * dt)
		local facing = CFrame.fromAxisAngle(Vector3.yAxis, step):VectorToWorldSpace(current)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
	end

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	-- set every frame, the default camera scripts keep trying to free it
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local back, side, height = framing(distance)
	local right = toTarget:Cross(Vector3.yAxis)
	-- looking down for a low guard tips the camera down a little so you can feel it
	local focus = (root.Position + targetRoot.Position) / 2 + Vector3.new(0, 1.1 + pitch * 0.04, 0)
	local eye = root.Position - toTarget * back + right * side * shoulder + Vector3.new(0, height, 0)

	-- pull in in front of posts and the (invisible) rope walls so the camera stays in the ring
	blockParams.FilterDescendantsInstances = { me :: Model, model }
	local hit = workspace:Raycast(focus, eye - focus, blockParams)
	if hit and hit.Instance.CanCollide then
		eye = hit.Position + (focus - eye).Unit * 0.4
	end

	local goal = CFrame.lookAt(eye, focus)
	local alpha = 1 - math.exp(-SPRING * dt)
	camCFrame = (camCFrame or goal):Lerp(goal, alpha)
	camera.CFrame = camCFrame :: CFrame
	-- eased slowly so the fov kick on big hits still reads
	local fov = if distance < 3.5 then CLOSE_FOV else BASE_FOV
	camera:SetAttribute("BaseFov", fov)
	camera.FieldOfView += (fov - camera.FieldOfView) * alpha * 0.3
end)

player.CharacterAdded:Connect(function()
	set(nil)
end)

return LockOn
