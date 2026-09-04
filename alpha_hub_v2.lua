--[[
    ALPHA // BLOX FRUITS HUB v2 (KEYLESS EDITION)
    Built with RedzLib UI Framework
    100% Keyless • Fast Attack • Auto Farm • Fruit Sniper • ESP • Server Hop
    Compatible with: KRNL, Synapse, Fluxus, Wave, Delta, Hydrogen, Arceus X
]]

if not game:IsLoaded() then game.Loaded:Wait() end

--============================== SERVICES ==============================
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

--============================== CAPABILITY CHECKS ==============================
local HAS_fireproximityprompt = type(fireproximityprompt) == "function"
local HAS_fireclickdetector = type(fireclickdetector) == "function"
local HAS_httprequest = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or (request and type(request) == "function")

local function safeRequest(args)
    if not HAS_httprequest then return nil end
    local fn = (syn and syn.request) or http_request or (fluxus and fluxus.request) or (http and http.request) or request
    local ok, result = pcall(fn, args)
    if ok then return result end
    return nil
end

--============================== REMOTES INITIALIZATION ==============================
local Remotes = RS:WaitForChild("Remotes", 10)
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")
local Commits = Remotes and Remotes:FindFirstChild("Commits")

-- Fallback remote search if path varies
if not CommF_ and not Commits then
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteFunction") and obj.Name == "CommF_" then
            CommF_ = obj
        elseif obj:IsA("RemoteEvent") and obj.Name == "Commits" then
            Commits = obj
        end
    end
end

-- Fast attack net modules
local NetModule = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
local RegisterAttack = NetModule and NetModule:FindFirstChild("RE/RegisterAttack")
local RegisterHit = NetModule and NetModule:FindFirstChild("RE/RegisterHit")

--============================== CONFIGURATION ==============================
_G.Config = {
    -- Main Farm
    AutoFarm = false,
    AutoQuest = false,
    BringMobs = true,
    FarmMode = "Level", -- "Level" | "Nearest" | "Boss"
    SelectedMob = "",
    SelectedWeapon = "Melee", -- "Melee" | "Sword" | "Gun" | "Fruit"
    TweenSpeed = 320,
    FarmDistance = 8,
    
    -- Fast Attack
    FastAttack = true,
    FastAttackDistance = 65,
    AttackCooldown = 0.05,
    
    -- Stats
    AutoStats = false,
    StatPoints = {
        Melee = true,
        Defense = true,
        Sword = false,
        Gun = false,
        Fruit = false
    },
    
    -- Fruit Sniper & ESP
    FruitSniper = false,
    FruitESP = false,
    PlayerESP = false,
    ESPDistance = 5000,
    
    -- Movement & Player
    FlyEnabled = false,
    FlySpeed = 80,
    Noclip = false,
    WalkSpeed = 16,
    JumpPower = 50,
    
    -- Utility
    AntiAFK = true,
    AutoRejoin = false
}

--============================== ANTI-AFK ==============================
local AntiAFKConn
local function EnableAntiAFK()
    if AntiAFKConn then AntiAFKConn:Disconnect() end
    AntiAFKConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton(Vector2.new())
    end)
end
EnableAntiAFK()

--============================== CHARACTER HELPERS ==============================
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

--============================== TWEEN MOVEMENT ==============================
local CurrentTween = nil

local function StopTween()
    if CurrentTween then
        CurrentTween:Cancel()
        CurrentTween = nil
    end
end

local function TweenTo(targetCFrame)
    local root = GetRoot()
    if not root then return end
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    local duration = distance / _G.Config.TweenSpeed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    CurrentTween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
    CurrentTween:Play()
    
    -- Stabilize player against anti-cheat rubberbanding
    root.AssemblyLinearVelocity = Vector3.zero
end

--============================== WEAPON MANAGEMENT ==============================
local function EquipWeapon(weaponType)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if not backpack or not char then return end
    
    -- Check if tool of desired type is already equipped
    local currentTool = char:FindFirstChildWhichIsA("Tool")
    if currentTool and (currentTool:GetAttribute("WeaponType") == weaponType or currentTool.Name:find(weaponType)) then
        return
    end
    
    -- Find and equip from backpack
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local matches = tool:GetAttribute("WeaponType") == weaponType or tool.Name:find(weaponType)
            if weaponType == "Melee" and (tool:GetAttribute("WeaponType") == "Melee" or tool.ToolTip == "Melee") then
                matches = true
            end
            if matches then
                tool.Parent = char
                break
            end
        end
    end
end

--============================== FAST ATTACK ENGINE ==============================
local function GetAttackTargets()
    local targets = {}
    local root = GetRoot()
    if not root then return targets end
    
    local searchFolders = {Workspace:FindFirstChild("Enemies"), Workspace:FindFirstChild("Characters")}
    for _, folder in pairs(searchFolders) do
        if folder then
            for _, mob in ipairs(folder:GetChildren()) do
                if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Head") then
                    if mob.Humanoid.Health > 0 and mob ~= LocalPlayer.Character then
                        local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
                        if dist <= _G.Config.FastAttackDistance then
                            table.insert(targets, mob)
                        end
                    end
                end
            end
        end
    end
    return targets
end

local function ExecuteFastAttack()
    if not _G.Config.FastAttack then return end
    local targets = GetAttackTargets()
    if #targets == 0 then return end
    
    -- Method 1: Net Modules (Instant network register)
    if RegisterAttack and RegisterHit then
        pcall(function()
            RegisterAttack:FireServer(-math.huge)
            local hitPacket = {nil, {}}
            for index, mob in ipairs(targets) do
                if not hitPacket[1] then hitPacket[1] = mob.Head end
                hitPacket[2][index] = {mob, mob.HumanoidRootPart}
            end
            RegisterHit:FireServer(unpack(hitPacket))
        end)
    end
    
    -- Method 2: Tool Activation fallback
    local char = GetCharacter()
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(_G.Config.AttackCooldown)
        pcall(ExecuteFastAttack)
    end
end)

--============================== MOB BRINGER ==============================
local function BringMobs(centerPosition)
    if not _G.Config.BringMobs then return end
    local folder = Workspace:FindFirstChild("Enemies")
    if not folder then return end
    
    for _, mob in ipairs(folder:GetChildren()) do
        if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") then
            if mob.Humanoid.Health > 0 then
                local dist = (mob.HumanoidRootPart.Position - centerPosition).Magnitude
                if dist < 300 and dist > 15 then
                    mob.HumanoidRootPart.CFrame = CFrame.new(centerPosition)
                    mob.HumanoidRootPart.CanCollide = false
                    mob.Humanoid.WalkSpeed = 0
                end
            end
        end
    end
end

--============================== AUTO FARM LOOP ==============================
local FarmThread = nil

local function GetClosestEnemy(nameFilter)
    local root = GetRoot()
    if not root then return nil end
    
    local closest, closestDist = nil, math.huge
    local folder = Workspace:FindFirstChild("Enemies")
    if not folder then return nil end
    
    for _, mob in ipairs(folder:GetChildren()) do
        if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") and mob.Humanoid.Health > 0 then
            local matches = true
            if nameFilter and nameFilter ~= "" then
                matches = mob.Name:lower():find(nameFilter:lower()) ~= nil
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
    return closest
end

local function StartAutoFarm()
    if FarmThread then task.cancel(FarmThread) end
    
    FarmThread = task.spawn(function()
        while _G.Config.AutoFarm do
            task.wait(0.1)
            local root = GetRoot()
            if not root then continue end
            
            local target = GetClosestEnemy(_G.Config.SelectedMob)
            if target and target:FindFirstChild("HumanoidRootPart") and target:FindFirstChild("Humanoid") then
                if target.Humanoid.Health > 0 then
                    local hrp = target.HumanoidRootPart
                    local farmPosition = hrp.Position + Vector3.new(0, _G.Config.FarmDistance, 0)
                    
                    -- Smoothly position above target
                    root.CFrame = CFrame.new(farmPosition, hrp.Position)
                    
                    -- Bring nearby mobs together
                    BringMobs(hrp.Position)
                    
                    -- Equip selected weapon
                    EquipWeapon(_G.Config.SelectedWeapon)
                end
            else
                StopTween()
            end
        end
        StopTween()
    end)
end

local function StopAutoFarm()
    _G.Config.AutoFarm = false
    if FarmThread then
        pcall(function() task.cancel(FarmThread) end)
        FarmThread = nil
    end
    StopTween()
end

--============================== AUTO STATS ==============================
local StatsThread = nil
local function StartAutoStats()
    if StatsThread then task.cancel(StatsThread) end
    StatsThread = task.spawn(function()
        while _G.Config.AutoStats do
            task.wait(0.5)
            local data = LocalPlayer:FindFirstChild("Data")
            if data and data:FindFirstChild("Points") and data.Points.Value > 0 then
                local statList = {"Melee", "Defense", "Sword", "Gun", "Demon Fruit"}
                for _, stat in ipairs(statList) do
                    local key = stat == "Demon Fruit" and "Fruit" or stat
                    if _G.Config.StatPoints[key] and data.Points.Value > 0 then
                        if CommF_ then
                            pcall(function() CommF_:InvokeServer("AddPoint", stat, 1) end)
                        elseif Commits then
                            pcall(function() Commits:FireServer("AddPoint", stat) end)
                        end
                    end
                end
            end
        end
    end)
end

--============================== DEVIL FRUIT SNIPER ==============================
local FruitNames = {
    "Rocket", "Spin", "Chop", "Spring", "Bomb", "Smoke", "Spike", "Flame",
    "Falcon", "Ice", "Sand", "Dark", "Diamond", "Light", "Rubber", "Barrier",
    "Magma", "Quake", "Buddha", "Love", "String", "Spider", "Sound",
    "Phoenix", "Portal", "Rumble", "Paw", "Gravity", "Dough", "Shadow",
    "Venom", "Control", "Spirit", "Dragon", "Leopard", "Kitsune", "Gas",
    "Blizzard", "Yeti"
}

local function FindSpawnedFruits()
    local fruits = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and not obj:FindFirstChild("Humanoid") then
            for _, fn in ipairs(FruitNames) do
                if obj.Name:lower():find(fn:lower()) or obj.Name:lower():find("fruit") then
                    table.insert(fruits, obj)
                    break
                end
            end
        end
    end
    return fruits
end

local function CollectFruit(fruit)
    local root = GetRoot()
    if not root or not fruit then return end
    local part = fruit:FindFirstChildWhichIsA("BasePart") or fruit:FindFirstChild("Handle")
    if not part then return end
    
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)
    
    local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and HAS_fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    end
    
    if CommF_ then
        pcall(function() CommF_:InvokeServer("StoreFruit", fruit.Name, fruit) end)
    end
end

local FruitSniperThread = nil
local function StartFruitSniper()
    if FruitSniperThread then task.cancel(FruitSniperThread) end
    FruitSniperThread = task.spawn(function()
        while _G.Config.FruitSniper do
            task.wait(1.5)
            local fruits = FindSpawnedFruits()
            if #fruits > 0 then
                CollectFruit(fruits[1])
            end
        end
    end)
end

--============================== ESP SYSTEM ==============================
local ESPObjects = {}

local function CreateESP(model, text, color)
    if ESPObjects[model] then return end
    local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    
    local bg = Instance.new("BillboardGui")
    bg.Name = "ALPHA_ESP"
    bg.Adornee = part
    bg.Size = UDim2.new(0, 200, 0, 40)
    bg.StudsOffset = Vector3.new(0, 3, 0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = _G.Config.ESPDistance
    
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = color or Color3.fromRGB(255, 60, 60)
    lbl.TextStrokeTransparency = 0
    lbl.Text = text
    lbl.Parent = bg
    
    pcall(function() bg.Parent = model end)
    ESPObjects[model] = bg
end

local function ClearAllESP()
    for model, bg in pairs(ESPObjects) do
        pcall(function() bg:Destroy() end)
    end
    ESPObjects = {}
end

task.spawn(function()
    while true do
        task.wait(1)
        if _G.Config.PlayerESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    CreateESP(p.Character, p.Name, Color3.fromRGB(255, 80, 80))
                end
            end
        end
        if _G.Config.FruitESP then
            for _, f in ipairs(FindSpawnedFruits()) do
                CreateESP(f, "DEVIL FRUIT: " .. f.Name, Color3.fromRGB(50, 255, 100))
            end
        end
    end
end)

--============================== MOVEMENT (FLY / NOCLIP) ==============================
local FlyBV, FlyBG, FlyConn
local function ToggleFly(state)
    _G.Config.FlyEnabled = state
    local root = GetRoot()
    if not root then return end
    
    if state then
        FlyBV = Instance.new("BodyVelocity")
        FlyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyBV.Velocity = Vector3.zero
        FlyBV.Parent = root
        
        FlyBG = Instance.new("BodyGyro")
        FlyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        FlyBG.CFrame = Camera.CFrame
        FlyBG.Parent = root
        
        FlyConn = RunService.RenderStepped:Connect(function()
            if not _G.Config.FlyEnabled then return end
            local dir = Vector3.zero
            local cam = Camera.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
            
            if FlyBV then FlyBV.Velocity = dir * _G.Config.FlySpeed end
            if FlyBG then FlyBG.CFrame = Camera.CFrame end
        end)
    else
        if FlyConn then FlyConn:Disconnect() end
        if FlyBV then FlyBV:Destroy() end
        if FlyBG then FlyBG:Destroy() end
    end
end

local NoclipConn
local function ToggleNoclip(state)
    _G.Config.Noclip = state
    if state then
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
        if NoclipConn then NoclipConn:Disconnect() end
    end
end

--============================== SERVER HOP ==============================
local function ServerHop()
    if not HAS_httprequest then return end
    local req = safeRequest({
        Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
        Method = "GET"
    })
    if req and req.Body then
        local ok, data = pcall(function() return HttpService:JSONDecode(req.Body) end)
        if ok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers - 1 then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    break
                end
            end
        end
    end
end

--============================== UI SETUP (REDZLIB) ==============================
local RedzLib = nil
pcall(function()
    RedzLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/farehamhz/RedzLib/main/RedzLib"))()
end)

if RedzLib then
    local Window = RedzLib:MakeWindow({
        Title = "Alpha Hub v2 : Blox Fruits",
        SubTitle = "Keyless Edition • Universal Executor",
        SaveFolder = "AlphaHubV2"
    })
    
    local MainTab = Window:MakeTab({"Main", "Home"})
    local CombatTab = Window:MakeTab({"Combat", "Sword"})
    local StatsTab = Window:MakeTab({"Stats", "BarChart"})
    local FruitTab = Window:MakeTab({"Fruits & ESP", "Eye"})
    local PlayerTab = Window:MakeTab({"Player", "User"})
    local MiscTab = Window:MakeTab({"Misc & Server", "Settings"})
    
    -- Main Tab
    MainTab:AddSection({"Auto Farm"})
    MainTab:AddToggle({
        Name = "Auto Farm Level / Nearest",
        Default = false,
        Callback = function(v)
            _G.Config.AutoFarm = v
            if v then StartAutoFarm() else StopAutoFarm() end
        end
    })
    
    MainTab:AddToggle({
        Name = "Bring Mobs (Stack)",
        Default = true,
        Callback = function(v) _G.Config.BringMobs = v end
    })
    
    MainTab:AddDropdown({
        Name = "Weapon Type",
        Options = {"Melee", "Sword", "Gun", "Fruit"},
        Default = "Melee",
        Callback = function(v) _G.Config.SelectedWeapon = v end
    })
    
    MainTab:AddSlider({
        Name = "Farm Distance Height",
        Min = 4,
        Max = 30,
        Default = 8,
        Callback = function(v) _G.Config.FarmDistance = v end
    })
    
    -- Combat Tab
    CombatTab:AddSection({"Fast Attack"})
    CombatTab:AddToggle({
        Name = "Fast Attack (RegisterHit Bypass)",
        Default = true,
        Callback = function(v) _G.Config.FastAttack = v end
    })
    
    CombatTab:AddSlider({
        Name = "Attack Range",
        Min = 20,
        Max = 120,
        Default = 65,
        Callback = function(v) _G.Config.FastAttackDistance = v end
    })
    
    -- Stats Tab
    StatsTab:AddSection({"Auto Stats Allocation"})
    StatsTab:AddToggle({
        Name = "Auto Allocate Stats",
        Default = false,
        Callback = function(v)
            _G.Config.AutoStats = v
            if v then StartAutoStats() end
        end
    })
    
    StatsTab:AddToggle({
        Name = "Points to Melee",
        Default = true,
        Callback = function(v) _G.Config.StatPoints.Melee = v end
    })
    
    StatsTab:AddToggle({
        Name = "Points to Defense",
        Default = true,
        Callback = function(v) _G.Config.StatPoints.Defense = v end
    })
    
    StatsTab:AddToggle({
        Name = "Points to Sword",
        Default = false,
        Callback = function(v) _G.Config.StatPoints.Sword = v end
    })
    
    -- Fruit & ESP Tab
    FruitTab:AddSection({"Devil Fruits"})
    FruitTab:AddToggle({
        Name = "Auto Fruit Sniper (Collect & Store)",
        Default = false,
        Callback = function(v)
            _G.Config.FruitSniper = v
            if v then StartFruitSniper() end
        end
    })
    
    FruitTab:AddSection({"Visuals"})
    FruitTab:AddToggle({
        Name = "Fruit ESP",
        Default = false,
        Callback = function(v) _G.Config.FruitESP = v end
    })
    
    FruitTab:AddToggle({
        Name = "Player ESP",
        Default = false,
        Callback = function(v) _G.Config.PlayerESP = v end
    })
    
    FruitTab:AddButton({
        Name = "Clear All ESPs",
        Callback = ClearAllESP
    })
    
    -- Player Tab
    PlayerTab:AddSection({"Movement"})
    PlayerTab:AddToggle({
        Name = "Fly (WASD + Space/Shift)",
        Default = false,
        Callback = ToggleFly
    })
    
    PlayerTab:AddSlider({
        Name = "Fly Speed",
        Min = 20,
        Max = 250,
        Default = 80,
        Callback = function(v) _G.Config.FlySpeed = v end
    })
    
    PlayerTab:AddToggle({
        Name = "Noclip (Walk through walls)",
        Default = false,
        Callback = ToggleNoclip
    })
    
    PlayerTab:AddSlider({
        Name = "Walk Speed",
        Min = 16,
        Max = 250,
        Default = 16,
        Callback = function(v)
            local char = GetCharacter()
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.WalkSpeed = v
            end
        end
    })
    
    -- Misc Tab
    MiscTab:AddSection({"Server Controls"})
    MiscTab:AddButton({
        Name = "Server Hop (Low Population)",
        Callback = ServerHop
    })
    
    MiscTab:AddButton({
        Name = "Rejoin Current Server",
        Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
    })
    
    MiscTab:AddToggle({
        Name = "Anti-AFK",
        Default = true,
        Callback = function(v)
            _G.Config.AntiAFK = v
            if v then EnableAntiAFK() elseif AntiAFKConn then AntiAFKConn:Disconnect() end
        end
    })
else
    -- Fallback ScreenGui if raw library fails to load
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AlphaHubV2_Fallback"
    ScreenGui.Parent = (CoreGui and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")
    
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 150)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -75)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    Frame.Parent = ScreenGui
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 50)
    Label.Text = "ALPHA HUB v2 (KEYLESS)"
    Label.TextColor3 = Color3.fromRGB(180, 80, 255)
    Label.Font = Enum.Font.GothamBold
    Label.TextSize = 18
    Label.BackgroundTransparency = 1
    Label.Parent = Frame
    
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -20, 0, 40)
    Btn.Position = UDim2.new(0, 10, 0, 60)
    Btn.Text = "Toggle Auto Farm"
    Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Parent = Frame
    
    Btn.MouseButton1Click:Connect(function()
        _G.Config.AutoFarm = not _G.Config.AutoFarm
        if _G.Config.AutoFarm then StartAutoFarm() else StopAutoFarm() end
        Btn.Text = "Auto Farm: " .. (_G.Config.AutoFarm and "ON" or "OFF")
    end)
end

print("[ALPHA HUB v2] Loaded successfully (Keyless Edition).")
