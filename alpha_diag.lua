--[[
    ALPHA MOVEMENT & TWEEN DIAGNOSTIC (v1)
    Specifically built to diagnose Blox Fruits movement rollback / rubberbanding.
    Tests 6 movement techniques and measures exact server rollback timing.
    Results are automatically copied to your clipboard when finished!
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LP = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart", 10)
local hum = char:WaitForChild("Humanoid", 10)

local logs = {}
local function log(msg)
    table.insert(logs, msg)
    print("[ALPHA DIAG] " .. msg)
end

log("==================================================")
log(" ALPHA MOVEMENT & TWEEN DIAGNOSTIC REPORT")
log(" Date/Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
log(" PlaceId: " .. tostring(game.PlaceId))
log(" Player: " .. tostring(LP.Name))
log("==================================================")

-- 1. BASELINE ENVIRONMENT CHECKS
log("\n[1] CHARACTER & PHYSICS BASELINE:")
log("  Root exists: " .. tostring(root ~= nil))
log("  Root Anchored: " .. tostring(root and root.Anchored))
log("  Humanoid Health: " .. tostring(hum and hum.Health or "N/A"))
log("  Humanoid PlatformStand: " .. tostring(hum and hum.PlatformStand))
log("  Humanoid Sit: " .. tostring(hum and hum.Sit))
log("  Humanoid WalkSpeed: " .. tostring(hum and hum.WalkSpeed))
log("  Humanoid State: " .. tostring(hum and hum:GetState().Name or "N/A"))
log("  Current Position: " .. tostring(root and root.Position or "N/A"))
log("  AssemblyLinearVelocity: " .. tostring(root and root.AssemblyLinearVelocity or "N/A"))

local hasNetOwner = false
pcall(function()
    hasNetOwner = root and root:CanSetNetworkOwnership() or false
end)
log("  Can Set Network Ownership: " .. tostring(hasNetOwner))

-- Scan for existing BodyMovers
local movers = {}
for _, v in ipairs(root:GetChildren()) do
    if v:IsA("BodyMover") or v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") or v:IsA("LinearVelocity") then
        table.insert(movers, v.ClassName .. " (" .. v.Name .. ")")
    end
end
log("  Existing Root BodyMovers: " .. (#movers > 0 and table.concat(movers, ", ") or "None"))

-- Check for Character collision state
local canCollideCount = 0
for _, p in ipairs(char:GetDescendants()) do
    if p:IsA("BasePart") and p.CanCollide then
        canCollideCount = canCollideCount + 1
    end
end
log("  Collidable Parts in Character: " .. canCollideCount)

-- 2. CREATE IN-GAME LIVE HUD
local sg = Instance.new("ScreenGui")
sg.Name = "AlphaDiagHUD"
sg.ResetOnSpawn = false
pcall(function()
    if gethui then sg.Parent = gethui()
    else sg.Parent = LP:WaitForChild("PlayerGui") end
end)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 320)
mainFrame.Position = UDim2.new(0.5, -240, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 42, 95)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 35)
title.Position = UDim2.new(0, 10, 0, 5)
title.Text = "ALPHA DIAGNOSTIC — TESTING MOVEMENT..."
title.TextColor3 = Color3.fromRGB(255, 60, 110)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local logBox = Instance.new("ScrollingFrame")
logBox.Size = UDim2.new(1, -20, 1, -50)
logBox.Position = UDim2.new(0, 10, 0, 42)
logBox.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
logBox.BorderSizePixel = 0
logBox.ScrollBarThickness = 4
logBox.Parent = mainFrame

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -10, 0, 1000)
logLabel.Position = UDim2.new(0, 5, 0, 5)
logLabel.BackgroundTransparency = 1
logLabel.Text = "Running movement tests...\nPlease do not touch WASD/mouse controls for 15 seconds."
logLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.Parent = logBox

local function updateHUD()
    logLabel.Text = table.concat(logs, "\n")
    logLabel.Size = UDim2.new(1, -10, 0, #logs * 16 + 50)
    logBox.CanvasSize = UDim2.new(0, 0, 0, #logs * 16 + 60)
    logBox.CanvasPosition = Vector2.new(0, #logs * 16 + 60)
end

task.wait(1.5)

-- 3. TEST SUITE
task.spawn(function()
    local origin = root.Position
    
    -- TEST A: DIRECT CFRAME INSTANT TELEPORT (+25 studs up)
    log("\n[TEST A] Direct CFrame Shift (+25 studs UP):")
    local testAPos = origin + Vector3.new(0, 25, 0)
    root.CFrame = CFrame.new(testAPos)
    task.wait(0.1)
    local pos1 = root.Position
    log("  After 100ms pos: " .. string.format("%.1f, %.1f, %.1f", pos1.X, pos1.Y, pos1.Z))
    task.wait(0.5)
    local pos2 = root.Position
    local diffA = (pos2 - testAPos).Magnitude
    log("  After 600ms pos: " .. string.format("%.1f, %.1f, %.1f", pos2.X, pos2.Y, pos2.Z))
    if diffA > 10 then
        log("  RESULT: FAILED! Rolled back / dropped by " .. math.floor(diffA) .. " studs")
    else
        log("  RESULT: PASSED! Position held (drift: " .. string.format("%.1f", diffA) .. " studs)")
    end
    updateHUD()
    task.wait(1)

    -- TEST B: TWEENSERVICE ON HRP (+60 studs horizontally)
    log("\n[TEST B] TweenService on HumanoidRootPart directly (+60 studs):")
    local startB = root.Position
    local targetB = startB + root.CFrame.LookVector * 60
    local tween = TweenService:Create(root, TweenInfo.new(1.0, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetB)})
    tween:Play()
    
    local rollbackDetected = false
    local maxDistReached = 0
    local t0 = tick()
    
    while (tick() - t0) < 1.5 do
        task.wait(0.05)
        local curDist = (root.Position - startB).Magnitude
        if curDist > maxDistReached then maxDistReached = curDist end
        -- Check if moving backwards towards start
        if maxDistReached > 15 and curDist < (maxDistReached - 10) and not rollbackDetected then
            rollbackDetected = true
            log("  ROLLBACK TRIGGERED at " .. string.format("%.2f", tick() - t0) .. "s! Reached " .. math.floor(maxDistReached) .. " studs then snapped back!")
        end
    end
    local finalDistB = (root.Position - targetB).Magnitude
    log("  Max distance reached during tween: " .. math.floor(maxDistReached) .. "/60 studs")
    log("  End distance from target: " .. math.floor(finalDistB) .. " studs")
    if rollbackDetected or finalDistB > 15 then
        log("  RESULT: FAILED! TweenService suffers server rollback.")
    else
        log("  RESULT: PASSED! TweenService completed without rollback.")
    end
    updateHUD()
    task.wait(1)

    -- TEST C: BODYVELOCITY WITH ZERO VELOCITY (ANTIGRAVITY HOVER TEST)
    log("\n[TEST C] BodyVelocity Hover Lock (Testing Antigravity):")
    local startC = root.Position
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DiagBV"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Parent = root
    
    task.wait(1.5)
    local dropC = (root.Position.Y - startC.Y)
    log("  Y-Axis displacement after 1.5s: " .. string.format("%.2f", dropC) .. " studs")
    if math.abs(dropC) > 2 then
        log("  RESULT: FAILED! BodyVelocity is being overridden/ignored by game physics!")
    else
        log("  RESULT: PASSED! BodyVelocity holds altitude perfectly.")
    end
    bv:Destroy()
    updateHUD()
    task.wait(1)

    -- TEST D: BODYVELOCITY PROPULSION (PHYSICS FLIGHT)
    log("\n[TEST D] BodyVelocity Velocity-Driven Propulsion (+80 studs):")
    local startD = root.Position
    local bvD = Instance.new("BodyVelocity")
    bvD.Name = "DiagPropulse"
    local flyDir = root.CFrame.LookVector
    bvD.Velocity = flyDir * 150
    bvD.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bvD.Parent = root
    
    local dMax = 0
    local dRollback = false
    local tD = tick()
    while (tick() - tD) < 1.0 do
        task.wait(0.05)
        local d = (root.Position - startD).Magnitude
        if d > dMax then dMax = d end
        if dMax > 20 and d < (dMax - 10) and not dRollback then
            dRollback = true
            log("  Propulsion snapped back at " .. string.format("%.2f", tick() - tD) .. "s!")
        end
    end
    bvD.Velocity = Vector3.new(0, 0, 0)
    task.wait(0.3)
    bvD:Destroy()
    log("  Distance traveled via BodyVelocity: " .. math.floor(dMax) .. " studs")
    if dRollback then
        log("  RESULT: FAILED! BodyVelocity propulsion triggered server rollback.")
    else
        log("  RESULT: PASSED! BodyVelocity propulsion moved character smoothly.")
    end
    updateHUD()
    task.wait(1)

    -- TEST E: HEARTBEAT STEPPED LERP (PHYSICS-STEP SYNCHRONIZED)
    log("\n[TEST E] RunService.Heartbeat Step-Lerp (+60 studs):")
    local startE = root.Position
    local targetE = startE + root.CFrame.RightVector * 60
    local stepConn
    local eRollback = false
    local eMax = 0
    local tE = tick()
    
    stepConn = RunService.Heartbeat:Connect(function(dt)
        if not root or not root.Parent then return end
        local dir = (targetE - root.Position)
        if dir.Magnitude < 2 then
            stepConn:Disconnect()
            stepConn = nil
            return
        end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.CFrame = root.CFrame + dir.Unit * math.min(150 * dt, dir.Magnitude)
    end)
    
    while (tick() - tE) < 1.5 do
        task.wait(0.05)
        local cur = (root.Position - startE).Magnitude
        if cur > eMax then eMax = cur end
        if eMax > 15 and cur < (eMax - 10) and not eRollback then
            eRollback = true
            log("  Heartbeat lerp rollback at " .. string.format("%.2f", tick() - tE) .. "s!")
        end
    end
    if stepConn then stepConn:Disconnect() end
    log("  Heartbeat lerp max distance: " .. math.floor(eMax) .. "/60 studs")
    if eRollback then
        log("  RESULT: FAILED! Heartbeat lerp triggered rollback.")
    else
        log("  RESULT: PASSED! Heartbeat step lerp completed.")
    end
    updateHUD()
    task.wait(0.5)

    -- SUMMARY & AUTO-COPY TO CLIPBOARD
    log("\n==================================================")
    log(" DIAGNOSTIC COMPLETE!")
    log(" Copying full report to clipboard...")
    log("==================================================")
    updateHUD()
    
    local fullReport = table.concat(logs, "\n")
    pcall(function()
        if setclipboard then
            setclipboard(fullReport)
            log(">> SUCCESS: REPORT COPIED TO CLIPBOARD! <<")
        elseif syn and syn.write_clipboard then
            syn.write_clipboard(fullReport)
            log(">> SUCCESS: REPORT COPIED TO CLIPBOARD! <<")
        else
            log(">> Notice: setclipboard not supported by executor. Please copy from F9 console! <<")
        end
    end)
    updateHUD()
    title.Text = "ALPHA DIAGNOSTIC — COMPLETE (COPIED TO CLIPBOARD)"
    title.TextColor3 = Color3.fromRGB(0, 255, 120)
end)
