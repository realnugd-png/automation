local H = require("./harness")

local SHARED = "src/shared"
local Rarities = H.require(SHARED .. "/Config/Rarities")
local RNG = H.require(SHARED .. "/Modules/RNG")
local Formulas = H.require(SHARED .. "/Modules/Formulas")
local NumberFormat = H.require(SHARED .. "/Modules/NumberFormat")
local GameConfig = H.require(SHARED .. "/Config/GameConfig")
local Quests = H.require(SHARED .. "/Config/Quests")
local Upgrades = H.require(SHARED .. "/Config/Upgrades")

print("Shared module tests")

H.test("rarities are ordered and progressively rarer", function()
	for i, rarity in Rarities.list do
		H.expect(rarity.order == i)
		H.expect(rarity.minCash <= rarity.maxCash, rarity.id .. " cash range")
		if i > 1 then
			H.expect(rarity.chance > Rarities.list[i - 1].chance)
			H.expect(rarity.minCash > Rarities.list[i - 1].maxCash, rarity.id .. " should pay more than the tier below")
		end
	end
end)

H.test("probabilities sum to 1 at any luck", function()
	for _, luck in { 1, 2, 7.5, 1000 } do
		local sum = 0
		for _, p in RNG.getProbabilities(luck) do
			sum += p
		end
		H.near(sum, 1, 1e-9, "sum at luck " .. luck)
	end
end)

H.test("luck scales rare tiers and keeps their relative odds", function()
	local base = RNG.getProbabilities(1)
	local lucky = RNG.getProbabilities(2)
	local n = #base
	-- Ratio between two rare tiers is unchanged by luck.
	H.near(lucky[n] / lucky[n - 1], base[n] / base[n - 1], 1e-12, "rare tier ratio")
	-- Rare tiers become ~2x as likely (exactly 2x relative to the common tier).
	H.near((lucky[n] / lucky[1]) / (base[n] / base[1]), 2, 1e-9, "luck vs common")
	H.expect(lucky[1] < base[1], "common tier must shrink with luck")
	-- Luck below 1 is treated as 1.
	H.near(RNG.getProbabilities(0.2)[n], base[n], 1e-15, "luck floor")
end)

H.test("rarest tier is genuinely rare at 1x luck", function()
	local probabilities = RNG.getProbabilities(1)
	H.expect(1 / probabilities[#probabilities] > 10_000_000, "Celestial should be rarer than 1 in 10M")
end)

H.test("pick matches the analytic distribution (Monte Carlo)", function()
	math.randomseed(1234)
	local samples = 400_000
	local luck = 50
	local counts = {}
	for _ = 1, samples do
		local rarity = RNG.pick(luck, math.random)
		counts[rarity.order] = (counts[rarity.order] or 0) + 1
	end
	local expected = RNG.getProbabilities(luck)
	for order = 1, 5 do
		local observed = (counts[order] or 0) / samples
		local sigma = math.sqrt(expected[order] * (1 - expected[order]) / samples)
		H.near(observed, expected[order], 5 * sigma + 1e-9, Rarities.list[order].id)
	end
end)

H.test("pick handles random() edge values", function()
	H.expect(RNG.pick(1, function()
		return 0
	end).order == Rarities.count, "0 maps to the last rarity bucket walked first")
	H.expect(RNG.pick(1, function()
		return 0.9999999999
	end).order == 1, "~1 maps to the common tier")
end)

H.test("rollCash stays within range", function()
	math.randomseed(7)
	for _, rarity in Rarities.list do
		for _ = 1, 200 do
			local cash = RNG.rollCash(rarity, math.random)
			H.expect(cash >= rarity.minCash and cash <= rarity.maxCash, rarity.id .. " cash " .. cash)
		end
		H.expect(RNG.rollCash(rarity, function()
			return 0
		end) == rarity.minCash)
	end
end)

local function profile(overrides)
	local p = { upgrades = {}, rebirths = 0, boosts = {}, totalRolls = 0 }
	for k, v in overrides or {} do
		p[k] = v
	end
	return p
end

local weekdayNoon = 1767960000 -- 2026-01-09 12:00 UTC, a Friday
local saturday = weekdayNoon + 86400

local function ctx(overrides)
	local c = { passes = {}, zoneId = "Downtown", now = weekdayNoon, serverLuck = 1 }
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

H.test("base stats for a new player", function()
	local stats = Formulas.computeStats(profile(), ctx())
	H.near(stats.luck, 1, 1e-12, "luck")
	H.near(stats.cashMultiplier, 1, 1e-12, "cash")
	H.near(stats.cooldown, GameConfig.Roll.baseCooldown, 1e-12, "cooldown")
	H.expect(stats.rollsPerClick == 1)
	H.expect(stats.autoRollUnlocked == false)
	H.expect(stats.eventName == nil)
end)

H.test("upgrades, rebirths, zones, passes, boosts and events stack correctly", function()
	local p = profile({
		upgrades = { Luck = 10, Cash = 4, Speed = 5, Capacity = 2 },
		rebirths = 2,
		boosts = {
			daily = { mult = 2, expires = weekdayNoon + 60 },
			product = { mult = 3, expires = weekdayNoon + 60 },
			old = { mult = 10, expires = weekdayNoon - 1 },
		},
		totalRolls = 800,
	})
	local stats = Formulas.computeStats(p, ctx({ zoneId = "LuxuryHills", passes = { VIP = true, DoubleLuck = true } }))
	-- additive: 1 + 1.0 (luck) + 0.2 (rebirth) + 0.25 (zone) + 0.1 (vip) = 2.55
	-- boosts: 1 + 1 + 2 = 4 (expired ignored); double luck 2x
	H.near(stats.luck, 2.55 * 2 * 4, 1e-9, "luck")
	-- cash: (1 + 0.6 + 1.0 + 0.25) * 1.5
	H.near(stats.cashMultiplier, 2.85 * 1.5, 1e-9, "cash")
	H.near(stats.cooldown, 1.6 * 0.7, 1e-9, "cooldown")
	H.expect(stats.rollsPerClick == 3)
	H.expect(stats.autoRollUnlocked == true)
end)

H.test("cooldown never drops below the minimum", function()
	local stats = Formulas.computeStats(profile({ upgrades = { Speed = 10 } }), ctx({ passes = { FastRoll = true } }))
	H.near(stats.cooldown, GameConfig.Roll.minCooldown, 1e-12)
end)

H.test("weekend event applies on Saturday only", function()
	H.expect(Formulas.weekday(weekdayNoon) == 5, "fixture should be a Friday")
	local _, name = Formulas.activeEvent(weekdayNoon)
	H.expect(name == nil)
	local mult, satName = Formulas.activeEvent(saturday)
	H.expect(satName ~= nil and mult == GameConfig.WeekendEvent.luckMultiplier)
	local stats = Formulas.computeStats(profile(), ctx({ now = saturday }))
	H.near(stats.luck, 1.5, 1e-12)
end)

H.test("scheduled event overrides weekend when stronger", function()
	local event = GameConfig.Events[1]
	local mult, name = Formulas.activeEvent(event.startsAt + 10)
	H.expect(mult == event.luckMultiplier and name == event.name)
	local after = Formulas.activeEvent(event.endsAt)
	H.expect(after ~= event.luckMultiplier or Formulas.weekday(event.endsAt) % 6 == 0)
end)

H.test("unknown zone falls back to Downtown", function()
	local stats = Formulas.computeStats(profile(), ctx({ zoneId = "Hacked" }))
	H.expect(stats.zoneId == "Downtown")
end)

H.test("upgrade costs grow and are integers", function()
	for _, upgrade in Upgrades.list do
		local last = 0
		for level = 0, upgrade.maxLevel - 1 do
			local cost = Formulas.upgradeCost(upgrade.id, level)
			H.expect(cost == math.floor(cost) and cost > last, upgrade.id .. " level " .. level)
			last = cost
		end
	end
end)

H.test("rebirth costs", function()
	H.expect(Formulas.rebirthCost(0) == 1_000_000)
	H.expect(Formulas.rebirthCost(1) == 20_000_000)
end)

H.test("reward cash scales with best rarity", function()
	H.expect(Formulas.rewardCash({ cash = 10 }, 1) == 10)
	H.expect(Formulas.rewardCash({ scaledCash = 2 }, 1) == 100) -- min base 50
	H.expect(Formulas.rewardCash({ scaledCash = 2, cash = 1 }, 6) == 2_000_001)
end)

H.test("offline cash respects min and cap", function()
	H.expect(Formulas.offlineCash(3, 5, 100) == 0)
	H.expect(Formulas.offlineCash(0, 5, 99999) == 0)
	local capped = Formulas.offlineCash(1, 5, 10 * 86400)
	local eightHours = Formulas.offlineCash(1, 5, 8 * 3600)
	H.expect(capped == eightHours and capped > 0)
end)

H.test("wealth titles", function()
	H.expect(Formulas.wealthTitle(0) == "Broke Beginner")
	H.expect(Formulas.wealthTitle(1_000_000) == "Millionaire")
	H.expect(Formulas.wealthTitle(5e20) == "Celestial Heir")
end)

H.test("leaderboard encoding round-trips and preserves order", function()
	local values = { 0, 1, 999, 1e6, 123456789, 5e15, 7.7e22 }
	local last = -1
	for _, v in values do
		local encoded = Formulas.encodeLeaderboardValue(v)
		H.expect(encoded == math.floor(encoded) and encoded >= last and encoded < 2 ^ 53)
		last = encoded
		if v >= 1 then
			H.near(Formulas.decodeLeaderboardValue(encoded) / v, 1, 1e-5, "round trip " .. v)
		end
	end
end)

H.test("number formatting", function()
	H.expect(NumberFormat.short(0) == "0")
	H.expect(NumberFormat.short(999) == "999")
	H.expect(NumberFormat.short(1000) == "1K")
	H.expect(NumberFormat.short(1234) == "1.23K")
	H.expect(NumberFormat.short(100_000) == "100K", NumberFormat.short(100_000))
	H.expect(NumberFormat.short(15_500_000) == "15.5M")
	H.expect(NumberFormat.short(5e15) == "5Qa")
	H.expect(NumberFormat.short(-2500) == "-2.5K")
	H.expect(NumberFormat.commas(1234567) == "1,234,567", NumberFormat.commas(1234567))
	H.expect(NumberFormat.commas(123) == "123")
	H.expect(NumberFormat.odds(0.5) == "1 in 2.0")
	H.expect(NumberFormat.duration(3725) == "1h 02m")
end)

H.test("quest config references valid rarities", function()
	for _, quest in Quests.DailyPool do
		if quest.kind == "rarityAtLeast" then
			H.expect(Rarities.list[quest.minOrder] ~= nil, quest.id)
		end
	end
	H.expect(#Quests.DailyPool >= Quests.DailyCount)
end)

H.test("zone progression is ordered", function()
	local lastCost = -1
	for _, zone in GameConfig.Zones do
		H.expect(zone.cost > lastCost, zone.id)
		lastCost = zone.cost
	end
end)

return H.summary()
