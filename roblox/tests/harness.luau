-- Minimal Roblox-style module loader for Lune so shared modules that use
-- `require(script.Parent.X)` can be unit tested outside Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

Harness.game = {
	GetService = function(_, name)
		return {
			WaitForChild = function(_, child)
				if name == "ReplicatedStorage" and child == "Shared" then
					return Harness.proxy("src/shared")
				end
				error("harness: unsupported " .. name .. "." .. child)
			end,
		}
	end,
}

local cache: { [string]: any } = {}

-- Extra globals (game, workspace, Instance, Enum...) for runtime tests.
Harness.globals = { game = Harness.game } :: { [string]: any }

function Harness.reset()
	table.clear(cache)
end

-- Pre-seeds a module so `require` returns a fake instead of the real file.
function Harness.preload(path: string, value: any)
	cache[path] = value
end

local makeProxy

local function resolveFile(path: string): string?
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	elseif fs.isDir(path) then
		for _, name in { "/init.luau", "/init.client.luau", "/init.server.luau" } do
			if fs.isFile(path .. name) then
				return path .. name
			end
		end
	end
	return nil
end

local function load(path: string)
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = resolveFile(path)
	assert(file, "Cannot require " .. path)
	local source = fs.readFile(file)
	local isInit = file:sub(-10) == "init.luau"
	local scriptProxy = makeProxy(path, isInit)
	local env = setmetatable({
		script = scriptProxy,
		require = function(target)
			if type(target) == "table" and rawget(target, "__path") then
				return load(rawget(target, "__path"))
			end
			return require(target)
		end,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
	}, { __index = _G })
	for key, value in Harness.globals do
		env[key] = value
	end
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

function makeProxy(path: string, isInit: boolean?)
	return setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, name)
					return makeProxy(path .. "/" .. name)
				end
			end
			if key == "Parent" then
				-- For an init module the "script" is the folder itself.
				local parent = path:match("^(.*)/[^/]+$")
				return makeProxy(parent)
			end
			return makeProxy(path .. "/" .. key)
		end,
	})
end

function Harness.proxy(path: string)
	return makeProxy(path)
end

function Harness.require(path: string)
	return load(path)
end

local passed, failed = 0, 0

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  PASS  " .. name)
	else
		failed += 1
		print("  FAIL  " .. name .. "\n        " .. tostring(err))
	end
end

function Harness.expect(condition: any, message: string?)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

function Harness.near(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(string.format("%s: expected %.6g ± %.3g, got %.6g", label or "value", expected, tolerance, actual), 2)
	end
end

function Harness.summary(): boolean
	print(string.format("\n%d passed, %d failed", passed, failed))
	return failed == 0
end

return Harness
