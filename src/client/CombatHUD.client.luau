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
local roundClock = gui:WaitForChild("RoundClock") :: ImageLabel
local roundText = roundClock:WaitForChild("Text") :: TextLabel
local ring = workspace:WaitForChild("Ring")

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

-- controls card: up for the first few seconds, then H toggles it
local UserInputService = game:GetService("UserInputService")
local controls = gui:WaitForChild("Controls") :: CanvasGroup
local controlsOpen = true
local CARD = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
local function showControls(open: boolean)
	controlsOpen = open
	if open then
		controls.Visible = true
	end
	local t = TweenService:Create(controls, CARD, { GroupTransparency = if open then 0 else 1 })
	t:Play()
	if not open then
		t.Completed:Once(function()
			if not controlsOpen then
				controls.Visible = false
			end
		end)
	end
end
task.delay(8, function()
	if controlsOpen then
		showControls(false)
	end
end)
-- never up during a ring match, it covers the other boxer
local function inMatch(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("InMatch") == true
end
local function watchMatch(character: Model)
	character:GetAttributeChangedSignal("InMatch"):Connect(function()
		if inMatch() and controlsOpen then
			showControls(false)
		end
	end)
end
player.CharacterAdded:Connect(watchMatch)
if player.Character then
	watchMatch(player.Character)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H and (controlsOpen or not inMatch()) then
		showControls(not controlsOpen)
	end
end)

-- the bottom line only says something when there's something to say
-- the hint lives bottom right, but down and KO messages go back to the middle
local HINT_CORNER = { AnchorPoint = hint.AnchorPoint, Position = hint.Position, Align = hint.TextXAlignment }
local function centerHint(center: boolean)
	hint.AnchorPoint = if center then Vector2.new(0.5, 1) else HINT_CORNER.AnchorPoint
	hint.Position = if center then UDim2.new(0.5, 0, 1, -14) else HINT_CORNER.Position
	hint.TextXAlignment = if center then Enum.TextXAlignment.Center else HINT_CORNER.Align
end

local function idleHint(): string
	return if controlsOpen then "" else "H - CONTROLS"
end
hint.Text = idleHint()

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

-- each fill has an arrow Tip riding on its end. the body only goes as far as the tip lets it,
-- so a full bar puts the tip right in the track's point
local function usable(fill: ImageLabel): number
	local clipSize = (fill.Parent :: Frame).AbsoluteSize
	if clipSize.X <= 0 then
		return 1
	end
	return 1 - (clipSize.Y * 0.5) / clipSize.X
end

local function setFill(fill: ImageLabel, share: number, speed: number)
	share = math.clamp(share, 0, 1)
	fill.Size = fill.Size:Lerp(UDim2.fromScale(share * usable(fill), 1), speed)
	local tip = fill:FindFirstChild("Tip") :: ImageLabel?
	if tip then
		tip.Visible = fill.Size.X.Scale > 0.003
		tip.ImageColor3 = fill.ImageColor3
	end
end

local function setBars(model: Model)
	local healthShare = math.clamp((model:GetAttribute("Health") or Config.MaxHealth) / Config.MaxHealth, 0, 1)
	setFill(fills.Health, healthShare, 0.3)
	-- the ghost waits for the real bar, then catches up slowly so you see the size of the hit
	local target = healthShare * usable(ghost)
	local ghostShare = ghost.Size.X.Scale
	ghost.Size = UDim2.fromScale(if target > ghostShare then target else ghostShare + (target - ghostShare) * 0.04, 1)
	local ghostTip = ghost:FindFirstChild("Tip") :: ImageLabel?
	if ghostTip then
		ghostTip.Visible = ghost.Size.X.Scale > 0.003
	end
	local maxNow = model:GetAttribute("MaxHealthNow") or Config.MaxHealth
	-- the dark lost chunk sits at the end of the bar with its own point, like the fills
	local lostShare = math.clamp(1 - maxNow / Config.MaxHealth, 0, 1)
	local room = usable(ghost)
	lost.Position = UDim2.fromScale(room, 0)
	lost.Size = UDim2.fromScale(lostShare * room, 1)
	local lostTip = lost:FindFirstChild("Tip") :: ImageLabel?
	if lostTip then
		lostTip.Visible = lostShare > 0
	end

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

-- stance box next to the panel: stance name, G cooldown, and the two specials with a dark
-- sweep that drains as they come back
local stanceBox = mine:WaitForChild("Stance") :: Frame
local stanceText = stanceBox:WaitForChild("Banner"):WaitForChild("StanceText") :: TextLabel
local switchFill = stanceBox:WaitForChild("SwitchBar"):WaitForChild("Fill") :: Frame
local slots = { stanceBox:WaitForChild("Slot1") :: ImageLabel, stanceBox:WaitForChild("Slot2") :: ImageLabel }

local function setStance(model: Model)
	local stance = Config.Stances[model:GetAttribute("Stance") or ""]
	if not stance then
		return
	end
	stanceText.Text = stance.Name
	local now = workspace:GetServerTimeNow()
	local switchLeft = math.max(0, (model:GetAttribute("StanceReady") or 0) - now)
	switchFill.Size = UDim2.fromScale(1 - switchLeft / Config.StanceSwitchCooldown, 1)
	for i, slot in slots do
		local name = stance.Specials[i]
		local sp = Config.Specials[name];
		(slot:FindFirstChild("NameText") :: TextLabel).Text = if sp then sp.Name else ""
		local left = if sp then math.max(0, (model:GetAttribute("Ready" .. name) or 0) - now) else 0
		local share = if sp then left / sp.Cooldown else 1
		-- step counter only works out of a counter window, grey it out until one opens
		if sp and sp.OnlyInCounter and share == 0 then
			local counterUntil = model:GetAttribute("CounterUntil")
			share = if typeof(counterUntil) == "number" and counterUntil > now then 0 else 0.999
		end
		(slot:FindFirstChild("Sweep") :: Frame).Size = UDim2.fromScale(1, share)
	end
end

local shake = 0
local function addShake(amount: number)
	shake = math.max(shake, amount)
end

-- a name with numbered copies (Thud1, Thud2...) plays a random one so it doesn't get samey
local function play(name: string, at: Instance?, pitch: number?)
	local template = sounds:FindFirstChild(name)
	if not template then
		local pool = {}
		for _, s in sounds:GetChildren() do
			if s.Name:match("^" .. name .. "%d+$") then
				table.insert(pool, s)
			end
		end
		template = pool[math.random(math.max(#pool, 1))]
	end
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
	-- specials borrow the feel of the base punch they're like
	if typeof(move) == "string" then
		move = Config.feelOf(move)
	end
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
			if result == "Counter" or result == "GuardBreak" then
				play("Cheer", target)
			end
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
		play("Thud", a)
		play("Cheer", a)
		shout("DOWN!", Color3.fromRGB(255, 60, 60), 110)
		addShake(if a == me then 2 else 0.8)
	elseif kind == "KO" then
		play("Thud", a)
		play("Bell", a)
		play("Cheer", a, 1.05)
		shout("K.O.!", Color3.fromRGB(255, 50, 50), 140)
	elseif kind == "SecondWind" and typeof(a) == "Instance" then
		play("Cheer", a, 1.1)
		shout("SECOND WIND!", Color3.fromRGB(255, 170, 60), 100)
		if a == me then
			thought(Config.SecondWindLines[b] or "")
		end
	elseif kind == "Match" and typeof(a) == "string" then
		shout(a, Color3.fromRGB(255, 255, 255), if #a > 12 then 70 else 110)
		if b == "Bell" then
			play("Bell", me)
		end
	elseif kind == "Count" then
		-- the ref slapping the canvas, a touch higher every count
		play("Count", a, 0.95 + (tonumber(b) or 1) * 0.02)
	elseif kind == "GetUp" and a == me then
		shout("BACK UP!", Color3.fromRGB(255, 255, 255), 60)
	elseif kind == "Special" and typeof(b) == "string" and Config.Specials[b] then
		if a == me or a == lockedModel() then
			shout(Config.Specials[b].Name .. "!", Color3.fromRGB(255, 140, 50), 70)
		end
	end
end)

-- after the camera scripts so the shake isn't overwritten
RunService:BindToRenderStep("BoxingHUD", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local me = player.Character
	-- round clock while a ring match is on and you're close enough to watch it
	local endsAt = ring:GetAttribute("MatchEndsAt")
	local myRoot = me and me:FindFirstChild("HumanoidRootPart")
	roundClock.Visible = typeof(endsAt) == "number"
		and myRoot ~= nil
		and ((myRoot :: BasePart).Position - ring:GetPivot().Position).Magnitude < 70
	if roundClock.Visible then
		local left = math.max(0, math.ceil((endsAt :: number) - workspace:GetServerTimeNow()))
		roundText.Text = string.format("ROUND %d  %d:%02d", ring:GetAttribute("MatchRound") or 1, left // 60, left % 60)
	end
	if me then
		setBars(me)
		setStance(me)
		local state = me:GetAttribute("State")
		local downCount = me:GetAttribute("DownCount")
		if state == "Down" and downCount then
			count.TextTransparency = 0
			count.TextStrokeTransparency = 0
			count.Text = tostring(downCount)
			local progress = me:GetAttribute("GetUpProgress") or 0
			hint.Text = string.format("MASH SPACE TO GET UP  %d%%", math.floor(progress * 100))
			centerHint(true)
		elseif state == "KO" then
			count.Text = ""
			hint.Text = if me:GetAttribute("InMatch") then "" else "You got knocked out. Press Enter to go again"
			centerHint(true)
		else
			count.TextTransparency = 1
			count.TextStrokeTransparency = 1
			hint.Text = idleHint()
			centerHint(false)
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
