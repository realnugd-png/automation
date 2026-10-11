local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

return {
	title = "STATISTICS",
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		local stats = snapshot.stats
		UI.clear(content)
		local best = Rarities.list[profile.bestOrder]
		local lines = {
			{ "Wealth title", Formulas.wealthTitle(profile.lifetime) },
			{ "Cash", "$" .. NumberFormat.commas(profile.cash) },
			{ "Lifetime earnings", "$" .. NumberFormat.short(profile.lifetime) },
			{ "Total rolls", NumberFormat.commas(profile.totalRolls) },
			{ "Best rarity", if best then best.name else "-" },
			{ "Best single roll", "$" .. NumberFormat.short(profile.bestCash) },
			{ "Rebirths", tostring(profile.rebirths) },
			{ "Luck", string.format("x%.2f", stats.luck) },
			{ "Cash multiplier", string.format("x%.2f", stats.cashMultiplier) },
			{ "Roll cooldown", string.format("%.2fs", stats.cooldown) },
			{ "Rolls per click", tostring(stats.rollsPerClick) },
			{ "Time played", NumberFormat.duration(profile.stats.playSeconds) },
			{ "Trades completed", tostring(profile.stats.trades) },
		}
		for index, line in lines do
			local row = UI.row(content, 34, index)
			UI.label({ Text = line[1], TextSize = 16, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			UI.label({ Text = line[2], TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), Parent = row })
		end
		UI.label({ Text = "Rolls by rarity", Font = T.Title, TextSize = 18, TextColor3 = T.Gold, LayoutOrder = 50, Parent = content })
		for index, rarity in Rarities.list do
			local count = profile.rarityCounts[rarity.id] or 0
			local row = UI.row(content, 30, 50 + index)
			UI.label({ Text = if profile.discovered[rarity.id] then rarity.name else "???", TextSize = 15, TextColor3 = if profile.discovered[rarity.id] then rarity.color else T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
			UI.label({ Text = NumberFormat.commas(count), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, -12, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), Parent = row })
		end
	end,
}
