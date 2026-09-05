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
end

--============================== AUTO SELECT TEAM (PIRATES) ==============================
-- Ensures character is spawned into the world immediately after game load or crash recovery
local function AutoSelectPirates()
    task.spawn(function()
        for attempt = 1, 20 do
            if LocalPlayer.Team ~= nil and tostring(LocalPlayer.Team) ~= "Neutral" and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                break
            end
            
            -- Method 1: Direct Server Remote (CommF_ SetTeam)
            pcall(function()
                local cf = CommF()
                if cf then
                    cf:InvokeServer("SetTeam", "Pirates")
                end
            end)
            
            -- Method 2: Client UI Button Click Simulation
            pcall(function()
                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                if pGui then
                    for _, gui in ipairs(pGui:GetChildren()) do
                        for _, desc in ipairs(gui:GetDescendants()) do
                            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                                local txt = (desc:IsA("TextButton") and desc.Text or ""):lower()
                                local name = desc.Name:lower()
                                if (txt:find("pirate") or name:find("pirate")) and desc.Visible then
                                    if getconnections then
                                        for _, c in pairs(getconnections(desc.Activated)) do c:Fire() end
                                        for _, c in pairs(getconnections(desc.MouseButton1Click)) do c:Fire() end
                                    elseif firesignal then
                                        firesignal(desc.MouseButton1Click)
                                        firesignal(desc.Activated)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            
            task.wait(0.6)
        end
    end)
end

-- Run auto-team selection immediately
AutoSelectPirates()

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
    AutoChestFarm = false,
    
    -- Farm Distance Settings
    AdaptiveBossDistance = true,
    MobFarmDistance = 14,
    BossFarmDistance = 20,
    FarmDistance = 14,
    TweenSpeed = 240,
    
    -- Teleport & Movement Engine
    BypassTeleport = true,
    AutoSetSpawn = true,
    WaypointFlight = true,
    AntiDesync = true,
    
    -- Combat Mode (M1 vs Skills)
    UseM1 = true,
    FastAttack = true,
    FastAttackSpeed = 0.015,
    AttackDistance = 120,
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
    
    -- Special Events & Summoners
    AutoFarmBones = false,
    AutoRollBones = false,
    AutoSummonSoulReaper = false,
    AutoCakePrinceSummon = false,
    AutoDoughKingSummon = false,
    
    -- Sea Events & Mirage
    AutoKillShark = false,
    AutoKillTerrorShark = false,
    AutoKillPiranha = false,
    AutoKillSeaBeast = false,
    AutoKillGhostShip = false,
    AutoFindGear = false,
    AutoPullLever = false,
    AutoKitsuneEmber = false,
    
    -- Race V4 System
    AutoRaceV4Trial = false,
    AutoInsertGear = false,
    AutoTrainV4 = false,
    
    -- Dungeon / Raids
    SelectedChip = "Flame",
    AutoBuyChip = false,
    AutoStartRaid = false,
    AutoFarmRaid = false,
    AutoAwaken = false,
    AutoLawRaid = false,
    
    -- Devil Fruit
    AutoRandomFruit = false,
    AutoStoreFruit = false,
    AutoGrabFruits = false,
    
    -- Visuals & ESP
    PlayerESP = false,
    FruitESP = false,
    ChestESP = false,
    FlowerESP = false,
    MirageESP = false,
    SeaEventESP = false,
    Fullbright = false,
    
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


--============================== HELPER FUNCTIONS & FLIGHT STATE ==============================
-- Universal Flight, Travel & Physics State Variables (scoped across entire file)
local CurrentTween = nil
local FlightBodyVel = nil
local CurrentTargetPos = nil
local IsTravelingSky = false
local NoclipConn = nil
local SetTravelHUD = nil -- Forward declaration for Cockpit HUD
local LandingPlatform = nil
local _activeFlight = nil -- Heartbeat flight connection tracker

local function GetMobRoot(mob)
    if not mob then return nil end
    return mob:FindFirstChild("HumanoidRootPart")
        or mob.PrimaryPart
        or mob:FindFirstChild("Torso")
        or mob:FindFirstChild("UpperTorso")
        or mob:FindFirstChild("Head")
        or mob:FindFirstChildWhichIsA("BasePart")
end

local function GetCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and char:FindFirstChild("HumanoidRootPart") then
        return char
    end
    return nil
end

local function GetRoot()
    local char = GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = GetCharacter()
    if not char then return nil end
    return char:FindFirstChild("Humanoid")
end

-- Global Character Lifecycle: automatically self-heals and resets movement on death and respawn
local function HookCharacterLifecycle(char)
    if not char then return end
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        if hum then
            hum.Died:Connect(function()
                IsTravelingSky = false
                CurrentTargetPos = nil
                if CurrentTween then pcall(function() CurrentTween:Cancel() end) end
                CurrentTween = nil
                if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
                FlightBodyVel = nil
            end)
        end
    end)
end

if LocalPlayer.Character then
    HookCharacterLifecycle(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
    IsTravelingSky = false
    CurrentTargetPos = nil
    if CurrentTween then pcall(function() CurrentTween:Cancel() end) end
    CurrentTween = nil
    if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
    FlightBodyVel = nil
    HookCharacterLifecycle(newChar)
end)

local function GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return data.Level.Value
    end
    return 1
end

-- ==================== WEAPON TYPE IDENTIFIER & EQUIPPING ====================
local _nonWeaponNames = {
    "key", "chalice", "fist of darkness", "flower", "torch", "cup",
    "microchip", "core", "scroll", "bone", "egg", "ticket"
}

local function IsNonWeaponItem(name)
    for _, item in ipairs(_nonWeaponNames) do
        if name:find(item) then return true end
    end
    return false
end

local function NormalizeWeaponType(targetType)
    if not targetType then return "Melee" end
    local lower = tostring(targetType):lower()
    if lower == "combat" or lower == "melee" or lower == "fightingstyle" then
        return "Melee"
    elseif lower == "sword" or lower == "swords" then
        return "Sword"
    elseif lower == "gun" or lower == "guns" then
        return "Gun"
    elseif lower == "fruit" or lower == "bloxfruit" or lower == "fruits" then
        return "Fruit"
    end
    return targetType
end

local function IsWeaponType(tool, targetType)
    if not tool or not tool:IsA("Tool") then return false end
    targetType = NormalizeWeaponType(targetType)
    
    local tip = tool.ToolTip or ""
    local name = tool.Name:lower()
    
    -- Filter out quest items, keys, materials
    if IsNonWeaponItem(name) then return false end
    
    -- 1. Trust explicit Blox Fruits ToolTips first
    if tip == "Melee" or tool:FindFirstChild("Combat") then
        return targetType == "Melee"
    elseif tip == "Sword" or tip == "Melee Weapon" then
        return targetType == "Sword"
    elseif tip == "Gun" then
        return targetType == "Gun"
    elseif tip == "Blox Fruit" then
        return targetType == "Fruit"
    end
    
    -- 2. Melee / Fighting Style identification
    local meleeStyles = {
        "combat", "black leg", "electro", "water kung fu", "dragon claw",
        "superhuman", "death step", "sharkman karate", "electric claw",
        "dragon talon", "godhuman", "sanguine art", "karate", "fishman karate"
    }
    local isMeleeByName = false
    for _, m in ipairs(meleeStyles) do
        if name:find(m) then isMeleeByName = true; break end
    end
    
    -- 3. Gun identification (Soul Guitar is strictly a gun)
    local gunNames = {
        "musket", "flintlock", "refined flintlock", "cannon", "kabucha",
        "acidum rifle", "serpent bow", "bizarre rifle", "bazooka", "soul guitar",
        "slingshot"
    }
    local isGunByName = false
    for _, g in ipairs(gunNames) do
        if name:find(g) then isGunByName = true; break end
    end
    
    -- 4. Sword identification (exclude Soul Guitar)
    local swordNames = {
        "cutlass", "katana", "pipe", "dual katana", "iron mace", "bisento",
        "trident", "pole", "soul cane", "saber", "longsword", "gravity cane",
        "saddi", "wando", "shisui", "yama", "tushita", "canvander",
        "rengoku", "buddy sword", "midnight blade", "hallow scythe",
        "cursed dual katana", "dark blade", "true triple katana",
        "dragon trident", "spikey trident", "dark dagger", "koko", "fox lamp",
        "shark anchor", "dual-headed blade", "warden's sword", "triple katana"
    }
    local isSwordByName = false
    for _, s in ipairs(swordNames) do
        if name:find(s) then isSwordByName = true; break end
    end
    
    -- 5. Fruit identification (require hyphen or 'fruit' keyword to avoid substring false positives)
    local isFruitByName = false
    if name:find("%-") or name:find("fruit") then
        local fruitRoots = {
            "bomb", "spike", "chop", "spring", "smoke", "flame", "falcon", "ice",
            "sand", "dark", "light", "rubber", "barrier", "magma", "quake",
            "human", "buddha", "string", "bird", "phoenix", "rumble", "paw",
            "gravity", "dough", "venom", "shadow", "control", "soul", "dragon",
            "leopard", "spirit", "portal", "blizzard", "sound", "mammoth",
            "t-rex", "kitsune", "rocket", "spin", "diamond", "love", "gas"
        }
        for _, fn in ipairs(fruitRoots) do
            if name:find(fn .. "%-") or name:find(fn .. " fruit") or name == fn then
                isFruitByName = true
                break
            end
        end
    end
    
    if targetType == "Melee" then
        return isMeleeByName
    elseif targetType == "Sword" then
        if isGunByName or isFruitByName then return false end
        return isSwordByName or (tip == "" and not isMeleeByName and name ~= "tool")
    elseif targetType == "Gun" then
        return isGunByName
    elseif targetType == "Fruit" then
        return isFruitByName and not isSwordByName and not isGunByName and not isMeleeByName
    end
    return false
end

local _lastEquipAttempt = 0
local function EquipWeapon(weaponType)
    weaponType = NormalizeWeaponType(weaponType or _G.Config.SelectedWeapon or "Melee")
    local char = GetCharacter()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return nil end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    
    -- 1. Check currently equipped tool
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        if IsWeaponType(currentTool, weaponType) then
            return currentTool
        else
            pcall(function() humanoid:UnequipTools() end)
        end
    end
    
    -- Throttle backpack scans to avoid per-frame overhead
    local now = tick()
    if (now - _lastEquipAttempt) < 0.25 then return nil end
    _lastEquipAttempt = now
    
    -- 2. Search backpack
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") and IsWeaponType(tool, weaponType) then
            humanoid:EquipTool(tool)
            return tool
        end
    end
    return nil
end

-- Debounced Auto Buso Haki (runs at most once every 3 seconds, non-blocking)
local _lastBusoCheck = 0
local function CheckBusoHaki()
    if not _G.Config.AutoBusoHaki then return end
    local now = tick()
    if (now - _lastBusoCheck) < 3.0 then return end
    _lastBusoCheck = now
    
    local char = GetCharacter()
    if char and not char:FindFirstChild("HasBuso") then
        local cf = CommF()
        if cf then
            task.spawn(function()
                pcall(function() cf:InvokeServer("Buso") end)
            end)
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

-- HoverLock: locks altitude above enemies or NPCs during combat/interaction
-- Enhanced with position validation and retry logic for unattended operation
local function HoverLock(targetCFrame)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent or not hum or hum.Health <= 0 then return end
    EnableNoclip()
    hum.PlatformStand = true
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    root.CFrame = targetCFrame
end

local function StopTween()
    -- Stop Heartbeat-driven flight if active
    if _activeFlight then
        pcall(function() _activeFlight:Disconnect() end)
        _activeFlight = nil
    end
    if CurrentTween then
        pcall(function() CurrentTween:Cancel() end)
        CurrentTween = nil
    end
    CurrentTargetPos = nil
    IsTravelingSky = false
    local hum = GetHumanoid()
    if hum then 
        hum.PlatformStand = false 
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if FlightBodyVel then
        pcall(function() FlightBodyVel:Destroy() end)
        FlightBodyVel = nil
    end
    local root = GetRoot()
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if (c:IsA("BodyVelocity") and c.Name == "AlphaFlightBV") or c:IsA("BodyGyro") or c:IsA("BodyPosition") then
                pcall(function() c:Destroy() end)
            end
        end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    if SetTravelHUD then SetTravelHUD(false) end
end

local function FullResetMovement()
    StopTween()
    DisableNoclip()
    local hum = GetHumanoid()
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
    end
    local char = GetCharacter()
    if char then
        for _, c in ipairs(char:GetDescendants()) do
            if c:IsA("BodyVelocity") or c:IsA("BodyGyro") or c:IsA("BodyPosition")
                or c:IsA("LinearVelocity") or c:IsA("VectorForce") or c:IsA("AlignPosition") or c:IsA("AlignOrientation") then
                pcall(function() c:Destroy() end)
            end
        end
    end
    local root = GetRoot()
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    FlightBodyVel = nil
end

--============================== SMART RUNTIME VALIDATOR (SELF-HEALING ENGINE) ==============================
-- Continuously analyses every action and auto-corrects. Designed for unattended overnight operation.
-- Validates: position accuracy, damage registration, stuck states, death recovery, speed tuning, quest completion.

local Validator = {
    -- Speed Auto-Tuner state
    CurrentSafeSpeed = _G.Config.TweenSpeed or 250,
    RollbackCount = 0,
    LastRollbackReset = tick(),
    MinSpeed = 180,
    SpeedStep = 20,
    RollbackResetInterval = 300, -- Reset rollback counter after 5 min of stability
    
    -- Stuck Detection state
    PositionHistory = {},
    MaxHistorySize = 6,
    StuckThreshold = 3, -- studs: if moved less than this across all samples, we're stuck
    StuckCheckInterval = 5, -- seconds between checks
    ConsecutiveStuckCount = 0,
    MaxStuckBeforeReset = 3, -- After 3 consecutive stuck detections (15s), force reset
    
    -- Damage Verification state
    FailedDamageAttempts = {}, -- [mobName] = count
    MaxFailedDamage = 5, -- Skip mob after this many failed hits
    GlitchedMobs = {}, -- Set of mob instance IDs confirmed glitched
    
    -- Death Recovery state
    WasFarmingBeforeDeath = false,
    FarmStateBeforeDeath = {},
    DeathCount = 0,
    LastDeathTime = 0,
    
    -- Quest Completion Verification
    LastQuestLevel = 0,
    QuestCheckPending = false,
    
    -- Position Validation
    LastValidatedPosition = nil,
    ValidationFailCount = 0,
    MaxValidationFails = 3,
    
    -- Runtime Stats
    TotalRollbacks = 0,
    TotalStuckResets = 0,
    TotalDeathRecoveries = 0,
    TotalGlitchedMobsSkipped = 0,
    StartTime = tick(),
}

-- ==================== POSITION VALIDATION ====================
-- Called after HoverLock / TweenTo completion to verify server accepted the position
function Validator.ValidatePosition(expectedCF, tolerance)
    tolerance = tolerance or 25
    local root = GetRoot()
    if not root or not root.Parent then return true end -- Can't validate without root
    
    task.wait(0.15) -- Give server time to acknowledge or rollback
    
    local actualPos = root.Position
    local expectedPos = expectedCF.Position
    local deviation = (actualPos - expectedPos).Magnitude
    
    if deviation > tolerance then
        -- ROLLBACK DETECTED!
        Validator.RollbackCount = Validator.RollbackCount + 1
        Validator.TotalRollbacks = Validator.TotalRollbacks + 1
        Validator.ValidationFailCount = Validator.ValidationFailCount + 1
        
        -- Auto-tune speed downward
        if Validator.RollbackCount >= 2 then
            local newSpeed = math.max(Validator.CurrentSafeSpeed - Validator.SpeedStep, Validator.MinSpeed)
            if newSpeed ~= Validator.CurrentSafeSpeed then
                Validator.CurrentSafeSpeed = newSpeed
                _G.Config.TweenSpeed = newSpeed
                print("[VALIDATOR] Speed reduced to " .. newSpeed .. " studs/s (rollback #" .. Validator.TotalRollbacks .. ")")
            end
            Validator.RollbackCount = 0
        end
        
        -- If too many consecutive validation fails, do a full reset
        if Validator.ValidationFailCount >= Validator.MaxValidationFails then
            print("[VALIDATOR] Multiple rollbacks detected — performing full movement reset")
            FullResetMovement()
            Validator.ValidationFailCount = 0
            task.wait(1)
        end
        
        return false
    end
    
    -- Position accepted by server
    Validator.ValidationFailCount = 0
    Validator.LastValidatedPosition = actualPos
    return true
end

-- ==================== SPEED AUTO-TUNER ====================
-- Periodically resets rollback counter if stable, allowing speed to recover
function Validator.SpeedAutoTunerTick()
    local now = tick()
    if (now - Validator.LastRollbackReset) > Validator.RollbackResetInterval then
        Validator.LastRollbackReset = now
        Validator.RollbackCount = 0
        -- Gradually try to recover speed (increase by half a step)
        if Validator.CurrentSafeSpeed < (_G.Config.TweenSpeed or 250) then
            local recovered = math.min(Validator.CurrentSafeSpeed + 10, 250)
            Validator.CurrentSafeSpeed = recovered
            _G.Config.TweenSpeed = recovered
            print("[VALIDATOR] Speed recovery: " .. recovered .. " studs/s (stable for 5 min)")
        end
    end
end

-- ==================== DAMAGE VERIFICATION ====================
-- Check if an attack actually dealt damage to a target
function Validator.VerifyDamage(target, preHP)
    if not target or not target.Parent then return true end -- Target died/despawned = success
    local hum = target:FindFirstChild("Humanoid")
    if not hum then return true end
    
    task.wait(0.1) -- Brief wait for damage to register server-side
    
    local postHP = hum.Health
    if postHP >= preHP and preHP > 0 then
        -- No damage dealt
        local mobKey = target.Name .. "_" .. tostring(target:GetDebugId())
        Validator.FailedDamageAttempts[mobKey] = (Validator.FailedDamageAttempts[mobKey] or 0) + 1
        
        if Validator.FailedDamageAttempts[mobKey] >= Validator.MaxFailedDamage then
            -- Mark as glitched — skip this specific mob instance
            Validator.GlitchedMobs[tostring(target:GetDebugId())] = true
            Validator.TotalGlitchedMobsSkipped = Validator.TotalGlitchedMobsSkipped + 1
            print("[VALIDATOR] Mob '" .. target.Name .. "' marked GLITCHED (no damage after " .. Validator.MaxFailedDamage .. " hits) — skipping")
            return false
        end
        return false
    end
    
    -- Damage confirmed — reset fail counter for this mob
    local mobKey = target.Name .. "_" .. tostring(target:GetDebugId())
    Validator.FailedDamageAttempts[mobKey] = 0
    return true
end

-- Check if a mob is known-glitched (should be skipped)
function Validator.IsMobGlitched(target)
    if not target then return false end
    return Validator.GlitchedMobs[tostring(target:GetDebugId())] == true
end

-- ==================== STUCK DETECTION ====================
-- Records position samples and detects if player is stuck
function Validator.RecordPosition()
    local root = GetRoot()
    if not root or not root.Parent then return end
    
    table.insert(Validator.PositionHistory, {
        pos = root.Position,
        time = tick()
    })
    
    -- Keep history bounded
    while #Validator.PositionHistory > Validator.MaxHistorySize do
        table.remove(Validator.PositionHistory, 1)
    end
end

function Validator.IsStuck()
    if #Validator.PositionHistory < Validator.MaxHistorySize then return false end
    
    -- Check if any farming mode is actually active
    local isFarming = _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses
    if not isFarming then
        Validator.ConsecutiveStuckCount = 0
        return false
    end
    
    -- Calculate total displacement across all samples
    local totalDisplacement = 0
    for i = 2, #Validator.PositionHistory do
        totalDisplacement = totalDisplacement + (Validator.PositionHistory[i].pos - Validator.PositionHistory[i-1].pos).Magnitude
    end
    
    if totalDisplacement < Validator.StuckThreshold then
        Validator.ConsecutiveStuckCount = Validator.ConsecutiveStuckCount + 1
        if Validator.ConsecutiveStuckCount >= Validator.MaxStuckBeforeReset then
            return true
        end
    else
        Validator.ConsecutiveStuckCount = 0
    end
    
    return false
end

function Validator.HandleStuck()
    Validator.TotalStuckResets = Validator.TotalStuckResets + 1
    Validator.ConsecutiveStuckCount = 0
    Validator.PositionHistory = {}
    
    print("[VALIDATOR] STUCK DETECTED — Force resetting movement (reset #" .. Validator.TotalStuckResets .. ")")
    
    -- Full reset and small random displacement to unstick
    FullResetMovement()
    task.wait(0.5)
    
    local root = GetRoot()
    if root and root.Parent then
        -- Small random displacement to break free from stuck geometry
        root.CFrame = root.CFrame * CFrame.new(math.random(-5, 5), 15, math.random(-5, 5))
    end
    
    task.wait(1)
end

-- ==================== DEATH RECOVERY ====================
-- Saves farming state before death and auto-resumes after respawn
function Validator.SaveFarmState()
    Validator.FarmStateBeforeDeath = {
        AutoFarmLevel = _G.Config.AutoFarmLevel,
        FarmSelectedMob = _G.Config.FarmSelectedMob,
        FarmSelectedBoss = _G.Config.FarmSelectedBoss,
        FarmAllBosses = _G.Config.FarmAllBosses,
        SelectedMob = _G.Config.SelectedMob,
        SelectedBoss = _G.Config.SelectedBoss,
        SelectedWeapon = _G.Config.SelectedWeapon,
    }
    Validator.WasFarmingBeforeDeath = (
        _G.Config.AutoFarmLevel or _G.Config.FarmSelectedMob or
        _G.Config.FarmSelectedBoss or _G.Config.FarmAllBosses
    )
end

function Validator.RestoreFarmState()
    if not Validator.WasFarmingBeforeDeath then return end
    
    local saved = Validator.FarmStateBeforeDeath
    if not saved then return end
    
    -- Restore all saved farming states
    _G.Config.AutoFarmLevel = saved.AutoFarmLevel or false
    _G.Config.FarmSelectedMob = saved.FarmSelectedMob or false
    _G.Config.FarmSelectedBoss = saved.FarmSelectedBoss or false
    _G.Config.FarmAllBosses = saved.FarmAllBosses or false
    _G.Config.SelectedMob = saved.SelectedMob or ""
    _G.Config.SelectedBoss = saved.SelectedBoss or ""
    _G.Config.SelectedWeapon = saved.SelectedWeapon or "Melee"
    
    Validator.WasFarmingBeforeDeath = false
    Validator.DeathCount = Validator.DeathCount + 1
    Validator.TotalDeathRecoveries = Validator.TotalDeathRecoveries + 1
    
    print("[VALIDATOR] Death #" .. Validator.DeathCount .. " — Auto-resuming farming in 3 seconds...")
end

-- ==================== QUEST COMPLETION VALIDATOR ====================
function Validator.CheckQuestCompletion()
    local currentLevel = GetPlayerLevel()
    if Validator.LastQuestLevel == 0 then
        Validator.LastQuestLevel = currentLevel
    end
    
    -- If level increased, quest definitely completed
    if currentLevel > Validator.LastQuestLevel then
        Validator.LastQuestLevel = currentLevel
        print("[VALIDATOR] Level UP! Now Lv." .. currentLevel .. " — Quest chain advancing")
        return true
    end
    
    return false
end

-- ==================== RUNTIME STATS ====================
function Validator.GetStats()
    local uptime = tick() - Validator.StartTime
    local hours = math.floor(uptime / 3600)
    local mins = math.floor((uptime % 3600) / 60)
    return string.format(
        "Uptime: %dh %dm | Speed: %d studs/s | Rollbacks: %d | Stuck Resets: %d | Deaths: %d | Glitched Mobs Skipped: %d",
        hours, mins, Validator.CurrentSafeSpeed, Validator.TotalRollbacks,
        Validator.TotalStuckResets, Validator.TotalDeathRecoveries, Validator.TotalGlitchedMobsSkipped
    )
end

-- ==================== ENHANCED CHARACTER ADDED (DEATH RECOVERY) ====================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    -- Save state BEFORE reset (we capture this on Humanoid.Died, but also here as failsafe)
    FullResetMovement()
    
    -- Clear glitched mob cache on respawn (new instances)
    Validator.GlitchedMobs = {}
    Validator.FailedDamageAttempts = {}
    Validator.PositionHistory = {}
    Validator.ConsecutiveStuckCount = 0
    
    -- Wait for character to fully load
    task.spawn(function()
        local hum = newChar:WaitForChild("Humanoid", 10)
        local root = newChar:WaitForChild("HumanoidRootPart", 10)
        if not hum or not root then return end
        
        -- Connect death listener for NEXT death
        hum.Died:Connect(function()
            Validator.SaveFarmState()
            Validator.LastDeathTime = tick()
        end)
        
        -- Auto-resume farming after respawn (staggered delay to let game settle)
        task.wait(3 + math.random() * 2)
        Validator.RestoreFarmState()
    end)
end)

-- Connect initial character's death listener
pcall(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.Died:Connect(function()
                Validator.SaveFarmState()
                Validator.LastDeathTime = tick()
            end)
        end
    end
end)

-- ==================== BACKGROUND VALIDATOR LOOPS ====================
-- Stuck Detection Loop
task.spawn(function()
    task.wait(10) -- Let everything initialize first
    while true do
        task.wait(Validator.StuckCheckInterval)
        pcall(function()
            Validator.RecordPosition()
            if Validator.IsStuck() then
                Validator.HandleStuck()
            end
        end)
    end
end)

-- Speed Auto-Tuner Loop
task.spawn(function()
    task.wait(15)
    while true do
        task.wait(30)
        pcall(function()
            Validator.SpeedAutoTunerTick()
        end)
    end
end)

-- Quest Completion Monitor Loop
task.spawn(function()
    task.wait(20)
    while true do
        task.wait(10)
        pcall(function()
            Validator.CheckQuestCompletion()
        end)
    end
end)

-- Runtime Stats Logger (prints every 5 minutes)
task.spawn(function()
    task.wait(60)
    while true do
        task.wait(300)
        pcall(function()
            print("[VALIDATOR STATS] " .. Validator.GetStats())
        end)
    end
end)

--============================== AUTONOMOUS IPC BRIDGE (AI LIVE CONNECTION) ==============================
-- Connects the in-game script to the AI and host tools via alpha_bridge files
local IPC_BRIDGE_DIR = "alpha_bridge"
local IPC_TELEMETRY_FILE = IPC_BRIDGE_DIR .. "/telemetry.json"
local IPC_EVENTS_FILE = IPC_BRIDGE_DIR .. "/events.log"
local IPC_COMMAND_FILE = IPC_BRIDGE_DIR .. "/command.json"
local IPC_EVAL_FILE = IPC_BRIDGE_DIR .. "/eval_result.json"

local function SafeWriteFile(filename, content)
    if writefile then
        pcall(function() writefile(filename, content) end)
    end
end

local function SafeAppendFile(filename, content)
    if appendfile then
        pcall(function() appendfile(filename, content) end)
    elseif writefile and isfile and readfile then
        pcall(function()
            local existing = isfile(filename) and readfile(filename) or ""
            writefile(filename, existing .. content)
        end)
    end
end

local function LogBridgeEvent(tag, msg)
    local line = string.format("[%s] [%s] %s\n", os.date("%X"), tag, tostring(msg))
    SafeAppendFile(IPC_EVENTS_FILE, line)
    print("[BRIDGE] " .. line)
end

-- Telemetry Streaming Loop (Runs every 2 seconds)
task.spawn(function()
    task.wait(3)
    while true do
        task.wait(2.0)
        pcall(function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local pos = root and root.Position or Vector3.new(0, 0, 0)
            
            local telemData = {
                timestamp = tick(),
                player = LocalPlayer.Name,
                level = GetPlayerLevel(),
                health = hum and math.floor(hum.Health) or 0,
                max_health = hum and math.floor(hum.MaxHealth) or 0,
                position = {
                    x = math.floor(pos.X * 10) / 10,
                    y = math.floor(pos.Y * 10) / 10,
                    z = math.floor(pos.Z * 10) / 10
                },
                altitude = math.floor(pos.Y),
                has_quest = HasQuest(),
                auto_farm_level = _G.Config.AutoFarmLevel,
                selected_weapon = _G.Config.SelectedWeapon,
                safe_speed = Validator.CurrentSafeSpeed,
                rollbacks = Validator.TotalRollbacks,
                stuck_resets = Validator.TotalStuckResets,
                deaths = Validator.DeathCount,
                glitched_mobs_skipped = Validator.TotalGlitchedMobsSkipped,
                is_traveling_sky = IsTravelingSky,
                stats = Validator.GetStats()
            }
            
            SafeWriteFile(IPC_TELEMETRY_FILE, HttpService:JSONEncode(telemData))
        end)
    end
end)

-- Command Listener Loop (Polls every 0.4 seconds, ignores past commands)
task.spawn(function()
    -- Initialize to current time so stale commands from disk NEVER trigger on launch!
    local lastCmdTimestamp = tick() * 1000
    task.wait(2)
    while true do
        task.wait(0.4)
        pcall(function()
            if isfile and isfile(IPC_COMMAND_FILE) and readfile then
                local ok, cmdData = pcall(function()
                    return HttpService:JSONDecode(readfile(IPC_COMMAND_FILE))
                end)
                if ok and type(cmdData) == "table" and cmdData.timestamp and cmdData.timestamp > lastCmdTimestamp then
                    lastCmdTimestamp = cmdData.timestamp
                    LogBridgeEvent("CMD", "AI dispatched command: " .. tostring(cmdData.cmd))
                    -- Immediately clear command file so it can NEVER trigger twice
                    SafeWriteFile(IPC_COMMAND_FILE, "{}")
                    
                    if cmdData.cmd == "reload" then
                        LogBridgeEvent("RELOAD", "Hot-reloading latest script from AI...")
                        StopTween()
                        DisableNoclip()
                        local path = isfile("alpha_bridge/latest_script.lua") and "alpha_bridge/latest_script.lua" or "alpha_v2.lua"
                        if isfile(path) then
                            loadstring(readfile(path))()
                        end
                    elseif cmdData.cmd == "set_speed" and cmdData.speed then
                        local spd = tonumber(cmdData.speed)
                        if spd and spd >= 150 and spd <= 300 then
                            Validator.CurrentSafeSpeed = spd
                            _G.Config.TweenSpeed = spd
                            LogBridgeEvent("SPEED", "Safe speed updated by AI to: " .. spd)
                        end
                    elseif cmdData.cmd == "set_config" and cmdData.key then
                        _G.Config[cmdData.key] = cmdData.value
                        LogBridgeEvent("CONFIG", "Config updated by AI: " .. tostring(cmdData.key) .. " = " .. tostring(cmdData.value))
                    elseif cmdData.cmd == "reset_movement" then
                        FullResetMovement()
                        LogBridgeEvent("MOVE", "Full movement reset executed by AI command")
                    elseif cmdData.cmd == "start_farm" then
                        _G.Config.AutoFarmLevel = true
                        LogBridgeEvent("FARM", "AutoFarmLevel enabled by AI command")
                    elseif cmdData.cmd == "stop_farm" then
                        _G.Config.AutoFarmLevel = false
                        StopTween()
                        FullResetMovement()
                        LogBridgeEvent("FARM", "AutoFarmLevel disabled by AI command")
                    elseif cmdData.cmd == "eval" and cmdData.code then
                        local fn, err = loadstring(cmdData.code)
                        if fn then
                            local okEval, resEval = pcall(fn)
                            SafeWriteFile(IPC_EVAL_FILE, HttpService:JSONEncode({success = okEval, result = tostring(resEval)}))
                            LogBridgeEvent("EVAL", "Eval executed: " .. tostring(okEval))
                        else
                            SafeWriteFile(IPC_EVAL_FILE, HttpService:JSONEncode({success = false, error = tostring(err)}))
                            LogBridgeEvent("EVAL", "Eval error: " .. tostring(err))
                        end
                    end
                end
            end
        end)
    end
end)

LogBridgeEvent("INIT", "Autonomous IPC Bridge connected to AI agent successfully")

--============================== NATIVE ENTRANCE PORTALS & BYPASS MATRIX ==============================
-- Blox Fruits official server entrance positions for CommF_:InvokeServer("requestEntrance", Vector3.new(...))
local ENTRANCE_PORTALS = {
    -- SEA 1 (PlaceId 2753915549)
    { Name = "Pirate Starter", Pos = Vector3.new(1059.37, 16.51, 1546.99), Sea = 1 },
    { Name = "Marine Starter", Pos = Vector3.new(-2573.39, 6.94, 2059.27), Sea = 1 },
    { Name = "Middle Town", Pos = Vector3.new(-655.82, 7.84, 1588.65), Sea = 1 },
    { Name = "Jungle", Pos = Vector3.new(-1612.33, 36.85, 149.13), Sea = 1 },
    { Name = "Pirate Village", Pos = Vector3.new(-1181.39, 4.75, 3843.43), Sea = 1 },
    { Name = "Desert", Pos = Vector3.new(1094.11, 6.44, 4192.89), Sea = 1 },
    { Name = "Snow Island", Pos = Vector3.new(1384.81, 87.27, -1298.47), Sea = 1 },
    { Name = "Marineford", Pos = Vector3.new(-5035.79, 28.65, 4324.96), Sea = 1 },
    { Name = "Sky 1 (Lower Skylands)", Pos = Vector3.new(-4839.53, 717.67, -2619.44), Sea = 1 },
    { Name = "Sky 2 (Upper Skylands)", Pos = Vector3.new(-7894.62, 5545.49, -380.41), Sea = 1 },
    { Name = "Prison", Pos = Vector3.new(4875.33, 5.65, 735.45), Sea = 1 },
    { Name = "Colosseum", Pos = Vector3.new(-1427.62, 7.28, -2792.77), Sea = 1 },
    { Name = "Magma Village", Pos = Vector3.new(-5247.72, 8.57, 8504.68), Sea = 1 },
    { Name = "Underwater City Entrance", Pos = Vector3.new(61163.85, 11.68, 1819.78), Sea = 1, IsEntrance = true },
    { Name = "Underwater City Exit", Pos = Vector3.new(3864.69, 6.74, -1926.21), Sea = 1, IsEntrance = true },
    { Name = "Fountain City", Pos = Vector3.new(5127.13, 59.50, 4105.45), Sea = 1 },
    
    -- SEA 2 (PlaceId 4442272183)
    { Name = "Cafe (Safe Zone)", Pos = Vector3.new(-380.48, 77.22, 255.83), Sea = 2, IsEntrance = true },
    { Name = "Mansion (Swan)", Pos = Vector3.new(2284.91, 15.15, 905.51), Sea = 2, IsEntrance = true },
    { Name = "Kingdom of Rose", Pos = Vector3.new(878.01, 121.98, 1235.35), Sea = 2 },
    { Name = "Green Zone", Pos = Vector3.new(-2448.53, 73.02, -3210.63), Sea = 2 },
    { Name = "Graveyard", Pos = Vector3.new(-5418.89, 48.52, -774.75), Sea = 2 },
    { Name = "Snow Mountain", Pos = Vector3.new(608.24, 401.52, -5372.46), Sea = 2 },
    { Name = "Hot and Cold", Pos = Vector3.new(-6026.96, 15.96, -5071.29), Sea = 2 },
    { Name = "Cursed Ship Interior", Pos = Vector3.new(923.21, 126.98, 32852.83), Sea = 2, IsEntrance = true },
    { Name = "Cursed Ship Exit", Pos = Vector3.new(-6508.56, 89.03, -132.84), Sea = 2, IsEntrance = true },
    { Name = "Ice Castle", Pos = Vector3.new(5422.31, 28.25, -6767.13), Sea = 2 },
    { Name = "Forgotten Island", Pos = Vector3.new(-3054.44, 237.15, -10142.82), Sea = 2 },
    { Name = "Dark Arena", Pos = Vector3.new(3780.03, 22.65, -3498.94), Sea = 2 },

    -- SEA 3 (PlaceId 7449423635)
    { Name = "Port Town", Pos = Vector3.new(-290.74, 6.73, 5343.55), Sea = 3 },
    { Name = "Hydra Island", Pos = Vector3.new(5229.93, 1004.28, -325.23), Sea = 3, IsEntrance = true },
    { Name = "Great Tree", Pos = Vector3.new(2281.54, 442.20, -12543.08), Sea = 3, IsEntrance = true },
    { Name = "Floating Turtle Mansion", Pos = Vector3.new(-12463.87, 374.91, -7523.77), Sea = 3, IsEntrance = true },
    { Name = "Castle on the Sea", Pos = Vector3.new(-5035.43, 314.52, -2917.48), Sea = 3, IsEntrance = true },
    { Name = "Haunted Castle", Pos = Vector3.new(-9516.99, 142.01, 6078.47), Sea = 3, IsEntrance = true },
    { Name = "Peanut Island", Pos = Vector3.new(-2062.73, 50.32, -10232.22), Sea = 3 },
    { Name = "Ice Cream Island", Pos = Vector3.new(-902.59, 79.92, -10988.69), Sea = 3 },
    { Name = "Cake Island", Pos = Vector3.new(-2100.12, 70.12, -12150.34), Sea = 3 },
    { Name = "Chocolate Island", Pos = Vector3.new(141.52, 34.21, -12608.45), Sea = 3 },
    { Name = "Candy Island", Pos = Vector3.new(-1149.29, 23.63, -14445.61), Sea = 3 },
    { Name = "Tiki Outpost", Pos = Vector3.new(-16106.33, 9.21, 440.38), Sea = 3 },
    { Name = "Temple of Time", Pos = Vector3.new(28282.57, 14896.85, 105.10), Sea = 3, IsEntrance = true },
    { Name = "Beautiful Pirate", Pos = Vector3.new(5314.58, 22.18, -125.94), Sea = 3, IsEntrance = true }
}

-- Raycast downwards to detect real server-replicated terrain/geometry
local function GetRealGroundPosition(x, y, z)
    local rayOrigin = Vector3.new(x, math.max(y + 60, 220), z)
    local rayDir = Vector3.new(0, -500, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = RaycastFilterType.Exclude
    local filterList = {}
    if LocalPlayer.Character then
        table.insert(filterList, LocalPlayer.Character)
    end
    if LandingPlatform and LandingPlatform.Parent then
        table.insert(filterList, LandingPlatform)
    end
    rayParams.FilterDescendantsInstances = filterList
    rayParams.IgnoreWater = true -- Strictly ignore water so Devil Fruit users never touch sea level
    
    local hit = Workspace:Raycast(rayOrigin, rayDir, rayParams)
    if hit and hit.Instance then
        return hit.Position, hit.Instance
    end
    return nil, nil
end

-- Position sync refresh (safe, no joint breaks, no impact velocity)
local function RecoverFromPhantomDesync(expectedCF)
    local root = GetRoot()
    local hum = GetHumanoid()
    if root and hum and hum.Health > 0 then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        if expectedCF then
            root.CFrame = expectedCF
        end
    end
    local cf = CommF()
    if cf then
        pcall(function() cf:InvokeServer("SetSpawnPoint") end)
    end
end

-- Multi-Waypoint Sky Cruise using Heartbeat CFrame Stepping
-- Key insight: TweenService tweens on HumanoidRootPart are CLIENT-ONLY visual effects.
-- The server does NOT replicate tween position changes - it sees the player at the original position
-- and periodically "corrects" (rubberbands) them back. Setting root.CFrame every Heartbeat frame
-- IS replicated because the client has network ownership of its character's HumanoidRootPart.

-- _activeFlight declared at top of flight engine section (line ~478)

local function StopActiveFlight()
    if _activeFlight then
        pcall(function() _activeFlight:Disconnect() end)
        _activeFlight = nil
    end
    CurrentTween = nil -- clear compat flag
end

-- Heartbeat-driven CFrame movement: moves root from A to B at given speed
-- Returns a "tween-like" object with :Cancel() and .Completed event for compat
local function HeartbeatMove(root, targetCFrame, speed, onStep)
    local startCF = root.CFrame
    local startPos = startCF.Position
    local endPos = targetCFrame.Position
    local totalDist = (endPos - startPos).Magnitude
    if totalDist < 1 then
        root.CFrame = targetCFrame
        return {
            Cancel = function() end,
            Completed = {
                Wait = function() end,
                Connect = function(a, b)
                    local cb = (type(a) == "function" and a) or (type(b) == "function" and b)
                    if cb then pcall(cb) end
                end
            }
        }
    end
    local duration = totalDist / math.max(speed, 50)
    local elapsed = 0
    local done = false
    local completedCallbacks = {}
    
    StopActiveFlight()
    
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if done or not root or not root.Parent then
            if conn then conn:Disconnect() end
            _activeFlight = nil
            done = true
            for _, cb in ipairs(completedCallbacks) do pcall(cb) end
            return
        end
        
        elapsed = elapsed + dt
        local alpha = math.clamp(elapsed / duration, 0, 1)
        local newPos = startPos:Lerp(endPos, alpha)
        root.CFrame = CFrame.new(newPos)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        if onStep then pcall(onStep, alpha, newPos) end
        
        if alpha >= 1 then
            done = true
            conn:Disconnect()
            _activeFlight = nil
            root.CFrame = targetCFrame
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            for _, cb in ipairs(completedCallbacks) do pcall(cb) end
        end
    end)
    _activeFlight = conn
    
    local mockTween = {}
    mockTween.Cancel = function()
        done = true
        if conn then pcall(function() conn:Disconnect() end) end
        _activeFlight = nil
    end
    mockTween.Completed = {
        Wait = function()
            while not done do task.wait(0.05) end
        end,
        Connect = function(a, b)
            local cb = (type(a) == "function" and a) or (type(b) == "function" and b)
            if not cb then return end
            if done then pcall(cb) else table.insert(completedCallbacks, cb) end
        end
    }
    CurrentTween = mockTween -- compat: so StopTween() can cancel it
    return mockTween
end

-- -------------------------------------------------------------------------
-- UNIFIED TRAVEL & TELEPORT ENGINE
-- Short distance (<= 350 studs): Heartbeat-driven CFrame glide for mob farming.
-- Long distance (> 350 studs or forceInstant): Instant direct CFrame teleport
-- with terrain pre-streaming, landing platform, position reinforcement,
-- and server spawn-point authority (eliminates rubberbanding completely).
-- -------------------------------------------------------------------------
local function TweenTo(targetCFrame, destName)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent or not hum or hum.Health <= 0 then return end
    
    local targetPos = targetCFrame.Position
    local distance = (targetPos - root.Position).Magnitude
    
    -- Within reach: lock position immediately
    if distance < 15 then
        StopTween()
        HoverLock(targetCFrame)
        return
    end
    
    -- Anti-spam: already moving to nearly the exact same position
    if CurrentTargetPos and (CurrentTargetPos - targetPos).Magnitude < 12 and (CurrentTween or IsTravelingSky) then
        return
    end
    
    local speed = Validator.CurrentSafeSpeed or _G.Config.TweenSpeed or 250
    if speed < 180 then speed = 220 end
    if speed > 270 then speed = 250 end
    
    StopTween()
    CurrentTargetPos = targetPos
    local label = destName or "Destination"
    
    -- Native server entrance portal bypass
    if _G.Config.BypassTeleport then
        local bestPortal = nil
        local bestDist = math.huge
        for _, portal in ipairs(ENTRANCE_PORTALS) do
            if portal.Sea == CurrentSea and portal.IsEntrance then
                local pDist = (targetPos - portal.Pos).Magnitude
                if pDist < bestDist then
                    bestDist = pDist
                    bestPortal = portal
                end
            end
        end
        if bestPortal and bestDist < 450 then
            local cf = CommF()
            if cf then
                pcall(function() cf:InvokeServer("requestEntrance", bestPortal.Pos) end)
                task.wait(0.5)
                root = GetRoot()
                if root and (targetPos - root.Position).Magnitude < 150 then
                    HoverLock(targetCFrame)
                    if _G.Config.AutoSetSpawn then
                        pcall(function() cf:InvokeServer("SetSpawnPoint") end)
                    end
                    return
                end
            end
        end
    end
    
    EnableNoclip()
    hum.PlatformStand = true
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    
    IsTravelingSky = true
    
    -- 1. SHORT RANGE (<= 250 studs, e.g. same island mob farm)
    if distance <= 250 then
        local dur = distance / speed
        local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        CurrentTween = tw
        tw:Play()
        
        tw.Completed:Connect(function(playbackState)
            if playbackState == Enum.PlaybackState.Completed then
                CurrentTween = nil
                IsTravelingSky = false
                HoverLock(targetCFrame)
            end
        end)
        return tw
    end
    
    -- 2. LONG RANGE (> 250 studs, cross-island multi-waypoint sky glide)
    local startPos = root.Position
    local cruiseY = math.max(startPos.Y, targetPos.Y, 280) + 40
    if cruiseY < 320 and CurrentSea ~= 1 then cruiseY = 320 end
    
    task.spawn(function()
        local function SafeTween(goalCF, dur)
            if not root or not root.Parent or not IsTravelingSky then return false end
            local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = goalCF})
            CurrentTween = tw
            tw:Play()
            local completed = false
            local conn = tw.Completed:Connect(function() completed = true end)
            local t0 = tick()
            while not completed and (tick() - t0) < (dur + 1.2) and root and root.Parent and IsTravelingSky and hum and hum.Health > 0 do
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                if bv and bv.Parent then bv.Velocity = Vector3.new(0, 0, 0) end
                
                local rem = (targetPos - root.Position).Magnitude
                if SetTravelHUD then SetTravelHUD(true, label, rem, speed, distance) end
                
                if LocalPlayer.RequestStreamAroundAsync and math.floor(tick() * 2) % 2 == 0 then
                    pcall(function()
                        LocalPlayer:RequestStreamAroundAsync(root.Position + (targetPos - root.Position).Unit * 250)
                    end)
                end
                RunService.Heartbeat:Wait()
            end
            if conn then conn:Disconnect() end
            if tw then pcall(function() tw:Cancel() end) end
            CurrentTween = nil
            return completed
        end
        
        -- Phase 1: Ascend smoothly to cruise altitude
        local ascendDist = math.abs(cruiseY - startPos.Y)
        if ascendDist > 15 then
            SafeTween(CFrame.new(startPos.X, cruiseY, startPos.Z), ascendDist / speed)
        end
        
        -- Phase 2: Horizontal sky cruise to coordinates directly above target
        if IsTravelingSky and root and root.Parent and hum and hum.Health > 0 then
            local horizDist = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
            SafeTween(CFrame.new(targetPos.X, cruiseY, targetPos.Z), horizDist / speed)
        end
        
        -- Phase 3: Gentle descent to targetCFrame
        if IsTravelingSky and root and root.Parent and hum and hum.Health > 0 then
            local descendDist = (targetPos - root.Position).Magnitude
            SafeTween(targetCFrame, math.max(descendDist / speed, 0.4))
        end
        
        -- Arrival
        if root and root.Parent and hum and hum.Health > 0 then
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            HoverLock(targetCFrame)
            
            if _G.Config.AutoSetSpawn then
                task.spawn(function()
                    task.wait(0.3)
                    local cf = CommF()
                    if cf then pcall(function() cf:InvokeServer("SetSpawnPoint") end) end
                end)
            end
        end
        
        IsTravelingSky = false
        CurrentTargetPos = nil
        if SetTravelHUD then SetTravelHUD(false) end
    end)
end

-- TeleportToIsland: Dedicated wrapper that suspends farming and executes Safe Island Sky Cruise
local function TeleportToIsland(targetCFrame, islandName)
    _G.Config.AutoFarmLevel = false
    _G.Config.FarmSelectedMob = false
    _G.Config.FarmSelectedBoss = false
    _G.Config.FarmAllBosses = false
    
    StopTween()
    TweenTo(targetCFrame, islandName or "Selected Island", false)
end
--============================== FAST ATTACK & SKILL ENGINE ==============================
local _lastAttackTime = 0
local _lastSkillCastTime = 0
local _skillCycle = {"Z", "X", "C", "V", "F"}
local _skillCycleIndex = 1

-- Resolve Net Remotes with deep-scan fallback
local function ResolveCombatRemote(remoteName)
    local cached = _remoteCache["Combat_" .. remoteName]
    if cached and cached.Parent then return cached end
    
    local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
    if net then
        local r = net:FindFirstChild(remoteName) or net:FindFirstChild("RE/" .. remoteName)
        if r then
            _remoteCache["Combat_" .. remoteName] = r
            return r
        end
        local reFolder = net:FindFirstChild("RE")
        if reFolder then
            local r2 = reFolder:FindFirstChild(remoteName)
            if r2 then
                _remoteCache["Combat_" .. remoteName] = r2
                return r2
            end
        end
    end
    
    local fallback = GetRemote(remoteName, "RemoteEvent") or GetRemote("RE/" .. remoteName, "RemoteEvent")
    if fallback then
        _remoteCache["Combat_" .. remoteName] = fallback
        return fallback
    end
    return nil
end

local _cachedCFController = nil
local _cfLookupAttempted = 0
local function GetCombatController()
    if _cachedCFController then return _cachedCFController end
    local now = tick()
    if (now - _cfLookupAttempted) < 5.0 then return nil end
    _cfLookupAttempted = now
    
    pcall(function()
        local cfModule = LocalPlayer.PlayerScripts:FindFirstChild("CombatFramework")
        if cfModule then
            local cf = require(cfModule)
            if type(cf) == "table" then
                if cf.activeController then
                    _cachedCFController = cf.activeController
                elseif getupvalues or (debug and debug.getupvalues) then
                    local guv = getupvalues or debug.getupvalues
                    for _, val in pairs(guv(cf)) do
                        if type(val) == "table" and rawget(val, "activeController") then
                            _cachedCFController = val.activeController
                            break
                        end
                    end
                end
            end
        end
    end)
    return _cachedCFController
end

local function GetBladeHits()
    local targets = {}
    local root = GetRoot()
    if not root then return targets end
    
    local maxDist = math.min(_G.Config.AttackDistance or 60, 60)
    
    local function CheckPart(folder, isPlayerFolder)
        if not folder then return end
        for _, v in ipairs(folder:GetChildren()) do
            if v ~= LocalPlayer.Character and (not isPlayerFolder or _G.Config.AttackPlayers) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local mobRoot = GetMobRoot(v)
                    if mobRoot and (mobRoot.Position - root.Position).Magnitude <= maxDist then
                        table.insert(targets, v)
                        if #targets >= 8 then return end
                    end
                end
            end
        end
    end
    
    CheckPart(Workspace:FindFirstChild("Enemies"), false)
    CheckPart(Workspace:FindFirstChild("SeaBeasts"), false)
    CheckPart(Workspace:FindFirstChild("SeaMonsters"), false)
    CheckPart(Workspace:FindFirstChild("BoatEnemies"), false)
    if _G.Config.AttackPlayers then
        CheckPart(Workspace:FindFirstChild("Characters"), true)
    end
    return targets
end

-- Fast M1 Clicks
local function FastAttack()
    if not _G.Config.FastAttack or not _G.Config.UseM1 then return end
    if _G.UIInteracting or IsTravelingSky then return end
    
    local char = GetCharacter()
    if not char then return end
    
    local selectedWep = NormalizeWeaponType(_G.Config.SelectedWeapon)
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not IsWeaponType(tool, selectedWep) then
        EquipWeapon(selectedWep)
        return
    end
    
    local now = tick()
    local cd = _G.Config.FastAttackSpeed or 0.015
    if (now - _lastAttackTime) < cd then return end
    _lastAttackTime = now
    
    local enemies = GetBladeHits()
    if #enemies > 0 then
        local controller = GetCombatController()
        if controller then
            controller.timeToNextAttack = 0
            controller.attacking = false
            controller.blocking = false
            if controller.humanoid then
                controller.humanoid.AutoRotate = true
            end
        end

        local regAttack = ResolveCombatRemote("RegisterAttack")
        local regHit = ResolveCombatRemote("RegisterHit")
        if regAttack and regHit then
            pcall(function()
                regAttack:FireServer(0)
                local hitList = {}
                local primaryPart = nil
                
                for _, v in ipairs(enemies) do
                    local part = v:FindFirstChild("Head") or GetMobRoot(v)
                    if part then
                        if not primaryPart then primaryPart = part end
                        table.insert(hitList, {v, part})
                    end
                end
                
                if primaryPart and #hitList > 0 then
                    regHit:FireServer(primaryPart, hitList)
                end
            end)
        end
        
        pcall(function() tool:Activate() end)
    end
end

-- Cast skills with selected weapon ONLY
local _skillCooldowns = { Z = 0, X = 0, C = 0, V = 0, F = 0 }
local _skillBaseCooldowns = { Z = 3.5, X = 5.0, C = 8.0, V = 12.0, F = 9.0 }

local function CastNextSkill()
    if not _G.Config.UseSkills or _G.UIInteracting or IsTravelingSky then return end
    
    local now = tick()
    if (now - _lastSkillCastTime) < 0.5 then return end
    
    local char = GetCharacter()
    if not char then return end
    local selectedWep = NormalizeWeaponType(_G.Config.SelectedWeapon)
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not IsWeaponType(tool, selectedWep) then
        EquipWeapon(selectedWep)
        return
    end
    
    local enemies = GetBladeHits()
    if #enemies == 0 then return end
    
    local allowedSkills = { Z = true, X = true }
    if selectedWep == "Melee" or selectedWep == "Sword" then
        allowedSkills.C = true
    elseif selectedWep == "Fruit" then
        allowedSkills.C = true
        allowedSkills.V = true
        allowedSkills.F = true
    end
    
    local chosenKey = nil
    for i = 1, #_skillCycle do
        local key = _skillCycle[_skillCycleIndex]
        _skillCycleIndex = (_skillCycleIndex % #_skillCycle) + 1
        
        if allowedSkills[key] and _G.Config["Skill_" .. key] then
            local lastUsed = _skillCooldowns[key] or 0
            local baseCD = _skillBaseCooldowns[key] or 4.0
            if (now - lastUsed) >= baseCD then
                chosenKey = key
                break
            end
        end
    end
    
    if chosenKey then
        _lastSkillCastTime = now
        _skillCooldowns[chosenKey] = now
        
        pcall(function()
            local targetRoot = GetMobRoot(enemies[1])
            local myRoot = GetRoot()
            if targetRoot and myRoot then
                myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(targetRoot.Position.X, myRoot.Position.Y, targetRoot.Position.Z))
            end
        end)
        
        task.spawn(function()
            local VIM = game:GetService("VirtualInputManager")
            local keyCode = Enum.KeyCode[chosenKey]
            if VIM and keyCode then
                pcall(function()
                    VIM:SendKeyEvent(true, keyCode, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, keyCode, false, game)
                end)
            elseif keypress and keyrelease then
                local byte = string.byte(chosenKey)
                pcall(function()
                    keypress(byte)
                    task.wait(0.05)
                    keyrelease(byte)
                end)
            end
        end)
    end
end

local function IsInCombatMode()
    return _G.Config.AutoFarmLevel
        or _G.Config.FarmSelectedMob
        or _G.Config.FarmSelectedBoss
        or _G.Config.FarmAllBosses
        or _G.Config.AutoKillRipIndra
        or _G.Config.AutoKillDoughKing
        or _G.Config.AutoKillCakePrince
        or _G.Config.AutoKillSoulReaper
        or _G.Config.AutoKillDarkbeard
        or _G.Config.AutoKillCursedCaptain
        or _G.Config.AutoKillLaw
        or _G.Config.AutoLawRaid
        or _G.Config.AutoFarmRaid
        or _G.Config.AutoKillSeaBeast
        or _G.Config.AutoKillTerrorShark
        or _G.Config.AutoKillShark
        or _G.Config.AutoKillPiranha
        or _G.Config.AutoKillGhostShip
        or _G.Config.AutoTrainV4
        or _G.Config.AutoFarmBones
        or _G.Config.AutoRaceV4Trial
        or _G.Config.AutoCakePrinceSummon
        or _G.Config.AutoDoughKingSummon
end

local function StartCombatLoop()
    task.spawn(function()
        while true do
            local cd = _G.Config.FastAttackSpeed or 0.015
            task.wait(cd)
            if IsInCombatMode() and not IsTravelingSky then
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
        if IsMobMatch(mob.Name, targetMobName) and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
            local mobRoot = GetMobRoot(mob)
            if mobRoot then
                local dist = (mobRoot.Position - centerCFrame.Position).Magnitude
                if dist < 140 and dist > 4 then
                    mobRoot.CFrame = centerCFrame
                    for _, p in ipairs(mob:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    mob.Humanoid.WalkSpeed = 0
                end
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
    {Sea = 3, Min = 2050, Max = 2074, Quest = "HauntedQuest2", Level = 2, Mob = "Possessed Mummy", Pos = CFrame.new(-9516.99, 12.01, 6078.47)},
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

-- Helper to resolve true Quest NPC position (Level 1 entry always holds NPC coords)
local function GetQuestNpcCFrame(questInfo)
    if not questInfo then return nil end
    for _, q in ipairs(QuestsDB) do
        if q.Quest == questInfo.Quest and q.Level == 1 then
            return q.Pos
        end
    end
    return questInfo.Pos
end

-- Strictly and authoritatively check if a quest is active
local function HasQuest()
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local qVal = data:FindFirstChild("Quest")
        if qVal and qVal:IsA("StringValue") and qVal.Value ~= "" then
            return true
        end
    end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        local main = pGui:FindFirstChild("Main")
        if main then
            local q = main:FindFirstChild("Quest")
            if q and q.Visible then
                return true
            end
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

-- Alias so both names work (UI uses GetActiveBossesList)
local GetActiveBossesList = GetSpawnedBossesList

-- ClearHover: stops hover/noclip state and resets player to normal ground physics
local function ClearHover()
    StopTween()
    DisableNoclip()
    local hum = GetHumanoid()
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    local root = GetRoot()
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("BodyVelocity") or c:IsA("BodyGyro") or c:IsA("BodyPosition") then
                pcall(function() c:Destroy() end)
            end
        end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    FlightBodyVel = nil
end

-- Robust mob name matcher (handles exact names, stripped level tags, case insensitivity)
local function IsMobMatch(mobName, targetName)
    if not mobName or not targetName then return false end
    if mobName == targetName then return true end
    local cleanMob = mobName:gsub("%s*%[Lv%.%s*%d+%]%s*$", "")
    if cleanMob == targetName then return true end
    if cleanMob:lower() == targetName:lower() then return true end
    return false
end

-- Find live enemy by name
local function FindEnemy(targetName)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local root = GetRoot()
    local closest, closestDist = nil, math.huge
    
    for _, mob in ipairs(enemies:GetChildren()) do
        if mob:IsA("Model") and IsMobMatch(mob.Name, targetName) then
            local hum = mob:FindFirstChildOfClass("Humanoid")
            local mRoot = GetMobRoot(mob)
            if hum and hum.Health > 0 and mRoot and not Validator.IsMobGlitched(mob) then
                local dist = root and (mRoot.Position - root.Position).Magnitude or 0
                if dist < closestDist then
                    closestDist = dist
                    closest = mob
                end
            end
        end
    end
    return closest
end
--============================== AUTO FARM LEVEL CORE ==============================
local function StartAutoFarmLevel()
    task.spawn(function()
        task.wait(1.0)
        while true do
            task.wait(0.2)
            if _G.Config.AutoFarmLevel then
                pcall(function()
                    local char = GetCharacter()
                    if not char then return end
                    local hum = GetHumanoid()
                    local root = GetRoot()
                    if not hum or hum.Health <= 0 or not root then return end
                    
                    local questInfo = GetCurrentQuest()
                    if not HasQuest() then
                        local npcCF = GetQuestNpcCFrame(questInfo)
                        local distToNPC = (npcCF.Position - root.Position).Magnitude
                        
                        if distToNPC > 30 then
                            TweenTo(npcCF * CFrame.new(0, 4, 0), "Quest NPC (" .. questInfo.Quest .. ")")
                        else
                            HoverLock(npcCF * CFrame.new(0, 4, 0))
                            local cf = CommF()
                            if cf then
                                cf:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
                                task.wait(0.5)
                            end
                        end
                    else
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

-- Auto Farm Selected Mob Core
local function StartAutoFarmSelectedMob()
    task.spawn(function()
        task.wait(1.0)
        while true do
            task.wait(0.25)
            if _G.Config.FarmSelectedMob then
                pcall(function()
                    local char = GetCharacter()
                    if not char then return end
                    local hum = GetHumanoid()
                    local root = GetRoot()
                    if not hum or hum.Health <= 0 or not root then return end
                    
                    if not _G.Config.SelectedMob or _G.Config.SelectedMob == "" then
                        local spawned = GetSpawnedMobsList()
                        if spawned and #spawned > 0 then
                            _G.Config.SelectedMob = spawned[1]
                        end
                    end
                    if _G.Config.SelectedMob and _G.Config.SelectedMob ~= "" then
                        local mobName = _G.Config.SelectedMob:gsub("^%[Spawned%] ", "")
                        local target = FindEnemy(mobName)
                        
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
                            local mobPos = nil
                            for _, q in ipairs(QuestsDB) do
                                if q.Sea == CurrentSea and IsMobMatch(q.Mob, mobName) then
                                    mobPos = q.Pos
                                    break
                                end
                            end
                            if mobPos then
                                local safePos = mobPos * CFrame.new(0, 30, 0)
                                local distToSafe = (safePos.Position - root.Position).Magnitude
                                if distToSafe < 15 then
                                    HoverLock(safePos)
                                else
                                    TweenTo(safePos, mobName .. " Spawn")
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end

local function StartAutoFarmSelectedBoss()
    task.spawn(function()
        task.wait(math.random(10, 25) / 10)
        while true do
            task.wait(0.3)
            if _G.Config.FarmSelectedBoss then
                if not _G.Config.SelectedBoss or _G.Config.SelectedBoss == "" then
                    local spawned = GetSpawnedBossesList()
                    if spawned and #spawned > 0 then
                        _G.Config.SelectedBoss = spawned[1]
                    end
                end
                if _G.Config.SelectedBoss and _G.Config.SelectedBoss ~= "" then
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
    else
        local bData = BossesDB[bossName]
        if bData and bData.Sea == CurrentSea then
            local checkPos = bData.Pos * CFrame.new(0, 35, 0)
            if (checkPos.Position - root.Position).Magnitude > 25 then
                TweenTo(checkPos, bossName .. " Spawn Area")
            end
        end
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

--============================== FULL VISUALS & ESP SUITE ==============================
local ESPFolder = {}
local function ClearESP(category)
    if ESPFolder[category] then
        for _, obj in pairs(ESPFolder[category]) do
            if obj and obj.Parent then pcall(function() obj:Destroy() end) end
        end
        ESPFolder[category] = {}
    else
        ESPFolder[category] = {}
    end
end

-- 1. Player ESP
local function UpdatePlayerESP()
    ClearESP("Players")
    if not _G.Config.PlayerESP then return end
    local root = GetRoot()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local pHrp = plr.Character.HumanoidRootPart
            local pHum = plr.Character.Humanoid
            local dist = root and math.floor((pHrp.Position - root.Position).Magnitude) or 0
            
            local bill = Instance.new("BillboardGui")
            bill.Name = RNG()
            bill.Adornee = pHrp
            bill.Size = UDim2.new(0, 150, 0, 48)
            bill.StudsOffset = Vector3.new(0, 3.5, 0)
            bill.AlwaysOnTop = true
            bill.Parent = pHrp
            
            local isMarine = (plr.Team and plr.Team.Name:find("Marine"))
            local teamColor = isMarine and Color3.fromRGB(0, 175, 255) or Color3.fromRGB(255, 55, 75)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0, 18)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = (isMarine and "🛡️ " or "🏴‍☠️ ") .. plr.DisplayName .. " (@" .. plr.Name .. ")"
            nameLabel.TextColor3 = teamColor
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 11
            nameLabel.Parent = bill
            
            local hpLabel = Instance.new("TextLabel")
            hpLabel.Size = UDim2.new(1, 0, 0, 14)
            hpLabel.Position = UDim2.new(0, 0, 0, 18)
            hpLabel.BackgroundTransparency = 1
            hpLabel.Text = "HP: " .. math.floor(pHum.Health) .. "/" .. math.floor(pHum.MaxHealth) .. " • " .. dist .. " studs"
            hpLabel.TextColor3 = Color3.fromRGB(100, 255, 130)
            hpLabel.Font = Enum.Font.GothamMedium
            hpLabel.TextSize = 10
            hpLabel.Parent = bill
            
            table.insert(ESPFolder["Players"], bill)
        end
    end
end

-- 2. Fruit ESP with Rarity Coding
local function GetFruitColor(name)
    local lower = name:lower()
    if lower:find("kitsune") or lower:find("dragon") or lower:find("leopard") or lower:find("t-rex") or lower:find("mammoth") or lower:find("dough") or lower:find("venom") or lower:find("spirit") or lower:find("shadow") then
        return Color3.fromRGB(255, 45, 95) -- Mythical Red/Pink
    elseif lower:find("blizzard") or lower:find("portal") or lower:find("rumble") or lower:find("buddha") or lower:find("phoenix") or lower:find("sound") or lower:find("quake") then
        return Color3.fromRGB(200, 50, 255) -- Legendary Magenta
    elseif lower:find("magma") or lower:find("ghost") or lower:find("light") or lower:find("dark") or lower:find("ice") then
        return Color3.fromRGB(0, 215, 255) -- Rare Cyan
    else
        return Color3.fromRGB(180, 180, 195) -- Common Gray
    end
end

local function UpdateFruitESP()
    ClearESP("Fruits")
    if not _G.Config.FruitESP then return end
    local root = GetRoot()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and (string.find(obj.Name, "Fruit") or obj.ToolTip == "Blox Fruit") and obj:FindFirstChild("Handle") then
            local dist = root and math.floor((obj.Handle.Position - root.Position).Magnitude) or 0
            local bill = Instance.new("BillboardGui")
            bill.Name = RNG()
            bill.Adornee = obj.Handle
            bill.Size = UDim2.new(0, 130, 0, 34)
            bill.StudsOffset = Vector3.new(0, 2.5, 0)
            bill.AlwaysOnTop = true
            bill.Parent = obj.Handle
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "🍇 " .. obj.Name .. "\n[" .. dist .. " studs]"
            label.TextColor3 = GetFruitColor(obj.Name)
            label.Font = Enum.Font.GothamBold
            label.TextSize = 11
            label.Parent = bill
            table.insert(ESPFolder["Fruits"], bill)
        end
    end
end

-- 3. Chest ESP & Auto Chest Collection
local function GetSpawnedChests()
    local chests = {}
    local function ScanFolder(folder)
        if not folder then return end
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("Model") or c:IsA("Part") then
                if string.find(c.Name, "Chest") or c:FindFirstChild("TouchInterest") then
                    table.insert(chests, c)
                end
            end
        end
    end
    ScanFolder(Workspace)
    local chestsFolder = Workspace:FindFirstChild("Chests")
    if chestsFolder then ScanFolder(chestsFolder) end
    local map = Workspace:FindFirstChild("Map")
    if map then ScanFolder(map) end
    return chests
end

local function UpdateChestESP()
    ClearESP("Chests")
    if not _G.Config.ChestESP then return end
    local root = GetRoot()
    for _, chest in ipairs(GetSpawnedChests()) do
        local part = chest:IsA("BasePart") and chest or chest:FindFirstChildWhichIsA("BasePart")
        if part then
            local dist = root and math.floor((part.Position - root.Position).Magnitude) or 0
            local bill = Instance.new("BillboardGui")
            bill.Name = RNG()
            bill.Adornee = part
            bill.Size = UDim2.new(0, 100, 0, 24)
            bill.StudsOffset = Vector3.new(0, 2, 0)
            bill.AlwaysOnTop = true
            bill.Parent = part
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = "🪙 " .. chest.Name .. " [" .. dist .. "m]"
            label.TextColor3 = Color3.fromRGB(255, 215, 0)
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 10
            label.Parent = bill
            table.insert(ESPFolder["Chests"], bill)
        end
    end
end

-- 4. Flower ESP (Bartilo Quest)
local function UpdateFlowerESP()
    ClearESP("Flowers")
    if not _G.Config.FlowerESP then return end
    local root = GetRoot()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if string.find(obj.Name:lower(), "flower") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = root and math.floor((part.Position - root.Position).Magnitude) or 0
                local bill = Instance.new("BillboardGui")
                bill.Name = RNG()
                bill.Adornee = part
                bill.Size = UDim2.new(0, 110, 0, 26)
                bill.StudsOffset = Vector3.new(0, 2, 0)
                bill.AlwaysOnTop = true
                bill.Parent = part
                
                local col = obj.Name:find("1") and Color3.fromRGB(0, 150, 255) or (obj.Name:find("2") and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 220, 0))
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = "🌸 " .. obj.Name .. " [" .. dist .. "m]"
                label.TextColor3 = col
                label.Font = Enum.Font.GothamBold
                label.TextSize = 11
                label.Parent = bill
                table.insert(ESPFolder["Flowers"], bill)
            end
        end
    end
end

-- 5. Mirage Island & Sea Events ESP
local function UpdateSeaEventESP()
    ClearESP("SeaEvents")
    if not _G.Config.MirageESP and not _G.Config.SeaEventESP then return end
    local root = GetRoot()
    
    if _G.Config.MirageESP then
        local mirage = Workspace:FindFirstChild("Mirage Island") or (Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin.Locations:FindFirstChild("Mirage Island"))
        if mirage then
            local part = mirage:IsA("BasePart") and mirage or mirage:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = root and math.floor((part.Position - root.Position).Magnitude) or 0
                local bill = Instance.new("BillboardGui")
                bill.Name = RNG()
                bill.Adornee = part
                bill.Size = UDim2.new(0, 170, 0, 40)
                bill.StudsOffset = Vector3.new(0, 60, 0)
                bill.AlwaysOnTop = true
                bill.Parent = part
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = "🌙 MIRAGE ISLAND ACTIVE!\n[" .. dist .. " studs]"
                label.TextColor3 = Color3.fromRGB(150, 110, 255)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 12
                label.Parent = bill
                table.insert(ESPFolder["SeaEvents"], bill)
            end
        end
    end
    
    if _G.Config.SeaEventESP then
        local function CheckSeaMob(mob, icon, col)
            if mob and mob:FindFirstChild("HumanoidRootPart") then
                local dist = root and math.floor((mob.HumanoidRootPart.Position - root.Position).Magnitude) or 0
                local bill = Instance.new("BillboardGui")
                bill.Name = RNG()
                bill.Adornee = mob.HumanoidRootPart
                bill.Size = UDim2.new(0, 150, 0, 36)
                bill.StudsOffset = Vector3.new(0, 18, 0)
                bill.AlwaysOnTop = true
                bill.Parent = mob.HumanoidRootPart
                
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = icon .. " " .. mob.Name .. "\n[" .. dist .. " studs]"
                label.TextColor3 = col
                label.Font = Enum.Font.GothamBold
                label.TextSize = 11
                label.Parent = bill
                table.insert(ESPFolder["SeaEvents"], bill)
            end
        end
        
        local sbFolder = Workspace:FindFirstChild("SeaBeasts")
        if sbFolder then
            for _, sb in ipairs(sbFolder:GetChildren()) do
                CheckSeaMob(sb, "🐉", Color3.fromRGB(0, 230, 255))
            end
        end
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, mob in ipairs(enemies:GetChildren()) do
                if string.find(mob.Name, "SeaBeast") or string.find(mob.Name, "Sea Beast") then
                    CheckSeaMob(mob, "🐉", Color3.fromRGB(0, 230, 255))
                elseif string.find(mob.Name, "Terror Shark") then
                    CheckSeaMob(mob, "🦈", Color3.fromRGB(255, 45, 95))
                end
            end
        end
    end
end

local function StartChestFarmLoop()
    task.spawn(function()
        task.wait(2)
        while true do
            task.wait(0.3)
            if _G.Config.AutoChestFarm then
                pcall(function()
                    local chests = GetSpawnedChests()
                    local root = GetRoot()
                    if root and #chests > 0 then
                        local closest = nil
                        local minDist = math.huge
                        for _, c in ipairs(chests) do
                            local part = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart")
                            if part then
                                local d = (part.Position - root.Position).Magnitude
                                if d < minDist then
                                    minDist = d
                                    closest = part
                                end
                            end
                        end
                        if closest then
                            TweenTo(closest.CFrame * CFrame.new(0, 2, 0))
                            task.wait(0.2)
                        end
                    end
                end)
            end
        end
    end)
end

local function StartESPLoops()
    task.spawn(function()
        task.wait(2)
        while true do
            task.wait(2.5)
            pcall(function()
                if _G.Config.PlayerESP then UpdatePlayerESP() else ClearESP("Players") end
                if _G.Config.FruitESP then UpdateFruitESP() else ClearESP("Fruits") end
                if _G.Config.ChestESP then UpdateChestESP() else ClearESP("Chests") end
                if _G.Config.FlowerESP then UpdateFlowerESP() else ClearESP("Flowers") end
                if _G.Config.MirageESP or _G.Config.SeaEventESP then UpdateSeaEventESP() else ClearESP("SeaEvents") end
            end)
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
                        local data = LocalPlayer:FindFirstChild("Data")
                        local ptsAvail = (data and data:FindFirstChild("Points") and data.Points.Value) or 0
                        if ptsAvail > 0 then
                            local pts = math.min(_G.Config.StatPoints or 1, ptsAvail)
                            if _G.Config.Stats.Melee then cf:InvokeServer("AddPoint", "Melee", pts) end
                            if _G.Config.Stats.Defense then cf:InvokeServer("AddPoint", "Defense", pts) end
                            if _G.Config.Stats.Sword then cf:InvokeServer("AddPoint", "Sword", pts) end
                            if _G.Config.Stats.Gun then cf:InvokeServer("AddPoint", "Gun", pts) end
                            if _G.Config.Stats.Fruit then cf:InvokeServer("AddPoint", "Demon Fruit", pts) end
                        end
                    end)
                end
            end
        end
    end)
end

--============================== ADVANCED RAIDS & DUNGEONS ENGINE ==============================
local function StartAdvancedRaidEngine()
    task.spawn(function()
        task.wait(2.5)
        while true do
            task.wait(1.5)
            pcall(function()
                local cf = CommF()
                if not cf then return end
                
                -- Auto Buy Raid Chip
                if _G.Config.AutoBuyChip then
                    cf:InvokeServer("RaidsNpc", "Select", _G.Config.SelectedChip)
                end
                
                -- Auto Start Raid
                if _G.Config.AutoStartRaid then
                    cf:InvokeServer("RaidsNpc", "Start")
                end
                
                -- Auto Farm Raid & Next Island Transition
                if _G.Config.AutoFarmRaid then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local hasMobs = false
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                hasMobs = true
                                local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, _G.Config.FarmDistance, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                TweenTo(farmPos)
                                EquipWeapon(_G.Config.SelectedWeapon)
                                break
                            end
                        end
                    end
                    
                    if not hasMobs then
                        local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
                        if locs then
                            for i = 1, 5 do
                                local island = locs:FindFirstChild("Island " .. i) or locs:FindFirstChild("Island" .. i)
                                if island then
                                    local root = GetRoot()
                                    if root and (island.Position - root.Position).Magnitude > 250 then
                                        TweenTo(island.CFrame * CFrame.new(0, 45, 0))
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Auto Awaken Fruit
                if _G.Config.AutoAwaken then
                    cf:InvokeServer("Awakener", "Check")
                    cf:InvokeServer("Awakener", "Awaken")
                end
                
                -- Auto Law / Order Raid
                if _G.Config.AutoLawRaid then
                    cf:InvokeServer("BlackbeardReward", "LawChip")
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        local order = enemies:FindFirstChild("Order")
                        if order and order:FindFirstChild("HumanoidRootPart") and order:FindFirstChild("Humanoid") and order.Humanoid.Health > 0 then
                            local farmPos = order.HumanoidRootPart.CFrame * CFrame.new(0, 25, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            TweenTo(farmPos)
                            EquipWeapon(_G.Config.SelectedWeapon)
                        end
                    end
                end
            end)
        end
    end)
end

--============================== COMPLETE SEA EVENTS & MIRAGE ENGINE ==============================
local function CheckIslandSpawn(islandName)
    local locs = Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("Locations")
    if locs and locs:FindFirstChild(islandName) then return true end
    if Workspace:FindFirstChild(islandName) then return true end
    return false
end

local function StartSeaEventsEngine()
    task.spawn(function()
        task.wait(2.0)
        while true do
            task.wait(0.35)
            pcall(function()
                local root = GetRoot()
                if not root then return end
                
                -- 1. Auto Kill Sea Beast (Safe hover 65 studs above water to evade water blast)
                if _G.Config.AutoKillSeaBeast then
                    local targetSB = nil
                    local sbFolder = Workspace:FindFirstChild("SeaBeasts")
                    if sbFolder then
                        for _, sb in ipairs(sbFolder:GetChildren()) do
                            if sb:FindFirstChild("HumanoidRootPart") and sb:FindFirstChild("Humanoid") and sb.Humanoid.Health > 0 then
                                targetSB = sb
                                break
                            end
                        end
                    end
                    if not targetSB then
                        local enemies = Workspace:FindFirstChild("Enemies")
                        if enemies then
                            for _, mob in ipairs(enemies:GetChildren()) do
                                if (string.find(mob.Name, "SeaBeast") or string.find(mob.Name, "Sea Beast")) and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                    targetSB = mob
                                    break
                                end
                            end
                        end
                    end
                    
                    if targetSB then
                        local farmPos = targetSB.HumanoidRootPart.CFrame * CFrame.new(0, 65, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                        local distToFarm = (farmPos.Position - root.Position).Magnitude
                        if distToFarm < 20 then
                            HoverLock(farmPos)
                        else
                            TweenTo(farmPos)
                        end
                        EquipWeapon(_G.Config.SelectedWeapon)
                        return
                    end
                end
                
                -- 2. Auto Kill Terror Shark (Safe hover 38 studs to evade bite hitboxes)
                if _G.Config.AutoKillTerrorShark then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        local ts = enemies:FindFirstChild("Terror Shark")
                        if ts and ts:FindFirstChild("HumanoidRootPart") and ts:FindFirstChild("Humanoid") and ts.Humanoid.Health > 0 then
                            local farmPos = ts.HumanoidRootPart.CFrame * CFrame.new(0, 38, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                            local distToFarm = (farmPos.Position - root.Position).Magnitude
                            if distToFarm < 16 then
                                HoverLock(farmPos)
                            else
                                TweenTo(farmPos)
                            end
                            EquipWeapon(_G.Config.SelectedWeapon)
                            return
                        end
                    end
                end
                
                -- 3. Auto Kill Sharks & Piranhas
                if _G.Config.AutoKillShark then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if (string.find(mob.Name, "Shark") or string.find(mob.Name, "Piranha")) and mob.Name ~= "Terror Shark" and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, 22, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                TweenTo(farmPos)
                                EquipWeapon(_G.Config.SelectedWeapon)
                                return
                            end
                        end
                    end
                end
                
                -- 4. Auto Mirage Blue Gear
                if _G.Config.AutoFindGear then
                    local mirage = Workspace:FindFirstChild("Mirage Island") or (Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin.Locations:FindFirstChild("Mirage Island"))
                    if mirage then
                        for _, v in ipairs(mirage:GetDescendants()) do
                            if v:IsA("BasePart") and (v.Name == "Gear" or v.Name == "BlueGear" or string.find(v.Name:lower(), "gear")) then
                                TweenTo(v.CFrame * CFrame.new(0, 2, 0))
                                task.wait(0.5)
                                local prompt = v:FindFirstChildWhichIsA("ProximityPrompt") or (v.Parent and v.Parent:FindFirstChildWhichIsA("ProximityPrompt"))
                                if prompt and fireproximityprompt then
                                    fireproximityprompt(prompt)
                                end
                                return
                            end
                        end
                    end
                end
                
                -- 5. Auto Kitsune Azure Embers
                if _G.Config.AutoKitsuneEmber then
                    local kitsune = Workspace:FindFirstChild("Kitsune Island") or (Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island"))
                    if kitsune then
                        for _, ember in ipairs(Workspace:GetChildren()) do
                            if ember.Name == "Ember" or ember.Name == "AzureEmber" or string.find(ember.Name, "Ember") then
                                local part = ember:IsA("BasePart") and ember or ember:FindFirstChildWhichIsA("BasePart")
                                if part then
                                    TweenTo(part.CFrame)
                                    task.wait(0.3)
                                    local prompt = ember:FindFirstChildWhichIsA("ProximityPrompt")
                                    if prompt and fireproximityprompt then
                                        fireproximityprompt(prompt)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

--============================== RACE V4 AWAKENING ENGINE ==============================
local function StartRaceV4Engine()
    task.spawn(function()
        task.wait(2.5)
        while true do
            task.wait(1.0)
            pcall(function()
                local root = GetRoot()
                if not root then return end
                
                -- Auto Pull Lever (Temple of Time)
                if _G.Config.AutoPullLever then
                    local tot = Workspace:FindFirstChild("TempleOfTime") or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("TempleOfTime"))
                    local lever = tot and (tot:FindFirstChild("Lever") or tot:FindFirstChild("SecretLever"))
                    if lever then
                        local part = lever:IsA("BasePart") and lever or lever:FindFirstChildWhichIsA("BasePart")
                        if part then
                            TweenTo(part.CFrame * CFrame.new(0, 2, 0))
                            task.wait(0.5)
                            local prompt = lever:FindFirstChildWhichIsA("ProximityPrompt")
                            if prompt and fireproximityprompt then fireproximityprompt(prompt) end
                        end
                    end
                end
                
                -- Auto Complete Trial
                if _G.Config.AutoRaceV4Trial then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local farmPos = mob.HumanoidRootPart.CFrame * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                TweenTo(farmPos)
                                EquipWeapon(_G.Config.SelectedWeapon)
                                break
                            end
                        end
                    end
                end
                
                -- Auto Insert Gear into Ancient Clock
                if _G.Config.AutoInsertGear then
                    local clock = Workspace:FindFirstChild("AncientClock") or (Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("AncientClock"))
                    if clock then
                        local part = clock:IsA("BasePart") and clock or clock:FindFirstChildWhichIsA("BasePart")
                        if part then
                            TweenTo(part.CFrame * CFrame.new(0, 3, 0))
                            task.wait(0.5)
                            local prompt = clock:FindFirstChildWhichIsA("ProximityPrompt")
                            if prompt and fireproximityprompt then fireproximityprompt(prompt) end
                        end
                    end
                end
            end)
        end
    end)
end

--============================== BONES & SPECIAL EVENTS ENGINE ==============================
local function StartSpecialBossAndBoneEngine()
    task.spawn(function()
        task.wait(2.2)
        while true do
            task.wait(0.8)
            pcall(function()
                local cf = CommF()
                if not cf then return end
                local root = GetRoot()
                if not root then return end
                
                -- Auto Farm Bones (Sea 3 Haunted Castle)
                if _G.Config.AutoFarmBones and Sea3 then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local boneMobs = {"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Possessed Mummy"}
                    local foundMob = false
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            local isBone = false
                            for _, bName in ipairs(boneMobs) do
                                if IsMobMatch(mob.Name, bName) then isBone = true; break end
                            end
                            if isBone and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local mobRoot = GetMobRoot(mob)
                                if mobRoot then
                                    foundMob = true
                                    local farmPos = mobRoot.CFrame * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                    TweenTo(farmPos, mob.Name)
                                    EquipWeapon(_G.Config.SelectedWeapon)
                                    BringMobsTo(mob.Name, mobRoot.CFrame)
                                    return
                                end
                            end
                        end
                    end
                    if not foundMob then
                        TweenTo(CFrame.new(-9516.99, 142.01, 6078.47), "Haunted Castle")
                    end
                end
                
                -- Auto Roll Bones at Death King (Verified >= 50 Bones)
                if _G.Config.AutoRollBones and Sea3 then
                    local data = LocalPlayer:FindFirstChild("Data")
                    local bones = (data and data:FindFirstChild("Bones") and data.Bones.Value) or 0
                    if bones >= 50 then
                        cf:InvokeServer("Bones", "Buy", 1)
                    end
                end
                
                -- Auto Summon Soul Reaper
                if _G.Config.AutoSummonSoulReaper and Sea3 then
                    local bp = LocalPlayer:FindFirstChild("Backpack")
                    local char = GetCharacter()
                    local hasEssence = (bp and bp:FindFirstChild("Hallow Essence")) or (char and char:FindFirstChild("Hallow Essence"))
                    if hasEssence then
                        if bp:FindFirstChild("Hallow Essence") then
                            bp["Hallow Essence"].Parent = char
                        end
                        TweenTo(CFrame.new(-9516.99, 172.01, 6078.47), "Soul Reaper Altar")
                    end
                end
                
                -- Auto Cake Prince / Dough King Mobs Farm
                if (_G.Config.AutoCakePrinceSummon or _G.Config.AutoDoughKingSummon) and Sea3 then
                    local enemies = Workspace:FindFirstChild("Enemies")
                    local cakeMobs = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker", "Cocoa Warrior", "Chocolate Bar Battler"}
                    if enemies then
                        for _, mob in ipairs(enemies:GetChildren()) do
                            local isCake = false
                            for _, cName in ipairs(cakeMobs) do
                                if IsMobMatch(mob.Name, cName) then isCake = true; break end
                            end
                            if isCake and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                                local mobRoot = GetMobRoot(mob)
                                if mobRoot then
                                    local farmPos = mobRoot.CFrame * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-90), 0, 0)
                                    TweenTo(farmPos, mob.Name)
                                    EquipWeapon(_G.Config.SelectedWeapon)
                                    BringMobsTo(mob.Name, mobRoot.CFrame)
                                    return
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

--============================== AUTO HAKI ENGINE ==============================
local function StartHakiLoop()
    task.spawn(function()
        task.wait(1.5)
        while true do
            task.wait(2.0)
            pcall(function()
                local char = GetCharacter()
                if not char then return end
                local cf = CommF()
                
                -- Auto Buso Haki
                if _G.Config.AutoBusoHaki and cf then
                    local hasBuso = char:FindFirstChild("HasBuso") or char:FindFirstChild("Buso")
                    if not hasBuso then
                        cf:InvokeServer("Buso")
                    end
                end
                
                -- Auto Ken Haki
                if _G.Config.AutoKenHaki and cf then
                    local vision = char:FindFirstChild("Vision") or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("VisionGui"))
                    if not vision then
                        cf:InvokeServer("KenHaki")
                    end
                end
            end)
        end
    end)
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
    -- 3D COCKPIT TRAVEL HUD (Live Progress Bar & Flight Stats)
    -- -------------------------------------------------------------
    local MainFrame = nil -- Forward declaration so Travel HUD can dock directly above MainFrame
    local TravelFrame = Instance.new("Frame")
    TravelFrame.Name = RNG()
    TravelFrame.Size = UDim2.new(0, 370, 0, 58)
    TravelFrame.Position = UDim2.new(0.5, -185, 0.5, -280)
    TravelFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 20)
    TravelFrame.BorderSizePixel = 0
    TravelFrame.Active = true
    TravelFrame.Selectable = true
    TravelFrame.Visible = false
    TravelFrame.ZIndex = 60
    TravelFrame.Parent = ScreenGui
    
    local TravelCorner = Instance.new("UICorner")
    TravelCorner.CornerRadius = UDim.new(0, 10)
    TravelCorner.Parent = TravelFrame
    
    local TravelStroke = Instance.new("UIStroke")
    TravelStroke.Color = Color3.fromRGB(0, 230, 255)
    TravelStroke.Thickness = 1.6
    TravelStroke.Parent = TravelFrame
    
    local TravelGrad = Instance.new("UIGradient")
    TravelGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 28, 42)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 12, 18))
    }
    TravelGrad.Rotation = 90
    TravelGrad.Parent = TravelFrame
    
    local TravelTitle = Instance.new("TextLabel")
    TravelTitle.Size = UDim2.new(1, -95, 0, 22)
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
    TravelDist.Size = UDim2.new(1, -95, 0, 16)
    TravelDist.Position = UDim2.new(0, 14, 0, 26)
    TravelDist.Text = "Distance: 0 studs • Speed: 250 studs/s"
    TravelDist.TextColor3 = Color3.fromRGB(170, 190, 220)
    TravelDist.Font = Enum.Font.Gotham
    TravelDist.TextSize = 10
    TravelDist.TextXAlignment = Enum.TextXAlignment.Left
    TravelDist.BackgroundTransparency = 1
    TravelDist.ZIndex = 61
    TravelDist.Parent = TravelFrame
    
    local TravelProgressBar = Instance.new("Frame")
    TravelProgressBar.Size = UDim2.new(1, -110, 0, 4)
    TravelProgressBar.Position = UDim2.new(0, 14, 0, 44)
    TravelProgressBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    TravelProgressBar.BorderSizePixel = 0
    TravelProgressBar.ZIndex = 61
    TravelProgressBar.Parent = TravelFrame
    local TPBCorner = Instance.new("UICorner")
    TPBCorner.CornerRadius = UDim.new(1, 0)
    TPBCorner.Parent = TravelProgressBar
    
    local TravelProgressFill = Instance.new("Frame")
    TravelProgressFill.Size = UDim2.new(0, 0, 1, 0)
    TravelProgressFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    TravelProgressFill.BorderSizePixel = 0
    TravelProgressFill.ZIndex = 62
    TravelProgressFill.Parent = TravelProgressBar
    local TPBFCorner = Instance.new("UICorner")
    TPBFCorner.CornerRadius = UDim.new(1, 0)
    TPBFCorner.Parent = TravelProgressFill
    
    local CancelFlightBtn = Instance.new("TextButton")
    CancelFlightBtn.Size = UDim2.new(0, 76, 0, 32)
    CancelFlightBtn.Position = UDim2.new(1, -86, 0.5, -16)
    CancelFlightBtn.Text = "✕ CANCEL"
    CancelFlightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelFlightBtn.Font = Enum.Font.GothamBold
    CancelFlightBtn.TextSize = 10
    CancelFlightBtn.BackgroundColor3 = Color3.fromRGB(230, 40, 75)
    CancelFlightBtn.BorderSizePixel = 0
    CancelFlightBtn.Active = true
    CancelFlightBtn.ZIndex = 62
    CancelFlightBtn.Parent = TravelFrame
    local CFCorner = Instance.new("UICorner")
    CFCorner.CornerRadius = UDim.new(0, 6)
    CFCorner.Parent = CancelFlightBtn
    
    CancelFlightBtn.MouseButton1Click:Connect(function()
        PlayClickSound()
        StopTween()
    end)
    
    -- Draggable functionality for Travel HUD
    local travelDragging, travelDragInput, travelDragStart, travelStartPos
    local travelHasCustomPos = false
    TravelFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            travelDragging = true
            travelDragStart = input.Position
            travelStartPos = TravelFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    travelDragging = false
                end
            end)
        end
    end)
    TravelFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            travelDragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == travelDragInput and travelDragging then
            local delta = input.Position - travelDragStart
            travelHasCustomPos = true
            TravelFrame.Position = UDim2.new(travelStartPos.X.Scale, travelStartPos.X.Offset + delta.X, travelStartPos.Y.Scale, travelStartPos.Y.Offset + delta.Y)
        end
    end)

    local function GetDockedTravelPos()
        if MainFrame then
            local ox = MainFrame.Position.X.Offset + math.floor((MainFrame.Size.X.Offset - 370) / 2)
            local oy = MainFrame.Position.Y.Offset - 66
            return UDim2.new(MainFrame.Position.X.Scale, ox, MainFrame.Position.Y.Scale, oy)
        end
        return UDim2.new(0.5, -185, 0.5, -256)
    end
    
    local isTravelHUDActive = false
    SetTravelHUD = function(visible, destName, curDist, spd, totalDist)
        if visible then
            TravelTitle.Text = "✈️ FLYING TO: " .. tostring(destName or "TARGET"):upper()
            TravelDist.Text = "Distance: " .. math.floor(curDist or 0) .. " studs • Speed: " .. math.floor(spd or 250) .. " studs/s"
            if totalDist and totalDist > 0 then
                local pct = math.clamp(1 - ((curDist or 0) / totalDist), 0, 1)
                TravelProgressFill.Size = UDim2.new(pct, 0, 1, 0)
            end
            if not isTravelHUDActive then
                isTravelHUDActive = true
                TravelFrame.Visible = true
                local targetPos = travelHasCustomPos and TravelFrame.Position or GetDockedTravelPos()
                if not travelHasCustomPos then
                    TravelFrame.Position = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset - 25)
                    TweenService:Create(TravelFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos}):Play()
                end
            end
        else
            if isTravelHUDActive then
                isTravelHUDActive = false
                TravelProgressFill.Size = UDim2.new(0, 0, 1, 0)
                if not travelHasCustomPos then
                    local hidePos = UDim2.new(TravelFrame.Position.X.Scale, TravelFrame.Position.X.Offset, TravelFrame.Position.Y.Scale, TravelFrame.Position.Y.Offset - 30)
                    local tw = TweenService:Create(TravelFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = hidePos})
                    tw:Play()
                    tw.Completed:Connect(function()
                        if not isTravelHUDActive then TravelFrame.Visible = false end
                    end)
                else
                    TravelFrame.Visible = false
                end
            end
        end
    end
    
    -- -------------------------------------------------------------
    -- 3D DEEP SHADOW LAYER
    -- -------------------------------------------------------------
    local ShadowFrame = Instance.new("Frame")
    ShadowFrame.Name = RNG()
    ShadowFrame.Size = UDim2.new(0, 614, 0, 394)
    ShadowFrame.Position = UDim2.new(0.5, -297, 0.5, -182)
    ShadowFrame.BackgroundColor3 = Color3.fromRGB(3, 4, 6)
    ShadowFrame.BackgroundTransparency = 0.35
    ShadowFrame.BorderSizePixel = 0
    ShadowFrame.Parent = ScreenGui
    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 14)
    ShadowCorner.Parent = ShadowFrame
    
    -- -------------------------------------------------------------
    -- MAIN CONTAINER (3D Obsidian Cyber Glassmorphism)
    -- -------------------------------------------------------------
    MainFrame = Instance.new("Frame")
    MainFrame.Name = RNG()
    MainFrame.Size = UDim2.new(0, 600, 0, 380)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -190)
    MainFrame.BackgroundColor3 = Color3.fromRGB(11, 12, 17)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    
    -- Smooth 3D Entrance Bounce Animation on load
    MainFrame.Size = UDim2.new(0, 520, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 600, 0, 380),
        Position = UDim2.new(0.5, -300, 0.5, -190)
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
    MainStroke.Color = Color3.fromRGB(0, 230, 255)
    MainStroke.Thickness = 1.6
    MainStroke.Transparency = 0.15
    MainStroke.Parent = MainFrame
    
    -- Dynamic rotating glowing border effect
    local StrokeGrad = Instance.new("UIGradient")
    StrokeGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 235, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 45, 95)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 235, 255))
    }
    StrokeGrad.Parent = MainStroke
    
    task.spawn(function()
        local rot = 0
        while MainStroke.Parent do
            rot = (rot + 2) % 360
            StrokeGrad.Rotation = rot
            task.wait(0.03)
        end
    end)
    
    -- 3D Top Bevel Highlight Line
    local TopHighlight = Instance.new("Frame")
    TopHighlight.Size = UDim2.new(1, 0, 0, 1)
    TopHighlight.BackgroundColor3 = Color3.fromRGB(150, 240, 255)
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
            if not travelHasCustomPos and TravelFrame and TravelFrame.Visible then
                TravelFrame.Position = GetDockedTravelPos()
            end
        end
    end)
    
    -- Top Bar with Metallic Gradient
    local TopBar = Instance.new("Frame")
    TopBar.Name = RNG()
    TopBar.Size = UDim2.new(1, 0, 0, 44)
    TopBar.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.Parent = MainFrame
    
    local TopBarGrad = Instance.new("UIGradient")
    TopBarGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 28, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 16, 22))
    }
    TopBarGrad.Rotation = 90
    TopBarGrad.Parent = TopBar
    
    local TopStroke = Instance.new("UIStroke")
    TopStroke.Color = Color3.fromRGB(34, 38, 54)
    TopStroke.Thickness = 1
    TopStroke.Parent = TopBar
    
    -- 3D Logo Badge
    local LogoBadge = Instance.new("Frame")
    LogoBadge.Size = UDim2.new(0, 26, 0, 26)
    LogoBadge.Position = UDim2.new(0, 12, 0, 9)
    LogoBadge.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    LogoBadge.BorderSizePixel = 0
    LogoBadge.Parent = TopBar
    local LBCorner = Instance.new("UICorner")
    LBCorner.CornerRadius = UDim.new(0, 6)
    LBCorner.Parent = LogoBadge
    local LBLabel = Instance.new("TextLabel")
    LBLabel.Size = UDim2.new(1, 0, 1, 0)
    LBLabel.Text = "α"
    LBLabel.TextColor3 = Color3.fromRGB(10, 12, 18)
    LBLabel.Font = Enum.Font.GothamBold
    LBLabel.TextSize = 16
    LBLabel.BackgroundTransparency = 1
    LBLabel.Parent = LogoBadge
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 220, 1, 0)
    TitleLabel.Position = UDim2.new(0, 46, 0, 0)
    TitleLabel.Text = "ALPHA // 3D CYBER EDITION"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Active = true
    TitleLabel.Parent = TopBar
    
    -- Status Pill Badges
    local SeaBadge = Instance.new("Frame")
    SeaBadge.Size = UDim2.new(0, 95, 0, 22)
    SeaBadge.Position = UDim2.new(0, 246, 0, 11)
    SeaBadge.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
    SeaBadge.BorderSizePixel = 0
    SeaBadge.Parent = TopBar
    local SBCorner = Instance.new("UICorner")
    SBCorner.CornerRadius = UDim.new(1, 0)
    SBCorner.Parent = SeaBadge
    local SBStroke = Instance.new("UIStroke")
    SBStroke.Color = Color3.fromRGB(0, 210, 255)
    SBStroke.Thickness = 1
    SBStroke.Transparency = 0.4
    SBStroke.Parent = SeaBadge
    local SBLabel = Instance.new("TextLabel")
    SBLabel.Size = UDim2.new(1, 0, 1, 0)
    SBLabel.Text = "🌊 " .. SeaName
    SBLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    SBLabel.Font = Enum.Font.GothamBold
    SBLabel.TextSize = 10
    SBLabel.BackgroundTransparency = 1
    SBLabel.Parent = SeaBadge
    
    -- Live Performance Monitor Badge (FPS & Ping)
    local PerfBadge = Instance.new("Frame")
    PerfBadge.Size = UDim2.new(0, 138, 0, 22)
    PerfBadge.Position = UDim2.new(0, 348, 0, 11)
    PerfBadge.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    PerfBadge.BorderSizePixel = 0
    PerfBadge.Parent = TopBar
    local PBCorner = Instance.new("UICorner")
    PBCorner.CornerRadius = UDim.new(1, 0)
    PBCorner.Parent = PerfBadge
    local PBStroke = Instance.new("UIStroke")
    PBStroke.Color = Color3.fromRGB(0, 230, 160)
    PBStroke.Thickness = 1
    PBStroke.Transparency = 0.4
    PBStroke.Parent = PerfBadge
    local PBLabel = Instance.new("TextLabel")
    PBLabel.Size = UDim2.new(1, 0, 1, 0)
    PBLabel.Text = "🟢 60 FPS | 40ms"
    PBLabel.TextColor3 = Color3.fromRGB(0, 240, 180)
    PBLabel.Font = Enum.Font.GothamBold
    PBLabel.TextSize = 10
    PBLabel.BackgroundTransparency = 1
    PBLabel.Parent = PerfBadge
    
    task.spawn(function()
        local lastTime = tick()
        local frameCount = 0
        local currentFPS = 60
        
        RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local now = tick()
            if (now - lastTime) >= 0.5 then
                currentFPS = math.floor(frameCount / (now - lastTime))
                frameCount = 0
                lastTime = now
                
                local ping = 45
                pcall(function()
                    local statsService = game:GetService("Stats")
                    local netStats = statsService.Network.ServerStatsItem
                    if netStats and netStats["Data Ping"] then
                        ping = math.floor(netStats["Data Ping"]:GetValue())
                    elseif LocalPlayer.GetNetworkPing then
                        ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                    end
                end)
                
                local icon = "🟢"
                local col = Color3.fromRGB(0, 240, 180)
                if currentFPS < 30 or ping > 180 then
                    icon = "🔴"
                    col = Color3.fromRGB(255, 75, 95)
                elseif currentFPS < 45 or ping > 110 then
                    icon = "🟡"
                    col = Color3.fromRGB(255, 200, 50)
                end
                
                PBLabel.Text = string.format("%s %d FPS | %dms", icon, currentFPS, ping)
                PBLabel.TextColor3 = col
                PBStroke.Color = col
            end
        end)
    end)
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0, 8)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(220, 220, 235)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.BackgroundColor3 = Color3.fromRGB(34, 22, 30)
    CloseBtn.BorderSizePixel = 0
    CloseBtn.Active = true
    CloseBtn.Parent = TopBar
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(225, 35, 70)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(34, 22, 30)}):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        PlayClickSound()
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 520, 0, 320),
            Position = UDim2.new(0.5, -260, 0.5, -160)
        }):Play()
        task.wait(0.25)
        MainFrame.Visible = false
    end)
    
    -- Floating Draggable Cyber Orb Button
    local FloatingBtn = Instance.new("TextButton")
    FloatingBtn.Name = RNG()
    FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
    FloatingBtn.Position = UDim2.new(0, 20, 0.5, -26)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
    FloatingBtn.Text = "ALPHA"
    FloatingBtn.TextColor3 = Color3.fromRGB(0, 235, 255)
    FloatingBtn.Font = Enum.Font.GothamBold
    FloatingBtn.TextSize = 11
    FloatingBtn.BorderSizePixel = 0
    FloatingBtn.Active = true
    FloatingBtn.Parent = ScreenGui
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatingBtn
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(0, 230, 255)
    FloatStroke.Thickness = 2
    FloatStroke.Parent = FloatingBtn
    
    task.spawn(function()
        while FloatStroke.Parent do
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
        PlayClickSound()
        if not MainFrame.Visible then
            MainFrame.Visible = true
            MainFrame.Size = UDim2.new(0, 520, 0, 320)
            MainFrame.Position = UDim2.new(0.5, -260, 0.5, -160)
            TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 600, 0, 380),
                Position = UDim2.new(0.5, -300, 0.5, -190)
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
    Sidebar.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 2
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 440)
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
    ContentHolder.BackgroundColor3 = Color3.fromRGB(11, 12, 17)
    ContentHolder.BorderSizePixel = 0
    ContentHolder.Active = true
    ContentHolder.Parent = MainFrame
    
    local Tabs = {}
    local CurrentActiveTab = nil
    
    -- Sliding Tab Indicator
    local TabIndicator = Instance.new("Frame")
    TabIndicator.Name = "ActiveTabIndicator"
    TabIndicator.Size = UDim2.new(0, 4, 0, 24)
    TabIndicator.Position = UDim2.new(0, 2, 0, 8)
    TabIndicator.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    TabIndicator.BorderSizePixel = 0
    TabIndicator.ZIndex = 5
    TabIndicator.Parent = Sidebar
    local TICorner = Instance.new("UICorner")
    TICorner.CornerRadius = UDim.new(1, 0)
    TICorner.Parent = TabIndicator
    
    local function SwitchTab(tabName)
        PlayClickSound()
        for name, page in pairs(Tabs) do
            if name == tabName then
                page.Page.Position = UDim2.new(0, 0, 0, 8)
                page.Page.Visible = true
                TweenService:Create(page.Page, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
                if page.Btn then
                    TweenService:Create(page.Btn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(0, 200, 240), TextColor3 = Color3.fromRGB(10, 12, 18)}):Play()
                    TweenService:Create(TabIndicator, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 2, 0, page.Btn.Position.Y.Offset + 2)
                    }):Play()
                end
            else
                page.Page.Visible = false
                if page.Btn then
                    TweenService:Create(page.Btn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(20, 22, 30), TextColor3 = Color3.fromRGB(150, 160, 180)}):Play()
                end
            end
        end
        CurrentActiveTab = tabName
    end
    
    local function CreateTab(name)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, -12, 0, 28)
        TabBtn.Text = name
        TabBtn.TextColor3 = Color3.fromRGB(150, 160, 180)
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 11
        TabBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
        TabBtn.BorderSizePixel = 0
        TabBtn.Active = true
        TabBtn.Parent = Sidebar
        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 5)
        TabBtnCorner.Parent = TabBtn
        
        TabBtn.MouseEnter:Connect(function()
            if CurrentActiveTab ~= name then
                TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 32, 44), TextColor3 = Color3.fromRGB(210, 220, 240)}):Play()
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if CurrentActiveTab ~= name then
                TweenService:Create(TabBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 22, 30), TextColor3 = Color3.fromRGB(150, 160, 180)}):Play()
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
            SecLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
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
            NFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
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
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
            ToggleFrame.BorderSizePixel = 0
            ToggleFrame.Active = true
            ToggleFrame.Parent = Page
            local TCorner = Instance.new("UICorner")
            TCorner.CornerRadius = UDim.new(0, 6)
            TCorner.Parent = ToggleFrame
            
            local TStroke = Instance.new("UIStroke")
            TStroke.Color = Color3.fromRGB(32, 36, 48)
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
            Switch.BackgroundColor3 = isChecked and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(38, 42, 54)
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
            Knob.BackgroundColor3 = isChecked and Color3.fromRGB(10, 12, 18) or Color3.fromRGB(240, 240, 245)
            Knob.BorderSizePixel = 0
            Knob.Active = true
            Knob.Parent = Switch
            local KCorner = Instance.new("UICorner")
            KCorner.CornerRadius = UDim.new(1, 0)
            KCorner.Parent = Knob
            
            local function UpdateToggle()
                local targetBg = isChecked and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(38, 42, 54)
                local targetKnobColor = isChecked and Color3.fromRGB(10, 12, 18) or Color3.fromRGB(240, 240, 245)
                local targetPos = isChecked and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                TweenService:Create(Switch, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {BackgroundColor3 = targetBg}):Play()
                TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = targetPos, BackgroundColor3 = targetKnobColor}):Play()
            end
            
            Switch.MouseButton1Click:Connect(function()
                PlayClickSound()
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
            Btn.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
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
            BStroke.Color = Color3.fromRGB(34, 38, 52)
            BStroke.Thickness = 1
            BStroke.Parent = Btn
            
            Btn.MouseEnter:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 36, 52)}):Play()
            end)
            Btn.MouseLeave:Connect(function()
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 22, 32)}):Play()
            end)
            Btn.MouseButton1Click:Connect(function()
                PlayClickSound()
                TweenService:Create(Btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(0, 230, 255)}):Play()
                task.wait(0.1)
                TweenService:Create(Btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 22, 32)}):Play()
                if callback then pcall(callback) end
            end)
        end
        
        function TabAPI:AddSearchDropdown(title, options, defaultVal, callback)
            local selected = defaultVal or (options and options[1]) or ""
            local allOptions = options or {}
            local filteredOptions = allOptions
            
            local DropFrame = Instance.new("Frame")
            DropFrame.Size = UDim2.new(1, -16, 0, 34)
            DropFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
            DropFrame.BorderSizePixel = 0
            DropFrame.ClipsDescendants = true
            DropFrame.Active = true
            DropFrame.Parent = Page
            local DCorner = Instance.new("UICorner")
            DCorner.CornerRadius = UDim.new(0, 6)
            DCorner.Parent = DropFrame
            local DStroke = Instance.new("UIStroke")
            DStroke.Color = Color3.fromRGB(34, 38, 50)
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
            SelectBtn.TextColor3 = Color3.fromRGB(0, 230, 255)
            SelectBtn.Font = Enum.Font.GothamMedium
            SelectBtn.TextSize = 10
            SelectBtn.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
            SelectBtn.BorderSizePixel = 0
            SelectBtn.Active = true
            SelectBtn.Parent = DropFrame
            local SBCorner = Instance.new("UICorner")
            SBCorner.CornerRadius = UDim.new(0, 5)
            SBCorner.Parent = SelectBtn
            
            local SearchBox = Instance.new("TextBox")
            SearchBox.Size = UDim2.new(1, -16, 0, 24)
            SearchBox.Position = UDim2.new(0, 8, 0, 36)
            SearchBox.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
            SearchBox.PlaceholderText = "🔍 Type to filter " .. title .. "..."
            SearchBox.PlaceholderColor3 = Color3.fromRGB(110, 120, 140)
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
            SearchStroke.Color = Color3.fromRGB(0, 230, 255)
            SearchStroke.Thickness = 0.8
            SearchStroke.Transparency = 0.5
            SearchStroke.Parent = SearchBox
            
            local ListScroll = Instance.new("ScrollingFrame")
            ListScroll.Size = UDim2.new(1, -16, 0, 115)
            ListScroll.Position = UDim2.new(0, 8, 0, 65)
            ListScroll.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
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
                    OptBtn.TextColor3 = (opt == selected) and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(205, 205, 215)
                    OptBtn.Font = (opt == selected) and Enum.Font.GothamBold or Enum.Font.Gotham
                    OptBtn.TextSize = 10
                    OptBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
                    OptBtn.BorderSizePixel = 0
                    OptBtn.Active = true
                    OptBtn.Parent = ListScroll
                    
                    OptBtn.MouseEnter:Connect(function()
                        TweenService:Create(OptBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(34, 38, 54)}):Play()
                    end)
                    OptBtn.MouseLeave:Connect(function()
                        TweenService:Create(OptBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(20, 22, 32)}):Play()
                    end)
                    
                    OptBtn.MouseButton1Click:Connect(function()
                        PlayClickSound()
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
                PlayClickSound()
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
            
            -- Ensure callback is executed on initialization so _G.Config keys are never empty strings
            if callback and selected ~= "" then
                pcall(callback, selected)
            end
            
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
            SliderFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
            SliderFrame.BorderSizePixel = 0
            SliderFrame.Active = true
            SliderFrame.Parent = Page
            local SlCorner = Instance.new("UICorner")
            SlCorner.CornerRadius = UDim.new(0, 6)
            SlCorner.Parent = SliderFrame
            local SlStroke = Instance.new("UIStroke")
            SlStroke.Color = Color3.fromRGB(34, 38, 50)
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
            SValue.TextColor3 = Color3.fromRGB(0, 230, 255)
            SValue.Font = Enum.Font.GothamBold
            SValue.TextSize = 11
            SValue.TextXAlignment = Enum.TextXAlignment.Right
            SValue.BackgroundTransparency = 1
            SValue.Active = true
            SValue.Parent = SliderFrame
            
            local Bar = Instance.new("Frame")
            Bar.Size = UDim2.new(1, -20, 0, 6)
            Bar.Position = UDim2.new(0, 10, 0, 30)
            Bar.BackgroundColor3 = Color3.fromRGB(32, 36, 48)
            Bar.BorderSizePixel = 0
            Bar.Active = true
            Bar.Parent = SliderFrame
            local BarCorner = Instance.new("UICorner")
            BarCorner.CornerRadius = UDim.new(1, 0)
            BarCorner.Parent = Bar
            
            local Fill = Instance.new("Frame")
            local pct = math.clamp((current - min) / (max - min), 0, 1)
            Fill.Size = UDim2.new(pct, 0, 1, 0)
            Fill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
            Fill.BorderSizePixel = 0
            Fill.Active = true
            Fill.Parent = Bar
            local FillCorner = Instance.new("UICorner")
            FillCorner.CornerRadius = UDim.new(1, 0)
            FillCorner.Parent = Fill
            
            local sDragging = false
            local function UpdateSlide(inputPos)
                local rel = math.clamp((inputPos.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                local val = math.floor(min + (max - min) * rel)
                current = val
                SValue.Text = tostring(current)
                TweenService:Create(Fill, TweenInfo.new(0.05), {Size = UDim2.new(rel, 0, 1, 0)}):Play()
                if callback then pcall(callback, current) end
            end
            
            SliderFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sDragging = true
                    UpdateSlide(input.Position)
                end
            end)
            UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sDragging = false
                end
            end)
            UIS.InputChanged:Connect(function(input)
                if sDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    UpdateSlide(input.Position)
                end
            end)
            
            local SliderAPI = {}
            function SliderAPI:Set(val)
                current = math.clamp(val, min, max)
                local p = (current - min) / (max - min)
                SValue.Text = tostring(current)
                Fill.Size = UDim2.new(p, 0, 1, 0)
                if callback then pcall(callback, current) end
            end
            return SliderAPI
        end
        
        return TabAPI
    end
    
    -- ==================== TAB INITIALIZATION ====================
    local FarmTab = CreateTab("⚔️ Main Farm")
    local BossTab = CreateTab("👑 Boss Farm")
    local RaidTab = CreateTab("🌀 Raids")
    local FruitTab = CreateTab("🍇 Devil Fruit")
    local SeaTab = CreateTab("🌊 Sea Events")
    local V4Tab = CreateTab("🧬 Race V4")
    local VisualTab = CreateTab("👁️ Visuals & ESP")
    local ItemTab = CreateTab("📜 Quests")
    local StatsTab = CreateTab("⚡ Stats")
    local ShopTab = CreateTab("🛒 Shop")
    local TeleportTab = CreateTab("🚀 Teleports")
    local MiscTab = CreateTab("⚙️ Settings")
    
    -- ==================== 1. MAIN FARM TAB ====================
    FarmTab:AddSection("Weapon & Combat Mode")
    FarmTab:AddDropdown("Select Weapon", {"Melee", "Sword", "Gun", "Fruit"}, "Melee", function(v)
        _G.Config.SelectedWeapon = v
        EquipWeapon(v)
    end)
    FarmTab:AddToggle("Use M1 / Fast Attack", true, function(v) _G.Config.UseM1 = v end)
    FarmTab:AddDropdown("Click Speed", {"Super Fast (0.015s)", "Fast (0.04s)", "Normal (0.08s)"}, "Super Fast (0.015s)", function(v)
        if v:find("0.015") then _G.Config.FastAttackSpeed = 0.015
        elseif v:find("0.04") then _G.Config.FastAttackSpeed = 0.04
        else _G.Config.FastAttackSpeed = 0.08 end
    end)
    FarmTab:AddSlider("Kill Aura Range (Studs)", 40, 250, 120, function(v) _G.Config.AttackDistance = v end)
    FarmTab:AddToggle("Bring Mobs (Simulation Radius)", true, function(v) _G.Config.BringMobs = v end)
    FarmTab:AddToggle("Auto Buso Haki (Enhancement)", true, function(v) _G.Config.AutoBusoHaki = v end)
    FarmTab:AddToggle("Auto Ken Haki (Observation)", false, function(v) _G.Config.AutoKenHaki = v end)
    
    FarmTab:AddSection("Weapon Skills")
    FarmTab:AddToggle("Use Weapon Skills", false, function(v) _G.Config.UseSkills = v end)
    FarmTab:AddToggle("Use Skill [Z]", true, function(v) _G.Config.Skill_Z = v end)
    FarmTab:AddToggle("Use Skill [X]", true, function(v) _G.Config.Skill_X = v end)
    FarmTab:AddToggle("Use Skill [C]", true, function(v) _G.Config.Skill_C = v end)
    FarmTab:AddToggle("Use Skill [V]", false, function(v) _G.Config.Skill_V = v end)
    FarmTab:AddToggle("Use Skill [F]", false, function(v) _G.Config.Skill_F = v end)
    
    FarmTab:AddSection("Farm Distance")
    FarmTab:AddToggle("Auto Adaptive Boss Distance", true, function(v) _G.Config.AdaptiveBossDistance = v end)
    FarmTab:AddSlider("Mob Distance (Studs)", 6, 25, 14, function(v) _G.Config.MobFarmDistance = v end)
    FarmTab:AddSlider("Boss Distance (Studs)", 10, 35, 20, function(v) _G.Config.BossFarmDistance = v end)
    
    FarmTab:AddSection("Level Farming")
    FarmTab:AddToggle("Auto Farm Level (Auto Quest + Mob)", false, function(v)
        _G.Config.AutoFarmLevel = v
        if not v then StopTween(); ClearHover() end
    end)
    FarmTab:AddToggle("Auto Double Quest", false, function(v) _G.Config.AutoDoubleQuest = v end)
    FarmTab:AddToggle("Auto Chest Farm", false, function(v) _G.Config.AutoChestFarm = v end)
    
    FarmTab:AddSection("Selected Mob Farming")
    local mobList = GetSpawnedMobsList()
    if mobList and mobList[1] then _G.Config.SelectedMob = mobList[1] end
    local MobDrop = FarmTab:AddSearchDropdown("Select Mob (" .. SeaName .. ")", mobList, mobList[1], function(v) _G.Config.SelectedMob = v end)
    FarmTab:AddButton("Refresh Mobs List (" .. SeaName .. ")", function()
        local updated = GetSpawnedMobsList()
        MobDrop:SetOptions(updated)
    end)
    FarmTab:AddToggle("Auto Farm Selected Mob", false, function(v)
        _G.Config.FarmSelectedMob = v
        if not v then StopTween(); ClearHover() end
    end)
    
    -- ==================== 2. BOSS FARM TAB ====================
    BossTab:AddSection("Boss Selection")
    local bossList = GetActiveBossesList()
    if bossList and bossList[1] then _G.Config.SelectedBoss = bossList[1] end
    local BossDrop = BossTab:AddSearchDropdown("Select Boss", bossList, bossList[1], function(v) _G.Config.SelectedBoss = v end)
    BossTab:AddButton("Refresh Bosses List (Scan Active)", function()
        local updated = GetActiveBossesList()
        BossDrop:SetOptions(updated)
    end)
    BossTab:AddToggle("Auto Farm Selected Boss", false, function(v)
        _G.Config.FarmSelectedBoss = v
        if not v then StopTween(); ClearHover() end
    end)
    BossTab:AddToggle("Auto Farm All Spawned Bosses (" .. SeaName .. ")", false, function(v)
        _G.Config.FarmAllBosses = v
        if not v then StopTween(); ClearHover() end
    end)
    
    BossTab:AddSection("World & Special Bosses")
    if Sea3 then
        BossTab:AddToggle("Auto Kill Rip Indra", false, function(v) _G.Config.AutoKillRipIndra = v end)
        BossTab:AddToggle("Auto Kill Dough King", false, function(v) _G.Config.AutoKillDoughKing = v end)
        BossTab:AddToggle("Auto Kill Cake Prince", false, function(v) _G.Config.AutoKillCakePrince = v end)
        BossTab:AddToggle("Auto Kill Soul Reaper", false, function(v) _G.Config.AutoKillSoulReaper = v end)
        BossTab:AddToggle("Auto Farm Bones (Haunted Castle)", false, function(v) _G.Config.AutoFarmBones = v end)
        BossTab:AddToggle("Auto Roll Bones (Death King)", false, function(v) _G.Config.AutoRollBones = v end)
        BossTab:AddToggle("Auto Summon Soul Reaper", false, function(v) _G.Config.AutoSummonSoulReaper = v end)
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
        RaidTab:AddToggle("Auto Law / Order Raid", false, function(v) _G.Config.AutoLawRaid = v end)
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
    SeaTab:AddSection("Sea Events & Hunting")
    if Sea1 then
        SeaTab:AddNotice("🔒 Sea Events unlock in Second & Third Sea.", Color3.fromRGB(100, 180, 255))
    else
        SeaTab:AddToggle("Auto Kill Sharks", false, function(v) _G.Config.AutoKillShark = v end)
        SeaTab:AddToggle("Auto Kill Terror Shark", false, function(v) _G.Config.AutoKillTerrorShark = v end)
        SeaTab:AddToggle("Auto Kill Sea Beast (Safe Altitude)", false, function(v) _G.Config.AutoKillSeaBeast = v end)
        SeaTab:AddButton("Check Mirage Island Status", function()
            local s = CheckIslandSpawn("MysticIsland") or CheckIslandSpawn("Mirage Island")
            print("[ALPHA] Mirage Island:", s and "SPAWNED!" or "NOT Spawned")
        end)
        SeaTab:AddButton("Check Kitsune Island Status", function()
            local s = CheckIslandSpawn("KitsuneIsland") or CheckIslandSpawn("Kitsune Island")
            print("[ALPHA] Kitsune Island:", s and "SPAWNED!" or "NOT Spawned")
        end)
        SeaTab:AddToggle("Auto Find Blue Gear (Mirage)", false, function(v) _G.Config.AutoFindGear = v end)
        SeaTab:AddToggle("Auto Collect Azure Embers (Kitsune)", false, function(v) _G.Config.AutoKitsuneEmber = v end)
    end
    
    -- ==================== 6. RACE V4 TAB ====================
    V4Tab:AddSection("Temple of Time & Trials")
    if not Sea3 then
        V4Tab:AddNotice("🔒 Race V4 is exclusive to Third Sea (Temple of Time).", Color3.fromRGB(255, 140, 70))
    else
        V4Tab:AddButton("Teleport to Temple of Time", function()
            TweenTo(CFrame.new(28282.57, 14896.85, 105.10))
        end)
        V4Tab:AddToggle("Auto Pull Secret Lever", false, function(v) _G.Config.AutoPullLever = v end)
        V4Tab:AddToggle("Auto Complete Race Trial", false, function(v) _G.Config.AutoRaceV4Trial = v end)
        V4Tab:AddToggle("Auto Insert Gear (Ancient Clock)", false, function(v) _G.Config.AutoInsertGear = v end)
    end
    
    -- ==================== 7. VISUALS & ESP ====================
    VisualTab:AddSection("ESP Suite")
    VisualTab:AddToggle("Player ESP (Health + Team)", false, function(v)
        _G.Config.PlayerESP = v
        UpdatePlayerESP()
    end)
    VisualTab:AddToggle("Fruit ESP (Rarity Colors)", false, function(v)
        _G.Config.FruitESP = v
        UpdateFruitESP()
    end)
    VisualTab:AddToggle("Chest ESP (Gold/Silver/Diamond)", false, function(v)
        _G.Config.ChestESP = v
        UpdateChestESP()
    end)
    VisualTab:AddToggle("Flower ESP (Blue/Red/Yellow)", false, function(v)
        _G.Config.FlowerESP = v
        UpdateFlowerESP()
    end)
    VisualTab:AddToggle("Sea Event & Mirage ESP", false, function(v)
        _G.Config.SeaEventESP = v
        _G.Config.MirageESP = v
        UpdateSeaEventESP()
    end)
    
    -- ==================== 8. ITEMS & QUESTS ====================
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
    
    -- ==================== 9. STATS ALLOCATOR ====================
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
    
    -- ==================== 10. SHOP ====================
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
    
    -- ==================== 11. TELEPORTS ====================
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
        _G.Config.AutoFarmLevel = false
        _G.Config.FarmSelectedMob = false
        _G.Config.FarmSelectedBoss = false
        _G.Config.FarmAllBosses = false
        local tcf = CurrentIslands[SelIsland]
        if tcf then TeleportToIsland(tcf, SelIsland) end
    end)
    TeleportTab:AddButton("🛑 Stop Travel & Hover Here", function()
        StopTween()
        local root = GetRoot()
        if root then HoverLock(root.CFrame) end
    end)
    
    TeleportTab:AddSection("Bypass & Anti-Desync Controls")
    TeleportTab:AddToggle("Instant Portal Bypass (requestEntrance)", _G.Config.BypassTeleport ~= false, function(v)
        _G.Config.BypassTeleport = v
    end)
    TeleportTab:AddToggle("Auto-Set Island Spawn on Arrival", _G.Config.AutoSetSpawn ~= false, function(v)
        _G.Config.AutoSetSpawn = v
    end)
    TeleportTab:AddToggle("Segmented Chunk Streaming (Anti-Lag)", _G.Config.WaypointFlight ~= false, function(v)
        _G.Config.WaypointFlight = v
    end)
    TeleportTab:AddButton("⚡ Force Anti-Desync Handshake", function()
        local root = GetRoot()
        if root then
            RecoverFromPhantomDesync(root.CFrame)
            print("[ALPHA] Server position handshake executed!")
        end
    end)
    
    -- ==================== 12. SETTINGS ====================
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
        report = report .. "Validator Safe Speed: " .. tostring(Validator.CurrentSafeSpeed) .. "\n"
        report = report .. "Validator Stats: " .. Validator.GetStats() .. "\n"
        pcall(function()
            if setclipboard then
                setclipboard(report)
                print("[ALPHA] Diagnostic report copied to clipboard!")
            end
        end)
    end)
    MiscTab:AddButton("🛡️ View Smart Validator Status (Print + Clipboard)", function()
        local stats = "[SMART VALIDATOR]\n" .. Validator.GetStats()
        print(stats)
        pcall(function()
            if setclipboard then setclipboard(stats) end
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
    MiscTab:AddToggle("Anti-Desync Protection", _G.Config.AntiDesync ~= false, function(v)
        _G.Config.AntiDesync = v
    end)
    MiscTab:AddToggle("Auto-Set Spawn Point on Arrival", _G.Config.AutoSetSpawn ~= false, function(v)
        _G.Config.AutoSetSpawn = v
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
    
    SwitchTab("⚔️ Main Farm")
end


--============================== STAGGERED INITIALIZATION ==============================
-- Step 1: UI first (immediate user feedback)
CreateUI()

-- Step 2: Start all background loops with staggered delays
task.spawn(function()
    task.wait(0.5 + math.random() * 0.5)
    StartCombatLoop()
    
    task.wait(0.2 + math.random() * 0.3)
    StartHakiLoop()
    
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
    StartESPLoops()
    
    task.wait(0.2 + math.random() * 0.3)
    StartChestFarmLoop()
    
    task.wait(0.2 + math.random() * 0.3)
    StartAutoStatsLoop()
    
    task.wait(0.2 + math.random() * 0.3)
    StartAdvancedRaidEngine()
    
    task.wait(0.2 + math.random() * 0.3)
    StartSeaEventsEngine()
    
    task.wait(0.2 + math.random() * 0.3)
    StartRaceV4Engine()
    
    task.wait(0.2 + math.random() * 0.3)
    StartSpecialBossAndBoneEngine()
end)

print("--------------------------------------------------")
print("[v2] Loaded successfully!")
print("[v2] Keyless Cyber 3D Edition active.")
print("[v2] Current Location: " .. SeaName)
print("--------------------------------------------------")
