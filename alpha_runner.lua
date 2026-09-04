--[[
    ALPHA V2 AUTONOMOUS TEST AGENT & TELEMETRY BRIDGE
    Runs inside Roblox via Xeno Executor.
    Communicates via C:\Users\Death\AppData\Local\Xeno\workspace\alpha_bridge\
]]

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local BRIDGE_DIR = "alpha_bridge/"
local TELEMETRY_FILE = BRIDGE_DIR .. "telemetry.json"
local EVENTS_FILE = BRIDGE_DIR .. "events.log"
local COMMAND_FILE = BRIDGE_DIR .. "command.json"
local RESULTS_FILE = BRIDGE_DIR .. "test_results.json"
local LATEST_SCRIPT_FILE = BRIDGE_DIR .. "latest_script.lua"

local function LogEvent(tag, msg)
    local line = string.format("[%s] [%s] %s\n", os.date("%X"), tag, tostring(msg))
    print("[AlphaBridge] " .. line)
    pcall(function()
        if appendfile then
            appendfile(EVENTS_FILE, line)
        elseif writefile then
            writefile(EVENTS_FILE, line)
        end
    end)
end

local function WriteTelemetry(data)
    pcall(function()
        if writefile then
            writefile(TELEMETRY_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function WriteResults(results)
    pcall(function()
        if writefile then
            writefile(RESULTS_FILE, HttpService:JSONEncode(results))
        end
    end)
end

local function ReadCommand()
    local ok, res = pcall(function()
        if isfile and isfile(COMMAND_FILE) and readfile then
            local raw = readfile(COMMAND_FILE)
            return HttpService:JSONDecode(raw)
        end
        return nil
    end)
    return ok and res or nil
end

pcall(function()
    if makefolder and not (isfolder and isfolder("alpha_bridge")) then
        makefolder("alpha_bridge")
    end
end)

LogEvent("INIT", "Autonomous Test Agent attached to: " .. LocalPlayer.Name)

local function GetChar() return LocalPlayer.Character end
local function GetRoot()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChild("Humanoid")
end

local function GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    if data and data:FindFirstChild("Level") then
        return tonumber(data.Level.Value) or 1
    end
    return 1
end

local function HasQuest()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return false end
    local main = pGui:FindFirstChild("Main")
    if main then
        local q = main:FindFirstChild("Quest")
        if q and q.Visible then return true end
    end
    return false
end

local function GetCommF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        return remotes:FindFirstChild("CommF_") or remotes:FindFirstChild("CommF")
    end
    return nil
end

local NoclipConn = nil
local CurrentTween = nil
local FlightBodyVel = nil
local LandingPlatform = nil
local IsTravelingSky = false

local function EnableNoclip()
    if NoclipConn then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local c = GetChar()
        if c then
            for _, part in ipairs(c:GetDescendants()) do
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
    local c = GetChar()
    if c then
        for _, part in ipairs(c:GetDescendants()) do
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
    if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AlphaFlightBV"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Parent = root
    FlightBodyVel = bv
    return bv
end

local function StopTween()
    if CurrentTween then
        pcall(function() CurrentTween:Cancel() end)
        CurrentTween = nil
    end
    IsTravelingSky = false
    local hum = GetHum()
    if hum then hum.PlatformStand = false end
end

-- HoverLock: keeps altitude locked in mid-air
local function HoverLock(targetCF)
    local root = GetRoot()
    local hum = GetHum()
    if not root or not root.Parent then return end
    EnableNoclip()
    if hum then hum.PlatformStand = true end
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    root.CFrame = targetCF
end

-- Equip combat weapon helper
local function EquipCombatWeapon()
    local char = GetChar()
    local hum = GetHum()
    if not char or not hum then return nil end
    
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped and equipped.Name ~= "Bomb-Bomb" and not string.find(equipped.Name:lower(), "fruit") and equipped.Name ~= "Tool" then
        return equipped
    end
    
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t.Name == "Combat" or t.Name == "Black Leg" or t.Name == "Electro" or t.Name == "Fishman Karate" or string.find(t.Name:lower(), "katana") or string.find(t.Name:lower(), "sword") then
                hum:EquipTool(t)
                task.wait(0.3)
                return t
            end
        end
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not string.find(t.Name:lower(), "fruit") and not string.find(t.Name:lower(), "bomb") and t.Name ~= "Tool" then
                hum:EquipTool(t)
                task.wait(0.3)
                return t
            end
        end
    end
    return char:FindFirstChildOfClass("Tool")
end

local TelemetryState = {
    running = true,
    timestamp = os.time(),
    player = LocalPlayer.Name,
    level = GetPlayerLevel(),
    position = {x = 0, y = 0, z = 0},
    altitude = 0,
    velocity_mag = 0,
    health = 100,
    max_health = 100,
    platform_stand = false,
    body_velocity_active = false,
    active_tween = false,
    is_traveling_sky = false,
    has_quest = false,
    current_test = "IDLE",
    rollback_detected = false,
    last_rollback_delta = 0
}

task.spawn(function()
    while true do
        task.wait(0.25)
        pcall(function()
            local root = GetRoot()
            local hum = GetHum()
            if root and hum then
                local curPos = root.Position
                TelemetryState.timestamp = os.time()
                TelemetryState.level = GetPlayerLevel()
                TelemetryState.position = {x = math.floor(curPos.X*10)/10, y = math.floor(curPos.Y*10)/10, z = math.floor(curPos.Z*10)/10}
                TelemetryState.altitude = math.floor(curPos.Y*10)/10
                TelemetryState.velocity_mag = math.floor(root.AssemblyLinearVelocity.Magnitude*10)/10
                TelemetryState.health = math.floor(hum.Health)
                TelemetryState.max_health = math.floor(hum.MaxHealth)
                TelemetryState.platform_stand = hum.PlatformStand
                TelemetryState.body_velocity_active = (FlightBodyVel ~= nil and FlightBodyVel.Parent == root)
                TelemetryState.active_tween = (CurrentTween ~= nil)
                TelemetryState.is_traveling_sky = IsTravelingSky
                TelemetryState.has_quest = HasQuest()
                WriteTelemetry(TelemetryState)
            end
        end)
    end
end)

local TestResults = {
    suite_start = os.date("%X"),
    player = LocalPlayer.Name,
    sea = 1,
    tests = {}
}

local function RecordTest(name, passed, details)
    local entry = {
        name = name,
        status = passed and "PASS" or "FAIL",
        time = os.date("%X"),
        details = details or {}
    }
    table.insert(TestResults.tests, entry)
    LogEvent("TEST_" .. (passed and "PASS" or "FAIL"), name .. ": " .. HttpService:JSONEncode(details))
    WriteResults(TestResults)
    return passed
end

local function ControlledTweenTo(targetCF, label, expectedSpeed)
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then return false, "No root part" end
    
    local speed = expectedSpeed or 250
    local distance = (targetCF.Position - root.Position).Magnitude
    LogEvent("TWEEN", string.format("Starting travel to %s (Dist: %.1f studs, Speed: %d)", label, distance, speed))
    
    if distance <= 150 then
        EnableNoclip()
        hum.PlatformStand = true
        local bv = GetOrCreateBodyVelocity(root)
        bv.Velocity = Vector3.new(0, 0, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        
        local tw = TweenService:Create(root, TweenInfo.new(distance / speed, Enum.EasingStyle.Linear), {CFrame = targetCF})
        CurrentTween = tw
        tw:Play()
        tw.Completed:Wait()
        CurrentTween = nil
        HoverLock(targetCF)
        return true, "Arrived (Short Direct)"
    end
    
    IsTravelingSky = true
    
    pcall(function()
        if LocalPlayer.RequestStreamAroundAsync then
            LocalPlayer:RequestStreamAroundAsync(targetCF.Position)
        end
    end)
    
    if LandingPlatform and LandingPlatform.Parent then LandingPlatform:Destroy() end
    LandingPlatform = Instance.new("Part")
    LandingPlatform.Name = "AlphaLandingPlatform"
    LandingPlatform.Size = Vector3.new(60, 2, 60)
    LandingPlatform.CFrame = CFrame.new(targetCF.Position.X, targetCF.Position.Y - 1, targetCF.Position.Z)
    LandingPlatform.Anchored = true
    LandingPlatform.CanCollide = true
    LandingPlatform.Transparency = 1
    LandingPlatform.Parent = Workspace
    
    EnableNoclip()
    hum.PlatformStand = true
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    
    local cruiseY = 240
    if targetCF.Position.Y > 200 then
        cruiseY = targetCF.Position.Y + 45
    elseif root.Position.Y > 200 then
        cruiseY = math.max(root.Position.Y, 240)
    end
    
    if root.Position.Y < (cruiseY - 20) then
        local upCF = CFrame.new(root.Position.X, cruiseY, root.Position.Z)
        local upDist = (upCF.Position - root.Position).Magnitude
        local upTween = TweenService:Create(root, TweenInfo.new(upDist / speed, Enum.EasingStyle.Linear), {CFrame = upCF})
        CurrentTween = upTween
        upTween:Play()
        upTween.Completed:Wait()
    end
    
    if not root or not root.Parent or not IsTravelingSky then return false, "Ascent interrupted" end
    
    local skyTargetCF = CFrame.new(targetCF.Position.X, cruiseY, targetCF.Position.Z)
    local hDist = (skyTargetCF.Position - root.Position).Magnitude
    if hDist > 20 then
        local hTween = TweenService:Create(root, TweenInfo.new(hDist / speed, Enum.EasingStyle.Linear), {CFrame = skyTargetCF})
        CurrentTween = hTween
        hTween:Play()
        hTween.Completed:Wait()
    end
    
    if not root or not root.Parent or not IsTravelingSky then return false, "Cruise interrupted" end
    
    pcall(function()
        if LocalPlayer.RequestStreamAroundAsync then
            LocalPlayer:RequestStreamAroundAsync(targetCF.Position)
        end
    end)
    
    local landCF = targetCF * CFrame.new(0, 3.5, 0)
    local downDist = (landCF.Position - root.Position).Magnitude
    local downTween = TweenService:Create(root, TweenInfo.new(downDist / speed, Enum.EasingStyle.Linear), {CFrame = landCF})
    CurrentTween = downTween
    downTween:Play()
    downTween.Completed:Wait()
    
    local finalBv = GetOrCreateBodyVelocity(root)
    finalBv.Velocity = Vector3.new(0, 0, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    root.CFrame = landCF
    
    HoverLock(landCF)
    IsTravelingSky = false
    CurrentTween = nil
    
    task.spawn(function()
        task.wait(0.5)
        DisableNoclip()
        task.wait(5.0)
        if LandingPlatform and LandingPlatform.Parent then
            LandingPlatform:Destroy()
            LandingPlatform = nil
        end
    end)
    
    return true, "Touchdown completed"
end

local function RunAllTests()
    LogEvent("SUITE", "==================================================")
    LogEvent("SUITE", "STARTING AUTONOMOUS TEST BATTERY")
    LogEvent("SUITE", "==================================================")
    
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then
        RecordTest("CharacterSanity", false, {error = "Character or Root not found"})
        return
    end
    
    -- TEST 1: Baseline Physics & HoverLock
    TelemetryState.current_test = "TEST_1_HOVER_LOCK"
    LogEvent("TEST_1", "Testing BodyVelocity and HoverLock...")
    local testPos1 = root.CFrame * CFrame.new(0, 15, 0)
    HoverLock(testPos1)
    task.wait(1.5)
    local hoverDist = (root.Position - testPos1.Position).Magnitude
    local pass1 = (hoverDist < 4) and (FlightBodyVel ~= nil)
    RecordTest("HoverLockPhysics", pass1, {delta = hoverDist})
    
    -- TEST 2: Short-Range Farm Tween
    TelemetryState.current_test = "TEST_2_SHORT_TWEEN"
    LogEvent("TEST_2", "Testing short-range linear farm tween (25 studs ahead)...")
    local testPos2 = root.CFrame * CFrame.new(0, 0, -25)
    local ok2, msg2 = ControlledTweenTo(testPos2, "Short Farm Target", 200)
    task.wait(0.3)
    local shortDist = (root.Position - testPos2.Position).Magnitude
    local pass2 = ok2 and (shortDist < 8)
    RecordTest("ShortRangeTween", pass2, {delta = shortDist, status = msg2})
    
    -- TEST 3: Cross-Island Ocean Flight (REAL SEA VOYAGE)
    TelemetryState.current_test = "TEST_3_OCEAN_FLIGHT"
    LogEvent("TEST_3", "Testing cross-island flight to Pirate Village...")
    local pirateVillageCF = CFrame.new(-1181.39, 20.0, 3843.43)
    local distToPV = (pirateVillageCF.Position - root.Position).Magnitude
    LogEvent("TEST_3", string.format("Distance to Pirate Village: %.1f studs", distToPV))
    
    local t0 = tick()
    local ok3, msg3 = ControlledTweenTo(pirateVillageCF, "Pirate Village (Lv. 30)", 250)
    local flightDuration = tick() - t0
    task.wait(1.0)
    
    local landDist = (root.Position - pirateVillageCF.Position).Magnitude
    local passArrival = ok3 and (landDist < 35)
    LogEvent("TEST_3", string.format("Arrival status: %s (Dist: %.1f, Time: %.1fs)", tostring(passArrival), landDist, flightDuration))
    
    -- TEST 3b: Anti-Rollback Stability Monitor (Wait 5 full seconds at destination)
    TelemetryState.current_test = "TEST_3B_ANTI_ROLLBACK"
    LogEvent("TEST_3B", "Monitoring post-landing stability for 5 seconds to verify ZERO server rollbacks...")
    local rollbackDetected = false
    local maxDev = 0
    for i = 1, 25 do
        task.wait(0.2)
        local curD = (root.Position - pirateVillageCF.Position).Magnitude
        if curD > maxDev then maxDev = curD end
        if curD > 80 then
            rollbackDetected = true
            LogEvent("TEST_3B_FAIL", string.format("Server rollback detected! Position deviated by %.1f studs", curD))
            break
        end
    end
    
    local passFlight = passArrival and not rollbackDetected
    RecordTest("CrossIslandOceanFlight", passFlight, {
        destination = "Pirate Village",
        duration_seconds = math.floor(flightDuration*10)/10,
        arrival_dist = landDist,
        post_landing_max_dev = maxDev,
        rollback_occurred = rollbackDetected
    })
    
    -- TEST 4: Quest NPC Interaction (BuggyQuest1)
    TelemetryState.current_test = "TEST_4_QUEST_INTERACTION"
    LogEvent("TEST_4", "Testing Quest NPC interaction for BuggyQuest1...")
    local cf = GetCommF()
    local questAccepted = false
    local commFResult = nil
    
    if cf then
        HoverLock(pirateVillageCF * CFrame.new(0, 5, 0))
        task.wait(0.5)
        local okQ, resQ = pcall(function()
            return cf:InvokeServer("StartQuest", "BuggyQuest1", 1)
        end)
        commFResult = resQ
        LogEvent("TEST_4", "CommF:StartQuest BuggyQuest1 result: " .. tostring(resQ))
        task.wait(0.5)
        questAccepted = HasQuest()
    else
        LogEvent("TEST_4", "CommF remote function not found!")
    end
    
    RecordTest("QuestNPCInteraction", questAccepted, {
        quest = "BuggyQuest1",
        level = 1,
        commf_result = tostring(commFResult),
        has_quest = questAccepted
    })
    
    -- TEST 5: Mob Navigation & Combat Hit Registration
    TelemetryState.current_test = "TEST_5_COMBAT_HIT"
    LogEvent("TEST_5", "Testing mob targeting and attack registration...")
    local enemies = Workspace:FindFirstChild("Enemies")
    local mobTarget = nil
    if enemies then
        for _, m in ipairs(enemies:GetChildren()) do
            if (m.Name == "Pirate" or string.find(m.Name, "Pirate")) and m:FindFirstChild("HumanoidRootPart") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                mobTarget = m
                break
            end
        end
    end
    
    local hitRegistered = false
    local hpDelta = 0
    if mobTarget then
        local initialHp = mobTarget.Humanoid.Health
        LogEvent("TEST_5", string.format("Found mob %s with HP %.0f/%.0f. Engaging...", mobTarget.Name, initialHp, mobTarget.Humanoid.MaxHealth))
        
        -- Equip combat weapon
        local tool = EquipCombatWeapon()
        if tool then
            LogEvent("TEST_5", "Equipped weapon: " .. tool.Name)
        else
            LogEvent("TEST_5", "Warning: No weapon tool found in character or backpack")
        end
        
        -- Hover 12 studs above mob
        local farmPos = mobTarget.HumanoidRootPart.CFrame * CFrame.new(0, 7.5, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        HoverLock(farmPos)
        task.wait(0.5)
        
        -- Bring mob under player
        pcall(function()
            mobTarget.HumanoidRootPart.CFrame = farmPos * CFrame.new(0, -9, 0)
            mobTarget.HumanoidRootPart.CanCollide = false
            mobTarget.Humanoid.WalkSpeed = 0
        end)
        
        -- Get Blox Fruits combat remotes
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local regAttack = remotes and (remotes:FindFirstChild("RE/RegisterAttack") or remotes:FindFirstChild("RegisterAttack"))
        local regHit = remotes and (remotes:FindFirstChild("RE/RegisterHit") or remotes:FindFirstChild("RegisterHit"))
        
        -- Screen center click via VirtualInputManager
        local vim = game:GetService("VirtualInputManager")
        local cam = Workspace.CurrentCamera
        local cx = cam and math.floor(cam.ViewportSize.X / 2) or 400
        local cy = cam and math.floor(cam.ViewportSize.Y / 2) or 300
        
        for k = 1, 15 do
            if regAttack and regHit and mobTarget:FindFirstChild("Head") and mobTarget:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    regAttack:FireServer(0)
                    regHit:FireServer(mobTarget.Head, {{mobTarget, mobTarget.HumanoidRootPart}})
                end)
            end
            if tool then
                pcall(function() tool:Activate() end)
            end
            pcall(function()
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
            task.wait(0.12)
        end
        task.wait(0.5)
        
        local finalHp = mobTarget.Humanoid.Health
        hpDelta = initialHp - finalHp
        hitRegistered = (hpDelta > 0)
        LogEvent("TEST_5", string.format("Combat result: Initial HP=%.0f, Final HP=%.0f, Damage=%.0f, Registered=%s", initialHp, finalHp, hpDelta, tostring(hitRegistered)))
    else
        LogEvent("TEST_5", "No live Pirate mobs found in Enemies folder")
    end
    
    RecordTest("MobCombatAndDamage", hitRegistered, {
        mob_found = (mobTarget ~= nil),
        damage_dealt = hpDelta,
        hit_registered = hitRegistered
    })
    
    -- TEST 6: Return Flight (Round-Trip Ocean Navigation)
    TelemetryState.current_test = "TEST_6_RETURN_FLIGHT"
    LogEvent("TEST_6", "Testing return flight across ocean to Jungle...")
    local jungleCF = CFrame.new(-1612.33, 36.85, 149.13)
    local ok6, msg6 = ControlledTweenTo(jungleCF, "Jungle (Origin)", 250)
    task.wait(1.0)
    local returnDist = (root.Position - jungleCF.Position).Magnitude
    local passReturn = ok6 and (returnDist < 35)
    RecordTest("ReturnOceanFlight", passReturn, {
        destination = "Jungle",
        return_dist = returnDist,
        status = msg6
    })
    
    TelemetryState.current_test = "COMPLETED"
    LogEvent("SUITE", "==================================================")
    LogEvent("SUITE", "AUTONOMOUS TEST BATTERY COMPLETED")
    LogEvent("SUITE", "==================================================")
end

task.spawn(function()
    local lastCmdTimestamp = 0
    while true do
        task.wait(0.5)
        pcall(function()
            local cmdData = ReadCommand()
            if cmdData and cmdData.timestamp and cmdData.timestamp > lastCmdTimestamp then
                lastCmdTimestamp = cmdData.timestamp
                LogEvent("CMD", "Received command: " .. tostring(cmdData.cmd))
                if cmdData.cmd == "run_all_tests" then
                    task.spawn(RunAllTests)
                elseif cmdData.cmd == "reload" then
                    StopTween()
                    DisableNoclip()
                    if isfile and isfile(LATEST_SCRIPT_FILE) and readfile then
                        local src = readfile(LATEST_SCRIPT_FILE)
                        task.spawn(function() loadstring(src)() end)
                    end
                elseif cmdData.cmd == "stop" then
                    StopTween()
                    DisableNoclip()
                end
            end
        end)
    end
end)

task.spawn(function()
    task.wait(1.5)
    RunAllTests()
end)
