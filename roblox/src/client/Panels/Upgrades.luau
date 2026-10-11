local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local function effectText(id: string, level: number): string
	local upgrade = Upgrades.byId[id]
	if id == "Luck" then
		return string.format("+%d%% luck", math.floor(level * upgrade.perLevel * 100 + 0.5))
	elseif id == "Cash" then
		return string.format("+%d%% cash", math.floor(level * upgrade.perLevel * 100 + 0.5))
	elseif id == "Speed" then
		return string.format("-%d%% cooldown", math.floor(level * upgrade.perLevel * 100 + 0.5))
	elseif id == "Capacity" then
		return `{1 + level} roll(s) per click`
	elseif id == "Offline" then
		return if level == 0 then "Off" else `Level {level} passive income`
	end
	return ""
end

return {
	title = "UPGRADES",
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		UI.clear(content)
		UI.label({
			Text = `Cash: ${NumberFormat.short(profile.cash)}  ·  Cooldown {string.format("%.2f", snapshot.stats.cooldown)}s  ·  Cash x{string.format("%.2f", snapshot.stats.cashMultiplier)}`,
			TextSize = 16,
			TextColor3 = T.GoldLight,
			LayoutOrder = 0,
			Parent = content,
		})
		for _, upgrade in Upgrades.list do
			local level = profile.upgrades[upgrade.id] or 0
			local maxed = level >= upgrade.maxLevel
			local cost = if maxed then 0 else Formulas.upgradeCost(upgrade.id, level)
			local row = UI.row(content, 74, upgrade.order)
			UI.label({
				Text = `{upgrade.name}  <font color="#A8A096">Lv {level}/{upgrade.maxLevel}</font>`,
				RichText = true,
				Font = T.Title,
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.6, 0, 0, 24),
				Position = UDim2.fromOffset(14, 6),
				Parent = row,
			})
			UI.label({
				Text = upgrade.description .. (if upgrade.keepOnRebirth then " · kept on rebirth" else ""),
				TextSize = 13,
				TextColor3 = T.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.6, 0, 0, 18),
				Position = UDim2.fromOffset(14, 30),
				Parent = row,
			})
			UI.label({
				Text = `Now: {effectText(upgrade.id, level)}` .. (if maxed then "" else `  →  {effectText(upgrade.id, level + 1)}`),
				TextSize = 13,
				TextColor3 = T.Green,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.62, 0, 0, 18),
				Position = UDim2.fromOffset(14, 50),
				Parent = row,
			})
			local buy = UI.button({
				Text = if maxed then "MAX" else "$" .. NumberFormat.short(cost),
				TextSize = 16,
				Size = UDim2.fromOffset(110, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -78, 0.5, 0),
				Parent = row,
			}, function()
				State.request("BuyUpgrade", upgrade.id)
			end, if maxed then "dark" else "gold")
			UI.setEnabled(buy, not maxed and profile.cash >= cost)
			local max = UI.button({
				Text = "MAX",
				TextSize = 14,
				Size = UDim2.fromOffset(60, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Parent = row,
			}, function()
				State.request("BuyUpgradeMax", upgrade.id)
			end, "blue")
			UI.setEnabled(max, not maxed and profile.cash >= cost)
		end
	end,
}
