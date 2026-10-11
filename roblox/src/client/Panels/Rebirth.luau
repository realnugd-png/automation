local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.Upgrades)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local confirmUntil = 0

return {
	title = "REBIRTH",
	onOpen = function()
		confirmUntil = 0
	end,
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		local rebirths = profile.rebirths
		local cost = Formulas.rebirthCost(rebirths)
		local cfg = GameConfig.Rebirth
		UI.clear(content)

		UI.label({ Text = `Rebirth {rebirths}`, Font = T.Title, TextSize = 34, TextColor3 = T.Purple, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = content })
		local bonus = UI.row(content, 96, 2)
		UI.label({
			Text = string.format(
				"Current permanent bonus: <b>+%d%% cash</b>, <b>+%d%% luck</b>\nAfter rebirth: <font color=\"#50D278\"><b>+%d%% cash</b>, <b>+%d%% luck</b></font>",
				math.floor(rebirths * cfg.cashBonusPer * 100 + 0.5),
				math.floor(rebirths * cfg.luckBonusPer * 100 + 0.5),
				math.floor((rebirths + 1) * cfg.cashBonusPer * 100 + 0.5),
				math.floor((rebirths + 1) * cfg.luckBonusPer * 100 + 0.5)
			),
			RichText = true,
			TextSize = 17,
			Size = UDim2.new(1, -20, 1, -10),
			Position = UDim2.fromOffset(10, 5),
			Parent = bonus,
		})

		local resets = {}
		for _, upgrade in Upgrades.list do
			if not upgrade.keepOnRebirth then
				table.insert(resets, upgrade.name)
			end
		end
		UI.label({
			Text = "Resets: cash and " .. table.concat(resets, ", ") .. ".\nKeeps: auras, index, zones, lifetime earnings, Passive Income, achievements.",
			TextSize = 14,
			TextColor3 = T.Muted,
			Size = UDim2.new(1, -20, 0, 40),
			LayoutOrder = 3,
			Parent = content,
		})

		local progressRow = UI.row(content, 56, 4)
		UI.label({
			Text = `${NumberFormat.short(profile.cash)} / ${NumberFormat.short(cost)}`,
			TextSize = 16,
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 4),
			Parent = progressRow,
		})
		local bar, setProgress = UI.progressBar(progressRow, T.Purple, 14)
		bar.Size = UDim2.new(1, -20, 0, 14)
		bar.Position = UDim2.fromOffset(10, 32)
		setProgress(profile.cash / cost)

		local maxed = rebirths >= cfg.maxRebirths
		local canAfford = profile.cash >= cost
		local confirming = os.clock() < confirmUntil
		local button = UI.button({
			Text = if maxed then "MAX REBIRTH" elseif confirming then "CLICK AGAIN TO CONFIRM" else `REBIRTH FOR ${NumberFormat.short(cost)}`,
			Size = UDim2.fromOffset(340, 54),
			TextSize = 20,
			LayoutOrder = 5,
			Parent = content,
		}, function()
			if os.clock() < confirmUntil then
				confirmUntil = 0
				State.request("Rebirth")
			else
				confirmUntil = os.clock() + 4
				local panels = require(script.Parent.Parent.UI.Panels)
				panels.refresh()
				task.delay(4.1, panels.refresh)
			end
		end, if confirming then "red" else "purple")
		UI.setEnabled(button, canAfford and not maxed)
	end,
}
