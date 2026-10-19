--!strict
-- Drives the menu (StarterGui.BoxingMenu, built in studio, copy in ui/). M or the corner button
-- opens it, it won't open mid fight. Also pops "+1 POWER" when training lands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)
local Stats = require(ReplicatedStorage.Shared.Stats)
local LockOn = require(script.Parent:WaitForChild("LockOn"))

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("BoxingMenu") :: ScreenGui
local button = gui:WaitForChild("MenuButton") :: ImageButton
local gain = gui:WaitForChild("Gain") :: TextLabel
local menu = gui:WaitForChild("Menu") :: Frame
local sheet = menu:WaitForChild("Sheet") :: ImageLabel
local tabs = sheet:WaitForChild("Tabs")
local pages = { Stats = sheet:WaitForChild("StatsPage") :: Frame, Styles = sheet:WaitForChild("StylesPage") :: Frame }
local radar = pages.Stats:WaitForChild("Radar")
local shape = radar:WaitForChild("Shape")
local rows = pages.Stats:WaitForChild("Rows")
local cardTemplate = pages.Styles:WaitForChild("StyleCard") :: ImageLabel

local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
local RADIUS = 0.455 -- outer hexagon in radar.png, as a share of the image

local function stats(): { [string]: number }
	local out = {}
	for _, name in Stats.Names do
		out[name] = (player:GetAttribute("Stat" .. name) :: number?) or 0
	end
	return out
end

local function needsText(mine: { [string]: number }, unlock: string): string
	local parts = {}
	for _, m in Stats.missing(mine, unlock) do
		table.insert(parts, string.format("%s %d/%d", string.upper(m.Stat), m.Have, m.Need))
	end
	return table.concat(parts, "  ")
end

local function drawStats()
	local mine = stats()
	local tips = {}
	for i, name in Stats.Names do
		-- a sliver even at 0 so the shape never collapses to a dot
		local v = math.max(0.04, mine[name] / Stats.Cap)
		local a = math.rad(60 * (i - 1))
		tips[i] = Vector2.new(0.5 + math.sin(a) * RADIUS * v, 0.5 - math.cos(a) * RADIUS * v);
		(shape:WaitForChild("Spoke" .. name) :: Frame).Size = UDim2.fromScale(0.025, RADIUS * v)
		local row = rows:WaitForChild(name)
		local fill = row:WaitForChild("Track"):WaitForChild("Clip"):WaitForChild("Fill") :: ImageLabel
		fill.Size = UDim2.fromScale(mine[name] / Stats.Cap, 1);
		(row:WaitForChild("Value") :: TextLabel).Text = tostring(math.floor(mine[name]))
	end
	for i, p in tips do
		local q = tips[i % #tips + 1]
		local edge = shape:WaitForChild("Edge" .. i) :: Frame
		local d = q - p
		edge.Position = UDim2.fromScale((p.X + q.X) / 2, (p.Y + q.Y) / 2)
		edge.Size = UDim2.new(d.Magnitude, 0, 0.012, 0)
		edge.Rotation = math.deg(math.atan2(d.Y, d.X))
	end
end

local cards: { [string]: ImageLabel } = {}
local function drawStyles()
	local mine = stats()
	local character = player.Character
	local current = character and character:GetAttribute("Stance")
	for order, stance in Config.Loadout do
		local card = cards[stance]
		if not card then
			card = cardTemplate:Clone()
			card.Name = stance
			card.LayoutOrder = order
			card.Visible = true
			card.Parent = pages.Styles
			cards[stance] = card
			local list = card:WaitForChild("Specials")
			local rowTemplate = list:WaitForChild("SpecialRow") :: Frame
			for slot, special in Config.Stances[stance].Specials do
				local row = rowTemplate:Clone()
				row.Name = special
				row.LayoutOrder = slot
				row.Visible = true;
				(row:WaitForChild("Key"):WaitForChild("Text") :: TextLabel).Text = if slot == 1 then "Z" else "X";
				(row:WaitForChild("Name") :: TextLabel).Text = Config.Specials[special].Name
				row.Parent = list
			end
		end
		local open = Stats.unlocked(mine, stance);
		(card:WaitForChild("Name") :: TextLabel).Text = Config.Stances[stance].Name;
		(card:WaitForChild("Status"):WaitForChild("Text") :: TextLabel).Text = if current == stance
			then "EQUIPPED"
			elseif open then "G TO SWITCH"
			else "LOCKED";
		(card:WaitForChild("Needs") :: TextLabel).Text = if open then "" else "NEEDS " .. needsText(mine, stance);
		(card:WaitForChild("Locked") :: Frame).Visible = not open
		for _, special in Config.Stances[stance].Specials do
			local row = card:WaitForChild("Specials"):WaitForChild(special);
			(row:WaitForChild("Needs") :: TextLabel).Text = if Stats.unlocked(mine, special)
				then "READY"
				else "NEEDS " .. needsText(mine, special)
		end
	end
end

local tab = "Stats"
local function showTab(name: string)
	tab = name
	for n, page in pages do
		page.Visible = n == name
		local t = tabs:WaitForChild(n) :: ImageButton
		t.ImageColor3 = if n == name then Color3.new(1, 1, 1) else Color3.fromRGB(150, 145, 135);
		(t:WaitForChild("Text") :: TextLabel).TextTransparency = if n == name then 0 else 0.4
	end
	if name == "Stats" then
		drawStats()
	else
		drawStyles()
	end
end

local function inFight(): boolean
	local character = player.Character
	local state = character and character:GetAttribute("State")
	return LockOn.target() ~= nil or state == "Down" or state == "KO" or state == "Stunned"
end

local sheetScale = sheet:WaitForChild("UIScale") :: UIScale
local function setOpen(open: boolean)
	if open and inFight() then
		return
	end
	menu.Visible = open
	if open then
		sheetScale.Scale = 0.85
		TweenService:Create(sheetScale, POP, { Scale = 1 }):Play()
		showTab(tab)
	end
end

local close = sheet:WaitForChild("Close") :: ImageButton
button.Activated:Connect(function()
	setOpen(not menu.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
for name in pages do
	(tabs:WaitForChild(name) :: ImageButton).Activated:Connect(function()
		showTab(name)
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		setOpen(not menu.Visible)
	end
end)

-- little press pop on the corner button
local buttonScale = button:WaitForChild("UIScale") :: UIScale
button.MouseEnter:Connect(function()
	TweenService:Create(buttonScale, FAST, { Scale = 1.08 }):Play()
end)
button.MouseLeave:Connect(function()
	TweenService:Create(buttonScale, FAST, { Scale = 1 }):Play()
end)

-- "+1.5 POWER" when a stat goes up from training
local gainScale = gain:WaitForChild("UIScale") :: UIScale
local last = stats()
local fadeToken = 0
local function onStat(name: string)
	local now = (player:GetAttribute("Stat" .. name) :: number?) or 0
	local diff = now - last[name]
	last[name] = now
	if menu.Visible then
		showTab(tab)
	end
	-- drills give tenths, fight gains of 0.1 stay quiet
	if diff < 0.15 then
		return
	end
	fadeToken += 1
	local token = fadeToken
	local rounded = math.floor(diff * 10 + 0.5) / 10
	gain.Text = string.format(if rounded % 1 == 0 then "+%d %s" else "+%.1f %s", rounded, string.upper(name))
	gain.TextTransparency, gain.TextStrokeTransparency = 0, 0
	gainScale.Scale = 0.6
	TweenService:Create(gainScale, POP, { Scale = 1 }):Play()
	task.delay(1, function()
		if token == fadeToken then
			TweenService:Create(gain, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
for _, name in Stats.Names do
	player:GetAttributeChangedSignal("Stat" .. name):Connect(function()
		onStat(name)
	end)
end

-- close it if a fight starts while it's open
task.spawn(function()
	while true do
		task.wait(0.25)
		if menu.Visible and inFight() then
			setOpen(false)
		end
	end
end)
