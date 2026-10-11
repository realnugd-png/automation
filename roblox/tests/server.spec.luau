local H = require("./harness")

local LOGIC = "src/server/Logic"
local Profile = H.require(LOGIC .. "/Profile")
local Economy = H.require(LOGIC .. "/Economy")
local Roll = H.require(LOGIC .. "/Roll")
local Daily = H.require(LOGIC .. "/Daily")
local Quests = H.require(LOGIC .. "/Quests")
local Trade = H.require(LOGIC .. "/Trade")
local Formulas = H.require("src/shared/Modules/Formulas")
local GameConfig = H.require("src/shared/Config/GameConfig")
local QuestConfig = H.require("src/shared/Config/Quests")
local Rarities = H.require("src/shared/Config/Rarities")

print("Server logic tests")

local NOW = 1767960000 -- Friday 2026-01-09 12:00 UTC
local DAY = 86400

local function stats(profile, overrides)
	local s = Formulas.computeStats(profile, { passes = {}, zoneId = "Downtown", now = NOW, serverLuck = 1 })
	for k, v in overrides or {} do
		s[k] = v
	end
	return s
end

H.test("migrate fills missing fields without touching existing data", function()
	local old = { version = 1, cash = 1234, inventory = { Rich = 3 }, upgrades = { Luck = 4 }, settings = { effects = false } }
	local profile = Profile.migrate(old)
	H.expect(profile.cash == 1234 and profile.inventory.Rich == 3)
	H.expect(profile.upgrades.Luck == 4 and profile.upgrades.Cash == 0)
	H.expect(profile.settings.effects == false and profile.settings.sounds == true)
	H.expect(profile.daily.playClaimed ~= nil and profile.quests.daily.list ~= nil)
end)

H.test("migrate refuses data from a newer version", function()
	local ok = pcall(Profile.migrate, { version = GameConfig.DataVersion + 1 })
	H.expect(not ok)
end)

H.test("migrate replaces wrongly-typed fields", function()
	local profile = Profile.migrate({ version = 1, cash = "lots", inventory = 5 })
	H.expect(profile.cash == 0 and type(profile.inventory) == "table")
end)

H.test("snapshot hides receipts and codes", function()
	local profile = Profile.template()
	profile.codes.SECRET = true
	table.insert(profile.receipts, "abc")
	local snap = Profile.snapshot(profile)
	H.expect(snap.codes == nil and snap.receipts == nil)
	H.expect(profile.codes.SECRET == true, "original untouched")
end)

H.test("roll grants cash, counts, inventory and history", function()
	local profile = Profile.template()
	local seq = { 0.9999, 0.5 } -- common tier, mid cash
	local i = 0
	local outcome = Roll.perform(profile, stats(profile), function()
		i += 1
		return seq[((i - 1) % #seq) + 1]
	end)
	H.expect(outcome.best == "Broke", outcome.best)
	H.expect(profile.cash == outcome.total and profile.lifetime == outcome.total and outcome.total >= 1)
	H.expect(profile.totalRolls == 1 and profile.bestOrder == 1 and profile.discovered.Broke)
	H.expect(profile.inventory.Broke == nil, "Broke has no aura")
	H.expect(#profile.history == 1 and outcome.newDiscoveries[1] == "Broke")
end)

H.test("multi-roll reveals the best result and applies cash multiplier", function()
	local profile = Profile.template()
	local values = { 0.9999, 0.0, 0.0, 0.0, 0.9999, 0.0 } -- Broke, Celestial(min), Broke
	local i = 0
	local outcome = Roll.perform(profile, stats(profile, { rollsPerClick = 3, cashMultiplier = 2 }), function()
		i += 1
		return values[i]
	end)
	H.expect(outcome.best == "CelestialFortune", outcome.best)
	H.expect(outcome.bestCash == Rarities.byId.CelestialFortune.minCash * 2)
	H.expect(profile.totalRolls == 3 and profile.inventory.CelestialFortune == 1)
	H.expect(profile.bestOrder == Rarities.count)
end)

H.test("history is capped", function()
	local profile = Profile.template()
	for _ = 1, 40 do
		Roll.perform(profile, stats(profile), math.random)
	end
	H.expect(#profile.history == GameConfig.Roll.historySize)
end)

H.test("upgrades validate cash, id and max level", function()
	local profile = Profile.template()
	H.expect(not Economy.buyUpgrade(profile, "Luck"), "no cash")
	H.expect(not Economy.buyUpgrade(profile, "Nope"))
	H.expect(not Economy.buyUpgrade(profile, { "Luck" }))
	profile.cash = 1e30
	H.expect(Economy.buyUpgrade(profile, "Luck"))
	H.expect(profile.upgrades.Luck == 1 and profile.stats.upgradesBought == 1)
	profile.upgrades.Capacity = 4
	H.expect(not Economy.buyUpgrade(profile, "Capacity"), "max level")
end)

H.test("upgrade changes gameplay stats", function()
	local profile = Profile.template()
	local before = stats(profile)
	profile.upgrades.Luck = 5
	profile.upgrades.Speed = 3
	profile.upgrades.Capacity = 1
	local after = stats(profile)
	H.expect(after.luck > before.luck and after.cooldown < before.cooldown and after.rollsPerClick == 2)
end)

H.test("rebirth requires cash, resets selected progress, keeps collection", function()
	local profile = Profile.template()
	profile.cash = Formulas.rebirthCost(0) - 1
	H.expect(not Economy.rebirth(profile))
	profile.cash = Formulas.rebirthCost(0)
	profile.lifetime = 5e6
	profile.upgrades.Luck = 10
	profile.upgrades.Offline = 2
	profile.inventory.Rich = 2
	profile.zones.LuxuryHills = true
	local before = stats(profile)
	H.expect(Economy.rebirth(profile))
	H.expect(profile.cash == 0 and profile.rebirths == 1 and profile.upgrades.Luck == 0)
	H.expect(profile.upgrades.Offline == 2 and profile.inventory.Rich == 2 and profile.zones.LuxuryHills)
	H.expect(profile.lifetime == 5e6)
	profile.upgrades.Luck = 10
	local after = stats(profile)
	H.expect(after.luck > before.luck and after.cashMultiplier > before.cashMultiplier, "permanent bonus")
end)

H.test("zone unlock checks rebirths and cash", function()
	local profile = Profile.template()
	profile.cash = 1e30
	H.expect(not Economy.unlockZone(profile, "CasinoStrip"), "needs rebirth")
	H.expect(Economy.unlockZone(profile, "LuxuryHills"))
	H.expect(not Economy.unlockZone(profile, "LuxuryHills"), "already")
	H.expect(not Economy.unlockZone(profile, "Fake"))
end)

H.test("aura equip requires ownership", function()
	local profile = Profile.template()
	H.expect(not Economy.equipAura(profile, "Rich", false))
	H.expect(not Economy.equipAura(profile, "Broke", false), "no aura for Broke")
	profile.inventory.Rich = 1
	H.expect(Economy.equipAura(profile, "Rich", false) and profile.equippedAura == "Rich")
	H.expect(not Economy.equipAura(profile, "VIP", false))
	H.expect(Economy.equipAura(profile, "VIP", true))
	H.expect(Economy.equipAura(profile, "", false) and profile.equippedAura == "")
end)

H.test("settings only accept known boolean keys", function()
	local profile = Profile.template()
	H.expect(Economy.setSetting(profile, "effects", false) and profile.settings.effects == false)
	H.expect(not Economy.setSetting(profile, "cash", true))
	H.expect(not Economy.setSetting(profile, "sounds", "yes"))
end)

H.test("codes redeem once, are case-insensitive and can expire", function()
	local codes = {
		RICH = { reward = { cash = 500 } },
		OLD = { reward = { cash = 1 }, expiresAt = NOW - 1 },
	}
	local profile = Profile.template()
	H.expect(Economy.redeemCode(profile, " rich ", codes, NOW) and profile.cash == 500)
	H.expect(not Economy.redeemCode(profile, "RICH", codes, NOW) and profile.cash == 500)
	H.expect(not Economy.redeemCode(profile, "OLD", codes, NOW))
	H.expect(not Economy.redeemCode(profile, "NOPE", codes, NOW))
	H.expect(not Economy.redeemCode(profile, 42, codes, NOW))
end)

H.test("boosts stack additively and extend per source", function()
	local profile = Profile.template()
	Economy.addBoost(profile, "a", 2, 10, NOW)
	Economy.addBoost(profile, "a", 2, 10, NOW)
	H.expect(profile.boosts.a.expires == NOW + 1200, "extended")
	Economy.addBoost(profile, "b", 3, 5, NOW)
	H.near(Formulas.boostLuck(profile.boosts, NOW), 4, 1e-12)
	H.near(Formulas.boostLuck(profile.boosts, NOW + 1201), 1, 1e-12)
	Economy.pruneBoosts(profile, NOW + 1201)
	H.expect(next(profile.boosts) == nil)
end)

H.test("daily login: once per UTC day, streak grows and resets", function()
	local profile = Profile.template()
	H.expect(Daily.claimLogin(profile, NOW))
	H.expect(not Daily.claimLogin(profile, NOW + 60), "same day blocked")
	H.expect(not Daily.claimLogin(profile, NOW - DAY), "clock going backwards blocked")
	H.expect(Daily.claimLogin(profile, NOW + DAY) and profile.daily.streak == 2)
	H.expect(Daily.loginIndex(profile, NOW + DAY) == 2)
	H.expect(Daily.loginIndex(profile, NOW + 2 * DAY) == 3)
	H.expect(Daily.claimLogin(profile, NOW + 5 * DAY) and profile.daily.streak == 1, "missed day resets")
end)

H.test("daily login streak wraps after the last reward", function()
	local profile = Profile.template()
	for d = 0, #GameConfig.DailyLogin do
		H.expect(Daily.claimLogin(profile, NOW + d * DAY))
	end
	H.expect(profile.daily.streak == #GameConfig.DailyLogin + 1)
	H.expect(Daily.loginIndex(profile, NOW + #GameConfig.DailyLogin * DAY) == 1)
end)

H.test("daily boost once per day", function()
	local profile = Profile.template()
	H.expect(Daily.claimBoost(profile, NOW))
	H.expect(not Daily.claimBoost(profile, NOW + 10))
	H.expect(Daily.claimBoost(profile, NOW + DAY))
end)

H.test("playtime rewards need real playtime and reset daily", function()
	local profile = Profile.template()
	H.expect(not Daily.claimPlaytime(profile, 1, NOW))
	Daily.addPlaytime(profile, NOW, 1e9) -- a single huge tick is clamped
	H.expect(profile.daily.playSeconds == 10)
	for _ = 1, 30 do
		Daily.addPlaytime(profile, NOW, 10)
	end
	H.expect(Daily.claimPlaytime(profile, 1, NOW))
	H.expect(not Daily.claimPlaytime(profile, 1, NOW), "once")
	H.expect(not Daily.claimPlaytime(profile, 99, NOW))
	H.expect(not Daily.claimPlaytime(profile, 1.5, NOW))
	H.expect(not Daily.claimPlaytime(profile, 1, NOW + DAY), "new day resets progress")
end)

H.test("daily quests are deterministic per day and progress/claim correctly", function()
	local a, b = Quests.pickDaily(20000), Quests.pickDaily(20000)
	H.expect(#a == QuestConfig.DailyCount and a[1] == b[1] and a[2] == b[2] and a[3] == b[3])
	local seen = {}
	for _, id in a do
		H.expect(not seen[id], "no duplicate quests")
		seen[id] = true
	end
	local profile = Profile.template()
	H.expect(Quests.ensureDaily(profile, NOW))
	H.expect(not Quests.ensureDaily(profile, NOW + 10))
	for index, entry in profile.quests.daily.list do
		H.expect(not Quests.claimDaily(profile, index, NOW), "incomplete")
		entry.progress = entry.target
		H.expect(Quests.claimDaily(profile, index, NOW))
		H.expect(not Quests.claimDaily(profile, index, NOW), "claimed once")
	end
	H.expect(Quests.ensureDaily(profile, NOW + DAY), "new quests next day")
end)

H.test("quest progress respects kind and rarity filter", function()
	local profile = Profile.template()
	Quests.ensureRepeatable(profile)
	Quests.progress(profile, "rolls", 10)
	Quests.progress(profile, "rarityAtLeast", 1, 2) -- too common
	Quests.progress(profile, "rarityAtLeast", 1, 4)
	H.expect(profile.quests.repeatable.r_roll.progress == 10)
	H.expect(profile.quests.repeatable.r_comfy.progress == 1)
	profile.quests.repeatable.r_roll.progress = profile.quests.repeatable.r_roll.target
	local oldTarget = profile.quests.repeatable.r_roll.target
	H.expect(Quests.claimRepeatable(profile, "r_roll", NOW))
	H.expect(profile.quests.repeatable.r_roll.stage == 1 and profile.quests.repeatable.r_roll.target > oldTarget)
	H.expect(not Quests.claimRepeatable(profile, "r_roll", NOW))
end)

H.test("achievements and milestones are granted exactly once", function()
	local profile = Profile.template()
	profile.totalRolls = 100
	local first = Quests.checkAchievements(profile, NOW)
	H.expect(#first == 1 and first[1].achievement.id == "a_first")
	H.expect(#Quests.checkAchievements(profile, NOW) == 0)
	local milestones = Quests.checkMilestones(profile, NOW)
	H.expect(#milestones == 1 and #Quests.checkMilestones(profile, NOW) == 0)
	for _, rarity in Rarities.list do
		profile.discovered[rarity.id] = true
	end
	local earned = Quests.checkAchievements(profile, NOW)
	local ids = {}
	for _, e in earned do
		ids[e.achievement.id] = true
	end
	H.expect(ids.a_colall and ids.a_col5 and ids.a_col8)
end)

H.test("trade: sanitize rejects forged or excessive offers", function()
	local p = Profile.template()
	p.inventory.Rich = 2
	H.expect(Trade.sanitizeOffer(p, { Rich = 2 }) ~= nil)
	H.expect(Trade.sanitizeOffer(p, { Rich = 3 }) == nil, "more than owned")
	H.expect(Trade.sanitizeOffer(p, { Rich = -1 }) == nil, "negative")
	H.expect(Trade.sanitizeOffer(p, { Rich = 0.5 }) == nil, "fraction")
	H.expect(Trade.sanitizeOffer(p, { Broke = 1 }) == nil, "not tradeable")
	H.expect(Trade.sanitizeOffer(p, { Fake = 1 }) == nil, "unknown")
	H.expect(Trade.sanitizeOffer(p, { cash = 1 }) == nil, "cash")
	H.expect(Trade.sanitizeOffer(p, "Rich") == nil)
	H.expect(Trade.sanitizeOffer(p, { Rich = 0 / 0 }) == nil, "NaN")
end)

H.test("trade: execute swaps atomically and never duplicates", function()
	local a, b = Profile.template(), Profile.template()
	a.inventory.Rich = 2
	a.equippedAura = "Rich"
	b.inventory.Millionaire = 1
	local offerA = assert(Trade.sanitizeOffer(a, { Rich = 2 }))
	local offerB = assert(Trade.sanitizeOffer(b, { Millionaire = 1 }))
	-- a spends one Rich elsewhere before the trade executes:
	a.inventory.Rich = 1
	H.expect(not Trade.execute(a, offerA, b, offerB), "stale offer rejected")
	H.expect(a.inventory.Rich == 1 and b.inventory.Millionaire == 1 and b.inventory.Rich == nil, "nothing moved")
	a.inventory.Rich = 2
	H.expect(Trade.execute(a, offerA, b, offerB))
	H.expect(a.inventory.Rich == nil and a.inventory.Millionaire == 1)
	H.expect(b.inventory.Rich == 2 and b.inventory.Millionaire == nil)
	H.expect(a.equippedAura == "", "traded-away aura unequipped")
	H.expect(a.stats.trades == 1 and b.stats.trades == 1)
	H.expect(not Trade.execute(a, {}, b, {}), "empty trade")
	H.expect(not Trade.execute(a, offerA, a, offerA), "self trade")
end)

return H.summary()
