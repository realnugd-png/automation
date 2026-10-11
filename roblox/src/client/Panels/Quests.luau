local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.Quests)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local tab = "Daily"

local function rewardText(reward, bestOrder: number): string
	local parts = {}
	local cash = Formulas.rewardCash(reward, bestOrder)
	if cash > 0 then
		table.insert(parts, "$" .. NumberFormat.short(cash))
	end
	if reward.luckBoost then
		table.insert(parts, `{reward.luckBoost.mult}x Luck {reward.luckBoost.minutes}m`)
	end
	return table.concat(parts, " + ")
end

local function questRow(content: Instance, order: number, text: string, progress: number, target: number, reward: string, done: boolean, claimable: boolean, onClaim: () -> ())
	local row = UI.row(content, 70, order)
	UI.label({ Text = text, Font = T.Bold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 22), Position = UDim2.fromOffset(12, 6), Parent = row })
	UI.label({ Text = "Reward: " .. reward, TextSize = 13, TextColor3 = T.GoldLight, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(12, 28), Parent = row })
	local bar, set = UI.progressBar(row, if done then T.Green else T.Blue, 10)
	bar.Size = UDim2.new(1, -180, 0, 10)
	bar.Position = UDim2.fromOffset(12, 52)
	set(progress / math.max(target, 1))
	UI.label({ Text = `{NumberFormat.short(progress)}/{NumberFormat.short(target)}`, TextSize = 12, TextColor3 = T.Muted, Size = UDim2.fromOffset(80, 14), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -168, 0, 36), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	local button = UI.button({
		Text = if done then "DONE" elseif claimable then "CLAIM" else "IN PROGRESS",
		TextSize = 14,
		Size = UDim2.fromOffset(140, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Parent = row,
	}, onClaim, if claimable then "green" else "dark")
	UI.setEnabled(button, claimable)
end

local function tabs(content: Instance)
	local bar = UI.new("Frame", {
		Size = UDim2.new(1, -6, 0, 42),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = content,
	}, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	for _, name in { "Daily", "Repeatable", "Achievements", "Milestones" } do
		UI.button({ Text = name, TextSize = 15, Size = UDim2.fromOffset(150, 38), Parent = bar }, function()
			tab = name
			require(script.Parent.Parent.UI.Panels).refresh()
		end, if tab == name then "gold" else "dark")
	end
end

return {
	title = "QUESTS",
	live = true,
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		local profile = snapshot.profile
		UI.clear(content)
		tabs(content)

		if tab == "Daily" then
			UI.label({ Text = `New quests in {NumberFormat.duration(86400 - State.now() % 86400)}`, TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 1, Parent = content })
			for index, entry in profile.quests.daily.list do
				local template = QuestConfig.DailyById[entry.id]
				if template then
					local text = template.text:gsub("{target}", NumberFormat.short(entry.target))
					questRow(content, 1 + index, text, entry.progress, entry.target, rewardText(template.reward, profile.bestOrder), entry.claimed, not entry.claimed and entry.progress >= entry.target, function()
						State.request("ClaimQuest", index)
					end)
				end
			end
		elseif tab == "Repeatable" then
			for index, template in QuestConfig.Repeatable do
				local state = profile.quests.repeatable[template.id]
				if state then
					local text = template.text:gsub("{target}", NumberFormat.short(state.target))
					questRow(content, index, `{text}  (stage {state.stage + 1})`, state.progress, state.target, rewardText(template.reward, profile.bestOrder), false, state.progress >= state.target, function()
						State.request("ClaimRepeatable", template.id)
					end)
				end
			end
		elseif tab == "Achievements" then
			local done = 0
			for _ in profile.achievements do
				done += 1
			end
			UI.label({ Text = `{done}/{#QuestConfig.Achievements} achievements · rewards are granted automatically`, TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 1, Parent = content })
			for index, achievement in QuestConfig.Achievements do
				local earned = profile.achievements[achievement.id] == true
				local row = UI.row(content, 54, 1 + index)
				UI.label({ Text = (if earned then "🏅 " else "🔒 ") .. achievement.name, Font = T.Bold, TextSize = 16, TextColor3 = if earned then T.Gold else T.Text, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(12, 6), Parent = row })
				local target = if achievement.target < 0 then Rarities.count else achievement.target
				UI.label({ Text = achievement.description, TextSize = 13, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(12, 28), Parent = row })
				UI.label({ Text = rewardText(achievement.reward, profile.bestOrder), TextSize = 13, TextColor3 = T.GoldLight, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.4, -14, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), Parent = row })
				local _ = target
			end
		else
			for index, milestone in GameConfig.RollMilestones do
				local reached = profile.milestones[tostring(milestone.rolls)] == true
				local row = UI.row(content, 50, index)
				UI.label({ Text = (if reached then "✔ " else "") .. `{NumberFormat.commas(milestone.rolls)} rolls`, Font = T.Bold, TextSize = 16, TextColor3 = if reached then T.Green else T.Text, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = row })
				UI.label({ Text = rewardText(milestone.reward, profile.bestOrder), TextSize = 14, TextColor3 = T.GoldLight, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.6, -14, 1, 0), Position = UDim2.new(0.4, 0, 0, 0), Parent = row })
			end
		end
	end,
}
