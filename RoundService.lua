local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local isLive = remotes:WaitForChild("RoundLive")
local uiEvent = remotes:WaitForChild("RoundUI")
local teamPrompt = remotes:WaitForChild("TeamSelectPrompt")
local scoreEvent = remotes:WaitForChild("ScoreboardAddPoint")
local resetEvent = remotes:WaitForChild("BrainrotReset")
local endEvent = remotes:WaitForChild("RoundEnded_BE")
local debugTime = remotes:WaitForChild("DebugSetTime")
local rewardsFunc = remotes:WaitForChild("GiveRoundRewards_BF")

isLive.Value = false

local phase = "INTERMISSION"
local t = 5
local goal = 15
local bscore = 0
local rscore = 0
local winner = "NONE"
local winsGiven = false

local LIVE_TIME = 300

local function sync()
	uiEvent:FireAllClients({
		phase = phase,
		timeLeft = t,
		blueScore = bscore,
		redScore = rscore,
		goal = goal,
		winner = winner,
	})
end

local function toggleRound(on)
	isLive.Value = on
	Workspace:SetAttribute("RoundLive", on)
end

local function sendToLobby(p, respawn)
	p:SetAttribute("InLobby", true)
	p:SetAttribute("HasTeam", false)
	p.Neutral = false
	p.Team = Teams.Lobby
	if respawn then
		p:LoadCharacter()
	end
end

local function resetAll(respawn)
	for _, p in Players:GetPlayers() do
		sendToLobby(p, respawn)
	end
end

debugTime.Event:Connect(function(val)
	t = math.max(1, math.floor(tonumber(val) or 60))
	sync()
end)

Players.PlayerAdded:Connect(function(p)
	task.defer(function()
		sendToLobby(p, false)
		uiEvent:FireClient(p, {
			phase = phase, timeLeft = t, blueScore = bscore, redScore = rscore, goal = goal, winner = winner
		})
	end)
end)

local function awardWins(team)
	if winsGiven or team == "TIE" or team == "NONE" then return end
	winsGiven = true
	local winRemote = remotes:WaitForChild("AddWin")
	for _, p in Players:GetPlayers() do
		if p.Team and p.Team.Name == team then 
			winRemote:Fire(p) 
		end
	end
end

local function addScore(side, amt)
	amt = math.clamp(math.floor(tonumber(amt) or 1), 1, 50)
	if phase ~= "LIVE" or not isLive.Value then return end

	for i = 1, amt do
		if side == "A" then 
			rscore = rscore + 1
		elseif side == "B" then 
			bscore = bscore + 1 
		end

		Workspace:SetAttribute("RedScore", rscore)
		Workspace:SetAttribute("BlueScore", bscore)

		if rscore >= goal then
			winner = "Team A"
			t = 0
			awardWins(winner)
			break
		elseif bscore >= goal then
			winner = "Team B"
			t = 0
			awardWins(winner)
			break
		end
	end
	sync()
end

scoreEvent.Event:Connect(function(a1, a2)
	if typeof(a1) == "string" then
		addScore(a1, a2)
	elseif typeof(a1) == "Instance" and typeof(a2) == "string" then
		addScore(a2, 1)
	end
end)

local function cleanup()
	local bases = Workspace.Bases
	for _, n in {"BaseA", "BaseB"} do
		bases[n].DepositedBrainrots:ClearAllChildren()
	end
end

local function dropAll()
	local carry = require(ServerScriptService.BrainrotCarryService)
	for _, p in Players:GetPlayers() do
		if carry.IsCarrying(p) then
			carry.Drop(p, "HitByTrain")
		end
	end
end

toggleRound(false)
resetAll(true)
sync()

task.spawn(function()
	while true do
		phase = "INTERMISSION"
		winner = "NONE"
		t = 5
		bscore = 0
		rscore = 0
		winsGiven = false

		Workspace:SetAttribute("RedScore", 0)
		Workspace:SetAttribute("BlueScore", 0)

		toggleRound(false)
		resetAll(false)
		sync()

		while t > 0 do 
			task.wait(1)
			t = t - 1
			sync() 
		end

		phase = "LIVE"
		winner = "NONE"
		t = LIVE_TIME
		toggleRound(true)

		for _, p in Players:GetPlayers() do
			sendToLobby(p, false)
			teamPrompt:FireClient(p)
		end
		sync()

		while t > 0 do 
			task.wait(1)
			t = t - 1
			sync() 
		end

		if winner == "NONE" then
			if rscore > bscore then 
				winner = "Team A"
			elseif bscore > rscore then 
				winner = "Team B"
			else 
				winner = "TIE" 
			end
		end

		awardWins(winner)

		phase = "RESULT"
		t = 10
		toggleRound(false)
		resetAll(true)
		sync()

		endEvent:Fire(winner)

		while t > 0 do 
			task.wait(1)
			t = t - 1
			sync() 
		end

		dropAll()
		cleanup()
		resetEvent:Fire()
	end
end)
