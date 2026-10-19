--!strict
-- Shows the training drill (StarterGui.BoxingMenu.Drill, built in studio). Notes slide to the
-- hit line, you press on the beat. The server grades it, this only draws and sends presses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Stats = require(ReplicatedStorage.Shared.Stats)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Training") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("BoxingMenu") :: ScreenGui
local drill = gui:WaitForChild("Drill") :: ImageLabel
local titleText = drill:WaitForChild("Title"):WaitForChild("Text") :: TextLabel
local score = drill:WaitForChild("Score") :: TextLabel
local notes = drill:WaitForChild("Lane"):WaitForChild("Notes") :: Frame
local template = notes:WaitForChild("Note") :: ImageLabel
local hitRing = notes:WaitForChild("HitRing") :: ImageLabel
local grade = drill:WaitForChild("Grade") :: TextLabel
local hitButton = drill:WaitForChild("HitButton") :: ImageButton

local NAMES = { Power = "HEAVY BAG", Technique = "BAG WORK", Stamina = "JUMP ROPE", Speed = "MITTS" }
local COLORS = {
	Perfect = Color3.fromRGB(255, 200, 40),
	Good = Color3.fromRGB(120, 220, 140),
	Miss = Color3.fromRGB(230, 60, 50),
}
local HIT_X = 0.12 -- where the hit line sits in the lane
local LOOKAHEAD = 1.6 -- seconds of notes visible ahead of the line
local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local active = false
local start = 0
local times: { number } = {}
local marks: { ImageLabel } = {}
local graded: { [number]: string } = {}
local lastPress = 0

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

-- space is the drill button, so no jumping until it's over
local function setJump(on: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, on and character:GetAttribute("FightMode") == false)
	end
end

local function press()
	local now = os.clock()
	-- the server ignores mashing anyway, this just keeps the remote quiet
	if not active or now - lastPress < 0.12 then
		return
	end
	lastPress = now
	remote:FireServer("Hit")
	local ringScale = hitRing:WaitForChild("UIScale") :: UIScale
	ringScale.Scale = 1.25
	TweenService:Create(ringScale, POP, { Scale = 1 }):Play()
end

remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Start" and typeof(a) == "string" and typeof(b) == "number" and typeof(c) == "table" then
		for _, m in marks do
			m:Destroy()
		end
		table.clear(marks)
		table.clear(graded)
		start, times = b, c
		for i in times do
			local m = template:Clone()
			m.Name = "Note" .. i
			m.Visible = true
			m.Parent = notes
			marks[i] = m
		end
		titleText.Text = (NAMES[a] or "TRAINING") .. "  -  " .. string.upper(a)
		grade.Text = "READY"
		grade.TextColor3 = Color3.fromRGB(14, 13, 12)
		updateScore()
		hitButton.Visible = UserInputService.TouchEnabled
		drill.Visible = true
		active = true
		setJump(false)
	elseif kind == "Grade" and typeof(a) == "number" and typeof(b) == "string" and marks[a] then
		graded[a] = b
		marks[a].Visible = false
		showGrade(string.upper(b) .. "!", COLORS[b] or COLORS.Good)
		updateScore()
	elseif kind == "Done" and typeof(a) == "number" then
		active = false
		setJump(true)
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
	local now = workspace:GetServerTimeNow() - start
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
	if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
		press()
	end
end)
hitButton.Activated:Connect(press)
