--!strict
-- Permanent upgrades bought with cash. Cost of level n -> n+1 is
-- floor(baseCost * growth ^ n). `perLevel` meaning depends on the upgrade.

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	baseCost: number,
	growth: number,
	maxLevel: number,
	perLevel: number,
	keepOnRebirth: boolean,
	order: number,
}

local Upgrades: { Upgrade } = {
	{
		id = "Luck",
		name = "Lucky Charm",
		description = "+10% luck per level",
		baseCost = 150,
		growth = 1.55,
		maxLevel = 50,
		perLevel = 0.10,
		keepOnRebirth = false,
		order = 1,
	},
	{
		id = "Cash",
		name = "Golden Wallet",
		description = "+15% cash from rolls per level",
		baseCost = 100,
		growth = 1.5,
		maxLevel = 50,
		perLevel = 0.15,
		keepOnRebirth = false,
		order = 2,
	},
	{
		id = "Speed",
		name = "Quick Hands",
		description = "-6% roll cooldown per level",
		baseCost = 400,
		growth = 2.1,
		maxLevel = 10,
		perLevel = 0.06,
		keepOnRebirth = false,
		order = 3,
	},
	{
		id = "Capacity",
		name = "Multi-Roll",
		description = "+1 roll per click (best result is revealed)",
		baseCost = 25_000,
		growth = 12,
		maxLevel = 4,
		perLevel = 1,
		keepOnRebirth = false,
		order = 4,
	},
	{
		id = "Offline",
		name = "Passive Income",
		description = "Earn cash while offline (up to 8h)",
		baseCost = 5_000,
		growth = 3,
		maxLevel = 10,
		perLevel = 1,
		keepOnRebirth = true,
		order = 5,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in Upgrades do
	byId[upgrade.id] = upgrade
end

return {
	list = Upgrades,
	byId = byId,
}
