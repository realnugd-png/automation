--!strict
-- Pure gameplay formulas shared by server (authoritative) and client (display).
-- No Roblox services are used here so the maths can be unit tested.

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Upgrades = require(Config.Upgrades)
local Rarities = require(Config.Rarities)
local Monetization = require(Config.Monetization)

export type Boost = { mult: number, expires: number }

export type StatContext = {
	passes: { [string]: boolean },
	zoneId: string,
	now: number,
	serverLuck: number,
}

export type Stats = {
	luck: number,
	cashMultiplier: number,
	cooldown: number,
	rollsPerClick: number,
	autoRollUnlocked: boolean,
	boostLuck: number,
	eventLuck: number,
	eventName: string?,
	zoneId: string,
}

local Formulas = {}

function Formulas.dayNumber(now: number): number
	return math.floor(now / 86400)
end

-- 0 = Sunday ... 6 = Saturday (1970-01-01 was a Thursday).
function Formulas.weekday(now: number): number
	return (Formulas.dayNumber(now) + 4) % 7
end

function Formulas.upgradeCost(upgradeId: string, level: number): number
	local upgrade = Upgrades.byId[upgradeId]
	assert(upgrade, `Unknown upgrade {upgradeId}`)
	return math.floor(upgrade.baseCost * upgrade.growth ^ level)
end

function Formulas.upgradeLevel(profile: any, upgradeId: string): number
	return (profile.upgrades and profile.upgrades[upgradeId]) or 0
end

function Formulas.rebirthCost(rebirths: number): number
	return math.floor(GameConfig.Rebirth.baseCost * GameConfig.Rebirth.costGrowth ^ rebirths)
end

-- Sum of (mult - 1) over active boosts, so two 2x boosts make 3x, not 4x.
function Formulas.boostLuck(boosts: { [string]: Boost }?, now: number): number
	local total = 1
	if boosts then
		for _, boost in boosts do
			if boost.expires > now then
				total += boost.mult - 1
			end
		end
	end
	return total
end

function Formulas.activeEvent(now: number): (number, string?)
	local best, name = 1, nil
	for _, event in GameConfig.Events do
		if now >= event.startsAt and now < event.endsAt and event.luckMultiplier > best then
			best, name = event.luckMultiplier, event.name
		end
	end
	local weekday = Formulas.weekday(now)
	if (weekday == 0 or weekday == 6) and GameConfig.WeekendEvent.luckMultiplier > best then
		best, name = GameConfig.WeekendEvent.luckMultiplier, GameConfig.WeekendEvent.name
	end
	return best, name
end

function Formulas.computeStats(profile: any, context: StatContext): Stats
	local passes = context.passes
	local zone = GameConfig.ZoneById[context.zoneId] or GameConfig.ZoneById.Downtown
	local rebirths = profile.rebirths or 0

	local additiveLuck = 1
		+ Formulas.upgradeLevel(profile, "Luck") * Upgrades.byId.Luck.perLevel
		+ rebirths * GameConfig.Rebirth.luckBonusPer
		+ zone.luckBonus
		+ (if passes.VIP then Monetization.VIP.luckBonus else 0)
	local boostLuck = Formulas.boostLuck(profile.boosts, context.now)
	local eventLuck, eventName = Formulas.activeEvent(context.now)
	local luck = additiveLuck
		* (if passes.DoubleLuck then 2 else 1)
		* boostLuck
		* eventLuck
		* math.max(context.serverLuck, 1)

	local cashMultiplier = (
		1
		+ Formulas.upgradeLevel(profile, "Cash") * Upgrades.byId.Cash.perLevel
		+ rebirths * GameConfig.Rebirth.cashBonusPer
		+ (if passes.VIP then Monetization.VIP.cashBonus else 0)
	) * zone.cashMultiplier

	local cooldown = GameConfig.Roll.baseCooldown
		* (1 - Formulas.upgradeLevel(profile, "Speed") * Upgrades.byId.Speed.perLevel)
		* (if passes.FastRoll then Monetization.FastRollMultiplier else 1)
	cooldown = math.max(cooldown, GameConfig.Roll.minCooldown)

	return {
		luck = luck,
		cashMultiplier = cashMultiplier,
		cooldown = cooldown,
		rollsPerClick = 1 + Formulas.upgradeLevel(profile, "Capacity") * Upgrades.byId.Capacity.perLevel,
		autoRollUnlocked = passes.AutoRoll == true or (profile.totalRolls or 0) >= GameConfig.Roll.autoRollUnlockRolls,
		boostLuck = boostLuck,
		eventLuck = eventLuck,
		eventName = eventName,
		zoneId = zone.id,
	}
end

function Formulas.bestMinCash(bestOrder: number): number
	local rarity = Rarities.list[math.clamp(bestOrder, 1, Rarities.count)]
	return math.max(50, rarity.minCash)
end

-- Turns a reward's scaled cash into a flat amount for this player.
function Formulas.rewardCash(reward: GameConfig.Reward, bestOrder: number): number
	local cash = reward.cash or 0
	if reward.scaledCash then
		cash += reward.scaledCash * Formulas.bestMinCash(bestOrder)
	end
	return math.floor(cash)
end

function Formulas.offlineCash(level: number, bestOrder: number, seconds: number): number
	if level <= 0 or seconds < GameConfig.Offline.minSeconds then
		return 0
	end
	local minutes = math.min(seconds, GameConfig.Offline.maxSeconds) / 60
	return math.floor(minutes * level * GameConfig.Offline.perMinuteFactor * Formulas.bestMinCash(bestOrder))
end

function Formulas.wealthTitle(lifetime: number): string
	local title = GameConfig.WealthTitles[1].title
	for _, entry in GameConfig.WealthTitles do
		if lifetime >= entry.lifetime then
			title = entry.title
		end
	end
	return title
end

function Formulas.repeatableTarget(baseTarget: number, growth: number, stage: number): number
	return math.max(1, math.floor(baseTarget * growth ^ stage))
end

-- OrderedDataStores only accept integers below 2^63, while cash can exceed
-- 1e15. Store log10 with 6 decimal places of precision instead.
function Formulas.encodeLeaderboardValue(value: number): number
	if value < 1 then
		return 0
	end
	return math.floor(math.log10(value) * 1e6) + 1
end

function Formulas.decodeLeaderboardValue(encoded: number): number
	if encoded <= 0 then
		return 0
	end
	return 10 ^ ((encoded - 1) / 1e6)
end

return Formulas
