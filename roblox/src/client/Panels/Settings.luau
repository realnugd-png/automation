local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local OPTIONS = {
	{ key = "effects", name = "Visual effects", description = "Flashes, bursts and cinematic reveals" },
	{ key = "shake", name = "Camera shake", description = "Shake the camera on rare rolls" },
	{ key = "sounds", name = "Sounds", description = "Roll, reveal and UI sounds" },
	{ key = "hideOtherAuras", name = "Hide other players' auras", description = "Improves performance in busy servers" },
	{ key = "autoRollSkipReveal", name = "Skip roll animations", description = "Instant results below Millionaire (rare rolls still play)" },
}

return {
	title = "SETTINGS",
	refresh = function(content: ScrollingFrame)
		local profile = State.profile()
		if not profile then
			return
		end
		UI.clear(content)
		for index, option in OPTIONS do
			local value = profile.settings[option.key] == true
			local row = UI.row(content, 60, index)
			UI.label({ Text = option.name, Font = T.Bold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 24), Position = UDim2.fromOffset(12, 6), Parent = row })
			UI.label({ Text = option.description, TextSize = 13, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(12, 32), Parent = row })
			UI.button({
				Text = if value then "ON" else "OFF",
				Size = UDim2.fromOffset(100, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Parent = row,
			}, function()
				State.request("SetSetting", option.key, not value)
			end, if value then "green" else "dark")
		end
		UI.label({ Text = "Settings are saved to your account.", TextSize = 13, TextColor3 = T.Muted, LayoutOrder = 99, Parent = content })
	end,
}
