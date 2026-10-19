--!strict
-- The INVITE stamp next to MENU (StarterGui.BoxingMenu.InviteButton, built in studio) opens
-- roblox's own friend invite. Playing in the same server as a friend gives you both a small
-- stat boost once a day (server/Career).
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local button = player:WaitForChild("PlayerGui"):WaitForChild("BoxingMenu"):WaitForChild("InviteButton") :: GuiButton

-- hidden where roblox won't let this player send invites (some accounts and regions)
local ok, can = pcall(function()
	return SocialService:CanSendGameInviteAsync(player)
end)
button.Visible = ok and can == true

button.Activated:Connect(function()
	pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come box with me in Second Wind Boxing"
		SocialService:PromptGameInvite(player, options)
	end)
end)
