--!strict
-- the ring this client follows: the spectated one, else the one it's standing by
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rings"))

local Watch = {
	Spectating = nil :: Model?,
}

function Watch.ring(): Model?
	if Watch.Spectating then
		return Watch.Spectating
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then Rings.nearest(root.Position) else nil
end

return Watch
