--!strict
-- Quest and achievement definitions.
--
-- Quest kinds (progress events raised by the server):
--   "rolls"      - any roll, +1 per individual roll
--   "earn"       - cash earned from rolls; target is multiplied by the
--                  minCash of the player's best rarity when the quest is issued
--   "rarityAtLeast" - roll a rarity with order >= `minOrder`
--   "upgrades"   - buy upgrade levels
--   "playMinutes" - minutes played

local GameConfig = require(script.Parent.GameConfig)

type Reward = GameConfig.Reward

export type QuestKind = "rolls" | "earn" | "rarityAtLeast" | "upgrades" | "playMinutes"

export type QuestTemplate = {
	id: string,
	kind: QuestKind,
	text: string, -- {target} is replaced with the (formatted) target
	target: number,
	minOrder: number?,
	reward: Reward,
}

export type Achievement = {
	id: string,
	name: string,
	description: string,
	stat: "totalRolls" | "lifetime" | "rebirths" | "discovered" | "bestOrder" | "upgradesBought" | "trades" | "streak",
	target: number,
	reward: Reward,
	badgeId: number, -- 0 = no Roblox badge; set real badge ids after creating them
}

local DailyPool: { QuestTemplate } = {
	{ id = "d_roll150", kind = "rolls", text = "Roll {target} times", target = 150, reward = { scaledCash = 30 } },
	{ id = "d_roll400", kind = "rolls", text = "Roll {target} times", target = 400, reward = { scaledCash = 80 } },
	{ id = "d_earn", kind = "earn", text = "Earn {target} cash from rolls", target = 40, reward = { scaledCash = 40 } },
	{ id = "d_rich", kind = "rarityAtLeast", text = "Roll Rich or better {target} times", target = 3, minOrder = 5, reward = { luckBoost = { mult = 2, minutes = 10 } } },
	{ id = "d_comfy", kind = "rarityAtLeast", text = "Roll Comfortable or better {target} times", target = 10, minOrder = 4, reward = { scaledCash = 50 } },
	{ id = "d_upg", kind = "upgrades", text = "Buy {target} upgrade levels", target = 3, reward = { scaledCash = 40 } },
	{ id = "d_play", kind = "playMinutes", text = "Play for {target} minutes", target = 20, reward = { luckBoost = { mult = 1.5, minutes = 15 } } },
}

-- Repeatable quests restart with a bigger target each time they are claimed.
export type RepeatableQuest = {
	id: string,
	kind: QuestKind,
	text: string,
	target: number,
	minOrder: number?,
	reward: Reward,
	growth: number,
}

local Repeatable: { RepeatableQuest } = {
	{ id = "r_roll", kind = "rolls", text = "Roll {target} times", target = 50, growth = 1.35, reward = { scaledCash = 15 } },
	{ id = "r_comfy", kind = "rarityAtLeast", text = "Roll Comfortable or better {target} times", target = 5, minOrder = 4, growth = 1.25, reward = { scaledCash = 25 } },
	{ id = "r_earn", kind = "earn", text = "Earn {target} cash from rolls", target = 25, growth = 1.3, reward = { luckBoost = { mult = 1.5, minutes = 5 } } },
}

local Achievements: { Achievement } = {
	{ id = "a_first", name = "First Spin", description = "Roll once", stat = "totalRolls", target = 1, reward = { cash = 100 }, badgeId = 0 },
	{ id = "a_roll1k", name = "Dedicated Roller", description = "Roll 1,000 times", stat = "totalRolls", target = 1_000, reward = { scaledCash = 100 }, badgeId = 0 },
	{ id = "a_roll25k", name = "RNG Addict", description = "Roll 25,000 times", stat = "totalRolls", target = 25_000, reward = { scaledCash = 1_000 }, badgeId = 0 },
	{ id = "a_mil", name = "Officially a Millionaire", description = "Earn 1M lifetime cash", stat = "lifetime", target = 1e6, reward = { luckBoost = { mult = 2, minutes = 15 } }, badgeId = 0 },
	{ id = "a_bil", name = "Billionaire Club", description = "Earn 1B lifetime cash", stat = "lifetime", target = 1e9, reward = { scaledCash = 500 }, badgeId = 0 },
	{ id = "a_tril", name = "Trillionaire Club", description = "Earn 1T lifetime cash", stat = "lifetime", target = 1e12, reward = { scaledCash = 500 }, badgeId = 0 },
	{ id = "a_rb1", name = "Fresh Start", description = "Rebirth once", stat = "rebirths", target = 1, reward = { luckBoost = { mult = 2, minutes = 20 } }, badgeId = 0 },
	{ id = "a_rb5", name = "Serial Reborn", description = "Rebirth 5 times", stat = "rebirths", target = 5, reward = { scaledCash = 1_000 }, badgeId = 0 },
	{ id = "a_rb10", name = "Eternal Fortune", description = "Rebirth 10 times", stat = "rebirths", target = 10, reward = { scaledCash = 5_000 }, badgeId = 0 },
	{ id = "a_col5", name = "Collector", description = "Discover 5 rarities", stat = "discovered", target = 5, reward = { scaledCash = 50 }, badgeId = 0 },
	{ id = "a_col8", name = "Curator", description = "Discover 8 rarities", stat = "discovered", target = 8, reward = { scaledCash = 300 }, badgeId = 0 },
	{ id = "a_colall", name = "Complete Collection", description = "Discover every rarity", stat = "discovered", target = -1, reward = { scaledCash = 10_000, luckBoost = { mult = 5, minutes = 60 } }, badgeId = 0 },
	{ id = "a_bil_roll", name = "Lucky Billion", description = "Roll Billionaire or rarer", stat = "bestOrder", target = 8, reward = { luckBoost = { mult = 3, minutes = 30 } }, badgeId = 0 },
	{ id = "a_upg25", name = "Investor", description = "Buy 25 upgrade levels", stat = "upgradesBought", target = 25, reward = { scaledCash = 80 }, badgeId = 0 },
	{ id = "a_trade", name = "Deal Maker", description = "Complete a trade", stat = "trades", target = 1, reward = { scaledCash = 40 }, badgeId = 0 },
	{ id = "a_streak7", name = "Loyal Investor", description = "Reach a 7-day login streak", stat = "streak", target = 7, reward = { luckBoost = { mult = 3, minutes = 30 } }, badgeId = 0 },
}

local templatesById: { [string]: QuestTemplate } = {}
for _, quest in DailyPool do
	templatesById[quest.id] = quest
end
local repeatableById: { [string]: RepeatableQuest } = {}
for _, quest in Repeatable do
	repeatableById[quest.id] = quest
end
local achievementsById: { [string]: Achievement } = {}
for _, achievement in Achievements do
	achievementsById[achievement.id] = achievement
end

return {
	DailyPool = DailyPool,
	DailyCount = 3,
	DailyById = templatesById,
	Repeatable = Repeatable,
	RepeatableById = repeatableById,
	Achievements = Achievements,
	AchievementById = achievementsById,
}
