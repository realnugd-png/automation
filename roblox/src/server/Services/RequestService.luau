-- Single entry point for client requests: Request(action, ...) -> result.
-- Every handler receives the calling Player (provided by Roblox, never by the
-- client) and raw, untrusted arguments that each handler validates.
-- Each action has its own minimum interval and there is a global budget per
-- player to stop remote spam.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Modules.Remotes)

local GLOBAL_BUDGET = 25 -- requests per second per player

export type Result = { ok: boolean, message: string?, data: any? }
type Handler = (player: Player, ...any) -> Result?

local RequestService = {}

local handlers: { [string]: { fn: Handler, interval: number } } = {}
local lastCall: { [Player]: { [string]: number } } = {}
local budget: { [Player]: { count: number, window: number } } = {}

function RequestService.register(action: string, fn: Handler, minInterval: number?)
	assert(handlers[action] == nil, "Duplicate request handler " .. action)
	handlers[action] = { fn = fn, interval = minInterval or 0.2 }
end

local function onInvoke(player: Player, action: any, ...): Result
	if type(action) ~= "string" then
		return { ok = false, message = "Bad request" }
	end
	local handler = handlers[action]
	if not handler then
		return { ok = false, message = "Unknown action" }
	end

	local now = os.clock()
	local playerBudget = budget[player]
	if not playerBudget or now - playerBudget.window >= 1 then
		playerBudget = { count = 0, window = now }
		budget[player] = playerBudget
	end
	playerBudget.count += 1
	if playerBudget.count > GLOBAL_BUDGET then
		return { ok = false, message = "Slow down!" }
	end

	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	if calls[action] and now - calls[action] < handler.interval then
		return { ok = false, message = "Slow down!" }
	end
	calls[action] = now

	local ok, result = pcall(handler.fn, player, ...)
	if not ok then
		warn(`[RequestService] {action} from {player.Name} errored: {result}`)
		return { ok = false, message = "Something went wrong" }
	end
	return result or { ok = true }
end

function RequestService.init()
	Remotes.func("Request").OnServerInvoke = onInvoke
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
		budget[player] = nil
	end)
end

return RequestService
