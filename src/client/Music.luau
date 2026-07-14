--[[
	Music - the radio. A small playlist of background tracks with play/pause and
	next. Tracks auto-advance when they finish. The Radio UI (UI/Radio) drives it
	and reads currentName()/isPlaying(); Music.onChanged fires whenever the state
	changes so the UI can refresh.

	Add a song by dropping another { name, id } into PLAYLIST.
]]

local SoundService = game:GetService("SoundService")

local Music = {}

local PLAYLIST = {
	{ name = "Track 1", id = "rbxassetid://116136939478767" },
	{ name = "Track 2", id = "rbxassetid://139252977045342" },
}

local tracks: { Sound } = {}
local current = 0 -- index of the loaded track (0 = none yet)
local playing = false

Music.onChanged = nil :: (() -> ())?

local function changed()
	if Music.onChanged then
		Music.onChanged()
	end
end

function Music.init()
	for i, def in PLAYLIST do
		local s = Instance.new("Sound")
		s.SoundId = def.id
		s.Looped = false
		s.Volume = 0.4
		s.Parent = SoundService
		tracks[i] = s
		s.Ended:Connect(function()
			-- auto-advance only if this is still the active, playing track
			if playing and current == i then
				Music.next()
			end
		end)
	end
	-- start the radio on the first track (Roblox allows autoplay)
	if #tracks > 0 then
		Music.playIndex(1)
	end
end

function Music.playIndex(i: number)
	if #tracks == 0 then
		return
	end
	if tracks[current] then
		tracks[current]:Stop()
	end
	current = ((i - 1) % #tracks) + 1
	playing = true
	tracks[current].TimePosition = 0
	tracks[current]:Play()
	changed()
end

function Music.next()
	Music.playIndex(current + 1)
end

function Music.toggle()
	if #tracks == 0 then
		return
	end
	if playing then
		playing = false
		if tracks[current] then
			tracks[current]:Pause()
		end
	elseif current == 0 then
		Music.playIndex(1)
		return
	else
		playing = true
		tracks[current]:Resume()
	end
	changed()
end

function Music.isPlaying(): boolean
	return playing
end

function Music.currentName(): string
	return (current > 0 and PLAYLIST[current].name) or "--"
end

return Music
