--!strict
-- admin menu, only for players the server marks Admin. buttons just fire their Cheat attribute,
-- the server checks everything. P or the button opens it
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("AdminMenu") :: ScreenGui
local button = gui:WaitForChild("AdminButton") :: GuiButton
local panel = gui:WaitForChild("Panel") :: Frame
local cheat = ReplicatedStorage:WaitForChild("BoxingRemotes"):WaitForChild("Cheat") :: RemoteEvent

local function show()
	button.Visible = player:GetAttribute("Admin") == true
	if not button.Visible then
		panel.Visible = false
	end
end
player:GetAttributeChangedSignal("Admin"):Connect(show)
show()

-- sits right after WATCH when that's up, or slides into its spot so there's no gap
local watchButton = player.PlayerGui:WaitForChild("Spectate"):WaitForChild("WatchButton") :: GuiButton
local withWatch = button.Position
local withoutWatch = watchButton.Position
local function slot()
	button.Position = if watchButton.Visible then withWatch else withoutWatch
end
watchButton:GetPropertyChangedSignal("Visible"):Connect(slot)
slot()

local function toggle()
	if button.Visible then
		panel.Visible = not panel.Visible
	end
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		toggle()
	end
end)

for _, child in panel:GetChildren() do
	local command = child:GetAttribute("Cheat")
	if child:IsA("GuiButton") and typeof(command) == "string" then
		child.Activated:Connect(function()
			cheat:FireServer(command, child:GetAttribute("A"), child:GetAttribute("B"))
		end)
	end
end
