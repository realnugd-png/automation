--!strict
-- Authoritative roll resolution. The caller supplies the computed stats and a
-- server-side random source; the client never influences either.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local RNG = require(Shared.Modules.RNG)
local Formulas = require(Shared.Modules.Formulas)
local Economy = require(script.Parent.Economy)

type Profile = { [string]: any }

export type SingleResult = { id: string, cash: number }
export type RollOutcome = {
	results: { SingleResult },
	best: string,
	bestCash: number,
	total: number,
	newDiscoveries: { string },
	rollsDone: number,
}

local Roll = {}

function Roll.perform(profile: Profile, stats: Formulas.Stats, random: () -> number): RollOutcome
	local results: { SingleResult } = {}
	local total = 0
	local best: Rarities.Rarity? = nil
	local bestCash = 0
	local newDiscoveries = {}

	for _ = 1, stats.rollsPerClick do
		local rarity = RNG.pick(stats.luck, random)
		local cash = math.floor(RNG.rollCash(rarity, random) * stats.cashMultiplier)
		table.insert(results, { id = rarity.id, cash = cash })
		total += cash

		profile.rarityCounts[rarity.id] = (profile.rarityCounts[rarity.id] or 0) + 1
		if rarity.hasAura then
			profile.inventory[rarity.id] = (profile.inventory[rarity.id] or 0) + 1
		end
		if not profile.discovered[rarity.id] then
			profile.discovered[rarity.id] = true
			table.insert(newDiscoveries, rarity.id)
		end
		if rarity.order > profile.bestOrder then
			profile.bestOrder = rarity.order
		end
		if not best or rarity.order > best.order or (rarity.order == best.order and cash > bestCash) then
			best = rarity
			bestCash = cash
		end
	end

	assert(best, "rollsPerClick must be >= 1")
	Economy.addCash(profile, total)
	profile.totalRolls += stats.rollsPerClick
	if bestCash > profile.bestCash then
		profile.bestCash = bestCash
	end

	table.insert(profile.history, 1, { id = best.id, cash = bestCash })
	while #profile.history > GameConfig.Roll.historySize do
		table.remove(profile.history)
	end

	return {
		results = results,
		best = best.id,
		bestCash = bestCash,
		total = total,
		newDiscoveries = newDiscoveries,
		rollsDone = stats.rollsPerClick,
	}
end

return Roll
