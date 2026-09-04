--==============================================================================
-- ALPHA V2 AUTONOMOUS IN-GAME RUNNER & IPC BRIDGE
-- Bulletproof Single-Instance Testing, Telemetry & Auto-Healing Engine
--==============================================================================

if _G.AlphaRunnerInstanceId then
    _G.AlphaRunnerRunning = false
    task.wait(0.3)
end

_G.AlphaRunnerRunning = true
_G.AlphaRunnerInstanceId = (_G.AlphaRunnerInstanceId or 0) + 1
local MY_ID = _G.AlphaRunnerInstanceId

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

local BRIDGE_DIR = "alpha_bridge"
local TELEMETRY_FILE = BRIDGE_DIR .. "/telemetry.json"
local EVENTS_FILE = BRIDGE_DIR .. "/events.log"
local RESULTS_FILE = BRIDGE_DIR .. "/test_results.json"
local COMMAND_FILE = BRIDGE_DIR .. "/command.json"
local EVAL_RESULT_FILE = BRIDGE_DIR .. "/eval_result.json"
local MASTER_V2_FILE = "alpha_v2.lua"

local function SafeWriteFile(filename, content)
    if writefile then
        pcall(function() writefile(filename, content) end)
    end
end

local function SafeAppendFile(filename, content)
    if isfile and not isfile(filename) and writefile then
        pcall(function() writefile(filename, "") end)
    end
    if appendfile then
        pcall(function() appendfile(filename, content) end)
    elseif writefile and isfile and readfile then
        pcall(function()
            local cur = isfile(filename) and readfile(filename) or ""
            writefile(filename, cur .. content)
        end)
    end
end

local function LogEvent(tag, msg)
    local line = string.format("[%s] [%s] %s\n", os.date("%X"), tag, tostring(msg))
    SafeAppendFile(EVENTS_FILE, line)
    print(line)
end

local function WriteTelemetry(data)
    SafeWriteFile(TELEMETRY_FILE, HttpService:JSONEncode(data))
end

local function WriteResults(data)
    SafeWriteFile(RESULTS_FILE, HttpService:JSONEncode(data))
end

local function ReadCommand()
    if isfile and isfile(COMMAND_FILE) and readfile then
        local ok, res = pcall(function()
            return HttpService:JSONDecode(readfile(COMMAND_FILE))
        end)
        if ok and type(res) == "table" then return res end
    end
    return nil
end

local function GetChar() return LocalPlayer.Character end
local function GetRoot()
    local char = GetChar()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end
local function GetHum()
    local char = GetChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    local lvl = data and data:FindFirstChild("Level")
    return lvl and lvl.Value or 1
end

local function HasQuest()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local main = pg:FindFirstChild("Main")
    if not main then return false end
    local qf = main:FindFirstChild("Quest")
    return (qf and qf.Visible == true)
end

local function GetCommF()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local cf = remotes:FindFirstChild("CommF_")
        if cf and cf:IsA("RemoteFunction") then return cf end
    end
    return nil
end

local FlightBodyVel = nil
local CurrentTween = nil
local IsTravelingSky = false
local LandingPlatform = nil
local NoclipConnection = nil

local function EnableNoclip()
    if NoclipConnection then return end
    NoclipConnection = RunService.Stepped:Connect(function()
        if (_G.AlphaRunnerInstanceId ~= MY_ID) or (not _G.AlphaRunnerRunning) then
            if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
            return
        end
        local char = GetChar()
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end)
end

local function DisableNoclip()
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
end

local function GetOrCreateBodyVelocity(root)
    if not FlightBodyVel or FlightBodyVel.Parent ~= root then
        if FlightBodyVel then pcall(function() FlightBodyVel:Destroy() end) end
        FlightBodyVel = Instance.new("BodyVelocity")
        FlightBodyVel.Name = "AlphaFlightBV"
        FlightBodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        FlightBodyVel.Velocity = Vector3.new(0, 0, 0)
        FlightBodyVel.Parent = root
    end
    return FlightBodyVel
end

local function StopTween()
    if CurrentTween then
        pcall(function() CurrentTween:Cancel() end)
        CurrentTween = nil
    end
    IsTravelingSky = false
end

local function HoverLock(targetCF)
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then return end
    local bv = GetOrCreateBodyVelocity(root)
    bv.Velocity = Vector3.new(0, 0, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    root.CFrame = targetCF
    hum.PlatformStand = true
end

local function ControlledTweenTo(targetCF, label, expectedSpeed)
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then return false, "No root part" end
    
    local speed = expectedSpeed or 240
    local distance = (targetCF.Position - root.Position).Magnitude
    LogEvent("TWEEN", string.format("Starting travel to %s (Dist: %.1f studs, Speed: %d)", label, distance, speed))
    
    if distance <= 80 then
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
    LandingPlatform.Size = Vector3.new(40, 2, 40)
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
    
    if not root or not root.Parent or not IsTravelingSky or (_G.AlphaRunnerInstanceId ~= MY_ID) then
        return false, "Ascent interrupted"
    end
    
    local skyTargetCF = CFrame.new(targetCF.Position.X, cruiseY, targetCF.Position.Z)
    local hDist = (skyTargetCF.Position - root.Position).Magnitude
    if hDist > 15 then
        local hTween = TweenService:Create(root, TweenInfo.new(hDist / speed, Enum.EasingStyle.Linear), {CFrame = skyTargetCF})
        CurrentTween = hTween
        hTween:Play()
        hTween.Completed:Wait()
    end
    
    if not root or not root.Parent or not IsTravelingSky or (_G.AlphaRunnerInstanceId ~= MY_ID) then
        return false, "Cruise interrupted"
    end
    
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
    hum.PlatformStand = false
    
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

local function EquipCombatWeapon()
    local char = GetChar()
    local hum = GetHum()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not hum then return nil end
    
    local fruitNames = {"bomb", "spike", "chop", "spring", "smoke", "flame", "falcon", "ice", "sand", "dark", "light", "rubber", "barrier", "magma", "quake", "human", "buddha", "fruit"}
    local function isFruit(t)
        local n = t.Name:lower()
        for _, fn in ipairs(fruitNames) do
            if n:find(fn) then return true end
        end
        return false
    end
    
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped and not isFruit(equipped) and equipped.Name ~= "Tool" then
        return equipped
    elseif equipped and isFruit(equipped) then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.1)
    end
    
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not isFruit(t) and (t.Name == "Combat" or t.Name == "Black Leg" or t.Name == "Electro" or t.Name:lower():find("katana") or t.Name:lower():find("sword") or t.Name:lower():find("cutlass")) then
                hum:EquipTool(t)
                task.wait(0.2)
                return t
            end
        end
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not isFruit(t) and t.Name ~= "Tool" then
                hum:EquipTool(t)
                task.wait(0.2)
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
    health = 100,
    max_health = 100,
    position = {x = 0, y = 0, z = 0},
    altitude = 0,
    velocity_mag = 0,
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
    while (_G.AlphaRunnerInstanceId == MY_ID) and _G.AlphaRunnerRunning do
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

local function RunAllTests()
    if (_G.AlphaRunnerInstanceId ~= MY_ID) or (not _G.AlphaRunnerRunning) then return end
    
    TestResults.suite_start = os.date("%X")
    TestResults.tests = {}
    WriteResults(TestResults)
    
    LogEvent("SUITE", "==================================================")
    LogEvent("SUITE", "STARTING AUTONOMOUS TEST BATTERY (CLEAN PASS)")
    LogEvent("SUITE", "==================================================")
    
    local root = GetRoot()
    local hum = GetHum()
    if not root or not hum then
        RecordTest("CharacterSanity", false, {error = "Character or Root not found"})
        TelemetryState.current_test = "COMPLETED"
        return
    end
    
    -- TEST 1: Baseline Physics & HoverLock
    TelemetryState.current_test = "TEST_1_HOVER_LOCK"
    LogEvent("TEST_1", "Testing BodyVelocity and HoverLock...")
    local curPos = root.CFrame
    HoverLock(curPos)
    task.wait(1.0)
    local hoverDist = (root.Position - curPos.Position).Magnitude
    local pass1 = (hoverDist < 5) and (FlightBodyVel ~= nil)
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
    
    -- TEST 3: Cross-Island Ocean Flight (REAL SEA VOYAGE TO PIRATE VILLAGE)
    TelemetryState.current_test = "TEST_3_OCEAN_FLIGHT"
    LogEvent("TEST_3", "Testing cross-island flight to Pirate Village...")
    local pirateVillageCF = CFrame.new(-1181.39, 20.0, 3843.43)
    local distToPV = (pirateVillageCF.Position - root.Position).Magnitude
    LogEvent("TEST_3", string.format("Distance to Pirate Village: %.1f studs", distToPV))
    
    local t0 = tick()
    local ok3, msg3 = ControlledTweenTo(pirateVillageCF, "Pirate Village (Lv. 30)", 240)
    local flightDuration = tick() - t0
    task.wait(0.8)
    
    local landDist = (root.Position - pirateVillageCF.Position).Magnitude
    local passArrival = ok3 and (landDist < 35)
    LogEvent("TEST_3", string.format("Arrival status: %s (Dist: %.1f, Time: %.1fs)", tostring(passArrival), landDist, flightDuration))
    
    -- TEST 3b: Anti-Rollback Stability Monitor
    TelemetryState.current_test = "TEST_3B_ANTI_ROLLBACK"
    LogEvent("TEST_3B", "Monitoring post-landing stability for 3 seconds to verify ZERO server rollbacks...")
    local rollbackDetected = false
    local maxDev = 0
    for i = 1, 15 do
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
    local questAccepted = HasQuest()
    local commFResult = nil
    
    if not questAccepted and cf then
        HoverLock(pirateVillageCF * CFrame.new(0, 5, 0))
        task.wait(0.3)
        local okQ, resQ = pcall(function()
            return cf:InvokeServer("StartQuest", "BuggyQuest1", 1)
        end)
        commFResult = resQ
        LogEvent("TEST_4", "CommF:StartQuest BuggyQuest1 result: " .. tostring(resQ))
        task.wait(0.5)
        questAccepted = HasQuest()
    elseif questAccepted then
        LogEvent("TEST_4", "Quest is already active in PlayerGui!")
    end
    
    RecordTest("QuestNPCInteraction", questAccepted, {
        quest = "BuggyQuest1",
        level = 1,
        commf_result = tostring(commFResult),
        has_quest = questAccepted
    })
    
    -- TEST 5: Mob Navigation & Combat Hit Registration
    TelemetryState.current_test = "TEST_5_COMBAT_HIT"
    LogEvent("TEST_5", "Moving toward Pirate mob area and testing attack registration...")
    
    local pirateAreaCF = CFrame.new(-1215.0, 15.0, 3915.0)
    ControlledTweenTo(pirateAreaCF, "Pirate Spawns", 200)
    task.wait(0.5)
    
    pcall(function()
        if LocalPlayer.RequestStreamAroundAsync then
            LocalPlayer:RequestStreamAroundAsync(Vector3.new(-1215, 10, 3915))
        end
    end)
    
    local mobTarget = nil
    for attempt = 1, 20 do
        local enemies = Workspace:FindFirstChild("Enemies")
        if enemies then
            for _, m in ipairs(enemies:GetChildren()) do
                if (m.Name == "Pirate" or string.find(m.Name, "Pirate")) and m:FindFirstChild("HumanoidRootPart") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                    mobTarget = m
                    break
                end
            end
            if not mobTarget then
                for _, m in ipairs(enemies:GetChildren()) do
                    if m:FindFirstChild("HumanoidRootPart") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                        mobTarget = m
                        break
                    end
                end
            end
        end
        if mobTarget then break end
        task.wait(0.4)
    end
    
    local hitRegistered = false
    local hpDelta = 0
    if mobTarget then
        local initialHp = mobTarget.Humanoid.Health
        LogEvent("TEST_5", string.format("Found mob %s with HP %.0f/%.0f. Engaging...", mobTarget.Name, initialHp, mobTarget.Humanoid.MaxHealth))
        
        local tool = EquipCombatWeapon()
        if tool then
            LogEvent("TEST_5", "Equipped weapon: " .. tool.Name)
        else
            LogEvent("TEST_5", "Warning: No combat weapon equipped")
        end
        
        local farmPos = mobTarget.HumanoidRootPart.CFrame * CFrame.new(0, 7.5, 0) * CFrame.Angles(math.rad(-90), 0, 0)
        HoverLock(farmPos)
        task.wait(0.3)
        
        pcall(function()
            mobTarget.HumanoidRootPart.CFrame = farmPos * CFrame.new(0, -7.5, 0)
            mobTarget.HumanoidRootPart.CanCollide = false
            mobTarget.Humanoid.WalkSpeed = 0
        end)
        
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local regAttack = remotes and (remotes:FindFirstChild("RE/RegisterAttack") or remotes:FindFirstChild("RegisterAttack"))
        local regHit = remotes and (remotes:FindFirstChild("RE/RegisterHit") or remotes:FindFirstChild("RegisterHit"))
        
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
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
            task.wait(0.12)
        end
        task.wait(0.5)
        
        local finalHp = mobTarget.Humanoid.Health
        hpDelta = initialHp - finalHp
        hitRegistered = (hpDelta > 0)
        LogEvent("TEST_5", string.format("Combat result: Initial HP=%.0f, Final HP=%.0f, Damage=%.0f, Registered=%s", initialHp, finalHp, hpDelta, tostring(hitRegistered)))
    else
        LogEvent("TEST_5", "No live mobs found in Enemies folder after 8s polling")
    end
    
    RecordTest("MobCombatAndDamage", hitRegistered, {
        mob_found = (mobTarget ~= nil),
        damage_dealt = hpDelta,
        hit_registered = hitRegistered
    })
    
    -- TEST 6: Return Flight (Round-Trip Ocean Navigation to Jungle)
    TelemetryState.current_test = "TEST_6_RETURN_FLIGHT"
    LogEvent("TEST_6", "Testing return flight across ocean to Jungle...")
    local jungleCF = CFrame.new(-1612.33, 36.85, 149.13)
    local ok6, msg6 = ControlledTweenTo(jungleCF, "Jungle (Origin)", 240)
    task.wait(0.8)
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

-- Command Dispatcher
task.spawn(function()
    local lastCmdTimestamp = 0
    while (_G.AlphaRunnerInstanceId == MY_ID) and _G.AlphaRunnerRunning do
        task.wait(0.3)
        pcall(function()
            local cmdData = ReadCommand()
            if cmdData and cmdData.timestamp and cmdData.timestamp > lastCmdTimestamp then
                lastCmdTimestamp = cmdData.timestamp
                local c = cmdData.cmd
                LogEvent("CMD", "Executing command: " .. tostring(c))
                
                -- Consume command immediately
                pcall(function()
                    SafeWriteFile(COMMAND_FILE, HttpService:JSONEncode({cmd = "consumed", timestamp = lastCmdTimestamp}))
                end)
                
                if c == "run_all_tests" then
                    task.spawn(RunAllTests)
                elseif c == "eval" and cmdData.code then
                    local fn, err = loadstring(cmdData.code)
                    if fn then
                        local okEval, resEval = pcall(fn)
                        SafeWriteFile(EVAL_RESULT_FILE, HttpService:JSONEncode({success = okEval, result = tostring(resEval)}))
                    else
                        SafeWriteFile(EVAL_RESULT_FILE, HttpService:JSONEncode({success = false, error = tostring(err)}))
                    end
                elseif c == "safe_land" then
                    StopTween()
                    local root = GetRoot()
                    if root then
                        local groundCF = CFrame.new(root.Position.X, 25, root.Position.Z)
                        ControlledTweenTo(groundCF, "Safe Ground Landing", 150)
                    end
                elseif c == "run_alpha_v2" then
                    StopTween()
                    DisableNoclip()
                    if isfile and isfile(MASTER_V2_FILE) and readfile then
                        local src = readfile(MASTER_V2_FILE)
                        task.spawn(function()
                            loadstring(src)()
                            task.wait(1.0)
                            if _G.Config then
                                _G.Config.AutoFarmLevel = true
                                LogEvent("AUTOFARM", "Activated _G.Config.AutoFarmLevel = true!")
                            end
                        end)
                    end
                elseif c == "stop" then
                    StopTween()
                    DisableNoclip()
                end
            end
        end)
    end
end)

LogEvent("RUNNER", "Alpha Runner v2.2 loaded successfully (Instance #" .. tostring(MY_ID) .. ")")

-- Auto-start test suite on clean boot
task.spawn(function()
    task.wait(3.0)
    if (_G.AlphaRunnerInstanceId == MY_ID) and _G.AlphaRunnerRunning then
        RunAllTests()
    end
end)
