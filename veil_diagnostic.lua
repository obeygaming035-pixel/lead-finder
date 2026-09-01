-- VEIL DIAGNOSTIC v1 — Run this in your executor and send me the output
-- This script does NOT change anything — it only READS and REPORTS

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer

local results = {}
local function log(msg)
    table.insert(results, msg)
    print("[DIAG] " .. msg)
end

log("========== VEIL DIAGNOSTIC ==========")
log("Game PlaceId: " .. tostring(game.PlaceId))
log("Game Name: " .. tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown"))

-- 1. EXECUTOR CAPABILITIES
log("")
log("===== EXECUTOR CAPABILITIES =====")
local caps = {
    "firetouchinterest", "fireclickdetector", "fireproximityprompt",
    "getgenv", "setclipboard", "hookfunction", "getrawmetatable",
    "newcclosure", "iscclosure", "checkcaller", "getnamecallmethod",
    "mouse1click", "mouse1press", "mouse1release", "mousemoverel",
    "keypress", "keyrelease"
}
for _, name in ipairs(caps) do
    local exists = false
    pcall(function() exists = getfenv()[name] ~= nil or _G[name] ~= nil end)
    pcall(function()
        if not exists then exists = getgenv and getgenv()[name] ~= nil end
    end)
    log("  " .. name .. ": " .. tostring(exists))
end

-- Check VirtualInputManager
local hasVIM = false
pcall(function() local v = game:GetService("VirtualInputManager"); hasVIM = v ~= nil end)
log("  VirtualInputManager: " .. tostring(hasVIM))

-- Check VirtualUser
local hasVU = false
pcall(function() local v = game:GetService("VirtualUser"); hasVU = v ~= nil end)
log("  VirtualUser: " .. tostring(hasVU))

-- 2. ALL REMOTES IN REPLICATEDSTORAGE
log("")
log("===== REMOTES IN REPLICATEDSTORAGE =====")
local function scanRemotes(folder, path)
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("RemoteEvent") then
            log("  [RemoteEvent] " .. path .. "/" .. child.Name)
        elseif child:IsA("RemoteFunction") then
            log("  [RemoteFunction] " .. path .. "/" .. child.Name)
        elseif child:IsA("Folder") or child:IsA("Configuration") then
            scanRemotes(child, path .. "/" .. child.Name)
        end
    end
end
scanRemotes(RS, "ReplicatedStorage")

-- 3. SPECIFIC KNOWN BF REMOTES
log("")
log("===== BLOX FRUITS SPECIFIC CHECKS =====")
local remotesFolder = RS:FindFirstChild("Remotes")
log("  Remotes folder exists: " .. tostring(remotesFolder ~= nil))
if remotesFolder then
    log("  Remotes children count: " .. #remotesFolder:GetChildren())
    for _, r in ipairs(remotesFolder:GetChildren()) do
        log("    " .. r.ClassName .. ": " .. r.Name)
    end
end

-- Check for other common BF folders
local bfFolders = {"__REMOTES", "__THINGS", "CombatFramework", "Weapons", "Fruits", "Quests", "Fighting"}
for _, name in ipairs(bfFolders) do
    local found = RS:FindFirstChild(name)
    log("  RS." .. name .. ": " .. tostring(found ~= nil))
end

-- 4. WORKSPACE STRUCTURE — Where are mobs?
log("")
log("===== WORKSPACE MOB FOLDERS =====")
local mobFolders = {"Enemies", "Enemy", "Mobs", "NPCs", "Humanoids", "mobs", "enemies"}
for _, name in ipairs(mobFolders) do
    local folder = WS:FindFirstChild(name)
    if folder then
        local count = #folder:GetChildren()
        log("  workspace." .. name .. ": " .. count .. " children")
        -- List first 5 mobs
        local shown = 0
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChild("Humanoid") then
                local hum = child:FindFirstChild("Humanoid")
                log("    Mob: \"" .. child.Name .. "\" HP:" .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth))
                shown = shown + 1
                if shown >= 5 then log("    ... and more"); break end
            end
        end
    end
end

-- Also check workspace root for mob-like models
log("")
log("===== MOBS IN WORKSPACE ROOT (first 10) =====")
local rootMobs = 0
for _, child in ipairs(WS:GetChildren()) do
    if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
        local hum = child:FindFirstChild("Humanoid")
        if child ~= LP.Character and hum.Health > 0 then
            log("  \"" .. child.Name .. "\" HP:" .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth))
            rootMobs = rootMobs + 1
            if rootMobs >= 10 then log("  ... and more"); break end
        end
    end
end
if rootMobs == 0 then log("  (none found in root)") end

-- 5. PLAYER TOOLS/WEAPONS
log("")
log("===== PLAYER TOOLS =====")
local char = LP.Character
if char then
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            log("  [Equipped] " .. child.Name .. " (Handle: " .. tostring(child:FindFirstChild("Handle") ~= nil) .. ")")
        end
    end
end
local bp = LP:FindFirstChild("Backpack")
if bp then
    for _, child in ipairs(bp:GetChildren()) do
        if child:IsA("Tool") then
            log("  [Backpack] " .. child.Name .. " (Handle: " .. tostring(child:FindFirstChild("Handle") ~= nil) .. ")")
        end
    end
end

-- 6. PLAYER DATA (level, stats)
log("")
log("===== PLAYER DATA =====")
if LP:FindFirstChild("Data") then
    log("  LP.Data exists")
    for _, child in ipairs(LP.Data:GetChildren()) do
        pcall(function()
            log("    " .. child.Name .. " = " .. tostring(child.Value))
        end)
    end
elseif LP:FindFirstChild("leaderstats") then
    log("  LP.leaderstats exists")
    for _, child in ipairs(LP.leaderstats:GetChildren()) do
        pcall(function()
            log("    " .. child.Name .. " = " .. tostring(child.Value))
        end)
    end
else
    log("  No Data or leaderstats folder found")
end

-- 7. OUTPUT SUMMARY
log("")
log("========== END DIAGNOSTIC ==========")
log("Copy ALL the output above and send it to me.")
log("Total lines: " .. #results)

-- Also try to copy to clipboard
pcall(function()
    if setclipboard then
        setclipboard(table.concat(results, "\n"))
        log("(Output copied to clipboard!)")
    end
end)

-- Show in a GUI too
pcall(function()
    local sg = Instance.new("ScreenGui")
    sg.Name = "VeilDiag"
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = LP:WaitForChild("PlayerGui") end
    
    local f = Instance.new("Frame", sg)
    f.Size = UDim2.new(0.6, 0, 0.8, 0)
    f.Position = UDim2.new(0.2, 0, 0.1, 0)
    f.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    f.Active = true
    f.Draggable = true
    
    local sf = Instance.new("ScrollingFrame", f)
    sf.Size = UDim2.new(1, -10, 1, -40)
    sf.Position = UDim2.new(0, 5, 0, 35)
    sf.BackgroundTransparency = 1
    sf.CanvasSize = UDim2.new(0, 0, 0, #results * 16)
    sf.ScrollBarThickness = 6
    
    local title = Instance.new("TextLabel", f)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    title.Text = " VEIL DIAGNOSTIC — Copy output from F9 console"
    title.TextColor3 = Color3.fromRGB(0, 255, 100)
    title.Font = Enum.Font.Code
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local txt = Instance.new("TextLabel", sf)
    txt.Size = UDim2.new(1, 0, 0, #results * 16)
    txt.BackgroundTransparency = 1
    txt.Text = table.concat(results, "\n")
    txt.TextColor3 = Color3.fromRGB(200, 200, 200)
    txt.Font = Enum.Font.Code
    txt.TextSize = 12
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.TextWrapped = true
    
    local closeBtn = Instance.new("TextButton", f)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)
end)
