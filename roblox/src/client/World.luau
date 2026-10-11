-- World interactions on the client: proximity prompts open menus, other
-- players' auras can be hidden, and VIP players get a chat tag.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextChatService = game:GetService("TextChatService")

local State = require(script.Parent.State)
local Panels = require(script.Parent.UI.Panels)

local World = {}

local function applyAuraVisibility()
	local profile = State.profile()
	local hide = profile ~= nil and profile.settings.hideOtherAuras == true
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			local aura = root and root:FindFirstChild("WealthAura")
			if aura then
				for _, child in aura:GetChildren() do
					if child:IsA("ParticleEmitter") or child:IsA("PointLight") then
						child.Enabled = not hide
					end
				end
			end
		end
	end
end

function World.init()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("OpenPanel")
		if type(panel) == "string" then
			Panels.open(panel)
		end
	end)

	State.changed:connect(applyAuraVisibility)
	task.spawn(function()
		while true do
			task.wait(3) -- catches auras rebuilt on respawn/equip
			applyAuraVisibility()
		end
	end)

	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local player = Players:GetPlayerByUserId(source.UserId)
			if player and player:GetAttribute("Pass_VIP") then
				properties.PrefixText = `<font color="#FFC846">[VIP]</font> ` .. message.PrefixText
			end
		end
		return properties
	end
end

return World
