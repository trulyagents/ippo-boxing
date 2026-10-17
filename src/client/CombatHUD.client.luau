-- Bars for you and your opponent, big call-outs (COUNTER, DOWN), the ref count,
-- punch sounds and screen shake.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local sounds = ReplicatedStorage:WaitForChild("BoxingSounds")

local font = Font.new("rbxasset://fonts/families/Bangers.json")
local bodyFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local gui = Instance.new("ScreenGui")
gui.Name = "BoxingHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(parent: Instance, name: string, color: Color3, y: number): Frame
	local back = Instance.new("Frame")
	back.Name = name
	back.Position = UDim2.new(0, 0, 0, y)
	back.Size = UDim2.new(1, 0, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = parent
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	return back
end

local function panel(position: UDim2, anchor: Vector2, title: string): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = UDim2.fromOffset(300, 88)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextSize = 24
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = title
	label.Parent = frame
	bar(frame, "Health", Color3.fromRGB(215, 45, 45), 26)
	bar(frame, "Stamina", Color3.fromRGB(235, 190, 50), 44)
	bar(frame, "Guard", Color3.fromRGB(70, 140, 230), 62)
	local courage = bar(frame, "Courage", Color3.fromRGB(255, 140, 40), 80)
	courage.Size = UDim2.new(1, 0, 0, 6)
	-- health gets a pale ghost that trails the real bar, and a dark end for max health lost
	local health = frame:FindFirstChild("Health") :: Frame
	local ghost = (health:FindFirstChild("Fill") :: Frame):Clone()
	ghost.Name = "Ghost"
	ghost.BackgroundColor3 = Color3.fromRGB(255, 225, 200)
	ghost.ZIndex = 1
	ghost.Parent = health
	;(health:FindFirstChild("Fill") :: Frame).ZIndex = 2
	local lost = Instance.new("Frame")
	lost.Name = "Lost"
	lost.AnchorPoint = Vector2.new(1, 0)
	lost.Position = UDim2.fromScale(1, 0)
	lost.Size = UDim2.fromScale(0, 1)
	lost.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
	lost.BorderSizePixel = 0
	lost.ZIndex = 3
	lost.Parent = health
	Instance.new("UICorner", lost).CornerRadius = UDim.new(0, 4)
	return frame, label
end

-- studio only test button
if RunService:IsStudio() then
	local test = Instance.new("TextButton")
	test.Name = "TestSecondWind"
	test.AnchorPoint = Vector2.new(1, 1)
	test.Position = UDim2.new(1, -24, 1, -70)
	test.Size = UDim2.fromOffset(170, 34)
	test.BackgroundColor3 = Color3.fromRGB(150, 70, 20)
	test.TextColor3 = Color3.new(1, 1, 1)
	test.FontFace = bodyFont
	test.TextSize = 15
	test.Text = "TEST SECOND WIND"
	test.Parent = gui
	Instance.new("UICorner", test).CornerRadius = UDim.new(0, 6)
	test.Activated:Connect(function()
		(ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Action") :: RemoteEvent):FireServer("TestSecondWind")
	end)
end

local mine = panel(UDim2.new(0, 24, 1, -24), Vector2.new(0, 1), "YOU")
local theirs, theirName = panel(UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0), "")
theirs.Visible = false

local callout = Instance.new("TextLabel")
callout.AnchorPoint = Vector2.new(0.5, 0.5)
callout.Position = UDim2.fromScale(0.5, 0.36)
callout.Size = UDim2.fromOffset(600, 90)
callout.BackgroundTransparency = 1
callout.FontFace = font
callout.TextSize = 80
callout.TextColor3 = Color3.fromRGB(255, 220, 60)
callout.TextStrokeTransparency = 0
callout.TextTransparency = 1
callout.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
callout.Parent = gui

local count = callout:Clone()
count.Position = UDim2.fromScale(0.5, 0.52)
count.TextSize = 120
count.TextColor3 = Color3.new(1, 1, 1)
count.Parent = gui

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -30)
hint.Size = UDim2.fromOffset(700, 24)
hint.BackgroundTransparency = 1
hint.FontFace = bodyFont
hint.TextSize = 15
hint.TextColor3 = Color3.fromRGB(230, 230, 230)
hint.TextStrokeTransparency = 0.5
local CONTROLS = "M1 jab  M2 cross  E hook  R uppercut  Q body  |  hold F guard (look down = low)  |  hold Space weave + A/D/W/S  |  T lock on (V swap side, scroll switch)"
hint.Text = CONTROLS
hint.Parent = gui

local function shout(text: string, color: Color3?, size: number?)
	callout.Text = text
	callout.TextColor3 = color or Color3.fromRGB(255, 220, 60)
	callout.TextSize = (size or 80) * 1.3
	callout.TextTransparency = 0
	callout.TextStrokeTransparency = 0
	TweenService:Create(callout, TweenInfo.new(0.18, Enum.EasingStyle.Back), { TextSize = size or 80 }):Play()
	task.delay(0.7, function()
		if callout.Text == text then
			TweenService:Create(callout, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local STAMINA_COLOR = Color3.fromRGB(235, 190, 50)
local GASSED_COLOR = Color3.fromRGB(230, 70, 40)
local staminaFlash = 0 -- os.clock() until which my stamina bar flashes after a gassed punch

local COURAGE_COLOR = Color3.fromRGB(255, 140, 40)
local COURAGE_HOT = Color3.fromRGB(255, 235, 120)

-- inner thought line for a second wind, quiet italic text low on the screen
local thoughtLabel = Instance.new("TextLabel")
thoughtLabel.AnchorPoint = Vector2.new(0.5, 0.5)
thoughtLabel.Position = UDim2.fromScale(0.5, 0.7)
thoughtLabel.Size = UDim2.fromOffset(800, 40)
thoughtLabel.BackgroundTransparency = 1
thoughtLabel.FontFace = Font.new(bodyFont.Family, Enum.FontWeight.Medium, Enum.FontStyle.Italic)
thoughtLabel.TextSize = 26
thoughtLabel.TextColor3 = Color3.fromRGB(255, 245, 230)
thoughtLabel.TextStrokeTransparency = 0.5
thoughtLabel.TextTransparency = 1
thoughtLabel.Parent = gui

local function thought(text: string)
	thoughtLabel.Text = "\"" .. text .. "\""
	thoughtLabel.TextTransparency = 1
	thoughtLabel.TextStrokeTransparency = 1
	TweenService:Create(thoughtLabel, TweenInfo.new(0.6), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	task.delay(3.2, function()
		if thoughtLabel.Text == "\"" .. text .. "\"" then
			TweenService:Create(thoughtLabel, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function setBars(frame: Frame, model: Model)
	local health = frame:FindFirstChild("Health") :: Frame
	local healthShare = math.clamp((model:GetAttribute("Health") or Config.MaxHealth) / Config.MaxHealth, 0, 1)
	-- the ghost waits for the real bar, then catches up slowly so you see the size of the hit
	local ghost = health:FindFirstChild("Ghost") :: Frame
	local ghostShare = ghost.Size.X.Scale
	ghost.Size = UDim2.fromScale(if healthShare > ghostShare then healthShare else ghostShare + (healthShare - ghostShare) * 0.04, 1)
	local maxNow = model:GetAttribute("MaxHealthNow") or Config.MaxHealth
	local lost = health:FindFirstChild("Lost") :: Frame
	lost.Size = UDim2.fromScale(math.clamp(1 - maxNow / Config.MaxHealth, 0, 1), 1)
	local courage = model:GetAttribute("Courage") or 0
	local courageFill = (frame:FindFirstChild("Courage") :: Frame):FindFirstChild("Fill") :: Frame
	courageFill.Size = courageFill.Size:Lerp(UDim2.fromScale(courage / Config.MaxCourage, 1), 0.2)
	-- 90+ is when a second wind gets likely, make it glow
	courageFill.BackgroundColor3 = if courage >= 90
		then COURAGE_COLOR:Lerp(COURAGE_HOT, 0.5 + 0.5 * math.sin(os.clock() * 8))
		else COURAGE_COLOR
	for _, stat in { "Health", "Stamina", "Guard" } do
		local max = Config["Max" .. stat]
		local value = model:GetAttribute(stat) or max
		local fill = frame:FindFirstChild(stat):FindFirstChild("Fill") :: Frame
		fill.Size = fill.Size:Lerp(UDim2.fromScale(math.clamp(value / max, 0, 1), 1), 0.3)
		if stat == "Stamina" then
			-- under the gassed line the bar throbs red so you know punches are slow
			local pulse = 0
			if value < Config.GassedBelow then
				pulse = 0.5 + 0.5 * math.sin(os.clock() * 10)
			end
			if frame == mine and os.clock() < staminaFlash then
				pulse = 1
			end
			fill.BackgroundColor3 = STAMINA_COLOR:Lerp(GASSED_COLOR, pulse)
		end
	end
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

fx.OnClientEvent:Connect(function(kind, a, b, move, result, damage, counterName)
	local me = player.Character
	if kind == "Hit" then
		local attacker, target = a, b
		local involved = attacker == me or target == me
		if result == "Blocked" then
			play("Block", target)
		elseif result == "Chip" then
			play("HitLight", target)
		else
			play(if move == "Jab" then "HitLight" elseif move == "Cross" or move == "Body" then "HitMedium" else "HitHeavy", target)
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
		setBars(mine, me)
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
				if model:IsA("Model") and model ~= me and model:GetAttribute("State") and model:FindFirstChild("HumanoidRootPart") then
					local root = me:FindFirstChild("HumanoidRootPart")
					if root and (model.HumanoidRootPart.Position - root.Position).Magnitude < 10 then
						other = model
						break
					end
				end
			end
		end
		theirs.Visible = other ~= nil
		if other then
			theirName.Text = string.upper(other.Name)
			setBars(theirs, other)
		end
	end
	if shake > 0.01 then
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame * CFrame.Angles(
			math.rad((math.random() - 0.5) * shake * 3),
			math.rad((math.random() - 0.5) * shake * 3),
			0
		)
		shake = math.max(0, shake - dt * 4)
	end
end)
