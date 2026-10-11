--!strict
-- Game passes and developer products.
--
-- IMPORTANT: ids are 0 until you create the passes/products on the Creator
-- Dashboard and paste the real ids here. Items with id 0 are shown in the shop
-- as "Not available yet" and cannot be bought — nothing is ever faked.

export type Pass = {
	key: string,
	id: number,
	name: string,
	description: string,
	priceHint: number, -- shown in the UI only; Roblox shows the real price at checkout
}

export type Product = {
	key: string,
	id: number,
	name: string,
	description: string,
	priceHint: number,
	-- What is granted; handled in MonetizationService.
	grant: {
		luckBoost: { mult: number, minutes: number }?,
		scaledCash: number?,
		serverLuck: { mult: number, minutes: number }?,
	},
}

local Passes: { Pass } = {
	{ key = "VIP", id = 0, name = "VIP", description = "+25% cash, +10% luck, VIP chat tag, exclusive VIP aura", priceHint = 299 },
	{ key = "DoubleLuck", id = 0, name = "2x Luck", description = "Permanently doubles your luck", priceHint = 499 },
	{ key = "FastRoll", id = 0, name = "Fast Roll", description = "Roll cooldown is 30% shorter", priceHint = 249 },
	{ key = "AutoRoll", id = 0, name = "Instant Auto-Roll", description = "Unlock auto-roll right away (free after 750 rolls)", priceHint = 99 },
}

local Products: { Product } = {
	{ key = "Luck15", id = 0, name = "2x Luck (15 min)", description = "Personal 2x luck boost", priceHint = 49, grant = { luckBoost = { mult = 2, minutes = 15 } } },
	{ key = "Luck60", id = 0, name = "3x Luck (60 min)", description = "Personal 3x luck boost", priceHint = 149, grant = { luckBoost = { mult = 3, minutes = 60 } } },
	{ key = "CashPack", id = 0, name = "Cash Briefcase", description = "Cash scaled to your best rarity", priceHint = 99, grant = { scaledCash = 400 } },
	{ key = "ServerLuck", id = 0, name = "Server 2x Luck (10 min)", description = "Everyone in the server gets 2x luck", priceHint = 199, grant = { serverLuck = { mult = 2, minutes = 10 } } },
}

local passByKey: { [string]: Pass } = {}
local passById: { [number]: Pass } = {}
for _, pass in Passes do
	passByKey[pass.key] = pass
	if pass.id ~= 0 then
		passById[pass.id] = pass
	end
end
local productByKey: { [string]: Product } = {}
local productById: { [number]: Product } = {}
for _, product in Products do
	productByKey[product.key] = product
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

return {
	Passes = Passes,
	Products = Products,
	PassByKey = passByKey,
	PassById = passById,
	ProductByKey = productByKey,
	ProductById = productById,
	VIP = { cashBonus = 0.25, luckBonus = 0.1 },
	FastRollMultiplier = 0.7,
}
