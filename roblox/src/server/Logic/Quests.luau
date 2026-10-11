--!strict
-- Daily quests, repeatable quests, achievements and roll milestones.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local QuestConfig = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local Economy = require(script.Parent.Economy)

type Profile = { [string]: any }

local Quests = {}

-- Deterministic per-day selection (same three quests for everyone each day).
local function pickDaily(day: number): { string }
	local ids = {}
	for _, quest in QuestConfig.DailyPool do
		table.insert(ids, quest.id)
	end
	-- Park-Miller LCG: products stay below 2^53 so doubles are exact.
	local state = (day % 2147483646) + 1
	for i = #ids, 2, -1 do
		state = (state * 16807) % 2147483647
		local j = (state % i) + 1
		ids[i], ids[j] = ids[j], ids[i]
	end
	local chosen = {}
	for i = 1, math.min(QuestConfig.DailyCount, #ids) do
		chosen[i] = ids[i]
	end
	return chosen
end
Quests.pickDaily = pickDaily

local function scaledTarget(kind: string, target: number, bestOrder: number): number
	if kind == "earn" then
		return math.floor(target * Formulas.bestMinCash(bestOrder))
	end
	return target
end

-- Makes sure today's quests exist. Returns true if they were (re)issued.
function Quests.ensureDaily(profile: Profile, now: number): boolean
	local today = Formulas.dayNumber(now)
	local daily = profile.quests.daily
	if daily.day == today and #daily.list > 0 then
		return false
	end
	daily.day = today
	daily.list = {}
	for _, id in pickDaily(today) do
		local template = QuestConfig.DailyById[id]
		table.insert(daily.list, {
			id = id,
			target = scaledTarget(template.kind, template.target, profile.bestOrder),
			progress = 0,
			claimed = false,
		})
	end
	return true
end

function Quests.ensureRepeatable(profile: Profile)
	for _, quest in QuestConfig.Repeatable do
		if not profile.quests.repeatable[quest.id] then
			profile.quests.repeatable[quest.id] = {
				stage = 0,
				progress = 0,
				target = scaledTarget(quest.kind, quest.target, profile.bestOrder),
			}
		end
	end
end

local function matches(template: QuestConfig.QuestTemplate, kind: string, order: number?): boolean
	if template.kind ~= kind then
		return false
	end
	if kind == "rarityAtLeast" then
		return order ~= nil and order >= (template.minOrder or 1)
	end
	return true
end

-- kind: quest kind; amount: progress to add; order: rarity order for rarityAtLeast
function Quests.progress(profile: Profile, kind: string, amount: number, order: number?)
	for _, entry in profile.quests.daily.list do
		local template = QuestConfig.DailyById[entry.id]
		if template and not entry.claimed and matches(template, kind, order) then
			entry.progress = math.min(entry.progress + amount, entry.target)
		end
	end
	for id, state in profile.quests.repeatable do
		local template = QuestConfig.RepeatableById[id]
		if template and matches(template, kind, order) then
			state.progress = math.min(state.progress + amount, state.target)
		end
	end
end

function Quests.claimDaily(profile: Profile, index: any, now: number): (boolean, string)
	if type(index) ~= "number" then
		return false, "Invalid quest"
	end
	local entry = profile.quests.daily.list[index]
	if not entry or profile.quests.daily.day ~= Formulas.dayNumber(now) then
		return false, "Quest expired"
	end
	if entry.claimed then
		return false, "Already claimed"
	end
	if entry.progress < entry.target then
		return false, "Quest not complete"
	end
	entry.claimed = true
	local template = QuestConfig.DailyById[entry.id]
	return true, "Quest complete: " .. Economy.grant(profile, template.reward, "quest", now)
end

function Quests.claimRepeatable(profile: Profile, id: any, now: number): (boolean, string)
	if type(id) ~= "string" then
		return false, "Invalid quest"
	end
	local template = QuestConfig.RepeatableById[id]
	local state = profile.quests.repeatable[id]
	if not template or not state then
		return false, "Invalid quest"
	end
	if state.progress < state.target then
		return false, "Quest not complete"
	end
	local text = Economy.grant(profile, template.reward, "quest", now)
	state.stage += 1
	state.progress = 0
	state.target = scaledTarget(
		template.kind,
		Formulas.repeatableTarget(template.target, template.growth, state.stage),
		profile.bestOrder
	)
	return true, "Quest complete: " .. text
end

function Quests.statValue(profile: Profile, stat: string): number
	if stat == "totalRolls" then
		return profile.totalRolls
	elseif stat == "lifetime" then
		return profile.lifetime
	elseif stat == "rebirths" then
		return profile.rebirths
	elseif stat == "discovered" then
		local count = 0
		for _ in profile.discovered do
			count += 1
		end
		return count
	elseif stat == "bestOrder" then
		return profile.bestOrder
	elseif stat == "upgradesBought" then
		return profile.stats.upgradesBought
	elseif stat == "trades" then
		return profile.stats.trades
	elseif stat == "streak" then
		return profile.daily.streak
	end
	return 0
end

function Quests.achievementTarget(achievement: QuestConfig.Achievement): number
	return if achievement.target < 0 then Rarities.count else achievement.target
end

-- Grants every newly met achievement. Returns their definitions + reward text.
function Quests.checkAchievements(profile: Profile, now: number): { { achievement: QuestConfig.Achievement, text: string } }
	local earned = {}
	for _, achievement in QuestConfig.Achievements do
		if not profile.achievements[achievement.id]
			and Quests.statValue(profile, achievement.stat) >= Quests.achievementTarget(achievement)
		then
			profile.achievements[achievement.id] = true
			local text = Economy.grant(profile, achievement.reward, "achievement", now)
			table.insert(earned, { achievement = achievement, text = text })
		end
	end
	return earned
end

function Quests.checkMilestones(profile: Profile, now: number): { string }
	local messages = {}
	for _, milestone in GameConfig.RollMilestones do
		local key = tostring(milestone.rolls)
		if profile.totalRolls >= milestone.rolls and not profile.milestones[key] then
			profile.milestones[key] = true
			local text = Economy.grant(profile, milestone.reward, "milestone", now)
			table.insert(messages, `{milestone.rolls} rolls milestone: {text}`)
		end
	end
	return messages
end

return Quests
