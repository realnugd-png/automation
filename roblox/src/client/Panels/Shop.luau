-- Optional Robux purchases. Buttons call the server, which opens the real
-- Roblox purchase prompt; rewards are granted only by the server after
-- Roblox confirms payment. Items without a configured id say so honestly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)

local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

local function item(content: Instance, order: number, name: string, description: string, priceHint: number, configured: boolean, owned: boolean, onBuy: () -> ())
	local row = UI.row(content, 64, order)
	UI.label({ Text = name, Font = T.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -180, 0, 24), Position = UDim2.fromOffset(12, 6), Parent = row })
	UI.label({ Text = description, TextSize = 13, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -180, 0, 30), Position = UDim2.fromOffset(12, 30), Parent = row })
	local text = if owned then "OWNED" elseif configured then `R$ {priceHint}` else "COMING SOON"
	local button = UI.button({
		Text = text,
		TextSize = 15,
		Size = UDim2.fromOffset(150, 42),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Parent = row,
	}, onBuy, if owned then "green" elseif configured then "gold" else "dark")
	UI.setEnabled(button, configured and not owned)
end

return {
	title = "SHOP",
	refresh = function(content: ScrollingFrame)
		local snapshot = State.snapshot
		if not snapshot then
			return
		end
		UI.clear(content)
		UI.label({
			Text = "Everything in the game can be earned for free. These are optional perks — prices shown are set on Roblox.",
			TextSize = 14,
			TextColor3 = T.Muted,
			Size = UDim2.new(1, -10, 0, 36),
			LayoutOrder = 0,
			Parent = content,
		})
		UI.label({ Text = "GAME PASSES (permanent)", Font = T.Title, TextSize = 18, TextColor3 = T.Gold, LayoutOrder = 1, Parent = content })
		for index, pass in Monetization.Passes do
			item(content, 1 + index, pass.name, pass.description, pass.priceHint, pass.id ~= 0, snapshot.passes[pass.key] == true, function()
				State.request("BuyPass", pass.key)
			end)
		end
		UI.label({ Text = "BOOSTS (one-time use)", Font = T.Title, TextSize = 18, TextColor3 = T.Gold, LayoutOrder = 20, Parent = content })
		for index, product in Monetization.Products do
			item(content, 20 + index, product.name, product.description, product.priceHint, product.id ~= 0, false, function()
				State.request("BuyProduct", product.key)
			end)
		end
	end,
}
