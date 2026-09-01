local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local LT = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local SG = game:GetService("StarterGui")
local TP = game:GetService("TeleportService")
local LP = Players.LocalPlayer
local twait = (task and task.wait) or wait
local tspawn = (task and task.spawn) or spawn

-- Executor compatibility
local _firetouchinterest = nil
pcall(function() _firetouchinterest = firetouchinterest end)
local _fireproximityprompt = nil
pcall(function() _fireproximityprompt = fireproximityprompt end)

-- VirtualInputManager for click simulation
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- GUI parent
local guiParent = nil
pcall(function() guiParent = game:GetService("CoreGui") end)
if not guiParent then pcall(function() guiParent = LP:WaitForChild("PlayerGui") end) end

local loadHub

local S = {
    autoFarm = false, autoLevel = false,
    killAura = false, auraRange = 200,
    bringMob = false, bringRange = 200,
    autoM1 = false, attackSpeed = 0.2,
    targetMode = "Nearest",
    fly = false, flySpeed = 80,
    noclip = false, godMode = false, noKB = false,
    walkSpeed = 16, jumpPower = 50, infJump = false,
    mobESP = false, fruitESP = false,
    fpsBst = false, antiAFK = true,
    notifications = true, debugPanel = false,
    farmMob = "Any", farmIsland = "None",
    farmState = "IDLE", currentTarget = nil,
    emergencyStop = false,
    selectedIsland = "None",
}

local function notify(title, text)
    if not S.notifications then return end
    pcall(function()
        SG:SetCore("SendNotification", {Title=title, Text=text, Duration=3})
    end)
end

local Islands = {
    {name = "Starter Island", level = 1, mob = "Bandit", cframe = CFrame.new(1059, 16, 1549)},
    {name = "Jungle", level = 15, mob = "Monkey", cframe = CFrame.new(-1612, 36, 149)},
    {name = "Pirate Village", level = 30, mob = "Pirate", cframe = CFrame.new(-1140, 4, 3828)},
    {name = "Desert", level = 60, mob = "Desert Bandit", cframe = CFrame.new(896, 6, 4388)},
    {name = "Middle Town", level = 100, mob = "None", cframe = CFrame.new(-690, 7, 1523)},
    {name = "Frozen Village", level = 90, mob = "Snow Bandit", cframe = CFrame.new(1185, 27, -1218)},
    {name = "Marine Fortress", level = 120, mob = "Chief Petty Officer", cframe = CFrame.new(-4806, 20, 4360)},
    {name = "Skylands", level = 150, mob = "Sky Bandit", cframe = CFrame.new(-4867, 717, -2625)},
    {name = "Prison", level = 190, mob = "Prisoner", cframe = CFrame.new(4875, 5, 734)},
    {name = "Colosseum", level = 225, mob = "Toga Warrior", cframe = CFrame.new(-1390, 7, -2763)},
    {name = "Magma Village", level = 300, mob = "Military Soldier", cframe = CFrame.new(-5312, 12, 8515)},
    {name = "Underwater City", level = 375, mob = "Fishman Warrior", cframe = CFrame.new(61163, 11, 1569)},
    {name = "Fountain City", level = 625, mob = "Galley Pirate", cframe = CFrame.new(5257, 38, 4050)}
}

local function IslandByLevel(lvl)
    local best = Islands[1]
    for _, isl in ipairs(Islands) do
        if lvl >= isl.level and isl.level > best.level then
            best = isl
        end
    end
    return best
end

local function GetMobForLevel(lvl)
    return IslandByLevel(lvl).mob
end

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LP.Character
    return c and c:FindFirstChild("Humanoid")
end
local function getLevel()
    local lvl = 1
    pcall(function()
        if LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level") then lvl = LP.Data.Level.Value
        elseif LP:FindFirstChild("leaderstats") and LP.leaderstats:FindFirstChild("Level") then lvl = LP.leaderstats.Level.Value end
    end)
    return lvl
end

print("[VEIL] firetouchinterest: " .. tostring(_firetouchinterest ~= nil))
print("[VEIL] VirtualInputManager: " .. tostring(VIM ~= nil))

local function getMobs()
    local mobs = {}
    local searched = {}
    local function scan(f)
        if not f then return end
        for _, v in ipairs(f:GetChildren()) do
            if v:IsA("Model") and v ~= LP.Character and not searched[v] then
                local h = v:FindFirstChild("Humanoid")
                local r = v:FindFirstChild("HumanoidRootPart")
                if h and r and h.Health > 0 then
                    searched[v] = true
                    table.insert(mobs, v)
                end
            end
        end
    end
    scan(WS:FindFirstChild("Enemies"))
    scan(WS:FindFirstChild("Enemy"))
    scan(WS:FindFirstChild("Mobs"))
    scan(WS:FindFirstChild("NPCs"))
    scan(WS)
    return mobs
end

local function findNearest(name)
    local hrp = getHRP()
    if not hrp then return nil end
    local best, dist = nil, math.huge
    for _, m in ipairs(getMobs()) do
        if name == "Any" or m.Name == name then
            local mr = m:FindFirstChild("HumanoidRootPart")
            if mr then
                local d = (hrp.Position - mr.Position).Magnitude
                if d < dist then dist = d; best = m end
            end
        end
    end
    return best
end

local function teleportTo(cf)
    for i = 1, 30 do
        local hrp = getHRP()
        if not hrp then break end
        hrp.CFrame = cf
        hrp.Velocity = Vector3.new(0,0,0)
        RunS.Heartbeat:Wait()
    end
end

local function equipWeapon()
    pcall(function()
        local c = LP.Character
        if not c or c:FindFirstChildOfClass("Tool") then return end
        local bp = LP:FindFirstChild("Backpack")
        if bp then
            for _, t in pairs(bp:GetChildren()) do
                if t:IsA("Tool") then t.Parent = c; return end
            end
        end
    end)
end

local function doAttack()
    pcall(function()
        if VIM then
            local vp = WS.CurrentCamera.ViewportSize
            VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
            VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
        end
    end)
    pcall(function()
        local c = LP.Character
        if c then
            local t = c:FindFirstChildOfClass("Tool")
            if t then t:Activate() end
        end
    end)
end

local function touchAttack(mob)
    pcall(function()
        if not _firetouchinterest then return end
        local c = LP.Character
        if not c then return end
        local tool = c:FindFirstChildOfClass("Tool")
        if not tool then return end
        local handle = tool:FindFirstChild("Handle")
        if not handle then
            for _, p in pairs(tool:GetDescendants()) do
                if p:IsA("BasePart") then handle = p; break end
            end
        end
        if not handle then return end
        for _, part in pairs(mob:GetChildren()) do
            if part:IsA("BasePart") then
                _firetouchinterest(handle, part, 0)
                _firetouchinterest(handle, part, 1)
            end
        end
    end)
end

local kaActive = false
local function kaStart()
    if kaActive then return end
    kaActive = true
    tspawn(function()
        while S.killAura do
            if S.emergencyStop then break end
            local hrp = getHRP()
            if hrp and getHum() and getHum().Health > 0 then
                equipWeapon()
                local savedCF = hrp.CFrame
                local mobs = getMobs()
                for _, mob in ipairs(mobs) do
                    if not S.killAura or S.emergencyStop then break end
                    local mhum = mob:FindFirstChild("Humanoid")
                    local mhrp = mob:FindFirstChild("HumanoidRootPart")
                    if mhum and mhrp and mhum.Health > 0 then
                        local dist = (savedCF.Position - mhrp.Position).Magnitude
                        if dist <= S.auraRange then
                            hrp.CFrame = mhrp.CFrame * CFrame.new(0, 0, 3)
                            doAttack()
                            touchAttack(mob)
                        end
                    end
                end
                hrp = getHRP()
                if hrp then hrp.CFrame = savedCF end
            end
            twait(S.attackSpeed)
        end
        kaActive = false
    end)
end

local bringActive = false
local function bringStart()
    if bringActive then return end
    bringActive = true
    tspawn(function()
        while S.bringMob do
            if S.emergencyStop then break end
            local hrp = getHRP()
            if hrp then
                equipWeapon()
                local mobs = getMobs()
                for _, mob in ipairs(mobs) do
                    if not S.bringMob or S.emergencyStop then break end
                    local mhum = mob:FindFirstChild("Humanoid")
                    local mhrp = mob:FindFirstChild("HumanoidRootPart")
                    if mhum and mhrp and mhum.Health > 0 then
                        local dist = (hrp.Position - mhrp.Position).Magnitude
                        if dist <= S.bringRange then
                            mhrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -5)
                            mhrp.Velocity = Vector3.new(0,0,0)
                            doAttack()
                            touchAttack(mob)
                        end
                    end
                end
            end
            twait(S.attackSpeed)
        end
        bringActive = false
    end)
end

local function autoFarmLoop()
    tspawn(function()
        while S.autoFarm do
            if S.emergencyStop then break end
            local ok, err = pcall(function()
                local hrp = getHRP()
                local hum = getHum()
                if not hrp or not hum or hum.Health <= 0 then
                    S.farmState = "RECOVERING"
                    twait(3)
                    S.farmState = "IDLE"
                    return
                end
                
                if S.farmState == "IDLE" then
                    S.farmState = "CHECKING_LEVEL"
                    
                elseif S.farmState == "CHECKING_LEVEL" then
                    if S.autoLevel then
                        local lvl = getLevel()
                        local isl = IslandByLevel(lvl)
                        S.farmIsland = isl.name
                        S.farmMob = isl.mob
                    end
                    if S.farmIsland ~= "None" then
                        for _, isl in ipairs(Islands) do
                            if isl.name == S.farmIsland then
                                local d = (hrp.Position - isl.cframe.Position).Magnitude
                                if d > 500 then
                                    S.farmState = "TRAVELING"
                                    notify("Farm", "Traveling to " .. isl.name)
                                    teleportTo(isl.cframe)
                                end
                                break
                            end
                        end
                    end
                    S.farmState = "FARMING"
                    
                elseif S.farmState == "FARMING" then
                    equipWeapon()
                    local mob = findNearest(S.farmMob)
                    if mob then
                        S.currentTarget = mob
                        local mhrp = mob:FindFirstChild("HumanoidRootPart")
                        local mhum = mob:FindFirstChild("Humanoid")
                        if mhrp and mhum and mhum.Health > 0 then
                            mhrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -5)
                            mhrp.Velocity = Vector3.new(0,0,0)
                            doAttack()
                            touchAttack(mob)
                        end
                    else
                        S.farmState = "CHECKING_LEVEL"
                        twait(1)
                    end
                    
                elseif S.farmState == "RECOVERING" then
                    S.currentTarget = nil
                    twait(3)
                    S.farmState = "IDLE"
                end
            end)
            if not ok then
                S.farmState = "RECOVERING"
            end
            twait(S.attackSpeed)
        end
        S.farmState = "IDLE"
    end)
end

tspawn(function()
    while true do
        if S.autoM1 and not S.emergencyStop then
            doAttack()
        end
        twait(S.attackSpeed)
    end
end)

local espFolder = Instance.new("Folder")
espFolder.Name = "VeilESP"
espFolder.Parent = guiParent

local function updateESP()
    if not S.mobESP then
        espFolder:ClearAllChildren()
        return
    end
    
    local mobs = getMobs()
    local existing = {}
    
    for _, mob in ipairs(mobs) do
        local mhum = mob:FindFirstChild("Humanoid")
        local head = mob:FindFirstChild("Head") or mob:FindFirstChild("HumanoidRootPart")
        if mhum and head and mhum.Health > 0 then
            local id = mob.Name .. "_" .. tostring(mob:GetDebugId())
            existing[id] = true
            
            local bg = espFolder:FindFirstChild(id)
            if not bg then
                bg = Instance.new("BillboardGui")
                bg.Name = id
                bg.Adornee = head
                bg.Size = UDim2.new(0, 120, 0, 40)
                bg.StudsOffset = Vector3.new(0, 3, 0)
                bg.AlwaysOnTop = true
                bg.Parent = espFolder
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "NameLabel"
                nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = mob.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 12
                nameLabel.TextStrokeTransparency = 0.5
                nameLabel.Parent = bg
                
                local hpBg = Instance.new("Frame")
                hpBg.Name = "HPBg"
                hpBg.Size = UDim2.new(0.8, 0, 0.2, 0)
                hpBg.Position = UDim2.new(0.1, 0, 0.55, 0)
                hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                hpBg.Parent = bg
                Instance.new("UICorner", hpBg).CornerRadius = UDim.new(1, 0)
                
                local hpFill = Instance.new("Frame")
                hpFill.Name = "HPFill"
                hpFill.Size = UDim2.new(1, 0, 1, 0)
                hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                hpFill.Parent = hpBg
                Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)
                
                local hpText = Instance.new("TextLabel")
                hpText.Name = "HPText"
                hpText.Size = UDim2.new(1, 0, 0.3, 0)
                hpText.Position = UDim2.new(0, 0, 0.7, 0)
                hpText.BackgroundTransparency = 1
                hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
                hpText.Font = Enum.Font.Gotham
                hpText.TextSize = 10
                hpText.TextStrokeTransparency = 0.5
                hpText.Parent = bg
            end
            
            local pct = mhum.Health / mhum.MaxHealth
            local hpFill = bg:FindFirstChild("HPBg") and bg.HPBg:FindFirstChild("HPFill")
            if hpFill then
                hpFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
                hpFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
            end
            local hpText = bg:FindFirstChild("HPText")
            if hpText then
                hpText.Text = math.floor(mhum.Health) .. " / " .. math.floor(mhum.MaxHealth)
            end
        end
    end
    
    for _, bg in pairs(espFolder:GetChildren()) do
        if not existing[bg.Name] then bg:Destroy() end
    end
end

RunS.Heartbeat:Connect(function()
    if S.mobESP then updateESP()
    else espFolder:ClearAllChildren() end
end)

local flyOff
local flyActive = false
local bv, bg_fly = nil, nil

local function flyOn()
    if flyActive then return end
    flyActive = true
    local hrp = getHRP()
    if not hrp then flyActive = false; return end
    bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    bg_fly = Instance.new("BodyGyro")
    bg_fly.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg_fly.D = 100; bg_fly.P = 10000
    bg_fly.CFrame = hrp.CFrame
    bg_fly.Parent = hrp
    tspawn(function()
        while S.fly and flyActive do
            if S.emergencyStop then flyOff(); break end
            local cam = WS.CurrentCamera
            if hrp and bv and bg_fly then
                bg_fly.CFrame = cam.CoordinateFrame
                local dir = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CoordinateFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CoordinateFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CoordinateFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CoordinateFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
                bv.Velocity = dir * S.flySpeed
            end
            twait(0.05)
        end
        flyOff()
    end)
end

flyOff = function()
    flyActive = false
    if bv then bv:Destroy(); bv = nil end
    if bg_fly then bg_fly:Destroy(); bg_fly = nil end
end

RunS.Stepped:Connect(function()
    if S.noclip and LP.Character then
        for _, p in pairs(LP.Character:GetChildren()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

RunS.Heartbeat:Connect(function()
    local c = LP.Character
    local h = c and c:FindFirstChild("Humanoid")
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        if S.godMode then pcall(function() h.Health = h.MaxHealth end) end
        if S.walkSpeed ~= 16 then h.WalkSpeed = S.walkSpeed end
        if S.jumpPower ~= 50 then h.JumpPower = S.jumpPower end
    end
    if hrp and S.noKB then
        pcall(function()
            hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0)
            hrp.RotVelocity = Vector3.zero
        end)
    end
end)

UIS.JumpRequest:Connect(function()
    if S.infJump then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local function triggerEmergencyStop()
    S.emergencyStop = true
    for k, v in pairs(S) do
        if type(v) == "boolean" and k ~= "emergencyStop" and k ~= "notifications" and k ~= "antiAFK" then
            S[k] = false
        end
    end
    flyOff()
    S.farmState = "IDLE"
    S.currentTarget = nil
    espFolder:ClearAllChildren()
    notify("EMERGENCY STOP", "All features stopped")
    twait(1)
    S.emergencyStop = false
end

-- Anti-AFK
pcall(function()
    LP.Idled:Connect(function()
        if VIM then
            VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            twait(0.1)
            VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end
    end)
end)

-- FPS Boost
local function applyFPSBoost()
    if not S.fpsBst then return end
    pcall(function()
        LT.GlobalShadows = false
        for _, v in pairs(WS:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
    end)
end

-- Key System UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VeilKeySystem"
screenGui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 150)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
title.Text = " VEIL HUB - Key System"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local keyInput = Instance.new("TextBox")
keyInput.Size = UDim2.new(0.8, 0, 0, 35)
keyInput.Position = UDim2.new(0.1, 0, 0.4, 0)
keyInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
keyInput.TextColor3 = Color3.new(1, 1, 1)
keyInput.PlaceholderText = "Enter Key..."
keyInput.Text = ""
keyInput.Font = Enum.Font.Gotham
keyInput.TextSize = 14
keyInput.Parent = mainFrame

local submitBtn = Instance.new("TextButton")
submitBtn.Size = UDim2.new(0.8, 0, 0, 30)
submitBtn.Position = UDim2.new(0.1, 0, 0.7, 0)
submitBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
submitBtn.TextColor3 = Color3.new(1, 1, 1)
submitBtn.Text = "Submit"
submitBtn.Font = Enum.Font.GothamBold
submitBtn.TextSize = 14
submitBtn.Parent = mainFrame

submitBtn.MouseButton1Click:Connect(function()
    if keyInput.Text == "patrick jain" then
        screenGui:Destroy()
        loadHub()
    else
        keyInput.Text = ""
        keyInput.PlaceholderText = "Invalid Key!"
    end
end)

loadHub = function()
    local ui = Instance.new("ScreenGui")
    ui.Name = "VeilHub"
    ui.Parent = guiParent
    
    local hubFrame = Instance.new("Frame")
    hubFrame.Size = UDim2.new(0, 450, 0, 500)
    hubFrame.Position = UDim2.new(0.5, -225, 0.5, -250)
    hubFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    hubFrame.Active = true
    hubFrame.Draggable = true
    hubFrame.Parent = ui
    
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    topBar.Parent = hubFrame
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -60, 1, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = " VEIL HUB v7"
    titleLbl.TextColor3 = Color3.new(1, 1, 1)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = topBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 1, 0)
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 0, 0)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = topBar
    closeBtn.MouseButton1Click:Connect(function() ui:Destroy() end)
    
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, 0, 1, -30)
    tabContainer.Position = UDim2.new(0, 0, 0, 30)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = hubFrame
    
    local tabBar = Instance.new("ScrollingFrame")
    tabBar.Size = UDim2.new(1, 0, 0, 35)
    tabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    tabBar.CanvasSize = UDim2.new(0, 600, 0, 0)
    tabBar.ScrollBarThickness = 0
    tabBar.Parent = tabContainer
    
    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.FillDirection = Enum.FillDirection.Horizontal
    tabListLayout.Parent = tabBar
    
    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, 0, 1, -35)
    contentContainer.Position = UDim2.new(0, 0, 0, 35)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = tabContainer
    
    local tabs = {}
    local function makeTab(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btn.Text = name
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = tabBar
        
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.ScrollBarThickness = 4
        page.Visible = false
        page.Parent = contentContainer
        
        local pageLayout = Instance.new("UIListLayout")
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Padding = UDim.new(0, 5)
        pageLayout.Parent = page
        
        btn.MouseButton1Click:Connect(function()
            for _, t in pairs(tabs) do
                t.page.Visible = false
                t.btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            end
            page.Visible = true
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end)
        
        table.insert(tabs, {btn=btn, page=page})
        return page
    end
    
    local function makeSection(parent, title)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 25)
        lbl.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        lbl.Text = "  " .. title
        lbl.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
    end
    
    local function makeToggle(parent, label, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.8, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "  " .. label
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 40, 0, 20)
        btn.Position = UDim2.new(1, -50, 0.5, -10)
        btn.BackgroundColor3 = default and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        btn.Text = ""
        btn.Parent = frame
        
        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.BackgroundColor3 = state and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
            callback(state)
        end)
    end
    
    local function makeSlider(parent, label, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundTransparency = 1
        frame.Parent = parent
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = "  " .. label .. ": " .. default
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame
        
        local bg = Instance.new("TextButton")
        bg.Size = UDim2.new(1, -20, 0, 10)
        bg.Position = UDim2.new(0, 10, 0, 25)
        bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        bg.Text = ""
        bg.Parent = frame
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        fill.Parent = bg
        
        local dragging = false
        bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local pct = math.clamp((input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                local val = math.floor(min + pct * (max - min))
                lbl.Text = "  " .. label .. ": " .. val
                callback(val)
            end
        end)
    end
    
    local function makeButton(parent, label, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 30)
        btn.Position = UDim2.new(0, 10, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btn.Text = label
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = parent
        btn.MouseButton1Click:Connect(callback)
    end
    
    local pageMain = makeTab("Main")
    local pageCombat = makeTab("Combat")
    local pageTeleport = makeTab("Teleport")
    local pagePlayer = makeTab("Player")
    local pageESP = makeTab("ESP")
    local pageSettings = makeTab("Settings")
    
    tabs[1].btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabs[1].page.Visible = true
    
    -- MAIN
    makeSection(pageMain, "Auto Farm")
    makeToggle(pageMain, "Auto Farm", S.autoFarm, function(v) S.autoFarm = v if v then autoFarmLoop() end end)
    makeToggle(pageMain, "Auto Level", S.autoLevel, function(v) S.autoLevel = v end)
    makeSlider(pageMain, "Attack Speed", 10, 100, 20, function(v) S.attackSpeed = v/100 end)
    makeSection(pageMain, "Collection")
    makeToggle(pageMain, "Fruit ESP", S.fruitESP, function(v) S.fruitESP = v end)
    
    -- COMBAT
    makeSection(pageCombat, "Kill Aura (Quick TP)")
    makeToggle(pageCombat, "Kill Aura", S.killAura, function(v) S.killAura = v if v then kaStart() end end)
    makeSlider(pageCombat, "Aura Range", 50, 1000, 200, function(v) S.auraRange = v end)
    makeSection(pageCombat, "Bring Mob")
    makeToggle(pageCombat, "Bring Mobs", S.bringMob, function(v) S.bringMob = v if v then bringStart() end end)
    makeSlider(pageCombat, "Bring Range", 50, 1000, 200, function(v) S.bringRange = v end)
    makeSection(pageCombat, "Auto Attack")
    makeToggle(pageCombat, "Auto M1", S.autoM1, function(v) S.autoM1 = v end)
    
    -- TELEPORT
    makeSection(pageTeleport, "Island Teleport")
    
    local islandNames = {}
    for _, isl in ipairs(Islands) do table.insert(islandNames, isl.name) end
    
    local selectedLbl = Instance.new("TextLabel")
    selectedLbl.Size = UDim2.new(1, 0, 0, 25)
    selectedLbl.BackgroundTransparency = 1
    selectedLbl.Text = "  Selected: None"
    selectedLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    selectedLbl.Font = Enum.Font.Gotham
    selectedLbl.TextSize = 12
    selectedLbl.TextXAlignment = Enum.TextXAlignment.Left
    selectedLbl.LayoutOrder = getOrder()
    selectedLbl.Parent = pageTeleport
    
    for _, iName in ipairs(islandNames) do
        makeButton(pageTeleport, iName, function()
            S.selectedIsland = iName
            selectedLbl.Text = "  Selected: " .. iName
        end)
    end
    
    makeButton(pageTeleport, ">> TELEPORT <<", function()
        if S.selectedIsland == "None" then notify("TP", "Select an island first"); return end
        for _, isl in ipairs(Islands) do
            if isl.name == S.selectedIsland then
                teleportTo(isl.cframe)
                notify("TP", "Teleported to " .. isl.name)
                break
            end
        end
    end)
    
    makeSection(pageTeleport, "Quick TP")
    makeButton(pageTeleport, "TP to Nearest Mob", function()
        local m = findNearest("Any")
        if m and m:FindFirstChild("HumanoidRootPart") then
            teleportTo(m.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
            notify("TP", "Teleported to " .. m.Name)
        end
    end)
    
    -- PLAYER
    makeSection(pagePlayer, "Movement")
    makeToggle(pagePlayer, "Fly", S.fly, function(v) S.fly = v if v then flyOn() else flyOff() end end)
    makeSlider(pagePlayer, "Fly Speed", 20, 500, 80, function(v) S.flySpeed = v end)
    makeToggle(pagePlayer, "Noclip", S.noclip, function(v) S.noclip = v end)
    makeToggle(pagePlayer, "Infinite Jump", S.infJump, function(v) S.infJump = v end)
    makeSlider(pagePlayer, "Walk Speed", 16, 500, 16, function(v) S.walkSpeed = v end)
    makeSlider(pagePlayer, "Jump Power", 50, 500, 50, function(v) S.jumpPower = v end)
    makeSection(pagePlayer, "Defense")
    makeToggle(pagePlayer, "God Mode", S.godMode, function(v) S.godMode = v end)
    makeToggle(pagePlayer, "No Knockback", S.noKB, function(v) S.noKB = v end)
    
    -- ESP
    makeSection(pageESP, "Mob ESP")
    makeToggle(pageESP, "Mob ESP", S.mobESP, function(v) S.mobESP = v end)
    makeSection(pageESP, "Fruit ESP")
    makeToggle(pageESP, "Fruit ESP", S.fruitESP, function(v) S.fruitESP = v end)
    
    -- SETTINGS
    makeSection(pageSettings, "Emergency")
    makeButton(pageSettings, "EMERGENCY STOP", triggerEmergencyStop)
    makeSection(pageSettings, "Performance")
    makeToggle(pageSettings, "FPS Boost", S.fpsBst, function(v) S.fpsBst = v; if v then applyFPSBoost() end end)
    makeSection(pageSettings, "Debug")
    makeToggle(pageSettings, "Debug Panel", S.debugPanel, function(v) S.debugPanel = v end)
    makeToggle(pageSettings, "Notifications", S.notifications, function(v) S.notifications = v end)
    makeSection(pageSettings, "Actions")
    makeButton(pageSettings, "Respawn", function() local h = getHum() if h then h.Health = 0 end end)
    makeButton(pageSettings, "Rejoin", function() TP:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    
    -- KEYBINDS & VISIBILITY
    UIS.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
            ui.Enabled = not ui.Enabled
        end
    end)
    
    notify("VEIL Hub v7 Loaded", "RightCtrl to toggle UI")
end
