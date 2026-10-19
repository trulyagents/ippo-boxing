--!strict
-- Every RemoteEvent the game uses, made here and nowhere else (ReplicatedStorage.BoxingRemotes).
-- Built on the first require, which needs nothing else, so no script waits on another to make
-- them. Clients find them by name with WaitForChild.
--   Action      client -> server, combat inputs (CombatServer, rate limited)
--   Fx          server -> client, hits, shouts, match screens
--   Training    both ways, drill inputs and cues (Training)
--   CornerPick  both ways, the pick between rounds (Corner)
--   Cheat       client -> server, QA commands, Studio and the owner only (Cheats)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "Action", "Fx", "Training", "CornerPick", "Cheat" }

local folder = ReplicatedStorage:FindFirstChild("BoxingRemotes") or Instance.new("Folder")
folder.Name = "BoxingRemotes"
local remotes: { [string]: RemoteEvent } = {}
for _, name in NAMES do
	local r = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	remotes[name] = r :: RemoteEvent
end
folder.Parent = ReplicatedStorage

return {
	Action = remotes.Action,
	Fx = remotes.Fx,
	Training = remotes.Training,
	CornerPick = remotes.CornerPick,
	Cheat = remotes.Cheat,
}
