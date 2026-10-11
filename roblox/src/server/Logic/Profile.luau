--!strict
-- Versioned player-data schema.
--
-- Adding a field: add it to `template()` with a default. `reconcile` fills it
-- in for existing players automatically, without touching their other data.
-- Changing the meaning/shape of a field: bump GameConfig.DataVersion and add a
-- step to MIGRATIONS that converts version n-1 data to version n.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Profile = {}

function Profile.template(): { [string]: any }
	return {
		version = GameConfig.DataVersion,
		cash = 0,
		lifetime = 0,
		totalRolls = 0,
		bestOrder = 0,
		bestCash = 0,
		rebirths = 0,
		upgrades = { Luck = 0, Cash = 0, Speed = 0, Capacity = 0, Offline = 0 },
		inventory = {}, -- [rarityId] = count of collected auras
		discovered = {}, -- [rarityId] = true
		rarityCounts = {}, -- [rarityId] = times rolled
		equippedAura = "",
		zones = { Downtown = true },
		history = {}, -- recent { id, cash }
		quests = {
			daily = { day = 0, list = {} },
			repeatable = {}, -- [questId] = { stage, progress }
		},
		achievements = {}, -- [id] = true
		milestones = {}, -- [tostring(rolls)] = true
		daily = {
			lastLoginDay = 0,
			streak = 0,
			boostDay = 0,
			playDay = 0,
			playSeconds = 0,
			playClaimed = {}, -- [tostring(index)] = true
		},
		boosts = {}, -- [source] = { mult, expires }
		settings = {
			effects = true,
			shake = true,
			sounds = true,
			hideOtherAuras = false,
			autoRollSkipReveal = false,
		},
		codes = {}, -- [CODE] = true
		receipts = {}, -- recent developer product PurchaseIds (newest last)
		stats = { upgradesBought = 0, trades = 0, playSeconds = 0 },
		lastOnline = 0,
		createdAt = 0,
	}
end

-- version n-1 -> n. Example for a future v2:
-- [2] = function(data) data.newField = data.oldField; data.oldField = nil end,
local MIGRATIONS: { [number]: (data: { [string]: any }) -> () } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end
Profile.deepCopy = deepCopy

-- Adds any missing keys from the template, recursively, but only into tables
-- whose template value is a "record" (non-empty). Map-style tables that are
-- empty in the template (inventory, codes...) are left as the player has them.
local function reconcile(target: { [string]: any }, template: { [string]: any })
	for key, default in template do
		local current = target[key]
		if current == nil or type(current) ~= type(default) then
			target[key] = deepCopy(default)
		elseif type(default) == "table" and next(default) ~= nil then
			reconcile(current, default)
		end
	end
end

-- Returns a profile that is safe to use. Never discards existing values.
function Profile.migrate(data: { [string]: any }?): { [string]: any }
	if data == nil then
		return Profile.template()
	end
	local version = tonumber(data.version) or 1
	if version > GameConfig.DataVersion then
		-- Data written by a newer server version. Refuse rather than downgrade.
		error(`Profile version {version} is newer than this server ({GameConfig.DataVersion})`)
	end
	while version < GameConfig.DataVersion do
		version += 1
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
	end
	data.version = GameConfig.DataVersion
	reconcile(data, Profile.template())
	return data
end

-- What the client is allowed to see about its own profile.
function Profile.snapshot(profile: { [string]: any }): { [string]: any }
	local copy = deepCopy(profile)
	copy.receipts = nil
	copy.codes = nil
	return copy
end

return Profile
