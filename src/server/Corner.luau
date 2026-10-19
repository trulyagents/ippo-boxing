--!strict
-- A boxer's corner between rounds: a stool under them, sitting (CornerSit anim off the Sitting
-- attribute), guard back, the round card (Fx "Corner") and one pick on CornerPick (hydrate,
-- treatment or a pep talk, applied by Fighters.corner). Matches opens one per boxer per break and
-- calls what open returns at the bell.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fighters = require(script.Parent.Fighters)
local Remotes = require(script.Parent.Remotes)

local stoolTemplate = ReplicatedStorage:WaitForChild("BoxingGear"):WaitForChild("CornerStool") :: Model

-- who can pick right now, one pick each per break
local picking: { [Player]: Fighters.Fighter } = {}
Remotes.CornerPick.OnServerEvent:Connect(function(player, pick)
	local f = picking[player]
	if not f or typeof(pick) ~= "string" or Fighters.get(f.Model) ~= f then
		return
	end
	if Fighters.corner(f, pick) then
		picking[player] = nil
		Remotes.CornerPick:FireClient(player, pick)
	end
end)

-- on the canvas under where the boxer stands, facing the same way
local function stoolUnder(f: Fighters.Fighter): Model
	local stool = stoolTemplate:Clone()
	local look = f.Root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { f.Model }
	local hit = workspace:Raycast(f.Root.Position, Vector3.new(0, -10, 0), params)
	local floor = if hit then hit.Position else f.Root.Position - Vector3.new(0, 3, 0)
	stool:PivotTo(CFrame.lookAt(floor, floor + Vector3.new(look.X, 0, look.Z)))
	stool.Parent = workspace
	return stool
end

local Corner = {}

-- card is what the corner screen shows (round, side, both tallies, lead, when it ends).
-- returns the function that gets them up for the bell
function Corner.open(f: Fighters.Fighter, card: { [string]: any }): () -> ()
	local stool = stoolUnder(f)
	f.Model:SetAttribute("Sitting", true)
	Fighters.rest(f)
	local player = f.Player
	if player then
		picking[player] = f
		Remotes.Fx:FireClient(player, "Corner", card)
	end
	return function()
		stool:Destroy()
		f.Model:SetAttribute("Sitting", nil)
		if player and picking[player] == f then
			picking[player] = nil
		end
	end
end

return Corner
