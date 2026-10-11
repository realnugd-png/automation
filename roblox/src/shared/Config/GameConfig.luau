--!strict
-- Central tuning values. Everything here is safe for clients to read; secrets
-- (codes) live in ServerScriptService.

export type Reward = {
	cash: number?, -- flat cash
	scaledCash: number?, -- multiplied by the minCash of the player's best rarity (min 50)
	luckBoost: { mult: number, minutes: number }?,
}

export type Zone = {
	id: string,
	name: string,
	description: string,
	cost: number,
	requiredRebirths: number,
	luckBonus: number, -- additive, 0.25 = +25%
	cashMultiplier: number,
	center: Vector3, -- world position of the zone island (also used for anti-cheat zone checks)
	radius: number,
	color: Color3,
}

local GameConfig = {}

GameConfig.GameName = "Become An Millionaire RNG"
GameConfig.DataVersion = 1
GameConfig.DataStoreName = "PlayerData_v1"
GameConfig.LeaderboardStoreName = "RichestLifetime_v1"

GameConfig.Roll = {
	baseCooldown = 1.6, -- seconds
	minCooldown = 0.45,
	latencyTolerance = 0.12, -- server accepts rolls this much earlier than the cooldown
	historySize = 12,
	autoRollUnlockRolls = 750, -- free auto-roll after this many total rolls
}

GameConfig.Rebirth = {
	baseCost = 1_000_000,
	costGrowth = 20,
	cashBonusPer = 0.5, -- +50% cash per rebirth
	luckBonusPer = 0.1, -- +10% luck per rebirth
	maxRebirths = 50,
}

GameConfig.Offline = {
	minSeconds = 300,
	maxSeconds = 8 * 3600,
	-- cash per minute per level = this * minCash of best rarity discovered
	perMinuteFactor = 0.04,
}

GameConfig.Zones = {
	{
		id = "Downtown",
		name = "Downtown Plaza",
		description = "Where every fortune starts.",
		cost = 0,
		requiredRebirths = 0,
		luckBonus = 0,
		cashMultiplier = 1,
		center = Vector3.new(0, 0, 0),
		radius = 0,
		color = Color3.fromRGB(255, 210, 90),
	},
	{
		id = "LuxuryHills",
		name = "Luxury Hills",
		description = "+25% luck, x1.5 cash",
		cost = 75_000,
		requiredRebirths = 0,
		luckBonus = 0.25,
		cashMultiplier = 1.5,
		center = Vector3.new(700, 0, 0),
		radius = 90,
		color = Color3.fromRGB(120, 230, 160),
	},
	{
		id = "CasinoStrip",
		name = "Neon Strip",
		description = "+60% luck, x2.5 cash",
		cost = 5_000_000,
		requiredRebirths = 1,
		luckBonus = 0.6,
		cashMultiplier = 2.5,
		center = Vector3.new(1100, 0, 0),
		radius = 90,
		color = Color3.fromRGB(255, 80, 200),
	},
	{
		id = "FortuneVault",
		name = "Fortune Vault",
		description = "+150% luck, x5 cash",
		cost = 2e9,
		requiredRebirths = 3,
		luckBonus = 1.5,
		cashMultiplier = 5,
		center = Vector3.new(1500, 0, 0),
		radius = 90,
		color = Color3.fromRGB(255, 170, 30),
	},
	{
		id = "CelestialHeights",
		name = "Celestial Heights",
		description = "+300% luck, x12 cash",
		cost = 1e12,
		requiredRebirths = 6,
		luckBonus = 3,
		cashMultiplier = 12,
		center = Vector3.new(1900, 60, 0),
		radius = 90,
		color = Color3.fromRGB(150, 200, 255),
	},
} :: { Zone }

GameConfig.ZoneById = {} :: { [string]: Zone }
for _, zone in GameConfig.Zones do
	GameConfig.ZoneById[zone.id] = zone
end

-- 7-day streak, repeats after day 7.
GameConfig.DailyLogin = {
	{ scaledCash = 20 },
	{ scaledCash = 40 },
	{ luckBoost = { mult = 2, minutes = 10 } },
	{ scaledCash = 80 },
	{ scaledCash = 120 },
	{ luckBoost = { mult = 2, minutes = 30 } },
	{ scaledCash = 300, luckBoost = { mult = 3, minutes = 15 } },
} :: { Reward }

GameConfig.DailyLuckBoost = { mult = 2, minutes = 15 }

-- Counted per UTC day, so rejoining never restarts the timer.
GameConfig.PlaytimeRewards = {
	{ minutes = 5, reward = { scaledCash = 10 } :: Reward },
	{ minutes = 15, reward = { luckBoost = { mult = 1.5, minutes = 10 } } :: Reward },
	{ minutes = 30, reward = { scaledCash = 60 } :: Reward },
	{ minutes = 60, reward = { luckBoost = { mult = 2, minutes = 20 } } :: Reward },
	{ minutes = 120, reward = { scaledCash = 250 } :: Reward },
}

-- Auto-granted when total rolls reaches the threshold.
GameConfig.RollMilestones = {
	{ rolls = 100, reward = { cash = 2_500 } :: Reward },
	{ rolls = 500, reward = { scaledCash = 50, luckBoost = { mult = 1.5, minutes = 10 } } :: Reward },
	{ rolls = 1_000, reward = { scaledCash = 100 } :: Reward },
	{ rolls = 5_000, reward = { scaledCash = 300, luckBoost = { mult = 2, minutes = 20 } } :: Reward },
	{ rolls = 10_000, reward = { scaledCash = 600 } :: Reward },
	{ rolls = 50_000, reward = { scaledCash = 2_000, luckBoost = { mult = 3, minutes = 30 } } :: Reward },
	{ rolls = 100_000, reward = { scaledCash = 5_000 } :: Reward },
}

-- Limited-time events. Times are UTC unix seconds. `weekendLuck` runs every
-- Saturday and Sunday automatically.
GameConfig.Events = {
	{
		id = "LaunchWeek",
		name = "Launch Week: 2x Luck",
		luckMultiplier = 2,
		startsAt = 1798761600, -- 2027-01-01 00:00 UTC (edit to your launch date)
		endsAt = 1798761600 + 7 * 86400,
	},
}
GameConfig.WeekendEvent = { name = "Weekend Fortune: 1.5x Luck", luckMultiplier = 1.5 }

GameConfig.WealthTitles = {
	{ lifetime = 0, title = "Broke Beginner" },
	{ lifetime = 1_000, title = "Penny Pincher" },
	{ lifetime = 50_000, title = "Side Hustler" },
	{ lifetime = 1_000_000, title = "Millionaire" },
	{ lifetime = 100_000_000, title = "Tycoon" },
	{ lifetime = 1e10, title = "Billionaire Mogul" },
	{ lifetime = 1e13, title = "Trillionaire Titan" },
	{ lifetime = 1e16, title = "Celestial Heir" },
}

GameConfig.Trade = {
	maxKindsPerOffer = 8,
	requestCooldown = 5,
	inviteTimeout = 30,
}

GameConfig.Leaderboard = {
	globalRefreshSeconds = 120,
	globalSize = 50,
}

return GameConfig
