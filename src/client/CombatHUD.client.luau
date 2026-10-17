-- Fills in the fight HUD (your bars, their name, call-outs, the ref count), plays punch
-- sounds and shakes the screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local sounds = ReplicatedStorage:WaitForChild("BoxingSounds")

-- the gui is built in studio (StarterGui.BoxingHUD, copy in ui/). this script only fills it in
local gui = player:WaitForChild("PlayerGui"):WaitForChild("BoxingHUD") :: ScreenGui
local mine = gui:WaitForChild("MyPanel") :: ImageLabel
local bars = mine:WaitForChild("Bars") :: Frame
local theirs = gui:WaitForChild("TheirName") :: ImageLabel
local theirName = theirs:WaitForChild("NameText") :: TextLabel
local callout = gui:WaitForChild("Callout") :: TextLabel
local calloutScale = callout:WaitForChild("UIScale") :: UIScale
local count = gui:WaitForChild("Count") :: TextLabel
local hint = gui:WaitForChild("Hint") :: TextLabel
local thoughtLabel = gui:WaitForChild("Thought") :: TextLabel

local function fillOf(stat: string): ImageLabel
	return bars:WaitForChild(stat):WaitForChild("Track"):WaitForChild("Clip"):WaitForChild("Fill") :: ImageLabel
end
local clip = bars:WaitForChild("Health"):WaitForChild("Track"):WaitForChild("Clip")
local fills =
	{ Health = fillOf("Health"), Stamina = fillOf("Stamina"), Guard = fillOf("Guard"), Courage = fillOf("Courage") }
local ghost = clip:WaitForChild("Ghost") :: ImageLabel
local lost = clip:WaitForChild("Lost") :: Frame

-- my name and avatar headshot in the panel
local banner = mine:WaitForChild("NameBanner") :: ImageLabel;
(banner:WaitForChild("NameText") :: TextLabel).Text = string.upper(player.DisplayName)
task.spawn(function()
	local ok, image = pcall(
		Players.GetUserThumbnailAsync,
		Players,
		player.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size180x180
	)
	if ok then
		(mine:WaitForChild("Portrait") :: ImageLabel).Image = image
	end
end)

-- studio only test button
local test = gui:WaitForChild("TestSecondWind") :: TextButton
test.Visible = RunService:IsStudio()
if RunService:IsStudio() then
	test.Activated:Connect(function()
		(ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Action") :: RemoteEvent):FireServer(
			"TestSecondWind"
		)
	end)
end

local CONTROLS =
	"M1 jab  M2 cross  E hook  R uppercut  Q body  |  hold F guard (look down = low)  |  hold Space weave + A/D/W/S  |  T lock on (V swap side, scroll switch)"
hint.Text = CONTROLS

local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back)
local FADE = TweenInfo.new(0.3)

-- size is the old pixel size, 80 is normal. the text scales itself, the UIScale pops it
local function shout(text: string, color: Color3?, size: number?)
	callout.Text = text
	callout.TextColor3 = color or Color3.fromRGB(255, 220, 60)
	callout.TextTransparency = 0
	callout.TextStrokeTransparency = 0
	local scale = (size or 80) / 80
	calloutScale.Scale = scale * 1.3
	TweenService:Create(calloutScale, POP, { Scale = scale }):Play()
	task.delay(0.7, function()
		if callout.Text == text then
			TweenService:Create(callout, FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local STAMINA_COLOR = fills.Stamina.ImageColor3
local GASSED_COLOR = Color3.fromRGB(230, 70, 40)
local staminaFlash = 0 -- os.clock() until which my stamina bar flashes after a gassed punch

local COURAGE_COLOR = fills.Courage.ImageColor3
local COURAGE_HOT = Color3.fromRGB(225, 190, 255)

-- inner thought line for a second wind
local function thought(text: string)
	thoughtLabel.Text = '"' .. text .. '"'
	thoughtLabel.TextTransparency = 1
	thoughtLabel.TextStrokeTransparency = 1
	TweenService:Create(thoughtLabel, TweenInfo.new(0.6), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	task.delay(3.2, function()
		if thoughtLabel.Text == '"' .. text .. '"' then
			TweenService:Create(thoughtLabel, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end)
end

local function setFill(fill: ImageLabel, share: number, speed: number)
	fill.Size = fill.Size:Lerp(UDim2.fromScale(math.clamp(share, 0, 1), 1), speed)
end

local function setBars(model: Model)
	local healthShare = math.clamp((model:GetAttribute("Health") or Config.MaxHealth) / Config.MaxHealth, 0, 1)
	setFill(fills.Health, healthShare, 0.3)
	-- the ghost waits for the real bar, then catches up slowly so you see the size of the hit
	local ghostShare = ghost.Size.X.Scale
	ghost.Size = UDim2.fromScale(
		if healthShare > ghostShare then healthShare else ghostShare + (healthShare - ghostShare) * 0.04,
		1
	)
	local maxNow = model:GetAttribute("MaxHealthNow") or Config.MaxHealth
	lost.Size = UDim2.fromScale(math.clamp(1 - maxNow / Config.MaxHealth, 0, 1), 1)

	local stamina = model:GetAttribute("Stamina") or Config.MaxStamina
	setFill(fills.Stamina, stamina / Config.MaxStamina, 0.3)
	-- under the gassed line the bar throbs red so you know punches are slow
	local pulse = if stamina < Config.GassedBelow then 0.5 + 0.5 * math.sin(os.clock() * 10) else 0
	if os.clock() < staminaFlash then
		pulse = 1
	end
	fills.Stamina.ImageColor3 = STAMINA_COLOR:Lerp(GASSED_COLOR, pulse)

	setFill(fills.Guard, (model:GetAttribute("Guard") or Config.MaxGuard) / Config.MaxGuard, 0.3)

	local courage = model:GetAttribute("Courage") or 0
	setFill(fills.Courage, courage / Config.MaxCourage, 0.2)
	-- 90+ is when a second wind gets likely, make it glow
	fills.Courage.ImageColor3 = if courage >= 90
		then COURAGE_COLOR:Lerp(COURAGE_HOT, 0.5 + 0.5 * math.sin(os.clock() * 8))
		else COURAGE_COLOR
end

local shake = 0
local function addShake(amount: number)
	shake = math.max(shake, amount)
end

local function play(name: string, at: Instance?, pitch: number?)
	local template = sounds:FindFirstChild(name)
	if not template then
		return
	end
	local s = template:Clone() :: Sound
	s.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
	local part = at and at:FindFirstChild("Head")
	s.Parent = part or gui
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

local function lockedModel(): Model?
	local name = player:GetAttribute("LockTarget")
	local found = name and workspace:FindFirstChild(name)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

fx.OnClientEvent:Connect(function(kind, a, b, move, result, _damage, counterName)
	local me = player.Character
	if kind == "Hit" then
		local attacker, target = a, b
		local involved = attacker == me or target == me
		if result == "Blocked" then
			play("Block", target)
		elseif result == "Chip" then
			play("HitLight", target)
		else
			play(
				if move == "Jab"
					then "HitLight"
					elseif move == "Cross" or move == "Body" then "HitMedium"
					else "HitHeavy",
				target
			)
		end
		if involved then
			local big = result == "Counter" or result == "GuardBreak" or move == "Uppercut" or move == "Hook"
			addShake(if target == me then (if big then 1.2 else 0.5) else (if big then 0.6 else 0.15))
		end
		if attacker == me or target == me then
			if result == "Counter" then
				local name = if typeof(counterName) == "string" then counterName else "COUNTER"
				shout(name .. "!", Color3.fromRGB(255, 90, 60), if name == "CROSS COUNTER" then 110 else nil)
			elseif result == "GuardBreak" then
				shout("GUARD BREAK!", Color3.fromRGB(110, 170, 255))
			elseif result == "Open" then
				shout("OPEN!", Color3.fromRGB(255, 200, 70), 60)
			end
		end
	elseif kind == "Gassed" then
		-- only ever sent to me
		staminaFlash = os.clock() + 0.35
		shout("NO STAMINA", Color3.fromRGB(200, 200, 200), 42)
	elseif kind == "Parried" then
		play("Block", a, 1.35)
		if a == me or b == me then
			shout("PARRY!", Color3.fromRGB(120, 200, 255), 70)
			addShake(0.4)
		end
	elseif kind == "Whiff" then
		play("Whoosh", a)
	elseif kind == "Slipped" then
		play("Whoosh", a, 1.2)
		if a == me then
			shout("SLIPPED!", Color3.fromRGB(120, 255, 160), 60)
		end
	elseif kind == "Down" then
		play("Crowd", a)
		shout("DOWN!", Color3.fromRGB(255, 60, 60), 110)
		addShake(if a == me then 2 else 0.8)
	elseif kind == "KO" then
		play("Bell", a)
		play("Crowd", a, 1.05)
		shout("K.O.!", Color3.fromRGB(255, 50, 50), 140)
	elseif kind == "SecondWind" and typeof(a) == "Instance" then
		play("Crowd", a, 1.1)
		shout("SECOND WIND!", Color3.fromRGB(255, 170, 60), 100)
		if a == me then
			thought(Config.SecondWindLines[b] or "")
		end
	elseif kind == "GetUp" and a == me then
		shout("BACK UP!", Color3.fromRGB(255, 255, 255), 60)
	end
end)

-- after the camera scripts so the shake isn't overwritten
RunService:BindToRenderStep("BoxingHUD", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local me = player.Character
	if me then
		setBars(me)
		local state = me:GetAttribute("State")
		local downCount = me:GetAttribute("DownCount")
		if state == "Down" and downCount then
			count.TextTransparency = 0
			count.TextStrokeTransparency = 0
			count.Text = tostring(downCount)
			local progress = me:GetAttribute("GetUpProgress") or 0
			hint.Text = string.format("MASH SPACE TO GET UP  %d%%", math.floor(progress * 100))
		elseif state == "KO" then
			count.Text = ""
			hint.Text = "You got knocked out. Press Enter to go again"
		else
			count.TextTransparency = 1
			count.TextStrokeTransparency = 1
			hint.Text = CONTROLS
		end
		-- the opponent you're locked on to, or whoever you last traded with
		local other = lockedModel()
		if not other then
			for _, model in workspace:GetChildren() do
				if
					model:IsA("Model")
					and model ~= me
					and model:GetAttribute("State")
					and model:FindFirstChild("HumanoidRootPart")
				then
					local root = me:FindFirstChild("HumanoidRootPart")
					if root and (model.HumanoidRootPart.Position - root.Position).Magnitude < 10 then
						other = model
						break
					end
				end
			end
		end
		-- just their name, no bars, you read them off their body
		theirs.Visible = other ~= nil
		if other then
			theirName.Text = string.upper(other.Name)
		end
	end
	if shake > 0.01 then
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame
			* CFrame.Angles(math.rad((math.random() - 0.5) * shake * 3), math.rad((math.random() - 0.5) * shake * 3), 0)
		shake = math.max(0, shake - dt * 4)
	end
end)
