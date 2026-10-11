--!strict
-- Trade validation and execution for collectible auras. Only auras are
-- tradeable (never cash) to keep the economy safe.
--
-- Safety properties:
--  * Offers are sanitised: only known aura ids, positive whole counts, no
--    more than the player owns, at most `maxKindsPerOffer` kinds.
--  * `execute` re-validates both offers against the live inventories and only
--    mutates after both pass. It never yields, so nothing can change between
--    validation and the swap (Luau runs it atomically on the server).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)

type Profile = { [string]: any }
export type Offer = { [string]: number }

local Trade = {}

function Trade.sanitizeOffer(profile: Profile, raw: any): (Offer?, string?)
	if type(raw) ~= "table" then
		return nil, "Invalid offer"
	end
	local offer: Offer = {}
	local kinds = 0
	for id, count in raw do
		if type(id) ~= "string" or type(count) ~= "number" then
			return nil, "Invalid offer"
		end
		local rarity = Rarities.get(id)
		if not rarity or not rarity.hasAura then
			return nil, "Invalid item"
		end
		if count ~= count or count % 1 ~= 0 or count < 0 or count > 1e6 then
			return nil, "Invalid amount"
		end
		if count > 0 then
			if (profile.inventory[id] or 0) < count then
				return nil, "You don't own enough " .. rarity.name
			end
			kinds += 1
			offer[id] = count
		end
	end
	if kinds > GameConfig.Trade.maxKindsPerOffer then
		return nil, "Too many different items"
	end
	return offer, nil
end

local function owns(profile: Profile, offer: Offer): boolean
	for id, count in offer do
		if (profile.inventory[id] or 0) < count then
			return false
		end
	end
	return true
end

local function isEmpty(offer: Offer): boolean
	return next(offer) == nil
end

local function move(from: Profile, to: Profile, offer: Offer)
	for id, count in offer do
		local remaining = from.inventory[id] - count
		from.inventory[id] = if remaining > 0 then remaining else nil
		to.inventory[id] = (to.inventory[id] or 0) + count
		if remaining <= 0 and from.equippedAura == id then
			from.equippedAura = ""
		end
	end
end

function Trade.execute(a: Profile, offerA: Offer, b: Profile, offerB: Offer): (boolean, string)
	if a == b then
		return false, "Cannot trade with yourself"
	end
	if isEmpty(offerA) and isEmpty(offerB) then
		return false, "Both offers are empty"
	end
	if not owns(a, offerA) or not owns(b, offerB) then
		return false, "An offered item is no longer available"
	end
	move(a, b, offerA)
	move(b, a, offerB)
	a.stats.trades += 1
	b.stats.trades += 1
	return true, "Trade complete!"
end

return Trade
