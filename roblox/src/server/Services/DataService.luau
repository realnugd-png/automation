-- Persistent player data with session locking.
--
-- Record layout in the DataStore (key "u_<UserId>"):
--   { data = <profile>, lock = { job = JobId, time = os.time() }? }
--
-- Guarantees:
--  * A failed load never produces a default profile that could overwrite real
--    data: the player is kicked with a message instead (except in Studio when
--    API access is disabled, where a temporary, never-saved profile is used).
--  * Only the server holding the session lock may write. A save that finds
--    the lock owned by another server is aborted and the player is kicked.
--  * Saves are serialised per player, retried with backoff, and flushed on
--    PlayerRemoving and BindToClose.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Modules.Remotes)
local Formulas = require(Shared.Modules.Formulas)

local Registry = require(script.Parent.Parent.Registry)
local Profile = require(script.Parent.Parent.Logic.Profile)
local Daily = require(script.Parent.Parent.Logic.Daily)


type PlayerState = {
	saving: boolean,
	temporary: boolean, -- Studio without API access: never saved
	dirty: boolean,
	pushQueued: boolean,
}

local DataService = {}

-- Timings (seconds). Exposed so tests can shorten them.
DataService.config = {
	lockStaleSeconds = 600, -- a lock older than this is considered abandoned
	autosaveSeconds = 90,
	loadAttempts = 6,
	lockedRetryDelay = 5,
	errorRetryDelay = 2, -- multiplied by the attempt number
	saveRetryDelay = 2, -- raised to the attempt number
}

local store: DataStore? = nil
local profiles: { [Player]: { [string]: any } } = {}
local states: { [Player]: PlayerState } = {}
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}
local stateRemote = Remotes.event("State")
local notifyRemote = Remotes.event("Notify")

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
		return result
	end
	return nil
end

-- Returns ("ok", data) | ("locked", nil) | ("error", message)
local function tryLoad(player: Player): (string, any)
	local dataStore = getStore()
	if not dataStore then
		return "error", "DataStore unavailable"
	end
	local lockedBy: string? = nil
	local loaded: any = nil
	local ok, err = pcall(function()
		dataStore:UpdateAsync(key(player), function(old)
			lockedBy = nil
			if type(old) == "table" and type(old.lock) == "table" then
				local lock = old.lock
				if lock.job ~= jobId() and os.time() - (tonumber(lock.time) or 0) < DataService.config.lockStaleSeconds then
					lockedBy = tostring(lock.job)
					return nil -- abort: another server owns this session
				end
			end
			local record = if type(old) == "table" then old else {}
			loaded = record.data
			record.lock = { job = jobId(), time = os.time() }
			return record
		end)
	end)
	if not ok then
		return "error", tostring(err)
	end
	if lockedBy then
		return "locked", nil
	end
	return "ok", loaded
end

local function isStudioApiError(message: string): boolean
	return RunService:IsStudio()
		and (message:find("403") ~= nil or message:find("API") ~= nil or message:find("unavailable") ~= nil or message:find("Studio") ~= nil)
end

function DataService.get(player: Player): { [string]: any }?
	return profiles[player]
end

function DataService.isTemporary(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.temporary
end

function DataService.onLoaded(callback: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

function DataService.notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, { text = text, kind = kind or "info" })
end

-- Sends the client a fresh snapshot (debounced to once per frame).
function DataService.changed(player: Player)
	local state = states[player]
	if not state or state.pushQueued then
		return
	end
	state.dirty = true
	state.pushQueued = true
	task.defer(function()
		state.pushQueued = false
		local profile = profiles[player]
		if not profile or player.Parent == nil then
			return
		end
		local now = os.time()
		local stats = Registry.StatsService.compute(player)
		stateRemote:FireClient(player, {
			profile = Profile.snapshot(profile),
			stats = stats,
			passes = Registry.MonetizationService.getPasses(player),
			serverLuck = Registry.MonetizationService.getServerLuck(),
			serverTime = now,
			loginIndex = Daily.loginIndex(profile, now),
			canClaimLogin = Daily.canClaimLogin(profile, now),
			canClaimBoost = profile.daily.boostDay < Formulas.dayNumber(now),
			autoRoll = Registry.RollService.isAutoRolling(player),
			temporary = state.temporary,
		})
	end)
end

function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	local state = states[player]
	if not profile or not state then
		return false
	end
	if state.temporary then
		return true
	end
	while state.saving do
		task.wait(0.1)
	end
	state.saving = true
	profile.lastOnline = os.time()
	local copy = Profile.deepCopy(profile)
	local success = false
	local lostLock = false
	local dataStore = getStore()
	for attempt = 1, 4 do
		if not dataStore then
			break
		end
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key(player), function(old)
				if type(old) == "table" and type(old.lock) == "table" and old.lock.job ~= jobId() then
					lostLock = true
					return nil
				end
				return {
					data = copy,
					lock = if release then nil else { job = jobId(), time = os.time() },
				}
			end)
		end)
		if ok then
			success = not lostLock
			break
		end
		warn(`[DataService] Save attempt {attempt} for {player.Name} failed: {err}`)
		task.wait(DataService.config.saveRetryDelay ^ attempt)
	end
	state.saving = false
	if success then
		state.dirty = false
	end
	if lostLock and player.Parent then
		player:Kick("Your data was opened on another server. Please rejoin.")
	end
	return success
end

local function onPlayerAdded(player: Player)
	local data: any = nil
	local temporary = false
	local status, result = "error", "not attempted"

	for attempt = 1, DataService.config.loadAttempts do
		status, result = tryLoad(player)
		if status == "ok" then
			data = result
			break
		end
		if status == "error" and isStudioApiError(result) then
			break
		end
		if player.Parent == nil then
			return
		end
		task.wait(if status == "locked" then DataService.config.lockedRetryDelay else attempt * DataService.config.errorRetryDelay)
	end

	if status ~= "ok" then
		if status == "error" and isStudioApiError(result) then
			warn("[DataService] Studio has no DataStore access (enable 'Studio Access to API Services'). Using a temporary profile that will NOT be saved.")
			temporary = true
		else
			warn(`[DataService] Could not load data for {player.Name}: {status} {result}`)
			if player.Parent then
				player:Kick(if status == "locked"
					then "Your data is still saving on another server. Please rejoin in a minute."
					else "We couldn't load your data (Roblox DataStores may be down). Your progress is safe — please rejoin shortly.")
			end
			return
		end
	end

	if player.Parent == nil then
		-- Left while loading: write back exactly what we loaded and release the lock.
		if not temporary then
			profiles[player] = Profile.migrate(data)
			states[player] = { saving = false, temporary = false, dirty = false, pushQueued = false }
			DataService.save(player, true)
			profiles[player] = nil
			states[player] = nil
		end
		return
	end

	local ok, profileOrErr = pcall(Profile.migrate, data)
	if not ok then
		warn(`[DataService] Migration failed for {player.Name}: {profileOrErr}`)
		player:Kick("Your data is from a newer game version. Please join a newer server.")
		return
	end
	local profile = profileOrErr
	if profile.createdAt == 0 then
		profile.createdAt = os.time()
	end
	profiles[player] = profile
	states[player] = { saving = false, temporary = temporary, dirty = false, pushQueued = false }
	player:SetAttribute("DataLoaded", true)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	DataService.changed(player)
	if temporary then
		DataService.notify(player, "Studio test mode: progress will not be saved.", "warning")
	end
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		DataService.save(player, true)
	end
	profiles[player] = nil
	states[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(DataService.config.autosaveSeconds)
			for player in profiles do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
