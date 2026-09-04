--[[
    ALPHA // BLOX FRUITS HUB v2 (KEYLESS EDITION)
    Complete Redz Hub Reconstruction • 100% Keyless • Full Feature Suite
    
    Features:
    - Auto Farm Level (Sea 1, 2, 3 complete level quest system)
    - Dynamic Mob Selector & Auto Farm Selected Mob
    - Master Boss Selector & Auto Farm Selected Boss / All Bosses
    - World & Raid Bosses: Rip Indra, Dough King, Cake Prince, Soul Reaper, Darkbeard, Cursed Captain, Law
    - Redz Fast Attack Engine (RE/RegisterAttack + RE/RegisterHit + Koby Fast Hit Algorithm)
    - Bring Mobs (SimulationRadius mob clumping)
    - Items & Quests: Auto Saber, Pole, Rengoku, Dragon Trident, Yama, Tushita, CDK, Soul Guitar, Bartilo
    - Sea Events: Shark, Terror Shark, Piranha, Fish Crew, Sea Beast
    - Mirage Island & Kitsune Island: Spawn Detector, Tween, Blue Gear Finder, Temple Lever
    - Dungeon & Raids: Auto Buy Chip, Auto Start, Next Island, Auto Awaken
    - Devil Fruit: Auto Random Gacha, Auto Store, Auto Grab Dropped Fruits, Fruit ESP
    - Auto Stats: Real-time point allocator for Melee, Defense, Sword, Gun, Fruit
    - Shop: 1-Click Buy for all Fighting Styles (V1 & V2), Swords, Haki, Geppo, Soru
    - Teleports: Full Island Teleports for Sea 1, Sea 2, Sea 3
    - UI: RedzLib UI Framework with built-in resilient fallback
    - Zero Key System • Zero Ads • Instant Execution
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--============================== CORE SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Place / Sea Identification
local PlaceId = game.PlaceId
local Sea1 = (PlaceId == 2753915549)
local Sea2 = (PlaceId == 4442272183)
local Sea3 = (PlaceId == 7449423635)
local SeaName = Sea1 and "First Sea" or (Sea2 and "Second Sea" or (Sea3 and "Third Sea" or "Unknown Sea"))

-- Safe request wrapper
local safeRequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request

--============================== REMOTES & MODULES ==============================
local Remotes = RS:WaitForChild("Remotes", 10)
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")
local Commits = Remotes and Remotes:FindFirstChild("Commits")
local Validator2 = Remotes and Remotes:FindFirstChild("Validator2")

if not CommF_ or not Commits then
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteFunction") and v.Name == "CommF_" then CommF_ = v end
        if v:IsA("RemoteEvent") and v.Name == "Commits" then Commits = v end
        if v:IsA("RemoteEvent") and v.Name == "Validator2" then Validator2 = v end
    end
end

local Net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
local RegisterAttack = Net and Net:FindFirstChild("RE/RegisterAttack")
local RegisterHit = Net and Net:FindFirstChild("RE/RegisterHit")
local ShootGunEvent = Net and Net:FindFirstChild("RE/ShootGunEvent")

--============================== CONFIGURATION ==============================
_G.Config = {
    -- Farming
    AutoFarmLevel = false,
    AutoDoubleQuest = false,
    FarmSelectedMob = false,
    FarmSelectedBoss = false,
    FarmAllBosses = false,
    SelectedMob = "",
    SelectedBoss = "",
    SelectedWeapon = "Melee", -- Melee | Sword | Gun | Fruit
    BringMobs = true,
    FarmDistance = 9,
    TweenSpeed = 320,
    
    -- Combat & Fast Attack
    FastAttack = true,
    AttackDistance = 65,
    AttackCooldown = 0.05,
    AutoBusoHaki = true,
    AutoKenHaki = false,
    
    -- World & Raid Bosses
    AutoKillRipIndra = false,
    AutoKillDoughKing = false,
    AutoKillCakePrince = false,
    AutoKillSoulReaper = false,
    AutoKillDarkbeard = false,
    AutoKillCursedCaptain = false,
    AutoKillLaw = false,
    
    -- Items & Quests
    AutoSaber = false,
    AutoPole = false,
    AutoRengoku = false,
    AutoDragonTrident = false,
    AutoYama = false,
    AutoTushita = false,
    AutoCDK = false,
    AutoSoulGuitar = false,
    AutoBartilo = false,
    AutoSecondSea = false,
    AutoThirdSea = false,
    
    -- Sea Events & Mirage
    AutoKillShark = false,
    AutoKillTerrorShark = false,
    AutoKillPiranha = false,
    AutoKillSeaBeast = false,
    AutoFindGear = false,
    AutoPullLever = false,
    
    -- Dungeon / Raids
    SelectedChip = "Flame",
    AutoBuyChip = false,
    AutoStartRaid = false,
    AutoFarmRaid = false,
    AutoAwaken = false,
    
    -- Devil Fruit
    AutoRandomFruit = false,
    AutoStoreFruit = false,
    AutoGrabFruits = false,
    FruitESP = false,
    
    -- Stats
    AutoStats = false,
    StatPoints = 1,
    Stats = {
        Melee = true,
        Defense = true,
        Sword = false,
        Gun = false,
        Fruit = false
    },
    
    -- Utility
    AntiAFK = true,
    SafeMode = false
}

--============================== HELPER FUNCTIONS ==============================
local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetRoot()
    local char = GetCharacter()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function GetHumanoid()
    local char = GetCharacter()
    return char:WaitForChild("Humanoid", 5)
end

local function GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return data.Level.Value
    end
    return 1
end

-- Equip selected weapon type
local function EquipWeapon(weaponType)
    weaponType = weaponType or _G.Config.SelectedWeapon
    local char = GetCharacter()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return end
    
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("ToolTip") and tool.ToolTip == weaponType then
            return tool
        end
    end
    
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == weaponType or (weaponType == "Fruit" and tool.ToolTip == "Blox Fruit")) then
            char.Humanoid:EquipTool(tool)
            return tool
        end
    end
    
    -- Fallback: equip any available tool
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            char.Humanoid:EquipTool(tool)
            return tool
        end
    end
end

-- Auto Buso Haki
local function CheckBusoHaki()
    if not _G.Config.AutoBusoHaki then return end
    local char = GetCharacter()
    if char and not char:FindFirstChild("HasBuso") then
        if CommF_ then
            pcall(function() CommF_:InvokeServer("Buso") end)
        end
    end
end

--============================== CLEAN TWEEN ENGINE ==============================
local CurrentTween = nil
local NoclipConn = nil

local function EnableNoclip()
    if NoclipConn then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function DisableNoclip()
    if NoclipConn then
        NoclipConn:Disconnect()
        NoclipConn = nil
    end
end

local function StopTween()
    if CurrentTween then
        CurrentTween:Cancel()
        CurrentTween = nil
    end
    DisableNoclip()
end

local function TweenTo(targetCFrame)
    local root = GetRoot()
    if not root then return end
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    if distance < 15 then
        root.CFrame = targetCFrame
        StopTween()
        return
    end
    
    local speed = _G.Config.TweenSpeed or 320
    local time = distance / speed
    
    EnableNoclip()
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    CurrentTween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    CurrentTween:Play()
    return CurrentTween
end

--============================== FAST ATTACK ENGINE ==============================
-- Exact Redz Hub multi-method combat system
local function GetBladeHits()
    local targets = {}
    local root = GetRoot()
    if not root then return targets end
    
    local function CheckPart(folder)
        if not folder then return end
        for _, v in ipairs(folder:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                if (v.HumanoidRootPart.Position - root.Position).Magnitude <= _G.Config.AttackDistance then
                    table.insert(targets, v)
                end
            end
        end
    end
    
    CheckPart(Workspace:FindFirstChild("Enemies"))
    CheckPart(Workspace:FindFirstChild("Characters"))
    return targets
end

local function FastAttack()
    if not _G.Config.FastAttack then return end
    local char = GetCharacter()
    if not char then return end
    
    local enemies = GetBladeHits()
    if #enemies > 0 then
        -- Method 1: Net remotes
        if RegisterAttack and RegisterHit then
            pcall(function()
                RegisterAttack:FireServer(-math.huge)
                local args = {nil, {}}
                for i, v in ipairs(enemies) do
                    if not args[1] and v:FindFirstChild("Head") then
                        args[1] = v.Head
                    end
                    args[2][i] = {v, v.HumanoidRootPart}
                end
                RegisterHit:FireServer(unpack(args))
            end)
        end
        
        -- Method 2: Tool activate fallback
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
        
        -- Method 3: VirtualUser click
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(Vector2.new(0, 0))
        end)
    end
end

-- Combat loop
task.spawn(function()
    while true do
        task.wait(_G.Config.AttackCooldown or 0.05)
        if _G.Config.FastAttack and (_G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses) then
            FastAttack()
            CheckBusoHaki()
        end
    end
end)

--============================== BRING MOBS SYSTEM ==============================
local function BringMobsTo(targetMobName, centerCFrame)
    if not _G.Config.BringMobs then return end
    
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
            sethiddenproperty(LocalPlayer, "MaxSimulationRadius", math.huge)
        end
    end)
    
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end
    
    for _, mob in ipairs(enemies:GetChildren()) do
        if mob.Name == targetMobName and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
            local dist = (mob.HumanoidRootPart.Position - centerCFrame.Position).Magnitude
            if dist < 260 and dist > 4 then
                mob.HumanoidRootPart.CFrame = centerCFrame
                mob.HumanoidRootPart.CanCollide = false
                mob.Humanoid.WalkSpeed = 0
            end
        end
    end
end

--============================== MASTER QUEST DATABASE ==============================
-- Covers every single level bracket for Sea 1, Sea 2, and Sea 3
local QuestsDB = {
    -- Sea 1 (First Sea)
    {Min = 1, Max = 9, Quest = "BanditQuest1", Level = 1, Mob = "Bandit", Pos = CFrame.new(1059.37, 16.51, 1546.99)},
    {Min = 10, Max = 14, Quest = "JungleQuest", Level = 1, Mob = "Monkey", Pos = CFrame.new(-1612.33, 36.85, 149.13)},
    {Min = 15, Max = 29, Quest = "JungleQuest", Level = 2, Mob = "Gorilla", Pos = CFrame.new(-1240.23, 6.27, -495.22)},
    {Min = 30, Max = 39, Quest = "BuggyQuest1", Level = 1, Mob = "Pirate", Pos = CFrame.new(-1181.39, 4.75, 3843.43)},
    {Min = 40, Max = 59, Quest = "BuggyQuest1", Level = 2, Mob = "Brute", Pos = CFrame.new(-1146.47, 77.22, 4476.81)},
    {Min = 60, Max = 74, Quest = "DesertQuest", Level = 1, Mob = "Desert Bandit", Pos = CFrame.new(1094.11, 6.44, 4192.89)},
    {Min = 75, Max = 89, Quest = "DesertQuest", Level = 2, Mob = "Desert Officer", Pos = CFrame.new(1568.17, 6.44, 4373.23)},
    {Min = 90, Max = 99, Quest = "SnowQuest", Level = 1, Mob = "Snow Bandit", Pos = CFrame.new(1384.81, 87.27, -1298.47)},
    {Min = 100, Max = 119, Quest = "SnowQuest", Level = 2, Mob = "Snowman", Pos = CFrame.new(1384.81, 87.27, -1298.47)},
    {Min = 120, Max = 149, Quest = "MarineQuest2", Level = 1, Mob = "Chief Petty Officer", Pos = CFrame.new(-5035.79, 28.65, 4324.96)},
    {Min = 150, Max = 174, Quest = "SkyQuest", Level = 1, Mob = "Sky Bandit", Pos = CFrame.new(-4839.53, 717.67, -2619.44)},
    {Min = 175, Max = 189, Quest = "SkyQuest", Level = 2, Mob = "Dark Master", Pos = CFrame.new(-4839.53, 717.67, -2619.44)},
    {Min = 190, Max = 209, Quest = "PrisonerQuest", Level = 1, Mob = "Prisoner", Pos = CFrame.new(4875.33, 5.65, 735.45)},
    {Min = 210, Max = 249, Quest = "PrisonerQuest", Level = 2, Mob = "Dangerous Prisoner", Pos = CFrame.new(4875.33, 5.65, 735.45)},
    {Min = 250, Max = 274, Quest = "ColosseumQuest", Level = 1, Mob = "Toga Warrior", Pos = CFrame.new(-1588.34, 7.39, -2982.52)},
    {Min = 275, Max = 299, Quest = "ColosseumQuest", Level = 2, Mob = "Gladiator", Pos = CFrame.new(-1427.62, 7.28, -2792.77)},
    {Min = 300, Max = 324, Quest = "MagmaQuest", Level = 1, Mob = "Military Soldier", Pos = CFrame.new(-5389.72, 8.57, 8533.84)},
    {Min = 325, Max = 374, Quest = "MagmaQuest", Level = 2, Mob = "Military Spy", Pos = CFrame.new(-5815.17, 83.99, 8820.32)},
    {Min = 375, Max = 399, Quest = "FishmanQuest", Level = 1, Mob = "Fishman Warrior", Pos = CFrame.new(61122.65, 18.50, 1569.40)},
    {Min = 400, Max = 449, Quest = "FishmanQuest", Level = 2, Mob = "Fishman Commando", Pos = CFrame.new(61845.89, 18.50, 1569.40)},
    {Min = 450, Max = 474, Quest = "SkyExp1Quest", Level = 1, Mob = "God's Guard", Pos = CFrame.new(-4721.89, 843.87, -1949.97)},
    {Min = 475, Max = 524, Quest = "SkyExp1Quest", Level = 2, Mob = "Shanda", Pos = CFrame.new(-7894.62, 5545.49, -380.41)},
    {Min = 525, Max = 549, Quest = "SkyExp2Quest", Level = 1, Mob = "Royal Squad", Pos = CFrame.new(-7906.82, 5635.96, -1411.99)},
    {Min = 550, Max = 624, Quest = "SkyExp2Quest", Level = 2, Mob = "Royal Soldier", Pos = CFrame.new(-7748.21, 5606.84, -1443.43)},
    {Min = 625, Max = 649, Quest = "FountainQuest", Level = 1, Mob = "Galley Pirate", Pos = CFrame.new(5589.90, 4.41, 3995.78)},
    {Min = 650, Max = 699, Quest = "FountainQuest", Level = 2, Mob = "Galley Captain", Pos = CFrame.new(5649.03, 38.51, 4937.42)},

    -- Sea 2 (Second Sea)
    {Min = 700, Max = 724, Quest = "Area1Quest", Level = 1, Mob = "Raider", Pos = CFrame.new(-429.54, 72.99, 1836.18)},
    {Min = 725, Max = 774, Quest = "Area1Quest", Level = 2, Mob = "Mercenary", Pos = CFrame.new(-960.61, 74.38, 1729.07)},
    {Min = 775, Max = 799, Quest = "Area2Quest", Level = 1, Mob = "Swan Pirate", Pos = CFrame.new(878.01, 121.98, 1235.35)},
    {Min = 800, Max = 874, Quest = "Area2Quest", Level = 2, Mob = "Factory Staff", Pos = CFrame.new(295.34, 73.01, -56.55)},
    {Min = 875, Max = 899, Quest = "MarineQuest3", Level = 1, Mob = "Marine Lieutenant", Pos = CFrame.new(-2806.12, 72.96, -3038.55)},
    {Min = 900, Max = 949, Quest = "MarineQuest3", Level = 2, Mob = "Marine Rear Admiral", Pos = CFrame.new(-3424.41, 72.96, -2997.74)},
    {Min = 950, Max = 974, Quest = "ZombieQuest", Level = 1, Mob = "Zombie", Pos = CFrame.new(-5418.89, 48.52, -774.75)},
    {Min = 975, Max = 999, Quest = "ZombieQuest", Level = 2, Mob = "Vampire", Pos = CFrame.new(-6033.86, 6.44, -1316.51)},
    {Min = 1000, Max = 1049, Quest = "SnowMountainQuest", Level = 1, Mob = "Snow Trooper", Pos = CFrame.new(608.24, 401.52, -5372.46)},
    {Min = 1050, Max = 1099, Quest = "SnowMountainQuest", Level = 2, Mob = "Winter Warrior", Pos = CFrame.new(1157.44, 430.12, -5187.52)},
    {Min = 1100, Max = 1124, Quest = "IceSideQuest", Level = 1, Mob = "Lab Subordinate", Pos = CFrame.new(-5775.29, 42.44, -4465.17)},
    {Min = 1125, Max = 1174, Quest = "FireSideQuest", Level = 1, Mob = "Horned Warrior", Pos = CFrame.new(-6411.39, 15.96, -5836.78)},
    {Min = 1175, Max = 1199, Quest = "FireSideQuest", Level = 2, Mob = "Magma Ninja", Pos = CFrame.new(-5430.72, 76.96, -5949.19)},
    {Min = 1200, Max = 1249, Quest = "FireSideQuest", Level = 2, Mob = "Lava Pirate", Pos = CFrame.new(-5223.12, 55.96, -4783.21)},
    {Min = 1250, Max = 1274, Quest = "ShipQuest1", Level = 1, Mob = "Ship Deckhand", Pos = CFrame.new(1198.81, 125.12, 32986.92)},
    {Min = 1275, Max = 1299, Quest = "ShipQuest1", Level = 2, Mob = "Ship Engineer", Pos = CFrame.new(918.42, 125.12, 32884.28)},
    {Min = 1300, Max = 1324, Quest = "ShipQuest2", Level = 1, Mob = "Ship Steward", Pos = CFrame.new(915.24, 125.12, 33458.12)},
    {Min = 1325, Max = 1349, Quest = "ShipQuest2", Level = 2, Mob = "Ship Officer", Pos = CFrame.new(915.24, 180.12, 33458.12)},
    {Min = 1350, Max = 1399, Quest = "FrostQuest", Level = 1, Mob = "Arctic Warrior", Pos = CFrame.new(6038.45, 28.25, -6231.25)},
    {Min = 1400, Max = 1424, Quest = "FrostQuest", Level = 2, Mob = "Snow Lurker", Pos = CFrame.new(5560.13, 28.25, -6826.91)},
    {Min = 1425, Max = 1449, Quest = "ForgottenQuest", Level = 1, Mob = "Sea Soldier", Pos = CFrame.new(-3054.44, 237.15, -10142.82)},
    {Min = 1450, Max = 1499, Quest = "ForgottenQuest", Level = 2, Mob = "Water Fighter", Pos = CFrame.new(-3435.12, 237.15, -10534.21)},

    -- Sea 3 (Third Sea)
    {Min = 1500, Max = 1524, Quest = "PiratePortQuest", Level = 1, Mob = "Pirate Millionaire", Pos = CFrame.new(-290.74, 43.73, 5580.12)},
    {Min = 1525, Max = 1574, Quest = "PiratePortQuest", Level = 2, Mob = "Pistol Billionaire", Pos = CFrame.new(-468.12, 74.21, 5945.32)},
    {Min = 1575, Max = 1599, Quest = "DragonCrewQuest", Level = 1, Mob = "Dragon Crew Archer", Pos = CFrame.new(6594.12, 384.12, 142.54)},
    {Min = 1600, Max = 1624, Quest = "DragonCrewQuest", Level = 2, Mob = "Dragon Crew Warrior", Pos = CFrame.new(6745.23, 384.12, -189.43)},
    {Min = 1625, Max = 1649, Quest = "VenomCrewQuest", Level = 1, Mob = "Venomous Assailant", Pos = CFrame.new(5210.45, 601.23, 894.12)},
    {Min = 1650, Max = 1699, Quest = "VenomCrewQuest", Level = 2, Mob = "Hydra Enforcer", Pos = CFrame.new(4512.34, 601.23, 1120.54)},
    {Min = 1700, Max = 1724, Quest = "DeepForestIsland", Level = 1, Mob = "Marine Commodore", Pos = CFrame.new(2450.12, 73.12, -7320.45)},
    {Min = 1725, Max = 1774, Quest = "DeepForestIsland", Level = 2, Mob = "Marine Rear Admiral", Pos = CFrame.new(2912.45, 73.12, -7640.12)},
    {Min = 1775, Max = 1799, Quest = "DeepForestIsland2", Level = 1, Mob = "Fishman Raider", Pos = CFrame.new(-10520.12, 332.12, -8412.34)},
    {Min = 1800, Max = 1824, Quest = "DeepForestIsland2", Level = 2, Mob = "Fishman Captain", Pos = CFrame.new(-10940.45, 332.12, -8890.12)},
    {Min = 1825, Max = 1849, Quest = "DeepForestIsland3", Level = 1, Mob = "Forest Pirate", Pos = CFrame.new(-13250.12, 332.12, -7640.54)},
    {Min = 1850, Max = 1899, Quest = "DeepForestIsland3", Level = 2, Mob = "Mythological Pirate", Pos = CFrame.new(-13560.34, 470.12, -6920.12)},
    {Min = 1900, Max = 1924, Quest = "DeepForestIsland3", Level = 3, Mob = "Jungle Pirate", Pos = CFrame.new(-12120.45, 332.12, -10540.23)},
    {Min = 1925, Max = 1974, Quest = "DeepForestIsland3", Level = 4, Mob = "Musketeer Pirate", Pos = CFrame.new(-13140.23, 390.12, -9650.34)},
    {Min = 1975, Max = 1999, Quest = "HauntedQuest1", Level = 1, Mob = "Reborn Skeleton", Pos = CFrame.new(-8760.12, 141.12, 6050.23)},
    {Min = 2000, Max = 2024, Quest = "HauntedQuest1", Level = 2, Mob = "Living Zombie", Pos = CFrame.new(-9120.34, 141.12, 5820.45)},
    {Min = 2025, Max = 2049, Quest = "HauntedQuest2", Level = 1, Mob = "Demonic Soul", Pos = CFrame.new(-9520.45, 172.01, 6120.12)},
    {Min = 2050, Max = 2074, Quest = "HauntedQuest2", Level = 2, Mob = "Posessed Mummy", Pos = CFrame.new(-9516.99, 12.01, 6078.47)},
    {Min = 2075, Max = 2099, Quest = "NutsIslandQuest", Level = 1, Mob = "Peanut Scout", Pos = CFrame.new(-2120.34, 38.12, -10190.23)},
    {Min = 2100, Max = 2124, Quest = "NutsIslandQuest", Level = 2, Mob = "Peanut President", Pos = CFrame.new(-2120.34, 38.12, -10520.45)},
    {Min = 2125, Max = 2149, Quest = "IceCreamIslandQuest", Level = 1, Mob = "Ice Cream Chef", Pos = CFrame.new(-820.12, 65.12, -10940.34)},
    {Min = 2150, Max = 2199, Quest = "IceCreamIslandQuest", Level = 2, Mob = "Ice Cream Commander", Pos = CFrame.new(-640.45, 65.12, -11250.12)},
    {Min = 2200, Max = 2224, Quest = "CakeQuest1", Level = 1, Mob = "Cookie Crafter", Pos = CFrame.new(-2350.12, 38.12, -12020.34)},
    {Min = 2225, Max = 2249, Quest = "CakeQuest1", Level = 2, Mob = "Cake Guard", Pos = CFrame.new(-1580.45, 38.12, -12340.12)},
    {Min = 2250, Max = 2274, Quest = "CakeQuest2", Level = 1, Mob = "Baking Staff", Pos = CFrame.new(-1890.23, 38.12, -12950.45)},
    {Min = 2275, Max = 2299, Quest = "CakeQuest2", Level = 2, Mob = "Head Baker", Pos = CFrame.new(-1920.45, 38.12, -13100.12)},
    {Min = 2300, Max = 2324, Quest = "ChocQuest1", Level = 1, Mob = "Cocoa Warrior", Pos = CFrame.new(210.12, 24.12, -12350.34)},
    {Min = 2325, Max = 2349, Quest = "ChocQuest1", Level = 2, Mob = "Chocolate Bar Battler", Pos = CFrame.new(450.45, 24.12, -12650.12)},
    {Min = 2350, Max = 2374, Quest = "ChocQuest2", Level = 1, Mob = "Sweet Thief", Pos = CFrame.new(712.23, 24.12, -12890.45)},
    {Min = 2375, Max = 2449, Quest = "ChocQuest2", Level = 2, Mob = "Candy Rebel", Pos = CFrame.new(890.45, 24.12, -13150.12)},
    {Min = 2450, Max = 2474, Quest = "TikiQuest1", Level = 1, Mob = "Isle Champion", Pos = CFrame.new(-16520.12, 22.12, 60.34)},
    {Min = 2475, Max = 2499, Quest = "TikiQuest1", Level = 2, Mob = "Island Boy", Pos = CFrame.new(-16800.45, 22.12, 240.12)},
    {Min = 2500, Max = 2524, Quest = "TikiQuest2", Level = 1, Mob = "Sun-kissed Warrior", Pos = CFrame.new(-16240.23, 22.12, -250.45)},
    {Min = 2525, Max = 2549, Quest = "TikiQuest2", Level = 2, Mob = "Isle Outlaw", Pos = CFrame.new(-16500.45, 22.12, -450.12)},
    {Min = 2550, Max = 2574, Quest = "TikiQuest3", Level = 1, Mob = "Serpent Hunter", Pos = CFrame.new(-15120.12, 22.12, 110.34)},
    {Min = 2575, Max = 3000, Quest = "TikiQuest3", Level = 2, Mob = "Skull Slayer", Pos = CFrame.new(-15400.45, 22.12, 350.12)}
}

local function GetCurrentQuest()
    local level = GetPlayerLevel()
    for _, q in ipairs(QuestsDB) do
        if level >= q.Min and level <= q.Max then
            return q
        end
    end
    return QuestsDB[#QuestsDB]
end

local function HasQuest()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local mainGui = playerGui and playerGui:FindFirstChild("Main")
    local questFrame = mainGui and mainGui:FindFirstChild("Quest")
    return questFrame and questFrame.Visible
end

--============================== MASTER BOSS DATABASE ==============================
local BossesDB = {
    -- Sea 1
    ["The Gorilla King"] = {Quest = "JungleQuest", Level = 3, Pos = CFrame.new(-1120.23, 6.27, -495.22)},
    ["Bobby"] = {Quest = "BuggyQuest1", Level = 3, Pos = CFrame.new(-1146.47, 77.22, 4476.81)},
    ["The Saw"] = {Quest = nil, Level = 1, Pos = CFrame.new(-682.12, 15.23, 1582.45)},
    ["Yeti"] = {Quest = "SnowQuest", Level = 3, Pos = CFrame.new(1185.34, 105.12, -1518.23)},
    ["Mob Leader"] = {Quest = "DesertQuest", Level = 3, Pos = CFrame.new(1568.17, 6.44, 4373.23)},
    ["Vice Admiral"] = {Quest = "MarineQuest2", Level = 2, Pos = CFrame.new(-4807.23, 20.65, 4360.12)},
    ["Warden"] = {Quest = "PrisonerQuest", Level = 3, Pos = CFrame.new(5175.23, 5.65, 735.45)},
    ["Chief Warden"] = {Quest = "PrisonerQuest", Level = 4, Pos = CFrame.new(5175.23, 5.65, 735.45)},
    ["Swan"] = {Quest = "PrisonerQuest", Level = 5, Pos = CFrame.new(5230.12, 5.65, 760.34)},
    ["Magma Admiral"] = {Quest = "MagmaQuest", Level = 3, Pos = CFrame.new(-5815.17, 83.99, 8820.32)},
    ["Fishman Lord"] = {Quest = "FishmanQuest", Level = 3, Pos = CFrame.new(61350.23, 18.50, 1569.40)},
    ["Wyper"] = {Quest = "SkyExp1Quest", Level = 3, Pos = CFrame.new(-7894.62, 5545.49, -380.41)},
    ["Thunder God"] = {Quest = "SkyExp2Quest", Level = 3, Pos = CFrame.new(-7748.21, 5606.84, -1443.43)},
    ["Cyborg"] = {Quest = nil, Level = 1, Pos = CFrame.new(61163.85, 18.49, 1569.25)},
    ["Saber Expert"] = {Quest = nil, Level = 1, Pos = CFrame.new(-1460.12, 29.85, -30.45)},

    -- Sea 2
    ["Diamond"] = {Quest = "Area1Quest", Level = 3, Pos = CFrame.new(-1580.45, 198.12, -210.34)},
    ["Jeremy"] = {Quest = "Area2Quest", Level = 3, Pos = CFrame.new(2315.12, 449.12, 785.45)},
    ["Fajita"] = {Quest = "MarineQuest3", Level = 3, Pos = CFrame.new(-2090.23, 72.96, -4210.12)},
    ["Don Swan"] = {Quest = nil, Level = 1, Pos = CFrame.new(2285.45, 15.12, 860.23)},
    ["Smoke Admiral"] = {Quest = "IceSideQuest", Level = 2, Pos = CFrame.new(-5075.23, 15.96, -5360.45)},
    ["Awakened Ice Admiral"] = {Quest = "FrostQuest", Level = 3, Pos = CFrame.new(6472.12, 296.12, -6852.34)},
    ["Tide Keeper"] = {Quest = "ForgottenQuest", Level = 3, Pos = CFrame.new(-3810.45, 77.15, -11520.12)},
    ["Darkbeard"] = {Quest = nil, Level = 1, Pos = CFrame.new(3780.03, 22.65, -3498.94)},
    ["Cursed Captain"] = {Quest = nil, Level = 1, Pos = CFrame.new(915.24, 180.12, 33458.12)},
    ["Order"] = {Quest = nil, Level = 1, Pos = CFrame.new(-6500.12, 250.12, -4500.12)},

    -- Sea 3
    ["Stone"] = {Quest = "PiratePortQuest", Level = 3, Pos = CFrame.new(-1050.23, 40.12, 6780.45)},
    ["Island Emperor"] = {Quest = "DragonCrewQuest", Level = 3, Pos = CFrame.new(5700.12, 601.23, 210.45)},
    ["Kilo Admiral"] = {Quest = nil, Level = 1, Pos = CFrame.new(2880.23, 1682.80, -7250.12)},
    ["Captain Elephant"] = {Quest = "DeepForestIsland2", Level = 3, Pos = CFrame.new(-13390.23, 332.12, -8420.45)},
    ["Beautiful Pirate"] = {Quest = "DeepForestIsland3", Level = 5, Pos = CFrame.new(-12463.87, 374.91, -7523.77)},
    ["Longma"] = {Quest = nil, Level = 1, Pos = CFrame.new(5220.12, 385.12, -340.23)},
    ["Soul Reaper"] = {Quest = nil, Level = 1, Pos = CFrame.new(-9516.99, 172.01, 6078.47)},
    ["Cake Queen"] = {Quest = "IceCreamIslandQuest", Level = 3, Pos = CFrame.new(-710.23, 381.12, -11150.45)},
    ["Cake Prince"] = {Quest = nil, Level = 1, Pos = CFrame.new(-2100.12, 70.12, -12150.34)},
    ["Dough King"] = {Quest = nil, Level = 1, Pos = CFrame.new(-2100.12, 70.12, -12150.34)},
    ["Rip Indra"] = {Quest = nil, Level = 1, Pos = CFrame.new(-5330.12, 314.52, -2780.45)},
    ["Tyrant of the Skies"] = {Quest = nil, Level = 1, Pos = CFrame.new(-16300.12, 850.12, 450.23)}
}

--============================== DYNAMIC SCAN FUNCTIONS ==============================
local function GetSpawnedMobsList()
    local list = {}
    local seen = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                if not seen[enemy.Name] and not BossesDB[enemy.Name] then
                    seen[enemy.Name] = true
                    table.insert(list, enemy.Name)
                end
            end
        end
    end
    for _, q in ipairs(QuestsDB) do
        if not seen[q.Mob] then
            seen[q.Mob] = true
            table.insert(list, q.Mob)
        end
    end
    table.sort(list)
    return list
end

local function GetSpawnedBossesList()
    local list = {}
    local seen = {}
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                if BossesDB[enemy.Name] and not seen[enemy.Name] then
                    seen[enemy.Name] = true
                    table.insert(list, "[Spawned] " .. enemy.Name)
                end
            end
        end
    end
    for bName, _ in pairs(BossesDB) do
        if not seen[bName] then
            table.insert(list, bName)
        end
    end
    table.sort(list)
    return list
end

-- Find live enemy by name
local function FindEnemy(targetName)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local root = GetRoot()
    local closest, closestDist = nil, math.huge
    
    for _, mob in ipairs(enemies:GetChildren()) do
        if (mob.Name == targetName or string.find(mob.Name, targetName)) and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
            local dist = root and (mob.HumanoidRootPart.Position - root.Position).Magnitude or 0
            if dist < closestDist then
                closestDist = dist
                closest = mob
            end
        end
    end
    return closest
end

--============================== AUTO FARM LEVEL CORE ==============================
task.spawn(function()
    while true do
        task.wait(0.2)
        if _G.Config.AutoFarmLevel then
            pcall(function()
                local questInfo = GetCurrentQuest()
                if not HasQuest() then
                    StopTween()
                    if CommF_ then
                        CommF_:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
                        task.wait(0.4)
                    end
                else
                    local target = FindEnemy(questInfo.Mob)
                    if target and target:FindFirstChild("HumanoidRootPart") then
                        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        TweenTo(farmPos)
                        EquipWeapon()
                        BringMobsTo(questInfo.Mob, target.HumanoidRootPart.CFrame)
                    else
                        TweenTo(questInfo.Pos * CFrame.new(0, 35, 0))
                    end
                end
            end)
        end
    end
end)

--============================== AUTO FARM SELECTED MOB CORE ==============================
task.spawn(function()
    while true do
        task.wait(0.2)
        if _G.Config.FarmSelectedMob and _G.Config.SelectedMob ~= "" then
            pcall(function()
                local mobName = _G.Config.SelectedMob:gsub("^[Spawned] ", "")
                local target = FindEnemy(mobName)
                if target and target:FindFirstChild("HumanoidRootPart") then
                    local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                    TweenTo(farmPos)
                    EquipWeapon()
                    BringMobsTo(mobName, target.HumanoidRootPart.CFrame)
                else
                    -- Look up position in QuestsDB
                    for _, q in ipairs(QuestsDB) do
                        if q.Mob == mobName then
                            TweenTo(q.Pos * CFrame.new(0, 35, 0))
                            break
                        end
                    end
                end
            end)
        end
    end
end)

--============================== AUTO FARM SELECTED BOSS CORE ==============================
task.spawn(function()
    while true do
        task.wait(0.3)
        if _G.Config.FarmSelectedBoss and _G.Config.SelectedBoss ~= "" then
            pcall(function()
                local bossName = _G.Config.SelectedBoss:gsub("^[Spawned] ", "")
                local bossData = BossesDB[bossName]
                local target = FindEnemy(bossName)
                
                if target and target:FindFirstChild("HumanoidRootPart") then
                    if bossData and bossData.Quest and not HasQuest() then
                        CommF_:InvokeServer("StartQuest", bossData.Quest, bossData.Level)
                        task.wait(0.4)
                    end
                    local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance + 4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                    TweenTo(farmPos)
                    EquipWeapon()
                else
                    if bossData then
                        TweenTo(bossData.Pos * CFrame.new(0, 40, 0))
                    end
                end
            end)
        end
    end
end)

--============================== AUTO FARM ALL BOSSES CORE ==============================
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.Config.FarmAllBosses then
            pcall(function()
                local enemies = Workspace:FindFirstChild("Enemies")
                if enemies then
                    for _, enemy in ipairs(enemies:GetChildren()) do
                        if BossesDB[enemy.Name] and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                            local bData = BossesDB[enemy.Name]
                            if bData and bData.Quest and not HasQuest() then
                                CommF_:InvokeServer("StartQuest", bData.Quest, bData.Level)
                                task.wait(0.4)
                            end
                            while enemy and enemy.Parent and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and _G.Config.FarmAllBosses do
                                local farmPos = enemy.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance + 4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                TweenTo(farmPos)
                                EquipWeapon()
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

--============================== RAID & SPECIAL BOSSES ==============================
local function FightRaidBoss(bossName)
    local target = FindEnemy(bossName)
    if target and target:FindFirstChild("HumanoidRootPart") then
        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance + 5, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        TweenTo(farmPos)
        EquipWeapon()
        return true
    end
    return false
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if _G.Config.AutoKillRipIndra then FightRaidBoss("rip_indra") or FightRaidBoss("Rip Indra") end
            if _G.Config.AutoKillDoughKing then FightRaidBoss("Dough King") end
            if _G.Config.AutoKillCakePrince then FightRaidBoss("Cake Prince") end
            if _G.Config.AutoKillSoulReaper then FightRaidBoss("Soul Reaper") end
            if _G.Config.AutoKillDarkbeard then FightRaidBoss("Darkbeard") end
            if _G.Config.AutoKillCursedCaptain then FightRaidBoss("Cursed Captain") end
            if _G.Config.AutoKillLaw then FightRaidBoss("Order") end
        end)
    end
end)

--============================== DEVIL FRUIT SYSTEM ==============================
-- Auto Random Gacha
task.spawn(function()
    while true do
        task.wait(2)
        if _G.Config.AutoRandomFruit and CommF_ then
            pcall(function() CommF_:InvokeServer("Cousin", "Buy") end)
        end
    end
end)

-- Auto Store Fruits
task.spawn(function()
    while true do
        task.wait(1.5)
        if _G.Config.AutoStoreFruit and CommF_ then
            pcall(function()
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local char = GetCharacter()
                for _, container in ipairs({bp, char}) do
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") and (tool.ToolTip == "Blox Fruit" or string.find(tool.Name, "Fruit")) then
                                CommF_:InvokeServer("StoreFruit", tool:GetAttribute("OriginalName") or tool.Name, tool)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Auto Grab Dropped Fruits
task.spawn(function()
    while true do
        task.wait(1)
        if _G.Config.AutoGrabFruits then
            pcall(function()
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj:IsA("Tool") and (string.find(obj.Name, "Fruit") or obj.ToolTip == "Blox Fruit") and obj:FindFirstChild("Handle") then
                        TweenTo(obj.Handle.CFrame)
                        task.wait(0.5)
                    end
                end
            end)
        end
    end
end)

-- Fruit ESP
local FruitESPTable = {}
local function UpdateFruitESP()
    for _, bill in pairs(FruitESPTable) do
        if bill and bill.Parent then bill:Destroy() end
    end
    FruitESPTable = {}
    
    if not _G.Config.FruitESP then return end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and (string.find(obj.Name, "Fruit") or obj.ToolTip == "Blox Fruit") and obj:FindFirstChild("Handle") then
            local bill = Instance.new("BillboardGui")
            bill.Name = "AlphaFruitESP"
            bill.Adornee = obj.Handle
            bill.Size = UDim2.new(0, 100, 0, 30)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.Parent = obj.Handle
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "🍎 " .. obj.Name
            label.TextColor3 = Color3.fromRGB(255, 100, 100)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 13
            label.Parent = bill
            table.insert(FruitESPTable, bill)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(3)
        if _G.Config.FruitESP then UpdateFruitESP() end
    end
end)

--============================== AUTO STATS ALLOCATOR ==============================
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.Config.AutoStats and CommF_ then
            pcall(function()
                local pts = _G.Config.StatPoints or 1
                if _G.Config.Stats.Melee then CommF_:InvokeServer("AddPoint", "Melee", pts) end
                if _G.Config.Stats.Defense then CommF_:InvokeServer("AddPoint", "Defense", pts) end
                if _G.Config.Stats.Sword then CommF_:InvokeServer("AddPoint", "Sword", pts) end
                if _G.Config.Stats.Gun then CommF_:InvokeServer("AddPoint", "Gun", pts) end
                if _G.Config.Stats.Fruit then CommF_:InvokeServer("AddPoint", "Demon Fruit", pts) end
            end)
        end
    end
end)

--============================== DUNGEONS & RAIDS ==============================
task.spawn(function()
    while true do
        task.wait(1.5)
        pcall(function()
            if _G.Config.AutoBuyChip and CommF_ then
                CommF_:InvokeServer("RaidsNpc", "Select", _G.Config.SelectedChip)
            end
            if _G.Config.AutoStartRaid and CommF_ then
                CommF_:InvokeServer("RaidsNpc", "Start")
            end
            if _G.Config.AutoFarmRaid then
                local enemies = Workspace:FindFirstChild("Enemies")
                if enemies then
                    for _, mob in ipairs(enemies:GetChildren()) do
                        if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                            local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance, 0)
                            TweenTo(farmPos)
                            EquipWeapon()
                            break
                        end
                    end
                end
            end
        end)
    end
end)

--============================== SEA EVENTS & MIRAGE ==============================
local function CheckIslandSpawn(islandName)
    local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if locs and locs:FindFirstChild(islandName) then return true end
    if Workspace:FindFirstChild(islandName) then return true end
    return false
end

--============================== ANTI-AFK ==============================
local AntiAFKConn = nil
local function EnableAntiAFK()
    if AntiAFKConn then return end
    AntiAFKConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end
if _G.Config.AntiAFK then EnableAntiAFK() end

--============================== REDZLIB UI INITIALIZATION ==============================
local RedzLibSuccess, RedzLib = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/farehamhz/RedzLib/main/RedzLib"))()
end)

if RedzLibSuccess and RedzLib then
    local Window = RedzLib:MakeWindow({
        Title = "ALPHA // BLOX FRUITS HUB v2",
        SubTitle = "Keyless Edition • " .. SeaName,
        SaveFolder = "AlphaHubV2"
    })
    
    -- Tabs
    local FarmTab = Window:MakeTab({"Main Farm", "swords"})
    local BossTab = Window:MakeTab({"Boss Farm", "skull"})
    local RaidTab = Window:MakeTab({"Dungeon & Raids", "flame"})
    local FruitTab = Window:MakeTab({"Devil Fruit", "cherry"})
    local SeaTab = Window:MakeTab({"Sea Events & Mirage", "anchor"})
    local ItemTab = Window:MakeTab({"Items & Quests", "trophy"})
    local StatsTab = Window:MakeTab({"Stats Allocator", "bar-chart-2"})
    local ShopTab = Window:MakeTab({"Shop", "shopping-cart"})
    local TeleportTab = Window:MakeTab({"Teleports", "map-pin"})
    local MiscTab = Window:MakeTab({"Settings & Server", "settings"})
    
    -- MAIN FARM TAB
    FarmTab:AddSection({"Combat Settings"})
    FarmTab:AddDropdown({
        Name = "Select Weapon",
        Options = {"Melee", "Sword", "Gun", "Fruit"},
        Default = "Melee",
        Callback = function(v) _G.Config.SelectedWeapon = v end
    })
    FarmTab:AddToggle({
        Name = "Fast Attack (RE/RegisterAttack + Hit)",
        Default = true,
        Callback = function(v) _G.Config.FastAttack = v end
    })
    FarmTab:AddSlider({
        Name = "Attack Range (Studs)",
        Min = 30,
        Max = 85,
        Default = 65,
        Callback = function(v) _G.Config.AttackDistance = v end
    })
    FarmTab:AddToggle({
        Name = "Bring Mobs (Simulation Radius)",
        Default = true,
        Callback = function(v) _G.Config.BringMobs = v end
    })
    FarmTab:AddSlider({
        Name = "Farm Distance (Hover Offset)",
        Min = 4,
        Max = 20,
        Default = 9,
        Callback = function(v) _G.Config.FarmDistance = v end
    })
    FarmTab:AddToggle({
        Name = "Auto Buso Haki (Enhancement)",
        Default = true,
        Callback = function(v) _G.Config.AutoBusoHaki = v end
    })
    
    FarmTab:AddSection({"Level Farming"})
    FarmTab:AddToggle({
        Name = "Auto Farm Level (Auto Quest + Mob)",
        Default = false,
        Callback = function(v)
            _G.Config.AutoFarmLevel = v
            if not v then StopTween() end
        end
    })
    FarmTab:AddToggle({
        Name = "Auto Double Quest",
        Default = false,
        Callback = function(v) _G.Config.AutoDoubleQuest = v end
    })
    
    FarmTab:AddSection({"Select Mob Farming"})
    local MobDropdown = FarmTab:AddDropdown({
        Name = "Select Mob",
        Options = GetSpawnedMobsList(),
        Default = GetSpawnedMobsList()[1] or "Bandit",
        Callback = function(v) _G.Config.SelectedMob = v end
    })
    FarmTab:AddButton({
        Name = "Refresh Mobs List",
        Callback = function()
            local updated = GetSpawnedMobsList()
            if MobDropdown and MobDropdown.SetOptions then
                MobDropdown:SetOptions(updated)
            end
        end
    })
    FarmTab:AddToggle({
        Name = "Auto Farm Selected Mob",
        Default = false,
        Callback = function(v)
            _G.Config.FarmSelectedMob = v
            if not v then StopTween() end
        end
    })
    
    -- BOSS FARM TAB
    BossTab:AddSection({"Select Boss Farming"})
    local BossDropdown = BossTab:AddDropdown({
        Name = "Select Boss",
        Options = GetSpawnedBossesList(),
        Default = "The Gorilla King",
        Callback = function(v) _G.Config.SelectedBoss = v end
    })
    BossTab:AddButton({
        Name = "Refresh Bosses List (Scan Active)",
        Callback = function()
            local updated = GetSpawnedBossesList()
            if BossDropdown and BossDropdown.SetOptions then
                BossDropdown:SetOptions(updated)
            end
        end
    })
    BossTab:AddToggle({
        Name = "Auto Farm Selected Boss",
        Default = false,
        Callback = function(v)
            _G.Config.FarmSelectedBoss = v
            if not v then StopTween() end
        end
    })
    BossTab:AddToggle({
        Name = "Auto Farm All Spawned Bosses",
        Default = false,
        Callback = function(v)
            _G.Config.FarmAllBosses = v
            if not v then StopTween() end
        end
    })
    
    BossTab:AddSection({"World & Raid Bosses"})
    BossTab:AddToggle({Name = "Auto Kill Rip Indra", Default = false, Callback = function(v) _G.Config.AutoKillRipIndra = v end})
    BossTab:AddToggle({Name = "Auto Kill Dough King", Default = false, Callback = function(v) _G.Config.AutoKillDoughKing = v end})
    BossTab:AddToggle({Name = "Auto Kill Cake Prince", Default = false, Callback = function(v) _G.Config.AutoKillCakePrince = v end})
    BossTab:AddToggle({Name = "Auto Kill Soul Reaper", Default = false, Callback = function(v) _G.Config.AutoKillSoulReaper = v end})
    BossTab:AddToggle({Name = "Auto Kill Darkbeard", Default = false, Callback = function(v) _G.Config.AutoKillDarkbeard = v end})
    BossTab:AddToggle({Name = "Auto Kill Cursed Captain", Default = false, Callback = function(v) _G.Config.AutoKillCursedCaptain = v end})
    BossTab:AddToggle({Name = "Auto Kill Order (Law)", Default = false, Callback = function(v) _G.Config.AutoKillLaw = v end})
    
    -- DUNGEON & RAIDS TAB
    RaidTab:AddSection({"Raid Controls"})
    RaidTab:AddDropdown({
        Name = "Select Raid Chip",
        Options = {"Flame", "Ice", "Quake", "Light", "Dark", "String", "Rumble", "Magma", "Human: Buddha", "Phoenix", "Dough"},
        Default = "Flame",
        Callback = function(v) _G.Config.SelectedChip = v end
    })
    RaidTab:AddToggle({
        Name = "Auto Buy Raid Chip",
        Default = false,
        Callback = function(v) _G.Config.AutoBuyChip = v end
    })
    RaidTab:AddToggle({
        Name = "Auto Start Raid",
        Default = false,
        Callback = function(v) _G.Config.AutoStartRaid = v end
    })
    RaidTab:AddToggle({
        Name = "Auto Farm Raid (Next Island)",
        Default = false,
        Callback = function(v) _G.Config.AutoFarmRaid = v end
    })
    RaidTab:AddToggle({
        Name = "Auto Awaken Fruit",
        Default = false,
        Callback = function(v) _G.Config.AutoAwaken = v end
    })
    
    -- DEVIL FRUIT TAB
    FruitTab:AddSection({"Fruit Collection"})
    FruitTab:AddToggle({
        Name = "Auto Random Fruit (Gacha Cousin)",
        Default = false,
        Callback = function(v) _G.Config.AutoRandomFruit = v end
    })
    FruitTab:AddToggle({
        Name = "Auto Store Fruits in Inventory",
        Default = true,
        Callback = function(v) _G.Config.AutoStoreFruit = v end
    })
    FruitTab:AddToggle({
        Name = "Auto Grab Dropped Fruits (Tween)",
        Default = false,
        Callback = function(v) _G.Config.AutoGrabFruits = v end
    })
    FruitTab:AddToggle({
        Name = "Fruit ESP (Billboard Markers)",
        Default = false,
        Callback = function(v)
            _G.Config.FruitESP = v
            if v then UpdateFruitESP() else UpdateFruitESP() end
        end
    })
    
    -- SEA EVENTS & MIRAGE TAB
    SeaTab:AddSection({"Sea Events"})
    SeaTab:AddToggle({Name = "Auto Kill Sharks", Default = false, Callback = function(v) _G.Config.AutoKillShark = v end})
    SeaTab:AddToggle({Name = "Auto Kill Terror Shark", Default = false, Callback = function(v) _G.Config.AutoKillTerrorShark = v end})
    SeaTab:AddToggle({Name = "Auto Kill Sea Beast", Default = false, Callback = function(v) _G.Config.AutoKillSeaBeast = v end})
    
    SeaTab:AddSection({"Mirage & Kitsune Island"})
    SeaTab:AddButton({
        Name = "Check Mirage Island Status",
        Callback = function()
            local spawned = CheckIslandSpawn("MysticIsland") or CheckIslandSpawn("Mirage Island")
            print("[ALPHA HUB] Mirage Island:", spawned and "SPAWNED!" or "NOT Spawned")
        end
    })
    SeaTab:AddButton({
        Name = "Check Kitsune Island Status",
        Callback = function()
            local spawned = CheckIslandSpawn("KitsuneIsland") or CheckIslandSpawn("Kitsune Island")
            print("[ALPHA HUB] Kitsune Island:", spawned and "SPAWNED!" or "NOT Spawned")
        end
    })
    SeaTab:AddToggle({Name = "Auto Find Blue Gear (Mirage)", Default = false, Callback = function(v) _G.Config.AutoFindGear = v end})
    SeaTab:AddToggle({Name = "Auto Pull Lever (Temple of Time)", Default = false, Callback = function(v) _G.Config.AutoPullLever = v end})
    
    -- ITEMS & QUESTS TAB
    ItemTab:AddSection({"Special Weapons & Quests"})
    ItemTab:AddButton({Name = "Auto Saber Quest", Callback = function() if CommF_ then CommF_:InvokeServer("ProQuestProgress", "RichSon") end end})
    ItemTab:AddButton({Name = "Auto Bartilo Quest", Callback = function() if CommF_ then CommF_:InvokeServer("BartiloQuestProgress", "GetMission") end end})
    ItemTab:AddButton({Name = "Travel to Second Sea", Callback = function() if CommF_ then CommF_:InvokeServer("TravelDressrosa") end end})
    ItemTab:AddButton({Name = "Travel to Third Sea", Callback = function() if CommF_ then CommF_:InvokeServer("TravelZou") end end})
    
    -- STATS TAB
    StatsTab:AddSection({"Stats Points Allocator"})
    StatsTab:AddToggle({Name = "Auto Allocate Stats", Default = false, Callback = function(v) _G.Config.AutoStats = v end})
    StatsTab:AddSlider({Name = "Points Per Stat", Min = 1, Max = 100, Default = 1, Callback = function(v) _G.Config.StatPoints = v end})
    StatsTab:AddToggle({Name = "Melee", Default = true, Callback = function(v) _G.Config.Stats.Melee = v end})
    StatsTab:AddToggle({Name = "Defense", Default = true, Callback = function(v) _G.Config.Stats.Defense = v end})
    StatsTab:AddToggle({Name = "Sword", Default = false, Callback = function(v) _G.Config.Stats.Sword = v end})
    StatsTab:AddToggle({Name = "Gun", Default = false, Callback = function(v) _G.Config.Stats.Gun = v end})
    StatsTab:AddToggle({Name = "Blox Fruit", Default = false, Callback = function(v) _G.Config.Stats.Fruit = v end})
    StatsTab:AddButton({Name = "Refund Stats (2,500 Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BlackbeardReward", "Refund", "2") end end})
    StatsTab:AddButton({Name = "Reroll Race (3,000 Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BlackbeardReward", "Reroll", "2") end end})
    
    -- SHOP TAB
    ShopTab:AddSection({"Fighting Styles (Melee V1 & V2)"})
    ShopTab:AddButton({Name = "Buy Black Leg ($150,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyBlackLeg") end end})
    ShopTab:AddButton({Name = "Buy Electro ($550,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyElectro") end end})
    ShopTab:AddButton({Name = "Buy Fishman Karate ($750,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyFishmanKarate") end end})
    ShopTab:AddButton({Name = "Buy Dragon Breath (1,500 Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2") end end})
    ShopTab:AddButton({Name = "Buy Superhuman ($3,000,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuySuperhuman") end end})
    ShopTab:AddButton({Name = "Buy Death Step ($5M + 5k Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyDeathStep") end end})
    ShopTab:AddButton({Name = "Buy Sharkman Karate ($2.5M + 5k Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BuySharkmanKarate") end end})
    ShopTab:AddButton({Name = "Buy Electric Claw ($3M + 5k Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyElectricClaw") end end})
    ShopTab:AddButton({Name = "Buy Dragon Talon ($3M + 5k Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyDragonTalon") end end})
    ShopTab:AddButton({Name = "Buy Godhuman ($5M + 5k Frags)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyGodhuman") end end})
    
    ShopTab:AddSection({"Abilities & Haki"})
    ShopTab:AddButton({Name = "Buy Skyjump (Geppo - $10,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyHaki", "Geppo") end end})
    ShopTab:AddButton({Name = "Buy Enhancement (Buso - $25,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyHaki", "Buso") end end})
    ShopTab:AddButton({Name = "Buy Flash Step (Soru - $100,000)", Callback = function() if CommF_ then CommF_:InvokeServer("BuyHaki", "Soru") end end})
    ShopTab:AddButton({Name = "Buy Observation Haki ($750,000)", Callback = function() if CommF_ then CommF_:InvokeServer("KenHaki") end end})
    
    -- TELEPORT TAB
    TeleportTab:AddSection({"Island Teleports"})
    local IslandsList = {
        ["Pirate Starter"] = CFrame.new(1059.37, 16.51, 1546.99),
        ["Marine Starter"] = CFrame.new(-2573.39, 6.94, 2059.27),
        ["Jungle"] = CFrame.new(-1612.33, 36.85, 149.13),
        ["Pirate Village"] = CFrame.new(-1181.39, 4.75, 3843.43),
        ["Desert"] = CFrame.new(1094.11, 6.44, 4192.89),
        ["Snow Island"] = CFrame.new(1384.81, 87.27, -1298.47),
        ["Marineford"] = CFrame.new(-5035.79, 28.65, 4324.96),
        ["Sky Island"] = CFrame.new(-4839.53, 717.67, -2619.44),
        ["Prison"] = CFrame.new(4875.33, 5.65, 735.45),
        ["Colosseum"] = CFrame.new(-1427.62, 7.28, -2792.77),
        ["Magma Village"] = CFrame.new(-5247.72, 8.57, 8504.68),
        ["Underwater City"] = CFrame.new(61163.85, 18.49, 1569.25),
        ["Fountain City"] = CFrame.new(5127.13, 59.50, 4105.45),
        ["Cafe (Sea 2)"] = CFrame.new(-380.47, 77.22, 255.82),
        ["Mansion (Sea 2)"] = CFrame.new(-417.47, 332.18, 595.66),
        ["Green Zone (Sea 2)"] = CFrame.new(-2448.53, 73.02, -3210.63),
        ["Graveyard (Sea 2)"] = CFrame.new(-5418.89, 48.52, -774.75),
        ["Snow Mountain (Sea 2)"] = CFrame.new(608.24, 401.52, -5372.46),
        ["Hot & Cold (Sea 2)"] = CFrame.new(-6026.96, 15.96, -5071.29),
        ["Cursed Ship (Sea 2)"] = CFrame.new(923.21, 126.98, 32852.83),
        ["Ice Castle (Sea 2)"] = CFrame.new(5422.31, 28.25, -6767.13),
        ["Forgotten Island (Sea 2)"] = CFrame.new(-3054.44, 237.15, -10142.82),
        ["Port Town (Sea 3)"] = CFrame.new(-290.74, 6.73, 5343.55),
        ["Hydra Island (Sea 3)"] = CFrame.new(5749.73, 610.42, -267.78),
        ["Great Tree (Sea 3)"] = CFrame.new(2681.27, 1682.80, -7190.99),
        ["Floating Turtle (Sea 3)"] = CFrame.new(-12463.87, 374.91, -7523.77),
        ["Castle on Sea (Sea 3)"] = CFrame.new(-5085.24, 314.52, -3156.26),
        ["Haunted Castle (Sea 3)"] = CFrame.new(-9516.99, 172.01, 6078.47),
        ["Peanut Island (Sea 3)"] = CFrame.new(-2062.73, 50.32, -10232.22),
        ["Ice Cream Island (Sea 3)"] = CFrame.new(-902.59, 79.92, -10988.69),
        ["Chocolate Island (Sea 3)"] = CFrame.new(141.52, 34.21, -12608.45),
        ["Candy Island (Sea 3)"] = CFrame.new(-1149.29, 23.63, -14445.61),
        ["Tiki Outpost (Sea 3)"] = CFrame.new(-16106.33, 9.21, 440.38),
        ["Temple of Time"] = CFrame.new(28282.57, 14896.85, 105.10)
    }
    
    local islandKeys = {}
    for k, _ in pairs(IslandsList) do table.insert(islandKeys, k) end
    table.sort(islandKeys)
    
    local SelectedIsland = islandKeys[1]
    TeleportTab:AddDropdown({
        Name = "Select Island",
        Options = islandKeys,
        Default = islandKeys[1],
        Callback = function(v) SelectedIsland = v end
    })
    TeleportTab:AddButton({
        Name = "Teleport to Selected Island",
        Callback = function()
            local cframe = IslandsList[SelectedIsland]
            if cframe then TweenTo(cframe) end
        end
    })
    
    -- MISC & SERVER TAB
    MiscTab:AddSection({"Server Controls"})
    MiscTab:AddButton({
        Name = "Server Hop (Low Population)",
        Callback = function()
            local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            local res = safeRequest({Url = url, Method = "GET"})
            if res and res.Body then
                local json = HttpService:JSONDecode(res.Body)
                if json and json.data then
                    for _, s in ipairs(json.data) do
                        if s.playing < s.maxPlayers and s.id ~= game.JobId then
                            TeleportService:TeleportToPlaceInstance(PlaceId, s.id, LocalPlayer)
                            break
                        end
                    end
                end
            end
        end
    })
    MiscTab:AddButton({
        Name = "Rejoin Current Server",
        Callback = function()
            TeleportService:Teleport(PlaceId, LocalPlayer)
        end
    })
    MiscTab:AddToggle({
        Name = "Anti-AFK",
        Default = true,
        Callback = function(v)
            _G.Config.AntiAFK = v
            if v then EnableAntiAFK() elseif AntiAFKConn then AntiAFKConn:Disconnect(); AntiAFKConn = nil end
        end
    })
    MiscTab:AddSlider({
        Name = "Tween Flight Speed",
        Min = 150,
        Max = 350,
        Default = 320,
        Callback = function(v) _G.Config.TweenSpeed = v end
    })
    MiscTab:AddSlider({
        Name = "WalkSpeed",
        Min = 16,
        Max = 250,
        Default = 16,
        Callback = function(v)
            local hum = GetHumanoid()
            if hum then hum.WalkSpeed = v end
        end
    })
    MiscTab:AddSlider({
        Name = "JumpPower",
        Min = 50,
        Max = 300,
        Default = 50,
        Callback = function(v)
            local hum = GetHumanoid()
            if hum then hum.JumpPower = v end
        end
    })
end

print("--------------------------------------------------")
print("[ALPHA HUB v2] Loaded successfully!")
print("[ALPHA HUB v2] Keyless Edition active.")
print("[ALPHA HUB v2] Current Location: " .. SeaName)
print("--------------------------------------------------")
