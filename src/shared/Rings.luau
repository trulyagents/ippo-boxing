--!strict
-- rings are models tagged BoxingRing. a spot belongs to the nearest one, height counts triple
-- so the gym and the basement under it don't hear each other's fights
local CollectionService = game:GetService("CollectionService")

local Rings = {}

Rings.Tag = "BoxingRing"
Rings.WatchDistance = 70

function Rings.all(): { Model }
	local out = {}
	for _, ring in CollectionService:GetTagged(Rings.Tag) do
		if ring:IsA("Model") then
			table.insert(out, ring)
		end
	end
	return out
end

function Rings.distance(ring: Model, at: Vector3): number
	local d = ring:GetPivot().Position - at
	return Vector3.new(d.X, d.Y * 3, d.Z).Magnitude
end

-- the ring a spot belongs to, if any is close enough to watch
function Rings.nearest(at: Vector3): Model?
	local best, bestDistance = nil, Rings.WatchDistance
	for _, ring in Rings.all() do
		local d = Rings.distance(ring, at)
		if d < bestDistance then
			best, bestDistance = ring, d
		end
	end
	return best
end

return Rings
