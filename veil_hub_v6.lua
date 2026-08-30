-- VEIL Hub v6 — Blox Fruits (Complete Rewrite)
-- Key: patrick jain | Toggle UI: RightCtrl
-- ============================================================
-- IMPORTANT DESIGN NOTES:
--   Kill Aura  = attacks mobs near you, NO teleporting at all
--   Mob Grind  = teleports to mob + attacks (uses smooth tween, not anchor)
--   Teleport   = uses smooth tween so you don't die from anchor glitch
--   Nothing auto-starts. Features only run when YOU toggle them on.
-- ============================================================

local key = "patrick jain"

-- Services
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunS       = game:GetService("RunService")
local TS         = game:GetService("TweenService")
local UIS        = game:GetService("UserInputService")
local LT         = game:GetService("Lighting")
local WS         = game:GetService("Workspace")
local LP         = Players.LocalPlayer

-- Safe references to exploit globals (may not exist in all executors)
local _firetouchinterest = nil
pcall(function() _firetouchinterest = firetouchinterest end)

local _fireproximityprompt = nil
pcall(function() _fireproximityprompt = fireproximityprompt end)

local _fireclickdetector = nil
pcall(function() _fireclickdetector = fireclickdetector end)

-- task library fallbacks
local twait  = (task and task.wait) or wait
local tspawn = (task and task.spawn) or spawn

-- ===================== KEY SYSTEM =====================
local KG = Instance.new("ScreenGui")
KG.Name = "VK"
KG.ResetOnSpawn = false
KG.IgnoreGuiInset = true
pcall(function() KG.Parent = game:GetService("CoreGui") end)
if not KG.Parent then pcall(function() KG.Parent = LP.PlayerGui end) end

local KF = Instance.new("Frame", KG)
KF.Size = UDim2.new(0,280,0,120)
KF.Position = UDim2.new(0.5,-140,0.5,-60)
KF.BackgroundColor3 = Color3.fromRGB(22,22,30)
Instance.new("UICorner", KF).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", KF).Color = Color3.fromRGB(50,50,60)

local KL = Instance.new("TextLabel", KF)
KL.Size = UDim2.new(1,0,0,30) KL.Position = UDim2.new(0,0,0,8)
KL.BackgroundTransparency = 1 KL.Text = "VEIL HUB" KL.TextColor3 = Color3.fromRGB(220,220,228)
KL.TextSize = 16 KL.Font = Enum.Font.GothamBold

local KTB = Instance.new("TextBox", KF)
KTB.Size = UDim2.new(0,240,0,28) KTB.Position = UDim2.new(0,20,0,45)
KTB.BackgroundColor3 = Color3.fromRGB(32,32,42) KTB.Text = "" KTB.PlaceholderText = "key..."
KTB.TextColor3 = Color3.fromRGB(220,220,228) KTB.PlaceholderColor3 = Color3.fromRGB(80,80,90)
KTB.TextSize = 13 KTB.Font = Enum.Font.Gotham KTB.BorderSizePixel = 0
Instance.new("UICorner", KTB).CornerRadius = UDim.new(0,6)
Instance.new("UIStroke", KTB).Color = Color3.fromRGB(60,60,70)

local KS = Instance.new("TextLabel", KF)
KS.Size = UDim2.new(1,0,0,16) KS.Position = UDim2.new(0,0,0,78)
KS.BackgroundTransparency = 1 KS.Text = "" KS.TextColor3 = Color3.fromRGB(200,50,50)
KS.TextSize = 11 KS.Font = Enum.Font.Gotham

local KBtn = Instance.new("TextButton", KF)
KBtn.Size = UDim2.new(0,240,0,26) KBtn.Position = UDim2.new(0,20,0,96)
KBtn.BackgroundColor3 = Color3.fromRGB(160,40,40) KBtn.Text = "SUBMIT"
KBtn.TextColor3 = Color3.new(1,1,1) KBtn.TextSize = 13 KBtn.Font = Enum.Font.GothamBold
KBtn.BorderSizePixel = 0
Instance.new("UICorner", KBtn).CornerRadius = UDim.new(0,6)

local function doKey()
    local t = string.gsub(KTB.Text, "^%s*(.-)%s*$", "%1")
    if t == key then KF:Destroy() loadHub()
    else KS.Text = "Wrong key" KTB.Text = "" end
end
KBtn.MouseButton1Click:Connect(doKey)
KTB.FocusLost:Connect(function(e) if e then doKey() end end)

-- ===================== MAIN HUB =====================
function loadHub()
    local Char = LP.Character or LP.CharacterAdded:Wait()
    if not Char then return end

    -- ======== UTILITY ========
    local function getHRP()
        local c = LP.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function getHum()
        local c = LP.Character
        return c and c:FindFirstChild("Humanoid")
    end

    -- ======== SAFE TWEEN TELEPORT ========
    -- Uses TweenService to move smoothly — prevents fall death from anchor method
    local function tweenTo(targetCF, speed)
        local hrp = getHRP()
        if not hrp then return end
        speed = speed or 200
        local dist = (hrp.Position - targetCF.Position).Magnitude
        local duration = dist / speed
        if duration < 0.05 then duration = 0.05 end
        if duration > 3 then duration = 3 end -- cap at 3s max

        local ti = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = TS:Create(hrp, ti, {CFrame = targetCF})
        tween:Play()
        tween.Completed:Wait()
    end

    -- Instant TP for short distances (safe within ~50 studs)
    local function instantTP(targetCF)
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end
        hrp.CFrame = targetCF
    end

    -- ======== FACE TARGET ========
    local function face(pos)
        local hrp = getHRP()
        if not hrp then return end
        pcall(function()
            hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(pos.X, hrp.Position.Y, pos.Z))
        end)
    end

    -- ======== MOB DETECTION ========
    local function getMobs()
        local mobs = {}
        local checked = {}

        local function scan(container)
            if not container or checked[container] then return end
            checked[container] = true
            for _, v in pairs(container:GetChildren()) do
                pcall(function()
                    if v:IsA("Model") and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
                        if v.Humanoid.Health > 0 and not Players:GetPlayerFromCharacter(v) then
                            table.insert(mobs, v)
                        end
                    end
                end)
            end
        end

        -- Search known folders + workspace root
        for _, n in pairs({"Enemies", "Enemy", "Mobs", "NPCs"}) do
            scan(WS:FindFirstChild(n))
        end
        scan(WS)

        -- Search folders with 3+ NPCs
        for _, child in pairs(WS:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                pcall(function()
                    local cnt = 0
                    for _, s in pairs(child:GetChildren()) do
                        if s:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(s) then
                            cnt = cnt + 1
                        end
                    end
                    if cnt > 2 then scan(child) end
                end)
            end
        end

        return mobs
    end

    local function findNearest(mobName)
        local hrp = getHRP()
        if not hrp then return nil end
        local best, bestDist = nil, math.huge
        for _, m in pairs(getMobs()) do
            pcall(function()
                if string.find(m.Name, mobName, 1, true) and m.Humanoid.Health > 0 then
                    local d = (m.HumanoidRootPart.Position - hrp.Position).Magnitude
                    if d < bestDist then bestDist = d; best = m end
                end
            end)
        end
        return best
    end

    -- ======== ATTACK MOB ========
    -- Multi-method: equip tool + click, firetouchinterest, virtual click
    local function attackMob(mob)
        local hrp = getHRP()
        local mhrp = mob and mob:FindFirstChild("HumanoidRootPart")
        if not hrp or not mhrp then return end

        face(mhrp.Position)

        -- Method 1: firetouchinterest (simulates melee hit)
        if _firetouchinterest then
            pcall(function()
                _firetouchinterest(hrp, mhrp, 0)
                twait()
                _firetouchinterest(hrp, mhrp, 1)
            end)
        end

        -- Method 2: Click using VirtualInputManager (better than VirtualUser)
        pcall(function()
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1) -- mouse down
            twait()
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1) -- mouse up
        end)
    end

    -- ======== STATE — nothing is on by default ========
    local S = {
        ka = false,  kaR = 60,
        grind = false, grindDist = 5, grindMob = "Bandit [Lv. 5]",
        god = false, noKB = false,
        fly = false, flyS = 80,
        esp = false, pick = false, nc = false, fps = false,
        isle = "None"
    }

    -- ===========================================================
    -- KILL AURA — attacks mobs near you, NO teleporting at all
    -- ===========================================================
    local kaActive = false
    local function kaStart()
        if kaActive then return end
        kaActive = true
        tspawn(function()
            while S.ka do
                pcall(function()
                    local hrp = getHRP()
                    local hum = getHum()
                    if not hrp or not hum or hum.Health <= 0 then twait(0.5) return end

                    for _, mob in pairs(getMobs()) do
                        if not S.ka then break end
                        pcall(function()
                            local mhrp = mob:FindFirstChild("HumanoidRootPart")
                            local mhum = mob:FindFirstChild("Humanoid")
                            if mhrp and mhum and mhum.Health > 0 then
                                local dist = (hrp.Position - mhrp.Position).Magnitude
                                if dist <= S.kaR then
                                    -- DO NOT TELEPORT — just attack from here
                                    attackMob(mob)
                                end
                            end
                        end)
                    end
                end)
                twait(0.3)
            end
            kaActive = false
        end)
    end

    -- ===========================================================
    -- MOB GRIND — tween to mob, attack until dead, next
    -- ===========================================================
    local grActive = false
    local function grStart()
        if grActive then return end
        grActive = true
        tspawn(function()
            while S.grind do
                pcall(function()
                    local hrp = getHRP()
                    local hum = getHum()
                    if not hrp or not hum then twait(1) return end
                    if hum.Health <= 0 then twait(3) return end

                    local target = findNearest(S.grindMob)
                    if target then
                        local mhrp = target:FindFirstChild("HumanoidRootPart")
                        local mhum = target:FindFirstChild("Humanoid")
                        if not mhrp or not mhum then return end

                        -- Tween to position near mob (not on top of it!)
                        local offset = mhrp.CFrame * CFrame.new(0, 0, S.grindDist)
                        tweenTo(offset, 250)
                        twait(0.15)

                        -- Attack loop until mob dies
                        local tries = 0
                        while mhum.Health > 0 and target.Parent and S.grind and tries < 200 do
                            -- Stay near mob using instant short-range TP
                            local nearCF = mhrp.CFrame * CFrame.new(0, 0, S.grindDist)
                            instantTP(nearCF)
                            twait(0.05)
                            attackMob(target)
                            tries = tries + 1
                            twait(0.2)
                        end
                        twait(0.3) -- pause before next mob
                    else
                        twait(1) -- no mob, wait for respawn
                    end
                end)
                twait(0.1)
            end
            grActive = false
        end)
    end

    -- ===========================================================
    -- GOD MODE
    -- ===========================================================
    local godConn = nil
    local function godOn()
        if godConn then return end
        S.god = true
        godConn = RunS.Heartbeat:Connect(function()
            pcall(function()
                local hum = getHum()
                if hum and hum.Health < hum.MaxHealth then
                    hum.Health = hum.MaxHealth
                end
            end)
        end)
    end
    local function godOff()
        S.god = false
        if godConn then godConn:Disconnect(); godConn = nil end
    end

    -- ===========================================================
    -- NO KNOCKBACK
    -- ===========================================================
    local kbConn = nil
    local function kbOn()
        if kbConn then return end
        S.noKB = true
        kbConn = RunS.Heartbeat:Connect(function()
            pcall(function()
                local hrp = getHRP()
                if hrp then
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end)
        end)
    end
    local function kbOff()
        S.noKB = false
        if kbConn then kbConn:Disconnect(); kbConn = nil end
    end

    -- ===========================================================
    -- FLY
    -- ===========================================================
    local bv, bg = nil, nil
    local flyOff -- forward declare

    local function flyOn()
        pcall(function()
            flyOff()
            local hrp = getHRP()
            if not hrp then return end

            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e9,1e9,1e9)
            bv.Velocity = Vector3.new(0,0,0)
            bv.Parent = hrp

            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(1e9,1e9,1e9)
            bg.P = 9e4
            bg.Parent = hrp

            S.fly = true
            tspawn(function()
                while S.fly do
                    pcall(function()
                        local h = getHRP()
                        local cam = WS.CurrentCamera
                        if not h or not cam then twait(0.1) return end

                        local dir = Vector3.new(0,0,0)
                        local cf = cam.CFrame
                        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
                        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
                        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
                        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
                        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
                        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
                        if dir.Magnitude > 0 then dir = dir.Unit end

                        bv.Velocity = dir * S.flyS
                        bg.CFrame = cf
                    end)
                    twait(0.016)
                end
            end)
        end)
    end

    flyOff = function()
        S.fly = false
        pcall(function() if bv then bv:Destroy(); bv = nil end end)
        pcall(function() if bg then bg:Destroy(); bg = nil end end)
    end

    -- ===========================================================
    -- FRUIT ESP
    -- ===========================================================
    local espLabels = {}
    local espActive = false

    local function isFruit(obj)
        local ok, r = pcall(function()
            return string.find(string.lower(obj.Name), "fruit") ~= nil
        end)
        return ok and r or false
    end

    local function espStart()
        if espActive then return end
        espActive = true
        tspawn(function()
            while S.esp do
                pcall(function()
                    for _, v in pairs(espLabels) do pcall(function() v:Destroy() end) end
                    espLabels = {}

                    local hrp = getHRP()
                    if not hrp then twait(2) return end

                    local locs = {WS:FindFirstChild("Debree"), WS:FindFirstChild("Debris"), WS}
                    for _, loc in pairs(locs) do
                        if not loc then continue end
                        for _, obj in pairs(loc:GetChildren()) do
                            if isFruit(obj) then pcall(function()
                                local pos, adornee
                                if obj:IsA("Model") then
                                    local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                                    if p then pos = p.Position; adornee = p end
                                elseif obj:IsA("BasePart") then
                                    pos = obj.Position; adornee = obj
                                end
                                if not pos or not adornee then return end

                                local bb = Instance.new("BillboardGui")
                                bb.Size = UDim2.new(0,180,0,28)
                                bb.StudsOffset = Vector3.new(0,3,0)
                                bb.AlwaysOnTop = true
                                bb.Adornee = adornee
                                bb.Parent = obj

                                local lb = Instance.new("TextLabel", bb)
                                lb.Size = UDim2.new(1,0,1,0)
                                lb.BackgroundTransparency = 1
                                lb.TextColor3 = Color3.new(1,0.84,0)
                                lb.TextStrokeTransparency = 0.3
                                lb.TextStrokeColor3 = Color3.new(0,0,0)
                                lb.Text = obj.Name .. " [" .. math.floor((hrp.Position - pos).Magnitude) .. "m]"
                                lb.TextSize = 12
                                lb.Font = Enum.Font.GothamBold

                                table.insert(espLabels, bb)
                            end) end
                        end
                    end
                end)
                twait(2)
            end
            for _, v in pairs(espLabels) do pcall(function() v:Destroy() end) end
            espLabels = {}
            espActive = false
        end)
    end

    -- ===========================================================
    -- AUTO PICKUP
    -- ===========================================================
    local pickActive = false
    local function pickStart()
        if pickActive then return end
        pickActive = true
        tspawn(function()
            while S.pick do
                pcall(function()
                    local hrp = getHRP()
                    if not hrp then twait(2) return end

                    local locs = {WS:FindFirstChild("Debree"), WS:FindFirstChild("Debris"), WS}
                    for _, loc in pairs(locs) do
                        if not loc then continue end
                        for _, obj in pairs(loc:GetChildren()) do
                            if isFruit(obj) then pcall(function()
                                local pos
                                if obj:IsA("Model") then
                                    local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                                    if p then pos = p.Position end
                                elseif obj:IsA("BasePart") then pos = obj.Position end
                                if not pos then return end

                                if (hrp.Position - pos).Magnitude < 500 then
                                    tweenTo(CFrame.new(pos + Vector3.new(0,2,0)), 300)
                                    twait(0.5)
                                    for _, d in pairs(obj:GetDescendants()) do
                                        if d:IsA("ProximityPrompt") then
                                            if _fireproximityprompt then
                                                pcall(function() _fireproximityprompt(d) end)
                                            end
                                            pcall(function()
                                                d:InputHoldBegin()
                                                twait((d.HoldDuration or 0) + 0.2)
                                                d:InputHoldEnd()
                                            end)
                                        elseif d:IsA("ClickDetector") then
                                            if _fireclickdetector then
                                                pcall(function() _fireclickdetector(d) end)
                                            end
                                        end
                                    end
                                    twait(0.5)
                                end
                            end) end
                        end
                    end
                end)
                twait(2)
            end
            pickActive = false
        end)
    end

    -- ===========================================================
    -- NOCLIP
    -- ===========================================================
    local ncConn = nil
    local function ncOn()
        if ncConn then return end
        S.nc = true
        ncConn = RunS.Stepped:Connect(function()
            pcall(function()
                local c = LP.Character
                if c then
                    for _, p in pairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end)
        end)
    end
    local function ncOff()
        S.nc = false
        if ncConn then ncConn:Disconnect(); ncConn = nil end
        pcall(function()
            local c = LP.Character
            if c then
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = true end
                end
            end
        end)
    end

    -- ===========================================================
    -- FPS BOOST
    -- ===========================================================
    local function fpsSet(on)
        S.fps = on
        pcall(function()
            if on then
                LT.GlobalShadows = false
                LT.FogEnd = 999999
                pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
                pcall(function() setfpscap(144) end)
            else
                LT.GlobalShadows = true
                LT.FogEnd = 100000
                pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
                pcall(function() setfpscap(60) end)
            end
        end)
    end

    -- Anti-AFK
    pcall(function()
        LP.Idled:Connect(function()
            pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                twait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        end)
    end)

    -- ===========================================================
    -- ISLAND DATA (Sea 1)
    -- ===========================================================
    local Islands = {
        ["Pirate Village"]  = CFrame.new(1045,15,1585),
        ["Marine Fortress"] = CFrame.new(-2550,73,-2360),
        ["Jungle"]          = CFrame.new(-1180,16,3600),
        ["Skylands"]        = CFrame.new(-4900,790,-2600),
        ["Prison"]          = CFrame.new(4850,5,740),
        ["Colosseum"]       = CFrame.new(-1450,45,-600),
        ["Magma Village"]   = CFrame.new(-5500,60,600),
        ["Underwater City"] = CFrame.new(-11500,45,-500),
        ["Fishman Island"]  = CFrame.new(61000,400,1500),
        ["Frozen Village"]  = CFrame.new(1200,12,-1500),
        ["Graveyard"]       = CFrame.new(-5400,200,-800),
        ["Baratie"]         = CFrame.new(-330,35,1700),
    }

    local MobList = {
        "Bandit [Lv. 5]","Monkey [Lv. 14]","Gorilla [Lv. 20]",
        "Pirate [Lv. 35]","Brute [Lv. 45]","Desert Bandit [Lv. 60]",
        "Desert Officer [Lv. 70]","Snow Bandit [Lv. 90]","Snowman [Lv. 100]",
        "Chief Petty Officer [Lv. 120]","Sky Bandit [Lv. 150]",
        "Dark Master [Lv. 175]","Prisoner [Lv. 190]",
        "Dangerous Prisoner [Lv. 210]","Toga Warrior [Lv. 225]",
        "Gladiator [Lv. 250]"
    }

    -- ===========================================================
    -- GUI
    -- ===========================================================
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "VEIL"
    Gui.ResetOnSpawn = false
    Gui.IgnoreGuiInset = true
    pcall(function() Gui.Parent = game:GetService("CoreGui") end)
    if not Gui.Parent then pcall(function() Gui.Parent = LP.PlayerGui end) end

    local MF = Instance.new("Frame", Gui)
    MF.Size = UDim2.new(0,400,0,380) MF.Position = UDim2.new(0.5,-200,0.5,-190)
    MF.BackgroundColor3 = Color3.fromRGB(18,18,24)
    Instance.new("UICorner", MF).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke", MF).Color = Color3.fromRGB(45,45,55)

    -- Drag
    local dg, ds, dp = false, nil, nil
    MF.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dg = true; ds = i.Position; dp = MF.Position
        end
    end)
    MF.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dg = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dg and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            MF.Position = UDim2.new(dp.X.Scale, dp.X.Offset + d.X, dp.Y.Scale, dp.Y.Offset + d.Y)
        end
    end)

    -- Title
    local TB = Instance.new("Frame", MF) TB.Size = UDim2.new(1,0,0,32) TB.BackgroundColor3 = Color3.fromRGB(24,24,32)
    Instance.new("UICorner", TB).CornerRadius = UDim.new(0,8)
    local TL = Instance.new("TextLabel", TB) TL.Size = UDim2.new(1,-40,1,0) TL.Position = UDim2.new(0,10,0,0)
    TL.BackgroundTransparency = 1 TL.Text = "VEIL HUB v6" TL.TextColor3 = Color3.fromRGB(220,220,228)
    TL.TextSize = 13 TL.Font = Enum.Font.GothamBold TL.TextXAlignment = Enum.TextXAlignment.Left

    local XB = Instance.new("TextButton", TB) XB.Size = UDim2.new(0,24,0,24) XB.Position = UDim2.new(1,-28,0.5,-12)
    XB.BackgroundTransparency = 1 XB.Text = "x" XB.TextColor3 = Color3.fromRGB(200,50,50)
    XB.TextSize = 16 XB.Font = Enum.Font.GothamBold
    XB.MouseButton1Click:Connect(function() MF.Visible = false end)

    -- Tabs
    local TBA = Instance.new("Frame", MF) TBA.Size = UDim2.new(1,0,0,28) TBA.Position = UDim2.new(0,0,0,32)
    TBA.BackgroundColor3 = Color3.fromRGB(20,20,28)
    Instance.new("UIListLayout", TBA).FillDirection = Enum.FillDirection.Horizontal
    local TabNames = {"Combat","Farm","TP","Misc"}
    local TabBtns, TabConts = {}, {}

    for i = 1, #TabNames do
        local b = Instance.new("TextButton", TBA)
        b.Size = UDim2.new(1/#TabNames,0,1,0)
        b.BackgroundColor3 = i == 1 and Color3.fromRGB(160,40,40) or Color3.fromRGB(20,20,28)
        b.BorderSizePixel = 0 b.Text = TabNames[i] b.TextColor3 = Color3.fromRGB(210,210,218)
        b.TextSize = 11 b.Font = Enum.Font.GothamBold
        TabBtns[i] = b

        local c = Instance.new("ScrollingFrame", MF)
        c.Size = UDim2.new(1,-10,1,-70) c.Position = UDim2.new(0,5,0,66)
        c.BackgroundTransparency = 1 c.BorderSizePixel = 0 c.ScrollBarThickness = 3
        c.ScrollBarImageColor3 = Color3.fromRGB(60,60,70)
        c.AutomaticCanvasSize = Enum.AutomaticSize.Y c.Visible = (i == 1)
        Instance.new("UIListLayout", c).Padding = UDim.new(0,4)
        Instance.new("UIPadding", c).PaddingLeft = UDim.new(0,3)
        TabConts[i] = c
    end

    local function switchTab(n)
        for j = 1, #TabNames do
            TabBtns[j].BackgroundColor3 = Color3.fromRGB(20,20,28)
            TabConts[j].Visible = false
        end
        TabBtns[n].BackgroundColor3 = Color3.fromRGB(160,40,40)
        TabConts[n].Visible = true
    end
    for i = 1, #TabNames do TabBtns[i].MouseButton1Click:Connect(function() switchTab(i) end) end

    -- ===========================================================
    -- UI BUILDERS
    -- ===========================================================
    local lo = 0

    local function makeToggle(par, label, default, cb)
        lo = lo + 1
        local f = Instance.new("Frame", par) f.Size = UDim2.new(1,0,0,26) f.BackgroundColor3 = Color3.fromRGB(24,24,32)
        f.BorderSizePixel = 0 f.LayoutOrder = lo Instance.new("UICorner", f).CornerRadius = UDim.new(0,5)
        local l = Instance.new("TextLabel", f) l.Size = UDim2.new(1,-48,1,0) l.Position = UDim2.new(0,10,0,0)
        l.BackgroundTransparency = 1 l.Text = label l.TextColor3 = Color3.fromRGB(210,210,218) l.TextSize = 12
        l.Font = Enum.Font.Gotham l.TextXAlignment = Enum.TextXAlignment.Left
        local t = Instance.new("TextButton", f) t.Size = UDim2.new(0,32,0,16) t.Position = UDim2.new(1,-40,0.5,-8)
        t.BackgroundColor3 = default and Color3.fromRGB(160,40,40) or Color3.fromRGB(50,50,60) t.Text = "" t.BorderSizePixel = 0
        Instance.new("UICorner", t).CornerRadius = UDim.new(1,0)
        local ci = Instance.new("Frame", t) ci.Size = UDim2.new(0,12,0,12)
        ci.Position = default and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
        ci.BackgroundColor3 = Color3.new(1,1,1) ci.BorderSizePixel = 0
        Instance.new("UICorner", ci).CornerRadius = UDim.new(1,0)
        local st = default
        t.MouseButton1Click:Connect(function()
            st = not st
            t.BackgroundColor3 = st and Color3.fromRGB(160,40,40) or Color3.fromRGB(50,50,60)
            pcall(function()
                TS:Create(ci, TweenInfo.new(0.12), {Position = st and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)}):Play()
            end)
            cb(st)
        end)
    end

    local function makeSlider(par, label, mn, mx, df, cb)
        lo = lo + 1
        local f = Instance.new("Frame", par) f.Size = UDim2.new(1,0,0,36) f.BackgroundColor3 = Color3.fromRGB(24,24,32)
        f.BorderSizePixel = 0 f.LayoutOrder = lo Instance.new("UICorner", f).CornerRadius = UDim.new(0,5)
        local l = Instance.new("TextLabel", f) l.Size = UDim2.new(1,-20,0,14) l.Position = UDim2.new(0,10,0,2)
        l.BackgroundTransparency = 1 l.Text = label..": "..tostring(df) l.TextColor3 = Color3.fromRGB(210,210,218)
        l.TextSize = 11 l.Font = Enum.Font.Gotham l.TextXAlignment = Enum.TextXAlignment.Left
        local bar = Instance.new("Frame", f) bar.Size = UDim2.new(1,-20,0,8) bar.Position = UDim2.new(0,10,0,20)
        bar.BackgroundColor3 = Color3.fromRGB(35,35,45) bar.BorderSizePixel = 0
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
        local fl = Instance.new("Frame", bar) fl.Size = UDim2.new((df-mn)/(mx-mn),0,1,0)
        fl.BackgroundColor3 = Color3.fromRGB(160,40,40) fl.BorderSizePixel = 0
        Instance.new("UICorner", fl).CornerRadius = UDim.new(1,0)
        local bt = Instance.new("TextButton", bar) bt.Size = UDim2.new(1,0,1,0) bt.BackgroundTransparency = 1
        bt.Text = "" bt.BorderSizePixel = 0
        local sliding = false
        bt.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end end)
        bt.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end end)
        UIS.InputChanged:Connect(function(i)
            if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
                local rx = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                local v = math.floor((mn + (mx - mn) * rx) * 10) / 10
                fl.Size = UDim2.new(rx,0,1,0) l.Text = label..": "..tostring(v) cb(v)
            end
        end)
    end

    local function makeDropdown(par, label, opts, df, cb)
        lo = lo + 1
        local f = Instance.new("Frame", par) f.Size = UDim2.new(1,0,0,42) f.BackgroundColor3 = Color3.fromRGB(24,24,32)
        f.BorderSizePixel = 0 f.LayoutOrder = lo Instance.new("UICorner", f).CornerRadius = UDim.new(0,5)
        local l = Instance.new("TextLabel", f) l.Size = UDim2.new(1,0,0,14) l.Position = UDim2.new(0,10,0,2)
        l.BackgroundTransparency = 1 l.Text = label l.TextColor3 = Color3.fromRGB(130,130,145) l.TextSize = 10
        l.Font = Enum.Font.Gotham l.TextXAlignment = Enum.TextXAlignment.Left
        local b = Instance.new("TextButton", f) b.Size = UDim2.new(1,-14,0,20) b.Position = UDim2.new(0,7,0,19)
        b.BackgroundColor3 = Color3.fromRGB(32,32,42) b.Text = df b.TextColor3 = Color3.fromRGB(210,210,218)
        b.TextSize = 11 b.Font = Enum.Font.Gotham b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
        local dd = Instance.new("Frame", Gui) dd.BackgroundColor3 = Color3.fromRGB(28,28,38) dd.BorderSizePixel = 0
        dd.Visible = false dd.ZIndex = 100 Instance.new("UICorner", dd).CornerRadius = UDim.new(0,6)
        local dsc = Instance.new("ScrollingFrame", dd) dsc.Size = UDim2.new(1,0,1,0) dsc.BackgroundTransparency = 1
        dsc.BorderSizePixel = 0 dsc.ScrollBarThickness = 3 dsc.ScrollBarImageColor3 = Color3.fromRGB(60,60,70)
        dsc.AutomaticCanvasSize = Enum.AutomaticSize.Y Instance.new("UIListLayout", dsc).Padding = UDim.new(0,1)
        for i = 1, #opts do
            local ob = Instance.new("TextButton", dsc) ob.Size = UDim2.new(1,-8,0,22) ob.Position = UDim2.new(0,4,0,0)
            ob.BackgroundColor3 = Color3.fromRGB(38,38,50) ob.Text = opts[i] ob.TextColor3 = Color3.fromRGB(210,210,218)
            ob.TextSize = 11 ob.Font = Enum.Font.Gotham ob.BorderSizePixel = 0 ob.ZIndex = 101
            Instance.new("UICorner", ob).CornerRadius = UDim.new(0,3)
            ob.MouseButton1Click:Connect(function() b.Text = opts[i]; dd.Visible = false; cb(opts[i]) end)
            ob.MouseEnter:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(50,50,65) end)
            ob.MouseLeave:Connect(function() ob.BackgroundColor3 = Color3.fromRGB(38,38,50) end)
        end
        b.MouseButton1Click:Connect(function()
            dd.Visible = not dd.Visible
            if dd.Visible then
                local ap = b.AbsolutePosition; local as = b.AbsoluteSize
                local h = math.min(#opts * 23 + 4, 200)
                dd.Size = UDim2.new(0,as.X,0,h)
                dd.Position = UDim2.new(0,ap.X,0,ap.Y + as.Y + 2)
            end
        end)
        UIS.InputBegan:Connect(function(i)
            if not dd.Visible then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                twait()
                local m = UIS:GetMouseLocation(); local p = dd.AbsolutePosition; local sz = dd.AbsoluteSize
                if m.X < p.X or m.X > p.X + sz.X or m.Y < p.Y or m.Y > p.Y + sz.Y then dd.Visible = false end
            end
        end)
    end

    local function makeButton(par, label, cb)
        lo = lo + 1
        local b = Instance.new("TextButton", par) b.Size = UDim2.new(1,0,0,26) b.BackgroundColor3 = Color3.fromRGB(130,30,30)
        b.Text = label b.TextColor3 = Color3.new(1,1,1) b.TextSize = 12 b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0 b.LayoutOrder = lo Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
        b.MouseButton1Click:Connect(cb)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(160,40,40) end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = Color3.fromRGB(130,30,30) end)
    end

    -- ===========================================================
    -- POPULATE TABS
    -- ===========================================================
    -- Combat
    makeToggle(TabConts[1], "Kill Aura (no TP)", false, function(v) S.ka = v; if v then kaStart() end end)
    makeSlider(TabConts[1], "Aura Range", 10, 150, 60, function(v) S.kaR = v end)
    makeToggle(TabConts[1], "God Mode", false, function(v) if v then godOn() else godOff() end end)
    makeToggle(TabConts[1], "No Knockback", false, function(v) if v then kbOn() else kbOff() end end)
    makeToggle(TabConts[1], "Fly (WASD/Space/Shift)", false, function(v) if v then flyOn() else flyOff() end end)
    makeSlider(TabConts[1], "Fly Speed", 20, 300, 80, function(v) S.flyS = v end)

    -- Farm
    makeToggle(TabConts[2], "Mob Grind (TP + Kill)", false, function(v) S.grind = v; if v then grStart() end end)
    makeSlider(TabConts[2], "Grind Distance", 3, 15, 5, function(v) S.grindDist = v end)
    makeDropdown(TabConts[2], "Select Mob", MobList, MobList[1], function(v) S.grindMob = v end)
    makeToggle(TabConts[2], "Fruit ESP", false, function(v) S.esp = v; if v then espStart() end end)
    makeToggle(TabConts[2], "Auto Pickup", false, function(v) S.pick = v; if v then pickStart() end end)

    -- TP
    local iN = {"None"}
    for k in pairs(Islands) do table.insert(iN, k) end
    table.sort(iN)
    makeDropdown(TabConts[3], "Island", iN, "None", function(v) S.isle = v end)
    makeButton(TabConts[3], "Teleport", function()
        if S.isle ~= "None" and Islands[S.isle] then
            tweenTo(Islands[S.isle], 300)
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {Title = "TP", Text = S.isle})
            end)
        end
    end)

    -- Misc
    makeToggle(TabConts[4], "No Clip", false, function(v) if v then ncOn() else ncOff() end end)
    makeToggle(TabConts[4], "FPS Boost", false, function(v) fpsSet(v) end)
    makeButton(TabConts[4], "Respawn", function() pcall(function() LP.Character.Humanoid.Health = 0 end) end)
    makeButton(TabConts[4], "Rejoin", function()
        pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
    end)

    -- Toggle UI
    UIS.InputBegan:Connect(function(i, gp) if not gp and i.KeyCode == Enum.KeyCode.RightControl then MF.Visible = not MF.Visible end end)

    -- Re-apply on respawn
    LP.CharacterAdded:Connect(function(c)
        twait(1.5)
        pcall(function() c:WaitForChild("HumanoidRootPart", 10); c:WaitForChild("Humanoid", 10) end)
        if S.nc then ncOn() end
        if S.fly then flyOn() end
        if S.god then godOn() end
        if S.noKB then kbOn() end
    end)

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "VEIL", Text = "Loaded — RightCtrl to toggle"})
    end)
end
