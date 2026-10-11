-- Aura Index: every rarity, its live odds, what you own, and equip buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local RNG = require(Shared.Modules.RNG)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local function equipButton(parent: Instance, auraId: string, equipped: boolean)
	local button = UI.button({
		Text = if equipped then "EQUIPPED" else "EQUIP",
		TextSize = 15,
		Size = UDim2.fromOffset(110, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Parent = parent,
	}, function()
		State.request("EquipAura", if equipped then "" else auraId)
	end, if equipped then "green" else "gold")
	return button
end

return {
	title = "AURA INDEX",
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		UI.clear(content)

		local discovered = 0
		for _ in profile.discovered do
			discovered += 1
		end
		UI.label({
			Text = `Discovered {discovered} / {Rarities.count} rarities  ·  Luck x{string.format("%.2f", snapshot.stats.luck)}`,
			TextSize = 17,
			TextColor3 = T.GoldLight,
			LayoutOrder = 0,
			Parent = content,
		})

		local probabilities = RNG.getProbabilities(snapshot.stats.luck)
		for index, rarity in Rarities.list do
			local known = profile.discovered[rarity.id] == true
			local row = UI.row(content, 58, index)
			UI.new("Frame", {
				Size = UDim2.new(0, 6, 1, -14),
				Position = UDim2.fromOffset(8, 7),
				BackgroundColor3 = if known then rarity.color else T.Muted,
				Parent = row,
			}, { UI.corner(3) })
			UI.label({
				Text = if known then rarity.name else "???",
				Font = T.Title,
				TextSize = 20,
				TextColor3 = if known then rarity.color else T.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.45, 0, 0, 26),
				Position = UDim2.fromOffset(22, 4),
				Parent = row,
			})
			UI.label({
				Text = `{NumberFormat.odds(probabilities[index])}  ·  ${NumberFormat.short(rarity.minCash)}–${NumberFormat.short(rarity.maxCash)}`,
				TextSize = 13,
				TextColor3 = T.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.6, 0, 0, 18),
				Position = UDim2.fromOffset(22, 32),
				Parent = row,
			})
			local owned = profile.inventory[rarity.id] or 0
			local rolled = profile.rarityCounts[rarity.id] or 0
			UI.label({
				Text = if rarity.hasAura then `Aura x{owned}\nRolled {rolled}` else `Rolled {rolled}\nNo aura`,
				TextSize = 13,
				TextColor3 = T.Text,
				Size = UDim2.fromOffset(100, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -128, 0.5, 0),
				Parent = row,
			})
			if rarity.hasAura and owned > 0 then
				equipButton(row, rarity.id, profile.equippedAura == rarity.id)
			end
		end

		if snapshot.passes.VIP then
			local row = UI.row(content, 58, 100)
			UI.label({
				Text = "VIP Golden Aura",
				Font = T.Title,
				TextSize = 20,
				TextColor3 = T.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.fromOffset(22, 0),
				Parent = row,
			})
			equipButton(row, "VIP", profile.equippedAura == "VIP")
		end
	end,
}
