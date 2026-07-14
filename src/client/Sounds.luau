--[[
	Sounds - tiny client SFX helper. One reusable Sound per effect, parented to
	SoundService (2D UI/feedback audio). Sounds.play(name) restarts + plays it.

	Add a new effect by dropping another entry in DEFS with its rbxassetid, then
	call Sounds.play("thatName") wherever it should fire.
]]

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- name -> { id, volume }. volume is 0..1 (relative loudness of this effect).
local DEFS = {
	click = { id = "rbxassetid://139658322785649", volume = 0.35 }, -- any UI button press
	equip = { id = "rbxassetid://138323438407619", volume = 0.5 }, -- equipping a skin / color / avatar
}

local sounds: { [string]: Sound } = {}

function Sounds.init()
	for name, def in DEFS do
		local s = Instance.new("Sound")
		s.SoundId = def.id
		s.Volume = def.volume
		s.Parent = SoundService
		sounds[name] = s
	end
end

-- Play an effect by name (no-op if unknown or before init). Restarts from 0 so
-- rapid repeats retrigger instead of being ignored mid-play.
function Sounds.play(name: string)
	local s = sounds[name]
	if s then
		s.TimePosition = 0
		s:Play()
	end
end

return Sounds
