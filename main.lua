if _G.FARM_CONNECTION then
	task.cancel(_G.FARM_CONNECTION)
	_G.FARM_CONNECTION = nil
end

if _G.QUEST_CONNECTION then
	_G.QUEST_CONNECTION:Disconnect()
	_G.QUEST_CONNECTION = nil
end

if _G.STAT_CONNECTION then
	task.cancel(_G.STAT_CONNECTION)
	_G.STAT_CONNECTION = nil
end

_G.ENABLED = not _G.ENABLED
print("Auto Farm:", _G.ENABLED and "ON" or "OFF")

if not _G.ENABLED then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local Network = ReplicatedStorage:WaitForChild("Network")
local dataRemoteEvent = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
local QuestsFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("TalkNpc"):WaitForChild("Quests")
local QuestModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Game"):WaitForChild("Quest"))

local lockConnection = nil
local weaponCheckConnection = nil
local statUpgradeConnection = nil
local currentQuestTargets = {}

local QuestRanges = {
	{Min = 1, Max = 50, Name = "QuestGiver (Lv.1-Lv.50)"},
	{Min = 50, Max = 150, Name = "QuestGiver (Lv.50-Lv.150)"},
	{Min = 150, Max = 250, Name = "QuestGiver (Lv.150-Lv.250)"},
	{Min = 250, Max = 350, Name = "QuestGiver (Lv.250-Lv.350)"},
	{Min = 350, Max = 400, Name = "QuestGiver (Lv.350-Lv.400)"},
	{Min = 400, Max = 450, Name = "QuestGiver (Lv.400-Lv.450)"},
	{Min = 450, Max = 500, Name = "QuestGiver (Lv.450-Lv.500)"},
}

local StatNames = {"Damage", "Durability", "Stamina", "Speed"}

local function CheckLevel()
	return Player.Data.Level.Value
end

local function GetStatFolder()
	return Player.Data:FindFirstChild("Stat")
end

local function GetStatValue(statName)
	local statFolder = GetStatFolder()
	if not statFolder then return 0, 0 end
	
	local stat = statFolder:FindFirstChild(statName)
	if not stat then return 0, 0 end
	
	local value = stat.Value or 0
	local buff = stat:GetAttribute("Buff") or 0
	
	return value, buff
end

local function GetEffectiveStat(statName)
	local value, buff = GetStatValue(statName)
	return value - buff
end

local function GetUpgradeableStats()
	local upgradeable = {}
	
	for _, statName in ipairs(StatNames) do
		local maxStat = _G.SETTINGS.MaxStats[statName]
		if maxStat > 0 then
			local effectiveValue = GetEffectiveStat(statName)
			if effectiveValue < maxStat then
				table.insert(upgradeable, {
					Name = statName,
					Current = effectiveValue,
					Max = maxStat,
					Remaining = maxStat - effectiveValue
				})
			end
		end
	end
	
	return upgradeable
end

local function UpgradeStat(statName)
	dataRemoteEvent:FireServer({
		{
			statName,
			1
		},
		"\003"
	})
end

local function UpgradeRandomStat()
	local upgradeable = GetUpgradeableStats()
	if #upgradeable == 0 then return false end
	
	local randomStat = upgradeable[math.random(1, #upgradeable)]
	UpgradeStat(randomStat.Name)
	return true
end

local function StartStatUpgradeLoop()
	if statUpgradeConnection then return end
	
	statUpgradeConnection = task.spawn(function()
		while _G.ENABLED do
			local upgraded = UpgradeRandomStat()
			if not upgraded then
				task.wait(1)
			else
				task.wait(_G.SETTINGS.StatUpgradeDelay)
			end
		end
	end)
end

local function StopStatUpgradeLoop()
	if statUpgradeConnection then
		task.cancel(statUpgradeConnection)
		statUpgradeConnection = nil
	end
end

local function GetQuestGiverByLevel(level)
	for i = #QuestRanges, 1, -1 do
		local range = QuestRanges[i]
		if level >= range.Min then
			return range.Name
		end
	end
	return QuestRanges[1].Name
end

local function FireAllRemotes(...)
	local args = {...}
	for _, v in ipairs(Network:GetChildren()) do
		if v:IsA("RemoteEvent") then
			local success, result = pcall(function()
				v:FireServer(unpack(args))
			end)
			if success and result ~= nil then
				return v, result
			end
			task.wait(0.25)
		end
	end
end

local function InvokeAllFunctions(...)
	local args = {...}
	for _, v in ipairs(Network:GetChildren()) do
		if v:IsA("RemoteFunction") then
			local success, result = pcall(function()
				return v:InvokeServer(unpack(args))
			end)
			if success and result ~= nil then
				return v, result
			end
			task.wait(0.25)
		end
	end
end

local function IsModelTransparent(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			return false
		end
	end
	return true
end

local function CheckAndEquipWeapons()
	local weaponFolder = Character:FindFirstChild("Weapon")
	if not weaponFolder then return end
	
	for _, item in ipairs(weaponFolder:GetChildren()) do
		if (item:IsA("Model") or item:IsA("Folder")) and item.Name ~= "Stacks" then
			if IsModelTransparent(item) then
				print("Equipping:", item.Name)
				InvokeAllFunctions(item.Name)
			end
		end
	end
end

local function StartWeaponCheckLoop()
	if weaponCheckConnection then return end
	
	weaponCheckConnection = task.spawn(function()
		while _G.ENABLED do
			CheckAndEquipWeapons()
			task.wait(_G.SETTINGS.WeaponCheckDelay)
		end
	end)
end

local function StopWeaponCheckLoop()
	if weaponCheckConnection then
		task.cancel(weaponCheckConnection)
		weaponCheckConnection = nil
	end
end

local function HasActiveQuest()
	local hud = Player.PlayerGui:FindFirstChild("HUD")
	if not hud then return false end
	return hud:FindFirstChild("Quest") ~= nil
end

local function GetActiveQuestTargets()
	local targets = {}
	local aiPlayerFolder = workspace:FindFirstChild("AI/Player")
	if not aiPlayerFolder then return targets end
	
	for _, npc in ipairs(aiPlayerFolder:GetChildren()) do
		if npc:FindFirstChild("Mark") then
			if not table.find(targets, npc.Name) then
				table.insert(targets, npc.Name)
			end
		end
	end
	
	return targets
end

local function GetQuestTargets(questGiverName)
	local questGiver = QuestsFolder:FindFirstChild(questGiverName)
	if not questGiver then return {} end
	
	local questModule = questGiver:FindFirstChild("Quest")
	if not questModule then return {} end
	
	local success, questData = pcall(function()
		return require(questModule)
	end)
	
	if success and questData and questData.Target then
		return questData.Target
	end
	
	return {}
end

local function RequestQuestByLevel()
	local level = CheckLevel()
	local questGiverName = GetQuestGiverByLevel(level)
	
	local questGiver = QuestsFolder:FindFirstChild(questGiverName)
	if not questGiver then return false end
	
	local quest = questGiver:FindFirstChild("Quest")
	if not quest then return false end
	
	currentQuestTargets = GetQuestTargets(questGiverName)
	print("Level:", level, "| Quest:", questGiverName, "| Targets:", table.concat(currentQuestTargets, ", "))
	
	FireAllRemotes("RequestQuest", quest)
	return true
end

local function SetupQuest()
	if HasActiveQuest() then
		print("Active quest found, continuing...")
		currentQuestTargets = GetActiveQuestTargets()
		if #currentQuestTargets > 0 then
			print("Quest targets:", table.concat(currentQuestTargets, ", "))
		else
			local level = CheckLevel()
			local questGiverName = GetQuestGiverByLevel(level)
			currentQuestTargets = GetQuestTargets(questGiverName)
			print("Targets from module:", table.concat(currentQuestTargets, ", "))
		end
		return true
	else
		print("No active quest, requesting new one...")
		return RequestQuestByLevel()
	end
end

local function isValidTarget(npc)
	if #currentQuestTargets == 0 then return true end
	return table.find(currentQuestTargets, npc.Name) ~= nil
end

local function getNearestNpc()
	local nearestNpc = nil
	local nearestDistance = math.huge
	
	local aiPlayerFolder = workspace:FindFirstChild("AI/Player")
	if not aiPlayerFolder then return nil end
	
	for _, npc in ipairs(aiPlayerFolder:GetChildren()) do
		if npc:GetAttribute("isNpc") == true and isValidTarget(npc) then
			local npcHumanoid = npc:FindFirstChild("Humanoid")
			local npcRoot = npc:FindFirstChild("HumanoidRootPart")
			if npcRoot and npcHumanoid and npcHumanoid.Health > 0 then
				local distance = (npcRoot.Position - HumanoidRootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestNpc = npc
				end
			end
		end
	end
	
	return nearestNpc
end

local function isNpcAlive(npc)
	if not npc or not npc.Parent then return false end
	local npcHumanoid = npc:FindFirstChild("Humanoid")
	return npcHumanoid and npcHumanoid.Health > 0
end

local function isPlayerAlive()
	if not Character or not Character.Parent then return false end
	if not HumanoidRootPart or not HumanoidRootPart.Parent then return false end
	return Humanoid and Humanoid.Health > 0
end

local function lockToNpc(npc)
	if lockConnection then
		lockConnection:Disconnect()
	end
	
	lockConnection = RunService.Heartbeat:Connect(function()
		if not _G.ENABLED or not isNpcAlive(npc) or not isPlayerAlive() then
			if lockConnection then
				lockConnection:Disconnect()
				lockConnection = nil
			end
			return
		end
		
		local npcRoot = npc:FindFirstChild("HumanoidRootPart")
		if not npcRoot then return end
		
		local behindPosition = npcRoot.CFrame * CFrame.new(0, 0, _G.SETTINGS.BehindOffset)
		HumanoidRootPart.CFrame = CFrame.new(behindPosition.Position, npcRoot.Position)
	end)
end

local function attackNpc(npc)
	lockToNpc(npc)
	
	while _G.ENABLED and isNpcAlive(npc) and isPlayerAlive() do
		dataRemoteEvent:FireServer({
			"NormalAttack",
			"\t"
		})
		task.wait(_G.SETTINGS.AttackDelay)
	end
	
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

local function farmLoop()
	while _G.ENABLED and isPlayerAlive() do
		local nearestNpc = getNearestNpc()
		
		if nearestNpc then
			print("Target:", nearestNpc.Name)
			attackNpc(nearestNpc)
		end
		
		task.wait(_G.SETTINGS.SearchDelay)
	end
end

local function mainLoop()
	while _G.ENABLED do
		Character = Player.Character or Player.CharacterAdded:Wait()
		HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
		Humanoid = Character:WaitForChild("Humanoid")
		
		print("Starting farm cycle...")
		CheckAndEquipWeapons()
		StartWeaponCheckLoop()
		StartStatUpgradeLoop()
		SetupQuest()
		task.wait(1)
		farmLoop()
		
		StopWeaponCheckLoop()
		StopStatUpgradeLoop()
		
		if not _G.ENABLED then break end
		
		print("Player died, waiting for respawn...")
		Player.CharacterAdded:Wait()
		task.wait(2)
		print("Respawned, resuming farm...")
	end
	
	StopWeaponCheckLoop()
	StopStatUpgradeLoop()
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
	print("Auto Farm stopped")
end

_G.FARM_CONNECTION = task.spawn(mainLoop)

_G.QUEST_CONNECTION = QuestModule.OnQuestCompleted:Connect(function()
	if not _G.ENABLED then return end
	print("Quest completed! Getting new quest...")
	task.wait(0.5)
	RequestQuestByLevel()
end)
