--!strict
-- Pure rarity maths. Used authoritatively by the server and for display
-- (odds lists) by the client. Contains no Roblox API calls so it can be unit
-- tested outside Studio.
--
-- Luck model: the most common rarity keeps its base weight, every other
-- rarity's weight (1 / chance) is multiplied by `luck`. Weights are then
-- normalised, so at 2x luck every non-common rarity is (almost exactly) twice
-- as likely and the relative odds between rare tiers never change.

local Rarities = require(script.Parent.Parent.Config.Rarities)

type Rarity = Rarities.Rarity

local RNG = {}

function RNG.getWeights(luck: number, list: { Rarity }?): { number }
	local rarities = list or Rarities.list
	luck = math.max(luck, 1)
	local weights = table.create(#rarities)
	for index, rarity in rarities do
		local weight = 1 / rarity.chance
		if index > 1 then
			weight *= luck
		end
		weights[index] = weight
	end
	return weights
end

-- Returns the probability (0-1) of each rarity, in list order.
function RNG.getProbabilities(luck: number, list: { Rarity }?): { number }
	local weights = RNG.getWeights(luck, list)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local probabilities = table.create(#weights)
	for index, weight in weights do
		probabilities[index] = weight / total
	end
	return probabilities
end

-- `random` must return a uniform number in [0, 1).
function RNG.pick(luck: number, random: () -> number, list: { Rarity }?): Rarity
	local rarities = list or Rarities.list
	local weights = RNG.getWeights(luck, rarities)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = random() * total
	-- Walk from rarest to most common so floating-point slack lands on the
	-- common tier rather than inflating a rare one.
	for index = #rarities, 1, -1 do
		roll -= weights[index]
		if roll < 0 then
			return rarities[index]
		end
	end
	return rarities[1]
end

-- Log-uniform cash within the rarity's range, so big ranges still feel varied.
function RNG.rollCash(rarity: Rarity, random: () -> number): number
	local low, high = math.log(rarity.minCash), math.log(rarity.maxCash)
	local value = math.exp(low + (high - low) * random())
	return math.clamp(math.floor(value), rarity.minCash, rarity.maxCash)
end

return RNG
