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
local CurrentSea = Sea1 and 1 or (Sea2 and 2 or (Sea3 and 3 or 1))
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
    TweenSpeed = 240, -- Redz Safe Speed (240 studs/s prevents server rollback) -- Redz Flight Speed (350 studs/s)
    
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

-- Strict weapon type identifier (handles Blox Fruits where ToolTip is often empty)
local function IsWeaponType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    local tip = tool.ToolTip or ""
    local name = tool.Name:lower()
    
    -- Known Blox Fruit names (always classified as Fruit regardless of ToolTip)
    local fruitNames = {
        "bomb", "spike", "chop", "spring", "smoke", "flame", "falcon", "ice",
        "sand", "dark", "light", "rubber", "barrier", "magma", "quake",
        "human", "buddha", "string", "bird", "phoenix", "rumble", "paw",
        "gravity", "dough", "venom", "shadow", "control", "soul", "dragon",
        "leopard", "spirit", "portal", "blizzard", "sound", "mammoth",
        "t-rex", "kitsune", "rocket", "spin", "diamond", "love", "gas"
    }
    -- Check if tool name contains a fruit name pattern (e.g. "Bomb-Bomb", "Flame-Flame")
    local isFruitByName = false
    for _, fn in ipairs(fruitNames) do
        if name:find(fn) then isFruitByName = true; break end
    end
    if name:find("fruit") then isFruitByName = true end
    
    -- Known melee/fighting style names
    local meleeStyles = {
        "combat", "black leg", "electro", "water kung fu", "dragon claw",
        "superhuman", "death step", "sharkman karate", "electric claw",
        "dragon talon", "godhuman", "sanguine art", "karate"
    }
    local isMeleeByName = false
    for _, m in ipairs(meleeStyles) do
        if name:find(m) then isMeleeByName = true; break end
    end
    
    -- Known sword names
    local swordNames = {
        "cutlass", "katana", "pipe", "dual katana", "iron mace", "bisento",
        "trident", "pole", "soul cane", "saber", "longsword", "gravity cane",
        "saddi", "wando", "shisui", "yama", "tushita", "canvander",
        "rengoku", "buddy sword", "midnight blade", "hallow scythe",
        "cursed dual katana", "dark blade", "true triple katana",
        "dragon trident", "soul guitar", "spikey trident"
    }
    local isSwordByName = false
    for _, s in ipairs(swordNames) do
        if name:find(s) then isSwordByName = true; break end
    end
    
    -- Known gun names
    local gunNames = {
        "musket", "flintlock", "refined flintlock", "cannon", "kabucha",
        "acidum rifle", "serpent bow", "bizarre rifle", "bazooka", "soul guitar"
    }
    local isGunByName = false
    for _, g in ipairs(gunNames) do
        if name:find(g) then isGunByName = true; break end
    end
    
    if targetType == "Melee" then
        if tip == "Melee" or tool:FindFirstChild("Combat") then return true end
        if isMeleeByName then return true end
        -- Generic "Tool" with no ToolTip and no specific classification = treat as melee accessory
        if not isFruitByName and not isSwordByName and not isGunByName and tip == "" and name == "tool" then return true end
        return false
    elseif targetType == "Sword" then
        if tip == "Sword" or tip == "Melee Weapon" then return true end
        if isSwordByName then return true end
        -- Any unrecognized tool with empty tooltip that isn't fruit/melee/gun = default Sword
        if not isFruitByName and not isMeleeByName and not isGunByName and tip == "" and name ~= "tool" then return true end
        return false
    elseif targetType == "Gun" then
        if tip == "Gun" then return true end
        return isGunByName
    elseif targetType == "Fruit" then
        if tip == "Blox Fruit" then return true end
        return isFruitByName
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
local SetTravelHUD = nil -- Forward declaration for Cockpit HUD
local LandingPlatform = nil

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
    -- Re-enable character collision
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
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

-- Persistent Hover Lock: used STRICTLY for MOB/BOSS FARMING to hover above enemies!
-- NEVER used for Island Teleports (prevents falling through unstreamed terrain / rubberbanding)
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
    if SetTravelHUD then SetTravelHUD(false) end
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

-- TweenTo: used for farming travel and short repositioning
local function TweenTo(targetCFrame, destName)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent or not hum then return end
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    
    if distance < 15 then
        StopTween()
        HoverLock(targetCFrame)
        return
    end
    
    -- Safe Blox Fruits speed limit: 240 studs/s (higher speeds trigger server position rollback!)
    local speed = _G.Config.TweenSpeed or 240
    if speed > 270 then speed = 250 end
    if speed < 150 then speed = 240 end
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    local label = islandName or "Selected Island"
    
    task.spawn(function()
        if SetTravelHUD then SetTravelHUD(true, label, distance, speed) end
        
        -- Request streaming for target location immediately so terrain loads
        pcall(function()
            if LocalPlayer.RequestStreamAroundAsync then
                LocalPlayer:RequestStreamAroundAsync(targetCFrame.Position)
            end
        end)
        
        -- Create invisible safe landing platform so player NEVER drops into void/water
        if LandingPlatform and LandingPlatform.Parent then LandingPlatform:Destroy() end
        LandingPlatform = Instance.new("Part")
        LandingPlatform.Name = "AlphaLandingPlatform"
        LandingPlatform.Size = Vector3.new(35, 2, 35)
        LandingPlatform.CFrame = targetCFrame * CFrame.new(0, -1, 0)
        LandingPlatform.Anchored = true
        LandingPlatform.CanCollide = true
        LandingPlatform.Transparency = 1
        LandingPlatform.Parent = Workspace
        
        EnableNoclip()
        hum.PlatformStand = true
        
        local bv = GetOrCreateBodyVelocity(root)
        bv.Velocity = Vector3.new(0, 0, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        -- Ascend to sky altitude (Y = 380+)
        local skyY = math.max(380, math.max(root.Position.Y, targetCFrame.Position.Y) + 60)
        if root.Position.Y < (skyY - 30) then
            local upCF = CFrame.new(root.Position.X, skyY, root.Position.Z)
            local upDist = (upCF.Position - root.Position).Magnitude
            local upTween = TweenService:Create(root, TweenInfo.new(upDist / speed, Enum.EasingStyle.Linear), {CFrame = upCF})
            CurrentTween = upTween
            upTween:Play()
            upTween.Completed:Wait()
        end
        
        if not root or not root.Parent or not IsTravelingSky then
            if SetTravelHUD then SetTravelHUD(false) end
            return
        end
        
        -- Fly horizontally across the sky to target X, Z
        local skyTargetCF = CFrame.new(targetCFrame.Position.X, skyY, targetCFrame.Position.Z)
        local hDist = (skyTargetCF.Position - root.Position).Magnitude
        if hDist > 25 then
            local hTween = TweenService:Create(root, TweenInfo.new(hDist / speed, Enum.EasingStyle.Linear), {CFrame = skyTargetCF})
            CurrentTween = hTween
            hTween:Play()
            
            local monConn
            monConn = RunService.Heartbeat:Connect(function()
                if not IsTravelingSky or not root or not root.Parent then
                    if monConn then monConn:Disconnect() end
                    return
                end
                local curDist = (targetCFrame.Position - root.Position).Magnitude
                if SetTravelHUD then SetTravelHUD(true, label, curDist, speed) end
            end)
            
            hTween.Completed:Wait()
            if monConn then monConn:Disconnect() end
        end
        
        if not root or not root.Parent or not IsTravelingSky then
            if SetTravelHUD then SetTravelHUD(false) end
            return
        end
        
        -- Request streaming again now that we are directly above the island
        pcall(function()
            if LocalPlayer.RequestStreamAroundAsync then
                LocalPlayer:RequestStreamAroundAsync(targetCFrame.Position)
            end
        end)
        
        -- Descend directly to target position + 4 studs above ground
        local landCF = targetCFrame * CFrame.new(0, 4, 0)
        local downDist = (landCF.Position - root.Position).Magnitude
        local downTween = TweenService:Create(root, TweenInfo.new(downDist / speed, Enum.EasingStyle.Linear), {CFrame = landCF})
        CurrentTween = downTween
        downTween:Play()
        downTween.Completed:Wait()
        
        -- CLEAN LANDING (ZERO RUBBERBAND):
        -- Turn OFF Noclip so character stands solid on island/platform
        DisableNoclip()
        -- Destroy flight BodyVelocity so no phantom forces hold character
        if FlightBodyVel then
            pcall(function() FlightBodyVel:Destroy() end)
            FlightBodyVel = nil
        end
        -- Restore Humanoid physics
        if hum and hum.Parent then
            hum.PlatformStand = false
            hum.Sit = false
        end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        root.CFrame = landCF
        
        IsTravelingSky = false
        if SetTravelHUD then SetTravelHUD(false) end
        
        -- Keep safe landing platform for 4 seconds while terrain finishes loading, then clean up
        task.spawn(function()
            task.wait(4)
            if LandingPlatform and LandingPlatform.Parent then
                LandingPlatform:Destroy()
                LandingPlatform = nil
            end
        end)
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
    -- Sea 1 (First Sea: Lv. 1 - 699)
    {Sea = 1, Min = 1, Max = 9, Quest = "BanditQuest1", Level = 1, Mob = "Bandit", Pos = CFrame.new(1059.37, 16.51, 1546.99)},
    {Sea = 1, Min = 10, Max = 14, Quest = "JungleQuest", Level = 1, Mob = "Monkey", Pos = CFrame.new(-1612.33, 36.85, 149.13)},
    {Sea = 1, Min = 15, Max = 29, Quest = "JungleQuest", Level = 2, Mob = "Gorilla", Pos = CFrame.new(-1240.23, 6.27, -495.22)},
    {Sea = 1, Min = 30, Max = 39, Quest = "BuggyQuest1", Level = 1, Mob = "Pirate", Pos = CFrame.new(-1181.39, 4.75, 3843.43)},
    {Sea = 1, Min = 40, Max = 59, Quest = "BuggyQuest1", Level = 2, Mob = "Brute", Pos = CFrame.new(-1146.47, 77.22, 4476.81)},
    {Sea = 1, Min = 60, Max = 74, Quest = "DesertQuest", Level = 1, Mob = "Desert Bandit", Pos = CFrame.new(1094.11, 6.44, 4192.89)},
    {Sea = 1, Min = 75, Max = 89, Quest = "DesertQuest", Level = 2, Mob = "Desert Officer", Pos = CFrame.new(1568.17, 6.44, 4373.23)},
    {Sea = 1, Min = 90, Max = 99, Quest = "SnowQuest", Level = 1, Mob = "Snow Bandit", Pos = CFrame.new(1384.81, 87.27, -1298.47)},
    {Sea = 1, Min = 100, Max = 119, Quest = "SnowQuest", Level = 2, Mob = "Snowman", Pos = CFrame.new(1384.81, 87.27, -1298.47)},
    {Sea = 1, Min = 120, Max = 149, Quest = "MarineQuest2", Level = 1, Mob = "Chief Petty Officer", Pos = CFrame.new(-5035.79, 28.65, 4324.96)},
    {Sea = 1, Min = 150, Max = 174, Quest = "SkyQuest", Level = 1, Mob = "Sky Bandit", Pos = CFrame.new(-4839.53, 717.67, -2619.44)},
    {Sea = 1, Min = 175, Max = 189, Quest = "SkyQuest", Level = 2, Mob = "Dark Master", Pos = CFrame.new(-4839.53, 717.67, -2619.44)},
    {Sea = 1, Min = 190, Max = 209, Quest = "PrisonerQuest", Level = 1, Mob = "Prisoner", Pos = CFrame.new(4875.33, 5.65, 735.45)},
    {Sea = 1, Min = 210, Max = 249, Quest = "PrisonerQuest", Level = 2, Mob = "Dangerous Prisoner", Pos = CFrame.new(4875.33, 5.65, 735.45)},
    {Sea = 1, Min = 250, Max = 274, Quest = "ColosseumQuest", Level = 1, Mob = "Toga Warrior", Pos = CFrame.new(-1588.34, 7.39, -2982.52)},
    {Sea = 1, Min = 275, Max = 299, Quest = "ColosseumQuest", Level = 2, Mob = "Gladiator", Pos = CFrame.new(-1427.62, 7.28, -2792.77)},
    {Sea = 1, Min = 300, Max = 324, Quest = "MagmaQuest", Level = 1, Mob = "Military Soldier", Pos = CFrame.new(-5389.72, 8.57, 8533.84)},
    {Sea = 1, Min = 325, Max = 374, Quest = "MagmaQuest", Level = 2, Mob = "Military Spy", Pos = CFrame.new(-5815.17, 83.99, 8820.32)},
    {Sea = 1, Min = 375, Max = 399, Quest = "FishmanQuest", Level = 1, Mob = "Fishman Warrior", Pos = CFrame.new(61122.65, 18.50, 1569.40)},
    {Sea = 1, Min = 400, Max = 449, Quest = "FishmanQuest", Level = 2, Mob = "Fishman Commando", Pos = CFrame.new(61845.89, 18.50, 1569.40)},
    {Sea = 1, Min = 450, Max = 474, Quest = "SkyExp1Quest", Level = 1, Mob = "God's Guard", Pos = CFrame.new(-4721.89, 843.87, -1949.97)},
    {Sea = 1, Min = 475, Max = 524, Quest = "SkyExp1Quest", Level = 2, Mob = "Shanda", Pos = CFrame.new(-7894.62, 5545.49, -380.41)},
    {Sea = 1, Min = 525, Max = 549, Quest = "SkyExp2Quest", Level = 1, Mob = "Royal Squad", Pos = CFrame.new(-7906.82, 5635.96, -1411.99)},
    {Sea = 1, Min = 550, Max = 624, Quest = "SkyExp2Quest", Level = 2, Mob = "Royal Soldier", Pos = CFrame.new(-7748.21, 5606.84, -1443.43)},
    {Sea = 1, Min = 625, Max = 649, Quest = "FountainQuest", Level = 1, Mob = "Galley Pirate", Pos = CFrame.new(5589.90, 4.41, 3995.78)},
    {Sea = 1, Min = 650, Max = 699, Quest = "FountainQuest", Level = 2, Mob = "Galley Captain", Pos = CFrame.new(5649.03, 38.51, 4937.42)},

    -- Sea 2 (Second Sea: Lv. 700 - 1499)
    {Sea = 2, Min = 700, Max = 724, Quest = "Area1Quest", Level = 1, Mob = "Raider", Pos = CFrame.new(-429.54, 72.99, 1836.18)},
    {Sea = 2, Min = 725, Max = 774, Quest = "Area1Quest", Level = 2, Mob = "Mercenary", Pos = CFrame.new(-960.61, 74.38, 1729.07)},
    {Sea = 2, Min = 775, Max = 799, Quest = "Area2Quest", Level = 1, Mob = "Swan Pirate", Pos = CFrame.new(878.01, 121.98, 1235.35)},
    {Sea = 2, Min = 800, Max = 874, Quest = "Area2Quest", Level = 2, Mob = "Factory Staff", Pos = CFrame.new(295.34, 73.01, -56.55)},
    {Sea = 2, Min = 875, Max = 899, Quest = "MarineQuest3", Level = 1, Mob = "Marine Lieutenant", Pos = CFrame.new(-2806.12, 72.96, -3038.55)},
    {Sea = 2, Min = 900, Max = 949, Quest = "MarineQuest3", Level = 2, Mob = "Marine Rear Admiral", Pos = CFrame.new(-3424.41, 72.96, -2997.74)},
    {Sea = 2, Min = 950, Max = 974, Quest = "ZombieQuest", Level = 1, Mob = "Zombie", Pos = CFrame.new(-5418.89, 48.52, -774.75)},
    {Sea = 2, Min = 975, Max = 999, Quest = "ZombieQuest", Level = 2, Mob = "Vampire", Pos = CFrame.new(-6033.86, 6.44, -1316.51)},
    {Sea = 2, Min = 1000, Max = 1049, Quest = "SnowMountainQuest", Level = 1, Mob = "Snow Trooper", Pos = CFrame.new(608.24, 401.52, -5372.46)},
    {Sea = 2, Min = 1050, Max = 1099, Quest = "SnowMountainQuest", Level = 2, Mob = "Winter Warrior", Pos = CFrame.new(1157.44, 430.12, -5187.52)},
    {Sea = 2, Min = 1100, Max = 1124, Quest = "IceSideQuest", Level = 1, Mob = "Lab Subordinate", Pos = CFrame.new(-5775.29, 42.44, -4465.17)},
    {Sea = 2, Min = 1125, Max = 1174, Quest = "FireSideQuest", Level = 1, Mob = "Horned Warrior", Pos = CFrame.new(-6411.39, 15.96, -5836.78)},
    {Sea = 2, Min = 1175, Max = 1199, Quest = "FireSideQuest", Level = 2, Mob = "Magma Ninja", Pos = CFrame.new(-5430.72, 76.96, -5949.19)},
    {Sea = 2, Min = 1200, Max = 1249, Quest = "FireSideQuest", Level = 2, Mob = "Lava Pirate", Pos = CFrame.new(-5223.12, 55.96, -4783.21)},
    {Sea = 2, Min = 1250, Max = 1274, Quest = "ShipQuest1", Level = 1, Mob = "Ship Deckhand", Pos = CFrame.new(1198.81, 125.12, 32986.92)},
    {Sea = 2, Min = 1275, Max = 1299, Quest = "ShipQuest1", Level = 2, Mob = "Ship Engineer", Pos = CFrame.new(918.42, 125.12, 32884.28)},
    {Sea = 2, Min = 1300, Max = 1324, Quest = "ShipQuest2", Level = 1, Mob = "Ship Steward", Pos = CFrame.new(915.24, 125.12, 33458.12)},
    {Sea = 2, Min = 1325, Max = 1349, Quest = "ShipQuest2", Level = 2, Mob = "Ship Officer", Pos = CFrame.new(915.24, 180.12, 33458.12)},
    {Sea = 2, Min = 1350, Max = 1399, Quest = "FrostQuest", Level = 1, Mob = "Arctic Warrior", Pos = CFrame.new(6038.45, 28.25, -6231.25)},
    {Sea = 2, Min = 1400, Max = 1424, Quest = "FrostQuest", Level = 2, Mob = "Snow Lurker", Pos = CFrame.new(5560.13, 28.25, -6826.91)},
    {Sea = 2, Min = 1425, Max = 1449, Quest = "ForgottenQuest", Level = 1, Mob = "Sea Soldier", Pos = CFrame.new(-3054.44, 237.15, -10142.82)},
    {Sea = 2, Min = 1450, Max = 1499, Quest = "ForgottenQuest", Level = 2, Mob = "Water Fighter", Pos = CFrame.new(-3435.12, 237.15, -10534.21)},

    -- Sea 3 (Third Sea: Lv. 1500 - 3000)
    {Sea = 3, Min = 1500, Max = 1524, Quest = "PiratePortQuest", Level = 1, Mob = "Pirate Millionaire", Pos = CFrame.new(-290.74, 43.73, 5580.12)},
    {Sea = 3, Min = 1525, Max = 1574, Quest = "PiratePortQuest", Level = 2, Mob = "Pistol Billionaire", Pos = CFrame.new(-468.12, 74.21, 5945.32)},
    {Sea = 3, Min = 1575, Max = 1599, Quest = "DragonCrewQuest", Level = 1, Mob = "Dragon Crew Archer", Pos = CFrame.new(6594.12, 384.12, 142.54)},
    {Sea = 3, Min = 1600, Max = 1624, Quest = "DragonCrewQuest", Level = 2, Mob = "Dragon Crew Warrior", Pos = CFrame.new(6745.23, 384.12, -189.43)},
    {Sea = 3, Min = 1625, Max = 1649, Quest = "VenomCrewQuest", Level = 1, Mob = "Venomous Assailant", Pos = CFrame.new(5210.45, 601.23, 894.12)},
    {Sea = 3, Min = 1650, Max = 1699, Quest = "VenomCrewQuest", Level = 2, Mob = "Hydra Enforcer", Pos = CFrame.new(4512.34, 601.23, 1120.54)},
    {Sea = 3, Min = 1700, Max = 1724, Quest = "DeepForestIsland", Level = 1, Mob = "Marine Commodore", Pos = CFrame.new(2450.12, 73.12, -7320.45)},
    {Sea = 3, Min = 1725, Max = 1774, Quest = "DeepForestIsland", Level = 2, Mob = "Marine Rear Admiral", Pos = CFrame.new(2912.45, 73.12, -7640.12)},
    {Sea = 3, Min = 1775, Max = 1799, Quest = "DeepForestIsland2", Level = 1, Mob = "Fishman Raider", Pos = CFrame.new(-10520.12, 332.12, -8412.34)},
    {Sea = 3, Min = 1800, Max = 1824, Quest = "DeepForestIsland2", Level = 2, Mob = "Fishman Captain", Pos = CFrame.new(-10940.45, 332.12, -8890.12)},
    {Sea = 3, Min = 1825, Max = 1849, Quest = "DeepForestIsland3", Level = 1, Mob = "Forest Pirate", Pos = CFrame.new(-13250.12, 332.12, -7640.54)},
    {Sea = 3, Min = 1850, Max = 1899, Quest = "DeepForestIsland3", Level = 2, Mob = "Mythological Pirate", Pos = CFrame.new(-13560.34, 470.12, -6920.12)},
    {Sea = 3, Min = 1900, Max = 1924, Quest = "DeepForestIsland3", Level = 3, Mob = "Jungle Pirate", Pos = CFrame.new(-12120.45, 332.12, -10540.23)},
    {Sea = 3, Min = 1925, Max = 1974, Quest = "DeepForestIsland3", Level = 4, Mob = "Musketeer Pirate", Pos = CFrame.new(-13140.23, 390.12, -9650.34)},
    {Sea = 3, Min = 1975, Max = 1999, Quest = "HauntedQuest1", Level = 1, Mob = "Reborn Skeleton", Pos = CFrame.new(-8760.12, 141.12, 6050.23)},
    {Sea = 3, Min = 2000, Max = 2024, Quest = "HauntedQuest1", Level = 2, Mob = "Living Zombie", Pos = CFrame.new(-9120.34, 141.12, 5820.45)},
    {Sea = 3, Min = 2025, Max = 2049, Quest = "HauntedQuest2", Level = 1, Mob = "Demonic Soul", Pos = CFrame.new(-9520.45, 172.01, 6120.12)},
    {Sea = 3, Min = 2050, Max = 2074, Quest = "HauntedQuest2", Level = 2, Mob = "Posessed Mummy", Pos = CFrame.new(-9516.99, 12.01, 6078.47)},
    {Sea = 3, Min = 2075, Max = 2099, Quest = "NutsIslandQuest", Level = 1, Mob = "Peanut Scout", Pos = CFrame.new(-2120.34, 38.12, -10190.23)},
    {Sea = 3, Min = 2100, Max = 2124, Quest = "NutsIslandQuest", Level = 2, Mob = "Peanut President", Pos = CFrame.new(-2120.34, 38.12, -10520.45)},
    {Sea = 3, Min = 2125, Max = 2149, Quest = "IceCreamIslandQuest", Level = 1, Mob = "Ice Cream Chef", Pos = CFrame.new(-820.12, 65.12, -10940.34)},
    {Sea = 3, Min = 2150, Max = 2199, Quest = "IceCreamIslandQuest", Level = 2, Mob = "Ice Cream Commander", Pos = CFrame.new(-640.45, 65.12, -11250.12)},
    {Sea = 3, Min = 2200, Max = 2224, Quest = "CakeQuest1", Level = 1, Mob = "Cookie Crafter", Pos = CFrame.new(-2350.12, 38.12, -12020.34)},
    {Sea = 3, Min = 2225, Max = 2249, Quest = "CakeQuest1", Level = 2, Mob = "Cake Guard", Pos = CFrame.new(-1580.45, 38.12, -12340.12)},
    {Sea = 3, Min = 2250, Max = 2274, Quest = "CakeQuest2", Level = 1, Mob = "Baking Staff", Pos = CFrame.new(-1890.23, 38.12, -12950.45)},
    {Sea = 3, Min = 2275, Max = 2299, Quest = "CakeQuest2", Level = 2, Mob = "Head Baker", Pos = CFrame.new(-1920.45, 38.12, -13100.12)},
    {Sea = 3, Min = 2300, Max = 2324, Quest = "ChocQuest1", Level = 1, Mob = "Cocoa Warrior", Pos = CFrame.new(210.12, 24.12, -12350.34)},
    {Sea = 3, Min = 2325, Max = 2349, Quest = "ChocQuest1", Level = 2, Mob = "Chocolate Bar Battler", Pos = CFrame.new(450.45, 24.12, -12650.12)},
    {Sea = 3, Min = 2350, Max = 2374, Quest = "ChocQuest2", Level = 1, Mob = "Sweet Thief", Pos = CFrame.new(712.23, 24.12, -12890.45)},
    {Sea = 3, Min = 2375, Max = 2449, Quest = "ChocQuest2", Level = 2, Mob = "Candy Rebel", Pos = CFrame.new(890.45, 24.12, -13150.12)},
    {Sea = 3, Min = 2450, Max = 2474, Quest = "TikiQuest1", Level = 1, Mob = "Isle Champion", Pos = CFrame.new(-16520.12, 22.12, 60.34)},
    {Sea = 3, Min = 2475, Max = 2499, Quest = "TikiQuest1", Level = 2, Mob = "Island Boy", Pos = CFrame.new(-16800.45, 22.12, 240.12)},
    {Sea = 3, Min = 2500, Max = 2524, Quest = "TikiQuest2", Level = 1, Mob = "Sun-kissed Warrior", Pos = CFrame.new(-16240.23, 22.12, -250.45)},
    {Sea = 3, Min = 2525, Max = 2549, Quest = "TikiQuest2", Level = 2, Mob = "Isle Outlaw", Pos = CFrame.new(-16500.45, 22.12, -450.12)},
    {Sea = 3, Min = 2550, Max = 2574, Quest = "TikiQuest3", Level = 1, Mob = "Serpent Hunter", Pos = CFrame.new(-15120.12, 22.12, 110.34)},
    {Sea = 3, Min = 2575, Max = 3000, Quest = "TikiQuest3", Level = 2, Mob = "Skull Slayer", Pos = CFrame.new(-15400.45, 22.12, 350.12)}
}

local function GetCurrentQuest()
    local level = GetPlayerLevel()
    local best = nil
    for _, q in ipairs(QuestsDB) do
        if q.Sea == CurrentSea and level >= q.Min and level <= q.Max then
            return q
        end
        if q.Sea == CurrentSea then
            best = q
        end
    end
    return best or QuestsDB[1]
end

-- Strictly check if Quest HUD is currently visible and active in game
local function HasQuest()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return false end
    local main = pGui:FindFirstChild("Main")
    if main then
        local q = main:FindFirstChild("Quest")
        if q and q.Visible then
            return true
        end
    end
    return false
end
--============================== MASTER BOSS DATABASE ==============================
local BossesDB = {
    -- Sea 1 (First Sea)
    ["The Gorilla King"] = {Sea = 1, Quest = "JungleQuest", Level = 3, Pos = CFrame.new(-1120.23, 6.27, -495.22)},
    ["Bobby"] = {Sea = 1, Quest = "BuggyQuest1", Level = 3, Pos = CFrame.new(-1146.47, 77.22, 4476.81)},
    ["The Saw"] = {Sea = 1, Quest = nil, Level = 1, Pos = CFrame.new(-682.12, 15.23, 1582.45)},
    ["Yeti"] = {Sea = 1, Quest = "SnowQuest", Level = 3, Pos = CFrame.new(1185.34, 105.12, -1518.23)},
    ["Mob Leader"] = {Sea = 1, Quest = "DesertQuest", Level = 3, Pos = CFrame.new(1568.17, 6.44, 4373.23)},
    ["Vice Admiral"] = {Sea = 1, Quest = "MarineQuest2", Level = 2, Pos = CFrame.new(-4807.23, 20.65, 4360.12)},
    ["Warden"] = {Sea = 1, Quest = "PrisonerQuest", Level = 3, Pos = CFrame.new(5175.23, 5.65, 735.45)},
    ["Chief Warden"] = {Sea = 1, Quest = "PrisonerQuest", Level = 4, Pos = CFrame.new(5175.23, 5.65, 735.45)},
    ["Swan"] = {Sea = 1, Quest = "PrisonerQuest", Level = 5, Pos = CFrame.new(5230.12, 5.65, 760.34)},
    ["Magma Admiral"] = {Sea = 1, Quest = "MagmaQuest", Level = 3, Pos = CFrame.new(-5815.17, 83.99, 8820.32)},
    ["Fishman Lord"] = {Sea = 1, Quest = "FishmanQuest", Level = 3, Pos = CFrame.new(61350.23, 18.50, 1569.40)},
    ["Wyper"] = {Sea = 1, Quest = "SkyExp1Quest", Level = 3, Pos = CFrame.new(-7894.62, 5545.49, -380.41)},
    ["Thunder God"] = {Sea = 1, Quest = "SkyExp2Quest", Level = 3, Pos = CFrame.new(-7748.21, 5606.84, -1443.43)},
    ["Cyborg"] = {Sea = 1, Quest = nil, Level = 1, Pos = CFrame.new(61163.85, 18.49, 1569.25)},
    ["Saber Expert"] = {Sea = 1, Quest = nil, Level = 1, Pos = CFrame.new(-1460.12, 29.85, -30.45)},

    -- Sea 2 (Second Sea)
    ["Diamond"] = {Sea = 2, Quest = "Area1Quest", Level = 3, Pos = CFrame.new(-1580.45, 198.12, -210.34)},
    ["Jeremy"] = {Sea = 2, Quest = "Area2Quest", Level = 3, Pos = CFrame.new(2315.12, 449.12, 785.45)},
    ["Fajita"] = {Sea = 2, Quest = "MarineQuest3", Level = 3, Pos = CFrame.new(-2090.23, 72.96, -4210.12)},
    ["Don Swan"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(2285.45, 15.12, 860.23)},
    ["Smoke Admiral"] = {Sea = 2, Quest = "IceSideQuest", Level = 2, Pos = CFrame.new(-5075.23, 15.96, -5360.45)},
    ["Awakened Ice Admiral"] = {Sea = 2, Quest = "FrostQuest", Level = 3, Pos = CFrame.new(6472.12, 296.12, -6852.34)},
    ["Tide Keeper"] = {Sea = 2, Quest = "ForgottenQuest", Level = 3, Pos = CFrame.new(-3810.45, 77.15, -11520.12)},
    ["Darkbeard"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(3780.03, 22.65, -3498.94)},
    ["Cursed Captain"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(915.24, 180.12, 33458.12)},
    ["Order"] = {Sea = 2, Quest = nil, Level = 1, Pos = CFrame.new(-6500.12, 250.12, -4500.12)},

    -- Sea 3 (Third Sea)
    ["Stone"] = {Sea = 3, Quest = "PiratePortQuest", Level = 3, Pos = CFrame.new(-1050.23, 40.12, 6780.45)},
    ["Island Emperor"] = {Sea = 3, Quest = "DragonCrewQuest", Level = 3, Pos = CFrame.new(5700.12, 601.23, 210.45)},
    ["Kilo Admiral"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(2880.23, 1682.80, -7250.12)},
    ["Captain Elephant"] = {Sea = 3, Quest = "DeepForestIsland2", Level = 3, Pos = CFrame.new(-13390.23, 332.12, -8420.45)},
    ["Beautiful Pirate"] = {Sea = 3, Quest = "DeepForestIsland3", Level = 5, Pos = CFrame.new(-12463.87, 374.91, -7523.77)},
    ["Longma"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(5220.12, 385.12, -340.23)},
    ["Soul Reaper"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-9516.99, 172.01, 6078.47)},
    ["Cake Queen"] = {Sea = 3, Quest = "IceCreamIslandQuest", Level = 3, Pos = CFrame.new(-710.23, 381.12, -11150.45)},
    ["Cake Prince"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-2100.12, 70.12, -12150.34)},
    ["Dough King"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-2100.12, 70.12, -12150.34)},
    ["Rip Indra"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-5330.12, 314.52, -2780.45)},
    ["Tyrant of the Skies"] = {Sea = 3, Quest = nil, Level = 1, Pos = CFrame.new(-16300.12, 850.12, 450.23)}
}

--============================== DYNAMIC SCAN FUNCTIONS (SEA FILTERED) ==============================
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
        if q.Sea == CurrentSea and not seen[q.Mob] then
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
                local bData = BossesDB[enemy.Name]
                if bData and bData.Sea == CurrentSea and not seen[enemy.Name] then
                    seen[enemy.Name] = true
                    table.insert(list, "[Spawned] " .. enemy.Name)
                end
            end
        end
    end
    for bName, bData in pairs(BossesDB) do
        if bData.Sea == CurrentSea and not seen[bName] then
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
            task.wait(0.2)
            if _G.Config.AutoFarmLevel then
                pcall(function()
                    local questInfo = GetCurrentQuest()
                    local root = GetRoot()
                    if not root then return end
                    
                    if not HasQuest() then
                        -- STEP 1: Travel to Quest NPC if far away
                        local npcPos = questInfo.Pos.Position
                        local distToNPC = (npcPos - root.Position).Magnitude
                        
                        if distToNPC > 30 then
                            TweenTo(questInfo.Pos * CFrame.new(0, 4, 0), "Quest NPC (" .. questInfo.Quest .. ")")
                            local t0 = tick()
                            while (questInfo.Pos.Position - root.Position).Magnitude > 35 and (tick() - t0) < 10 and not HasQuest() and _G.Config.AutoFarmLevel do
                                task.wait(0.15)
                            end
                        end
                        
                        -- STEP 2: Talk to Quest NPC within range
                        if (questInfo.Pos.Position - root.Position).Magnitude <= 45 then
                            local cf = CommF()
                            if cf then
                                cf:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
                                task.wait(0.35)
                                if not HasQuest() then
                                    cf:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
                                    task.wait(0.25)
                                end
                            end
                        end
                    else
                        -- STEP 3: Quest active! Farm mobs!
                        local target = FindEnemy(questInfo.Mob)
                        if target and target:FindFirstChild("HumanoidRootPart") then
                            local dist = GetOptimalFarmDistance(target)
                            local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            local distToFarm = (farmPos.Position - root.Position).Magnitude
                            
                            if distToFarm < 15 then
                                HoverLock(farmPos)
                            else
                                TweenTo(farmPos, questInfo.Mob)
                            end
                            EquipWeapon(_G.Config.SelectedWeapon)
                            BringMobsTo(questInfo.Mob, target.HumanoidRootPart.CFrame)
                        else
                            local safePos = questInfo.Pos * CFrame.new(0, 30, 0)
                            local distToSafe = (safePos.Position - root.Position).Magnitude
                            if distToSafe < 15 then
                                HoverLock(safePos)
                            else
                                TweenTo(safePos, "Mob Spawn Point")
                            end
                        end
                    end
                end)
            end
        end
    end)
end

--============================== AUTO FARM SELECTED MOB CORE ==============================
local function StartAutoFarmSelectedMob()
    task.spawn(function()
        task.wait(math.random(8, 20) / 10)
        while true do
            task.wait(0.25)
            if _G.Config.FarmSelectedMob and _G.Config.SelectedMob ~= "" then
                pcall(function()
                    local mobName = _G.Config.SelectedMob:gsub("^%[Spawned%] ", "")
                    local target = FindEnemy(mobName)
                    local root = GetRoot()
                    if not root then return end
                    if target and target:FindFirstChild("HumanoidRootPart") then
                        local dist = GetOptimalFarmDistance(target)
                        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distToFarm = (farmPos.Position - root.Position).Magnitude
                        if distToFarm < 15 then
                            HoverLock(farmPos)
                        else
                            TweenTo(farmPos, mobName)
                        end
                        EquipWeapon(_G.Config.SelectedWeapon)
                        BringMobsTo(mobName, target.HumanoidRootPart.CFrame)
                    else
                        for _, q in ipairs(QuestsDB) do
                            if q.Mob == mobName then
                                local safePos = q.Pos * CFrame.new(0, 35, 0)
                                local distToSafe = (safePos.Position - root.Position).Magnitude
                                if distToSafe < 15 then
                                    HoverLock(safePos)
                                else
                                    TweenTo(safePos, mobName .. " Spawn")
                                end
                                break
                            end
                        end
                    end
                end)
            end
        end
    end)
end

--============================== AUTO FARM SELECTED BOSS CORE ==============================
local function StartAutoFarmSelectedBoss()
    task.spawn(function()
        task.wait(math.random(10, 25) / 10)
        while true do
            task.wait(0.3)
            if _G.Config.FarmSelectedBoss and _G.Config.SelectedBoss ~= "" then
                pcall(function()
                    local bossName = _G.Config.SelectedBoss:gsub("^%[Spawned%] ", "")
                    local bossData = BossesDB[bossName]
                    local target = FindEnemy(bossName)
                    local root = GetRoot()
                    if not root then return end
                    
                    if target and target:FindFirstChild("HumanoidRootPart") then
                        if bossData and bossData.Quest and not HasQuest() then
                            local cf = CommF()
                            if cf then cf:InvokeServer("StartQuest", bossData.Quest, bossData.Level) end
                            task.wait(0.35)
                        end
                        local dist = GetOptimalFarmDistance(target)
                        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distToFarm = (farmPos.Position - root.Position).Magnitude
                        if distToFarm < 15 then
                            HoverLock(farmPos)
                        else
                            TweenTo(farmPos, bossName)
                        end
                        EquipWeapon(_G.Config.SelectedWeapon)
                    else
                        if bossData then
                            local safePos = bossData.Pos * CFrame.new(0, 40, 0)
                            local distToSafe = (safePos.Position - root.Position).Magnitude
                            if distToSafe < 15 then
                                HoverLock(safePos)
                            else
                                TweenTo(safePos, bossName .. " Spawn")
                            end
                        end
                    end
                end)
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
                    local root = GetRoot()
                    if enemies and root then
                        for _, enemy in ipairs(enemies:GetChildren()) do
                            local bData = BossesDB[enemy.Name]
                            if bData and bData.Sea == CurrentSea and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                                if bData.Quest and not HasQuest() then
                                    local cf = CommF()
                                    if cf then cf:InvokeServer("StartQuest", bData.Quest, bData.Level) end
                                    task.wait(0.35)
                                end
                                while enemy and enemy.Parent and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and _G.Config.FarmAllBosses do
                                    local dist = GetOptimalFarmDistance(enemy)
                                    local farmPos = enemy.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                    local distToFarm = (farmPos.Position - root.Position).Magnitude
                                    if distToFarm < 15 then
                                        HoverLock(farmPos)
                                    else
                                        TweenTo(farmPos, enemy.Name)
                                    end
                                    EquipWeapon(_G.Config.SelectedWeapon)
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end
--============================== RAID & SPECIAL BOSSES ==============================
local function FightRaidBoss(bossName)
    local target = FindEnemy(bossName)
    local root = GetRoot()
    if not root then return false end
    if target and target:FindFirstChild("HumanoidRootPart") then
        local dist = GetOptimalFarmDistance(target)
        local farmPos = target.HumanoidRootPart.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        local distToFarm = (farmPos.Position - root.Position).Magnitude
        if distToFarm < 15 then
            HoverLock(farmPos)
        else
            TweenTo(farmPos)
        end
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

--============================== STEALTH UI FRAMEWORK (REDZ 3D CYBER EDITION) ==============================
-- All GUI elements use randomized names via GenerateGUID
-- Full input isolation: Active = true on all containers so clicks NEVER register into the 3D game world!
-- Featuring: 3D Depth layering, smooth TweenService micro-animations, real-time Searchable Dropdowns, and Per-Sea filtering!


-- Tactile Audio Feedback for 3D UI
local SoundService = game:GetService("SoundService")
local function PlayClickSound()
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://6895079853"
        s.Volume = 0.4
        s.Parent = SoundService
        s:Play()
        game:GetService("Debris"):AddItem(s, 1)
    end)
end

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
    
    -- -------------------------------------------------------------
    -- 3D COCKPIT TRAVEL HUD (Appears when traveling long distances)
    -- -------------------------------------------------------------
    local TravelFrame = Instance.new("Frame")
    TravelFrame.Name = RNG()
    TravelFrame.Size = UDim2.new(0, 360, 0, 54)
    TravelFrame.Position = UDim2.new(0.5, -180, 0, -80) -- Starts hidden above screen
    TravelFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    TravelFrame.BorderSizePixel = 0
    TravelFrame.Active = true
    TravelFrame.ZIndex = 60
    TravelFrame.Parent = ScreenGui
    
    local TravelCorner = Instance.new("UICorner")
    TravelCorner.CornerRadius = UDim.new(0, 10)
    TravelCorner.Parent = TravelFrame
    
    local TravelStroke = Instance.new("UIStroke")
    TravelStroke.Color = Color3.fromRGB(255, 42, 95)
    TravelStroke.Thickness = 1.6
    TravelStroke.Parent = TravelFrame
    
    local TravelGrad = Instance.new("UIGradient")
    TravelGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 38)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 18))
    }
    TravelGrad.Rotation = 90
    TravelGrad.Parent = TravelFrame
    
    local TravelTitle = Instance.new("TextLabel")
    TravelTitle.Size = UDim2.new(1, -95, 0, 24)
    TravelTitle.Position = UDim2.new(0, 14, 0, 6)
    TravelTitle.Text = "✈️ FLYING TO: DESTINATION"
    TravelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    TravelTitle.Font = Enum.Font.GothamBold
    TravelTitle.TextSize = 12
    TravelTitle.TextXAlignment = Enum.TextXAlignment.Left
    TravelTitle.BackgroundTransparency = 1
    TravelTitle.ZIndex = 61
    TravelTitle.Parent = TravelFrame
    
    local TravelDist = Instance.new("TextLabel")
    TravelDist.Size = UDim2.new(1, -95, 0, 18)
    TravelDist.Position = UDim2.new(0, 14, 0, 28)
    TravelDist.Text = "Distance: 0 studs • Speed: 350 studs/s"
    TravelDist.TextColor3 = Color3.fromRGB(180, 180, 205)
    TravelDist.Font = Enum.Font.Gotham
    TravelDist.TextSize = 10
    TravelDist.TextXAlignment = Enum.TextXAlignment.Left
    TravelDist.BackgroundTransparency = 1
    TravelDist.ZIndex = 61
    TravelDist.Parent = TravelFrame
    
    local CancelFlightBtn = Instance.new("TextButton")
    CancelFlightBtn.Size = UDim2.new(0, 74, 0, 32)
    CancelFlightBtn.Position = UDim2.new(1, -84, 0.5, -16)
    CancelFlightBtn.Text = "✕ CANCEL"
    CancelFlightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelFlightBtn.Font = Enum.Font.GothamBold
    CancelFlightBtn.TextSize = 10
    CancelFlightBtn.BackgroundColor3 = Color3.fromRGB(220, 35, 70)
    CancelFlightBtn.BorderSizePixel = 0
    CancelFlightBtn.Active = true
    CancelFlightBtn.ZIndex = 62
    CancelFlightBtn.Parent = TravelFrame
    local CFCorner = Instance.new("UICorner")
    CFCorner.CornerRadius = UDim.new(0, 6)
    CFCorner.Parent = CancelFlightBtn
    
    CancelFlightBtn.MouseButton1Click:Connect(function()
        StopTween()
    end)
    
    local isTravelHUDActive = false
    SetTravelHUD = function(visible, destName, dist, spd)
        if visible then
            TravelTitle.Text = "✈️ FLYING TO: " .. tostring(destName or "TARGET"):upper()
            TravelDist.Text = "Distance: " .. math.floor(dist or 0) .. " studs • Speed: " .. math.floor(spd or 350)
            if not isTravelHUDActive then
                isTravelHUDActive = true
                TweenService:Create(TravelFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -180, 0, 68)}):Play()
            end
        else
            if isTravelHUDActive then
                isTravelHUDActive = false
                TweenService:Create(TravelFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -180, 0, -80)}):Play()
            end
        end
    end
    
    -- -------------------------------------------------------------
    -- 3D DEEP SHADOW LAYER
    -- -------------------------------------------------------------
    local ShadowFrame = Instance.new("Frame")
    ShadowFrame.Name = RNG()
    ShadowFrame.Size = UDim2.new(0, 610, 0, 385)
    ShadowFrame.Position = UDim2.new(0.5, -295, 0.5, -180) -- 5px 3D offset
    ShadowFrame.BackgroundColor3 = Color3.fromRGB(4, 4, 7)
    ShadowFrame.BackgroundTransparency = 0.35
    ShadowFrame.BorderSizePixel = 0
    ShadowFrame.Parent = ScreenGui
    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 14)
    ShadowCorner.Parent = ShadowFrame
    
    -- -------------------------------------------------------------
    -- MAIN CONTAINER (3D Obsidian Cyber Glass)
    -- -------------------------------------------------------------
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = RNG()
    MainFrame.Size = UDim2.new(0, 600, 0, 375)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -187)
    MainFrame.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true -- Input isolation
    MainFrame.Parent = ScreenGui
    
    -- Smooth 3D Entrance Bounce Animation on load
    MainFrame.Size = UDim2.new(0, 520, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 600, 0, 375),
        Position = UDim2.new(0.5, -300, 0.5, -187)
    }):Play()
    
    local function SyncShadow()
        ShadowFrame.Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset + 5, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset + 6)
        ShadowFrame.Size = UDim2.new(0, MainFrame.AbsoluteSize.X + 10, 0, MainFrame.AbsoluteSize.Y + 10)
        ShadowFrame.Visible = MainFrame.Visible
    end
    MainFrame:GetPropertyChangedSignal("Position"):Connect(SyncShadow)
    MainFrame:GetPropertyChangedSignal("Visible"):Connect(SyncShadow)
    
    MainFrame.MouseEnter:Connect(function() _G.UIInteracting = true end)
    MainFrame.MouseLeave:Connect(function() _G.UIInteracting = false end)
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(255, 42, 95)
    MainStroke.Thickness = 1.6
    MainStroke.Transparency = 0.2
    MainStroke.Parent = MainFrame
    
    -- 3D Top Bevel Highlight Line
    local TopHighlight = Instance.new("Frame")
    TopHighlight.Size = UDim2.new(1, 0, 0, 1)
    TopHighlight.Position = UDim2.new(0, 0, 0, 0)
    TopHighlight.BackgroundColor3 = Color3.fromRGB(255, 120, 160)
    TopHighlight.BackgroundTransparency = 0.5
    TopHighlight.BorderSizePixel = 0
    TopHighlight.ZIndex = 10
    TopHighlight.Parent = MainFrame
    
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
    
    -- Top Bar with Metallic Gradient
    local TopBar = Instance.new("Frame")
    TopBar.Name = RNG()
    TopBar.Size = UDim2.new(1, 0, 0, 44)
    TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.Parent = MainFrame
    
    local TopBarGrad = Instance.new("UIGradient")
    TopBarGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 16, 24))
    }
    TopBarGrad.Rotation = 90
    TopBarGrad.Parent = TopBar
    
    local TopStroke = Instance.new("UIStroke")
    TopStroke.Color = Color3.fromRGB(38, 38, 54)
    TopStroke.Thickness = 1
    TopStroke.Parent = TopBar
    
    -- 3D Logo Badge
    local LogoBadge = Instance.new("Frame")
    LogoBadge.Size = UDim2.new(0, 26, 0, 26)
    LogoBadge.Position = UDim2.new(0, 12, 0, 9)
    LogoBadge.BackgroundColor3 = Color3.fromRGB(255, 42, 95)
    LogoBadge.BorderSizePixel = 0
    LogoBadge.Parent = TopBar
    local LBCorner = Instance.new("UICorner")
    LBCorner.CornerRadius = UDim.new(0, 6)
    LBCorner.Parent = LogoBadge
    local LBLabel = Instance.new("TextLabel")
    LBLabel.Size = UDim2.new(1, 0, 1, 0)
    LBLabel.Text = "α"
    LBLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    LBLabel.Font = Enum.Font.GothamBold
    LBLabel.TextSize = 16
    LBLabel.BackgroundTransparency = 1
    LBLabel.Parent = LogoBadge
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 220, 1, 0)
    TitleLabel.Position = UDim2.new(0, 46, 0, 0)
    TitleLabel.Text = "ALPHA // 3D CYBER HUB"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Active = true
    TitleLabel.Parent = TopBar
    
    -- Sea Status Pill Badge
    local SeaBadge = Instance.new("Frame")
    SeaBadge.Size = UDim2.new(0, 95, 0, 22)
    SeaBadge.Position = UDim2.new(0, 245, 0, 11)
    SeaBadge.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    SeaBadge.BorderSizePixel = 0
    SeaBadge.Parent = TopBar
    local SBCorner = Instance.new("UICorner")
    SBCorner.CornerRadius = UDim.new(1, 0)
    SBCorner.Parent = SeaBadge
    local SBStroke = Instance.new("UIStroke")
    SBStroke.Color = Color3.fromRGB(255, 45, 95)
    SBStroke.Thickness = 1
    SBStroke.Transparency = 0.4
    SBStroke.Parent = SeaBadge
    local SBLabel = Instance.new("TextLabel")
    SBLabel.Size = UDim2.new(1, 0, 1, 0)
    SBLabel.Text = "🌊 " .. SeaName
    SBLabel.TextColor3 = Color3.fromRGB(255, 90, 135)
    SBLabel.Font = Enum.Font.GothamBold
    SBLabel.TextSize = 10
    SBLabel.BackgroundTransparency = 1
    SBLabel.Parent = SeaBadge
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0, 8)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.BackgroundColor3 = Color3.fromRGB(38, 22, 32)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Active = true
    CloseBtn.Parent = TopBar
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 35, 70)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 22, 32)}):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 520, 0, 320),
            Position = UDim2.new(0.5, -260, 0.5, -160)
        }):Play()
        task.wait(0.25)
        MainFrame.Visible = false
    end)
    
    -- Floating Reopen Button with continuous breathing neon pulse
    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = RNG()
    FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
    FloatingBtn.Position = UDim2.new(0, 20, 0.5, -26)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    FloatingBtn.Text = "ALPHA"
    FloatingBtn.TextColor3 = Color3.fromRGB(255, 50, 100)
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
    FloatStroke.Thickness = 2
    FloatStroke.Parent = FloatingBtn
    
    task.spawn(function()
        while true do
            TweenService:Create(FloatStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.65}):Play()
            task.wait(1.2)
            TweenService:Create(FloatStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.1}):Play()
            task.wait(1.2)
        end
    end)
    
    local fDragging, fDragInput, fDragStart, fStartPos
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            fDragging = true
            fDragStart = input.Position
            fStartPos = FloatingBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then fDragging = false end
            end)
        end
    end)
    FloatingBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            fDragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == fDragInput and fDragging then
            local delta = input.Position - fDragStart
            FloatingBtn.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
        end
    end)
    FloatingBtn.MouseButton1Click:Connect(function()
        if not MainFrame.Visible then
            MainFrame.Visible = true
            MainFrame.Size = UDim2.new(0, 520, 0, 320)
            MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
            TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 600, 0, 375),
                Position = UDim2.new(0.5, -300, 0.5, -187)
            }):Play()
        else
            MainFrame.Visible = false
        end
    end)
    
    -- Left Sidebar
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = RNG()
    Sidebar.Size = UDim2.new(0, 145, 1, -44)
    Sidebar.Position = UDim2.new(0, 0, 0, 44)
    Sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 2
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 390)
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
    ContentHolder.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
    ContentHolder.BorderSizePixel = 0
    ContentHolder.Active = true
    ContentHolder.Parent = MainFrame
local Tabs = {}
    local CurrentActiveTab = nil
    
    local function SwitchTab(tabName)
        for name, page in pairs(Tabs) do
            if name == tabName then
                page.Page.Position = UDim2.new(0, 0, 0, 8)
                page.Page.Visible = true
                TweenService:Create(page.Page, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
                if page.Btn then
                    TweenService:Create(page.Btn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(255, 42, 95), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                end
            else
                page.Page.Visible = false
                if page.Btn then
                    TweenService:Create(page.Btn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(22, 22, 30), TextColor3 = Color3.fromRGB(160, 160, 180)}):Play()
                end
            end
        end
        CurrentActiveTab = tabName
    end
    
    local function CreateTab(name)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, -12, 0, 28)
        TabBtn.Text = name
        TabBtn.TextColor3 = Color3.fromRGB(160, 160, 180)
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 11
        TabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
        TabBtn.BorderSizePixel = 0
        TabBtn.Active = true
        TabBtn.Parent = Sidebar
        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 5)
        TabBtnCorner.Parent = TabBtn
        
        -- Micro hover animation for tab buttons
        TabBtn.MouseEnter:Connect(function()
            if CurrentActiveTab ~= name then
                TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 42), TextColor3 = Color3.fromRGB(210, 210, 230)}):Play()
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if CurrentActiveTab ~= name then
                TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(22, 22, 30), TextColor3 = Color3.fromRGB(160, 160, 180)}):Play()
            end
        end)
        
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
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 28)
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
        
        function TabAPI:AddNotice(text, color)
            local NFrame = Instance.new("Frame")
            NFrame.Size = UDim2.new(1, -16, 0, 32)
            NFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
            NFrame.BorderSizePixel = 0
            NFrame.Parent = Page
            local NCorner = Instance.new("UICorner")
            NCorner.CornerRadius = UDim.new(0, 6)
            NCorner.Parent = NFrame
            local NStroke = Instance.new("UIStroke")
            NStroke.Color = color or Color3.fromRGB(255, 180, 50)
            NStroke.Thickness = 1
            NStroke.Transparency = 0.4
            NStroke.Parent = NFrame
            
            local NText = Instance.new("TextLabel")
            NText.Size = UDim2.new(1, -16, 1, 0)
            NText.Position = UDim2.new(0, 8, 0, 0)
            NText.Text = text
            NText.TextColor3 = color or Color3.fromRGB(255, 200, 80)
            NText.Font = Enum.Font.GothamMedium
            NText.TextSize = 10
            NText.TextXAlignment = Enum.TextXAlignment.Left
            NText.BackgroundTransparency = 1
            NText.Parent = NFrame
        end
        
        function TabAPI:AddToggle(title, defaultVal, callback)
            local isChecked = defaultVal or false
            local ToggleFrame = Instance.new("Frame")
            ToggleFrame.Size = UDim2.new(1, -16, 0, 34)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(19, 19, 27)
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Active = true
            ToggleFrame.Parent = Page
            local TCorner = Instance.new("UICorner")
            TCorner.CornerRadius = UDim.new(0, 6)
            TCorner.Parent = ToggleFrame
            
            local TStroke = Instance.new("UIStroke")
            TStroke.Color = Color3.fromRGB(35, 35, 48)
            TStroke.Thickness = 1
            TStroke.Parent = ToggleFrame
            
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
            Switch.BackgroundColor3 = isChecked and Color3.fromRGB(255, 42, 95) or Color3.fromRGB(42, 42, 55)
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
                local targetColor = isChecked and Color3.fromRGB(255, 42, 95) or Color3.fromRGB(42, 42, 55)
                local targetPos = isChecked and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                TweenService:Create(Switch, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = targetColor}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = targetPos}):Play()
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
            Btn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
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
            local BStroke = Instance.new("UIStroke")
            BStroke.Color = Color3.fromRGB(38, 38, 52)
            BStroke.Thickness = 1
            BStroke.Parent = Btn
            
            -- Smooth micro-animations
            Btn.MouseEnter:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(34, 34, 48)}):Play()
            end)
            Btn.MouseLeave:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(22, 22, 32)}):Play()
            end)
            Btn.MouseButton1Click:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(255, 42, 95)}):Play()
                task.wait(0.1)
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(22, 22, 32)}):Play()
                if callback then pcall(callback) end
            end)
        end
        
        -- -------------------------------------------------------------
        -- SEARCHABLE DROPDOWN WITH REAL-TIME FILTER
        -- -------------------------------------------------------------
        function TabAPI:AddSearchDropdown(title, options, defaultVal, callback)
            local selected = defaultVal or (options and options[1]) or ""
            local allOptions = options or {}
            local filteredOptions = allOptions
            
            local DropFrame = Instance.new("Frame")
            DropFrame.Size = UDim2.new(1, -16, 0, 34)
            DropFrame.BackgroundColor3 = Color3.fromRGB(19, 19, 27)
            DropFrame.BorderSizePixel = 0
            DropFrame.ClipsDescendants = true
            DropFrame.Active = true
            DropFrame.Parent = Page
            local DCorner = Instance.new("UICorner")
            DCorner.CornerRadius = UDim.new(0, 6)
            DCorner.Parent = DropFrame
            local DStroke = Instance.new("UIStroke")
            DStroke.Color = Color3.fromRGB(36, 36, 50)
            DStroke.Thickness = 1
            DStroke.Parent = DropFrame
            
            local DTitle = Instance.new("TextLabel")
            DTitle.Size = UDim2.new(0, 150, 0, 34)
            DTitle.Position = UDim2.new(0, 10, 0, 0)
            DTitle.Text = title
            DTitle.TextColor3 = Color3.fromRGB(220, 220, 230)
            DTitle.Font = Enum.Font.Gotham
            DTitle.TextSize = 11
            DTitle.TextXAlignment = Enum.TextXAlignment.Left
            DTitle.BackgroundTransparency = 1
            DTitle.Active = true
            DTitle.Parent = DropFrame
            
            local SelectBtn = Instance.new("TextButton")
            SelectBtn.Size = UDim2.new(0, 215, 0, 24)
            SelectBtn.Position = UDim2.new(1, -225, 0, 5)
            SelectBtn.Text = tostring(selected) .. " ▾"
            SelectBtn.TextColor3 = Color3.fromRGB(255, 75, 125)
            SelectBtn.Font = Enum.Font.GothamMedium
            SelectBtn.TextSize = 10
            SelectBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
            SelectBtn.BorderSizePixel = 0
            SelectBtn.Active = true
            SelectBtn.Parent = DropFrame
            local SBCorner = Instance.new("UICorner")
            SBCorner.CornerRadius = UDim.new(0, 5)
            SBCorner.Parent = SelectBtn
            
            -- Search input box
            local SearchBox = Instance.new("TextBox")
            SearchBox.Size = UDim2.new(1, -16, 0, 24)
            SearchBox.Position = UDim2.new(0, 8, 0, 36)
            SearchBox.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
            SearchBox.PlaceholderText = "🔍 Type to filter " .. title .. "..."
            SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
            SearchBox.Text = ""
            SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            SearchBox.Font = Enum.Font.Gotham
            SearchBox.TextSize = 10
            SearchBox.ClearTextOnFocus = false
            SearchBox.BorderSizePixel = 0
            SearchBox.Active = true
            SearchBox.Visible = false
            SearchBox.Parent = DropFrame
            local SearchCorner = Instance.new("UICorner")
            SearchCorner.CornerRadius = UDim.new(0, 4)
            SearchCorner.Parent = SearchBox
            local SearchStroke = Instance.new("UIStroke")
            SearchStroke.Color = Color3.fromRGB(255, 42, 95)
            SearchStroke.Thickness = 0.8
            SearchStroke.Transparency = 0.5
            SearchStroke.Parent = SearchBox
            
            local ListScroll = Instance.new("ScrollingFrame")
            ListScroll.Size = UDim2.new(1, -16, 0, 115)
            ListScroll.Position = UDim2.new(0, 8, 0, 65)
            ListScroll.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
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
                    OptBtn.TextColor3 = (opt == selected) and Color3.fromRGB(255, 75, 125) or Color3.fromRGB(205, 205, 215)
                    OptBtn.Font = (opt == selected) and Enum.Font.GothamBold or Enum.Font.Gotham
                    OptBtn.TextSize = 10
                    OptBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
                    OptBtn.BorderSizePixel = 0
                    OptBtn.Active = true
                    OptBtn.Parent = ListScroll
                    
                    OptBtn.MouseEnter:Connect(function()
                        TweenService:Create(OptBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(38, 38, 54)}):Play()
                    end)
                    OptBtn.MouseLeave:Connect(function()
                        TweenService:Create(OptBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(22, 22, 32)}):Play()
                    end)
                    
                    OptBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        SelectBtn.Text = tostring(selected) .. " ▾"
                        isOpen = false
                        TweenService:Create(DropFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -16, 0, 34)}):Play()
                        task.wait(0.2)
                        SearchBox.Visible = false
                        ListScroll.Visible = false
                        if callback then pcall(callback, selected) end
                    end)
                end
                ListScroll.CanvasSize = UDim2.new(0, 0, 0, #opts * 24)
            end
            
            SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local query = SearchBox.Text:lower()
                if query == "" then
                    filteredOptions = allOptions
                else
                    filteredOptions = {}
                    for _, opt in ipairs(allOptions) do
                        if tostring(opt):lower():find(query) then
                            table.insert(filteredOptions, opt)
                        end
                    end
                end
                Populate(filteredOptions)
            end)
            
            SelectBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    SearchBox.Visible = true
                    ListScroll.Visible = true
                    SearchBox.Text = ""
                    filteredOptions = allOptions
                    Populate(filteredOptions)
                    TweenService:Create(DropFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -16, 0, 188)}):Play()
                else
                    TweenService:Create(DropFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, -16, 0, 34)}):Play()
                    task.wait(0.2)
                    if not isOpen then
                        SearchBox.Visible = false
                        ListScroll.Visible = false
                    end
                end
            end)
            
            Populate(allOptions)
            
            local DropAPI = {}
            function DropAPI:SetOptions(newOpts)
                allOptions = newOpts
                filteredOptions = newOpts
                Populate(newOpts)
            end
            function DropAPI:Get()
                return selected
            end
            return DropAPI
        end
        
        function TabAPI:AddDropdown(title, options, defaultVal, callback)
            return TabAPI:AddSearchDropdown(title, options, defaultVal, callback)
        end
        
        function TabAPI:AddSlider(title, min, max, defaultVal, callback)
            local current = defaultVal or min
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Size = UDim2.new(1, -16, 0, 44)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(19, 19, 27)
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Active = true
            SliderFrame.Parent = Page
            local SlCorner = Instance.new("UICorner")
            SlCorner.CornerRadius = UDim.new(0, 6)
            SlCorner.Parent = SliderFrame
            local SlStroke = Instance.new("UIStroke")
            SlStroke.Color = Color3.fromRGB(35, 35, 48)
            SlStroke.Thickness = 1
            SlStroke.Parent = SliderFrame
            
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
            Bar.BackgroundColor3 = Color3.fromRGB(36, 36, 48)
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
            local function UpdateSlide(input)
                local relX = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                current = math.floor(min + (max - min) * relX)
                TweenService:Create(Fill, TweenInfo.new(0.08), {Size = UDim2.new(relX, 0, 1, 0)}):Play()
                SValue.Text = tostring(current)
                if callback then pcall(callback, current) end
            end
            
            Bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isSliding = true
                    _G.UIInteracting = true
                    UpdateSlide(input)
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
                    UpdateSlide(input)
                end
            end)
        end
        
        return TabAPI
    end
    
    -- Instantiate Tabs
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
    
    -- ==================== 1. MAIN FARM ====================
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
    
    FarmTab:AddSection("Select Mob Farming (" .. SeaName .. ")")
    local MobDrop = FarmTab:AddSearchDropdown("Select Mob", GetSpawnedMobsList(), GetSpawnedMobsList()[1] or "Bandit", function(v) _G.Config.SelectedMob = v end)
    FarmTab:AddButton("Refresh Mobs List (" .. SeaName .. ")", function()
        local updated = GetSpawnedMobsList()
        MobDrop:SetOptions(updated)
    end)
    FarmTab:AddToggle("Auto Farm Selected Mob", false, function(v)
        _G.Config.FarmSelectedMob = v
        if not v then FullResetMovement() end
    end)
    
    -- ==================== 2. BOSS FARM ====================
    BossTab:AddSection("Select Boss Farming (" .. SeaName .. ")")
    local BossDrop = BossTab:AddSearchDropdown("Select Boss", GetSpawnedBossesList(), GetSpawnedBossesList()[1] or "The Gorilla King", function(v) _G.Config.SelectedBoss = v end)
    BossTab:AddButton("Refresh Bosses List (Scan Active)", function()
        local updated = GetSpawnedBossesList()
        BossDrop:SetOptions(updated)
    end)
    BossTab:AddToggle("Auto Farm Selected Boss", false, function(v)
        _G.Config.FarmSelectedBoss = v
        if not v then StopTween() end
    end)
    BossTab:AddToggle("Auto Farm All Spawned Bosses (" .. SeaName .. ")", false, function(v)
        _G.Config.FarmAllBosses = v
        if not v then StopTween() end
    end)
    
    -- World & Raid Bosses filtered by current sea
    BossTab:AddSection("World & Special Bosses")
    if Sea3 then
        BossTab:AddToggle("Auto Kill Rip Indra", false, function(v) _G.Config.AutoKillRipIndra = v end)
        BossTab:AddToggle("Auto Kill Dough King", false, function(v) _G.Config.AutoKillDoughKing = v end)
        BossTab:AddToggle("Auto Kill Cake Prince", false, function(v) _G.Config.AutoKillCakePrince = v end)
        BossTab:AddToggle("Auto Kill Soul Reaper", false, function(v) _G.Config.AutoKillSoulReaper = v end)
    elseif Sea2 then
        BossTab:AddToggle("Auto Kill Darkbeard", false, function(v) _G.Config.AutoKillDarkbeard = v end)
        BossTab:AddToggle("Auto Kill Cursed Captain", false, function(v) _G.Config.AutoKillCursedCaptain = v end)
        BossTab:AddToggle("Auto Kill Order (Law)", false, function(v) _G.Config.AutoKillLaw = v end)
    else
        BossTab:AddNotice("World Raid Bosses (Indra, Dough King, Darkbeard) are located in Second & Third Sea.", Color3.fromRGB(255, 170, 70))
    end
    
    -- ==================== 3. DUNGEON & RAIDS ====================
    RaidTab:AddSection("Raid Controls")
    if Sea1 then
        RaidTab:AddNotice("🔒 Raids unlock at Level 1100 in Second Sea.", Color3.fromRGB(255, 150, 70))
    else
        RaidTab:AddSearchDropdown("Select Raid Chip", {"Flame", "Ice", "Quake", "Light", "Dark", "String", "Rumble", "Magma", "Human: Buddha", "Phoenix", "Dough"}, "Flame", function(v) _G.Config.SelectedChip = v end)
        RaidTab:AddToggle("Auto Buy Raid Chip", false, function(v) _G.Config.AutoBuyChip = v end)
        RaidTab:AddToggle("Auto Start Raid", false, function(v) _G.Config.AutoStartRaid = v end)
        RaidTab:AddToggle("Auto Farm Raid (Next Island)", false, function(v) _G.Config.AutoFarmRaid = v end)
        RaidTab:AddToggle("Auto Awaken Fruit", false, function(v) _G.Config.AutoAwaken = v end)
    end
    
    -- ==================== 4. DEVIL FRUIT ====================
    FruitTab:AddSection("Fruit Actions")
    FruitTab:AddToggle("Auto Random Fruit (Gacha Cousin)", false, function(v) _G.Config.AutoRandomFruit = v end)
    FruitTab:AddToggle("Auto Store Fruits in Inventory", true, function(v) _G.Config.AutoStoreFruit = v end)
    FruitTab:AddToggle("Auto Grab Dropped Fruits (Tween)", false, function(v) _G.Config.AutoGrabFruits = v end)
    FruitTab:AddToggle("Fruit ESP (Billboard Labels)", false, function(v)
        _G.Config.FruitESP = v
        UpdateFruitESP()
    end)
    
    -- ==================== 5. SEA EVENTS ====================
    SeaTab:AddSection("Sea Events & Mirage")
    if Sea1 then
        SeaTab:AddNotice("🔒 Sea Events & Mirage Island unlock in Second & Third Sea.", Color3.fromRGB(100, 180, 255))
    else
        SeaTab:AddToggle("Auto Kill Sharks", false, function(v) _G.Config.AutoKillShark = v end)
        SeaTab:AddToggle("Auto Kill Terror Shark", false, function(v) _G.Config.AutoKillTerrorShark = v end)
        SeaTab:AddToggle("Auto Kill Sea Beast", false, function(v) _G.Config.AutoKillSeaBeast = v end)
        SeaTab:AddButton("Check Mirage Island Status", function()
            local s = CheckIslandSpawn("MysticIsland") or CheckIslandSpawn("Mirage Island")
            print("[ALPHA] Mirage Island:", s and "SPAWNED!" or "NOT Spawned")
        end)
        SeaTab:AddButton("Check Kitsune Island Status", function()
            local s = CheckIslandSpawn("KitsuneIsland") or CheckIslandSpawn("Kitsune Island")
            print("[ALPHA] Kitsune Island:", s and "SPAWNED!" or "NOT Spawned")
        end)
        SeaTab:AddToggle("Auto Find Blue Gear (Mirage)", false, function(v) _G.Config.AutoFindGear = v end)
        SeaTab:AddToggle("Auto Pull Lever (Temple of Time)", false, function(v) _G.Config.AutoPullLever = v end)
    end
    
    -- ==================== 6. ITEMS & QUESTS ====================
    ItemTab:AddSection("Special Quests & Sea Travel")
    if Sea1 then
        ItemTab:AddButton("Auto Saber Quest", function() local cf = CommF(); if cf then cf:InvokeServer("ProQuestProgress", "RichSon") end end)
        ItemTab:AddButton("Travel to Second Sea (Requires Lv. 700)", function() local cf = CommF(); if cf then cf:InvokeServer("TravelDressrosa") end end)
    elseif Sea2 then
        ItemTab:AddButton("Auto Bartilo Quest", function() local cf = CommF(); if cf then cf:InvokeServer("BartiloQuestProgress", "GetMission") end end)
        ItemTab:AddButton("Travel to Third Sea (Requires Lv. 1500)", function() local cf = CommF(); if cf then cf:InvokeServer("TravelZou") end end)
    else
        ItemTab:AddNotice("You have reached the Third Sea!", Color3.fromRGB(100, 255, 150))
    end
    
    -- ==================== 7. STATS ALLOCATOR ====================
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
    
    -- ==================== 8. SHOP ====================
    ShopTab:AddSection("Fighting Styles")
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
    
    -- ==================== 9. TELEPORTS (PER-SEA ONLY) ====================
    TeleportTab:AddSection("Island Teleports (" .. SeaName .. ")")
    
    local AllIslands = {
        [1] = {
            ["Pirate Starter (Lv. 1)"] = CFrame.new(1059.37, 16.51, 1546.99),
            ["Marine Starter (Lv. 1)"] = CFrame.new(-2573.39, 6.94, 2059.27),
            ["Middle Town"] = CFrame.new(-655.82, 7.84, 1588.65),
            ["Jungle (Lv. 15)"] = CFrame.new(-1612.33, 36.85, 149.13),
            ["Pirate Village (Lv. 30)"] = CFrame.new(-1181.39, 4.75, 3843.43),
            ["Desert (Lv. 60)"] = CFrame.new(1094.11, 6.44, 4192.89),
            ["Snow Island (Lv. 90)"] = CFrame.new(1384.81, 87.27, -1298.47),
            ["Marineford (Lv. 120)"] = CFrame.new(-5035.79, 28.65, 4324.96),
            ["Sky Island (Lv. 150)"] = CFrame.new(-4839.53, 717.67, -2619.44),
            ["Upper Sky (Lv. 450)"] = CFrame.new(-7894.62, 5545.49, -380.41),
            ["Prison (Lv. 190)"] = CFrame.new(4875.33, 5.65, 735.45),
            ["Colosseum (Lv. 250)"] = CFrame.new(-1427.62, 7.28, -2792.77),
            ["Magma Village (Lv. 300)"] = CFrame.new(-5247.72, 8.57, 8504.68),
            ["Underwater City (Lv. 375)"] = CFrame.new(61163.85, 18.49, 1569.25),
            ["Fountain City (Lv. 625)"] = CFrame.new(5127.13, 59.50, 4105.45)
        },
        [2] = {
            ["Cafe (Safe Zone)"] = CFrame.new(-380.47, 77.22, 255.82),
            ["Mansion (Swan)"] = CFrame.new(-417.47, 332.18, 595.66),
            ["Kingdom of Rose (Lv. 700)"] = CFrame.new(878.01, 121.98, 1235.35),
            ["Green Zone (Lv. 875)"] = CFrame.new(-2448.53, 73.02, -3210.63),
            ["Graveyard (Lv. 950)"] = CFrame.new(-5418.89, 48.52, -774.75),
            ["Snow Mountain (Lv. 1000)"] = CFrame.new(608.24, 401.52, -5372.46),
            ["Hot and Cold (Lv. 1100)"] = CFrame.new(-6026.96, 15.96, -5071.29),
            ["Cursed Ship (Lv. 1250)"] = CFrame.new(923.21, 126.98, 32852.83),
            ["Ice Castle (Lv. 1350)"] = CFrame.new(5422.31, 28.25, -6767.13),
            ["Forgotten Island (Lv. 1425)"] = CFrame.new(-3054.44, 237.15, -10142.82),
            ["Dark Arena (Darkbeard)"] = CFrame.new(3780.03, 22.65, -3498.94)
        },
        [3] = {
            ["Port Town (Lv. 1500)"] = CFrame.new(-290.74, 6.73, 5343.55),
            ["Hydra Island (Lv. 1575)"] = CFrame.new(5749.73, 610.42, -267.78),
            ["Great Tree (Lv. 1700)"] = CFrame.new(2681.27, 1682.80, -7190.99),
            ["Floating Turtle (Lv. 1775)"] = CFrame.new(-12463.87, 374.91, -7523.77),
            ["Castle on the Sea"] = CFrame.new(-5085.24, 314.52, -3156.26),
            ["Haunted Castle (Lv. 1975)"] = CFrame.new(-9516.99, 172.01, 6078.47),
            ["Peanut Island (Lv. 2075)"] = CFrame.new(-2062.73, 50.32, -10232.22),
            ["Ice Cream Island (Lv. 2125)"] = CFrame.new(-902.59, 79.92, -10988.69),
            ["Cake Island (Lv. 2200)"] = CFrame.new(-2100.12, 70.12, -12150.34),
            ["Chocolate Island (Lv. 2300)"] = CFrame.new(141.52, 34.21, -12608.45),
            ["Candy Island (Lv. 2375)"] = CFrame.new(-1149.29, 23.63, -14445.61),
            ["Tiki Outpost (Lv. 2450)"] = CFrame.new(-16106.33, 9.21, 440.38),
            ["Temple of Time"] = CFrame.new(28282.57, 14896.85, 105.10)
        }
    }
    
    local CurrentIslands = AllIslands[CurrentSea] or AllIslands[1]
    local islandKeys = {}
    for k, _ in pairs(CurrentIslands) do table.insert(islandKeys, k) end
    table.sort(islandKeys)
    local SelIsland = islandKeys[1] or "Pirate Starter"
    
    local IslandDrop = TeleportTab:AddSearchDropdown("Select Island", islandKeys, islandKeys[1], function(v) SelIsland = v end)
    
    TeleportTab:AddButton("🚀 Teleport to Selected Island", function()
        -- Crucial: turn off farming toggles so auto farm loop doesn't drag player back!
        _G.Config.AutoFarmLevel = false
        _G.Config.FarmSelectedMob = false
        _G.Config.FarmSelectedBoss = false
        _G.Config.FarmAllBosses = false
        
        local tcf = CurrentIslands[SelIsland]
        if tcf then
            TeleportToIsland(tcf, SelIsland)
        end
    end)
    
    TeleportTab:AddButton("🛑 Stop Travel & Hover Here", function()
        StopTween()
        local root = GetRoot()
        if root then HoverLock(root.CFrame) end
    end)
    
    -- ==================== 10. SETTINGS ====================
    
    MiscTab:AddSection("Diagnostics & Fixes")
    MiscTab:AddButton("🔍 Run Movement Diagnostic (Copies to Clipboard)", function()
        local root = GetRoot()
        local hum = GetHumanoid()
        local rPos = root and tostring(root.Position) or "N/A"
        local bvs = root and root:FindFirstChildOfClass("BodyVelocity") and "YES (" .. root:FindFirstChildOfClass("BodyVelocity").Name .. ")" or "NONE"
        local report = "ALPHA V2 DIAGNOSTIC SNAPSHOT\n"
        report = report .. "Player Level: " .. GetPlayerLevel() .. "\n"
        report = report .. "PlaceId: " .. PlaceId .. " (" .. SeaName .. ")\n"
        report = report .. "Position: " .. rPos .. "\n"
        report = report .. "Humanoid PlatformStand: " .. tostring(hum and hum.PlatformStand) .. "\n"
        report = report .. "Root BodyVelocity: " .. bvs .. "\n"
        report = report .. "Active Tweens: " .. tostring(CurrentTween ~= nil) .. "\n"
        report = report .. "HasQuest: " .. tostring(HasQuest()) .. "\n"
        report = report .. "IsTravelingSky: " .. tostring(IsTravelingSky) .. "\n"
        report = report .. "TweenSpeed Config: " .. tostring(_G.Config.TweenSpeed) .. "\n"
        pcall(function()
            if setclipboard then
                setclipboard(report)
                print("[ALPHA] Diagnostic report copied to clipboard!")
            end
        end)
    end)

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
    MiscTab:AddSlider("Tween Flight Speed (Safe 200-260)", 150, 300, 240, function(v) _G.Config.TweenSpeed = v end)
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
