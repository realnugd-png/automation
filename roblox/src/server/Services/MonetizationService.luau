-- Game passes and developer products.
--
-- * Pass ownership is checked with UserOwnsGamePassAsync on join (with
--   retries) and updated from PromptGamePassPurchaseFinished, which Roblox
--   only fires on the server for real purchases.
-- * Developer products are granted only inside ProcessReceipt. Each
--   PurchaseId is recorded in the player's profile and the profile is saved
--   BEFORE returning PurchaseGranted, so a product is never granted twice and
--   never lost. If anything fails we return NotProcessedYet and Roblox retries.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Remotes = require(Shared.Modules.Remotes)

local Registry = require(script.Parent.Parent.Registry)
local Economy = require(script.Parent.Parent.Logic.Economy)

local MAX_RECEIPTS = 100

local MonetizationService = {}

local passes: { [Player]: { [string]: boolean } } = {}
local serverLuck = { mult = 1, expires = 0 }
local announceRemote = Remotes.event("Announce")

function MonetizationService.getPasses(player: Player): { [string]: boolean }
	return passes[player] or {}
end

function MonetizationService.hasPass(player: Player, key: string): boolean
	local owned = passes[player]
	return owned ~= nil and owned[key] == true
end

function MonetizationService.getServerLuck(): { mult: number, expires: number }
	if serverLuck.expires <= os.time() then
		return { mult = 1, expires = 0 }
	end
	return { mult = serverLuck.mult, expires = serverLuck.expires }
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		Registry.DataService.changed(player)
	end
end

local function setPass(player: Player, key: string)
	passes[player] = passes[player] or {}
	passes[player][key] = true
	player:SetAttribute("Pass_" .. key, true)
	Registry.DataService.changed(player)
	Registry.AvatarService.refresh(player)
end

local function loadPasses(player: Player)
	passes[player] = passes[player] or {}
	for _, pass in Monetization.Passes do
		if pass.id ~= 0 then
			for _ = 1, 3 do
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				if ok then
					if owns then
						setPass(player, pass.key)
					end
					break
				end
				task.wait(1)
			end
		end
	end
end

local function grantProduct(player: Player, profile: { [string]: any }, product: Monetization.Product): string
	local now = os.time()
	local parts = {}
	if product.grant.luckBoost then
		Economy.addBoost(profile, "product", product.grant.luckBoost.mult, product.grant.luckBoost.minutes, now)
		table.insert(parts, `{product.grant.luckBoost.mult}x Luck for {product.grant.luckBoost.minutes} minutes`)
	end
	if product.grant.scaledCash then
		table.insert(parts, Economy.grant(profile, { scaledCash = product.grant.scaledCash }, "product", now))
	end
	if product.grant.serverLuck then
		local boost = product.grant.serverLuck
		local start = math.max(serverLuck.expires, now)
		serverLuck = { mult = math.max(boost.mult, if serverLuck.expires > now then serverLuck.mult else 1), expires = start + boost.minutes * 60 }
		announceRemote:FireAllClients({
			kind = "serverLuck",
			text = `{player.DisplayName} activated {boost.mult}x SERVER LUCK for everyone!`,
		})
		table.insert(parts, "Server luck activated")
		refreshAll()
	end
	return table.concat(parts, " + ")
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Registry.DataService.get(player)
	if not profile or Registry.DataService.isTemporary(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Monetization.ProductById[receipt.ProductId]
	if not product then
		warn(`[Monetization] Unknown product id {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if table.find(profile.receipts, receipt.PurchaseId) == nil then
		local ok, result = pcall(grantProduct, player, profile, product)
		if not ok then
			warn(`[Monetization] Grant failed: {result}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(profile.receipts, receipt.PurchaseId)
		while #profile.receipts > MAX_RECEIPTS do
			table.remove(profile.receipts, 1)
		end
		Registry.DataService.notify(player, `Purchase complete: {result}`, "success")
		Registry.DataService.changed(player)
	end

	if not Registry.DataService.save(player, false) then
		-- Grant stays in memory with its receipt recorded, so a retry can't
		-- double-grant on this server; if the server dies the grant is lost
		-- along with the receipt and Roblox will retry on the next session.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function promptPass(player: Player, key: any)
	if type(key) ~= "string" then
		return { ok = false, message = "Invalid pass" }
	end
	local pass = Monetization.PassByKey[key]
	if not pass then
		return { ok = false, message = "Invalid pass" }
	end
	if pass.id == 0 then
		return { ok = false, message = "This pass isn't available yet" }
	end
	if MonetizationService.hasPass(player, key) then
		return { ok = false, message = "You already own this pass" }
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
	return { ok = true }
end

local function promptProduct(player: Player, key: any)
	if type(key) ~= "string" then
		return { ok = false, message = "Invalid product" }
	end
	local product = Monetization.ProductByKey[key]
	if not product then
		return { ok = false, message = "Invalid product" }
	end
	if product.id == 0 then
		return { ok = false, message = "This product isn't available yet" }
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
	return { ok = true }
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Monetization.PassById[passId]
		if pass then
			setPass(player, pass.key)
			Registry.DataService.notify(player, `Thanks for buying {pass.name}!`, "success")
		end
	end)

	Players.PlayerAdded:Connect(loadPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
	end)

	Registry.RequestService.register("BuyPass", promptPass, 1)
	Registry.RequestService.register("BuyProduct", promptProduct, 1)

	-- Tell everyone when the server luck boost ends.
	task.spawn(function()
		local wasActive = false
		while true do
			task.wait(1)
			local active = serverLuck.expires > os.time()
			if wasActive and not active then
				refreshAll()
			end
			wasActive = active
		end
	end)
end

return MonetizationService
