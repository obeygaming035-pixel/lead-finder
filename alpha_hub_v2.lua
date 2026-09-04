--[[
    Blox Fruits Utility Module (v2 Hardened)
    All features self-contained. No external HTTP dependencies.
    Compatible with: KRNL, Synapse, Wave, Fluxus, Delta, Hydrogen, Arceus X, Solara
]]

--============================== STAGGERED STARTUP ==============================
pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
end)

-- Randomized startup delay to avoid frame-0 detection
task.wait(math.random(20, 50) / 10) -- 2.0 to 5.0 seconds

--============================== CORE SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Place / Sea Identification
local PlaceId = game.PlaceId
local Sea1 = (PlaceId == 2753915549)
local Sea2 = (PlaceId == 4442272183)
local Sea3 = (PlaceId == 7449423635)
local SeaName = Sea1 and "First Sea" or (Sea2 and "Second Sea" or (Sea3 and "Third Sea" or "Blox Fruits"))

-- Safe request wrapper
local safeRequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request

-- Random GUID generator for stealth naming
local function RNG()
    return HttpService:GenerateGUID(false):sub(1, 12)
end

--============================== SOFT ANTI-KICK (NO GLOBAL HOOKS) ==============================
-- Instead of hookmetamethod (which triggers GUI bombing), we use a pcall-wrapped
-- connection-based approach that doesn't modify the global metatable
pcall(function()
    -- Only intercept the Idled event kick, not all kicks globally
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end)

-- NOTE: We intentionally do NOT:
-- 1. hookmetamethod(__namecall) -- triggers GUI bombing detection
-- 2. Block BANEXPLOIT/Security remotes -- legitimate clients never call them, blocking confirms script presence
-- 3. Disable LocalScripts (NeutralizeAntiCheat) -- the game detects when its own scripts are disabled

--============================== SAFE GUI PARENTING ==============================
local function GetSafeGui()
    -- gethui() is the safest -- hidden from game scripts entirely
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    -- Fall back to PlayerGui (less safe but universally compatible)
    return LocalPlayer:WaitForChild("PlayerGui", 10)
end

--============================== LAZY REMOTE INITIALIZATION ==============================
-- Remotes are NOT looked up at startup (suspicious). Instead, found on first use.
local _remoteCache = {}

local function GetRemote(name, className)
    if _remoteCache[name] then return _remoteCache[name] end
    
    -- Try direct path first (fast)
    local remotes = RS:FindFirstChild("Remotes")
    if remotes then
        local r = remotes:FindFirstChild(name)
        if r then
            _remoteCache[name] = r
            return r
        end
    end
    
    -- Deep scan fallback (only if not found directly)
    for _, v in ipairs(RS:GetDescendants()) do
        if v.Name == name and (not className or v:IsA(className)) then
            _remoteCache[name] = v
            return v
        end
    end
    return nil
end

local function CommF()
    return GetRemote("CommF_", "RemoteFunction")
end

local function CommitsRemote()
    return GetRemote("Commits", "RemoteEvent")
end

-- Net module remotes (lazy)
local function GetNetRemote(subName)
    if _remoteCache["Net_" .. subName] then return _remoteCache["Net_" .. subName] end
    local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
    if net then
        local r = net:FindFirstChild(subName)
        if r then
            _remoteCache["Net_" .. subName] = r
            return r
        end
    end
    return nil
end

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
    
    -- Farm Distance Settings
    AdaptiveBossDistance = true,
    MobFarmDistance = 14, -- Normal mobs distance set to 14 studs as requested
    BossFarmDistance = 20, -- Boss distance set to 20 studs
    FarmDistance = 14,
    TweenSpeed = 350, -- Redz Flight Speed (350 studs/s)
    
    -- Combat Mode (M1 vs Skills)
    UseM1 = true,
    FastAttack = true,
    FastAttackSpeed = 0.015, -- Super Fast clicks (Redz style)
    AttackDistance = 120, -- Increased kill aura range to 120 studs as requested
    AutoBusoHaki = true,
    AutoKenHaki = false,
    
    -- Weapon Skills
    UseSkills = false,
    Skill_Z = true,
    Skill_X = true,
    Skill_C = true,
    Skill_V = false,
    Skill_F = false,
    
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

-- Global input isolation guard: when user interacts with UI, combat clicks are muted!
_G.UIInteracting = false

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

-- Strict weapon type identifier
local function IsWeaponType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    local tip = tool:FindFirstChild("ToolTip") and tool.ToolTip or ""
    local name = tool.Name:lower()
    
    if targetType == "Melee" then
        if tip == "Melee" or tool:FindFirstChild("Combat") then return true end
        local meleeStyles = {
            "combat", "black leg", "electro", "water kung fu", "dragon claw",
            "superhuman", "death step", "sharkman karate", "electric claw",
            "dragon talon", "godhuman", "sanguine art", "karate"
        }
        for _, m in ipairs(meleeStyles) do
            if name:find(m) then return true end
        end
        return false
    elseif targetType == "Sword" then
        return tip == "Sword" or tip == "Melee Weapon"
    elseif targetType == "Gun" then
        return tip == "Gun"
    elseif targetType == "Fruit" then
        return tip == "Blox Fruit" or name:find("fruit")
    end
    return false
end

-- Strictly equip only the chosen weapon type (never equips Fruit if Melee selected)
local function EquipWeapon(weaponType)
    weaponType = weaponType or _G.Config.SelectedWeapon or "Melee"
    local char = GetCharacter()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return end
    
    -- 1. If currently equipped tool matches targetType, keep it
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        if IsWeaponType(currentTool, weaponType) then
            return currentTool
        else
            -- Wrong weapon currently held in hands (e.g. Fruit held when Melee was selected):
            -- UNEQUIP IT immediately so it doesn't fire unwanted moves!
            pcall(function() char.Humanoid:UnequipTools() end)
            task.wait(0.05)
        end
    end
    
    -- 2. Search Backpack for exact match
    for _, tool in ipairs(bp:GetChildren()) do
        if IsWeaponType(tool, weaponType) then
            char.Humanoid:EquipTool(tool)
            return tool
        end
    end
    
    -- If not found, DO NOT equip random items!
    return nil
end

-- Auto Buso Haki
local function CheckBusoHaki()
    if not _G.Config.AutoBusoHaki then return end
    local char = GetCharacter()
    if char and not char:FindFirstChild("HasBuso") then
        local cf = CommF()
        if cf then
            pcall(function() cf:InvokeServer("Buso") end)
        end
    end
end

-- Forward declaration of BossesDB
local BossesDB

-- Adaptive farm distance calculator (gives bosses more clearance against AoE stuns)
local function GetOptimalFarmDistance(enemy)
    if not enemy then return _G.Config.MobFarmDistance or 14 end
    local isBoss = (BossesDB and BossesDB[enemy.Name] ~= nil) or (enemy:FindFirstChild("Humanoid") and enemy.Humanoid.MaxHealth > 50000)
    if isBoss then
        if _G.Config.AdaptiveBossDistance then
            local name = enemy.Name:lower()
            if name:find("indra") or name:find("dough") or name:find("cake") or name:find("reaper") or name:find("beast") then
                return 24
            elseif name:find("king") or name:find("admiral") or name:find("warden") or name:find("emperor") or name:find("captain") then
                return 20
            else
                return _G.Config.BossFarmDistance or 20
            end
        else
            return _G.Config.BossFarmDistance or 20
        end
    end
    return _G.Config.MobFarmDistance or 14
end

--============================== REDZ-GRADE SKY TWEEN & HOVER LOCK ENGINE ==============================
local CurrentTween = nil
local FlightBodyVel = nil
local CurrentTargetPos = nil
local IsTravelingSky = false
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

local function GetOrCreateBodyVelocity(root)
    if FlightBodyVel and FlightBodyVel.Parent == root then
        return FlightBodyVel
    end
    if FlightBodyVel then
        pcall(function() FlightBodyVel:Destroy() end)
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AlphaFlightBV"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Parent = root
    FlightBodyVel = bv
    return bv
end

-- Persistent Hover Lock: keeps character rigidly anchored at hover altitude so they NEVER fall into the mob!
local function HoverLock(targetCFrame)
    local root = GetRoot()
    if not root or not root.Parent then return end
    EnableNoclip()
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    root.CFrame = targetCFrame
end

local function StopTween()
    if CurrentTween then
        pcall(function() CurrentTween:Cancel() end)
        CurrentTween = nil
    end
    CurrentTargetPos = nil
    IsTravelingSky = false
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

local function FullResetMovement()
    StopTween()
    if FlightBodyVel then
        pcall(function() FlightBodyVel:Destroy() end)
        FlightBodyVel = nil
    end
    DisableNoclip()
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

LocalPlayer.CharacterAdded:Connect(function()
    FullResetMovement()
end)

local function TweenTo(targetCFrame)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent or not hum then return end
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    
    -- Close enough: lock position immediately and maintain hover
    if distance < 15 then
        StopTween()
        HoverLock(targetCFrame)
        return
    end
    
    local speed = _G.Config.TweenSpeed or 350
    if speed < 280 then speed = 350 end
    
    -- 1. LOCAL HOVER / SHORT RANGE (<= 250 studs)
    if distance <= 250 then
        EnableNoclip()
        local bv = GetOrCreateBodyVelocity(root)
        local dir = (targetCFrame.Position - root.Position).Unit
        bv.Velocity = dir * speed -- Physics velocity matches CFrame movement to eliminate snap-back!
        hum.PlatformStand = true -- Prevents character walking physics from conflicting with flight
        
        local time = distance / speed
        if CurrentTween then CurrentTween:Cancel() end
        CurrentTween = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        CurrentTween.Completed:Connect(function()
            if hum and hum.Parent then hum.PlatformStand = false end
            HoverLock(targetCFrame)
        end)
        CurrentTween:Play()
        return CurrentTween
    end
    
    -- 2. LONG RANGE / CROSS-ISLAND FLIGHT (> 250 studs)
    if CurrentTargetPos and (CurrentTargetPos - targetCFrame.Position).Magnitude < 30 and IsTravelingSky then
        return -- Already sky-traveling to this target
    end
    
    CurrentTargetPos = targetCFrame.Position
    IsTravelingSky = true
    
    task.spawn(function()
        -- Try instant game door entrance for extreme distances (> 2500 studs)
        if distance > 2500 then
            local cf = CommF()
            if cf then
                pcall(function() cf:InvokeServer("requestEntrance", targetCFrame.Position) end)
                task.wait(0.35)
                if not root or not root.Parent then IsTravelingSky = false; return end
                distance = (targetCFrame.Position - root.Position).Magnitude
                if distance < 120 then
                    StopTween()
                    HoverLock(targetCFrame)
                    return
                end
            end
        end
        
        EnableNoclip()
        local bv = GetOrCreateBodyVelocity(root)
        hum.PlatformStand = true
        
        -- High flight altitude: Y = 380+ (immune to water damage, clears all trees/mountains)
        local skyY = math.max(380, math.max(root.Position.Y, targetCFrame.Position.Y) + 70)
        
        -- Ascend to sky altitude
        if root.Position.Y < (skyY - 30) then
            local upCF = CFrame.new(root.Position.X, skyY, root.Position.Z)
            local upDist = (upCF.Position - root.Position).Magnitude
            bv.Velocity = Vector3.new(0, speed, 0)
            local upTween = TweenService:Create(root, TweenInfo.new(upDist / speed, Enum.EasingStyle.Linear), {CFrame = upCF})
            CurrentTween = upTween
            upTween:Play()
            upTween.Completed:Wait()
        end
        
        if not root or not root.Parent or not IsTravelingSky then return end
        
        -- Fly horizontally across sky to target X, Z
        local skyTargetCF = CFrame.new(targetCFrame.Position.X, skyY, targetCFrame.Position.Z)
        local hDist = (skyTargetCF.Position - root.Position).Magnitude
        if hDist > 25 then
            local hDir = (skyTargetCF.Position - root.Position).Unit
            bv.Velocity = hDir * speed
            local hTween = TweenService:Create(root, TweenInfo.new(hDist / speed, Enum.EasingStyle.Linear), {CFrame = skyTargetCF})
            CurrentTween = hTween
            hTween:Play()
            hTween.Completed:Wait()
        end
        
        if not root or not root.Parent or not IsTravelingSky then return end
        
        -- Descend directly to target position
        local downDist = (targetCFrame.Position - root.Position).Magnitude
        local downDir = (targetCFrame.Position - root.Position).Unit
        bv.Velocity = downDir * speed
        local downTween = TweenService:Create(root, TweenInfo.new(downDist / speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        CurrentTween = downTween
        downTween:Play()
        downTween.Completed:Wait()
        
        IsTravelingSky = false
        if hum and hum.Parent then hum.PlatformStand = false end
        HoverLock(targetCFrame)
    end)
end

--============================== FAST ATTACK & SKILL ENGINE ==============================
local _lastAttackTime = 0
local _lastSkillCastTime = 0
local _skillCycle = {"Z", "X", "C", "V", "F"}
local _skillCycleIndex = 1

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

-- Fast M1 Clicks (Redz Hub style: 0.015s blazing speed)
local function FastAttack()
    if not _G.Config.FastAttack or not _G.Config.UseM1 then return end
    if _G.UIInteracting then return end -- Prevent weapon swings while clicking in UI!
    
    local char = GetCharacter()
    if not char then return end
    
    -- Strict check: only activate if equipped weapon matches selected weapon
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not IsWeaponType(tool, _G.Config.SelectedWeapon) then
        EquipWeapon(_G.Config.SelectedWeapon)
        return
    end
    
    local now = tick()
    local cd = _G.Config.FastAttackSpeed or 0.015
    if (now - _lastAttackTime) < cd then return end
    _lastAttackTime = now
    
    local enemies = GetBladeHits()
    if #enemies > 0 then
        local regAttack = GetNetRemote("RE/RegisterAttack")
        local regHit = GetNetRemote("RE/RegisterHit")
        if regAttack and regHit then
            pcall(function()
                regAttack:FireServer(0)
                local args = {nil, {}}
                for i, v in ipairs(enemies) do
                    if not args[1] and v:FindFirstChild("Head") then
                        args[1] = v.Head
                    end
                    args[2][i] = {v, v.HumanoidRootPart}
                end
                regHit:FireServer(unpack(args))
            end)
        end
        
        -- Activate equipped weapon ONLY (never fires if holding fruit by mistake)
        if tool and _G.Config.UseM1 and not _G.UIInteracting then
            pcall(function() tool:Activate() end)
        end
    end
end

-- Cast skills with selected weapon ONLY
local function CastNextSkill()
    if not _G.Config.UseSkills then return end
    if _G.UIInteracting then return end
    
    local now = tick()
    if (now - _lastSkillCastTime) < 1.0 then return end
    
    local char = GetCharacter()
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not IsWeaponType(tool, _G.Config.SelectedWeapon) then
        EquipWeapon(_G.Config.SelectedWeapon)
        return
    end
    
    local enemies = GetBladeHits()
    if #enemies == 0 then return end
    
    local chosenKey = nil
    for i = 1, #_skillCycle do
        local key = _skillCycle[_skillCycleIndex]
        _skillCycleIndex = (_skillCycleIndex % #_skillCycle) + 1
        if _G.Config["Skill_" .. key] then
            chosenKey = key
            break
        end
    end
    
    if chosenKey then
        _lastSkillCastTime = now
        local VIM = game:GetService("VirtualInputManager")
        local keyCode = Enum.KeyCode[chosenKey]
        if VIM and keyCode then
            pcall(function()
                VIM:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.06)
                VIM:SendKeyEvent(false, keyCode, false, game)
            end)
        elseif keypress and keyrelease then
            local byte = string.byte(chosenKey)
            pcall(function()
                keypress(byte)
                task.wait(0.06)
                keyrelease(byte)
            end)
        end
    end
end

local function StartCombatLoop()
    task.spawn(function()
        while true do
            local cd = _G.Config.FastAttackSpeed or 0.015
            task.wait(cd)
            if _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses then
                if _G.Config.FastAttack and _G.Config.UseM1 then
                    FastAttack()
                end
                if _G.Config.UseSkills then
                    CastNextSkill()
                end
                CheckBusoHaki()
            end
        end
    end)
end

--============================== BRING MOBS SYSTEM (CAPPED SIM RADIUS) ==============================
local _simRadiusSet = false

local function BringMobsTo(targetMobName, centerCFrame)
    if not _G.Config.BringMobs then
        -- Reset sim radius when not actively bringing
        if _simRadiusSet then
            pcall(function()
                if sethiddenproperty then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", 100)
                end
            end)
            _simRadiusSet = false
        end
        return
    end
    
    -- Cap at 1000 instead of math.huge to avoid server-side flag
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(LocalPlayer, "SimulationRadius", 1000)
            sethiddenproperty(LocalPlayer, "MaxSimulationRadius", 1000)
            _simRadiusSet = true
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
local function StartAutoFarmLevel()
    task.spawn(function()
        task.wait(math.random(5, 15) / 10)
        while true do
            task.wait(0.15)
            if _G.Config.AutoFarmLevel then
                pcall(function()
                    local questInfo = GetCurrentQuest()
                    if not HasQuest() then
                        local cf = CommF()
                        if cf then
                            TweenTo(questInfo.Pos * CFrame.new(0, 5, 0))
                            cf:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
                            task.wait(0.35)
                        end
                    else
                        local target = FindEnemy(questInfo.Mob)
                        if target and target:FindFirstChild("HumanoidRootPart") then
                            local dist = GetOptimalFarmDistance(target)
                            local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            TweenTo(farmPos)
                            HoverLock(farmPos)
                            EquipWeapon(_G.Config.SelectedWeapon)
                            BringMobsTo(questInfo.Mob, target.HumanoidRootPart.CFrame)
                        else
                            local safePos = questInfo.Pos * CFrame.new(0, 30, 0)
                            TweenTo(safePos)
                            HoverLock(safePos)
                        end
                    end
                end)
            else
                StopTween()
            end
        end
    end)
end

--============================== AUTO FARM SELECTED MOB CORE ==============================
local function StartAutoFarmSelectedMob()
    task.spawn(function()
        task.wait(math.random(8, 20) / 10)
        while true do
            task.wait(0.15)
            if _G.Config.FarmSelectedMob and _G.Config.SelectedMob ~= "" then
                pcall(function()
                    local mobName = _G.Config.SelectedMob:gsub("^%[Spawned%] ", "")
                    local target = FindEnemy(mobName)
                    if target and target:FindFirstChild("HumanoidRootPart") then
                        local dist = GetOptimalFarmDistance(target)
                        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        TweenTo(farmPos)
                        HoverLock(farmPos)
                        EquipWeapon(_G.Config.SelectedWeapon)
                        BringMobsTo(mobName, target.HumanoidRootPart.CFrame)
                    else
                        for _, q in ipairs(QuestsDB) do
                            if q.Mob == mobName then
                                local safePos = q.Pos * CFrame.new(0, 35, 0)
                                TweenTo(safePos)
                                HoverLock(safePos)
                                break
                            end
                        end
                    end
                end)
            else
                StopTween()
            end
        end
    end)
end

--============================== AUTO FARM SELECTED BOSS CORE ==============================
local function StartAutoFarmSelectedBoss()
    task.spawn(function()
        task.wait(math.random(10, 25) / 10)
        while true do
            task.wait(0.2)
            if _G.Config.FarmSelectedBoss and _G.Config.SelectedBoss ~= "" then
                pcall(function()
                    local bossName = _G.Config.SelectedBoss:gsub("^%[Spawned%] ", "")
                    local bossData = BossesDB[bossName]
                    local target = FindEnemy(bossName)
                    
                    if target and target:FindFirstChild("HumanoidRootPart") then
                        if bossData and bossData.Quest and not HasQuest() then
                            local cf = CommF()
                            if cf then cf:InvokeServer("StartQuest", bossData.Quest, bossData.Level) end
                            task.wait(0.35)
                        end
                        local dist = GetOptimalFarmDistance(target)
                        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        TweenTo(farmPos)
                        HoverLock(farmPos)
                        EquipWeapon(_G.Config.SelectedWeapon)
                    else
                        if bossData then
                            local safePos = bossData.Pos * CFrame.new(0, 40, 0)
                            TweenTo(safePos)
                            HoverLock(safePos)
                        end
                    end
                end)
            else
                StopTween()
            end
        end
    end)
end

--============================== AUTO FARM ALL BOSSES CORE ==============================
local function StartAutoFarmAllBosses()
    task.spawn(function()
        task.wait(math.random(12, 30) / 10)
        while true do
            task.wait(0.3)
            if _G.Config.FarmAllBosses then
                pcall(function()
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            if BossesDB[enemy.Name] and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                                local bData = BossesDB[enemy.Name]
                                if bData and bData.Quest and not HasQuest() then
                                    local cf = CommF()
                                    if cf then cf:InvokeServer("StartQuest", bData.Quest, bData.Level) end
                                    task.wait(0.35)
                                end
                                while enemy and enemy.Parent and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and _G.Config.FarmAllBosses do
                                    local dist = GetOptimalFarmDistance(enemy)
                                    local farmPos = enemy.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                    TweenTo(farmPos)
                                    HoverLock(farmPos)
                                    EquipWeapon(_G.Config.SelectedWeapon)
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                end)
            else
                StopTween()
            end
        end
    end)
end

--============================== RAID & SPECIAL BOSSES ==============================
local function FightRaidBoss(bossName)
    local target = FindEnemy(bossName)
    if target and target:FindFirstChild("HumanoidRootPart") then
        local dist = GetOptimalFarmDistance(target)
        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        TweenTo(farmPos)
        HoverLock(farmPos)
        EquipWeapon(_G.Config.SelectedWeapon)
        return true
    end
    return false
end

local function StartRaidBossLoop()
    task.spawn(function()
        task.wait(math.random(15, 35) / 10)
        while true do
            task.wait(0.4)
            pcall(function()
                if _G.Config.AutoKillRipIndra then if not FightRaidBoss("rip_indra") then FightRaidBoss("Rip Indra") end end
                if _G.Config.AutoKillDoughKing then FightRaidBoss("Dough King") end
                if _G.Config.AutoKillCakePrince then FightRaidBoss("Cake Prince") end
                if _G.Config.AutoKillSoulReaper then FightRaidBoss("Soul Reaper") end
                if _G.Config.AutoKillDarkbeard then FightRaidBoss("Darkbeard") end
                if _G.Config.AutoKillCursedCaptain then FightRaidBoss("Cursed Captain") end
                if _G.Config.AutoKillLaw then FightRaidBoss("Order") end
            end)
        end
    end)
end

--============================== DEVIL FRUIT SYSTEM ==============================
local function StartDevilFruitLoops()
    -- Auto Random Gacha
    task.spawn(function()
        task.wait(math.random(20, 40) / 10)
        while true do
            task.wait(2 + math.random() * 0.5)
            if _G.Config.AutoRandomFruit then
                local cf = CommF()
                if cf then pcall(function() cf:InvokeServer("Cousin", "Buy") end) end
            end
        end
    end)

    -- Auto Store Fruits
    task.spawn(function()
        task.wait(math.random(22, 42) / 10)
        while true do
            task.wait(1.5 + math.random() * 0.5)
            if _G.Config.AutoStoreFruit then
                local cf = CommF()
                if cf then
                    pcall(function()
                        local bp = LocalPlayer:FindFirstChild("Backpack")
                        local char = GetCharacter()
                        for _, container in ipairs({bp, char}) do
                            if container then
                                for _, tool in ipairs(container:GetChildren()) do
                                    if tool:IsA("Tool") and (tool.ToolTip == "Blox Fruit" or string.find(tool.Name, "Fruit")) then
                                        cf:InvokeServer("StoreFruit", tool:GetAttribute("OriginalName") or tool.Name, tool)
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- Auto Grab Dropped Fruits
    task.spawn(function()
        task.wait(math.random(25, 45) / 10)
        while true do
            task.wait(1 + math.random() * 0.3)
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
end

-- Fruit ESP (randomized billboard names)
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
            bill.Name = RNG() -- Random name instead of "AlphaFruitESP"
            bill.Adornee = obj.Handle
            bill.Size = UDim2.new(0, 100, 0, 30)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.Parent = obj.Handle
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "[Fruit] " .. obj.Name
            label.TextColor3 = Color3.fromRGB(255, 100, 100)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 13
            label.Parent = bill
            table.insert(FruitESPTable, bill)
        end
    end
end

local function StartFruitESPLoop()
    task.spawn(function()
        task.wait(math.random(30, 50) / 10)
        while true do
            task.wait(3 + math.random() * 1)
            if _G.Config.FruitESP then UpdateFruitESP() end
        end
    end)
end

--============================== AUTO STATS ALLOCATOR ==============================
local function StartAutoStatsLoop()
    task.spawn(function()
        task.wait(math.random(18, 38) / 10)
        while true do
            task.wait(0.5 + math.random() * 0.2)
            if _G.Config.AutoStats then
                local cf = CommF()
                if cf then
                    pcall(function()
                        local pts = _G.Config.StatPoints or 1
                        if _G.Config.Stats.Melee then cf:InvokeServer("AddPoint", "Melee", pts) end
                        if _G.Config.Stats.Defense then cf:InvokeServer("AddPoint", "Defense", pts) end
                        if _G.Config.Stats.Sword then cf:InvokeServer("AddPoint", "Sword", pts) end
                        if _G.Config.Stats.Gun then cf:InvokeServer("AddPoint", "Gun", pts) end
                        if _G.Config.Stats.Fruit then cf:InvokeServer("AddPoint", "Demon Fruit", pts) end
                    end)
                end
            end
        end
    end)
end

--============================== DUNGEONS & RAIDS ==============================
local function StartDungeonRaidLoop()
    task.spawn(function()
        task.wait(math.random(20, 40) / 10)
        while true do
            task.wait(1.5 + math.random() * 0.5)
            pcall(function()
                local cf = CommF()
                if _G.Config.AutoBuyChip and cf then
                    cf:InvokeServer("RaidsNpc", "Select", _G.Config.SelectedChip)
                end
                if _G.Config.AutoStartRaid and cf then
                    cf:InvokeServer("RaidsNpc", "Start")
                end
                if _G.Config.AutoFarmRaid then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance, 0)
                                TweenTo(farmPos)
                                EquipWeapon(_G.Config.SelectedWeapon)
                                break
                            end
                        end
                    end
                end
            end)
        end
    end)
end

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

--============================== STEALTH UI FRAMEWORK (REDZ NEON EDITION) ==============================
-- All GUI elements use randomized names via GenerateGUID
-- Full input isolation: Active = true on all containers so clicks NEVER register into the 3D game world!
local function CreateUI()
    local parentGui = GetSafeGui()
    
    -- Cleanup any existing instance
    for _, child in ipairs(parentGui:GetChildren()) do
        if child:IsA("ScreenGui") and child:GetAttribute("_uid") == "v2h" then
            child:Destroy()
        end
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = RNG()
    ScreenGui:SetAttribute("_uid", "v2h")
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    ScreenGui.Parent = parentGui
    
    -- Main Frame (Dark Obsidian Cyber Theme)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = RNG()
    MainFrame.Size = UDim2.new(0, 600, 0, 375)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -187)
    MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true -- Consumes input so clicks never reach game!
    MainFrame.Parent = ScreenGui
    
    -- Global input lock listeners
    MainFrame.MouseEnter:Connect(function() _G.UIInteracting = true end)
    MainFrame.MouseLeave:Connect(function() _G.UIInteracting = false end)
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(255, 42, 95)
    MainStroke.Thickness = 1.2
    MainStroke.Transparency = 0.3
    MainStroke.Parent = MainFrame
    
    -- Dragging logic
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Top Bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = RNG()
    TopBar.Size = UDim2.new(1, 0, 0, 44)
    TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.Parent = MainFrame
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 320, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.Text = "ALPHA // REDZ HUB EDITION"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 60, 110)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Active = true
    TitleLabel.Parent = TopBar
    
    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(0, 200, 1, 0)
    SubLabel.Position = UDim2.new(0, 245, 0, 0)
    SubLabel.Text = "Keyless • " .. SeaName
    SubLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
    SubLabel.Font = Enum.Font.Gotham
    SubLabel.TextSize = 11
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.BackgroundTransparency = 1
    SubLabel.Active = true
    SubLabel.Parent = TopBar
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0, 8)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 13
    CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 25, 35)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Active = true
    CloseBtn.Parent = TopBar
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)
    
    -- Floating Reopen Button with neon pulse
    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = RNG()
    FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
    FloatingBtn.Position = UDim2.new(0, 20, 0.5, -26)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    FloatingBtn.Text = "REDZ"
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 55, 105)
    FloatingBtn.Font = Enum.Font.GothamBold
    FloatingBtn.TextSize = 11
    FloatingBtn.BorderSizePixel = 0
    FloatingBtn.Active = true
    FloatingBtn.Parent = ScreenGui
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatingBtn
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(255, 45, 95)
    FloatStroke.Thickness = 1.6
    FloatStroke.Parent = FloatingBtn
    FloatingBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
    end)
    
    -- Left Sidebar
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = RNG()
    Sidebar.Size = UDim2.new(0, 145, 1, -44)
    Sidebar.Position = UDim2.new(0, 0, 0, 44)
    Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 2
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 380)
    Sidebar.Active = true
    Sidebar.Parent = MainFrame
    
    local SidebarLayout = Instance.new("UIListLayout")
    SidebarLayout.Padding = UDim.new(0, 4)
    SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarLayout.Parent = Sidebar
    local SidebarPad = Instance.new("UIPadding")
    SidebarPad.PaddingTop = UDim.new(0, 6)
    SidebarPad.Parent = Sidebar
    
    -- Content Container
    local ContentHolder = Instance.new("Frame")
    ContentHolder.Name = RNG()
    ContentHolder.Size = UDim2.new(1, -145, 1, -44)
    ContentHolder.Position = UDim2.new(0, 145, 0, 44)
    ContentHolder.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
    ContentHolder.BorderSizePixel = 0
    ContentHolder.Active = true
    ContentHolder.Parent = MainFrame
    
    local Tabs = {}
    local CurrentActiveTab = nil
    
    local function SwitchTab(tabName)
        for name, page in pairs(Tabs) do
            page.Page.Visible = (name == tabName)
            if page.Btn then
                if name == tabName then
                    page.Btn.BackgroundColor3 = Color3.fromRGB(255, 42, 95)
                    page.Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                else
                    page.Btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
                    page.Btn.TextColor3 = Color3.fromRGB(170, 170, 190)
                end
            end
        end
        CurrentActiveTab = tabName
    end
    
    local function CreateTab(name)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, -12, 0, 28)
        TabBtn.Text = name
        TabBtn.TextColor3 = Color3.fromRGB(170, 170, 190)
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 11
        TabBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
        TabBtn.BorderSizePixel = 0
        TabBtn.Active = true
        TabBtn.Parent = Sidebar
        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 5)
        TabBtnCorner.Parent = TabBtn
        
        local Page = Instance.new("ScrollingFrame")
        Page.Name = RNG()
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.BorderSizePixel = 0
        Page.ScrollBarThickness = 3
        Page.CanvasSize = UDim2.new(0, 0, 0, 100)
        Page.Visible = false
        Page.Active = true
        Page.Parent = ContentHolder
        
        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Padding = UDim.new(0, 6)
        PageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Parent = Page
        local PagePad = Instance.new("UIPadding")
        PagePad.PaddingTop = UDim.new(0, 8)
        PagePad.PaddingBottom = UDim.new(0, 16)
        PagePad.Parent = Page
        
        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 24)
        end)
        
        TabBtn.MouseButton1Click:Connect(function()
            SwitchTab(name)
        end)
        
        Tabs[name] = {Btn = TabBtn, Page = Page}
        
        local TabAPI = {}
        
        function TabAPI:AddSection(secName)
            local SecFrame = Instance.new("Frame")
            SecFrame.Size = UDim2.new(1, -16, 0, 24)
            SecFrame.BackgroundTransparency = 1
            SecFrame.Active = true
            SecFrame.Parent = Page
            
            local SecLabel = Instance.new("TextLabel")
            SecLabel.Size = UDim2.new(1, 0, 1, 0)
            SecLabel.Text = "• " .. secName:upper()
            SecLabel.TextColor3 = Color3.fromRGB(255, 60, 110)
            SecLabel.Font = Enum.Font.GothamBold
            SecLabel.TextSize = 10
            SecLabel.TextXAlignment = Enum.TextXAlignment.Left
            SecLabel.BackgroundTransparency = 1
            SecLabel.Active = true
            SecLabel.Parent = SecFrame
        end
        
        function TabAPI:AddToggle(title, defaultVal, callback)
            local isChecked = defaultVal or false
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, -16, 0, 34)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Active = true
            ToggleFrame.Parent = Page
            local TCorner = Instance.new("UICorner")
            TCorner.CornerRadius = UDim.new(0, 6)
            TCorner.Parent = ToggleFrame
            
            local TTitle = Instance.new("TextLabel")
            TTitle.Size = UDim2.new(1, -55, 1, 0)
            TTitle.Position = UDim2.new(0, 10, 0, 0)
            TTitle.Text = title
            TTitle.TextColor3 = Color3.fromRGB(225, 225, 235)
            TTitle.Font = Enum.Font.Gotham
            TTitle.TextSize = 11
            TTitle.TextXAlignment = Enum.TextXAlignment.Left
            TTitle.BackgroundTransparency = 1
            TTitle.Active = true
            TTitle.Parent = ToggleFrame
            
            local Switch = Instance.new("TextButton")
            Switch.Size = UDim2.new(0, 38, 0, 20)
            Switch.Position = UDim2.new(1, -48, 0.5, -10)
            Switch.BackgroundColor3 = isChecked and Color3.fromRGB(255, 42, 95) or Color3.fromRGB(45, 45, 58)
            Switch.Text = ""
            Switch.BorderSizePixel = 0
            Switch.Active = true
            Switch.Parent = ToggleFrame
            local SCorner = Instance.new("UICorner")
            SCorner.CornerRadius = UDim.new(1, 0)
            SCorner.Parent = Switch
            
            local Knob = Instance.new("Frame")
            Knob.Size = UDim2.new(0, 16, 0, 16)
            Knob.Position = isChecked and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Knob.BorderSizePixel = 0
            Knob.Active = true
            Knob.Parent = Switch
            local KCorner = Instance.new("UICorner")
            KCorner.CornerRadius = UDim.new(1, 0)
            KCorner.Parent = Knob
            
            local function UpdateToggle()
                Switch.BackgroundColor3 = isChecked and Color3.fromRGB(255, 42, 95) or Color3.fromRGB(45, 45, 58)
                Knob.Position = isChecked and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            end
            
            Switch.MouseButton1Click:Connect(function()
                isChecked = not isChecked
                UpdateToggle()
                if callback then pcall(callback, isChecked) end
            end)
            
            local ToggleAPI = {}
            function ToggleAPI:Set(val)
                isChecked = val
                UpdateToggle()
                if callback then pcall(callback, isChecked) end
            end
            return ToggleAPI
        end
        
        function TabAPI:AddButton(title, callback)
            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(1, -16, 0, 30)
            Btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
            Btn.Text = title
            Btn.TextColor3 = Color3.fromRGB(235, 235, 245)
            Btn.Font = Enum.Font.GothamMedium
            Btn.TextSize = 11
            Btn.BorderSizePixel = 0
            Btn.Active = true
            Btn.Parent = Page
            local BCorner = Instance.new("UICorner")
            BCorner.CornerRadius = UDim.new(0, 5)
            BCorner.Parent = Btn
            
            Btn.MouseButton1Click:Connect(function()
                Btn.BackgroundColor3 = Color3.fromRGB(255, 42, 95)
                task.wait(0.1)
                Btn.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
                if callback then pcall(callback) end
            end)
        end
        
        function TabAPI:AddDropdown(title, options, defaultVal, callback)
            local selected = defaultVal or (options and options[1]) or ""
            local DropFrame = Instance.new("Frame")
            DropFrame.Size = UDim2.new(1, -16, 0, 34)
            DropFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
            DropFrame.BorderSizePixel = 0
            DropFrame.ClipsDescendants = true
            DropFrame.Active = true
            DropFrame.Parent = Page
            local DCorner = Instance.new("UICorner")
            DCorner.CornerRadius = UDim.new(0, 5)
            DCorner.Parent = DropFrame
            
            local DTitle = Instance.new("TextLabel")
            DTitle.Size = UDim2.new(0, 160, 0, 34)
            DTitle.Position = UDim2.new(0, 10, 0, 0)
            DTitle.Text = title
            DTitle.TextColor3 = Color3.fromRGB(215, 215, 225)
            DTitle.Font = Enum.Font.Gotham
            DTitle.TextSize = 11
            DTitle.TextXAlignment = Enum.TextXAlignment.Left
            DTitle.BackgroundTransparency = 1
            DTitle.Active = true
            DTitle.Parent = DropFrame
            
            local SelectBtn = Instance.new("TextButton")
            SelectBtn.Size = UDim2.new(0, 210, 0, 24)
            SelectBtn.Position = UDim2.new(1, -218, 0, 5)
            SelectBtn.Text = tostring(selected) .. " v"
            SelectBtn.TextColor3 = Color3.fromRGB(255, 80, 130)
            SelectBtn.Font = Enum.Font.GothamMedium
            SelectBtn.TextSize = 10
            SelectBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
            SelectBtn.BorderSizePixel = 0
            SelectBtn.Active = true
            SelectBtn.Parent = DropFrame
            local SBCorner = Instance.new("UICorner")
            SBCorner.CornerRadius = UDim.new(0, 4)
            SBCorner.Parent = SelectBtn
            
            local ListScroll = Instance.new("ScrollingFrame")
            ListScroll.Size = UDim2.new(1, -16, 0, 100)
            ListScroll.Position = UDim2.new(0, 8, 0, 38)
            ListScroll.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
            ListScroll.BorderSizePixel = 0
            ListScroll.ScrollBarThickness = 2
            ListScroll.Visible = false
            ListScroll.Active = true
            ListScroll.Parent = DropFrame
            local LCorner = Instance.new("UICorner")
            LCorner.CornerRadius = UDim.new(0, 4)
            LCorner.Parent = ListScroll
            local LLayout = Instance.new("UIListLayout")
            LLayout.Padding = UDim.new(0, 2)
            LLayout.Parent = ListScroll
            
            local isOpen = false
            local function Populate(opts)
                for _, child in ipairs(ListScroll:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, opt in ipairs(opts) do
                    local OptBtn = Instance.new("TextButton")
                    OptBtn.Size = UDim2.new(1, 0, 0, 22)
                    OptBtn.Text = tostring(opt)
                    OptBtn.TextColor3 = Color3.fromRGB(210, 210, 220)
                    OptBtn.Font = Enum.Font.Gotham
                    OptBtn.TextSize = 10
                    OptBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
                    OptBtn.BorderSizePixel = 0
                    OptBtn.Active = true
                    OptBtn.Parent = ListScroll
                    OptBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        SelectBtn.Text = tostring(selected) .. " v"
                        isOpen = false
                        DropFrame.Size = UDim2.new(1, -16, 0, 34)
                        ListScroll.Visible = false
                        if callback then pcall(callback, selected) end
                    end)
                end
                ListScroll.CanvasSize = UDim2.new(0, 0, 0, #opts * 24)
            end
            Populate(options or {})
            
            SelectBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    DropFrame.Size = UDim2.new(1, -16, 0, 146)
                    ListScroll.Visible = true
                else
                    DropFrame.Size = UDim2.new(1, -16, 0, 34)
                    ListScroll.Visible = false
                end
            end)
            
            local DropAPI = {}
            function DropAPI:SetOptions(newOpts)
                Populate(newOpts)
            end
            return DropAPI
        end
        
        function TabAPI:AddSlider(title, min, max, defaultVal, callback)
            local current = defaultVal or min
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size = UDim2.new(1, -16, 0, 44)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Active = true
            SliderFrame.Parent = Page
            local SlCorner = Instance.new("UICorner")
            SlCorner.CornerRadius = UDim.new(0, 5)
            SlCorner.Parent = SliderFrame
            
            local STitle = Instance.new("TextLabel")
            STitle.Size = UDim2.new(0, 220, 0, 20)
            STitle.Position = UDim2.new(0, 10, 0, 4)
            STitle.Text = title
            STitle.TextColor3 = Color3.fromRGB(220, 220, 230)
            STitle.Font = Enum.Font.Gotham
            STitle.TextSize = 11
            STitle.TextXAlignment = Enum.TextXAlignment.Left
            STitle.BackgroundTransparency = 1
            STitle.Active = true
            STitle.Parent = SliderFrame
            
            local SValue = Instance.new("TextLabel")
            SValue.Size = UDim2.new(0, 60, 0, 20)
            SValue.Position = UDim2.new(1, -70, 0, 4)
            SValue.Text = tostring(current)
            SValue.TextColor3 = Color3.fromRGB(255, 75, 125)
            SValue.Font = Enum.Font.GothamBold
            SValue.TextSize = 11
            SValue.TextXAlignment = Enum.TextXAlignment.Right
            SValue.BackgroundTransparency = 1
            SValue.Active = true
            SValue.Parent = SliderFrame
            
            local Bar = Instance.new("Frame")
            Bar.Size = UDim2.new(1, -20, 0, 6)
            Bar.Position = UDim2.new(0, 10, 0, 30)
            Bar.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
            Bar.BorderSizePixel = 0
            Bar.Active = true
            Bar.Parent = SliderFrame
            local BarCorner = Instance.new("UICorner")
            BarCorner.CornerRadius = UDim.new(1, 0)
            BarCorner.Parent = Bar
            
            local Fill = Instance.new("Frame")
            local pct = math.clamp((current - min) / (max - min), 0, 1)
            Fill.Size = UDim2.new(pct, 0, 1, 0)
            Fill.BackgroundColor3 = Color3.fromRGB(255, 42, 95)
            Fill.BorderSizePixel = 0
            Fill.Active = true
            Fill.Parent = Bar
            local FillCorner = Instance.new("UICorner")
            FillCorner.CornerRadius = UDim.new(1, 0)
            FillCorner.Parent = Fill
            
            local isSliding = false
            Bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isSliding = true
                    _G.UIInteracting = true -- Mute combat clicks while sliding!
                    local relX = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                    current = math.floor(min + (max - min) * relX)
                    Fill.Size = UDim2.new(relX, 0, 1, 0)
                    SValue.Text = tostring(current)
                    if callback then pcall(callback, current) end
                end
            end)
            UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if isSliding then
                        isSliding = false
                        task.wait(0.05)
                        _G.UIInteracting = false
                    end
                end
            end)
            UIS.InputChanged:Connect(function(input)
                if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local relX = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                    current = math.floor(min + (max - min) * relX)
                    Fill.Size = UDim2.new(relX, 0, 1, 0)
                    SValue.Text = tostring(current)
                    if callback then pcall(callback, current) end
                end
            end)
        end
        
        return TabAPI
    end
    
    -- Instantiate All Tabs with Redz Hub Icons
    local FarmTab = CreateTab("⚔️ Main Farm")
    local BossTab = CreateTab("👑 Boss Farm")
    local RaidTab = CreateTab("🌀 Raids")
    local FruitTab = CreateTab("🍇 Devil Fruit")
    local SeaTab = CreateTab("🌊 Sea Events")
    local ItemTab = CreateTab("📜 Quests")
    local StatsTab = CreateTab("⚡ Stats")
    local ShopTab = CreateTab("🛒 Shop")
    local TeleportTab = CreateTab("🚀 Teleports")
    local MiscTab = CreateTab("⚙️ Settings")
    
    -- MAIN FARM
    FarmTab:AddSection("Combat Mode & Weapon Selection")
    FarmTab:AddDropdown("Select Weapon", {"Melee", "Sword", "Gun", "Fruit"}, "Melee", function(v)
        _G.Config.SelectedWeapon = v
        EquipWeapon(v)
    end)
    FarmTab:AddToggle("Use M1 / Normal Clicks (Fast Attack)", true, function(v) _G.Config.UseM1 = v end)
    FarmTab:AddDropdown("Click Speed", {"Super Fast (0.015s)", "Fast (0.04s)", "Normal (0.1s)"}, "Super Fast (0.015s)", function(v)
        if v:find("Super") then
            _G.Config.FastAttackSpeed = 0.015
        elseif v:find("Fast") then
            _G.Config.FastAttackSpeed = 0.04
        else
            _G.Config.FastAttackSpeed = 0.1
        end
    end)
    FarmTab:AddSlider("Kill Aura Range (Studs)", 40, 250, 120, function(v) _G.Config.AttackDistance = v end)
    FarmTab:AddToggle("Bring Mobs (Simulation Radius)", true, function(v) _G.Config.BringMobs = v end)
    FarmTab:AddToggle("Auto Buso Haki (Enhancement)", true, function(v) _G.Config.AutoBusoHaki = v end)
    
    FarmTab:AddSection("Skills Control")
    FarmTab:AddToggle("Use Weapon Skills", false, function(v) _G.Config.UseSkills = v end)
    FarmTab:AddToggle("Use Skill [Z]", true, function(v) _G.Config.Skill_Z = v end)
    FarmTab:AddToggle("Use Skill [X]", true, function(v) _G.Config.Skill_X = v end)
    FarmTab:AddToggle("Use Skill [C]", true, function(v) _G.Config.Skill_C = v end)
    FarmTab:AddToggle("Use Skill [V]", false, function(v) _G.Config.Skill_V = v end)
    FarmTab:AddToggle("Use Skill [F]", false, function(v) _G.Config.Skill_F = v end)
    
    FarmTab:AddSection("Farm Distance Control")
    FarmTab:AddToggle("Auto Adaptive Boss Distance", true, function(v) _G.Config.AdaptiveBossDistance = v end)
    FarmTab:AddSlider("Mob Distance (Studs)", 6, 25, 14, function(v) _G.Config.MobFarmDistance = v end)
    FarmTab:AddSlider("Boss Distance (Studs)", 10, 35, 20, function(v) _G.Config.BossFarmDistance = v end)
    
    FarmTab:AddSection("Level Farming")
    FarmTab:AddToggle("Auto Farm Level (Auto Quest + Mob)", false, function(v)
        _G.Config.AutoFarmLevel = v
        if not v then FullResetMovement() end
    end)
    FarmTab:AddToggle("Auto Double Quest", false, function(v) _G.Config.AutoDoubleQuest = v end)
    
    FarmTab:AddSection("Select Mob Farming")
    local MobDrop = FarmTab:AddDropdown("Select Mob", GetSpawnedMobsList(), GetSpawnedMobsList()[1] or "Bandit", function(v) _G.Config.SelectedMob = v end)
    FarmTab:AddButton("Refresh Mobs List", function()
        local updated = GetSpawnedMobsList()
        MobDrop:SetOptions(updated)
    end)
    FarmTab:AddToggle("Auto Farm Selected Mob", false, function(v)
        _G.Config.FarmSelectedMob = v
        if not v then FullResetMovement() end
    end)
    
-- BOSS FARM
    BossTab:AddSection("Select Boss Farming")
    local BossDrop = BossTab:AddDropdown("Select Boss", GetSpawnedBossesList(), "The Gorilla King", function(v) _G.Config.SelectedBoss = v end)
    BossTab:AddButton("Refresh Bosses List (Scan Active)", function()
        local updated = GetSpawnedBossesList()
        BossDrop:SetOptions(updated)
    end)
    BossTab:AddToggle("Auto Farm Selected Boss", false, function(v)
        _G.Config.FarmSelectedBoss = v
        if not v then StopTween() end
    end)
    BossTab:AddToggle("Auto Farm All Spawned Bosses", false, function(v)
        _G.Config.FarmAllBosses = v
        if not v then StopTween() end
    end)
    
    BossTab:AddSection("World & Raid Bosses")
    BossTab:AddToggle("Auto Kill Rip Indra", false, function(v) _G.Config.AutoKillRipIndra = v end)
    BossTab:AddToggle("Auto Kill Dough King", false, function(v) _G.Config.AutoKillDoughKing = v end)
    BossTab:AddToggle("Auto Kill Cake Prince", false, function(v) _G.Config.AutoKillCakePrince = v end)
    BossTab:AddToggle("Auto Kill Soul Reaper", false, function(v) _G.Config.AutoKillSoulReaper = v end)
    BossTab:AddToggle("Auto Kill Darkbeard", false, function(v) _G.Config.AutoKillDarkbeard = v end)
    BossTab:AddToggle("Auto Kill Cursed Captain", false, function(v) _G.Config.AutoKillCursedCaptain = v end)
    BossTab:AddToggle("Auto Kill Order (Law)", false, function(v) _G.Config.AutoKillLaw = v end)
    
    -- DUNGEON & RAIDS
    RaidTab:AddSection("Raid Controls")
    RaidTab:AddDropdown("Select Raid Chip", {"Flame", "Ice", "Quake", "Light", "Dark", "String", "Rumble", "Magma", "Human: Buddha", "Phoenix", "Dough"}, "Flame", function(v) _G.Config.SelectedChip = v end)
    RaidTab:AddToggle("Auto Buy Raid Chip", false, function(v) _G.Config.AutoBuyChip = v end)
    RaidTab:AddToggle("Auto Start Raid", false, function(v) _G.Config.AutoStartRaid = v end)
    RaidTab:AddToggle("Auto Farm Raid (Next Island)", false, function(v) _G.Config.AutoFarmRaid = v end)
    RaidTab:AddToggle("Auto Awaken Fruit", false, function(v) _G.Config.AutoAwaken = v end)
    
    -- DEVIL FRUIT
    FruitTab:AddSection("Fruit Actions")
    FruitTab:AddToggle("Auto Random Fruit (Gacha Cousin)", false, function(v) _G.Config.AutoRandomFruit = v end)
    FruitTab:AddToggle("Auto Store Fruits in Inventory", true, function(v) _G.Config.AutoStoreFruit = v end)
    FruitTab:AddToggle("Auto Grab Dropped Fruits (Tween)", false, function(v) _G.Config.AutoGrabFruits = v end)
    FruitTab:AddToggle("Fruit ESP (Billboard Labels)", false, function(v)
        _G.Config.FruitESP = v
        UpdateFruitESP()
    end)
    
    -- SEA EVENTS
    SeaTab:AddSection("Sea Events")
    SeaTab:AddToggle("Auto Kill Sharks", false, function(v) _G.Config.AutoKillShark = v end)
    SeaTab:AddToggle("Auto Kill Terror Shark", false, function(v) _G.Config.AutoKillTerrorShark = v end)
    SeaTab:AddToggle("Auto Kill Sea Beast", false, function(v) _G.Config.AutoKillSeaBeast = v end)
    SeaTab:AddSection("Mirage & Kitsune Island")
    SeaTab:AddButton("Check Mirage Island Status", function()
        local s = CheckIslandSpawn("MysticIsland") or CheckIslandSpawn("Mirage Island")
        print("[HUB] Mirage Island:", s and "SPAWNED!" or "NOT Spawned")
    end)
    SeaTab:AddButton("Check Kitsune Island Status", function()
        local s = CheckIslandSpawn("KitsuneIsland") or CheckIslandSpawn("Kitsune Island")
        print("[HUB] Kitsune Island:", s and "SPAWNED!" or "NOT Spawned")
    end)
    SeaTab:AddToggle("Auto Find Blue Gear (Mirage)", false, function(v) _G.Config.AutoFindGear = v end)
    SeaTab:AddToggle("Auto Pull Lever (Temple of Time)", false, function(v) _G.Config.AutoPullLever = v end)
    
    -- ITEMS & QUESTS
    ItemTab:AddSection("Special Weapons & Quests")
    ItemTab:AddButton("Auto Saber Quest", function() local cf = CommF(); if cf then cf:InvokeServer("ProQuestProgress", "RichSon") end end)
    ItemTab:AddButton("Auto Bartilo Quest", function() local cf = CommF(); if cf then cf:InvokeServer("BartiloQuestProgress", "GetMission") end end)
    ItemTab:AddButton("Travel to Second Sea", function() local cf = CommF(); if cf then cf:InvokeServer("TravelDressrosa") end end)
    ItemTab:AddButton("Travel to Third Sea", function() local cf = CommF(); if cf then cf:InvokeServer("TravelZou") end end)
    
    -- STATS ALLOCATOR
    StatsTab:AddSection("Stat Points Allocator")
    StatsTab:AddToggle("Auto Allocate Stats", false, function(v) _G.Config.AutoStats = v end)
    StatsTab:AddSlider("Points Per Stat", 1, 100, 1, function(v) _G.Config.StatPoints = v end)
    StatsTab:AddToggle("Melee", true, function(v) _G.Config.Stats.Melee = v end)
    StatsTab:AddToggle("Defense", true, function(v) _G.Config.Stats.Defense = v end)
    StatsTab:AddToggle("Sword", false, function(v) _G.Config.Stats.Sword = v end)
    StatsTab:AddToggle("Gun", false, function(v) _G.Config.Stats.Gun = v end)
    StatsTab:AddToggle("Blox Fruit", false, function(v) _G.Config.Stats.Fruit = v end)
    StatsTab:AddButton("Refund Stats (2,500 Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BlackbeardReward", "Refund", "2") end end)
    StatsTab:AddButton("Reroll Race (3,000 Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BlackbeardReward", "Reroll", "2") end end)
    
    -- SHOP
    ShopTab:AddSection("Fighting Styles (Melee V1 & V2)")
    ShopTab:AddButton("Buy Black Leg ($150,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyBlackLeg") end end)
    ShopTab:AddButton("Buy Electro ($550,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyElectro") end end)
    ShopTab:AddButton("Buy Fishman Karate ($750,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyFishmanKarate") end end)
    ShopTab:AddButton("Buy Dragon Breath (1,500 Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BlackbeardReward", "DragonClaw", "2") end end)
    ShopTab:AddButton("Buy Superhuman ($3,000,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuySuperhuman") end end)
    ShopTab:AddButton("Buy Death Step ($5M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyDeathStep") end end)
    ShopTab:AddButton("Buy Sharkman Karate ($2.5M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuySharkmanKarate") end end)
    ShopTab:AddButton("Buy Electric Claw ($3M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyElectricClaw") end end)
    ShopTab:AddButton("Buy Dragon Talon ($3M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyDragonTalon") end end)
    ShopTab:AddButton("Buy Godhuman ($5M + 5k Frags)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyGodhuman") end end)
    ShopTab:AddSection("Abilities & Haki")
    ShopTab:AddButton("Buy Skyjump (Geppo - $10,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyHaki", "Geppo") end end)
    ShopTab:AddButton("Buy Enhancement (Buso - $25,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyHaki", "Buso") end end)
    ShopTab:AddButton("Buy Flash Step (Soru - $100,000)", function() local cf = CommF(); if cf then cf:InvokeServer("BuyHaki", "Soru") end end)
    ShopTab:AddButton("Buy Observation Haki ($750,000)", function() local cf = CommF(); if cf then cf:InvokeServer("KenHaki") end end)
    
    -- TELEPORTS
    TeleportTab:AddSection("Island Teleports")
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
    local SelIsland = islandKeys[1]
    TeleportTab:AddDropdown("Select Island", islandKeys, islandKeys[1], function(v) SelIsland = v end)
    TeleportTab:AddButton("Teleport to Selected Island", function()
        local tcf = IslandsList[SelIsland]
        if tcf then TweenTo(tcf) end
    end)
    
    -- SETTINGS
    MiscTab:AddSection("Server Controls")
    MiscTab:AddButton("Server Hop (Low Population)", function()
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
    end)
    MiscTab:AddButton("Rejoin Current Server", function()
        TeleportService:Teleport(PlaceId, LocalPlayer)
    end)
    MiscTab:AddToggle("Anti-AFK", true, function(v)
        _G.Config.AntiAFK = v
        if v then EnableAntiAFK() elseif AntiAFKConn then AntiAFKConn:Disconnect(); AntiAFKConn = nil end
    end)
    MiscTab:AddSlider("Tween Flight Speed", 100, 300, 200, function(v) _G.Config.TweenSpeed = v end)
    MiscTab:AddSlider("WalkSpeed", 16, 250, 16, function(v)
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v end
    end)
    MiscTab:AddSlider("JumpPower", 50, 300, 50, function(v)
        local hum = GetHumanoid()
        if hum then hum.JumpPower = v end
    end)
    
    -- Set default active tab
    SwitchTab("⚔️ Main Farm")
end

--============================== STAGGERED INITIALIZATION ==============================
-- Step 1: UI first (immediate user feedback)
CreateUI()

-- Step 2: Start all background loops with staggered delays (not all at once)
task.spawn(function()
    task.wait(0.5 + math.random() * 0.5)
    StartCombatLoop()
    
    task.wait(0.3 + math.random() * 0.3)
    StartAutoFarmLevel()
    
    task.wait(0.2 + math.random() * 0.3)
    StartAutoFarmSelectedMob()
    
    task.wait(0.2 + math.random() * 0.3)
    StartAutoFarmSelectedBoss()
    
    task.wait(0.2 + math.random() * 0.3)
    StartAutoFarmAllBosses()
    
    task.wait(0.2 + math.random() * 0.3)
    StartRaidBossLoop()
    
    task.wait(0.2 + math.random() * 0.3)
    StartDevilFruitLoops()
    
    task.wait(0.2 + math.random() * 0.3)
    StartFruitESPLoop()
    
    task.wait(0.2 + math.random() * 0.3)
    StartAutoStatsLoop()
    
    task.wait(0.2 + math.random() * 0.3)
    StartDungeonRaidLoop()
end)

print("--------------------------------------------------")
print("[v2] Loaded successfully!")
print("[v2] Keyless Edition active.")
print("[v2] Current Location: " .. SeaName)
print("--------------------------------------------------")
