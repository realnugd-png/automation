-- Secure player-to-player aura trading.
--
-- Flow: TradeRequest -> (target) TradeRespond -> both TradeSetOffer ->
-- both TradeAccept(version). Any offer change bumps `version` and clears both
-- accepts, so a player can only ever accept exactly what they last saw.
-- Execution re-validates inventories inside Logic/Trade.execute (no yields),
-- then both profiles are saved immediately.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Modules.Remotes)

local Registry = require(script.Parent.Parent.Registry)
local Trade = require(script.Parent.Parent.Logic.Trade)

type Session = {
	a: Player,
	b: Player,
	offers: { [Player]: Trade.Offer },
	accepted: { [Player]: boolean },
	version: number,
	busy: boolean,
}

local TradeService = {}

local tradeRemote = Remotes.event("Trade")
local sessions: { [Player]: Session } = {}
local invites: { [Player]: { from: Player, expires: number } } = {}
local lastRequest: { [Player]: number } = {}

local function partnerOf(session: Session, player: Player): Player
	return if session.a == player then session.b else session.a
end

local function push(session: Session)
	for _, player in { session.a, session.b } do
		local partner = partnerOf(session, player)
		tradeRemote:FireClient(player, {
			type = "update",
			partnerName = partner.DisplayName,
			partnerUserId = partner.UserId,
			myOffer = session.offers[player],
			theirOffer = session.offers[partner],
			myAccepted = session.accepted[player] == true,
			theirAccepted = session.accepted[partner] == true,
			version = session.version,
		})
	end
end

local function close(session: Session, reason: string)
	for _, player in { session.a, session.b } do
		if sessions[player] == session then
			sessions[player] = nil
		end
		if player.Parent then
			tradeRemote:FireClient(player, { type = "closed", reason = reason })
		end
	end
end

local function request(player: Player, targetUserId: any)
	if type(targetUserId) ~= "number" then
		return { ok = false, message = "Invalid player" }
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return { ok = false, message = "Player not found" }
	end
	if not Registry.DataService.get(player) or not Registry.DataService.get(target) then
		return { ok = false, message = "Player is still loading" }
	end
	if sessions[player] or sessions[target] then
		return { ok = false, message = "Already in a trade" }
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < GameConfig.Trade.requestCooldown then
		return { ok = false, message = "Wait before sending another request" }
	end
	lastRequest[player] = now
	invites[target] = { from = player, expires = now + GameConfig.Trade.inviteTimeout }
	tradeRemote:FireClient(target, { type = "invite", fromName = player.DisplayName, fromUserId = player.UserId })
	return { ok = true, message = `Trade request sent to {target.DisplayName}` }
end

local function respond(player: Player, fromUserId: any, accept: any)
	local invite = invites[player]
	if not invite or type(fromUserId) ~= "number" or invite.from.UserId ~= fromUserId then
		return { ok = false, message = "No such trade request" }
	end
	invites[player] = nil
	local from = invite.from
	if accept ~= true then
		if from.Parent then
			Registry.DataService.notify(from, `{player.DisplayName} declined your trade`, "warning")
		end
		return { ok = true }
	end
	if os.clock() > invite.expires or from.Parent == nil then
		return { ok = false, message = "Trade request expired" }
	end
	if sessions[player] or sessions[from] then
		return { ok = false, message = "Already in a trade" }
	end
	local session: Session = {
		a = from,
		b = player,
		offers = { [from] = {}, [player] = {} },
		accepted = {},
		version = 1,
		busy = false,
	}
	sessions[from] = session
	sessions[player] = session
	push(session)
	return { ok = true }
end

local function setOffer(player: Player, rawOffer: any)
	local session = sessions[player]
	local profile = Registry.DataService.get(player)
	if not session or not profile or session.busy then
		return { ok = false, message = "Not in a trade" }
	end
	local offer, err = Trade.sanitizeOffer(profile, rawOffer)
	if not offer then
		return { ok = false, message = err }
	end
	session.offers[player] = offer
	session.accepted = {}
	session.version += 1
	push(session)
	return { ok = true }
end

local function accept(player: Player, version: any)
	local session = sessions[player]
	if not session or session.busy then
		return { ok = false, message = "Not in a trade" }
	end
	if version ~= session.version then
		return { ok = false, message = "The offer changed — review it again" }
	end
	session.accepted[player] = true
	local partner = partnerOf(session, player)
	if not session.accepted[partner] then
		push(session)
		return { ok = true }
	end

	session.busy = true
	local profileA = Registry.DataService.get(session.a)
	local profileB = Registry.DataService.get(session.b)
	if not profileA or not profileB then
		close(session, "Trade failed: a player left")
		return { ok = false, message = "Trade failed" }
	end
	local ok, message = Trade.execute(profileA, session.offers[session.a], profileB, session.offers[session.b])
	close(session, message)
	if ok then
		for _, participant in { session.a, session.b } do
			Registry.RewardService.checkProgress(participant, Registry.DataService.get(participant), os.time())
			Registry.DataService.changed(participant)
			Registry.AvatarService.refresh(participant)
			task.spawn(Registry.DataService.save, participant, false)
		end
	end
	return { ok = ok, message = message }
end

local function cancel(player: Player)
	local session = sessions[player]
	if session and not session.busy then
		close(session, `{player.DisplayName} cancelled the trade`)
	end
	return { ok = true }
end

function TradeService.init()
	local Request = Registry.RequestService
	Request.register("TradeRequest", request, 1)
	Request.register("TradeRespond", respond, 0.5)
	Request.register("TradeSetOffer", setOffer, 0.2)
	Request.register("TradeAccept", accept, 0.3)
	Request.register("TradeCancel", cancel, 0.3)

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			session.busy = false
			close(session, "Trade cancelled: player left")
		end
		invites[player] = nil
		lastRequest[player] = nil
		for target, invite in invites do
			if invite.from == player then
				invites[target] = nil
			end
		end
	end)
end

return TradeService
