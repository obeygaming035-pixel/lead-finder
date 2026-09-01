--[[
    VEIL // BLOX FRUITS HUB v2
    Rebuilt from ground up. Every feature tested against known working patterns.
    
    Executor: KRNL / Synapse / Fluxus / Wave / Delta / Arceus X
    
    FIXED IN v2:
    - Remote path corrected to ReplicatedStorage.Remotes.Commits
    - Attack uses equip/unequip + Activate pattern (bypasses client cooldown)
    - Mob detection scans Workspace.Enemies properly with health checks
    - Quest system fires proximity prompts dynamically
    - Stats uses correct Commits:FireServer("AddPoint", stat) format
    - Fly/Noclip properly manage connections and clean up on disable
    - ESP doesn't duplicate BillboardGuis every frame
    - Server hop uses correct executor request function
    - Added: Fruit Sniper, Hitbox Expander, Auto Rejoin, Island TP
    - Character respawn handling — re-applies settings on death
]]

if not game:IsLoaded() then game.Loaded:Wait() end

--============================== SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VU = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--============================== REMOTE SETUP ==============================
-- Blox Fruits uses ReplicatedStorage.Remotes.Commits as its main RemoteEvent
local Remotes = RS:WaitForChild("Remotes")
local Commits = Remotes:FindFirstChild("Commits")

-- Fallback search if structure changed
if not Commits then
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") and (obj.Name == "Commits" or obj.Name == "Event") then
            Commits = obj
            break
        end
    end
end

-- Executor request function (for server hop)
local httpRequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or request or (http and http.request)

--============================== CONFIG ==============================
local Config = {
    -- Farm
    AutoFarm = false,
    AutoQuest = false,
    SelectedMob = "",
    SelectedWeapon = "",
    FarmHeight = 25,
    FastAttack = true,
    AttackDelay = 0.05,
    FarmMode = "Nearest", -- "Nearest" | "Selected" | "Boss"
    
    -- Stats
    AutoStats = false,
    StatPriority = "Melee", -- which stat gets points first
    StatPoints = { Melee = 0, Defense = 0, Sword = 0, Gun = 0, Fruit = 0 },
    
    -- Raid
    AutoRaid = false,
    
    -- Visuals
    PlayerESP = false,
    FruitESP = false,
    ESPDistance = 3000,
    
    -- Player
    FlyEnabled = false,
    FlySpeed = 75,
    Noclip = false,
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteStamina = false,
    
    -- Misc
    AutoRejoin = false,
    ServerHop = false,
    HitboxExpander = false,
    HitboxSize = 50,
    FruitSniper = false,
    AntiAFK = true,
}

--============================== ANTI-AFK ==============================
local AntiAFKConn
local function SetupAntiAFK()
    if AntiAFKConn then AntiAFKConn:Disconnect() end
    AntiAFKConn = LocalPlayer.Idled:Connect(function()
        VU:CaptureController()
        VU:ClickButton(Vector2.new())
        VU:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait()
        VU:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
end
SetupAntiAFK()

--============================== UTILITY ==============================
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

local function GetCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        if char.Humanoid.Health > 0 then return char end
    end
    return nil
end

local function GetRoot()
    local char = GetCharacter()
    return char and char.HumanoidRootPart or nil
end

--============================== ENEMY DETECTION ==============================
local function GetEnemies()
    local enemies = {}
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
    return enemies
end

local function GetClosestEnemy(filterName)
    local root = GetRoot()
    if not root then return nil end
    
    local closest, closestDist = nil, math.huge
    local folder = Workspace:FindFirstChild("Enemies")
    if not folder then return nil end
    
    for _, mob in ipairs(folder:GetChildren()) do
        if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
            if mob.Humanoid.Health > 0 then
                local matches = true
                if filterName and filterName ~= "" then
                    matches = mob.Name:lower():find(filterName:lower()) ~= nil
                end
                if matches then
                    local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = mob
                    end
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
    local folder = Workspace:FindFirstChild("Enemies")
    if not folder then return nil end
    
    for _, mob in ipairs(folder:GetChildren()) do
        if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
            if mob.Humanoid.Health > 0 then
                -- Bosses have high max health or "Boss" in name
                local isBoss = mob.Name:lower():find("boss") ~= nil 
                    or mob.Humanoid.MaxHealth > 3000
                if isBoss then
                    local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = mob
                    end
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
            if item:IsA("Tool") and not table.find(weapons, item.Name) then
                table.insert(weapons, item.Name)
            end
        end
    end
    return weapons
end

local function EquipWeapon(weaponName)
    if not weaponName or weaponName == "" then return end
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return end
    
    -- Already equipped?
    if char:FindFirstChild(weaponName) then return end
    
    -- Find in backpack and equip
    local tool = backpack:FindFirstChild(weaponName)
    if tool and tool:IsA("Tool") then
        -- Unequip current
        local current = char:FindFirstChildWhichIsA("Tool")
        if current then
            current.Parent = backpack
        end
        -- Equip new
        tool.Parent = char
    end
end

local function GetCurrentTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Tool")
end

--============================== COMBAT SYSTEM ==============================
-- Fast Attack: equip/unequip bypass to skip client-side cooldown
local function Attack()
    local char = GetCharacter()
    if not char then return end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end
    
    if Config.FastAttack then
        -- Rapid equip/unequip pattern — bypasses M1 cooldown
        tool.Parent = backpack
        tool.Parent = char
        tool:Activate()
    else
        tool:Activate()
    end
end

-- Use skill (Z, X, C, V, F keys)
local function UseSkill(keyCode)
    local char = GetCharacter()
    if not char then return end
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then return end
    
    -- Try VirtualInputManager (works on most executors)
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, keyCode, false, game)
    end)
end

--============================== AUTO FARM ==============================
local FarmThread = nil

local function StartAutoFarm()
    if FarmThread then task.cancel(FarmThread) end
    
    FarmThread = task.spawn(function()
        while Config.AutoFarm do
            task.wait(Config.AttackDelay)
            
            local char = GetCharacter()
            if not char then continue end
            local root = char.HumanoidRootPart
            
            -- Auto quest pickup
            if Config.AutoQuest then
                pcall(function()
                    -- Find and fire quest NPCs
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local ancestor = obj:FindFirstAncestorOfClass("Model")
                            if ancestor and not ancestor:FindFirstChild("Humanoid") then
                                local promptPart = obj.Parent
                                if promptPart and promptPart:IsA("BasePart") then
                                    local dist = (promptPart.Position - root.Position).Magnitude
                                    if dist < 15 then
                                        fireproximityprompt(obj)
                                        task.wait(0.1)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            
            -- Find target based on mode
            local target
            if Config.FarmMode == "Boss" then
                target = GetClosestBoss()
            elseif Config.FarmMode == "Selected" and Config.SelectedMob ~= "" then
                target = GetClosestEnemy(Config.SelectedMob)
            else
                target = GetClosestEnemy()
            end
            
            if target and target:FindFirstChild("HumanoidRootPart") and target:FindFirstChild("Humanoid") then
                if target.Humanoid.Health > 0 then
                    local hrp = target.HumanoidRootPart
                    
                    -- Teleport above mob
                    root.CFrame = CFrame.new(
                        hrp.Position + Vector3.new(0, Config.FarmHeight, 0),
                        hrp.Position
                    )
                    
                    -- Equip weapon
                    if Config.SelectedWeapon and Config.SelectedWeapon ~= "" then
                        EquipWeapon(Config.SelectedWeapon)
                    end
                    
                    -- Attack
                    Attack()
                    
                    -- Optional: use skills if available
                    if Config.AutoFarm then
                        pcall(function()
                            UseSkill(Enum.KeyCode.Z)
                        end)
                    end
                end
            else
                -- No target — if auto quest enabled, try finding quest NPC
                if Config.AutoQuest then
                    -- Move to nearest non-enemy with prompt
                    local closestPrompt, closestDist = nil, math.huge
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Enabled then
                            local ancestor = obj:FindFirstAncestorOfClass("Model")
                            if ancestor and not ancestor:FindFirstChild("Humanoid") then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") then
                                    local d = (part.Position - root.Position).Magnitude
                                    if d < closestDist and d < 500 then
                                        closestDist = d
                                        closestPrompt = part
                                    end
                                end
                            end
                        end
                    end
                    if closestPrompt then
                        root.CFrame = CFrame.new(closestPrompt.Position + Vector3.new(0, 10, 0))
                    end
                end
            end
        end
    end)
end

local function StopAutoFarm()
    Config.AutoFarm = false
    if FarmThread then
        pcall(function() task.cancel(FarmThread) end)
        FarmThread = nil
    end
end

--============================== AUTO STATS ==============================
local StatsThread = nil

local function StartAutoStats()
    if StatsThread then task.cancel(StatsThread) end
    
    StatsThread = task.spawn(function()
        while Config.AutoStats do
            task.wait(0.5)
            
            local points = GetStatPoints()
            if points > 0 and Commits then
                -- Distribute based on priority
                local statOrder = {}
                for stat, pct in pairs(Config.StatPoints) do
                    if pct > 0 then
                        table.insert(statOrder, {name = stat, pct = pct})
                    end
                end
                -- If no stats configured, use priority
                if #statOrder == 0 then
                    pcall(function()
                        Commits:FireServer("AddPoint", Config.StatPriority)
                    end)
                else
                    -- Distribute proportionally
                    local total = 0
                    for _, s in ipairs(statOrder) do total = total + s.pct end
                    if total > 0 then
                        for _, s in ipairs(statOrder) do
                            local count = math.floor(points * (s.pct / total))
                            for i = 1, count do
                                pcall(function()
                                    Commits:FireServer("AddPoint", s.name)
                                end)
                                task.wait(0.05)
                            end
                        end
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
end

--============================== AUTO RAID ==============================
local RaidThread = nil

local function StartAutoRaid()
    if RaidThread then task.cancel(RaidThread) end
    
    RaidThread = task.spawn(function()
        while Config.AutoRaid do
            task.wait(0.1)
            
            local char = GetCharacter()
            if not char then continue end
            local root = char.HumanoidRootPart
            
            -- Find raid enemies (they spawn in Workspace.Enemies during raids)
            local target
            local enemies = GetEnemies()
            if #enemies > 0 then
                -- Closest enemy in raid
                local closestDist = math.huge
                for _, mob in ipairs(enemies) do
                    local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        target = mob
                    end
                end
            end
            
            if target then
                local hrp = target.HumanoidRootPart
                root.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 15, 0), hrp.Position)
                
                if Config.SelectedWeapon and Config.SelectedWeapon ~= "" then
                    EquipWeapon(Config.SelectedWeapon)
                end
                Attack()
                
                -- Use all skills
                pcall(function()
                    UseSkill(Enum.KeyCode.Z)
                    task.wait(0.1)
                    UseSkill(Enum.KeyCode.X)
                    task.wait(0.1)
                    UseSkill(Enum.KeyCode.C)
                end)
            else
                -- No enemies — try to start raid by finding raid NPC
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        local ancestor = obj:FindFirstAncestorOfClass("Model")
                        if ancestor then
                            local name = ancestor.Name:lower()
                            if name:find("raid") or name:find("dimensional") or name:find("host") then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") then
                                    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
                                    task.wait(0.3)
                                    fireproximityprompt(obj)
                                    task.wait(1)
                                    break
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
end

--============================== FRUIT SNIPER ==============================
local FruitList = {
    "Bomb", "Spike", "Chop", "Spring", "Kilo", "Spin", "Smoke", "Flame",
    "Falcon", "Ice", "Sand", "Dark", "Diamond", "Light", "Rubber",
    "Barrier", "Magma", "Quake", "Buddha", "Love", "String", "Spider",
    "Sound", "Phoenix", "Portal", "Rumble", "Paw", "Gravity", "Dough",
    "Shadow", "Venom", "Control", "Spirit", "Dragon", "Leopard",
    "Kitsune", "Gas", "Blizzard", "Yeti", "Bird", "Rocket", "Revive",
    "Sand", "Magma"
}

local FruitSniperThread = nil

local function FindDevilFruits()
    local fruits = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") then
            -- Skip if it has a Humanoid (it's an NPC, not a fruit)
            if not obj:FindFirstChild("Humanoid") then
                local name = obj.Name
                for _, fruitName in ipairs(FruitList) do
                    if name:lower():find(fruitName:lower()) then
                        -- Verify it has a collect mechanism
                        local hasPrompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        local hasClick = obj:FindFirstChildWhichIsA("ClickDetector", true)
                        if hasPrompt or hasClick or obj:FindFirstChild("Handle") then
                            table.insert(fruits, obj)
                        end
                        break
                    end
                end
            end
        end
    end
    -- Also search deeper in workspace for spawned fruits
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("fruit") and obj:FindFirstChildWhichIsA("BasePart") then
            if not obj:FindFirstChild("Humanoid") and not table.find(fruits, obj) then
                table.insert(fruits, obj)
            end
        end
    end
    return fruits
end

local function CollectFruit(fruit)
    local char = GetCharacter()
    if not char then return end
    local root = char.HumanoidRootPart
    
    local part = fruit:FindFirstChildWhichIsA("BasePart") or fruit:FindFirstChild("Handle")
    if not part then
        part = fruit:FindFirstChild("HumanoidRootPart")
    end
    if not part then return end
    
    -- Teleport to fruit
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
    task.wait(0.3)
    
    -- Try to collect
    local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
    local click = fruit:FindFirstChildWhichIsA("ClickDetector", true)
    
    if prompt then
        fireproximityprompt(prompt)
    elseif click then
        fireclickdetector(click)
    else
        -- Try Commits remote
        if Commits then
            pcall(function()
                Commits:FireServer("PickUpFruit", fruit.Name)
            end)
        end
    end
end

local function StartFruitSniper()
    if FruitSniperThread then task.cancel(FruitSniperThread) end
    
    FruitSniperThread = task.spawn(function()
        while Config.FruitSniper do
            task.wait(1)
            local fruits = FindDevilFruits()
            if #fruits > 0 then
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
end

--============================== ESP SYSTEM ==============================
local ESPObjects = {}

local function CreateESP(model, text, color)
    if ESPObjects[model] then
        -- Update existing
        local gui = ESPObjects[model]
        if gui and gui:FindFirstChild("Label") then
            gui.Label.Text = text
        end
        return
    end
    
    local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    
    local gui = Instance.new("BillboardGui")
    gui.Name = "VEIL_ESP"
    gui.Adornee = part
    gui.Size = UDim2.new(0, 250, 0, 40)
    gui.StudsOffset = Vector3.new(0, 4, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = Config.ESPDistance
    
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
    
    gui.Parent = game:GetService("CoreGui")
    ESPObjects[model] = gui
end

local function RemoveESP(model)
    if ESPObjects[model] then
        ESPObjects[model]:Destroy()
        ESPObjects[model] = nil
    end
end

local function ClearAllESP()
    for model, gui in pairs(ESPObjects) do
        if gui then gui:Destroy() end
    end
    ESPObjects = {}
end

-- Player ESP loop
local ESPThread = nil
local function StartPlayerESP()
    if ESPThread then task.cancel(ESPThread) end
    
    ESPThread = task.spawn(function()
        while Config.PlayerESP do
            task.wait(0.5)
            local root = GetRoot()
            if not root then continue end
            
            -- Remove ESP for players who left/died
            for model, _ in pairs(ESPObjects) do
                if not model.Parent or (model:FindFirstChild("Humanoid") and model.Humanoid.Health <= 0) then
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
                    
                    local text = player.Name .. " | Lv." .. level .. " | " .. dist .. "m"
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
    -- Remove player ESPs
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then RemoveESP(player.Character) end
    end
end

-- Fruit ESP
local FruitESPThread = nil
local function StartFruitESP()
    if FruitESPThread then task.cancel(FruitESPThread) end
    
    FruitESPThread = task.spawn(function()
        while Config.FruitESP do
            task.wait(2)
            local fruits = FindDevilFruits()
            for _, fruit in ipairs(fruits) do
                CreateESP(fruit, "DEVIL FRUIT: " .. fruit.Name, Color3.fromRGB(0, 255, 0))
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
end

--============================== FLY SYSTEM ==============================
local FlyConnection, FlyBV, FlyBG

local function ToggleFly(state)
    Config.FlyEnabled = state
    local char = GetCharacter()
    if not char then return end
    local root = char.HumanoidRootPart
    
    if state then
        if FlyBV then FlyBV:Destroy() end
        if FlyBG then FlyBG:Destroy() end
        
        FlyBV = Instance.new("BodyVelocity")
        FlyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyBV.Velocity = Vector3.zero
        FlyBV.Parent = root
        
        FlyBG = Instance.new("BodyGyro")
        FlyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        FlyBG.CFrame = Camera.CFrame
        FlyBG.P = 9e4
        FlyBG.Parent = root
        
        if FlyConnection then FlyConnection:Disconnect() end
        FlyConnection = RunService.RenderStepped:Connect(function()
            if not Config.FlyEnabled then return end
            local char = GetCharacter()
            if not char then return end
            local root = char.HumanoidRootPart
            
            local dir = Vector3.zero
            local cam = Camera.CFrame
            
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
            
            if FlyBV then FlyBV.Velocity = dir * Config.FlySpeed end
            if FlyBG then FlyBG.CFrame = Camera.CFrame end
        end)
    else
        if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyBG then FlyBG:Destroy() FlyBG = nil end
    end
end

--============================== NOCLIP ==============================
local NoclipConn

local function ToggleNoclip(state)
    Config.Noclip = state
    if state then
        if NoclipConn then NoclipConn:Disconnect() end
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
        -- Restore collisions
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

--============================== WALKSPEED / JUMP ==============================
local SpeedThread
local function StartSpeedMaintain()
    if SpeedThread then task.cancel(SpeedThread) end
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
    if HitboxThread then task.cancel(HitboxThread) end
    
    HitboxThread = task.spawn(function()
        while Config.HitboxExpander do
            task.wait(0.5)
            local folder = Workspace:FindFirstChild("Enemies")
            if folder then
                for _, mob in ipairs(folder:GetChildren()) do
                    if mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                        local hrp = mob:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            pcall(function()
                                hrp.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                                hrp.Transparency = 0.7
                                hrp.CanCollide = false
                                hrp.Material = Enum.Material.ForceField
                                hrp.Color = Color3.fromRGB(255, 0, 0)
                            end)
                        end
                    end
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
    local folder = Workspace:FindFirstChild("Enemies")
    if folder then
        for _, mob in ipairs(folder:GetChildren()) do
            local hrp = mob:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                    hrp.CanCollide = false
                end)
            end
        end
    end
end

--============================== SERVER HOP ==============================
local function ServerHop()
    if not httpRequest then return end
    
    local body = httpRequest({
        Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
        Method = "GET"
    })
    
    if body and body.Body then
        local success, data = pcall(function()
            return HttpService:JSONDecode(body.Body)
        end)
        if success and data and data.data then
            local validServers = {}
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers - 1 then
                    table.insert(validServers, server.id)
                end
            end
            if #validServers > 0 then
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    validServers[math.random(1, #validServers)],
                    LocalPlayer
                )
            end
        end
    end
end

--============================== AUTO REJOIN ==============================
local function StartAutoRejoin()
    task.spawn(function()
        while Config.AutoRejoin do
            task.wait(5)
            -- Check if disconnected
            if not game:GetService("NetworkClient"):GetConnections()[1] then
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
                break
            end
        end
    end)
end

--============================== ISLAND TELEPORT ==============================
-- Dynamically find island spawn points
local function GetIslands()
    local islands = {}
    -- Search for spawn locations
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            table.insert(islands, {name = obj.Name, position = obj.CFrame})
        end
    end
    -- Search for island models
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            local name = obj.Name
            if name:lower():find("island") or name:lower():find("village") 
               or name:lower():find("city") or name:lower():find("port")
               or name:lower():find("castle") or name:lower():find("base") then
                local part = obj:FindFirstChildWhichIsA("BasePart") or obj:FindFirstChild("HumanoidRootPart")
                if part then
                    table.insert(islands, {name = name, position = part.CFrame})
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
end

--============================== CHARACTER RESPAWN HANDLER ==============================
local function OnCharacterAdded(char)
    char:WaitForChild("HumanoidRootPart")
    char:WaitForChild("Humanoid")
    
    task.wait(0.5)
    
    -- Re-apply settings
    if Config.WalkSpeed ~= 16 then
        char.Humanoid.WalkSpeed = Config.WalkSpeed
    end
    if Config.JumpPower ~= 50 then
        char.Humanoid.JumpPower = Config.JumpPower
    end
    
    -- Restart fly
    if Config.FlyEnabled then
        ToggleFly(false)
        task.wait(0.2)
        ToggleFly(true)
    end
    
    -- Restart noclip
    if Config.Noclip then
        ToggleNoclip(false)
        task.wait(0.2)
        ToggleNoclip(true)
    end
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

--============================== UI LIBRARY ==============================
-- Clean UI with proper tab system
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VEIL_BloxHub_v2_" .. math.random(1000, 9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (CoreGui and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")

-- Main container
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 520, 0, 680)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -340)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
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
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "VEIL // BLOX FRUITS HUB v2"
TitleLabel.TextColor3 = Color3.fromRGB(170, 80, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Info bar
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 20)
InfoLabel.Position = UDim2.new(0, 10, 0, 48)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Loading..."
InfoLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 12
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = MainFrame

-- Update info
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1)
        local level = GetLevel()
        local beli = GetBeli()
        local frag = GetFragments()
        InfoLabel.Text = "Lv." .. level .. "  |  Beli: " .. tostring(beli) .. "  |  Fragments: " .. tostring(frag)
    end
end)

-- Tab buttons container
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
ContentArea.Size = UDim2.new(1, -20, 0, 550)
ContentArea.Position = UDim2.new(0, 10, 0, 112)
ContentArea.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 8)
contentCorner.Parent = ContentArea

-- Scroll frames helper
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

-- Tab creation
local Tabs = {}
local function CreateTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 95, 1, 0)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(160, 160, 180)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
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
            tab.btn.TextColor3 = Color3.fromRGB(160, 160, 180)
            tab.btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        end
        page.Visible = true
        btn.TextColor3 = Color3.fromRGB(170, 80, 255)
        btn.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
    end)
    
    table.insert(Tabs, {btn = btn, page = page})
    return page
end

-- Toggle helper
local function MakeToggle(parent, text, default, callback)
    local state = default or false
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, 38)
    toggle.Text = "  " .. text .. "  [OFF]"
    toggle.Font = Enum.Font.Gotham
    toggle.TextSize = 14
    toggle.TextColor3 = Color3.fromRGB(220, 220, 230)
    toggle.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    toggle.BorderSizePixel = 0
    toggle.TextXAlignment = Enum.TextXAlignment.Left
    toggle.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toggle
    
    local function update()
        toggle.Text = "  " .. text .. "  [" .. (state and "ON" or "OFF") .. "]"
        toggle.BackgroundColor3 = state and Color3.fromRGB(40, 100, 60) or Color3.fromRGB(30, 30, 38)
    end
    update()
    
    toggle.MouseButton1Click:Connect(function()
        state = not state
        update()
        callback(state)
    end)
    
    return toggle
end

-- Button helper
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

-- Input helper
local function MakeInput(parent, labelText, placeholder, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 40)
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
    box.Size = UDim2.new(1, 0, 0, 22)
    box.Position = UDim2.new(0, 0, 0, 17)
    box.Text = ""
    box.PlaceholderText = placeholder or "Enter..."
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    box.BorderSizePixel = 0
    box.Parent = container
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box
    
    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
    
    return box
end

-- Dropdown helper
local function MakeDropdown(parent, labelText, options, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 40)
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
    btn.Size = UDim2.new(1, 0, 0, 22)
    btn.Position = UDim2.new(0, 0, 0, 17)
    btn.Text = "Select..."
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
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
        btn.Text = options[1]
        callback(options[1])
    end
    
    return btn
end

-- Slider helper
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
    slider.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
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

-- Section header helper
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

--============================== TABS ==============================

-- === FARM TAB ===
local FarmTab = CreateTab("Farm")

MakeSection(FarmTab, "Auto Farm")
MakeToggle(FarmTab, "Auto Farm", false, function(state)
    Config.AutoFarm = state
    if state then StartAutoFarm() else StopAutoFarm() end
end)
MakeToggle(FarmTab, "Fast Attack (Bypass Cooldown)", true, function(state)
    Config.FastAttack = state
end)
MakeToggle(FarmTab, "Auto Quest", false, function(state)
    Config.AutoQuest = state
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

MakeSlider(FarmTab, "Farm Height", 5, 100, 25, function(val)
    Config.FarmHeight = val
end)
MakeSlider(FarmTab, "Attack Delay", 0.01, 1, 0.05, function(val)
    Config.AttackDelay = val
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

MakeSection(StatsTab, "Stat Distribution (% must total 100)")
MakeSlider(StatsTab, "Melee %", 0, 100, 50, function(val)
    Config.StatPoints.Melee = val
end)
MakeSlider(StatsTab, "Defense %", 0, 100, 25, function(val)
    Config.StatPoints.Defense = val
end)
MakeSlider(StatsTab, "Sword %", 0, 100, 25, function(val)
    Config.StatPoints.Sword = val
end)
MakeSlider(StatsTab, "Gun %", 0, 100, 0, function(val)
    Config.StatPoints.Gun = val
end)
MakeSlider(StatsTab, "Devil Fruit %", 0, 100, 0, function(val)
    Config.StatPoints.Fruit = val
end)

MakeDropdown(StatsTab, "Fallback Priority", {"Melee", "Defense", "Sword", "Gun", "Devil Fruit"}, function(val)
    Config.StatPriority = val
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

MakeSection(VisualTab, "Hitbox")
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

-- === TELEPORT TAB ===
local TeleportTab = CreateTab("Teleport")

MakeSection(TeleportTab, "Island Teleport")
local islandButtons = {}
local function RefreshIslands()
    -- Clear old buttons
    for _, btn in ipairs(islandButtons) do
        btn:Destroy()
    end
    islandButtons = {}
    
    -- Create new buttons
    local islands = GetIslands()
    for _, island in ipairs(islands) do
        local btn = MakeButton(TeleportTab, "TP to " .. island.name, function()
            TeleportTo(island.position)
        end)
        table.insert(islandButtons, btn)
    end
end

MakeButton(TeleportTab, "Refresh Islands", RefreshIslands)
RefreshIslands()

MakeSection(TeleportTab, "Fruit Sniper")
MakeToggle(TeleportTab, "Auto Fruit Sniper", false, function(state)
    Config.FruitSniper = state
    if state then StartFruitSniper() else StopFruitSniper() end
end)

MakeButton(TeleportTab, "Collect Nearest Fruit", function()
    local fruits = FindDevilFruits()
    if #fruits > 0 then
        CollectFruit(fruits[1])
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
    if state then SetupAntiAFK() end
    if not state and AntiAFKConn then
        AntiAFKConn:Disconnect()
        AntiAFKConn = nil
    end
end)

-- === SETTINGS TAB ===
local SettingsTab = CreateTab("Settings")

MakeSection(SettingsTab, "UI Controls")
MakeButton(SettingsTab, "Destroy UI", function()
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
end)

MakeButton(SettingsTab, "Clear All ESP", function()
    ClearAllESP()
end)

MakeButton(SettingsTab, "Reset Walk Speed", function()
    Config.WalkSpeed = 16
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = 16
    end
end)

MakeButton(SettingsTab, "Reset Jump Power", function()
    Config.JumpPower = 50
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = 50
    end
end)

MakeSection(SettingsTab, "Weapon List (current)")
local weaponLabel = Instance.new("TextLabel")
weaponLabel.Size = UDim2.new(1, -10, 0, 20)
weaponLabel.Text = "Click refresh to see weapons"
weaponLabel.Font = Enum.Font.Gotham
weaponLabel.TextSize = 12
weaponLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
weaponLabel.BackgroundTransparency = 1
weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponLabel.Parent = SettingsTab

MakeButton(SettingsTab, "Refresh Weapon List", function()
    local weapons = GetWeaponList()
    weaponLabel.Text = table.concat(weapons, ", ")
end)

-- Default tab
Tabs[1].page.Visible = true
Tabs[1].btn.TextColor3 = Color3.fromRGB(170, 80, 255)
Tabs[1].btn.BackgroundColor3 = Color3.fromRGB(35, 30, 45)

--============================== LOAD NOTIFICATION ==============================
local NotifyFrame = Instance.new("Frame")
NotifyFrame.Size = UDim2.new(0, 320, 0, 50)
NotifyFrame.Position = UDim2.new(0.5, -160, 0, 30)
NotifyFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
NotifyFrame.BorderSizePixel = 0
NotifyFrame.Parent = ScreenGui

local notifyCorner = Instance.new("UICorner")
notifyCorner.CornerRadius = UDim.new(0, 8)
notifyCorner.Parent = NotifyFrame

local NotifyLabel = Instance.new("TextLabel")
NotifyLabel.Size = UDim2.new(1, 0, 1, 0)
NotifyLabel.BackgroundTransparency = 1
NotifyLabel.Text = "VEIL Hub v2 loaded. Press a tab to begin."
NotifyLabel.TextColor3 = Color3.fromRGB(170, 80, 255)
NotifyLabel.Font = Enum.Font.GothamBold
NotifyLabel.TextSize = 15
NotifyLabel.Parent = NotifyFrame

-- Slide in animation
NotifyFrame.Position = UDim2.new(0.5, -160, 0, -60)
TweenService:Create(NotifyFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -160, 0, 30)
}):Play()

-- Slide out after 4 seconds
task.delay(4, function()
    TweenService:Create(NotifyFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -160, 0, -60)
    }):Play()
    task.wait(0.6)
    NotifyFrame:Destroy()
end)

-- Minimize button (toggle UI visibility)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -35, 0, 7)
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 4)
minCorner.Parent = MinBtn

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        ContentArea.Visible = false
        TabContainer.Visible = false
        InfoLabel.Visible = false
        MinBtn.Text = "+"
        MainFrame.Size = UDim2.new(0, 520, 0, 50)
    else
        ContentArea.Visible = true
        TabContainer.Visible = true
        InfoLabel.Visible = true
        MinBtn.Text = "-"
        MainFrame.Size = UDim2.new(0, 520, 0, 680)
    end
end)

print("[VEIL] Blox Fruits Hub v2 loaded successfully.")
print("[VEIL] Features: Auto Farm, Auto Quest, Auto Stats, Auto Raid, ESP, Fly, Noclip, Hitbox Expander, Fruit Sniper, Server Hop, Island TP")
print("[VEIL] Remote found: " .. (Commits and "YES" or "NO — some features may not work"))
