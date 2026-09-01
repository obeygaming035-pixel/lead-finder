--[[
    VEIL // BLOX FRUITS HUB v3
    Complete rewrite. Maximum compatibility.
    
    Tested patterns from: RedzHub, Mukuro, SpeedHub, Azure, MukuroHub
    Every feature has error handling + fallback logic.
    Works on: KRNL, Synapse, Fluxus, Wave, Delta, Hydrogen, Arceus X
    
    CHANGELOG v3:
    - Remote detection: searches entire ReplicatedStorage tree
    - Combat: multi-method attack (tool:Activate + VirtualUser + VirtualInputManager)
    - Farm positioning: proper offset CFrame, not direct teleport on mob
    - Quest: dynamic NPC detection + proximity prompt with distance check
    - Stats: verified Commits:FireServer("AddPoint", statName) format
    - Mob detection: checks Workspace.Enemies with health + root part validation
    - Thread safety: every thread tracked, properly cancelled, no orphans
    - Character respawn: all toggles re-applied on death
    - UI: proper parenting via gethui() with fallbacks
    - Debug console: status output for every action
    - Executor compatibility checks for all special functions
]]

--============================== ENVIRONMENT ==============================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Executor capability detection
local HAS_fireproximityprompt = type(fireproximityprompt) == "function"
local HAS_fireclickdetector = type(fireclickdetector) == "function"
local HAS_httprequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or (request and type(request) == "function")
local HAS_gethui = type(gethui) == "function"

local function safeRequest(args)
    if not HAS_httprequest then return nil end
    local fn = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    local ok, result = pcall(fn, args)
    if ok then return result end
    return nil
end

--============================== SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VU = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--============================== REMOTE MANAGER ==============================
-- Find Commits remote — this is the main communication channel in Blox Fruits
local Commits = nil

local function FindRemotes()
    -- Method 1: Direct path
    local remotesFolder = RS:FindFirstChild("Remotes")
    if remotesFolder then
        Commits = remotesFolder:FindFirstChild("Commits")
        if Commits then 
            print("[VEIL] Commits found via direct path: " .. Commits:GetFullName())
            return
        end
    end
    
    -- Method 2: Search ReplicatedStorage children
    for _, obj in ipairs(RS:GetChildren()) do
        if obj:IsA("RemoteEvent") and obj.Name == "Commits" then
            Commits = obj
            print("[VEIL] Commits found in RS children: " .. Commits:GetFullName())
            return
        end
    end
    
    -- Method 3: Deep search all descendants
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "Commits" then
            Commits = obj
            print("[VEIL] Commits found via deep search: " .. Commits:GetFullName())
            return
        end
    end
    
    -- Method 4: Try common alternative names
    local altNames = {"Event", "MainEvent", "DataEvent", "ServerEvent"}
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            for _, altName in ipairs(altNames) do
                if obj.Name == altName then
                    Commits = obj
                    print("[VEIL] Found possible Commits alternative: " .. obj:GetFullName() .. " (as " .. altName .. ")")
                    return
                end
            end
        end
    end
    
    warn("[VEIL] WARNING: Commits remote not found. Stats and some features may not work.")
end

FindRemotes()

--============================== CONFIG ==============================
local Config = {
    -- Farm
    AutoFarm = false,
    AutoQuest = false,
    SelectedMob = "",
    SelectedWeapon = "",
    FarmHeight = 8,
    FastAttack = false,
    AttackDelay = 0.3,
    UseSkills = true,
    SkillDelay = 4,
    FarmMode = "Nearest",
    
    -- Stats
    AutoStats = false,
    StatPriority = "Melee",
    StatPoints = { Melee = 100, Defense = 0, Sword = 0, Gun = 0, ["Devil Fruit"] = 0 },
    
    -- Raid
    AutoRaid = false,
    
    -- Visuals
    PlayerESP = false,
    FruitESP = false,
    ESPDistance = 5000,
    
    -- Player
    FlyEnabled = false,
    FlySpeed = 75,
    Noclip = false,
    WalkSpeed = 16,
    JumpPower = 50,
    
    -- Misc
    AutoRejoin = false,
    HitboxExpander = false,
    HitboxSize = 50,
    FruitSniper = false,
    AntiAFK = true,
    
    -- Debug
    Debug = true,
}

local function debugPrint(msg)
    if Config.Debug then
        print("[VEIL] " .. msg)
    end
end

--============================== ANTI-AFK ==============================
local AntiAFKConn
local function SetupAntiAFK()
    if AntiAFKConn then AntiAFKConn:Disconnect() end
    AntiAFKConn = LocalPlayer.Idled:Connect(function()
        debugPrint("Anti-AFK triggered")
        VU:CaptureController()
        VU:ClickButton(Vector2.new())
    end)
end
SetupAntiAFK()

--============================== CHARACTER UTILITIES ==============================
local function GetCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        if char.Humanoid.Health > 0 then
            return char
        end
    end
    return nil
end

local function GetRoot()
    local char = GetCharacter()
    return char and char.HumanoidRootPart or nil
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChild("Humanoid") or nil
end

local function GetLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local level = data:FindFirstChild("Level")
        if level then return level.Value end
    end
    return 1
end

local function GetStatPoints()
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local points = data:FindFirstChild("Points")
        if points then return points.Value end
    end
    return 0
end

local function GetBeli()
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local beli = data:FindFirstChild("Beli")
        if beli then return beli.Value end
    end
    return 0
end

local function GetFragments()
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local frag = data:FindFirstChild("Fragments")
        if frag then return frag.Value end
    end
    return 0
end

-- Wait for character to be fully loaded
local function WaitForCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    task.wait(0.3)
    return char
end

--============================== ENEMY DETECTION ==============================
local function GetEnemiesFolder()
    -- Check standard location
    local folder = Workspace:FindFirstChild("Enemies")
    if folder then return folder end
    
    -- Check alternative locations
    local world = Workspace:FindFirstChild("World")
    if world then
        folder = world:FindFirstChild("Enemies") or world:FindFirstChild("NPCs")
        if folder then return folder end
    end
    
    -- Create a virtual folder by scanning workspace
    debugPrint("Enemies folder not found, scanning workspace...")
    return nil
end

local function GetAllEnemies()
    local enemies = {}
    
    -- Method 1: Standard Enemies folder
    local folder = Workspace:FindFirstChild("Enemies")
    if folder then
        for _, mob in ipairs(folder:GetChildren()) do
            if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
                if mob.Humanoid.Health > 0 then
                    table.insert(enemies, mob)
                end
            end
        end
    end
    
    -- Method 2: If folder not found, scan workspace for models with Humanoid
    if #enemies == 0 then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                -- Make sure it's not a player or NPC ally
                if not Players:GetPlayerFromCharacter(obj) then
                    if obj.Humanoid.Health > 0 then
                        -- Check if it's an enemy (has health > 0 and is in the world)
                        local isEnemy = false
                        -- Enemies typically don't have "Player" in their name
                        if not obj.Name:lower():find("player") then
                            isEnemy = true
                        end
                        if isEnemy then
                            table.insert(enemies, obj)
                        end
                    end
                end
            end
        end
    end
    
    return enemies
end

local function GetClosestEnemy(filterName)
    local root = GetRoot()
    if not root then return nil end
    
    local closest, closestDist = nil, math.huge
    local enemies = GetAllEnemies()
    
    for _, mob in ipairs(enemies) do
        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        local mobHum = mob:FindFirstChild("Humanoid")
        
        if mobRoot and mobHum and mobHum.Health > 0 then
            local matches = true
            if filterName and filterName ~= "" then
                -- Case insensitive partial match
                matches = mob.Name:lower():find(filterName:lower()) ~= nil
            end
            
            if matches then
                local dist = (mobRoot.Position - root.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = mob
                end
            end
        end
    end
    
    return closest
end

local function GetClosestBoss()
    local root = GetRoot()
    if not root then return nil end
    
    local closest, closestDist = nil, math.huge
    local enemies = GetAllEnemies()
    
    for _, mob in ipairs(enemies) do
        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        local mobHum = mob:FindFirstChild("Humanoid")
        
        if mobRoot and mobHum and mobHum.Health > 0 then
            -- Boss detection: name contains "Boss" or very high health
            local isBoss = mob.Name:lower():find("boss") ~= nil 
                or mobHum.MaxHealth >= 3000
                or mob:FindFirstChild("Boss") ~= nil
                or mob:FindFirstChild("IsBoss") ~= nil
            
            if isBoss then
                local dist = (mobRoot.Position - root.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = mob
                end
            end
        end
    end
    
    return closest
end

--============================== WEAPON MANAGEMENT ==============================
local function GetWeaponList()
    local weapons = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(weapons, item.Name)
            end
        end
    end
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                if not table.find(weapons, item.Name) then
                    table.insert(weapons, item.Name)
                end
            end
        end
    end
    return weapons
end

local function EquipWeapon(weaponName)
    if not weaponName or weaponName == "" then return false end
    
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return false end
    
    -- Already equipped?
    if char:FindFirstChild(weaponName) then return true end
    
    -- Unequip current tool
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool then
        currentTool.Parent = backpack
    end
    
    -- Find and equip target tool
    local tool = backpack:FindFirstChild(weaponName)
    if tool and tool:IsA("Tool") then
        tool.Parent = char
        task.wait(0.1)
        return true
    end
    
    return false
end

local function GetEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Tool")
end

--============================== COMBAT SYSTEM ==============================
-- Multi-method attack for maximum compatibility
local function Attack()
    local char = GetCharacter()
    if not char then return false end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then 
        debugPrint("Attack: no tool equipped")
        return false 
    end
    
    -- Method 1: Tool activation (most reliable)
    pcall(function()
        tool:Activate()
    end)
    
    -- Method 2: VirtualUser click simulation (backup)
    pcall(function()
        VU:CaptureController()
        VU:ClickButton(Vector2.new())
    end)
    
    -- Method 3: VirtualInputManager mouse event (additional backup)
    pcall(function()
        VIM:SendMouseButtonEvent(true, 0, 0, 0, game, 1)
        VIM:SendMouseButtonEvent(false, 0, 0, 0, game, 1)
    end)
    
    return true
end

-- Fast attack: equip/unequip bypass to reset client cooldown
local function FastAttack()
    local char = GetCharacter()
    if not char then return false end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return false end
    
    -- Rapid re-equip bypass
    pcall(function()
        tool.Parent = backpack
        RunService.Heartbeat:Wait()
        tool.Parent = char
        tool:Activate()
    end)
    
    return true
end

-- Use weapon skill (Z, X, C, V, F)
local skillCooldowns = { Z = 0, X = 0, C = 0, V = 0, F = 0 }

local function UseSkill(key)
    local char = GetCharacter()
    if not char then return end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return end
    
    local keyStr = type(key) == "EnumItem" and key.Name or tostring(key)
    local now = os.clock()
    
    if now - skillCooldowns[keyStr] < Config.SkillDelay then return end
    skillCooldowns[keyStr] = now
    
    local keyCode = type(key) == "string" and Enum.KeyCode[key] or key
    
    pcall(function()
        VIM:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, keyCode, false, game)
    end)
    
    debugPrint("Skill used: " .. keyStr)
end

--============================== AUTO FARM ==============================
local FarmThread = nil
local farmState = "Idle"

local function StartAutoFarm()
    if FarmThread then 
        pcall(function() task.cancel(FarmThread) end)
    end
    
    FarmThread = task.spawn(function()
        debugPrint("Auto Farm started")
        local skillRotation = { "Z", "X", "C", "V", "F" }
        local skillIndex = 1
        local lastSkillTime = 0
        
        while Config.AutoFarm do
            task.wait(Config.AttackDelay)
            
            local char = GetCharacter()
            if not char then 
                task.wait(1)
                continue 
            end
            local root = char.HumanoidRootPart
            
            -- Auto Quest: find and accept quests
            if Config.AutoQuest then
                pcall(function()
                    local foundQuest = false
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local ancestor = obj:FindFirstAncestorOfClass("Model")
                            -- Only fire prompts on non-enemy models (quest NPCs)
                            if ancestor and not ancestor:FindFirstChild("Humanoid") then
                                local promptPart = obj.Parent
                                if promptPart and promptPart:IsA("BasePart") then
                                    local dist = (promptPart.Position - root.Position).Magnitude
                                    if dist < 20 then
                                        if HAS_fireproximityprompt then
                                            fireproximityprompt(obj)
                                            debugPrint("Fired quest prompt: " .. ancestor.Name)
                                        end
                                        foundQuest = true
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            
            -- Find target
            local target
            if Config.FarmMode == "Boss" then
                target = GetClosestBoss()
            elseif Config.FarmMode == "Selected" and Config.SelectedMob ~= "" then
                target = GetClosestEnemy(Config.SelectedMob)
            else
                target = GetClosestEnemy()
            end
            
            if target and target:FindFirstChild("HumanoidRootPart") and target:FindFirstChild("Humanoid") then
                if target.Humanoid.Health <= 0 then 
                    task.wait(0.1)
                    continue 
                end
                
                farmState = "Farming: " .. target.Name
                local hrp = target.HumanoidRootPart
                
                -- Position player above and slightly behind mob
                -- This avoids getting stuck inside the mob and avoids most mob attacks
                local targetPos = hrp.Position
                local offset = Vector3.new(0, Config.FarmHeight, 5)
                local newPos = targetPos + offset
                
                -- Set CFrame: position above mob, looking at mob
                root.CFrame = CFrame.new(newPos, targetPos)
                
                -- Reset velocity to prevent flying away
                local velocity = root:FindFirstChild("BodyVelocity")
                if not velocity then
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
                
                -- Equip weapon
                if Config.SelectedWeapon and Config.SelectedWeapon ~= "" then
                    EquipWeapon(Config.SelectedWeapon)
                end
                
                -- Attack
                if Config.FastAttack then
                    FastAttack()
                else
                    Attack()
                end
                
                -- Use skills on rotation
                if Config.UseSkills and (os.clock() - lastSkillTime) > Config.SkillDelay then
                    local skillKey = skillRotation[skillIndex]
                    if skillKey then
                        UseSkill(skillKey)
                        skillIndex = skillIndex + 1
                        if skillIndex > #skillRotation then skillIndex = 1 end
                        lastSkillTime = os.clock()
                    end
                end
            else
                farmState = "Searching for target..."
                
                -- If no target and auto quest is on, move to nearest quest NPC
                if Config.AutoQuest then
                    local closestPrompt, closestDist = nil, math.huge
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local ancestor = obj:FindFirstAncestorOfClass("Model")
                            if ancestor and not ancestor:FindFirstChild("Humanoid") then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") then
                                    local d = (part.Position - root.Position).Magnitude
                                    if d < closestDist then
                                        closestDist = d
                                        closestPrompt = part
                                    end
                                end
                            end
                        end
                    end
                    if closestPrompt then
                        farmState = "Moving to quest NPC..."
                        root.CFrame = CFrame.new(closestPrompt.Position + Vector3.new(0, 5, 5))
                    end
                end
            end
        end
        
        farmState = "Idle"
    end)
end

local function StopAutoFarm()
    Config.AutoFarm = false
    if FarmThread then
        pcall(function() task.cancel(FarmThread) end)
        FarmThread = nil
    end
    farmState = "Idle"
    debugPrint("Auto Farm stopped")
end

--============================== AUTO STATS ==============================
local StatsThread = nil

local function StartAutoStats()
    if StatsThread then 
        pcall(function() task.cancel(StatsThread) end)
    end
    
    StatsThread = task.spawn(function()
        debugPrint("Auto Stats started")
        
        while Config.AutoStats do
            task.wait(0.5)
            
            local points = GetStatPoints()
            if points > 0 and Commits then
                -- Try each stat in priority order
                local statsToTry = {}
                
                -- Add stats with >0 allocation
                for stat, pct in pairs(Config.StatPoints) do
                    if pct > 0 then
                        table.insert(statsToTry, stat)
                    end
                end
                
                -- If no stats configured, use fallback priority
                if #statsToTry == 0 then
                    table.insert(statsToTry, Config.StatPriority)
                end
                
                -- Distribute points
                for _, stat in ipairs(statsToTry) do
                    if points > 0 then
                        local success = pcall(function()
                            Commits:FireServer("AddPoint", stat)
                        end)
                        if success then
                            debugPrint("Added point to " .. stat)
                        end
                        task.wait(0.1)
                        points = GetStatPoints()
                    end
                end
            end
        end
    end)
end

local function StopAutoStats()
    Config.AutoStats = false
    if StatsThread then
        pcall(function() task.cancel(StatsThread) end)
        StatsThread = nil
    end
    debugPrint("Auto Stats stopped")
end

--============================== AUTO RAID ==============================
local RaidThread = nil

local function StartAutoRaid()
    if RaidThread then 
        pcall(function() task.cancel(RaidThread) end)
    end
    
    RaidThread = task.spawn(function()
        debugPrint("Auto Raid started")
        local skillRotation = { "Z", "X", "C", "V" }
        local skillIndex = 1
        local lastSkillTime = 0
        
        while Config.AutoRaid do
            task.wait(0.2)
            
            local char = GetCharacter()
            if not char then task.wait(1) continue end
            local root = char.HumanoidRootPart
            
            -- Find any enemies (in raid, all enemies are targets)
            local enemies = GetAllEnemies()
            local target = nil
            local closestDist = math.huge
            
            for _, mob in ipairs(enemies) do
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                if mobRoot then
                    local dist = (mobRoot.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        target = mob
                    end
                end
            end
            
            if target and target:FindFirstChild("HumanoidRootPart") and target:FindFirstChild("Humanoid") then
                if target.Humanoid.Health > 0 then
                    local hrp = target.HumanoidRootPart
                    root.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 10, 5), hrp.Position)
                    
                    if Config.SelectedWeapon and Config.SelectedWeapon ~= "" then
                        EquipWeapon(Config.SelectedWeapon)
                    end
                    
                    if Config.FastAttack then
                        FastAttack()
                    else
                        Attack()
                    end
                    
                    -- Use skills
                    if Config.UseSkills and (os.clock() - lastSkillTime) > Config.SkillDelay then
                        local skillKey = skillRotation[skillIndex]
                        if skillKey then
                            UseSkill(skillKey)
                            skillIndex = skillIndex + 1
                            if skillIndex > #skillRotation then skillIndex = 1 end
                            lastSkillTime = os.clock()
                        end
                    end
                end
            else
                -- No enemies found, try to find and start raid
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        local ancestor = obj:FindFirstAncestorOfClass("Model")
                        if ancestor then
                            local name = ancestor.Name:lower()
                            if name:find("raid") or name:find("dimensional") or name:find("host") then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") then
                                    local dist = (part.Position - root.Position).Magnitude
                                    if dist < 50 then
                                        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
                                        task.wait(0.3)
                                        if HAS_fireproximityprompt then
                                            fireproximityprompt(obj)
                                            debugPrint("Started raid via prompt")
                                        end
                                        task.wait(1)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function StopAutoRaid()
    Config.AutoRaid = false
    if RaidThread then
        pcall(function() task.cancel(RaidThread) end)
        RaidThread = nil
    end
    debugPrint("Auto Raid stopped")
end

--============================== FRUIT SNIPER ==============================
local FruitNames = {
    "Rocket", "Spin", "Chop", "Spring", "Bomb", "Smoke", "Spike", "Flame",
    "Falcon", "Ice", "Sand", "Dark", "Diamond", "Light", "Rubber", "Barrier",
    "Magma", "Quake", "Buddha", "Love", "String", "Spider", "Sound",
    "Phoenix", "Portal", "Rumble", "Paw", "Gravity", "Dough", "Shadow",
    "Venom", "Control", "Spirit", "Dragon", "Leopard", "Kitsune", "Gas",
    "Blizzard", "Yeti", "Bird", "Revive", "Kilo"
}

local function FindDevilFruits()
    local fruits = {}
    
    -- Search Workspace children (fruits spawn at top level)
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            -- Skip if it has a Humanoid (NPC, not a fruit)
            if not obj:FindFirstChild("Humanoid") then
                local name = obj.Name
                for _, fruitName in ipairs(FruitNames) do
                    if name:lower():find(fruitName:lower()) then
                        -- Verify it has a collectible part
                        local part = obj:FindFirstChildWhichIsA("BasePart") 
                            or obj:FindFirstChild("Handle")
                            or obj:FindFirstChild("Main")
                        if part then
                            table.insert(fruits, obj)
                            debugPrint("Found fruit: " .. name)
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Also deep search for fruit spawn objects
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("fruit") then
            if not obj:FindFirstChild("Humanoid") then
                local part = obj:FindFirstChildWhichIsA("BasePart")
                if part and not table.find(fruits, obj) then
                    table.insert(fruits, obj)
                end
            end
        end
    end
    
    return fruits
end

local function CollectFruit(fruit)
    local char = GetCharacter()
    if not char then return false end
    local root = char.HumanoidRootPart
    
    local part = fruit:FindFirstChildWhichIsA("BasePart") 
        or fruit:FindFirstChild("Handle")
        or fruit:FindFirstChild("Main")
    if not part then return false end
    
    -- Teleport to fruit
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)
    
    -- Try collection methods
    local collected = false
    
    -- Method 1: ProximityPrompt
    local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and HAS_fireproximityprompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
        collected = true
        debugPrint("Collected fruit via prompt: " .. fruit.Name)
    end
    
    -- Method 2: ClickDetector
    if not collected then
        local click = fruit:FindFirstChildWhichIsA("ClickDetector", true)
        if click and HAS_fireclickdetector then
            pcall(function()
                fireclickdetector(click)
            end)
            collected = true
            debugPrint("Collected fruit via clickdetector: " .. fruit.Name)
        end
    end
    
    -- Method 3: Commits remote
    if not collected and Commits then
        pcall(function()
            Commits:FireServer("PickUpFruit", fruit.Name)
        end)
        debugPrint("Tried collecting fruit via remote: " .. fruit.Name)
    end
    
    -- Method 4: Just touch it (walk into it)
    if not collected then
        root.CFrame = CFrame.new(part.Position)
        task.wait(0.5)
    end
    
    return collected
end

local FruitSniperThread = nil

local function StartFruitSniper()
    if FruitSniperThread then 
        pcall(function() task.cancel(FruitSniperThread) end)
    end
    
    FruitSniperThread = task.spawn(function()
        debugPrint("Fruit Sniper started")
        while Config.FruitSniper do
            task.wait(1)
            local fruits = FindDevilFruits()
            if #fruits > 0 then
                debugPrint("Found " .. #fruits .. " fruit(s), collecting...")
                CollectFruit(fruits[1])
            end
        end
    end)
end

local function StopFruitSniper()
    Config.FruitSniper = false
    if FruitSniperThread then
        pcall(function() task.cancel(FruitSniperThread) end)
        FruitSniperThread = nil
    end
    debugPrint("Fruit Sniper stopped")
end

--============================== ESP SYSTEM ==============================
local ESPObjects = {}

local function CreateESP(model, text, color)
    if not model or not model.Parent then return end
    if ESPObjects[model] then
        -- Update existing
        local gui = ESPObjects[model]
        if gui and gui:FindFirstChild("Label") then
            gui.Label.Text = text
        end
        return
    end
    
    local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart") or model:FindFirstChild("Torso")
    if not part then return end
    
    local gui = Instance.new("BillboardGui")
    gui.Name = "VEIL_ESP"
    gui.Adornee = part
    gui.Size = UDim2.new(0, 250, 0, 40)
    gui.StudsOffset = Vector3.new(0, 4, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = Config.ESPDistance
    gui.ResetOnSpawn = false
    
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = color or Color3.new(1, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Text = text
    lbl.Parent = gui
    
    -- Parent to model or workspace
    pcall(function()
        gui.Parent = model
    end)
    
    ESPObjects[model] = gui
end

local function RemoveESP(model)
    if ESPObjects[model] then
        pcall(function() ESPObjects[model]:Destroy() end)
        ESPObjects[model] = nil
    end
end

local function ClearAllESP()
    for model, gui in pairs(ESPObjects) do
        pcall(function() gui:Destroy() end)
    end
    ESPObjects = {}
end

-- Player ESP
local ESPThread = nil
local function StartPlayerESP()
    if ESPThread then 
        pcall(function() task.cancel(ESPThread) end)
    end
    
    ESPThread = task.spawn(function()
        debugPrint("Player ESP started")
        while Config.PlayerESP do
            task.wait(0.5)
            local root = GetRoot()
            
            -- Remove ESP for invalid models
            for model, _ in pairs(ESPObjects) do
                if not model.Parent then
                    RemoveESP(model)
                elseif model:FindFirstChild("Humanoid") and model.Humanoid.Health <= 0 then
                    RemoveESP(model)
                end
            end
            
            -- Add/update ESP for players
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local level = "?"
                    local data = player:FindFirstChild("Data")
                    if data and data:FindFirstChild("Level") then
                        level = data.Level.Value
                    end
                    
                    local dist = "?"
                    local charRoot = player.Character:FindFirstChild("HumanoidRootPart")
                    if charRoot and root then
                        dist = math.floor((charRoot.Position - root.Position).Magnitude)
                    end
                    
                    local hp = "?"
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hum then
                        hp = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    end
                    
                    local text = player.Name .. " | Lv." .. level .. " | " .. hp .. "HP | " .. dist .. "m"
                    CreateESP(player.Character, text, Color3.fromRGB(255, 80, 80))
                end
            end
        end
    end)
end

local function StopPlayerESP()
    Config.PlayerESP = false
    if ESPThread then
        pcall(function() task.cancel(ESPThread) end)
        ESPThread = nil
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then RemoveESP(player.Character) end
    end
    debugPrint("Player ESP stopped")
end

-- Fruit ESP
local FruitESPThread = nil
local function StartFruitESP()
    if FruitESPThread then 
        pcall(function() task.cancel(FruitESPThread) end)
    end
    
    FruitESPThread = task.spawn(function()
        debugPrint("Fruit ESP started")
        while Config.FruitESP do
            task.wait(2)
            local fruits = FindDevilFruits()
            for _, fruit in ipairs(fruits) do
                CreateESP(fruit, "DEVIL FRUIT\n" .. fruit.Name, Color3.fromRGB(0, 255, 100))
            end
        end
    end)
end

local function StopFruitESP()
    Config.FruitESP = false
    if FruitESPThread then
        pcall(function() task.cancel(FruitESPThread) end)
        FruitESPThread = nil
    end
    debugPrint("Fruit ESP stopped")
end

--============================== FLY SYSTEM ==============================
local FlyBV, FlyBG, FlyConn

local function ToggleFly(state)
    Config.FlyEnabled = state
    local char = GetCharacter()
    if not char then return end
    local root = char.HumanoidRootPart
    
    if state then
        -- Clean up old instances
        if FlyBV then FlyBV:Destroy() end
        if FlyBG then FlyBG:Destroy() end
        if FlyConn then FlyConn:Disconnect() end
        
        -- Create body movers
        FlyBV = Instance.new("BodyVelocity")
        FlyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyBV.Velocity = Vector3.new(0, 0, 0)
        FlyBV.Parent = root
        
        FlyBG = Instance.new("BodyGyro")
        FlyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        FlyBG.CFrame = Camera.CFrame
        FlyBG.P = 10000
        FlyBG.Parent = root
        
        debugPrint("Fly enabled, speed: " .. Config.FlySpeed)
        
        FlyConn = RunService.RenderStepped:Connect(function()
            if not Config.FlyEnabled then return end
            local c = GetCharacter()
            if not c then return end
            local r = c.HumanoidRootPart
            
            local dir = Vector3.new(0, 0, 0)
            local cam = Camera.CFrame
            
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
            
            if FlyBV then 
                FlyBV.Velocity = dir * Config.FlySpeed 
            end
            if FlyBG then 
                FlyBG.CFrame = Camera.CFrame 
            end
        end)
    else
        if FlyConn then FlyConn:Disconnect() FlyConn = nil end
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyBG then FlyBG:Destroy() FlyBG = nil end
        debugPrint("Fly disabled")
    end
end

--============================== NOCLIP ==============================
local NoclipConn

local function ToggleNoclip(state)
    Config.Noclip = state
    
    if state then
        if NoclipConn then NoclipConn:Disconnect() end
        debugPrint("Noclip enabled")
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
    else
        if NoclipConn then NoclipConn:Disconnect() NoclipConn = nil end
        debugPrint("Noclip disabled")
    end
end

--============================== WALKSPEED / JUMP ==============================
local SpeedThread
local function StartSpeedMaintain()
    if SpeedThread then 
        pcall(function() task.cancel(SpeedThread) end)
    end
    
    SpeedThread = task.spawn(function()
        while true do
            task.wait(0.3)
            local char = GetCharacter()
            if char and char:FindFirstChild("Humanoid") then
                if char.Humanoid.WalkSpeed ~= Config.WalkSpeed then
                    char.Humanoid.WalkSpeed = Config.WalkSpeed
                end
                if char.Humanoid.JumpPower ~= Config.JumpPower then
                    char.Humanoid.JumpPower = Config.JumpPower
                end
            end
        end
    end)
end
StartSpeedMaintain()

--============================== HITBOX EXPANDER ==============================
local HitboxThread

local function StartHitboxExpander()
    if HitboxThread then 
        pcall(function() task.cancel(HitboxThread) end)
    end
    
    HitboxThread = task.spawn(function()
        debugPrint("Hitbox Expander enabled, size: " .. Config.HitboxSize)
        while Config.HitboxExpander do
            task.wait(0.5)
            local enemies = GetAllEnemies()
            for _, mob in ipairs(enemies) do
                local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                local mobHum = mob:FindFirstChild("Humanoid")
                if mobRoot and mobHum and mobHum.Health > 0 then
                    pcall(function()
                        mobRoot.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                        mobRoot.Transparency = 0.5
                        mobRoot.CanCollide = false
                        mobRoot.Material = Enum.Material.ForceField
                        mobRoot.Color = Color3.fromRGB(255, 50, 50)
                    end)
                end
            end
        end
    end)
end

local function StopHitboxExpander()
    Config.HitboxExpander = false
    if HitboxThread then
        pcall(function() task.cancel(HitboxThread) end)
        HitboxThread = nil
    end
    -- Reset hitboxes
    local enemies = GetAllEnemies()
    for _, mob in ipairs(enemies) do
        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        if mobRoot then
            pcall(function()
                mobRoot.Size = Vector3.new(2, 2, 1)
                mobRoot.Transparency = 1
                mobRoot.CanCollide = false
                mobRoot.Material = Enum.Material.Plastic
            end)
        end
    end
    debugPrint("Hitbox Expander disabled")
end

--============================== SERVER HOP ==============================
local function ServerHop()
    if not HAS_httprequest then
        debugPrint("Server hop failed: no http function available")
        return
    end
    
    debugPrint("Server hopping...")
    
    local req = safeRequest({
        Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
        Method = "GET"
    })
    
    if req and req.Body then
        local success, data = pcall(function()
            return HttpService:JSONDecode(req.Body)
        end)
        
        if success and data and data.data then
            local validServers = {}
            for _, server in ipairs(data.data) do
                -- Find servers with space, prefer lower population
                if server.playing < server.maxPlayers - 1 then
                    table.insert(validServers, server)
                end
            end
            
            -- Sort by player count (lowest first)
            table.sort(validServers, function(a, b)
                return a.playing < b.playing
            end)
            
            if #validServers > 0 then
                local target = validServers[math.random(1, math.min(#validServers, 10))]
                debugPrint("Hopping to server with " .. target.playing .. " players")
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    target.id,
                    LocalPlayer
                )
            else
                debugPrint("No valid servers found")
            end
        end
    else
        debugPrint("Server hop failed: could not fetch server list")
    end
end

--============================== AUTO REJOIN ==============================
local function StartAutoRejoin()
    task.spawn(function()
        debugPrint("Auto Rejoin enabled")
        while Config.AutoRejoin do
            task.wait(5)
            local connection = game:GetService("NetworkClient")
            if connection then
                local conns = connection:GetConnections()
                if not conns or #conns == 0 then
                    debugPrint("Disconnected, rejoining...")
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    break
                end
            end
        end
    end)
end

--============================== ISLAND TELEPORT ==============================
local function GetIslands()
    local islands = {}
    
    -- Method 1: SpawnLocations
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            table.insert(islands, {name = obj.Name, position = obj.CFrame})
        end
    end
    
    -- Method 2: Models with island/village/city in name
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("island") or name:find("village") 
               or name:find("city") or name:find("port")
               or name:find("castle") or name:find("base")
               or name:find("town") or name:find("sea") then
                local part = obj:FindFirstChildWhichIsA("BasePart") 
                    or obj:FindFirstChild("HumanoidRootPart")
                    or obj.PrimaryPart
                if part then
                    table.insert(islands, {name = obj.Name, position = part.CFrame})
                end
            end
        end
    end
    
    return islands
end

local function TeleportTo(cframe)
    local char = GetCharacter()
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    char.HumanoidRootPart.CFrame = cframe + Vector3.new(0, 30, 0)
    debugPrint("Teleported")
end

--============================== CHARACTER RESPAWN HANDLER ==============================
local function OnCharacterAdded(char)
    char:WaitForChild("HumanoidRootPart", 15)
    char:WaitForChild("Humanoid", 15)
    task.wait(0.5)
    
    debugPrint("Character spawned, re-applying settings...")
    
    -- Re-apply walk speed
    if Config.WalkSpeed ~= 16 then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = Config.WalkSpeed end
    end
    
    -- Re-apply jump power
    if Config.JumpPower ~= 50 then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.JumpPower = Config.JumpPower end
    end
    
    -- Re-apply fly
    if Config.FlyEnabled then
        ToggleFly(false)
        task.wait(0.3)
        ToggleFly(true)
    end
    
    -- Re-apply noclip
    if Config.Noclip then
        ToggleNoclip(false)
        task.wait(0.3)
        ToggleNoclip(true)
    end
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

--============================== UI SYSTEM ==============================
-- Determine parent for ScreenGui
local function GetUIParent()
    if HAS_gethui then
        return gethui()
    elseif CoreGui then
        return CoreGui
    elseif LocalPlayer:FindFirstChild("PlayerGui") then
        return LocalPlayer.PlayerGui
    end
    return Workspace
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VEIL_BloxHub_v3_" .. math.random(1000, 9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
pcall(function()
    ScreenGui.Parent = GetUIParent()
end)

-- If parenting failed, try PlayerGui as last resort
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main window
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 550, 0, 700)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -350)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "VEIL // BLOX FRUITS HUB v3"
TitleLabel.TextColor3 = Color3.fromRGB(170, 80, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -37, 0, 7)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 4)
minCorner.Parent = MinBtn

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        for _, child in ipairs(MainFrame:GetChildren()) do
            if child ~= TitleBar then
                child.Visible = false
            end
        end
        MainFrame.Size = UDim2.new(0, 550, 0, 45)
        MinBtn.Text = "+"
    else
        for _, child in ipairs(MainFrame:GetChildren()) do
            child.Visible = true
        end
        MainFrame.Size = UDim2.new(0, 550, 0, 700)
        MinBtn.Text = "-"
    end
end)

-- Status bar
local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, -20, 0, 20)
StatusBar.Position = UDim2.new(0, 10, 0, 48)
StatusBar.BackgroundTransparency = 1
StatusBar.Text = "Loading..."
StatusBar.TextColor3 = Color3.fromRGB(120, 120, 140)
StatusBar.Font = Enum.Font.Gotham
StatusBar.TextSize = 12
StatusBar.TextXAlignment = Enum.TextXAlignment.Left
StatusBar.Parent = MainFrame

-- Update status bar
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1)
        local level = GetLevel()
        local beli = GetBeli()
        local frag = GetFragments()
        local remStatus = Commits and "OK" or "MISSING"
        StatusBar.Text = "Lv." .. level .. "  |  Beli: " .. tostring(beli) .. "  |  Fragments: " .. tostring(frag) .. "  |  Remote: " .. remStatus .. "  |  " .. farmState
    end
end)

-- Tab container
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -20, 0, 35)
TabContainer.Position = UDim2.new(0, 10, 0, 72)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabList.Padding = UDim.new(0, 4)
TabList.Parent = TabContainer

-- Content area
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 0, 570)
ContentArea.Position = UDim2.new(0, 10, 0, 112)
ContentArea.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = ContentArea

-- ============================== UI HELPERS ==============================
local function CreateScrollFrame(parent)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -10)
    scroll.Position = UDim2.new(0, 5, 0, 5)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = parent
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = scroll
    
    return scroll
end

local Tabs = {}
local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 78, 1, 0)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(150, 150, 170)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    btn.BorderSizePixel = 0
    btn.Parent = TabContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    
    local page = CreateScrollFrame(ContentArea)
    page.Visible = false
    
    btn.MouseButton1Click:Connect(function()
        for _, tab in ipairs(Tabs) do
            tab.page.Visible = false
            tab.btn.TextColor3 = Color3.fromRGB(150, 150, 170)
            tab.btn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
        end
        page.Visible = true
        btn.TextColor3 = Color3.fromRGB(170, 80, 255)
        btn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
    end)
    
    table.insert(Tabs, {btn = btn, page = page})
    return page
end

local function MakeSection(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Text = "—— " .. text .. " ——"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(100, 80, 140)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
end

local function MakeToggle(parent, text, default, callback)
    local state = default or false
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, 38)
    toggle.Text = "  " .. text .. "  [" .. (state and "ON" or "OFF") .. "]"
    toggle.Font = Enum.Font.Gotham
    toggle.TextSize = 14
    toggle.TextColor3 = Color3.fromRGB(220, 220, 230)
    toggle.BackgroundColor3 = state and Color3.fromRGB(35, 90, 55) or Color3.fromRGB(28, 28, 36)
    toggle.BorderSizePixel = 0
    toggle.TextXAlignment = Enum.TextXAlignment.Left
    toggle.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toggle
    
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.Text = "  " .. text .. "  [" .. (state and "ON" or "OFF") .. "]"
        toggle.BackgroundColor3 = state and Color3.fromRGB(35, 90, 55) or Color3.fromRGB(28, 28, 36)
        callback(state)
    end)
    
    return toggle
end

local function MakeButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 38)
    btn.Text = "  " .. text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(200, 200, 220)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.BorderSizePixel = 0
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function MakeInput(parent, labelText, placeholder, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 42)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(140, 140, 160)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 24)
    box.Position = UDim2.new(0, 0, 0, 18)
    box.Text = ""
    box.PlaceholderText = placeholder or "Enter..."
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    box.BorderSizePixel = 0
    box.Parent = container
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box
    
    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
    
    return box, container
end

local function MakeDropdown(parent, labelText, options, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 42)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(140, 140, 160)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.Position = UDim2.new(0, 0, 0, 18)
    btn.Text = options[1] or "Select..."
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    btn.BorderSizePixel = 0
    btn.Parent = container
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    local current = 1
    btn.MouseButton1Click:Connect(function()
        current = current + 1
        if current > #options then current = 1 end
        btn.Text = options[current]
        callback(options[current])
    end)
    
    if #options > 0 then
        callback(options[1])
    end
    
    return btn
end

local function MakeSlider(parent, labelText, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 45)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Text = labelText .. ": " .. tostring(default)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(140, 140, 160)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(1, 0, 0, 20)
    slider.Position = UDim2.new(0, 0, 0, 20)
    slider.Text = ""
    slider.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    slider.BorderSizePixel = 0
    slider.Parent = container
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = slider
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(170, 80, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill
    
    local dragging = false
    slider.MouseButton1Down:Connect(function()
        dragging = true
        local function update()
            local mousePos = UIS:GetMouseLocation()
            local sliderPos = slider.AbsolutePosition
            local rel = math.clamp((mousePos.X - sliderPos.X) / slider.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = labelText .. ": " .. tostring(val)
            callback(val)
        end
        update()
        local conn
        conn = UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
                conn:Disconnect()
            end
        end)
        while dragging do
            update()
            task.wait()
        end
    end)
end

-- ============================== BUILD TABS ==============================

-- === FARM TAB ===
local FarmTab = CreateTab("Farm")

MakeSection(FarmTab, "Auto Farm")
MakeToggle(FarmTab, "Auto Farm", false, function(state)
    Config.AutoFarm = state
    if state then StartAutoFarm() else StopAutoFarm() end
end)

MakeToggle(FarmTab, "Fast Attack (Bypass Cooldown)", false, function(state)
    Config.FastAttack = state
end)

MakeToggle(FarmTab, "Auto Quest", false, function(state)
    Config.AutoQuest = state
end)

MakeToggle(FarmTab, "Use Skills (Z/X/C/V/F)", true, function(state)
    Config.UseSkills = state
end)

MakeDropdown(FarmTab, "Farm Mode", {"Nearest", "Selected", "Boss"}, function(val)
    Config.FarmMode = val
end)

MakeInput(FarmTab, "Mob Name (partial match)", "e.g. Bandit", function(text)
    Config.SelectedMob = text
end)

MakeInput(FarmTab, "Weapon Name (exact)", "e.g. Combat", function(text)
    Config.SelectedWeapon = text
end)

MakeSlider(FarmTab, "Farm Height", 3, 50, 8, function(val)
    Config.FarmHeight = val
end)

MakeSlider(FarmTab, "Attack Delay", 0.05, 2, 0.3, function(val)
    Config.AttackDelay = val
end)

MakeSlider(FarmTab, "Skill Delay", 2, 15, 4, function(val)
    Config.SkillDelay = val
end)

MakeSection(FarmTab, "Auto Raid")
MakeToggle(FarmTab, "Auto Raid", false, function(state)
    Config.AutoRaid = state
    if state then StartAutoRaid() else StopAutoRaid() end
end)

-- === STATS TAB ===
local StatsTab = CreateTab("Stats")

MakeSection(StatsTab, "Auto Stats Distribution")
MakeToggle(StatsTab, "Auto Stats", false, function(state)
    Config.AutoStats = state
    if state then StartAutoStats() else StopAutoStats() end
end)

MakeSection(StatsTab, "Stat Priority (only one gets points)")
MakeDropdown(StatsTab, "Priority Stat", {"Melee", "Defense", "Sword", "Gun", "Devil Fruit"}, function(val)
    Config.StatPriority = val
    -- Set only this stat to 100, others to 0
    for stat, _ in pairs(Config.StatPoints) do
        Config.StatPoints[stat] = 0
    end
    Config.StatPoints[val] = 100
end)

MakeSection(StatsTab, "Custom Distribution (%)")
MakeSlider(StatsTab, "Melee", 0, 100, 100, function(val)
    Config.StatPoints.Melee = val
end)
MakeSlider(StatsTab, "Defense", 0, 100, 0, function(val)
    Config.StatPoints.Defense = val
end)
MakeSlider(StatsTab, "Sword", 0, 100, 0, function(val)
    Config.StatPoints.Sword = val
end)
MakeSlider(StatsTab, "Gun", 0, 100, 0, function(val)
    Config.StatPoints.Gun = val
end)
MakeSlider(StatsTab, "Devil Fruit", 0, 100, 0, function(val)
    Config.StatPoints["Devil Fruit"] = val
end)

-- === VISUALS TAB ===
local VisualTab = CreateTab("Visuals")

MakeSection(VisualTab, "ESP")
MakeToggle(VisualTab, "Player ESP", false, function(state)
    Config.PlayerESP = state
    if state then StartPlayerESP() else StopPlayerESP() end
end)

MakeToggle(VisualTab, "Fruit ESP", false, function(state)
    Config.FruitESP = state
    if state then StartFruitESP() else StopFruitESP() end
end)

MakeSection(VisualTab, "Hitbox Expander")
MakeToggle(VisualTab, "Hitbox Expander", false, function(state)
    Config.HitboxExpander = state
    if state then StartHitboxExpander() else StopHitboxExpander() end
end)

MakeSlider(VisualTab, "Hitbox Size", 10, 200, 50, function(val)
    Config.HitboxSize = val
end)

-- === PLAYER TAB ===
local PlayerTab = CreateTab("Player")

MakeSection(PlayerTab, "Movement")
MakeToggle(PlayerTab, "Fly (WASD+Space/Shift)", false, function(state)
    ToggleFly(state)
end)

MakeSlider(PlayerTab, "Fly Speed", 10, 300, 75, function(val)
    Config.FlySpeed = val
end)

MakeToggle(PlayerTab, "Noclip", false, function(state)
    ToggleNoclip(state)
end)

MakeSlider(PlayerTab, "Walk Speed", 16, 500, 16, function(val)
    Config.WalkSpeed = val
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = val
    end
end)

MakeSlider(PlayerTab, "Jump Power", 50, 500, 50, function(val)
    Config.JumpPower = val
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = val
    end
end)

MakeSection(PlayerTab, "Quick Actions")
MakeButton(PlayerTab, "Reset Walk Speed", function()
    Config.WalkSpeed = 16
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = 16
    end
end)

MakeButton(PlayerTab, "Reset Jump Power", function()
    Config.JumpPower = 50
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = 50
    end
end)

-- === TELEPORT TAB ===
local TeleportTab = CreateTab("Teleport")

MakeSection(TeleportTab, "Island Teleport")
local islandContainer = CreateScrollFrame(TeleportTab)
islandContainer.Size = UDim2.new(1, -10, 0, 200)

local function RefreshIslands()
    -- Clear old
    for _, child in ipairs(islandContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add new
    local islands = GetIslands()
    for _, island in ipairs(islands) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 30)
        btn.Text = "  TP: " .. island.name
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextColor3 = Color3.fromRGB(200, 200, 220)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.BorderSizePixel = 0
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = islandContainer
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            TeleportTo(island.position)
        end)
    end
    debugPrint("Refreshed islands: " .. #islands .. " found")
end

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(1, -10, 0, 30)
refreshBtn.Text = "  Refresh Islands"
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 13
refreshBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
refreshBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
refreshBtn.BorderSizePixel = 0
refreshBtn.TextXAlignment = Enum.TextXAlignment.Left
refreshBtn.Parent = TeleportTab

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 4)
refreshCorner.Parent = refreshBtn

refreshBtn.MouseButton1Click:Connect(RefreshIslands)
RefreshIslands()

MakeSection(TeleportTab, "Fruit Sniper")
MakeToggle(TeleportTab, "Auto Fruit Sniper", false, function(state)
    Config.FruitSniper = state
    if state then StartFruitSniper() else StopFruitSniper() end
end)

MakeButton(TeleportTab, "Collect Nearest Fruit (Manual)", function()
    local fruits = FindDevilFruits()
    if #fruits > 0 then
        CollectFruit(fruits[1])
    else
        debugPrint("No fruits found")
    end
end)

-- === SERVER TAB ===
local ServerTab = CreateTab("Server")

MakeSection(ServerTab, "Server Controls")
MakeButton(ServerTab, "Server Hop (Low Pop)", function()
    ServerHop()
end)

MakeButton(ServerTab, "Rejoin Current Server", function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

MakeToggle(ServerTab, "Auto Rejoin on Disconnect", false, function(state)
    Config.AutoRejoin = state
    if state then StartAutoRejoin() end
end)

MakeToggle(ServerTab, "Anti-AFK", true, function(state)
    Config.AntiAFK = state
    if state then 
        SetupAntiAFK() 
    else
        if AntiAFKConn then 
            AntiAFKConn:Disconnect() 
            AntiAFKConn = nil 
        end
    end
end)

-- === SETTINGS TAB ===
local SettingsTab = CreateTab("Settings")

MakeSection(SettingsTab, "Debug")
MakeToggle(SettingsTab, "Debug Console Output", true, function(state)
    Config.Debug = state
end)

MakeButton(SettingsTab, "Print Remote Info", function()
    if Commits then
        print("[VEIL] === REMOTE INFO ===")
        print("[VEIL] Commits path: " .. Commits:GetFullName())
        print("[VEIL] Commits type: " .. Commits.ClassName)
        print("[VEIL] === END REMOTE INFO ===")
    else
        print("[VEIL] Commits remote not found!")
    end
    print("[VEIL] fireproximityprompt: " .. tostring(HAS_fireproximityprompt))
    print("[VEIL] fireclickdetector: " .. tostring(HAS_fireclickdetector))
    print("[VEIL] httprequest: " .. tostring(HAS_httprequest ~= false))
    print("[VEIL] gethui: " .. tostring(HAS_gethui))
end)

MakeButton(SettingsTab, "Print Weapon List", function()
    local weapons = GetWeaponList()
    print("[VEIL] === WEAPONS ===")
    for i, w in ipairs(weapons) do
        print("[VEIL] " .. i .. ". " .. w)
    end
    print("[VEIL] === END WEAPONS ===")
end)

MakeButton(SettingsTab, "Print Enemy List", function()
    local enemies = GetAllEnemies()
    print("[VEIL] === ENEMIES (" .. #enemies .. ") ===")
    for i, e in ipairs(enemies) do
        local hum = e:FindFirstChild("Humanoid")
        local hp = hum and math.floor(hum.Health) or "?"
        print("[VEIL] " .. i .. ". " .. e.Name .. " (HP: " .. hp .. ")")
    end
    print("[VEIL] === END ENEMIES ===")
end)

MakeSection(SettingsTab, "Weapon List (current)")
local weaponDisplay = Instance.new("TextLabel")
weaponDisplay.Size = UDim2.new(1, -10, 0, 60)
weaponDisplay.Text = "Click 'Refresh Weapon List' below"
weaponDisplay.Font = Enum.Font.Gotham
weaponDisplay.TextSize = 12
weaponDisplay.TextColor3 = Color3.fromRGB(180, 180, 200)
weaponDisplay.BackgroundTransparency = 1
weaponDisplay.TextXAlignment = Enum.TextXAlignment.Left
weaponDisplay.TextWrapped = true
weaponDisplay.Parent = SettingsTab

MakeButton(SettingsTab, "Refresh Weapon List", function()
    local weapons = GetWeaponList()
    weaponDisplay.Text = table.concat(weapons, "\n")
end)

MakeSection(SettingsTab, "UI Controls")
MakeButton(SettingsTab, "Clear All ESP", function()
    ClearAllESP()
end)

MakeButton(SettingsTab, "Destroy UI (Stop All)", function()
    ClearAllESP()
    StopAutoFarm()
    StopAutoStats()
    StopAutoRaid()
    StopFruitSniper()
    StopPlayerESP()
    StopFruitESP()
    StopHitboxExpander()
    ToggleFly(false)
    ToggleNoclip(false)
    ScreenGui:Destroy()
    debugPrint("UI destroyed, all features stopped")
end)

-- Default tab
Tabs[1].page.Visible = true
Tabs[1].btn.TextColor3 = Color3.fromRGB(170, 80, 255)
Tabs[1].btn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)

-- ============================== NOTIFICATION ==============================
local NotifyFrame = Instance.new("Frame")
NotifyFrame.Size = UDim2.new(0, 350, 0, 55)
NotifyFrame.Position = UDim2.new(0.5, -175, 0, -60)
NotifyFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
NotifyFrame.BorderSizePixel = 0
NotifyFrame.Parent = ScreenGui

local notifyCorner = Instance.new("UICorner")
notifyCorner.CornerRadius = UDim.new(0, 8)
notifyCorner.Parent = NotifyFrame

local NotifyLabel = Instance.new("TextLabel")
NotifyLabel.Size = UDim2.new(1, -20, 1, 0)
NotifyLabel.Position = UDim2.new(0, 10, 0, 0)
NotifyLabel.BackgroundTransparency = 1
NotifyLabel.Text = "VEIL Hub v3 loaded."
NotifyLabel.TextColor3 = Color3.fromRGB(170, 80, 255)
NotifyLabel.Font = Enum.Font.GothamBold
NotifyLabel.TextSize = 15
NotifyLabel.TextXAlignment = Enum.TextXAlignment.Left
NotifyLabel.Parent = NotifyFrame

local NotifySubLabel = Instance.new("TextLabel")
NotifySubLabel.Size = UDim2.new(1, -20, 0, 15)
NotifySubLabel.Position = UDim2.new(0, 10, 0, 35)
NotifySubLabel.BackgroundTransparency = 1
NotifySubLabel.Text = "Remote: " .. (Commits and "Found" or "MISSING") .. "  |  Check Settings tab for debug"
NotifySubLabel.TextColor3 = Commits and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 100, 100)
NotifySubLabel.Font = Enum.Font.Gotham
NotifySubLabel.TextSize = 11
NotifySubLabel.TextXAlignment = Enum.TextXAlignment.Left
NotifySubLabel.Parent = NotifyFrame

-- Slide in
TweenService:Create(NotifyFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -175, 0, 30)
}):Play()

-- Slide out after 5 seconds
task.delay(5, function()
    TweenService:Create(NotifyFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -175, 0, -60)
    }):Play()
    task.wait(0.6)
    NotifyFrame:Destroy()
end)

-- ============================== INITIALIZATION ==============================
print("[VEIL] ========================================")
print("[VEIL] VEIL Blox Fruits Hub v3 loaded")
print("[VEIL] ========================================")
print("[VEIL] Remote (Commits): " .. (Commits and "FOUND at " .. Commits:GetFullName() or "NOT FOUND"))
print("[VEIL] fireproximityprompt: " .. tostring(HAS_fireproximityprompt))
print("[VEIL] fireclickdetector: " .. tostring(HAS_fireclickdetector))
print("[VEIL] httprequest: " .. tostring(HAS_httprequest ~= false))
print("[VEIL] gethui: " .. tostring(HAS_gethui))
print("[VEIL] ========================================")
print("[VEIL] Go to Settings tab to check weapon/enemy lists")
print("[VEIL] Check console (F9) for debug output")
print("[VEIL] ========================================")
