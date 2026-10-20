--!strict
-- Background music, APM tracks from ReplicatedStorage.BoxingSounds.Music (roblox's licensed
-- library, free to use). Gym1, Gym2... play quietly anywhere. When a ring match is on and you're
-- close enough to watch it, it crossfades to Match1, Match2... and back once the match ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local folder = ReplicatedStorage:WaitForChild("BoxingSounds"):WaitForChild("Music")
local Watch = require(script.Parent:WaitForChild("Watch"))

local VOLUME = { Gym = 0.45, Match = 0.6 }
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)

-- each playlist has its own copy so a crossfade can play both for a moment
local function playlist(prefix: string): { Sound }
	local list: { Sound } = {}
	for _, s in folder:GetChildren() do
		if s:IsA("Sound") and s.Name:match("^" .. prefix .. "%d+$") then
			local copy = s:Clone()
			copy.Volume = 0
			copy.Parent = SoundService
			table.insert(list, copy)
		end
	end
	table.sort(list, function(a: Sound, b: Sound)
		return a.Name < b.Name
	end)
	return list
end
local lists = { Gym = playlist("Gym"), Match = playlist("Match") }
local at = { Gym = 1, Match = 1 }
local current: string? = nil

local function track(name: string): Sound?
	return lists[name][at[name]]
end

-- the next track in the list when one ends
for name, list in lists do
	for _, s in list do
		s.Ended:Connect(function()
			if current ~= name then
				return
			end
			at[name] = at[name] % #list + 1
			local nextTrack = track(name)
			if nextTrack then
				nextTrack.Volume = VOLUME[name]
				nextTrack:Play()
			end
		end)
	end
end

local function switchTo(name: string)
	if name == current then
		return
	end
	local old = current and track(current)
	if old then
		local fade = TweenService:Create(old, FADE, { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			if old.Volume == 0 then
				old:Pause()
			end
		end)
	end
	current = name
	local new = track(name)
	if new then
		-- pick the track back up where it was, don't restart it
		if new.IsPaused then
			new:Resume()
		elseif not new.IsPlaying then
			new:Play()
		end
		TweenService:Create(new, FADE, { Volume = VOLUME[name] }):Play()
	end
end

-- by a ring with a fight on, or spectating one
local function watching(): boolean
	local ring = Watch.ring()
	return ring ~= nil and ring:GetAttribute("MatchOn") == true
end

-- a few times a second is plenty for music
task.spawn(function()
	while true do
		switchTo(if watching() then "Match" else "Gym")
		task.wait(0.5)
	end
end)
