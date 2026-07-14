--[[
	Radio - a compact top-right music control: play/pause, the current track
	name, and a next button. Drives the Music module and refreshes whenever
	Music.onChanged fires (state change), so no per-frame work.
]]

local Theme = require(script.Parent.Theme)
local Music = require(script.Parent.Parent.Music)

local Radio = {}

local playBtn: TextButton
local nameLabel: TextLabel

local function refresh()
	if playBtn then
		playBtn.Text = Music.isPlaying() and "\u{23F8}" or "\u{25B6}" -- pause / play
	end
	if nameLabel then
		nameLabel.Text = "\u{1F3B5} " .. Music.currentName()
	end
end

function Radio.init(parent: Instance)
	local bar = Theme.panel(parent, UDim2.fromScale(0.992, 0.012), UDim2.fromScale(0.18, 0.05), Vector2.new(1, 0))

	playBtn = Theme.button(bar, "\u{25B6}", UDim2.fromScale(0.02, 0.15), UDim2.fromScale(0.16, 0.7), Music.toggle)
	Theme.capText(playBtn, 16)

	nameLabel = Theme.mono(bar, "", UDim2.fromScale(0.2, 0.15), UDim2.fromScale(0.6, 0.7))
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	Theme.capText(nameLabel, 13)

	local nextBtn = Theme.button(bar, "\u{23ED}", UDim2.fromScale(0.82, 0.15), UDim2.fromScale(0.16, 0.7), Music.next)
	Theme.capText(nextBtn, 16)

	Music.onChanged = refresh
	refresh()
end

return Radio
