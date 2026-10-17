--!strict
-- Local "game feel" clock shared by the animator, effects and camera on this client.
-- Hit-stop freezes poses for a few frames, slow-mo stretches them. The server never
-- slows down, this is only how it looks for you.
local Feel = {}

local hitstopUntil = 0
local slowUntil = 0
local slowScale = 1

-- freeze animation for a moment, the classic fighting game punch pause
function Feel.hitstop(seconds: number)
	hitstopUntil = math.max(hitstopUntil, os.clock() + seconds)
end

function Feel.slowmo(seconds: number, scale: number)
	local now = os.clock()
	if now >= slowUntil or scale < slowScale then
		slowScale = scale
	end
	slowUntil = math.max(slowUntil, now + seconds)
end

-- how fast poses should move right now, 0 = frozen, 1 = normal
function Feel.scale(): number
	local now = os.clock()
	if now < hitstopUntil then
		return 0
	end
	if now < slowUntil then
		-- ease back to full speed over the last third
		local left = slowUntil - now
		return slowScale + (1 - slowScale) * math.clamp(1 - left / 0.25, 0, 1)
	end
	return 1
end

function Feel.isSlow(): boolean
	return os.clock() < slowUntil
end

-- per-fighter hit reactions the animator layers on top of the pose
export type Reaction = { Move: string, Result: string, Started: number, Side: number }
Feel.reactions = {} :: { [Model]: Reaction }

function Feel.react(model: Model, move: string, result: string, side: number)
	Feel.reactions[model] = { Move = move, Result = result, Started = os.clock(), Side = side }
end

return Feel
