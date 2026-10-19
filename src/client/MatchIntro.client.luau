--!strict
-- The VS screen before a ring match (StarterGui.MatchIntro, built in studio): both boxers'
-- names, ranks and records slide in from their corners, VS pops in the middle with the bell,
-- then it all clears before round 1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchIntro") :: ScreenGui
local root = gui:WaitForChild("Root") :: Frame
local red = root:WaitForChild("Red") :: ImageLabel
local blue = root:WaitForChild("Blue") :: ImageLabel
local vs = root:WaitForChild("VS") :: ImageLabel
local vsScale = vs:WaitForChild("UIScale") :: UIScale
local title = root:WaitForChild("Title") :: TextLabel
local bell = ReplicatedStorage:WaitForChild("BoxingSounds"):FindFirstChild("Bell")

local SLIDE = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POP = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOME = { Red = red.Position, Blue = blue.Position }

local function fill(card: ImageLabel, info: any)
	if typeof(info) ~= "table" then
		return
	end
	-- their avatar headshot on the right, same as the one on the hud panel
	local portrait = card:WaitForChild("Portrait") :: ImageLabel
	portrait.Image = ""
	local userId = tonumber(info.UserId)
	if userId then
		task.spawn(function()
			local ok, image = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				math.max(userId, 1),
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size180x180
			)
			if ok then
				portrait.Image = image
			end
		end)
	end
	(card:WaitForChild("Name") :: TextLabel).Text = string.upper(tostring(info.Name or "?"));
	(card:WaitForChild("Rank") :: TextLabel).Text = tostring(info.Rank or "ROOKIE");
	(card:WaitForChild("Record") :: TextLabel).Text = string.format(
		"%d - %d - %d   %d KO",
		tonumber(info.Wins) or 0,
		tonumber(info.Losses) or 0,
		tonumber(info.Draws) or 0,
		tonumber(info.KOs) or 0
	)
end

local token = 0
fx.OnClientEvent:Connect(function(kind, a, b)
	if kind ~= "Intro" then
		return
	end
	token += 1
	local mine = token
	fill(red, a)
	fill(blue, b)
	-- in from off screen on their own side
	red.Position = HOME.Red - UDim2.fromScale(0.7, 0)
	blue.Position = HOME.Blue + UDim2.fromScale(0.7, 0)
	vsScale.Scale = 0
	title.TextTransparency, title.TextStrokeTransparency = 1, 1
	root.BackgroundTransparency = 1
	root.Visible = true
	TweenService:Create(root, OUT, { BackgroundTransparency = 0.5 }):Play()
	TweenService:Create(red, SLIDE, { Position = HOME.Red }):Play()
	TweenService:Create(blue, SLIDE, { Position = HOME.Blue }):Play()
	TweenService:Create(title, OUT, { TextTransparency = 0, TextStrokeTransparency = 0 }):Play()
	task.delay(0.45, function()
		if mine ~= token then
			return
		end
		TweenService:Create(vsScale, POP, { Scale = 1 }):Play()
		if bell and bell:IsA("Sound") then
			-- sounds don't play from ReplicatedStorage, a copy goes in the gui
			local s = bell:Clone()
			s.Parent = gui
			s:Play()
			s.Ended:Once(function()
				s:Destroy()
			end)
		end
	end)
	-- out a beat before round 1 gets called
	task.delay(Config.Match.Intro - 0.6, function()
		if mine ~= token then
			return
		end
		TweenService:Create(red, OUT, { Position = HOME.Red - UDim2.fromScale(0.7, 0) }):Play()
		TweenService:Create(blue, OUT, { Position = HOME.Blue + UDim2.fromScale(0.7, 0) }):Play()
		TweenService:Create(vsScale, OUT, { Scale = 0 }):Play()
		TweenService:Create(title, OUT, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(root, OUT, { BackgroundTransparency = 1 }):Play()
		task.delay(0.35, function()
			if mine == token then
				root.Visible = false
			end
		end)
	end)
end)
