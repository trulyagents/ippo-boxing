--!strict
-- The admin menu (StarterGui.AdminMenu, built in studio). Only shows for players the server marks
-- Admin (studio, or the owner). Each button carries a Cheat attribute plus optional A and B, and
-- just fires that on the Cheat remote, so the server still checks everything. P or the button opens it.
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
