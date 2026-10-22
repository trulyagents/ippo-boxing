--!strict
-- gold [VIP] before chat from pass owners (the server sets the VIP attribute)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender and sender:GetAttribute("VIP") == true then
		props.PrefixText = '<font color="#C48C14">[VIP]</font> ' .. message.PrefixText
	end
	return props
end
