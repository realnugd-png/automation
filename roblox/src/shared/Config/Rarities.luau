--!strict
-- Every rollable rarity, ordered from most common to rarest.
--
-- To add a rarity: append (or insert) an entry, keep `order` equal to its
-- position in the list, and give it a `chance` larger than the one before it.
-- RNG, rewards, auras, the index, quests and the UI all read from this list.

export type Effect = "none" | "sparkle" | "burst" | "flash" | "cinematic" | "celestial"

export type Rarity = {
	id: string,
	name: string,
	order: number,
	chance: number, -- "1 in chance" at 1x luck, before normalisation
	minCash: number,
	maxCash: number,
	color: Color3,
	accent: Color3,
	effect: Effect,
	announce: boolean, -- server-wide announcement when rolled
	hasAura: boolean, -- grants a collectible, equippable aura
	revealTime: number, -- seconds the client spends on the build-up
}

local Rarities: { Rarity } = {
	{
		id = "Broke",
		name = "Broke",
		order = 1,
		chance = 2,
		minCash = 1,
		maxCash = 5,
		color = Color3.fromRGB(150, 150, 150),
		accent = Color3.fromRGB(90, 90, 90),
		effect = "none",
		announce = false,
		hasAura = false,
		revealTime = 0.6,
	},
	{
		id = "Poor",
		name = "Poor",
		order = 2,
		chance = 4,
		minCash = 10,
		maxCash = 40,
		color = Color3.fromRGB(181, 140, 99),
		accent = Color3.fromRGB(110, 80, 50),
		effect = "none",
		announce = false,
		hasAura = false,
		revealTime = 0.6,
	},
	{
		id = "WorkingClass",
		name = "Working Class",
		order = 3,
		chance = 10,
		minCash = 75,
		maxCash = 250,
		color = Color3.fromRGB(96, 178, 255),
		accent = Color3.fromRGB(40, 100, 180),
		effect = "sparkle",
		announce = false,
		hasAura = false,
		revealTime = 0.7,
	},
	{
		id = "Comfortable",
		name = "Comfortable",
		order = 4,
		chance = 35,
		minCash = 500,
		maxCash = 1_500,
		color = Color3.fromRGB(90, 220, 140),
		accent = Color3.fromRGB(30, 140, 80),
		effect = "sparkle",
		announce = false,
		hasAura = true,
		revealTime = 0.8,
	},
	{
		id = "Rich",
		name = "Rich",
		order = 5,
		chance = 150,
		minCash = 5_000,
		maxCash = 20_000,
		color = Color3.fromRGB(255, 215, 90),
		accent = Color3.fromRGB(200, 150, 20),
		effect = "burst",
		announce = false,
		hasAura = true,
		revealTime = 1.0,
	},
	{
		id = "Millionaire",
		name = "Millionaire",
		order = 6,
		chance = 1_000,
		minCash = 1_000_000,
		maxCash = 3_000_000,
		color = Color3.fromRGB(255, 190, 40),
		accent = Color3.fromRGB(255, 240, 160),
		effect = "burst",
		announce = false,
		hasAura = true,
		revealTime = 1.3,
	},
	{
		id = "MultiMillionaire",
		name = "Multi-Millionaire",
		order = 7,
		chance = 7_500,
		minCash = 5_000_000,
		maxCash = 25_000_000,
		color = Color3.fromRGB(255, 120, 60),
		accent = Color3.fromRGB(255, 220, 120),
		effect = "flash",
		announce = true,
		hasAura = true,
		revealTime = 1.6,
	},
	{
		id = "Billionaire",
		name = "Billionaire",
		order = 8,
		chance = 50_000,
		minCash = 1e9,
		maxCash = 5e9,
		color = Color3.fromRGB(190, 90, 255),
		accent = Color3.fromRGB(255, 200, 255),
		effect = "flash",
		announce = true,
		hasAura = true,
		revealTime = 2.0,
	},
	{
		id = "Trillionaire",
		name = "Trillionaire",
		order = 9,
		chance = 400_000,
		minCash = 1e12,
		maxCash = 5e12,
		color = Color3.fromRGB(255, 60, 120),
		accent = Color3.fromRGB(255, 210, 90),
		effect = "cinematic",
		announce = true,
		hasAura = true,
		revealTime = 2.6,
	},
	{
		id = "SecretWealth",
		name = "Secret Wealth",
		order = 10,
		chance = 3_000_000,
		minCash = 5e13,
		maxCash = 2e14,
		color = Color3.fromRGB(40, 255, 220),
		accent = Color3.fromRGB(10, 10, 10),
		effect = "cinematic",
		announce = true,
		hasAura = true,
		revealTime = 3.2,
	},
	{
		id = "CelestialFortune",
		name = "Celestial Fortune",
		order = 11,
		chance = 25_000_000,
		minCash = 1e15,
		maxCash = 5e15,
		color = Color3.fromRGB(255, 255, 255),
		accent = Color3.fromRGB(140, 200, 255),
		effect = "celestial",
		announce = true,
		hasAura = true,
		revealTime = 4.0,
	},
}

local byId: { [string]: Rarity } = {}
for index, rarity in Rarities do
	assert(rarity.order == index, `Rarity {rarity.id} has order {rarity.order}, expected {index}`)
	assert(byId[rarity.id] == nil, `Duplicate rarity id {rarity.id}`)
	if index > 1 then
		assert(rarity.chance > Rarities[index - 1].chance, `Rarity {rarity.id} must be rarer than the one before it`)
	end
	byId[rarity.id] = rarity
end

return {
	list = Rarities,
	byId = byId,
	get = function(id: string): Rarity?
		return byId[id]
	end,
	count = #Rarities,
}
