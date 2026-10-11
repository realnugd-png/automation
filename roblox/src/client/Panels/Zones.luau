local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

return {
	title = "WEALTH ZONES",
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		UI.clear(content)
		UI.label({ Text = "Zone bonuses apply while you stand in the zone. Travel instantly once unlocked.", TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, -10, 0, 36), LayoutOrder = 0, Parent = content })
		for index, zone in GameConfig.Zones do
			local unlocked = profile.zones[zone.id] == true
			local here = snapshot.stats.zoneId == zone.id
			local row = UI.row(content, 76, index)
			row.BackgroundColor3 = if here then Color3.fromRGB(40, 52, 40) else T.Row
			UI.new("Frame", { Size = UDim2.new(0, 6, 1, -14), Position = UDim2.fromOffset(8, 7), BackgroundColor3 = zone.color, Parent = row }, { UI.corner(3) })
			UI.label({ Text = zone.name .. (if here then "  (you are here)" else ""), Font = T.Title, TextSize = 19, TextColor3 = zone.color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 26), Position = UDim2.fromOffset(22, 6), Parent = row })
			UI.label({ Text = zone.description, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 20), Position = UDim2.fromOffset(22, 32), Parent = row })
			local requirement = if unlocked then "Unlocked" else `Cost ${NumberFormat.short(zone.cost)}` .. (if zone.requiredRebirths > 0 then ` · needs {zone.requiredRebirths} rebirth(s)` else "")
			UI.label({ Text = requirement, TextSize = 13, TextColor3 = if unlocked then T.Green else T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 18), Position = UDim2.fromOffset(22, 52), Parent = row })

			if unlocked then
				local travel = UI.button({
					Text = if here then "HERE" else "TRAVEL",
					TextSize = 15,
					Size = UDim2.fromOffset(130, 42),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Parent = row,
				}, function()
					local result = State.request("TravelZone", zone.id)
					if result.ok then
						require(script.Parent.Parent.UI.Panels).close()
					end
				end, "blue")
				UI.setEnabled(travel, not here)
			else
				local canAfford = profile.cash >= zone.cost and profile.rebirths >= zone.requiredRebirths
				local unlock = UI.button({
					Text = "UNLOCK",
					TextSize = 15,
					Size = UDim2.fromOffset(130, 42),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Parent = row,
				}, function()
					State.request("UnlockZone", zone.id)
				end, "gold")
				UI.setEnabled(unlock, canAfford)
			end
		end
	end,
}
