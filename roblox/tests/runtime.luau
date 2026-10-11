-- A small Roblox runtime for Lune: real Instances (Lune validates every
-- property name and value type against the Roblox API dump) plus stubs for
-- engine features Lune doesn't provide (events, tweens, remotes, services).

local roblox = require("@lune/roblox")
local task = require("@lune/task")
local H = require("./harness")

local Runtime = {}

-- Signal stub that records listeners so tests can fire events.
local function newSignal()
	local signal = { listeners = {} }
	function signal:Connect(fn)
		table.insert(self.listeners, fn)
		return {
			Disconnect = function() end,
			Connected = true,
		}
	end
	function signal:Once(fn)
		return self:Connect(fn)
	end
	function signal:Fire(...)
		for _, fn in table.clone(self.listeners) do
			fn(...)
		end
	end
	function signal:Wait() end
	return signal
end
Runtime.newSignal = newSignal

-- Instance events Lune doesn't implement.
-- Lune hands out a fresh userdata per access, so key signals by an id attribute.
local signals: { [number]: { [string]: any } } = {}
local nextId = 0
local function idOf(instance): number
	local id = instance:GetAttribute("__testSignalId")
	if not id then
		nextId += 1
		id = nextId
		instance:SetAttribute("__testSignalId", id)
	end
	return id
end
local function eventProperty(className: string, eventName: string)
	roblox.implementProperty(className, eventName, function(instance)
		local id = idOf(instance)
		signals[id] = signals[id] or {}
		local existing = signals[id][eventName]
		if not existing then
			existing = newSignal()
			signals[id][eventName] = existing
		end
		return existing
	end)
end
Runtime.signalOf = function(instance, eventName)
	return (signals[idOf(instance)] or {})[eventName]
end

-- Must be called from the main script: Lune deadlocks if the roblox
-- implement* APIs run while a module is being required.
local installed = false
function Runtime.install()
	if installed then
		return
	end
	installed = true
	local PART_CLASSES = { "Part", "WedgePart", "SpawnLocation", "MeshPart", "TrussPart" }
	for _, class in PART_CLASSES do
		eventProperty(class, "Touched")
	end
	for _, class in { "TextButton", "ImageButton" } do
		for _, event in { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseEnter", "MouseLeave" } do
			eventProperty(class, event)
		end
	end
	eventProperty("TextBox", "FocusLost")
	eventProperty("NumberValue", "Changed")
	for _, class in { "Camera", "Workspace", "Players", "Player" } do
		roblox.implementMethod(class, "GetPropertyChangedSignal", function()
			return newSignal()
		end)
	end
	for _, event in { "PlayerAdded", "PlayerRemoving" } do
		eventProperty("Players", event)
	end
	roblox.implementMethod("Instance", "WaitForChild", function(self, name)
		return self:FindFirstChild(name)
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return os.time()
	end)
	roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
	roblox.implementProperty("Camera", "ViewportSize", function()
		return roblox.Vector2.new(844, 390) -- phone landscape
	end)
	roblox.implementMethod("Model", "GetExtentsSize", function()
		return roblox.Vector3.new(10, 10, 10)
	end)
end

-- Services that Lune can't provide get stubs.
local function tweenService()
	return {
		Create = function(_, instance, _, goal)
			return {
				Completed = newSignal(),
				Play = function(self)
					-- Apply the goal immediately so final states are validated too.
					for key, value in goal do
						instance[key] = value
					end
					self.Completed:Fire(roblox.Enum.PlaybackState.Completed)
				end,
				Cancel = function() end,
			}
		end,
	}
end

function Runtime.create(options: { isServer: boolean, remotes: any?, stubs: { [string]: any }? })
	local dm = roblox.Instance.new("DataModel")
	local stubs: { [string]: any } = options.stubs or {}
	local defaults: { [string]: any } = {
		TweenService = tweenService(),
		RunService = {
			IsServer = function()
				return options.isServer
			end,
			IsClient = function()
				return not options.isServer
			end,
			IsStudio = function()
				return true
			end,
			Heartbeat = newSignal(),
			RenderStepped = newSignal(),
		},
		ContextActionService = { BindAction = function() end, UnbindAction = function() end },
		ProximityPromptService = { PromptTriggered = newSignal() },
		SoundService = dm:GetService("SoundService"),
		TextChatService = dm:GetService("TextChatService"),
		StarterGui = { SetCoreGuiEnabled = function() end },
		MarketplaceService = {},
	}
	for key, value in defaults do
		if stubs[key] == nil then
			stubs[key] = value
		end
	end
	local replicated = {
		WaitForChild = function(_, child)
			if child == "Shared" then
				return H.proxy("src/shared")
			elseif child == "Remotes" then
				return options.remotes
			end
			error("unknown ReplicatedStorage child " .. child)
		end,
	}
	replicated.FindFirstChild = replicated.WaitForChild
	local game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return replicated
			end
			return stubs[name] or dm:GetService(name)
		end,
		JobId = "test",
	}
	local workspaceInstance = dm:GetService("Workspace")
	local camera = roblox.Instance.new("Camera")
	camera.Name = "Camera"
	camera.Parent = workspaceInstance
	workspaceInstance.CurrentCamera = camera

	H.globals = {
		game = game,
		workspace = workspaceInstance,
		Instance = roblox.Instance,
		task = task,
		TweenInfo = { new = function(...) return { ... } end },
		Enum = roblox.Enum,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Random = { new = function()
			return { NextNumber = function()
				return math.random()
			end }
		end },
	}
	H.reset()
	return {
		dm = dm,
		game = game,
		workspace = workspaceInstance,
	}
end

-- Fake remotes for client tests. Records every Request invocation.
function Runtime.fakeRemotes(handler: ((action: string, ...any) -> any)?)
	local calls = {}
	local remotes = {}
	local function remoteEvent()
		return { OnClientEvent = newSignal(), OnServerEvent = newSignal(), FireServer = function() end }
	end
	local events = {
		State = remoteEvent(),
		RollResult = remoteEvent(),
		Notify = remoteEvent(),
		Announce = remoteEvent(),
		Trade = remoteEvent(),
		Leaderboard = remoteEvent(),
	}
	local request = {
		InvokeServer = function(_, action, ...)
			table.insert(calls, { action = action, args = { ... } })
			if handler then
				return handler(action, ...)
			end
			return { ok = true }
		end,
	}
	remotes.WaitForChild = function(_, name)
		if name == "Request" then
			return request
		end
		return events[name]
	end
	return remotes, events, calls
end

-- Collects all descendants of a class.
function Runtime.descendants(root, className: string)
	local found = {}
	for _, instance in root:GetDescendants() do
		if instance:IsA(className) then
			table.insert(found, instance)
		end
	end
	return found
end

return Runtime
