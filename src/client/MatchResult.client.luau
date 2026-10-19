--!strict
-- The result screen after a ring match (StarterGui.MatchResult, built in studio): win, loss or
-- draw and how, both boxers' fight numbers, rank points and the new record.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer
local fx = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Fx") :: RemoteEvent
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MatchResult") :: ScreenGui
local root = gui:WaitForChild("Root") :: Frame
local outcome = root:WaitForChild("Outcome") :: TextLabel
local pop = outcome:WaitForChild("UIScale") :: UIScale
local how = root:WaitForChild("How") :: TextLabel
local card = root:WaitForChild("Card") :: ImageLabel

local WORDS = { Win = "YOU WIN", Loss = "YOU LOSE", Draw = "DRAW" }
local COLORS = {
	Win = Color3.fromRGB(237, 228, 207),
	Loss = Color3.fromRGB(150, 145, 135),
	Draw = Color3.fromRGB(237, 228, 207),
}
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
local HOME = card.Position

local function text(parent: Instance, name: string): TextLabel
	return parent:WaitForChild(name) :: TextLabel
end

local token = 0
fx.OnClientEvent:Connect(function(kind, info)
	if kind ~= "Result" or typeof(info) ~= "table" then
		return
	end
	token += 1
	local mine = token
	local result = if WORDS[info.Outcome] then info.Outcome else "Draw"
	outcome.Text = WORDS[result]
	outcome.TextColor3 = COLORS[result]
	how.Text = if result == "Draw" then "ON THE CARDS" else "BY " .. tostring(info.How)
	local you, them = info.You or {}, info.Them or {}
	text(card, "VsLine").Text = string.upper(tostring(you.Name or "YOU")) .. "  VS  " .. string.upper(tostring(them.Name or "?"))
	for _, key in { "Hits", "Downs" } do
		local row = card:WaitForChild(key)
		text(row, "You").Text = tostring(math.floor((info.YouFight and info.YouFight[key] or 0) + 0.5))
		text(row, "Them").Text = tostring(math.floor((info.ThemFight and info.ThemFight[key] or 0) + 0.5))
	end
	local points = tonumber(info.Points) or 0
	text(card:WaitForChild("Points"), "Text").Text = (if points >= 0 then "+" else "") .. points .. " RANK POINTS"
	text(card, "Rank").Text = tostring(you.Rank or "ROOKIE")
	text(card, "Record").Text = string.format(
		"%d - %d - %d   %d KO",
		tonumber(you.Wins) or 0,
		tonumber(you.Losses) or 0,
		tonumber(you.Draws) or 0,
		tonumber(you.KOs) or 0
	)

	pop.Scale = 0
	card.Position = HOME + UDim2.fromScale(0, 0.6)
	root.BackgroundTransparency = 1
	root.Visible = true
	TweenService:Create(root, FADE, { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(pop, POP, { Scale = 1 }):Play()
	task.delay(0.25, function()
		if mine == token then
			TweenService:Create(card, POP, { Position = HOME }):Play()
		end
	end)
	task.delay(Config.Match.EndTime - 0.5, function()
		if mine ~= token then
			return
		end
		TweenService:Create(root, FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(pop, FADE, { Scale = 0 }):Play()
		TweenService:Create(card, FADE, { Position = HOME + UDim2.fromScale(0, 0.6) }):Play()
		task.delay(0.3, function()
			if mine == token then
				root.Visible = false
			end
		end)
	end)
end)
