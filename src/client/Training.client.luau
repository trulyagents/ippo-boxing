--!strict
-- Shows the training minigames (StarterGui.BoxingMenu.Drill, built in studio). Each station has
-- its own: notes on a lane (Rhythm, Combo), a hold meter (Charge) or a mitt that flashes up
-- (Reaction). The server grades everything, this only draws and sends what you pressed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AnimIds = require(ReplicatedStorage.Shared.AnimIds)
local Stats = require(ReplicatedStorage.Shared.Stats)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Training") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("BoxingMenu") :: ScreenGui
local drill = gui:WaitForChild("Drill") :: ImageLabel
local titleText = drill:WaitForChild("Title"):WaitForChild("Text") :: TextLabel
local score = drill:WaitForChild("Score") :: TextLabel
local hint = drill:WaitForChild("Hint") :: TextLabel
local lane = drill:WaitForChild("Lane") :: ImageLabel
local notes = lane:WaitForChild("Notes") :: Frame
local template = notes:WaitForChild("Note") :: ImageLabel
local hitRing = notes:WaitForChild("HitRing") :: ImageLabel
local charge = drill:WaitForChild("Charge") :: ImageLabel
local chargeClip = charge:WaitForChild("Clip")
local chargeFill = chargeClip:WaitForChild("Fill") :: ImageLabel
local target = drill:WaitForChild("Target") :: ImageLabel
local grade = drill:WaitForChild("Grade") :: TextLabel
local hitButton = drill:WaitForChild("HitButton") :: ImageButton

local NAMES = { Power = "HEAVY BAG", Technique = "BAG WORK", Stamina = "JUMP ROPE", Speed = "MITTS" }
local HINTS = {
	Rhythm = "SPACE OR CLICK ON THE BEAT, IT SPEEDS UP",
	Combo = "THROW THE PUNCH ON THE NOTE: M1 JAB, M2 CROSS, E HOOK",
	Charge = "HOLD SPACE OR CLICK, LET GO IN THE GOLD",
	Reaction = "HIT THE MITT THE MOMENT IT COMES UP",
}
local COLORS = {
	Perfect = Color3.fromRGB(255, 200, 40),
	Good = Color3.fromRGB(120, 220, 140),
	Miss = Color3.fromRGB(230, 60, 50),
}
local COMBO_KEYS = {
	[Enum.UserInputType.MouseButton1] = "Jab",
	[Enum.UserInputType.MouseButton2] = "Cross",
	[Enum.KeyCode.E] = "Hook",
}
local HIT_X = 0.12 -- where the hit line sits in the lane
local LOOKAHEAD = 1.6 -- seconds of notes visible ahead of the line
local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local active = false
local kind = ""
local start = 0
local times: { number } = {}
local marks: { ImageLabel } = {}
local graded: { [number]: string } = {}
local lastPress = 0
local holdingSince: number? = nil

-- the jump rope drill skips in time: g2's skip anim is 1s with a skip every half second, so it
-- runs at whatever speed puts a skip on each beat as they speed up
local SKIP_EVERY = 0.5
local ropeAnim = Instance.new("Animation")
ropeAnim.AnimationId = AnimIds.JumpRope
local ropeTrack: AnimationTrack? = nil
local function stopRope()
	if ropeTrack then
		ropeTrack:Stop(0.2)
		ropeTrack = nil
	end
end
local function startRope()
	stopRope()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local track = animator:LoadAnimation(ropeAnim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
		ropeTrack = track
	end
end

local function showGrade(text: string, color: Color3)
	grade.Text = text
	grade.TextColor3 = color
	local scale = grade:WaitForChild("UIScale") :: UIScale
	scale.Scale = 1.4
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
end

local function updateScore()
	local hits = 0
	for _, g in graded do
		if g ~= "Miss" then
			hits += 1
		end
	end
	score.Text = string.format("%d / %d", hits, #times)
end

-- space is a drill button, so no jumping until it's over
local function setJump(on: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, on and character:GetAttribute("FightMode") == false)
	end
end

local function send(what: string, key: string?)
	remote:FireServer(what, key)
end

local function press(key: string?)
	local now = os.clock()
	-- the server ignores mashing anyway, this just keeps the remote quiet
	if not active or now - lastPress < 0.1 then
		return
	end
	lastPress = now
	send("Hit", key)
	local ringScale = hitRing:WaitForChild("UIScale") :: UIScale
	ringScale.Scale = 1.25
	TweenService:Create(ringScale, POP, { Scale = 1 }):Play()
end

local function holdStart()
	if active and kind == "Charge" and not holdingSince and workspace:GetServerTimeNow() >= start then
		holdingSince = os.clock()
		send("Down")
	end
end

local function holdEnd()
	if holdingSince then
		holdingSince = nil
		send("Up")
	end
end

-- the gold and green zones on the charge meter, from the server's own numbers
local function layoutCharge()
	local perfect = chargeClip:WaitForChild("Perfect") :: Frame
	local good = chargeClip:WaitForChild("Good") :: Frame
	perfect.Position = UDim2.fromScale((Stats.ChargeTarget - Stats.ChargePerfect) / Stats.ChargeMax, 0)
	perfect.Size = UDim2.fromScale(2 * Stats.ChargePerfect / Stats.ChargeMax, 1)
	good.Position = UDim2.fromScale((Stats.ChargeTarget - Stats.ChargeGood) / Stats.ChargeMax, 0)
	good.Size = UDim2.fromScale(2 * Stats.ChargeGood / Stats.ChargeMax, 1)
	chargeFill.Size = UDim2.fromScale(0, 1)
end

remote.OnClientEvent:Connect(function(event, a, b, c, stand)
	if event == "Start" and typeof(a) == "string" and typeof(b) == "number" and typeof(c) == "table" then
		-- stood a punch away from the bag or mitts, facing them
		local character = player.Character
		if character and typeof(stand) == "CFrame" then
			character:PivotTo(stand)
		end
		local drillInfo = Stats.Drills[a]
		kind = drillInfo and drillInfo.Kind or "Rhythm"
		for _, m in marks do
			m:Destroy()
		end
		table.clear(marks)
		table.clear(graded)
		start, times = b, c
		holdingSince = nil
		local lanes = kind == "Rhythm" or kind == "Combo"
		lane.Visible = lanes
		charge.Visible = kind == "Charge"
		target.Visible = false
		if lanes then
			for i in times do
				local m = template:Clone()
				m.Name = "Note" .. i
				m.Visible = true;
				(m:WaitForChild("Key") :: TextLabel).Text = if kind == "Combo" and drillInfo.Keys
					then Stats.ComboInputs[drillInfo.Keys[(i - 1) % #drillInfo.Keys + 1]]
					else ""
				m.Parent = notes
				marks[i] = m
			end
		end
		if kind == "Charge" then
			layoutCharge()
		end
		titleText.Text = (NAMES[a] or "TRAINING") .. "  -  " .. string.upper(a)
		hint.Text = HINTS[kind] or ""
		grade.Text = "READY"
		grade.TextColor3 = Color3.fromRGB(14, 13, 12)
		updateScore()
		hitButton.Visible = UserInputService.TouchEnabled and kind ~= "Combo"
		drill.Visible = true
		active = true
		setJump(false)
		if kind == "Rhythm" then
			-- a beat late, the animator stops every track when fight mode switches on
			task.delay(0.2, function()
				if active and kind == "Rhythm" then
					startRope()
				end
			end)
		end
	elseif event == "Cue" and typeof(a) == "number" then
		target.Visible = true
		local scale = target:WaitForChild("UIScale") :: UIScale
		scale.Scale = 0.4
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	elseif event == "Grade" and typeof(a) == "number" and typeof(b) == "string" then
		graded[a] = b
		if marks[a] then
			marks[a].Visible = false
		end
		target.Visible = false
		showGrade(string.upper(b) .. "!", COLORS[b] or COLORS.Good)
		updateScore()
	elseif event == "Done" and typeof(a) == "number" then
		active = false
		holdingSince = nil
		target.Visible = false
		setJump(true)
		stopRope()
		showGrade(if a > 0 then "DONE" else "TRY AGAIN", if a > 0 then COLORS.Perfect else COLORS.Miss)
		task.delay(1, function()
			if not active then
				drill.Visible = false
			end
		end)
	end
end)

RunService.RenderStepped:Connect(function()
	if not active then
		return
	end
	if kind == "Charge" then
		local held = if holdingSince then os.clock() - holdingSince else 0
		chargeFill.Size = UDim2.fromScale(math.min(held / Stats.ChargeMax, 1), 1)
		return
	end
	if kind ~= "Rhythm" and kind ~= "Combo" then
		return
	end
	local now = workspace:GetServerTimeNow() - start
	if ropeTrack then
		-- the gap to the next beat sets the skip speed
		local gap = SKIP_EVERY
		for i = 2, #times do
			if times[i] > now then
				gap = times[i] - times[i - 1]
				break
			end
		end
		ropeTrack:AdjustSpeed(SKIP_EVERY / gap)
	end
	for i, t in times do
		local m = marks[i]
		if m and m.Visible then
			local x = HIT_X + (t - now) / LOOKAHEAD * (1 - HIT_X)
			m.Position = UDim2.fromScale(x, 0.5)
			-- went past the line with nothing pressed
			if now - t > Stats.DrillGood + 0.13 and not graded[i] then
				graded[i] = "Miss"
				m.Visible = false
				showGrade("MISS", COLORS.Miss)
				updateScore()
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not active then
		return
	end
	local main = input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1
	if kind == "Combo" then
		local key = COMBO_KEYS[input.KeyCode] or COMBO_KEYS[input.UserInputType]
		if key then
			press(key)
		end
	elseif kind == "Charge" then
		if main then
			holdStart()
		end
	elseif main then
		press()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdEnd()
	end
end)
hitButton.MouseButton1Down:Connect(function()
	if kind == "Charge" then
		holdStart()
	else
		press()
	end
end)
hitButton.MouseButton1Up:Connect(holdEnd)
