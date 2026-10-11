local State = require(script.Parent.Parent.State)
local UI = require(script.Parent.Parent.UI.UI)

local T = UI.Theme

return {
	title = "CODES",
	build = function(content: ScrollingFrame)
		UI.label({ Text = "Enter a code from our social pages for free rewards!", TextSize = 16, TextColor3 = T.Muted, LayoutOrder = 1, Parent = content })
		local box = UI.new("TextBox", {
			Size = UDim2.fromOffset(380, 50),
			BackgroundColor3 = T.Row,
			PlaceholderText = "Type code here",
			PlaceholderColor3 = T.Muted,
			Text = "",
			ClearTextOnFocus = false,
			TextColor3 = T.Text,
			Font = T.Bold,
			TextSize = 22,
			LayoutOrder = 2,
			Parent = content,
		}, { UI.corner(10), UI.stroke(T.Gold, 1.5, 0.3) })
		local function redeem()
			local code = box.Text
			if code:match("^%s*$") then
				State.notify:fire("Type a code first", "warning")
				return
			end
			local result = State.request("RedeemCode", code)
			if result.ok then
				box.Text = ""
			end
		end
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				redeem()
			end
		end)
		UI.button({ Text = "REDEEM", Size = UDim2.fromOffset(220, 48), LayoutOrder = 3, Parent = content }, redeem, "green")
	end,
	refresh = function() end,
}
