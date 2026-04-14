-- rebirths v2 

local p = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local rem = rs:WaitForChild("Remotes")
local grs = rem:WaitForChild("GetRebirthState")
local rr = rem:WaitForChild("RequestRebirth")

busy = {}
local lastreb = {}
local COOLDOWN = 3

local cfg = {
	[1] = {
		money = 5e6,
		level = nil,
		brs = {"Tung Tung Tung Sahur","Tralalero Tralala","Ballerina Cappuccina"},
		unlocks = {
			{kind="Unlock", text="Gravity Coil",     icon="rbxassetid://132650611644555"},
			{kind="Slot",   text="+1 Brainrot Slot", icon="rbxassetid://124379522962993"},
			{kind="XP",     text="2x XP",            icon="rbxassetid://120851766834871"},
		},
		multi = {"XP_x2"},
		bonus = 0,
	},
	[2] = {
		money = 1e7,
		level = 5,
		brs = {"Trippi Troppi","Boneca Ambalabu","Chimpanzini Bananini","Capuccino Assassino"},
		unlocks = {
			{kind="Unlock", text="Grapple Hook",     icon="rbxassetid://94074799999195"},
			{kind="Slot",   text="+1 Brainrot Slot", icon="rbxassetid://124379522962993"},
			{kind="Money",  text="2x Money",         icon="rbxassetid://75587499543184"},
		},
		multi = {"Money_x2"},
		bonus = 0,
	},
	[3] = {
		money = 5e7,
		level = 10,
		brs = {"Gangster Footera","Cacto Hipopotamo","Odin din din dun"},
		unlocks = {
			{kind="Unlock", text="Body Swap",         icon="rbxassetid://133574454346071"},
			{kind="Unlock", text="Invisibility Cape", icon="rbxassetid://135912146858108"},
			{kind="Slot",   text="+1 Brainrot Slot",  icon="rbxassetid://124379522962993"},
			{kind="Bonus",  text="+$500k Bonus",      icon="rbxassetid://106164878268674"},
		},
		multi = {},
		bonus = 5e5,
	},
	[4] = {
		money = 15e7,
		level = 15,
		brs = {"Ta Ta Ta Sahur","Frigo Camelo","To To To Sahur","Bombardiro Crocodilo"},
		unlocks = {
			{kind="Unlock", text="Jetpack",     icon="rbxassetid://113554686033472"},
			{kind="XP",     text="2x XP",      icon="rbxassetid://120851766834871"},
			{kind="Money",  text="2x Money",   icon="rbxassetid://75587499543184"},
			{kind="Bonus",  text="+$2M Bonus", icon="rbxassetid://106164878268674"},
		},
		multi = {"Money_x2","XP_x2"},
		bonus = 2e6,
	},
}

local function getbrf(plr)
	local f = plr:FindFirstChild("OwnedBrainrots")
	if not f then
		f = Instance.new("Folder")
		f.Name = "OwnedBrainrots"
		f.Parent = plr
	end
	return f
end

local function hasbr(plr, name)
	local f = plr:FindFirstChild("OwnedBrainrots")
	if not f then
		print(plr.Name.." has no OwnedBrainrots folder??")
		return false
	end
	local b = f:FindFirstChild(name)
	if not b then return false end
	if not b:IsA("BoolValue") then
		print(name.." isnt a BoolValue wtf")
		return false
	end
	return b.Value == true
end

local function getm(plr) return plr:GetAttribute("Money") or 0 end
local function getlv(plr) return plr:GetAttribute("Level") or 1 end
local function getrb(plr) return plr:GetAttribute("Rebirth") or 0 end
local function getsl(plr) return plr:GetAttribute("InventoryMaxSlots") or 10 end

local function setupplr(plr)
	wait(1) -- breaks without this sometimes 
	if plr:GetAttribute("Money") == nil then plr:SetAttribute("Money", 0) end
	if plr:GetAttribute("Level") == nil then plr:SetAttribute("Level", 1) end
	if plr:GetAttribute("Rebirth") == nil then plr:SetAttribute("Rebirth", 0) end
	if plr:GetAttribute("InventoryMaxSlots") == nil then plr:SetAttribute("InventoryMaxSlots", 10) end
	if plr:GetAttribute("TotalRebirths") == nil then plr:SetAttribute("TotalRebirths", 0) end
	getbrf(plr)
	lastreb[plr] = 0
	busy[plr] = false
	print(plr.Name.." setup done")
end

local function oncd(plr)
	local last = lastreb[plr] or 0
	if tick() - last < COOLDOWN then return true end
	return false
end

local function canreb(plr)
	local rb = getrb(plr)
	if rb >= 4 then return false end
	local d = cfg[rb+1]
	if not d then return false end
	local m = getm(plr)
	if m < d.money then return false end
	if m ~= m then return false end 
	if d.level and getlv(plr) < d.level then return false end
	for _,v in pairs(d.brs) do
		if not hasbr(plr,v) then return false end
	end
	return true
end

local function buildstate(plr)
	local rb = getrb(plr)
	if rb >= 4 then
		return {maxed=true, rebirth=rb, money=getm(plr), level=getlv(plr)}
	end
	local d = cfg[rb+1]
	if not d then return {maxed=true, rebirth=rb} end
	local owned = {}
	for _,v in pairs(d.brs) do
		owned[v] = hasbr(plr,v)
	end
	return {
		maxed   = false,
		rebirth = rb,
		next    = rb+1,
		req     = {money=d.money, level=d.level, brs=d.brs},
		owned   = owned,
		unlocks = d.unlocks,
		money   = getm(plr),
		level   = getlv(plr),
		can     = canreb(plr),
	}
end

local function dounlocks(plr, rb)
	local d = cfg[rb]
	if not d then
		print("no cfg for rb "..rb.." ??")
		return
	end
	local slots = getsl(plr)
	local gotbonus = false
	for _,u in pairs(d.unlocks) do
		if u.kind == "Slot" then
			slots += 1
			print(plr.Name.." got +1 slot -> "..slots)
		elseif u.kind == "Bonus" and not gotbonus then
			if d.bonus > 0 then
				local cur = getm(plr)
				plr:SetAttribute("Money", cur + d.bonus)
				print(plr.Name.." got bonus $"..d.bonus.." total: "..(cur+d.bonus))
				gotbonus = true
			end
		elseif u.kind == "Unlock" then
			print(plr.Name.." unlocked: "..u.text)
		elseif u.kind == "XP" then
			print(plr.Name.." got xp boost: "..u.text)
		elseif u.kind == "Money" then
			print(plr.Name.." got money boost: "..u.text)
		end
	end
	plr:SetAttribute("InventoryMaxSlots", slots)
end

local function domulti(plr, rb)
	local d = cfg[rb]
	if not d or #d.multi == 0 then return end
	local gm = rem:FindFirstChild("GiveMultiplier")
	if not gm then
		print("GiveMultiplier not found")
		return
	end
	for _,k in pairs(d.multi) do
		local ok = pcall(function()
			gm:Invoke(plr, k, 1)
		end)
		if ok then
			print(plr.Name.." got multiplier "..k)
		else
			print("multiplier failed for "..k)
		end
	end
end

grs.OnServerInvoke = function(plr)
	return buildstate(plr)
end

rr.OnServerInvoke = function(plr)
	if busy[plr] then
		print(plr.Name.." already in rebirth")
		return false, "busy", buildstate(plr)
	end

	if oncd(plr) then
		print(plr.Name.." on cooldown")
		return false, "cooldown", buildstate(plr)
	end

	if not canreb(plr) then
		local rb = getrb(plr)
		local d = cfg[rb+1]
		if d then
			for _,v in pairs(d.brs) do
				if not hasbr(plr,v) then
					print(plr.Name.." missing: "..v)
				end
			end
			if getm(plr) < d.money then
				print(plr.Name.." broke: "..getm(plr).."/"..d.money)
			end
			if d.level and getlv(plr) < d.level then
				print(plr.Name.." low level: "..getlv(plr).."/"..d.level)
			end
		end
		return false, "reqs", buildstate(plr)
	end

	busy[plr] = true

	local rb = getrb(plr)
	local newrb = rb + 1

	plr:SetAttribute("Rebirth", newrb)
	plr:SetAttribute("Money", 0)
	plr:SetAttribute("TotalRebirths", (plr:GetAttribute("TotalRebirths") or 0) + 1)

	dounlocks(plr, newrb)
	domulti(plr, newrb)

	lastreb[plr] = tick()
	busy[plr] = false

	print(plr.Name.." rebirth "..rb.." -> "..newrb)
	print("slots: "..getsl(plr).." money: "..getm(plr))

	return true, "ok", {
		newrb  = newrb,
		money  = getm(plr),
		slots  = getsl(plr),
	}
end

p.PlayerAdded:Connect(setupplr)

p.PlayerRemoving:Connect(function(plr)
	busy[plr] = nil
	lastreb[plr] = nil
end)

for _,v in pairs(p:GetPlayers()) do
	setupplr(v)
end

print("rebirths loaded")
