-- REBIRTH SYSTEM - Maatzzs
-- v2 final (dont touch remotes or the gui breaks)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DS = game:GetService("DataStoreService")

local rbStore = DS:GetDataStore("PlayerRebirths_FINAL")

local rems = RS:FindFirstChild("Remotes")
local getState = rems:WaitForChild("GetRebirthState")
local doRebirth = rems:WaitForChild("RequestRebirth")

local active_db = {}
local cd_table = {}
local COOLDOWN = 5

local TIERS = {
	[1] = {
		price = 5000000,
		level = 1,
		items = {"Tung Tung Tung Sahur", "Tralalero Tralala", "Ballerina Cappuccina"},
		slots = 1,
		bonus = 0,
		id = "132650611644555",
		mults = {{"XP_x2", 1}}
	},
	[2] = {
		price = 10000000,
		level = 5,
		items = {"Trippi Troppi", "Boneca Ambalabu", "Chimpanzini Bananini", "Capuccino Assassino"},
		slots = 1,
		bonus = 0,
		id = "94074799999195",
		mults = {{"Money_x2", 1}}
	},
	[3] = {
		price = 50000000,
		level = 10,
		items = {"Gangster Footera", "Cacto Hipopotamo", "Odin din din dun"},
		slots = 1,
		bonus = 500000,
		id = "133574454346071"
	},
	[4] = {
		price = 150000000,
		level = 15,
		items = {"Ta Ta Ta Sahur", "Frigo Camelo", "To To To Sahur", "Bombardiro Crocodilo"},
		slots = 0,
		bonus = 2000000,
		id = "113554686033472",
		mults = {{"Money_x2", 1}, {"XP_x2", 1}}
	},
	[5] = {
		price = 500000000,
		level = 25,
		items = {"Mega Sahur", "Super Frigo", "Ultra Bombardiro"},
		slots = 2,
		bonus = 5000000,
		id = "142650611644001"
	},
	[6] = {
		price = 1000000000,
		level = 40,
		items = {"Giga Brainrot", "Final Sahur"},
		slots = 0,
		bonus = 10000000,
		id = "133574454346006"
	},
	[7] = {
		price = 5000000000,
		level = 60,
		items = {"Mythic Sahur", "Eternal Frigo"},
		slots = 2,
		bonus = 25000000,
		id = "124379522962993"
	},
	[8] = {
		price = 25000000000,
		level = 80,
		items = {"Void Sahur", "Cosmic Frigo"},
		slots = 0,
		bonus = 100000000,
		id = "113554686033008"
	},
	[9] = {
		price = 100000000000,
		level = 100,
		items = {"Divine Sahur", "Omega Frigo"},
		slots = 5,
		bonus = 500000000,
		id = "135912146858009"
	},
	[10] = {
		price = 1000000000000,
		level = 150,
		items = {"Absolute Sahur"},
		slots = 0,
		bonus = 1000000000,
		id = "152650611644010"
	}
}

local function getInv(p)
	local f = p:FindFirstChild("OwnedBrainrots")
	if not f then
		print(p.Name.." missing OwnedBrainrots, creating")
		f = Instance.new("Folder", p)
		f.Name = "OwnedBrainrots"
	end
	return f
end

local function hasItem(p, name)
	local inv = getInv(p)
	local v = inv:FindFirstChild(name)
	if not v then return false end
	if not v:IsA("BoolValue") then
		print(name.." wrong type: "..v.ClassName)
		return false
	end
	return v.Value == true
end

local function onCooldown(p)
	local last = cd_table[p]
	if not last then return false end
	return tick() - last < COOLDOWN
end

local function saveData(p)
	if not p or not p.Parent then return end
	local data = {
		rb    = p:GetAttribute("Rebirth") or 0,
		slots = p:GetAttribute("InventoryMaxSlots") or 10
	}
	local ok, err = pcall(function()
		rbStore:SetAsync(tostring(p.UserId), data)
	end)
	if not ok then
		print("save failed for "..p.Name..": "..tostring(err))
	end
end

local function setupPlr(p)
	local ok, saved = pcall(function() return rbStore:GetAsync(tostring(p.UserId)) end)

	p:SetAttribute("Rebirth", (ok and saved and saved.rb) or 0)
	p:SetAttribute("InventoryMaxSlots", (ok and saved and saved.slots) or 10)

	if not p:GetAttribute("Money") then p:SetAttribute("Money", 0) end
	if not p:GetAttribute("Level") then p:SetAttribute("Level", 1) end
	if not p:GetAttribute("TotalRebirths") then p:SetAttribute("TotalRebirths", 0) end

	getInv(p)
	cd_table[p] = 0
	print(p.Name.." loaded rb="..tostring(p:GetAttribute("Rebirth")))
end

getState.OnServerInvoke = function(p)
	local cur = p:GetAttribute("Rebirth") or 0
	local nxt = cur + 1
	local data = TIERS[nxt]

	if not data then return {maxed = true, rebirth = cur} end

	local money = p:GetAttribute("Money") or 0
	local lvl   = p:GetAttribute("Level") or 1
	local owned = {}
	local can   = true

	for _, name in pairs(data.items) do
		local has = hasItem(p, name)
		owned[name] = has
		if not has then can = false end
	end

	if money < data.price then can = false end
	if lvl < data.level then can = false end

	return {
		maxed      = false,
		rebirth    = cur,
		cost       = data.price,
		reqLvl     = data.level,
		reqItems   = data.items,
		ownedItems = owned,
		canRb      = can,
		money      = money,
		level      = lvl,
	}
end

doRebirth.OnServerInvoke = function(p)
	if active_db[p] then
		print(p.Name.." already busy")
		return false, "busy"
	end

	if onCooldown(p) then
		print(p.Name.." on cooldown")
		return false, "cooldown"
	end

	local rb   = p:GetAttribute("Rebirth") or 0
	local nxt  = rb + 1
	local data = TIERS[nxt]

	if not data then return false, "max" end

	local money = p:GetAttribute("Money") or 0
	local lvl   = p:GetAttribute("Level") or 1

	if money < data.price then
		print(p.Name.." not enough money "..money.."/"..data.price)
		return false, "reqs"
	end
	if lvl < data.level then
		print(p.Name.." not enough level "..lvl.."/"..data.level)
		return false, "reqs"
	end

	for _, item in pairs(data.items) do
		if not hasItem(p, item) then
			print(p.Name.." missing item: "..item)
			return false, "items"
		end
	end

	active_db[p] = true

	p:SetAttribute("Rebirth", nxt)
	p:SetAttribute("Money", data.bonus)
	p:SetAttribute("TotalRebirths", (p:GetAttribute("TotalRebirths") or 0) + 1)

	if data.slots and data.slots > 0 then
		local cur = p:GetAttribute("InventoryMaxSlots") or 10
		p:SetAttribute("InventoryMaxSlots", cur + data.slots)
		print(p.Name.." slots "..cur.." -> "..(cur+data.slots))
	end

	if data.mults then
		local give = rems:FindFirstChild("GiveMultiplier")
		if give then
			for _, m in pairs(data.mults) do
				local ok = pcall(function() give:Invoke(p, m[1], m[2]) end)
				if not ok then print("mult failed: "..m[1]) end
			end
		else
			print("GiveMultiplier not found")
		end
	end

	task.wait(0.5)
	saveData(p)

	cd_table[p] = tick()
	active_db[p] = nil

	print(p.Name.." rebirth "..rb.." -> "..nxt)
	return true, "ok"
end

Players.PlayerAdded:Connect(setupPlr)

Players.PlayerRemoving:Connect(function(p)
	saveData(p)
	active_db[p] = nil
	cd_table[p] = nil
end)

game:BindToClose(function()
	for _, p in pairs(Players:GetPlayers()) do
		saveData(p)
	end
end)

for _, p in pairs(Players:GetPlayers()) do
	task.spawn(setupPlr, p)
end

print("rebirths loaded")
