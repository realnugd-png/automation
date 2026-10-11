local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local function describe(reward, bestOrder: number): string
	local parts = {}
	local cash = Formulas.rewardCash(reward, bestOrder)
	if cash > 0 then
		table.insert(parts, "$" .. NumberFormat.short(cash))
	end
	if reward.luckBoost then
		table.insert(parts, `{reward.luckBoost.mult}x Luck {reward.luckBoost.minutes}m`)
	end
	return table.concat(parts, "\n+ ")
end

local function section(content: Instance, text: string, order: number)
	UI.label({ Text = text, Font = T.Title, TextSize = 19, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = content })
end

return {
	title = "DAILY REWARDS",
	live = true,
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		local now = State.now()
		UI.clear(content)

		-- Login streak
		section(content, `Login streak: {profile.daily.streak} day(s)`, 1)
		local track = UI.new("Frame", {
			Size = UDim2.new(1, -6, 0, 104),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = content,
		}, {
			UI.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local current = snapshot.loginIndex
		for day, reward in GameConfig.DailyLogin do
			local claimed = day < current or (day == current and not snapshot.canClaimLogin)
			local isToday = day == current
			UI.new("Frame", {
				Size = UDim2.new(1 / #GameConfig.DailyLogin, -6, 1, 0),
				BackgroundColor3 = if isToday then Color3.fromRGB(70, 56, 20) else T.Row,
				LayoutOrder = day,
				Parent = track,
			}, {
				UI.corner(10),
				UI.stroke(if isToday then T.Gold else T.Muted, if isToday then 2 else 1, if isToday then 0 else 0.7),
				UI.label({ Text = `Day {day}`, TextSize = 14, Font = T.Title, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 4), TextColor3 = if isToday then T.Gold else T.Text }),
				UI.label({ Text = describe(reward, profile.bestOrder), TextSize = 12, Size = UDim2.new(1, -6, 0, 50), Position = UDim2.fromOffset(3, 26), TextColor3 = T.Text }),
				UI.label({ Text = if claimed then "✔" else "", TextSize = 20, TextColor3 = T.Green, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -24) }),
			})
		end
		local claim = UI.button({
			Text = if snapshot.canClaimLogin then "CLAIM TODAY'S REWARD" else `NEXT IN {NumberFormat.duration(86400 - now % 86400)}`,
			Size = UDim2.fromOffset(320, 46),
			LayoutOrder = 3,
			Parent = content,
		}, function()
			State.request("ClaimDaily")
		end, "green")
		UI.setEnabled(claim, snapshot.canClaimLogin)

		-- Daily luck boost
		section(content, "Free daily luck boost", 4)
		local boostRow = UI.row(content, 56, 5)
		UI.label({
			Text = `{GameConfig.DailyLuckBoost.mult}x Luck for {GameConfig.DailyLuckBoost.minutes} minutes, once per day`,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -170, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Parent = boostRow,
		})
		local boostButton = UI.button({
			Text = if snapshot.canClaimBoost then "ACTIVATE" else "USED",
			Size = UDim2.fromOffset(140, 40),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = boostRow,
		}, function()
			State.request("ClaimDailyBoost")
		end, "green")
		UI.setEnabled(boostButton, snapshot.canClaimBoost)

		-- Playtime rewards (estimated live from the last snapshot)
		local today = Formulas.dayNumber(now)
		local playSeconds = if profile.daily.playDay == today then profile.daily.playSeconds else 0
		playSeconds += math.max(0, now - State.receivedAt)
		section(content, `Playtime today: {NumberFormat.duration(playSeconds)}`, 6)
		for index, tier in GameConfig.PlaytimeRewards do
			local claimed = profile.daily.playDay == today and profile.daily.playClaimed[tostring(index)] == true
			local ready = playSeconds >= tier.minutes * 60
			local row = UI.row(content, 56, 6 + index)
			UI.label({
				Text = `{tier.minutes} min: {describe(tier.reward, profile.bestOrder):gsub("\n", " ")}`,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -170, 0, 24),
				Position = UDim2.fromOffset(12, 4),
				Parent = row,
			})
			local bar, set = UI.progressBar(row, T.Blue, 8)
			bar.Size = UDim2.new(1, -180, 0, 8)
			bar.Position = UDim2.fromOffset(12, 36)
			set(playSeconds / (tier.minutes * 60))
			local button = UI.button({
				Text = if claimed then "CLAIMED" elseif ready then "CLAIM" else NumberFormat.duration(tier.minutes * 60 - playSeconds),
				TextSize = 15,
				Size = UDim2.fromOffset(140, 40),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Parent = row,
			}, function()
				State.request("ClaimPlaytime", index)
			end, if ready and not claimed then "green" else "dark")
			UI.setEnabled(button, ready and not claimed)
		end

		-- Active boosts
		section(content, "Active boosts", 30)
		local any = false
		for source, boost in profile.boosts do
			if boost.expires > now then
				any = true
				local row = UI.row(content, 34, 31)
				UI.label({
					Text = `{boost.mult}x luck ({source}) — {NumberFormat.duration(boost.expires - now)} left`,
					TextSize = 15,
					TextColor3 = T.Green,
					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.fromOffset(10, 0),
					Parent = row,
				})
			end
		end
		if not any then
			UI.label({ Text = "No active boosts", TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 31, Parent = content })
		end
	end,
}
