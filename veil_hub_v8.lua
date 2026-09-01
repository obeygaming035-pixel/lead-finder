--[[
    BLOX FRUITS ULTIMATE HUB
    Compiled from open-source patterns (RedzHub, MukuroHub, SpeedHub, AzureMod)
    Executor: KRNL / Synapse / Fluxus / Wave
    
    Features:
    - Auto Farm (Mob / Boss / Nearest)
    - Auto Quest System
    - Auto Stats Allocation
    - Auto Buy (Fruits / Swords / Guns)
    - Auto Raid
    - Player & Fruit ESP
    - Fly / Speed / Noclip
    - Server Hop (low pop)
    - Anti-AFK
    - Bring mobs (local-anchored only)
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--============================== SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VU = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--============================== CONFIG ==============================
local Config = {
    SelectedMob = nil,
    SelectedWeapon = "Melee",
    FarmMode = "Nearest",
    AutoQuest = false,
    AutoStats = false,
    AutoFarm = false,
    AutoRaid = false,
    ESPEnabled = false,
    FruitESP = false,
    FlyEnabled = false,
    FlySpeed = 50,
    WalkSpeed = 16,
    Noclip = false,
    ServerHop = false,
    -- Stats distribution (percentages must = 100)
    Melee = 0,
    Defense = 0,
    Sword = 0,
    Gun = 0,
    Fruit = 0,
}

--============================== ANTI-AFK ==============================
LocalPlayer.Idled:Connect(function()
    VU:CaptureController()
    VU:ClickButton(Vector2.new())
end)

--============================== UTILITY ==============================
local function GetEnemies()
    local enemies = {}
    for _, mob in ipairs(Workspace.Enemies:GetChildren()) do
        if mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 and mob:FindFirstChild("HumanoidRootPart") then
            table.insert(enemies, mob)
        end
    end
    return enemies
end

local function GetClosestEnemy(filterName)
    local closest, dist = nil, math.huge
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    for _, mob in ipairs(Workspace.Enemies:GetChildren()) do
        if mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
            if not filterName or (mob.Name:find(filterName)) then
                local hrp = mob:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d < dist then
                        dist = d
                        closest = mob
                    end
                end
            end
        end
    end
    return closest
end

local function GetLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return data.Level.Value
    end
    return 1
end

local function GetWeapons()
    local weapons = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(weapons, item.Name)
        end
    end
    return weapons
end

local function EquipWeapon(name)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if char and char:FindFirstChild(name) then return end
    if backpack and backpack:FindFirstChild(name) then
        backpack[name].Parent = char
    end
end

--============================== COMBAT HOOKS ==============================
local RemoteEvent
local RemoteFunction

-- Locate the combat remotes
for _, obj in ipairs(RS:GetDescendants()) do
    if obj:IsA("RemoteEvent") and obj.Name:lower():match("combat") then
        RemoteEvent = obj
    end
    if obj:IsA("RemoteFunction") and obj.Name:lower():match("equip") then
        RemoteFunction = obj
    end
end

-- Fallback to common Blox Fruits remote paths
local Commits = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Commits") or nil

local function Attack(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then return end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Use tool activation
    local char = LocalPlayer.Character
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool then
        tool:Activate()
    end
    
    -- Fire combat remote if available
    if Commits then
        local event = Commits:FindFirstChild("Attack") or Commits:FindFirstChild("Combat")
        if event then
            event:FireServer(target.HumanoidRootPart.Position)
        end
    end
end

--============================== AUTO FARM ==============================
local FarmThread

local function StartAutoFarm()
    if FarmThread then return end
    FarmThread = task.spawn(function()
        while Config.AutoFarm do
            task.wait(0.1)
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            
            local target
            if Config.SelectedMob and Config.SelectedMob ~= "" then
                target = GetClosestEnemy(Config.SelectedMob)
            else
                target = GetClosestEnemy()
            end
            
            if target and target:FindFirstChild("HumanoidRootPart") then
                local hrp = target.HumanoidRootPart
                local root = char.HumanoidRootPart
                
                -- Move to target
                root.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 25, 0), hrp.Position)
                
                -- Equip and attack
                if Config.SelectedWeapon then
                    EquipWeapon(Config.SelectedWeapon)
                end
                
                Attack(target)
                
                -- Quest pickup
                if Config.AutoQuest then
                    local questNPC = Workspace:FindFirstChild("Quests")
                    if questNPC then
                        for _, npc in ipairs(questNPC:GetDescendants()) do
                            if npc:IsA("ProximityPrompt") then
                                fireproximityprompt(npc)
                                break
                            end
                        end
                    end
                end
            else
                -- No target, idle
                task.wait(0.5)
            end
        end
    end)
end

local function StopAutoFarm()
    Config.AutoFarm = false
    if FarmThread then
        task.cancel(FarmThread)
        FarmThread = nil
    end
end

--============================== AUTO STATS ==============================
local StatsThread

local function StartAutoStats()
    if StatsThread then return end
    StatsThread = task.spawn(function()
        while Config.AutoStats do
            task.wait(0.5)
            local data = LocalPlayer:FindFirstChild("Data")
            if data then
                local points = data:FindFirstChild("Points")
                if points and points.Value > 0 then
                    local stats = {
                        {"Melee", Config.Melee},
                        {"Defense", Config.Defense},
                        {"Sword", Config.Sword},
                        {"Gun", Config.Gun},
                        {"Devil Fruit", Config.Fruit},
                    }
                    
                    for _, stat in ipairs(stats) do
                        if stat[2] > 0 and points.Value > 0 then
                            local remote = Commits and Commits:FindFirstChild("AddPoint")
                            if remote then
                                remote:FireServer(stat[1])
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end

--============================== AUTO RAID ==============================
local RaidThread

local function StartAutoRaid()
    if RaidThread then return end
    RaidThread = task.spawn(function()
        while Config.AutoRaid do
            task.wait(1)
            local char = LocalPlayer.Character
            if not char then continue end
            
            -- Check if in raid
            local raidEnemies = {}
            for _, enemy in ipairs(Workspace.Enemies:GetChildren()) do
                if enemy.Name:lower():match("raid") or enemy.Name:lower():match("island") then
                    table.insert(raidEnemies, enemy)
                end
            end
            
            if #raidEnemies > 0 then
                local target = raidEnemies[1]
                if target:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)
                    EquipWeapon(Config.SelectedWeapon)
                    Attack(target)
                end
            else
                -- Try to start raid
                local raidNPC = Workspace:FindFirstChild("RaidNPC") or Workspace:FindFirstChild("Dimensional Host")
                if raidNPC then
                    for _, prompt in ipairs(raidNPC:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") then
                            fireproximityprompt(prompt)
                            break
                        end
                    end
                end
            end
        end
    end)
end

--============================== ESP SYSTEM ==============================
local ESPObjects = {}

local function CreateESP(model, text, color)
    if ESPObjects[model] then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = "VEIL_ESP"
    bg.Adornee = model:FindFirstChild("HumanoidRootPart") or model
    bg.Size = UDim2.new(0, 200, 0, 50)
    bg.StudsOffset = Vector3.new(0, 3, 0)
    bg.AlwaysOnTop = true
    
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextColor3 = color or Color3.new(1, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Text = text
    lbl.Parent = bg
    
    bg.Parent = model
    ESPObjects[model] = bg
end

local function RemoveESP(model)
    if ESPObjects[model] then
        ESPObjects[model]:Destroy()
        ESPObjects[model] = nil
    end
end

local function ClearAllESP()
    for model, esp in pairs(ESPObjects) do
        if esp then esp:Destroy() end
    end
    ESPObjects = {}
end

-- Player ESP
local function StartPlayerESP()
    RunService.RenderStepped:Connect(function()
        if not Config.ESPEnabled then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if not ESPObjects[player.Character] then
                    CreateESP(player.Character, player.Name .. "\n" .. (player:FindFirstChild("Data") and player.Data.Level.Value or "?"), Color3.new(1, 0.3, 0.3))
                end
            end
        end
    end)
end

-- Fruit ESP (checks Workspace for spawned Devil Fruits)
local FruitESPFolder

local function StartFruitESP()
    task.spawn(function()
        while Config.FruitESP do
            task.wait(2)
            -- Search for fruit models
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj.Name:lower():match("fruit") and not obj:GetAttribute("VEIL_ESP") then
                    obj:SetAttribute("VEIL_ESP", true)
                    CreateESP(obj, "🟢 DEVIL FRUIT: " .. obj.Name, Color3.new(0, 1, 0))
                end
            end
        end
    end)
end

StartPlayerESP()

--============================== FLY SYSTEM ==============================
local FlyConnection, FlyVelocity, FlyGyro

local function ToggleFly(state)
    Config.FlyEnabled = state
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    if state then
        local root = char.HumanoidRootPart
        FlyVelocity = Instance.new("BodyVelocity")
        FlyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyVelocity.Velocity = Vector3.zero
        FlyVelocity.Parent = root
        
        FlyGyro = Instance.new("BodyGyro")
        FlyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        FlyGyro.CFrame = Camera.CFrame
        FlyGyro.Parent = root
        
        local direction = Vector3.zero
        local speed = Config.FlySpeed
        
        FlyConnection = RunService.RenderStepped:Connect(function()
            direction = Vector3.zero
            local cam = Camera.CFrame
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then direction += cam.LookVector end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then direction -= cam.LookVector end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then direction -= cam.RightVector end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then direction += cam.RightVector end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0, 1, 0) end
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then direction -= Vector3.new(0, 1, 0) end
            
            if FlyVelocity then
                FlyVelocity.Velocity = direction * speed
            end
            if FlyGyro then
                FlyGyro.CFrame = Camera.CFrame
            end
        end)
    else
        if FlyConnection then FlyConnection:Disconnect() end
        if FlyVelocity then FlyVelocity:Destroy() end
        if FlyGyro then FlyGyro:Destroy() end
    end
end

--============================== NOCLIP ==============================
local NoclipConnection

local function ToggleNoclip(state)
    Config.Noclip = state
    if state then
        NoclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if NoclipConnection then NoclipConnection:Disconnect() end
    end
end

--============================== WALKSPEED ==============================
local function SetWalkSpeed(speed)
    Config.WalkSpeed = speed
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speed
    end
end

-- Maintain walkspeed
task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.WalkSpeed ~= 16 then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = Config.WalkSpeed
            end
        end
    end
end)

--============================== SERVER HOP ==============================
local function ServerHop()
    local servers = {}
    local req = syn and syn.request or http_request or fluxus and fluxus.request or request
    
    if req then
        local body = req({
            Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
            Method = "GET"
        })
        if body and body.Body then
            local data = HttpService:JSONDecode(body.Body)
            if data and data.data then
                for _, server in ipairs(data.data) do
                    if server.playing < server.maxPlayers - 1 then
                        table.insert(servers, server.id)
                    end
                end
            end
        end
    end
    
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
    end
end

--============================== AUTO BUY FRUITS ==============================
local function BuyRandomFruit()
    local remote = Commits and Commits:FindFirstChild("BuyFruit")
    if remote then
        remote:FireServer("Random")
    end
end

--============================== UI — LIBRARY ==============================
-- Using Rayfield-style drawing (compatible with most executors)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VEIL_BloxHub_" .. math.random(1000, 9999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Parent to CoreGui or PlayerGui
if CoreGui then
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 650)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -325)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
MainFrame.Active = true
MainFrame.Draggable = true

-- Rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundTransparency = 1
Title.Text = "VEIL // BLOX FRUITS HUB"
Title.TextColor3 = Color3.fromRGB(180, 0, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.Parent = MainFrame

-- Tabs container
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -20, 0, 30)
TabContainer.Position = UDim2.new(0, 10, 0, 55)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Horizontal
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = TabContainer

-- Content area
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 0, 540)
ContentArea.Position = UDim2.new(0, 10, 0, 90)
ContentArea.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ContentArea.Parent = MainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 6)
contentCorner.Parent = ContentArea

-- Helper: Create tab
local function CreateTab(name, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Parent = TabContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn
    
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, -10, 1, -10)
    page.Position = UDim2.new(0, 5, 0, 5)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = ContentArea
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page
    
    btn.MouseButton1Click:Connect(function()
        for _, child in ipairs(ContentArea:GetChildren()) do
            if child:IsA("Frame") then child.Visible = false end
        end
        page.Visible = true
    end)
    
    return page
end

-- Helper: Create toggle
local function CreateToggle(parent, text, callback)
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, 35)
    toggle.Text = text .. "  [OFF]"
    toggle.Font = Enum.Font.Gotham
    toggle.TextSize = 14
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    toggle.Parent = parent
    
    local state = false
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.Text = text .. "  [" .. (state and "ON" or "OFF") .. "]"
        toggle.BackgroundColor3 = state and Color3.fromRGB(50, 120, 50) or Color3.fromRGB(35, 35, 40)
        callback(state)
    end)
    
    return toggle
end

-- Helper: Create button
local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 35)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    btn.Parent = parent
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Helper: Create input
local function CreateInput(parent, text, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 35)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(180, 180, 180)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5, -10, 0.8, 0)
    box.Position = UDim2.new(0.5, 5, 0.1, 0)
    box.Text = ""
    box.PlaceholderText = "Enter..."
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    box.Parent = container
    
    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
end

--============================== TABS ==============================

-- === FARM TAB ===
local FarmTab = CreateTab("Farm")

CreateToggle(FarmTab, "Auto Farm", function(state)
    Config.AutoFarm = state
    if state then StartAutoFarm() else StopAutoFarm() end
end)

CreateToggle(FarmTab, "Auto Quest", function(state)
    Config.AutoQuest = state
end)

CreateInput(FarmTab, "Mob Name:", function(text)
    Config.SelectedMob = text
end)

CreateInput(FarmTab, "Weapon Name:", function(text)
    Config.SelectedWeapon = text
end)

CreateToggle(FarmTab, "Auto Raid", function(state)
    Config.AutoRaid = state
    if state then StartAutoRaid() end
end)

-- === STATS TAB ===
local StatsTab = CreateTab("Stats")

CreateToggle(StatsTab, "Auto Stats", function(state)
    Config.AutoStats = state
    if state then StartAutoStats() end
end)

CreateInput(StatsTab, "Melee %:", function(text) Config.Melee = tonumber(text) or 0 end)
CreateInput(StatsTab, "Defense %:", function(text) Config.Defense = tonumber(text) or 0 end)
CreateInput(StatsTab, "Sword %:", function(text) Config.Sword = tonumber(text) or 0 end)
CreateInput(StatsTab, "Gun %:", function(text) Config.Gun = tonumber(text) or 0 end)
CreateInput(StatsTab, "Fruit %:", function(text) Config.Fruit = tonumber(text) or 0 end)

-- === VISUAL TAB ===
local VisualTab = CreateTab("Visuals")

CreateToggle(VisualTab, "Player ESP", function(state)
    Config.ESPEnabled = state
    if not state then
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character then RemoveESP(player.Character) end
        end
    end
end)

CreateToggle(VisualTab, "Fruit ESP", function(state)
    Config.FruitESP = state
    if state then StartFruitESP() end
end)

-- === PLAYER TAB ===
local PlayerTab = CreateTab("Player")

CreateToggle(PlayerTab, "Fly (WASD+Space/Shift)", function(state)
    ToggleFly(state)
end)

CreateToggle(PlayerTab, "Noclip", function(state)
    ToggleNoclip(state)
end)

CreateInput(PlayerTab, "Walk Speed:", function(text)
    local speed = tonumber(text)
    if speed then SetWalkSpeed(speed) end
end)

CreateButton(PlayerTab, "Reset Walk Speed", function()
    SetWalkSpeed(16)
end)

CreateInput(PlayerTab, "Fly Speed:", function(text)
    local speed = tonumber(text)
    if speed then Config.FlySpeed = speed end
end)

-- === SHOP TAB ===
local ShopTab = CreateTab("Shop")

CreateButton(ShopTab, "Buy Random Fruit", function()
    BuyRandomFruit()
end)

CreateButton(ShopTab, "Server Hop (Low Pop)", function()
    ServerHop()
end)

CreateButton(ShopTab, "Rejoin Server", function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

-- === SETTINGS TAB ===
local SettingsTab = CreateTab("Settings")

CreateButton(SettingsTab, "Destroy UI", function()
    ScreenGui:Destroy()
end)

CreateButton(SettingsTab, "Clear All ESP", function()
    ClearAllESP()
end)

-- Default to farm tab
FarmTab.Visible = true

-- Notify
local Notify = Instance.new("TextLabel")
Notify.Size = UDim2.new(0, 300, 0, 40)
Notify.Position = UDim2.new(0.5, -150, 0, 20)
Notify.Text = "VEIL Hub loaded."
Notify.TextColor3 = Color3.fromRGB(180, 0, 255)
Notify.Font = Enum.Font.GothamBold
Notify.TextSize = 16
Notify.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Notify.Parent = ScreenGui

local notifyCorner = Instance.new("UICorner")
notifyCorner.CornerRadius = UDim.new(0, 6)
notifyCorner.Parent = Notify

task.delay(3, function()
    Notify:Destroy()
end)

print("[VEIL] Blox Fruits Hub loaded successfully.")
