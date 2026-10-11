-- Client-side mirror of the server state. Read-only: every change goes
-- through State.request, and the server answers with a new snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Modules.Remotes)

export type Snapshot = {
	profile: { [string]: any },
	stats: { [string]: any },
	passes: { [string]: boolean },
	serverLuck: { mult: number, expires: number },
	serverTime: number,
	loginIndex: number,
	canClaimLogin: boolean,
	canClaimBoost: boolean,
	autoRoll: boolean,
	temporary: boolean,
}

local State = {}

State.snapshot = nil :: Snapshot?
State.leaderboard = { server = {}, global = {} }
State.receivedAt = 0

-- Tiny signal implementation
local function signal()
	local listeners: { (...any) -> () } = {}
	return {
		connect = function(_, fn: (...any) -> ())
			table.insert(listeners, fn)
			return function()
				local index = table.find(listeners, fn)
				if index then
					table.remove(listeners, index)
				end
			end
		end,
		fire = function(_, ...)
			for _, fn in table.clone(listeners) do
				task.spawn(fn, ...)
			end
		end,
	}
end

State.changed = signal()
State.rollResult = signal()
State.leaderboardChanged = signal()
State.tradeEvent = signal()
State.notify = signal() -- (text, kind)
State.announce = signal() -- (payload)

local requestRemote = Remotes.func("Request")

function State.now(): number
	return workspace:GetServerTimeNow()
end

function State.profile(): { [string]: any }?
	return State.snapshot and State.snapshot.profile
end

-- Sends a request; shows the server's message as a toast unless `silent`.
function State.request(action: string, ...: any): { ok: boolean, message: string?, data: any? }
	local ok, result = pcall(requestRemote.InvokeServer, requestRemote, action, ...)
	if not ok or type(result) ~= "table" then
		State.notify:fire("Connection problem, try again", "error")
		return { ok = false }
	end
	if result.message then
		State.notify:fire(result.message, if result.ok then "success" else "error")
	end
	return result
end

function State.init()
	Remotes.event("State").OnClientEvent:Connect(function(snapshot)
		State.snapshot = snapshot
		State.receivedAt = State.now()
		State.changed:fire(snapshot)
	end)
	Remotes.event("RollResult").OnClientEvent:Connect(function(result)
		State.rollResult:fire(result)
	end)
	Remotes.event("Notify").OnClientEvent:Connect(function(payload)
		State.notify:fire(payload.text, payload.kind)
	end)
	Remotes.event("Announce").OnClientEvent:Connect(function(payload)
		State.announce:fire(payload)
	end)
	Remotes.event("Trade").OnClientEvent:Connect(function(payload)
		State.tradeEvent:fire(payload)
	end)
	Remotes.event("Leaderboard").OnClientEvent:Connect(function(payload)
		State.leaderboard = payload
		State.leaderboardChanged:fire(payload)
	end)
end

return State
