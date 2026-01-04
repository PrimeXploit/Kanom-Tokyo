if _G.SCRIPT_LOADED then
	warn("Script is already running!")
	return
end
_G.SCRIPT_LOADED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local function CreateMobileButton(callback)
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "MobileToggle"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	local success = pcall(function()
		ScreenGui.Parent = CoreGui
	end)
	if not success then
		ScreenGui.Parent = Player:WaitForChild("PlayerGui")
	end

	local Button = Instance.new("TextButton")
	Button.Name = "ToggleButton"
	Button.Size = UDim2.fromOffset(50, 50)
	Button.Position = UDim2.new(0, 20, 0.5, -25)
	Button.AnchorPoint = Vector2.new(0, 0)
	Button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	Button.BackgroundTransparency = 0.3
	Button.Text = "P"
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.TextSize = 24
	Button.Font = Enum.Font.GothamBold
	Button.AutoButtonColor = false
	Button.Parent = ScreenGui

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = Button

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(100, 100, 100)
	Stroke.Thickness = 2
	Stroke.Parent = Button

	local dragging = false
	local dragStart = nil
	local startPos = nil
	local dragThreshold = 10
	local totalDragDistance = 0

	Button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = Button.Position
			totalDragDistance = 0
		end
	end)

	Button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragging and totalDragDistance < dragThreshold then
				callback()
			end
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = input.Position - dragStart
			totalDragDistance = delta.Magnitude
			local newPos = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			Button.Position = newPos
		end
	end)

	Button.MouseEnter:Connect(function()
		TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
	end)

	Button.MouseLeave:Connect(function()
		TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
	end)

	return ScreenGui, Button
end

local Window = Fluent:CreateWindow({
	Title = "PrimeXploit [ Kanom Tokyo ]",
	SubTitle = "v1.0",
	TabWidth = 160,
	Size = UDim2.fromOffset(500, 400),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftAlt
})

local MobileGui, MobileButton = CreateMobileButton(function()
	Window:Minimize()
end)

local fluentGui = CoreGui:FindFirstChild("Fluent") or Player.PlayerGui:FindFirstChild("Fluent")
if fluentGui then
	fluentGui.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if MobileGui and MobileGui.Parent then
				MobileGui:Destroy()
			end
			_G.SCRIPT_LOADED = nil
		end
	end)
end

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "swords" }),
	Stats = Window:AddTab({ Title = "Stats", Icon = "bar-chart" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

local Network = ReplicatedStorage:WaitForChild("Network")
local dataRemoteEvent = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
local QuestsFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("TalkNpc"):WaitForChild("Quests")
local QuestModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Game"):WaitForChild("Quest"))

local Character, HumanoidRootPart, Humanoid
local lockConnection, weaponCheckConnection, statUpgradeConnection
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
	local maxStats = {
		Damage = Options.MaxDamage and Options.MaxDamage.Value or 400,
		Durability = Options.MaxDurability and Options.MaxDurability.Value or 500,
		Stamina = Options.MaxStamina and Options.MaxStamina.Value or 500,
		Speed = Options.MaxSpeed and Options.MaxSpeed.Value or 100
	}
	for _, statName in ipairs(StatNames) do
		local maxStat = maxStats[statName]
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
	dataRemoteEvent:FireServer({{statName, 1}, "\003"})
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
			task.wait(upgraded and 0.1 or 1)
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
		if level >= range.Min then return range.Name end
	end
	return QuestRanges[1].Name
end

local function FireAllRemotes(...)
	local args = {...}
	for _, v in ipairs(Network:GetChildren()) do
		if v:IsA("RemoteEvent") then
			local success, result = pcall(function() v:FireServer(unpack(args)) end)
			if success and result ~= nil then return v, result end
			task.wait(0.25)
		end
	end
end

local function IsModelTransparent(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then return false end
	end
	return true
end

local function CheckAndEquipWeapons()
	local weaponFolder = Character and Character:FindFirstChild("Weapon")
	if not weaponFolder then return end
	for _, item in ipairs(weaponFolder:GetChildren()) do
		if (item:IsA("Model") or item:IsA("Folder")) and item.Name ~= "Stacks" then
			if IsModelTransparent(item) then
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
				task.wait(0.1)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			end
		end
	end
end

local function StartWeaponCheckLoop()
	if weaponCheckConnection then return end
	weaponCheckConnection = task.spawn(function()
		while _G.ENABLED do
			CheckAndEquipWeapons()
			task.wait(2)
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
		if npc:FindFirstChild("Mark") and not table.find(targets, npc.Name) then
			table.insert(targets, npc.Name)
		end
	end
	return targets
end

local function GetQuestTargets(questGiverName)
	local questGiver = QuestsFolder:FindFirstChild(questGiverName)
	if not questGiver then return {} end
	local questModule = questGiver:FindFirstChild("Quest")
	if not questModule then return {} end
	local success, questData = pcall(function() return require(questModule) end)
	if success and questData and questData.Target then return questData.Target end
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
	FireAllRemotes("RequestQuest", quest)
	return true
end

local function SetupQuest()
	if HasActiveQuest() then
		currentQuestTargets = GetActiveQuestTargets()
		if #currentQuestTargets == 0 then
			local level = CheckLevel()
			local questGiverName = GetQuestGiverByLevel(level)
			currentQuestTargets = GetQuestTargets(questGiverName)
		end
		return true
	else
		return RequestQuestByLevel()
	end
end

local function isValidTarget(npc)
	if #currentQuestTargets == 0 then return true end
	return table.find(currentQuestTargets, npc.Name) ~= nil
end

local function getNearestNpc()
	local nearestNpc, nearestDistance = nil, math.huge
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
	if lockConnection then lockConnection:Disconnect() end
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
		local offset = Options.BehindOffset and Options.BehindOffset.Value or 3
		local behindPosition = npcRoot.CFrame * CFrame.new(0, 0, offset)
		HumanoidRootPart.CFrame = CFrame.new(behindPosition.Position, npcRoot.Position)
	end)
end

local function attackNpc(npc)
	lockToNpc(npc)
	while _G.ENABLED and isNpcAlive(npc) and isPlayerAlive() do
		dataRemoteEvent:FireServer({"NormalAttack", "\t"})
		local delay = Options.AttackDelay and Options.AttackDelay.Value or 0
		task.wait(delay)
	end
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

local function farmLoop()
	while _G.ENABLED and isPlayerAlive() do
		local nearestNpc = getNearestNpc()
		if nearestNpc then attackNpc(nearestNpc) end
		local searchDelay = Options.SearchDelay and Options.SearchDelay.Value or 0.5
		task.wait(searchDelay)
	end
end

local function mainLoop()
	while _G.ENABLED do
		Character = Player.Character or Player.CharacterAdded:Wait()
		HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
		Humanoid = Character:WaitForChild("Humanoid")
		CheckAndEquipWeapons()
		StartWeaponCheckLoop()
		if Options.AutoStats and Options.AutoStats.Value then
			StartStatUpgradeLoop()
		end
		SetupQuest()
		task.wait(1)
		farmLoop()
		StopWeaponCheckLoop()
		StopStatUpgradeLoop()
		if not _G.ENABLED then break end
		Player.CharacterAdded:Wait()
		task.wait(2)
	end
	StopWeaponCheckLoop()
	StopStatUpgradeLoop()
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

local function StartFarm()
	if _G.FARM_CONNECTION then
		task.cancel(_G.FARM_CONNECTION)
		_G.FARM_CONNECTION = nil
	end
	if _G.QUEST_CONNECTION then
		_G.QUEST_CONNECTION:Disconnect()
		_G.QUEST_CONNECTION = nil
	end
	_G.ENABLED = true
	_G.FARM_CONNECTION = task.spawn(mainLoop)
	_G.QUEST_CONNECTION = QuestModule.OnQuestCompleted:Connect(function()
		if not _G.ENABLED then return end
		task.wait(0.5)
		RequestQuestByLevel()
	end)
end

local function StopFarm()
	_G.ENABLED = false
	if _G.FARM_CONNECTION then
		task.cancel(_G.FARM_CONNECTION)
		_G.FARM_CONNECTION = nil
	end
	if _G.QUEST_CONNECTION then
		_G.QUEST_CONNECTION:Disconnect()
		_G.QUEST_CONNECTION = nil
	end
	StopWeaponCheckLoop()
	StopStatUpgradeLoop()
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

local AutoFarm = Tabs.Main:AddSection("[ 💵 ] - Auto Farm")

AutoFarm:AddToggle("AutoFarm", {Title = "Auto Farm", Default = false}):OnChanged(function()
	if Options.AutoFarm.Value then
		StartFarm()
		Fluent:Notify({Title = "Auto Farm", Content = "Enabled", Duration = 3})
	else
		StopFarm()
		Fluent:Notify({Title = "Auto Farm", Content = "Disabled", Duration = 3})
	end
end)

AutoFarm:AddSlider("BehindOffset", {
	Title = "Behind Offset",
	Default = 3,
	Min = 0,
	Max = 10,
	Rounding = 1
})

AutoFarm:AddSlider("AttackDelay", {
	Title = "Attack Delay",
	Default = 0,
	Min = 0,
	Max = 1,
	Rounding = 2
})

AutoFarm:AddSlider("SearchDelay", {
	Title = "Search Delay",
	Default = 0.5,
	Min = 0.1,
	Max = 2,
	Rounding = 1
})

local AutoUpStats = Tabs.Stats:AddSection("[ 🧰 ] - Auto Up Stats")

AutoUpStats:AddToggle("AutoStats", {Title = "Auto Up Stats", Default = true})

AutoUpStats:AddSlider("MaxDamage", {
	Title = "Max Damage",
	Default = 400,
	Min = 0,
	Max = 1000,
	Rounding = 0
})

AutoUpStats:AddSlider("MaxDurability", {
	Title = "Max Durability",
	Default = 500,
	Min = 0,
	Max = 1000,
	Rounding = 0
})

AutoUpStats:AddSlider("MaxStamina", {
	Title = "Max Stamina",
	Default = 500,
	Min = 0,
	Max = 1000,
	Rounding = 0
})

AutoUpStats:AddSlider("MaxSpeed", {
	Title = "Max Speed",
	Default = 100,
	Min = 0,
	Max = 1000,
	Rounding = 0
})

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("PrimeXploit/Kanom-Tokyo")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
	Title = "PrimeXploit",
	Content = "Script loaded successfully!",
	Duration = 5
})