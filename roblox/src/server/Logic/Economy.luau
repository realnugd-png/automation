--!strict
-- Pure, server-only state transitions for spending and granting cash.
-- Every function validates its input against the profile and returns
-- (ok, message). Nothing here trusts values from a client.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.Upgrades)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Modules.Formulas)
local NumberFormat = require(Shared.Modules.NumberFormat)

type Profile = { [string]: any }
type Reward = GameConfig.Reward

local Economy = {}

function Economy.addCash(profile: Profile, amount: number)
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	profile.cash += amount
	profile.lifetime += amount
end

function Economy.addBoost(profile: Profile, source: string, mult: number, minutes: number, now: number)
	local existing = profile.boosts[source]
	local start = if existing and existing.expires > now then existing.expires else now
	profile.boosts[source] = {
		mult = if existing and existing.expires > now then math.max(existing.mult, mult) else mult,
		expires = start + minutes * 60,
	}
end

function Economy.pruneBoosts(profile: Profile, now: number)
	for source, boost in profile.boosts do
		if boost.expires <= now then
			profile.boosts[source] = nil
		end
	end
end

-- Grants a reward and returns a human readable description of it.
function Economy.grant(profile: Profile, reward: Reward, source: string, now: number): string
	local parts = {}
	local cash = Formulas.rewardCash(reward, profile.bestOrder)
	if cash > 0 then
		Economy.addCash(profile, cash)
		table.insert(parts, "$" .. NumberFormat.short(cash))
	end
	if reward.luckBoost then
		Economy.addBoost(profile, source, reward.luckBoost.mult, reward.luckBoost.minutes, now)
		table.insert(parts, `{reward.luckBoost.mult}x Luck ({reward.luckBoost.minutes}m)`)
	end
	return table.concat(parts, " + ")
end

function Economy.describe(reward: Reward, bestOrder: number): string
	local parts = {}
	local cash = Formulas.rewardCash(reward, bestOrder)
	if cash > 0 then
		table.insert(parts, "$" .. NumberFormat.short(cash))
	end
	if reward.luckBoost then
		table.insert(parts, `{reward.luckBoost.mult}x Luck ({reward.luckBoost.minutes}m)`)
	end
	return table.concat(parts, " + ")
end

function Economy.buyUpgrade(profile: Profile, upgradeId: any): (boolean, string)
	if type(upgradeId) ~= "string" then
		return false, "Invalid upgrade"
	end
	local upgrade = Upgrades.byId[upgradeId]
	if not upgrade then
		return false, "Invalid upgrade"
	end
	local level = profile.upgrades[upgradeId] or 0
	if level >= upgrade.maxLevel then
		return false, "Already maxed"
	end
	local cost = Formulas.upgradeCost(upgradeId, level)
	if profile.cash < cost then
		return false, "Not enough cash"
	end
	profile.cash -= cost
	profile.upgrades[upgradeId] = level + 1
	profile.stats.upgradesBought += 1
	return true, `{upgrade.name} upgraded to level {level + 1}`
end

function Economy.rebirth(profile: Profile): (boolean, string)
	if profile.rebirths >= GameConfig.Rebirth.maxRebirths then
		return false, "Max rebirths reached"
	end
	local cost = Formulas.rebirthCost(profile.rebirths)
	if profile.cash < cost then
		return false, `You need ${NumberFormat.short(cost)} to rebirth`
	end
	profile.cash = 0
	for _, upgrade in Upgrades.list do
		if not upgrade.keepOnRebirth then
			profile.upgrades[upgrade.id] = 0
		end
	end
	profile.rebirths += 1
	return true, `Rebirth {profile.rebirths}! Permanent bonuses increased.`
end

function Economy.unlockZone(profile: Profile, zoneId: any): (boolean, string)
	if type(zoneId) ~= "string" then
		return false, "Invalid zone"
	end
	local zone = GameConfig.ZoneById[zoneId]
	if not zone then
		return false, "Invalid zone"
	end
	if profile.zones[zoneId] then
		return false, "Already unlocked"
	end
	if profile.rebirths < zone.requiredRebirths then
		return false, `Requires {zone.requiredRebirths} rebirth(s)`
	end
	if profile.cash < zone.cost then
		return false, `You need ${NumberFormat.short(zone.cost)}`
	end
	profile.cash -= zone.cost
	profile.zones[zoneId] = true
	return true, `{zone.name} unlocked!`
end

function Economy.equipAura(profile: Profile, auraId: any, hasVipPass: boolean): (boolean, string)
	if auraId == "" then
		profile.equippedAura = ""
		return true, "Aura unequipped"
	end
	if type(auraId) ~= "string" then
		return false, "Invalid aura"
	end
	if auraId == "VIP" then
		if not hasVipPass then
			return false, "VIP aura requires the VIP pass"
		end
		profile.equippedAura = "VIP"
		return true, "VIP aura equipped"
	end
	local rarity = Rarities.get(auraId)
	if not rarity or not rarity.hasAura then
		return false, "Invalid aura"
	end
	if (profile.inventory[auraId] or 0) < 1 then
		return false, "You don't own that aura"
	end
	profile.equippedAura = auraId
	return true, `{rarity.name} aura equipped`
end

local BOOLEAN_SETTINGS = {
	effects = true,
	shake = true,
	sounds = true,
	hideOtherAuras = true,
	autoRollSkipReveal = true,
}

function Economy.setSetting(profile: Profile, key: any, value: any): (boolean, string)
	if type(key) ~= "string" or not BOOLEAN_SETTINGS[key] or type(value) ~= "boolean" then
		return false, "Invalid setting"
	end
	profile.settings[key] = value
	return true, "Saved"
end

export type CodeDefinition = { reward: Reward, expiresAt: number? }

function Economy.redeemCode(profile: Profile, rawCode: any, codes: { [string]: CodeDefinition }, now: number): (boolean, string)
	if type(rawCode) ~= "string" or #rawCode == 0 or #rawCode > 32 then
		return false, "Invalid code"
	end
	local code = string.upper((rawCode:gsub("%s", "")))
	local definition = codes[code]
	if not definition then
		return false, "Invalid code"
	end
	if definition.expiresAt and now >= definition.expiresAt then
		return false, "This code has expired"
	end
	if profile.codes[code] then
		return false, "Code already redeemed"
	end
	profile.codes[code] = true
	return true, "Code redeemed: " .. Economy.grant(profile, definition.reward, "code", now)
end

return Economy
