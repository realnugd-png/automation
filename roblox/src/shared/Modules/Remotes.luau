--!strict
-- Single place that defines every remote. The server creates them on start,
-- clients wait for them.
--
-- Client -> server:
--   Request (RemoteFunction): Request(action: string, payload: any) -> { ok, message?, data? }
-- Server -> client (RemoteEvents):
--   State        full player snapshot after any change
--   RollResult   result of a roll (manual or auto)
--   Notify       toast { text, kind }
--   Announce     server-wide rare roll / boost announcement
--   Trade        trade session updates
--   Leaderboard  global + server leaderboard data

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = { "State", "RollResult", "Notify", "Announce", "Trade", "Leaderboard" }
local FUNCTIONS = { "Request" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
