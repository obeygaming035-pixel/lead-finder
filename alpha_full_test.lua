--[[
    ALPHA V2 COMPREHENSIVE DIAGNOSTIC
    Tests EVERY feature of alpha_v2.lua and reports exact behavior.
    Results are auto-copied to clipboard when done.
    Run this INSTEAD of alpha_v2 (stop alpha_v2 first).
]]

-- Wait for game
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local PlaceId = game.PlaceId
local Sea1 = (PlaceId == 2753915549)
local Sea2 = (PlaceId == 4442272183)
local Sea3 = (PlaceId == 7449423635)
local SeaName = Sea1 and "First Sea" or (Sea2 and "Second Sea" or (Sea3 and "Third Sea" or "Unknown"))

local report = {}
local testNum = 0

local function Log(msg)
    testNum = testNum + 1
    local line = "[" .. testNum .. "] " .. msg
    table.insert(report, line)
    print(line)
end

local function Section(title)
    local sep = string.rep("=", 60)
    table.insert(report, "")
    table.insert(report, sep)
    table.insert(report, " " .. title)
    table.insert(report, sep)
    print("\n" .. sep)
    print(" " .. title)
    print(sep)
end

local function SafeCall(fn)
    local ok, err = pcall(fn)
    if not ok then
        Log("ERROR: " .. tostring(err))
    end
    return ok
end

-- Helper to get character/root safely
local function GetChar()
    return LocalPlayer.Character
end
local function GetRoot()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChild("Humanoid")
end

-- HUD for live status
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "AlphaDiagHUD"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 9999999
if gethui then
    pcall(function() hudGui.Parent = gethui() end)
end
if not hudGui.Parent then
    hudGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5)
end

local hudLabel = Instance.new("TextLabel")
hudLabel.Size = UDim2.new(0.5, 0, 0, 40)
hudLabel.Position = UDim2.new(0.25, 0, 0, 10)
hudLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hudLabel.BackgroundTransparency = 0.4
hudLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
hudLabel.Font = Enum.Font.Code
hudLabel.TextSize = 14
hudLabel.Text = "ALPHA DIAGNOSTIC: Starting..."
hudLabel.Parent = hudGui

local function UpdateHUD(msg)
    hudLabel.Text = "DIAG: " .. msg
end

---------- CLEANUP ANY RUNNING ALPHA V2 ----------
Section("PHASE 0: CLEANUP EXISTING ALPHA V2")
UpdateHUD("Cleaning up...")

SafeCall(function()
    -- Destroy AlphaFlightBV
    local root = GetRoot()
    if root then
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
                Log("Destroying existing BodyMover: " .. child.Name .. " (" .. child.ClassName .. ")")
                child:Destroy()
            end
        end
    end
    -- Kill alpha v2 GUI
    local guiParent = gethui and gethui() or LocalPlayer:FindFirstChild("PlayerGui")
    if guiParent then
        for _, child in ipairs(guiParent:GetChildren()) do
            if child:IsA("ScreenGui") and child:GetAttribute("_uid") == "v2h" then
                Log("Destroying existing Alpha V2 ScreenGui: " .. child.Name)
                child:Destroy()
            end
        end
    end
    -- Reset globals
    if _G.Config then
        Log("Existing _G.Config found - resetting AutoFarmLevel")
        _G.Config.AutoFarmLevel = false
        _G.Config.FarmSelectedMob = false
        _G.Config.FarmSelectedBoss = false
        _G.Config.FarmAllBosses = false
    end
    _G.UIInteracting = false
end)

-- Reset humanoid state
SafeCall(function()
    local hum = GetHum()
    if hum then
        hum.PlatformStand = false
    end
end)
task.wait(0.5)

---------- TEST 1: ENVIRONMENT & EXECUTOR ----------
Section("PHASE 1: ENVIRONMENT & EXECUTOR CAPABILITIES")
UpdateHUD("Testing executor...")

Log("Player: " .. tostring(LocalPlayer.Name))
Log("PlaceId: " .. tostring(PlaceId))
Log("Sea: " .. SeaName)
Log("GameId: " .. tostring(game.GameId))
Log("JobId: " .. tostring(game.JobId))

-- Executor capabilities
local caps = {
    {"gethui", gethui},
    {"setclipboard", setclipboard},
    {"firetouchinterest", firetouchinterest},
    {"getgenv", getgenv},
    {"hookfunction", hookfunction},
    {"hookmetamethod", hookmetamethod},
    {"getrawmetatable", getrawmetatable},
    {"newcclosure", newcclosure},
    {"sethiddenproperty", sethiddenproperty},
    {"getnamecallmethod", getnamecallmethod},
    {"Drawing", Drawing},
    {"isexecutorclosure", isexecutorclosure},
    {"getconnections", getconnections},
}
for _, c in ipairs(caps) do
    Log("Capability [" .. c[1] .. "]: " .. (c[2] and "YES" or "NO"))
end

-- VirtualInputManager
local VIMExists = pcall(function() return game:GetService("VirtualInputManager") end)
Log("VirtualInputManager: " .. (VIMExists and "YES" or "NO"))

---------- TEST 2: CHARACTER & PHYSICS ----------
Section("PHASE 2: CHARACTER & PHYSICS STATE")
UpdateHUD("Testing character...")

SafeCall(function()
    local root = GetRoot()
    local hum = GetHum()
    local char = GetChar()
    
    Log("Character exists: " .. tostring(char ~= nil))
    Log("Root exists: " .. tostring(root ~= nil))
    Log("Humanoid exists: " .. tostring(hum ~= nil))
    
    if root then
        Log("Root Anchored: " .. tostring(root.Anchored))
        Log("Root Position: " .. tostring(root.Position))
        Log("AssemblyLinearVelocity: " .. tostring(root.AssemblyLinearVelocity))
        Log("Can Set NetworkOwnership: " .. tostring(pcall(function() root:SetNetworkOwner(LocalPlayer) end)))
        
        -- Count existing body movers
        local movers = {}
        for _, child in ipairs(root:GetChildren()) do
            if child:IsA("BodyMover") then
                table.insert(movers, child.Name .. "(" .. child.ClassName .. ")")
            end
        end
        Log("Existing BodyMovers on Root: " .. (#movers > 0 and table.concat(movers, ", ") or "NONE"))
        
        -- Check collidable parts
        local collidable = 0
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                collidable = collidable + 1
            end
        end
        Log("Collidable parts in character: " .. collidable)
    end
    
    if hum then
        Log("Health: " .. hum.Health .. " / " .. hum.MaxHealth)
        Log("WalkSpeed: " .. hum.WalkSpeed)
        Log("JumpPower: " .. hum.JumpPower)
        Log("PlatformStand: " .. tostring(hum.PlatformStand))
        Log("Sit: " .. tostring(hum.Sit))
        Log("HumanoidStateType: " .. tostring(hum:GetState()))
    end
end)

---------- TEST 3: PLAYER DATA ----------
Section("PHASE 3: PLAYER DATA & LEVEL")
UpdateHUD("Testing player data...")

SafeCall(function()
    local data = LocalPlayer:FindFirstChild("Data")
    Log("Data folder exists: " .. tostring(data ~= nil))
    
    if data then
        local children = {}
        for _, child in ipairs(data:GetChildren()) do
            local val = ""
            pcall(function() val = tostring(child.Value) end)
            table.insert(children, child.Name .. "=" .. val .. " (" .. child.ClassName .. ")")
        end
        for i, c in ipairs(children) do
            Log("Data." .. c)
        end
        
        local level = data:FindFirstChild("Level")
        if level then
            Log("Player Level: " .. tostring(level.Value))
        end
        
        local quest = data:FindFirstChild("Quest")
        if quest then
            Log("Data.Quest value: '" .. tostring(quest.Value) .. "'")
        end
    end
end)

---------- TEST 4: REMOTES ----------
Section("PHASE 4: REMOTE DISCOVERY")
UpdateHUD("Scanning remotes...")

SafeCall(function()
    local remotes = RS:FindFirstChild("Remotes")
    Log("ReplicatedStorage.Remotes exists: " .. tostring(remotes ~= nil))
    
    if remotes then
        local rfList = {}
        local reList = {}
        for _, r in ipairs(remotes:GetChildren()) do
            if r:IsA("RemoteFunction") then
                table.insert(rfList, r.Name)
            elseif r:IsA("RemoteEvent") then
                table.insert(reList, r.Name)
            end
        end
        table.sort(rfList)
        table.sort(reList)
        Log("RemoteFunctions (" .. #rfList .. "): " .. table.concat(rfList, ", "))
        Log("RemoteEvents (" .. #reList .. "): " .. table.concat(reList, ", "))
    end
    
    -- Check Net module
    local modules = RS:FindFirstChild("Modules")
    Log("RS.Modules exists: " .. tostring(modules ~= nil))
    if modules then
        local net = modules:FindFirstChild("Net")
        Log("RS.Modules.Net exists: " .. tostring(net ~= nil))
        if net then
            local netChildren = {}
            for _, child in ipairs(net:GetDescendants()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    table.insert(netChildren, child:GetFullName():gsub("ReplicatedStorage.Modules.Net.", ""))
                end
            end
            table.sort(netChildren)
            for _, n in ipairs(netChildren) do
                Log("  Net Remote: " .. n)
            end
        end
    end
    
    -- CommF_ test
    local commF = remotes and remotes:FindFirstChild("CommF_")
    Log("CommF_ RemoteFunction: " .. (commF and "FOUND" or "NOT FOUND"))
    
    -- Commits test
    local commits = remotes and remotes:FindFirstChild("Commits")
    Log("Commits RemoteEvent: " .. (commits and "FOUND" or "NOT FOUND"))
end)

---------- TEST 5: QUEST SYSTEM ----------
Section("PHASE 5: QUEST DETECTION")
UpdateHUD("Testing quest system...")

SafeCall(function()
    -- Method 1: PlayerGui.Main.Quest
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    Log("PlayerGui exists: " .. tostring(pGui ~= nil))
    
    if pGui then
        local main = pGui:FindFirstChild("Main")
        Log("PlayerGui.Main exists: " .. tostring(main ~= nil))
        if main then
            local quest = main:FindFirstChild("Quest")
            Log("PlayerGui.Main.Quest exists: " .. tostring(quest ~= nil))
            if quest then
                Log("Quest.Visible: " .. tostring(quest.Visible))
                Log("Quest ClassName: " .. quest.ClassName)
                -- Try to read quest text
                for _, child in ipairs(quest:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Text ~= "" then
                        Log("Quest text found: '" .. child.Text:sub(1, 80) .. "'")
                    end
                end
            end
        end
        
        -- Method 2: Deep scan for Quest frames
        local questFrames = {}
        for _, v in ipairs(pGui:GetDescendants()) do
            if v.Name == "Quest" and v:IsA("Frame") then
                table.insert(questFrames, v:GetFullName() .. " (Visible=" .. tostring(v.Visible) .. ")")
            end
        end
        Log("Quest frames found (" .. #questFrames .. "): " .. (#questFrames > 0 and table.concat(questFrames, "; ") or "NONE"))
    end
    
    -- Method 3: Data.Quest
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local qVal = data:FindFirstChild("Quest")
        Log("Data.Quest: " .. (qVal and ("'" .. tostring(qVal.Value) .. "'") or "NOT FOUND"))
    end
end)

---------- TEST 6: CommF_ INVOKE TESTS ----------
Section("PHASE 6: CommF_ REMOTE INVOKE TESTS")
UpdateHUD("Testing CommF_ calls...")

SafeCall(function()
    local remotes = RS:FindFirstChild("Remotes")
    local commF = remotes and remotes:FindFirstChild("CommF_")
    if not commF then
        Log("SKIP: CommF_ not found")
        return
    end
    
    -- Test Buso Haki
    local busoOk, busoRes = pcall(function()
        return commF:InvokeServer("Buso")
    end)
    Log("CommF_:InvokeServer('Buso'): ok=" .. tostring(busoOk) .. " result=" .. tostring(busoRes))
    
    -- Test getting current quest info
    local data = LocalPlayer:FindFirstChild("Data")
    local level = 1
    if data and data:FindFirstChild("Level") then
        level = data.Level.Value
    end
    Log("Testing StartQuest for level " .. level)
    
    -- Find appropriate quest for current level
    local QuestsDB = {
        {Min = 1, Max = 9, Quest = "BanditQuest1", Level = 1, Mob = "Bandit"},
        {Min = 10, Max = 14, Quest = "JungleQuest", Level = 1, Mob = "Monkey"},
        {Min = 15, Max = 29, Quest = "JungleQuest", Level = 2, Mob = "Gorilla"},
        {Min = 30, Max = 39, Quest = "BuggyQuest1", Level = 1, Mob = "Pirate"},
        {Min = 40, Max = 59, Quest = "BuggyQuest1", Level = 2, Mob = "Brute"},
        {Min = 60, Max = 74, Quest = "DesertQuest", Level = 1, Mob = "Desert Bandit"},
        {Min = 75, Max = 89, Quest = "DesertQuest", Level = 2, Mob = "Desert Officer"},
        {Min = 90, Max = 99, Quest = "SnowQuest", Level = 1, Mob = "Snow Bandit"},
        {Min = 100, Max = 119, Quest = "SnowQuest", Level = 2, Mob = "Snowman"},
    }
    
    local questInfo = nil
    for _, q in ipairs(QuestsDB) do
        if level >= q.Min and level <= q.Max then
            questInfo = q
            break
        end
    end
    
    if questInfo then
        Log("Quest for level " .. level .. ": " .. questInfo.Quest .. " Lv." .. questInfo.Level .. " -> " .. questInfo.Mob)
        local sqOk, sqRes = pcall(function()
            return commF:InvokeServer("StartQuest", questInfo.Quest, questInfo.Level)
        end)
        Log("CommF_:InvokeServer('StartQuest', '" .. questInfo.Quest .. "', " .. questInfo.Level .. "): ok=" .. tostring(sqOk) .. " result=" .. tostring(sqRes))
    else
        Log("No quest mapping for level " .. level .. " in diagnostic DB (only Sea 1 low levels)")
    end
    
    -- Test AddPoint
    local apOk, apRes = pcall(function()
        return commF:InvokeServer("AddPoint", "Melee", 0)
    end)
    Log("CommF_:InvokeServer('AddPoint', 'Melee', 0): ok=" .. tostring(apOk) .. " result=" .. tostring(apRes))
    
    -- Test requestEntrance
    local reOk, reRes = pcall(function()
        return commF:InvokeServer("requestEntrance", Vector3.new(0, 100, 0))
    end)
    Log("CommF_:InvokeServer('requestEntrance', ...): ok=" .. tostring(reOk) .. " result=" .. tostring(reRes))
end)

---------- TEST 7: WORKSPACE ENEMIES ----------
Section("PHASE 7: ENEMY / MOB SYSTEM")
UpdateHUD("Scanning enemies...")

SafeCall(function()
    local enemies = Workspace:FindFirstChild("Enemies")
    Log("Workspace.Enemies exists: " .. tostring(enemies ~= nil))
    
    if enemies then
        local mobCounts = {}
        local aliveMobs = {}
        local deadMobs = 0
        local totalMobs = 0
        
        for _, mob in ipairs(enemies:GetChildren()) do
            if mob:IsA("Model") then
                totalMobs = totalMobs + 1
                local hum = mob:FindFirstChild("Humanoid")
                local hrp = mob:FindFirstChild("HumanoidRootPart")
                
                if hum and hum.Health > 0 and hrp then
                    if not mobCounts[mob.Name] then
                        mobCounts[mob.Name] = {count = 0, health = hum.Health, maxHP = hum.MaxHealth}
                    end
                    mobCounts[mob.Name].count = mobCounts[mob.Name].count + 1
                    table.insert(aliveMobs, mob.Name)
                elseif hum and hum.Health <= 0 then
                    deadMobs = deadMobs + 1
                end
            end
        end
        
        Log("Total mob models: " .. totalMobs)
        Log("Dead mobs: " .. deadMobs)
        Log("Alive mob types: " .. #aliveMobs)
        
        -- Sort and display
        local sortedMobs = {}
        for name, info in pairs(mobCounts) do
            table.insert(sortedMobs, {name = name, count = info.count, hp = info.maxHP})
        end
        table.sort(sortedMobs, function(a, b) return a.count > b.count end)
        
        for i, m in ipairs(sortedMobs) do
            if i <= 20 then
                Log("  Mob: " .. m.name .. " x" .. m.count .. " (MaxHP: " .. m.hp .. ")")
            end
        end
        if #sortedMobs > 20 then
            Log("  ... and " .. (#sortedMobs - 20) .. " more mob types")
        end
        
        -- FindEnemy test - find closest mob
        local root = GetRoot()
        if root and #aliveMobs > 0 then
            local closest, closestDist, closestName = nil, math.huge, ""
            for _, mob in ipairs(enemies:GetChildren()) do
                if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                    local dist = (mob.HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = mob
                        closestName = mob.Name
                    end
                end
            end
            if closest then
                Log("Closest alive mob: " .. closestName .. " at " .. math.floor(closestDist) .. " studs")
                Log("  Mob Position: " .. tostring(closest.HumanoidRootPart.Position))
                Log("  Mob Health: " .. closest.Humanoid.Health .. "/" .. closest.Humanoid.MaxHealth)
            end
        end
    end
end)

---------- TEST 8: WEAPON / TOOL SYSTEM ----------
Section("PHASE 8: WEAPON & TOOL SYSTEM")
UpdateHUD("Testing weapons...")

SafeCall(function()
    local char = GetChar()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    
    -- List all tools in backpack
    if bp then
        local tools = {}
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local tip = tool:FindFirstChild("ToolTip") and tool.ToolTip or ""
                local hasCombat = tool:FindFirstChild("Combat") ~= nil
                table.insert(tools, tool.Name .. " [ToolTip='" .. tip .. "', Combat=" .. tostring(hasCombat) .. "]")
            end
        end
        Log("Backpack tools (" .. #tools .. "):")
        for _, t in ipairs(tools) do
            Log("  " .. t)
        end
    else
        Log("Backpack: NOT FOUND")
    end
    
    -- Check currently equipped tool
    if char then
        local equipped = char:FindFirstChildOfClass("Tool")
        if equipped then
            Log("Currently equipped: " .. equipped.Name .. " [ToolTip='" .. (equipped.ToolTip or "") .. "']")
        else
            Log("Currently equipped: NONE")
        end
    end
    
    -- Test IsWeaponType classification
    local meleeStyles = {"combat", "black leg", "electro", "water kung fu", "dragon claw", "superhuman", "death step", "sharkman karate", "electric claw", "dragon talon", "godhuman", "sanguine art"}
    
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local tip = tool.ToolTip or ""
                local name = tool.Name:lower()
                local classified = "Unknown"
                
                if tip == "Melee" or tool:FindFirstChild("Combat") then
                    classified = "Melee"
                else
                    for _, m in ipairs(meleeStyles) do
                        if name:find(m) then classified = "Melee"; break end
                    end
                end
                if tip == "Sword" or tip == "Melee Weapon" then classified = "Sword" end
                if tip == "Gun" then classified = "Gun" end
                if tip == "Blox Fruit" or name:find("fruit") then classified = "Fruit" end
                
                Log("Classification: " .. tool.Name .. " -> " .. classified)
            end
        end
    end
    
    -- Test equip/unequip
    Log("Testing Humanoid:EquipTool / UnequipTools...")
    local hum = GetHum()
    if hum and bp then
        local firstTool = nil
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then firstTool = t; break end
        end
        if firstTool then
            Log("Equipping: " .. firstTool.Name)
            local eqOk = pcall(function() hum:EquipTool(firstTool) end)
            Log("EquipTool result: " .. tostring(eqOk))
            task.wait(0.3)
            local nowEquipped = char:FindFirstChildOfClass("Tool")
            Log("After equip, holding: " .. (nowEquipped and nowEquipped.Name or "NOTHING"))
            
            Log("Unequipping...")
            pcall(function() hum:UnequipTools() end)
            task.wait(0.2)
            nowEquipped = char:FindFirstChildOfClass("Tool")
            Log("After unequip, holding: " .. (nowEquipped and nowEquipped.Name or "NOTHING"))
        else
            Log("No tools in backpack to test equip")
        end
    end
end)

---------- TEST 9: COMBAT REMOTES ----------
Section("PHASE 9: COMBAT REMOTE TESTS")
UpdateHUD("Testing combat remotes...")

SafeCall(function()
    local modules = RS:FindFirstChild("Modules")
    if not modules then
        Log("RS.Modules NOT FOUND - combat remotes unavailable")
        return
    end
    
    local net = modules:FindFirstChild("Net")
    if not net then
        Log("RS.Modules.Net NOT FOUND")
        return
    end
    
    -- Find RegisterAttack
    local regAttack = nil
    local regHit = nil
    for _, child in ipairs(net:GetDescendants()) do
        if child.Name == "RE" and child:IsA("Folder") then
            regAttack = child:FindFirstChild("RegisterAttack")
            regHit = child:FindFirstChild("RegisterHit")
        end
        if child:GetFullName():find("RE/RegisterAttack") or (child.Name == "RegisterAttack" and child:IsA("RemoteEvent")) then
            regAttack = child
        end
        if child:GetFullName():find("RE/RegisterHit") or (child.Name == "RegisterHit" and child:IsA("RemoteEvent")) then
            regHit = child
        end
    end
    
    -- Also try direct path
    if not regAttack then
        local re = net:FindFirstChild("RE")
        if re then
            regAttack = re:FindFirstChild("RegisterAttack")
            regHit = re:FindFirstChild("RegisterHit")
        end
    end
    
    Log("RegisterAttack: " .. (regAttack and ("FOUND at " .. regAttack:GetFullName()) or "NOT FOUND"))
    Log("RegisterHit: " .. (regHit and ("FOUND at " .. regHit:GetFullName()) or "NOT FOUND"))
    
    -- Test firing RegisterAttack
    if regAttack then
        local ok = pcall(function()
            regAttack:FireServer(0)
        end)
        Log("RegisterAttack:FireServer(0): " .. (ok and "SUCCESS" or "FAILED"))
    end
    
    -- List all remote events in Net
    Log("All remotes under Modules.Net:")
    for _, child in ipairs(net:GetDescendants()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            Log("  " .. child.ClassName .. ": " .. child:GetFullName():gsub("ReplicatedStorage.Modules.Net.", ""))
        end
    end
end)

---------- TEST 10: MOVEMENT TESTS ----------
Section("PHASE 10: MOVEMENT & TWEEN TESTS")
UpdateHUD("Testing movement...")

-- Store initial position
local startPos = nil
SafeCall(function()
    local root = GetRoot()
    if root then startPos = root.Position end
end)

-- Test A: Direct CFrame set (small move)
SafeCall(function()
    Log("TEST A: Direct CFrame set (+10 studs forward)")
    local root = GetRoot()
    if not root then Log("SKIP: no root"); return end
    
    local before = root.Position
    local target = root.CFrame * CFrame.new(0, 0, -10)
    root.CFrame = target
    task.wait(0.05)
    local after1 = root.Position
    task.wait(0.3)
    local after2 = root.Position
    task.wait(0.7)
    local after3 = root.Position
    
    local moved1 = (after1 - before).Magnitude
    local moved2 = (after2 - before).Magnitude
    local moved3 = (after3 - before).Magnitude
    
    Log("  Before: " .. tostring(before))
    Log("  After 50ms: " .. string.format("%.1f studs moved", moved1) .. " pos=" .. tostring(after1))
    Log("  After 350ms: " .. string.format("%.1f studs moved", moved2) .. " pos=" .. tostring(after2))
    Log("  After 1050ms: " .. string.format("%.1f studs moved", moved3) .. " pos=" .. tostring(after3))
    
    if moved3 < 3 then
        Log("  RESULT: ROLLED BACK - CFrame set does not persist")
    elseif moved3 >= 8 then
        Log("  RESULT: SUCCESS - position held")
    else
        Log("  RESULT: PARTIAL - moved " .. string.format("%.1f", moved3) .. " studs")
    end
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.3)
    end
end)

-- Test B: BodyVelocity creation & persistence
SafeCall(function()
    Log("TEST B: BodyVelocity creation and persistence")
    local root = GetRoot()
    if not root then Log("SKIP: no root"); return end
    
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DiagTestBV"
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = root
    
    task.wait(0.1)
    local exists1 = root:FindFirstChild("DiagTestBV") ~= nil
    Log("  BV exists after 100ms: " .. tostring(exists1))
    
    task.wait(0.5)
    local exists2 = root:FindFirstChild("DiagTestBV") ~= nil
    Log("  BV exists after 600ms: " .. tostring(exists2))
    
    task.wait(1.0)
    local exists3 = root:FindFirstChild("DiagTestBV") ~= nil
    Log("  BV exists after 1600ms: " .. tostring(exists3))
    
    if exists3 then
        Log("  RESULT: BodyVelocity PERSISTS - game does NOT destroy it")
    else
        Log("  RESULT: BodyVelocity DESTROYED by game scripts after creation!")
    end
    
    -- Test hover lock (BV + CFrame)
    if exists3 or exists2 then
        Log("  Testing hover with BV (Velocity=0, hold position)...")
        local bvRef = root:FindFirstChild("DiagTestBV")
        if bvRef then
            local holdPos = root.Position
            bvRef.Velocity = Vector3.new(0, 0, 0)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            task.wait(1.5)
            local drift = (root.Position - holdPos).Magnitude
            Log("  After 1.5s hover, drift: " .. string.format("%.2f studs", drift))
            if drift < 2 then
                Log("  HOVER: SUCCESS - character stays in place")
            else
                Log("  HOVER: FAILED - drifted " .. string.format("%.1f", drift) .. " studs (Y=" .. string.format("%.1f", root.Position.Y - holdPos.Y) .. ")")
            end
        end
    end
    
    -- Cleanup
    pcall(function()
        local bvClean = root:FindFirstChild("DiagTestBV")
        if bvClean then bvClean:Destroy() end
    end)
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.3)
    end
end)

-- Test C: TweenService on HumanoidRootPart (short distance)
SafeCall(function()
    Log("TEST C: TweenService on HRP (30 studs)")
    local root = GetRoot()
    if not root then Log("SKIP: no root"); return end
    
    local before = root.Position
    local targetCF = root.CFrame * CFrame.new(0, 0, -30)
    
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCF})
    
    local maxDist = 0
    local rollbackDetected = false
    local rollbackTime = 0
    
    local monConn
    local t0 = tick()
    monConn = RunService.Heartbeat:Connect(function()
        if not root or not root.Parent then monConn:Disconnect(); return end
        local d = (root.Position - before).Magnitude
        if d > maxDist then maxDist = d end
        if maxDist > 10 and d < maxDist * 0.5 and not rollbackDetected then
            rollbackDetected = true
            rollbackTime = tick() - t0
        end
    end)
    
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.5)
    monConn:Disconnect()
    
    local finalDist = (root.Position - before).Magnitude
    Log("  Max distance reached: " .. string.format("%.1f studs", maxDist))
    Log("  Final distance: " .. string.format("%.1f studs", finalDist))
    if rollbackDetected then
        Log("  ROLLBACK detected at " .. string.format("%.2fs", rollbackTime))
        Log("  RESULT: TWEEN ROLLED BACK")
    elseif finalDist > 25 then
        Log("  RESULT: TWEEN SUCCESS (30 stud short range)")
    else
        Log("  RESULT: TWEEN PARTIAL - only " .. string.format("%.1f", finalDist) .. " studs")
    end
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.3)
    end
end)

-- Test D: TweenService on HRP (long distance 200 studs)
SafeCall(function()
    Log("TEST D: TweenService on HRP (200 studs)")
    local root = GetRoot()
    if not root then Log("SKIP: no root"); return end
    
    local before = root.Position
    local targetCF = root.CFrame * CFrame.new(0, 0, -200)
    
    local speed = 350
    local time = 200 / speed
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCF})
    
    local maxDist = 0
    local rollbackDetected = false
    local rollbackTime = 0
    local positions = {}
    
    local monConn
    local t0 = tick()
    monConn = RunService.Heartbeat:Connect(function()
        if not root or not root.Parent then monConn:Disconnect(); return end
        local d = (root.Position - before).Magnitude
        local elapsed = tick() - t0
        if d > maxDist then maxDist = d end
        if maxDist > 30 and d < maxDist * 0.5 and not rollbackDetected then
            rollbackDetected = true
            rollbackTime = elapsed
        end
        if elapsed < 2 then
            table.insert(positions, {t = elapsed, d = d, pos = root.Position})
        end
    end)
    
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.5)
    monConn:Disconnect()
    
    local finalDist = (root.Position - before).Magnitude
    Log("  Max distance reached: " .. string.format("%.1f studs", maxDist))
    Log("  Final distance: " .. string.format("%.1f studs", finalDist))
    
    -- Log sample positions
    for i, p in ipairs(positions) do
        if i % 5 == 1 or i == #positions then
            Log("  t=" .. string.format("%.2f", p.t) .. "s dist=" .. string.format("%.1f", p.d))
        end
    end
    
    if rollbackDetected then
        Log("  ROLLBACK at " .. string.format("%.2fs", rollbackTime))
        Log("  RESULT: LONG TWEEN ROLLED BACK")
    elseif finalDist > 180 then
        Log("  RESULT: LONG TWEEN SUCCESS")
    else
        Log("  RESULT: LONG TWEEN PARTIAL - " .. string.format("%.1f", finalDist) .. " studs")
    end
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.3)
    end
end)

-- Test E: Noclip + BV + TweenService combo (what alpha_v2 actually does)
SafeCall(function()
    Log("TEST E: Alpha V2 combo (Noclip + BV + TweenService) 100 studs")
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then Log("SKIP"); return end
    
    local before = root.Position
    local targetCF = root.CFrame * CFrame.new(0, 0, -100)
    
    -- Enable noclip
    local noclipConn = RunService.Stepped:Connect(function()
        local char = GetChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
    
    -- Create BV
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DiagComboBV"
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    local dir = (targetCF.Position - root.Position).Unit
    bv.Velocity = dir * 350
    bv.Parent = root
    
    hum.PlatformStand = true
    
    -- TweenService
    local speed = 350
    local dist = 100
    local time = dist / speed
    local tween = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = targetCF})
    
    local maxDist = 0
    local rollbackDetected = false
    local rollbackTime = 0
    
    local monConn
    local t0 = tick()
    monConn = RunService.Heartbeat:Connect(function()
        if not root or not root.Parent then monConn:Disconnect(); return end
        local d = (root.Position - before).Magnitude
        if d > maxDist then maxDist = d end
        if maxDist > 20 and d < maxDist * 0.3 and not rollbackDetected then
            rollbackDetected = true
            rollbackTime = tick() - t0
        end
    end)
    
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.5)
    monConn:Disconnect()
    
    -- Stop
    hum.PlatformStand = false
    bv.Velocity = Vector3.new(0, 0, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    task.wait(0.3)
    
    local finalDist = (root.Position - before).Magnitude
    Log("  Max distance: " .. string.format("%.1f studs", maxDist))
    Log("  Final distance: " .. string.format("%.1f studs", finalDist))
    Log("  BV still exists: " .. tostring(root:FindFirstChild("DiagComboBV") ~= nil))
    
    if rollbackDetected then
        Log("  ROLLBACK at " .. string.format("%.2fs", rollbackTime))
        Log("  RESULT: COMBO ROLLED BACK")
    elseif finalDist > 80 then
        Log("  RESULT: COMBO SUCCESS")
    else
        Log("  RESULT: COMBO PARTIAL - " .. string.format("%.1f", finalDist) .. " studs")
    end
    
    -- Cleanup
    noclipConn:Disconnect()
    pcall(function() bv:Destroy() end)
    hum.PlatformStand = false
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.3)
    end
end)

-- Test F: Heartbeat step-lerp (frame-by-frame CFrame)
SafeCall(function()
    Log("TEST F: Heartbeat step-lerp (frame-by-frame CFrame set) 50 studs")
    local root = GetRoot()
    if not root then Log("SKIP"); return end
    
    local before = root.Position
    local targetCF = root.CFrame * CFrame.new(0, 0, -50)
    local speed = 200
    local maxDist = 0
    local rollbackDetected = false
    local rollbackTime = 0
    local done = false
    
    -- Noclip
    local noclipConn = RunService.Stepped:Connect(function()
        local char = GetChar()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
    
    local t0 = tick()
    local lerpConn
    lerpConn = RunService.Heartbeat:Connect(function(dt)
        if done or not root or not root.Parent then
            if lerpConn then lerpConn:Disconnect() end
            return
        end
        local remaining = (targetCF.Position - root.Position).Magnitude
        local d = (root.Position - before).Magnitude
        if d > maxDist then maxDist = d end
        if maxDist > 15 and d < maxDist * 0.4 and not rollbackDetected then
            rollbackDetected = true
            rollbackTime = tick() - t0
        end
        
        if remaining < 3 then
            done = true
            lerpConn:Disconnect()
            return
        end
        
        local step = math.min(speed * dt, remaining)
        local dir = (targetCF.Position - root.Position).Unit
        root.CFrame = root.CFrame + dir * step
    end)
    
    -- Wait up to 3 seconds
    local t0Wait = tick()
    while not done and (tick() - t0Wait) < 3 do
        task.wait(0.1)
    end
    if lerpConn then pcall(function() lerpConn:Disconnect() end) end
    noclipConn:Disconnect()
    
    local finalDist = (root.Position - before).Magnitude
    Log("  Max distance: " .. string.format("%.1f studs", maxDist))
    Log("  Final distance: " .. string.format("%.1f studs", finalDist))
    
    if rollbackDetected then
        Log("  ROLLBACK at " .. string.format("%.2fs", rollbackTime))
        Log("  RESULT: STEP-LERP ROLLED BACK")
    elseif finalDist > 40 then
        Log("  RESULT: STEP-LERP SUCCESS")
    else
        Log("  RESULT: STEP-LERP PARTIAL - " .. string.format("%.1f", finalDist) .. " studs")
    end
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.5)
    end
end)

-- Test G: Rapid small CFrame teleports (5 studs at a time)
SafeCall(function()
    Log("TEST G: Rapid small CFrame teleports (5 studs x 20 = 100 studs)")
    local root = GetRoot()
    if not root then Log("SKIP"); return end
    
    local before = root.Position
    local dir = root.CFrame.LookVector
    local maxDist = 0
    
    for i = 1, 20 do
        if not root or not root.Parent then break end
        root.CFrame = root.CFrame + dir * 5
        task.wait(0.05)
        local d = (root.Position - before).Magnitude
        if d > maxDist then maxDist = d end
    end
    
    task.wait(0.5)
    local finalDist = (root.Position - before).Magnitude
    Log("  Max distance: " .. string.format("%.1f studs", maxDist))
    Log("  Final distance: " .. string.format("%.1f studs", finalDist))
    
    if finalDist > 80 then
        Log("  RESULT: RAPID TP SUCCESS")
    elseif finalDist > 40 then
        Log("  RESULT: RAPID TP PARTIAL (some rollback)")
    else
        Log("  RESULT: RAPID TP FAILED")
    end
end)

task.wait(0.5)

-- Reset position
SafeCall(function()
    local root = GetRoot()
    if root and startPos then
        root.CFrame = CFrame.new(startPos)
        task.wait(0.3)
    end
end)

---------- TEST 11: GUI SYSTEM ----------
Section("PHASE 11: GUI & UI SYSTEM")
UpdateHUD("Testing GUI...")

SafeCall(function()
    -- Test gethui
    if gethui then
        local ok, gui = pcall(gethui)
        Log("gethui(): " .. (ok and ("SUCCESS - " .. tostring(gui)) or "FAILED"))
    else
        Log("gethui: NOT AVAILABLE")
    end
    
    -- Test ScreenGui creation
    local testGui = Instance.new("ScreenGui")
    testGui.Name = "DiagTestGui"
    testGui.ResetOnSpawn = false
    
    local guiParent = nil
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then guiParent = res end
    end
    if not guiParent then
        guiParent = LocalPlayer:FindFirstChild("PlayerGui")
    end
    
    if guiParent then
        testGui.Parent = guiParent
        Log("ScreenGui created: " .. tostring(testGui.Parent ~= nil))
        
        -- Test Active property
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 100, 0, 100)
        frame.Active = true
        frame.Parent = testGui
        Log("Frame with Active=true created")
        
        -- Test that it's visible
        Log("ScreenGui.Enabled: " .. tostring(testGui.Enabled))
        
        -- Cleanup
        testGui:Destroy()
        Log("Test GUI destroyed cleanly")
    else
        Log("Could not find GUI parent!")
    end
end)

---------- TEST 12: ANTI-CHEAT BEHAVIOR ANALYSIS ----------
Section("PHASE 12: ANTI-CHEAT BEHAVIOR ANALYSIS")
UpdateHUD("Analyzing anti-cheat...")

SafeCall(function()
    -- Check for anti-cheat related scripts
    local suspiciousScripts = {}
    for _, child in ipairs(LocalPlayer.PlayerScripts:GetDescendants()) do
        if child:IsA("LocalScript") then
            local name = child.Name:lower()
            if name:find("anti") or name:find("cheat") or name:find("detect") or name:find("security") or name:find("ban") or name:find("monitor") then
                table.insert(suspiciousScripts, child.Name .. " (" .. child:GetFullName() .. ") Enabled=" .. tostring(child.Enabled))
            end
        end
    end
    Log("Suspicious scripts in PlayerScripts (" .. #suspiciousScripts .. "):")
    for _, s in ipairs(suspiciousScripts) do
        Log("  " .. s)
    end
    
    -- Check StarterPlayer scripts
    local starterScripts = {}
    pcall(function()
        local sp = game:GetService("StarterPlayer")
        if sp then
            for _, child in ipairs(sp:GetDescendants()) do
                if child:IsA("LocalScript") then
                    table.insert(starterScripts, child.Name)
                end
            end
        end
    end)
    Log("StarterPlayer LocalScripts: " .. table.concat(starterScripts, ", "))
    
    -- Check for BodyMover cleanup scripts by monitoring
    Log("Monitoring BodyMover persistence (creating test BV for 3s)...")
    local root = GetRoot()
    if root then
        local testBV = Instance.new("BodyVelocity")
        testBV.Name = "ACTestBV"
        testBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        testBV.Velocity = Vector3.new(0, 0, 0)
        testBV.Parent = root
        
        local destroyed = false
        local destroyTime = 0
        local t0 = tick()
        
        testBV.AncestryChanged:Connect(function(_, newParent)
            if not newParent and not destroyed then
                destroyed = true
                destroyTime = tick() - t0
            end
        end)
        
        task.wait(3)
        
        if destroyed then
            Log("  BodyVelocity was DESTROYED by game after " .. string.format("%.2fs", destroyTime))
            Log("  CONCLUSION: Game has active BodyMover cleanup scripts!")
        else
            Log("  BodyVelocity SURVIVED 3 seconds")
            Log("  CONCLUSION: Game does NOT aggressively destroy BodyMovers")
            pcall(function() testBV:Destroy() end)
        end
    end
end)

---------- TEST 13: sethiddenproperty ----------
Section("PHASE 13: SIMULATION RADIUS")
UpdateHUD("Testing sim radius...")

SafeCall(function()
    if sethiddenproperty then
        local ok1 = pcall(function()
            sethiddenproperty(LocalPlayer, "SimulationRadius", 1000)
        end)
        Log("sethiddenproperty SimulationRadius=1000: " .. (ok1 and "SUCCESS" or "FAILED"))
        
        local ok2 = pcall(function()
            sethiddenproperty(LocalPlayer, "MaxSimulationRadius", 1000)
        end)
        Log("sethiddenproperty MaxSimulationRadius=1000: " .. (ok2 and "SUCCESS" or "FAILED"))
        
        -- Reset
        pcall(function()
            sethiddenproperty(LocalPlayer, "SimulationRadius", 100)
        end)
    else
        Log("sethiddenproperty NOT AVAILABLE")
    end
end)

---------- TEST 14: VirtualInputManager ----------
Section("PHASE 14: VIRTUALINPUTMANAGER & SKILL CASTING")
UpdateHUD("Testing VIM...")

SafeCall(function()
    local ok, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok and VIM then
        Log("VIM service acquired: YES")
        
        -- Test SendKeyEvent
        local keyOk = pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.Z, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
        end)
        Log("VIM:SendKeyEvent(Z): " .. (keyOk and "SUCCESS" or "FAILED"))
    else
        Log("VIM service: NOT AVAILABLE")
        
        -- Test fallback
        if keypress and keyrelease then
            Log("keypress/keyrelease: AVAILABLE")
        else
            Log("keypress/keyrelease: NOT AVAILABLE")
        end
    end
end)

---------- TEST 15: WORKSPACE STRUCTURE ----------
Section("PHASE 15: WORKSPACE GAME STRUCTURE")
UpdateHUD("Scanning workspace...")

SafeCall(function()
    -- Check key workspace children
    local keyChildren = {"Enemies", "Characters", "_WorldOrigin", "Map", "Terrain", "Camera", "Sea"}
    for _, name in ipairs(keyChildren) do
        local child = Workspace:FindFirstChild(name)
        Log("Workspace." .. name .. ": " .. (child and (child.ClassName .. " (" .. #child:GetChildren() .. " children)") or "NOT FOUND"))
    end
    
    -- Check for Locations
    local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
    if worldOrigin then
        local locations = worldOrigin:FindFirstChild("Locations")
        if locations then
            local locNames = {}
            for _, loc in ipairs(locations:GetChildren()) do
                table.insert(locNames, loc.Name)
            end
            table.sort(locNames)
            Log("Locations (" .. #locNames .. "): " .. table.concat(locNames, ", "):sub(1, 300))
        end
    end
    
    -- Check for dropped fruits
    local droppedFruits = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") then
            table.insert(droppedFruits, obj.Name .. " [" .. (obj.ToolTip or "?") .. "]")
        end
    end
    Log("Dropped tools in Workspace (" .. #droppedFruits .. "): " .. (#droppedFruits > 0 and table.concat(droppedFruits, ", ") or "NONE"))
end)

---------- FINALIZE ----------
Section("DIAGNOSTIC COMPLETE")
UpdateHUD("Done! Copying to clipboard...")

local timestamp = os.date("%Y-%m-%d %H:%M:%S")
local header = {
    "==================================================",
    " ALPHA V2 COMPREHENSIVE DIAGNOSTIC REPORT",
    " Date/Time: " .. timestamp,
    " PlaceId: " .. tostring(PlaceId),
    " Sea: " .. SeaName,
    " Player: " .. tostring(LocalPlayer.Name),
    "==================================================",
    ""
}

local fullReport = table.concat(header, "\n") .. table.concat(report, "\n")

-- Copy to clipboard
if setclipboard then
    pcall(function()
        setclipboard(fullReport)
    end)
    Log("Results copied to clipboard! Paste anywhere to share.")
    UpdateHUD("DONE - Results in clipboard!")
else
    Log("setclipboard not available - printing full report to console")
    print("\n\n" .. fullReport)
    UpdateHUD("DONE - Check console output")
end

-- Keep HUD visible for 30 seconds then cleanup
task.spawn(function()
    task.wait(30)
    if hudGui and hudGui.Parent then
        hudGui:Destroy()
    end
end)

print("\n[DIAGNOSTIC] All tests complete. " .. testNum .. " log entries generated.")
