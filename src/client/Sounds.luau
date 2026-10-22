--!strict
-- numbered sound copies (Thud1, Thud2...) so a sound can play a random one

local Sounds = {}

function Sounds.numbered(folder: Instance, prefix: string): { Sound }
	local list: { Sound } = {}
	for _, s in folder:GetChildren() do
		if s:IsA("Sound") and s.Name:match(`^{prefix}%d+$`) then
			table.insert(list, s)
		end
	end
	return list
end

return Sounds
