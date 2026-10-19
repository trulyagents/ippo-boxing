--!strict
-- A gold [VIP] in front of VIP pass owners' chat messages. The server sets the VIP attribute
-- after checking the pass (server/Shop).
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
