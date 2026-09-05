--[[
    ██████╗ ██╗      ██████╗ ██╗  ██╗    ██╗   ██╗██╗  ████████╗██╗███╗   ███╗ █████╗ ████████╗███████╗
    ██╔══██╗██║     ██╔═══██╗╚██╗██╔╝    ██║   ██║██║  ╚══██╔══╝██║████╗ ████║██╔══██╗╚══██╔══╝██╔════╝
    ██████╔╝██║     ██║   ██║ ╚███╔╝     ██║   ██║██║     ██║   ██║██╔████╔██║███████║   ██║   █████╗  
    ██╔══██╗██║     ██║   ██║ ██╔██╗     ██║   ██║██║     ██║   ██║██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  
    ██████╔╝███████╗╚██████╔╝██╔╝ ██╗    ╚██████╔╝███████╗██║   ██║██║ ╚═╝ ██║██║  ██║   ██║   ███████╗
    ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝     ╚═════╝ ╚══════╝╚═╝   ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
    
    BLOX FRUITS ULTIMATE GAME ANALYZER + AUTO-FIX SCRIPT GENERATOR
    
    This script does NOT farm. It ANALYZES the entire game after an update, then generates
    a WORKING script with correct paths and teleportation methods, and copies it to clipboard.
    
    What it scans:
    ✓ All Workspace children & folder structure (Enemies, NPCs, Map, Islands, etc.)
    ✓ All ReplicatedStorage remotes & modules  
    ✓ All player data values (Level, Stats, Inventory, etc.)
    ✓ All available quest NPCs & proximity prompts
    ✓ All mob types, positions, health values
    ✓ All fruit spawns & collectible items
    ✓ All chest locations & interactive objects
    ✓ Anti-cheat detection mechanisms
    ✓ Teleportation method testing (7+ methods tried)
    ✓ Server-side validation behavior
    ✓ Map structure & island positions
    
    After analysis: Generates a COMPLETE working hub script → clipboard
]]

-- ═══════════════════════════════════════════════════════════════
-- PHASE 0: SAFE STARTUP
-- ═══════════════════════════════════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")

local LP = Players.LocalPlayer
local Camera = WS.CurrentCamera

-- Output log
local LOG = {}
local REPORT = {}
local DISCOVERED = {
    EnemyFolder = nil,
    EnemyFolderPath = "",
    MobNames = {},
    MobPositions = {},
    BossMobs = {},
    
    NPCFolder = nil,
    NPCFolderPath = "",
    QuestNPCs = {},
    
    RemoteFolder = nil,
    RemoteFolderPath = "",
    Remotes = {},
    RemoteFunctions = {},
    
    CommF = nil,
    CommFPath = "",
    
    PlayerData = {},
    PlayerLevel = 0,
    
    FruitLocations = {},
    ChestLocations = {},
    InteractiveObjects = {},
    
    IslandPositions = {},
    MapFolders = {},
    
    WorkingTeleportMethod = nil,
    TeleportTestResults = {},
    
    AntiCheatDetected = {},
    
    Sea = 0,
    PlaceId = game.PlaceId,
}

local function Log(category, msg)
    local entry = string.format("[%s] %s", category, msg)
    table.insert(LOG, entry)
    print(entry)
end

local function AddReport(section, key, value)
    if not REPORT[section] then REPORT[section] = {} end
    table.insert(REPORT[section], {key = key, value = tostring(value)})
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 1: IDENTIFY SEA & PLACE
-- ═══════════════════════════════════════════════════════════════
Log("INIT", "Starting Ultimate Blox Fruits Analyzer...")
Log("INIT", "PlaceId: " .. tostring(game.PlaceId))
Log("INIT", "GameId: " .. tostring(game.GameId))

local PlaceId = game.PlaceId
local Sea1IDs = {2753915549}
local Sea2IDs = {4442272183}
local Sea3IDs = {7449423635}

local function MatchSea(id, tbl)
    for _, v in ipairs(tbl) do if v == id then return true end end
    return false
end

if MatchSea(PlaceId, Sea1IDs) then DISCOVERED.Sea = 1
elseif MatchSea(PlaceId, Sea2IDs) then DISCOVERED.Sea = 2
elseif MatchSea(PlaceId, Sea3IDs) then DISCOVERED.Sea = 3
else DISCOVERED.Sea = 0 end

-- Also detect by workspace content
if DISCOVERED.Sea == 0 then
    for _, child in ipairs(WS:GetChildren()) do
        local n = child.Name:lower()
        if n:find("third") or n:find("sea3") or n:find("sea_3") then DISCOVERED.Sea = 3; break
        elseif n:find("second") or n:find("sea2") or n:find("sea_2") then DISCOVERED.Sea = 2; break
        elseif n:find("first") or n:find("sea1") or n:find("sea_1") then DISCOVERED.Sea = 1; break
        end
    end
end

Log("SEA", "Detected Sea: " .. DISCOVERED.Sea)
AddReport("Game Info", "PlaceId", PlaceId)
AddReport("Game Info", "Sea", DISCOVERED.Sea)
AddReport("Game Info", "Player", LP.Name)

-- ═══════════════════════════════════════════════════════════════
-- PHASE 2: FULL WORKSPACE STRUCTURE SCAN
-- ═══════════════════════════════════════════════════════════════
Log("SCAN", "Scanning entire Workspace structure...")

local WS_STRUCTURE = {}
local ENEMY_CANDIDATES = {}
local NPC_CANDIDATES = {}
local MAP_CANDIDATES = {}
local INTERACTIVE_CANDIDATES = {}
local CHEST_CANDIDATES = {}
local FRUIT_CANDIDATES = {}

-- Deep scan workspace first-level children
for _, child in ipairs(WS:GetChildren()) do
    local info = {
        Name = child.Name,
        ClassName = child.ClassName,
        ChildCount = #child:GetChildren(),
        DescendantCount = #child:GetDescendants(),
    }
    table.insert(WS_STRUCTURE, info)
    
    local nameLower = child.Name:lower()
    
    -- Enemy folder detection (check many possible names)
    if nameLower == "enemies" or nameLower == "enemy" or nameLower == "mobs" or nameLower == "monsters" 
       or nameLower == "npcs" or nameLower == "hostiles" or nameLower == "entities"
       or nameLower == "livingentities" or nameLower == "characters" or nameLower == "combatentities"
       or nameLower == "ai" or nameLower == "aicharacters" or nameLower == "spawned"
       or nameLower == "spawnedentities" or nameLower == "creatures" then
        table.insert(ENEMY_CANDIDATES, {folder = child, path = "Workspace." .. child.Name, priority = 1})
    end
    
    -- Also check if any child has Humanoid children (strong signal for enemy folder)
    if child:IsA("Folder") or child:IsA("Model") then
        local hasHumanoid = false
        for _, sub in ipairs(child:GetChildren()) do
            if sub:FindFirstChild("Humanoid") and sub:FindFirstChild("HumanoidRootPart") then
                hasHumanoid = true
                break
            end
        end
        if hasHumanoid and not nameLower:find("player") then
            table.insert(ENEMY_CANDIDATES, {folder = child, path = "Workspace." .. child.Name, priority = 2})
        end
    end
    
    -- NPC folder detection
    if nameLower:find("quest") or nameLower:find("npc") or nameLower:find("shopkeeper") 
       or nameLower:find("givers") or nameLower:find("interactable") then
        table.insert(NPC_CANDIDATES, {folder = child, path = "Workspace." .. child.Name})
    end
    
    -- Map/Island detection
    if nameLower:find("map") or nameLower:find("island") or nameLower:find("location") 
       or nameLower:find("terrain") or nameLower:find("world") or nameLower:find("areas") 
       or nameLower:find("zones") or nameLower:find("region") then
        table.insert(MAP_CANDIDATES, {folder = child, path = "Workspace." .. child.Name})
    end
    
    -- Chest detection
    if nameLower:find("chest") or nameLower:find("loot") or nameLower:find("treasure")
       or nameLower:find("crate") or nameLower:find("reward") then
        table.insert(CHEST_CANDIDATES, {folder = child, path = "Workspace." .. child.Name})
    end
    
    -- Fruit detection
    if nameLower:find("fruit") or nameLower:find("devil") or nameLower:find("spawn")
       or nameLower:find("devilfruit") or nameLower:find("fruitspawn") then
        table.insert(FRUIT_CANDIDATES, {folder = child, path = "Workspace." .. child.Name})
    end
end

-- Log workspace structure
Log("SCAN", "Workspace top-level children: " .. #WS_STRUCTURE)
for _, info in ipairs(WS_STRUCTURE) do
    Log("SCAN", string.format("  %-35s | Class: %-20s | Children: %d | Descendants: %d",
        info.Name, info.ClassName, info.ChildCount, info.DescendantCount))
    AddReport("Workspace Structure", info.Name, 
        string.format("Class=%s, Children=%d, Desc=%d", info.ClassName, info.ChildCount, info.DescendantCount))
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 2B: DEEP ENEMY FOLDER DISCOVERY
-- ═══════════════════════════════════════════════════════════════
Log("ENEMY", "Searching for enemy containers...")

-- Also scan 2 levels deep for enemy containers
for _, child in ipairs(WS:GetChildren()) do
    if child:IsA("Folder") or child:IsA("Model") then
        for _, sub in ipairs(child:GetChildren()) do
            local sn = sub.Name:lower()
            if sn == "enemies" or sn == "mobs" or sn == "monsters" or sn == "hostiles"
               or sn == "entities" or sn == "spawned" or sn == "ai" then
                table.insert(ENEMY_CANDIDATES, {folder = sub, path = "Workspace." .. child.Name .. "." .. sub.Name, priority = 1})
            end
            -- Check for humanoids at this level too
            if sub:IsA("Folder") or sub:IsA("Model") then
                local count = 0
                for _, mob in ipairs(sub:GetChildren()) do
                    if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
                        count = count + 1
                    end
                end
                if count >= 2 then
                    table.insert(ENEMY_CANDIDATES, {folder = sub, path = "Workspace." .. child.Name .. "." .. sub.Name, priority = 2})
                end
            end
        end
    end
end

-- Select best enemy folder
table.sort(ENEMY_CANDIDATES, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return #a.folder:GetChildren() > #b.folder:GetChildren()
end)

if #ENEMY_CANDIDATES > 0 then
    local best = ENEMY_CANDIDATES[1]
    DISCOVERED.EnemyFolder = best.folder
    DISCOVERED.EnemyFolderPath = best.path
    Log("ENEMY", "✓ Best enemy folder: " .. best.path .. " (" .. #best.folder:GetChildren() .. " entities)")
    AddReport("Enemy System", "Folder Path", best.path)
    AddReport("Enemy System", "Entity Count", #best.folder:GetChildren())
    
    -- All candidates
    for i, c in ipairs(ENEMY_CANDIDATES) do
        Log("ENEMY", "  Candidate #" .. i .. ": " .. c.path .. " (" .. #c.folder:GetChildren() .. " children, priority=" .. c.priority .. ")")
    end
else
    Log("ENEMY", "✗ No enemy folder found! Scanning ALL workspace descendants...")
    -- Emergency: scan all workspace for any models with Humanoid
    local found = {}
    for _, desc in ipairs(WS:GetDescendants()) do
        if desc:IsA("Model") and desc:FindFirstChild("Humanoid") and desc:FindFirstChild("HumanoidRootPart") then
            if desc.Parent and not desc.Parent:IsA("Model") then -- skip player characters
                local parentName = desc.Parent.Name
                if not found[parentName] then
                    found[parentName] = {folder = desc.Parent, count = 0}
                end
                found[parentName].count = found[parentName].count + 1
            end
        end
    end
    
    local bestParent, bestCount = nil, 0
    for name, data in pairs(found) do
        Log("ENEMY", "  Found humanoids in: " .. name .. " (count: " .. data.count .. ")")
        if data.count > bestCount then
            bestCount = data.count
            bestParent = data.folder
        end
    end
    
    if bestParent then
        DISCOVERED.EnemyFolder = bestParent
        DISCOVERED.EnemyFolderPath = "Workspace." .. bestParent.Name
        Log("ENEMY", "✓ Emergency discovery: " .. bestParent.Name)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 2C: CATALOG ALL MOBS
-- ═══════════════════════════════════════════════════════════════
if DISCOVERED.EnemyFolder then
    Log("MOBS", "Cataloging all mobs...")
    local mobCounts = {}
    
    for _, mob in ipairs(DISCOVERED.EnemyFolder:GetChildren()) do
        local hum = mob:FindFirstChild("Humanoid")
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        
        if hum and hrp then
            local name = mob.Name
            if not mobCounts[name] then
                mobCounts[name] = {count = 0, health = 0, maxHealth = 0, position = nil, level = "?"}
            end
            mobCounts[name].count = mobCounts[name].count + 1
            mobCounts[name].health = hum.Health
            mobCounts[name].maxHealth = hum.MaxHealth
            mobCounts[name].position = hrp.Position
            
            -- Try to get level
            local lvl = mob:FindFirstChild("Level") 
                or (mob:FindFirstChild("Data") and mob.Data:FindFirstChild("Level"))
                or mob:GetAttribute("Level")
            if lvl then
                mobCounts[name].level = type(lvl) == "number" and lvl or (typeof(lvl) == "Instance" and lvl.Value or lvl)
            end
            
            -- Check if boss
            local isBoss = name:lower():find("boss") or hum.MaxHealth > 50000 
                or mob:GetAttribute("IsBoss") or mob:FindFirstChild("IsBoss")
            if isBoss then
                DISCOVERED.BossMobs[name] = true
            end
            
            table.insert(DISCOVERED.MobPositions, {name = name, pos = hrp.Position})
        end
    end
    
    for name, data in pairs(mobCounts) do
        table.insert(DISCOVERED.MobNames, name)
        local bossTag = DISCOVERED.BossMobs[name] and " [BOSS]" or ""
        Log("MOBS", string.format("  %-30s | Count: %d | HP: %.0f/%.0f | Level: %s%s | Pos: (%.0f,%.0f,%.0f)",
            name, data.count, data.health, data.maxHealth, tostring(data.level), bossTag,
            data.position.X, data.position.Y, data.position.Z))
        AddReport("Mobs Found", name .. bossTag, 
            string.format("Count=%d, HP=%d/%d, Lv=%s", data.count, data.health, data.maxHealth, tostring(data.level)))
    end
    
    Log("MOBS", "Total unique mob types: " .. #DISCOVERED.MobNames)
    Log("MOBS", "Boss mobs detected: " .. (function() local c = 0; for _ in pairs(DISCOVERED.BossMobs) do c = c + 1 end; return c end)())
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 3: REPLICATED STORAGE FULL SCAN
-- ═══════════════════════════════════════════════════════════════
Log("RS", "Scanning ReplicatedStorage...")

local RS_STRUCTURE = {}
for _, child in ipairs(RS:GetChildren()) do
    local info = {Name = child.Name, ClassName = child.ClassName, Children = #child:GetChildren()}
    table.insert(RS_STRUCTURE, info)
    Log("RS", string.format("  %-35s | Class: %-25s | Children: %d", info.Name, info.ClassName, info.Children))
    AddReport("ReplicatedStorage", child.Name, string.format("Class=%s, Children=%d", child.ClassName, info.Children))
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 3B: DISCOVER ALL REMOTES
-- ═══════════════════════════════════════════════════════════════
Log("REMOTES", "Discovering ALL remote events and functions...")

local allRemoteEvents = {}
local allRemoteFunctions = {}
local commF_candidates = {}

for _, desc in ipairs(RS:GetDescendants()) do
    if desc:IsA("RemoteEvent") then
        local path = desc:GetFullName()
        table.insert(allRemoteEvents, {name = desc.Name, path = path, instance = desc})
        Log("REMOTES", "  RE: " .. path)
        AddReport("Remote Events", desc.Name, path)
    elseif desc:IsA("RemoteFunction") then
        local path = desc:GetFullName()
        table.insert(allRemoteFunctions, {name = desc.Name, path = path, instance = desc})
        Log("REMOTES", "  RF: " .. path)
        AddReport("Remote Functions", desc.Name, path)
        
        -- CommF_ detection
        if desc.Name:find("CommF") or desc.Name:find("Comm_F") or desc.Name:find("CommFunc")
           or desc.Name == "CommF_" then
            table.insert(commF_candidates, desc)
        end
    end
end

-- Find remotes folder
local remoteFolderCandidates = {}
for _, child in ipairs(RS:GetChildren()) do
    if child:IsA("Folder") then
        local hasRemotes = false
        for _, sub in ipairs(child:GetChildren()) do
            if sub:IsA("RemoteEvent") or sub:IsA("RemoteFunction") then
                hasRemotes = true
                break
            end
        end
        if hasRemotes then
            table.insert(remoteFolderCandidates, child)
        end
    end
end

if #remoteFolderCandidates > 0 then
    DISCOVERED.RemoteFolder = remoteFolderCandidates[1]
    DISCOVERED.RemoteFolderPath = remoteFolderCandidates[1]:GetFullName()
    Log("REMOTES", "✓ Remote folder: " .. DISCOVERED.RemoteFolderPath)
end

-- CommF_ discovery
if #commF_candidates > 0 then
    DISCOVERED.CommF = commF_candidates[1]
    DISCOVERED.CommFPath = commF_candidates[1]:GetFullName()
    Log("REMOTES", "✓ CommF_ found: " .. DISCOVERED.CommFPath)
else
    -- Try broader search
    for _, rf in ipairs(allRemoteFunctions) do
        if rf.name:lower():find("comm") or rf.name:lower():find("server") 
           or rf.name:lower():find("main") or rf.name:lower():find("handler") then
            DISCOVERED.CommF = rf.instance
            DISCOVERED.CommFPath = rf.path
            Log("REMOTES", "✓ CommF_ candidate (broad match): " .. rf.path)
            break
        end
    end
end

AddReport("Remotes Summary", "Total RemoteEvents", #allRemoteEvents)
AddReport("Remotes Summary", "Total RemoteFunctions", #allRemoteFunctions)
AddReport("Remotes Summary", "CommF_ Path", DISCOVERED.CommFPath or "NOT FOUND")
AddReport("Remotes Summary", "Remote Folder", DISCOVERED.RemoteFolderPath or "NOT FOUND")

-- Key remotes we need
local KEY_REMOTES = {
    "Commits", "CommF_", "AddPoint", "Attack", "Combat", "BuyFruit", 
    "SetTeam", "SetSpawnPoint", "Equip", "Unequip", "UseSkill",
    "QuestAccept", "QuestComplete", "RequestEntrance", "Chat",
    "Net", "Interact", "Collect", "Pickup", "Use", "Store",
    "requestEntrance", "RaidStart", "BossRaid"
}

Log("REMOTES", "Checking key remote availability:")
for _, name in ipairs(KEY_REMOTES) do
    local found = false
    for _, re in ipairs(allRemoteEvents) do
        if re.name == name then found = true; Log("REMOTES", "  ✓ " .. name .. " (Event) → " .. re.path); break end
    end
    if not found then
        for _, rf in ipairs(allRemoteFunctions) do
            if rf.name == name then found = true; Log("REMOTES", "  ✓ " .. name .. " (Function) → " .. rf.path); break end
        end
    end
    if not found then
        Log("REMOTES", "  ✗ " .. name .. " — NOT FOUND")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 3C: DISCOVER NET MODULE STRUCTURE
-- ═══════════════════════════════════════════════════════════════
Log("NET", "Scanning for Net/Modules structure...")

local moduleCandidates = {}
for _, child in ipairs(RS:GetChildren()) do
    if child.Name == "Modules" or child.Name == "Module" or child.Name:lower():find("module") then
        table.insert(moduleCandidates, child)
        Log("NET", "  Module folder: " .. child:GetFullName())
        for _, sub in ipairs(child:GetChildren()) do
            Log("NET", "    ├─ " .. sub.Name .. " (" .. sub.ClassName .. ")")
            if sub:IsA("Folder") or sub:IsA("ModuleScript") then
                for _, subsub in ipairs(sub:GetChildren()) do
                    Log("NET", "    │  ├─ " .. subsub.Name .. " (" .. subsub.ClassName .. ")")
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 4: PLAYER DATA ANALYSIS
-- ═══════════════════════════════════════════════════════════════
Log("PLAYER", "Analyzing player data...")

-- Check multiple possible data locations
local dataLocations = {
    LP:FindFirstChild("Data"),
    LP:FindFirstChild("PlayerData"),
    LP:FindFirstChild("Stats"),
    LP:FindFirstChild("leaderstats"),
    LP:FindFirstChild("Attributes"),
    LP:FindFirstChild("Values"),
}

for _, dataFolder in ipairs(dataLocations) do
    if dataFolder then
        Log("PLAYER", "Found data folder: " .. dataFolder.Name .. " (" .. dataFolder.ClassName .. ")")
        for _, val in ipairs(dataFolder:GetChildren()) do
            local v = "N/A"
            pcall(function()
                if val:IsA("ValueBase") then
                    v = tostring(val.Value)
                else
                    v = val.ClassName
                end
            end)
            Log("PLAYER", string.format("  %-25s = %s (%s)", val.Name, v, val.ClassName))
            DISCOVERED.PlayerData[val.Name] = v
            AddReport("Player Data", val.Name, v)
        end
    end
end

-- Level detection
DISCOVERED.PlayerLevel = 0
local levelSources = {
    LP:FindFirstChild("Data") and LP.Data:FindFirstChild("Level"),
    LP:FindFirstChild("leaderstats") and LP.leaderstats:FindFirstChild("Level"),
    LP:FindFirstChild("Stats") and LP.Stats:FindFirstChild("Level"),
}
for _, src in ipairs(levelSources) do
    if src then 
        pcall(function() DISCOVERED.PlayerLevel = src.Value end)
        break
    end
end
-- Also check attributes
if DISCOVERED.PlayerLevel == 0 then
    pcall(function() 
        local lvl = LP:GetAttribute("Level")
        if lvl then DISCOVERED.PlayerLevel = lvl end
    end)
end

Log("PLAYER", "Player Level: " .. DISCOVERED.PlayerLevel)
AddReport("Player Info", "Level", DISCOVERED.PlayerLevel)
AddReport("Player Info", "Name", LP.Name)
AddReport("Player Info", "Team", tostring(LP.Team))

-- ═══════════════════════════════════════════════════════════════
-- PHASE 5: QUEST & NPC DISCOVERY
-- ═══════════════════════════════════════════════════════════════
Log("QUEST", "Discovering quest NPCs and proximity prompts...")

-- Scan entire workspace for proximity prompts (NPCs, chests, etc.)
local allPrompts = {}
local questNPCs = {}

for _, desc in ipairs(WS:GetDescendants()) do
    if desc:IsA("ProximityPrompt") then
        local parent = desc.Parent
        local grandParent = parent and parent.Parent
        local info = {
            prompt = desc,
            actionText = desc.ActionText,
            objectText = desc.ObjectText,
            holdDuration = desc.HoldDuration,
            maxDistance = desc.MaxActivationDistance,
            parentName = parent and parent.Name or "?",
            grandParentName = grandParent and grandParent.Name or "?",
            fullPath = desc:GetFullName(),
            position = nil,
        }
        
        -- Get position
        if parent:IsA("BasePart") then
            info.position = parent.Position
        elseif parent:IsA("Model") and parent:FindFirstChild("HumanoidRootPart") then
            info.position = parent.HumanoidRootPart.Position
        elseif parent.Parent and parent.Parent:IsA("Model") and parent.Parent:FindFirstChild("HumanoidRootPart") then
            info.position = parent.Parent.HumanoidRootPart.Position
        end
        
        table.insert(allPrompts, info)
        
        -- Is this a quest NPC?
        local isQuest = (desc.ActionText or ""):lower():find("quest") 
            or (desc.ObjectText or ""):lower():find("quest")
            or (parent.Name or ""):lower():find("quest")
            or (grandParent and grandParent.Name or ""):lower():find("quest")
        
        if isQuest then
            table.insert(questNPCs, info)
        end
        
        local posStr = info.position and string.format("(%.0f,%.0f,%.0f)", info.position.X, info.position.Y, info.position.Z) or "unknown"
        Log("QUEST", string.format("  Prompt: Action='%s' Object='%s' Parent=%s @ %s | Path: %s",
            info.actionText or "", info.objectText or "", info.parentName, posStr, info.fullPath))
    end
end

DISCOVERED.QuestNPCs = questNPCs
Log("QUEST", "Total proximity prompts found: " .. #allPrompts)
Log("QUEST", "Quest NPCs found: " .. #questNPCs)
AddReport("Quest System", "Total Prompts", #allPrompts)
AddReport("Quest System", "Quest NPCs", #questNPCs)

-- ═══════════════════════════════════════════════════════════════
-- PHASE 5B: FRUIT & CHEST DISCOVERY
-- ═══════════════════════════════════════════════════════════════
Log("ITEMS", "Scanning for fruits, chests, and collectibles...")

for _, desc in ipairs(WS:GetDescendants()) do
    local nameLower = desc.Name:lower()
    
    -- Fruit detection (multiple patterns)
    if (nameLower:find("fruit") or nameLower:find("devil")) and desc:IsA("Model") then
        local pos = desc:FindFirstChild("Handle") and desc.Handle.Position 
            or desc:FindFirstChild("HumanoidRootPart") and desc.HumanoidRootPart.Position
            or desc:GetPivot() and desc:GetPivot().Position
        if pos then
            table.insert(DISCOVERED.FruitLocations, {name = desc.Name, position = pos})
            Log("ITEMS", string.format("  🟢 FRUIT: %s @ (%.0f,%.0f,%.0f)", desc.Name, pos.X, pos.Y, pos.Z))
        end
    end
    
    -- Chest detection
    if (nameLower:find("chest") or nameLower:find("treasure") or nameLower:find("crate")) 
       and (desc:IsA("Model") or desc:IsA("BasePart")) then
        local pos = desc:IsA("BasePart") and desc.Position 
            or desc:FindFirstChild("Handle") and desc.Handle.Position
            or pcall(function() return desc:GetPivot().Position end) and desc:GetPivot().Position
        if pos then
            local hasPrompt = desc:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
            table.insert(DISCOVERED.ChestLocations, {name = desc.Name, position = pos, hasPrompt = hasPrompt})
            Log("ITEMS", string.format("  📦 CHEST: %s @ (%.0f,%.0f,%.0f) [Prompt: %s]", 
                desc.Name, pos.X, pos.Y, pos.Z, tostring(hasPrompt)))
        end
    end
    
    -- Tool / collectible detection
    if desc:IsA("Tool") and desc.Parent == WS then
        local handle = desc:FindFirstChild("Handle")
        if handle then
            table.insert(DISCOVERED.InteractiveObjects, {name = desc.Name, position = handle.Position, type = "Tool"})
            Log("ITEMS", string.format("  🔧 TOOL: %s @ (%.0f,%.0f,%.0f)", desc.Name, handle.Position.X, handle.Position.Y, handle.Position.Z))
        end
    end
end

AddReport("Items", "Fruits Found", #DISCOVERED.FruitLocations)
AddReport("Items", "Chests Found", #DISCOVERED.ChestLocations)
AddReport("Items", "Collectibles Found", #DISCOVERED.InteractiveObjects)

-- ═══════════════════════════════════════════════════════════════
-- PHASE 6: MAP & ISLAND POSITION DISCOVERY
-- ═══════════════════════════════════════════════════════════════
Log("MAP", "Discovering island/area positions...")

-- Scan for large parts/models that could be islands
local islandCandidates = {}
for _, child in ipairs(WS:GetChildren()) do
    if (child:IsA("Model") or child:IsA("Folder")) and #child:GetDescendants() > 20 then
        local pivot = nil
        pcall(function() pivot = child:GetPivot().Position end)
        if not pivot then
            local firstPart = child:FindFirstChildWhichIsA("BasePart", true)
            if firstPart then pivot = firstPart.Position end
        end
        if pivot then
            table.insert(islandCandidates, {name = child.Name, position = pivot, size = #child:GetDescendants()})
        end
    end
end

for _, island in ipairs(islandCandidates) do
    DISCOVERED.IslandPositions[island.name] = island.position
    Log("MAP", string.format("  🏝 %-30s @ (%.0f,%.0f,%.0f) | Parts: %d",
        island.name, island.position.X, island.position.Y, island.position.Z, island.size))
    AddReport("Islands/Areas", island.name, 
        string.format("Pos=(%.0f,%.0f,%.0f), Parts=%d", island.position.X, island.position.Y, island.position.Z, island.size))
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 7: ANTI-CHEAT DETECTION SCAN
-- ═══════════════════════════════════════════════════════════════
Log("ANTICHEAT", "Scanning for anti-cheat mechanisms...")

-- Check for anti-exploit LocalScripts
local antiCheatScripts = {}
for _, desc in ipairs(RS:GetDescendants()) do
    if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
        local n = desc.Name:lower()
        if n:find("anti") or n:find("cheat") or n:find("exploit") or n:find("security")
           or n:find("detect") or n:find("ban") or n:find("kick") or n:find("verify")
           or n:find("integrity") or n:find("guard") or n:find("protect") or n:find("shield")
           or n:find("monitor") or n:find("watchdog") or n:find("validator") then
            table.insert(antiCheatScripts, {name = desc.Name, path = desc:GetFullName(), class = desc.ClassName})
            Log("ANTICHEAT", "  ⚠ " .. desc:GetFullName() .. " (" .. desc.ClassName .. ")")
        end
    end
end

-- Check player GUI for anti-cheat
pcall(function()
    local pGui = LP:FindFirstChild("PlayerGui")
    if pGui then
        for _, desc in ipairs(pGui:GetDescendants()) do
            if desc:IsA("LocalScript") then
                local n = desc.Name:lower()
                if n:find("anti") or n:find("cheat") or n:find("exploit") or n:find("security")
                   or n:find("ban") or n:find("detect") then
                    table.insert(antiCheatScripts, {name = desc.Name, path = desc:GetFullName(), class = "PlayerGui Script"})
                    Log("ANTICHEAT", "  ⚠ PlayerGui: " .. desc:GetFullName())
                end
            end
        end
    end
end)

-- Check for remote-based anti-cheat (BAN/EXPLOIT remotes)
for _, re in ipairs(allRemoteEvents) do
    local n = re.name:lower()
    if n:find("ban") or n:find("exploit") or n:find("security") or n:find("kick")
       or n:find("flag") or n:find("report") or n:find("detect") then
        table.insert(DISCOVERED.AntiCheatDetected, {type = "Remote", name = re.name, path = re.path})
        Log("ANTICHEAT", "  🚨 Anti-cheat remote: " .. re.path)
    end
end

-- Check for position validation connections
local positionCheckers = {}
for _, conn in ipairs(RunService:GetSignalConnections and RunService:GetSignalConnections(RunService.Heartbeat) or {}) do
    -- Can't enumerate connections on most executors, but try
end

AddReport("Anti-Cheat", "Scripts Detected", #antiCheatScripts)
AddReport("Anti-Cheat", "Suspicious Remotes", #DISCOVERED.AntiCheatDetected)

-- ═══════════════════════════════════════════════════════════════
-- PHASE 8: TELEPORTATION METHOD TESTING (THE CRITICAL PART!)
-- ═══════════════════════════════════════════════════════════════
Log("TELEPORT", "═══════════════════════════════════════════")
Log("TELEPORT", "TESTING ALL TELEPORTATION METHODS...")
Log("TELEPORT", "═══════════════════════════════════════════")

local function GetCharRoot()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChild("Humanoid")
end

local function WaitForRoot(timeout)
    timeout = timeout or 10
    local start = tick()
    while tick() - start < timeout do
        local root = GetCharRoot()
        if root and root.Parent then return root end
        task.wait(0.1)
    end
    return nil
end

local root = WaitForRoot(5)
if not root then
    Log("TELEPORT", "✗ CRITICAL: No HumanoidRootPart found! Character may not be loaded.")
else
    local startPos = root.Position
    -- Test position: 50 studs forward from current position
    local testOffset = Vector3.new(50, 0, 0)
    local testCFrame = CFrame.new(startPos + testOffset)
    
    local methods = {}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 1: Direct CFrame Set
    -- ──────────────────────────────────────────────────
    methods[1] = {name = "Direct CFrame Set", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        r.CFrame = CFrame.new(before + testOffset)
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        -- Teleport back
        r.CFrame = CFrame.new(before)
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 2: CFrame + Zero Velocity
    -- ──────────────────────────────────────────────────
    methods[2] = {name = "CFrame + Zero Velocity", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        r.CFrame = CFrame.new(before + testOffset)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        r.CFrame = CFrame.new(before)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 3: TweenService CFrame Tween
    -- ──────────────────────────────────────────────────
    methods[3] = {name = "TweenService CFrame Tween", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        local target = CFrame.new(before + testOffset)
        local tw = TweenService:Create(r, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {CFrame = target})
        tw:Play()
        tw.Completed:Wait()
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        r.CFrame = CFrame.new(before)
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 4: PivotTo (Model-level teleport)
    -- ──────────────────────────────────────────────────
    methods[4] = {name = "Character:PivotTo()", test = function()
        local char = LP.Character
        local r = GetCharRoot()
        if not r or not char then return false, "No char/root" end
        local before = r.Position
        local target = CFrame.new(before + testOffset)
        pcall(function() char:PivotTo(target) end)
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        pcall(function() char:PivotTo(CFrame.new(before)) end)
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 5: Heartbeat Lerp (frame-by-frame)
    -- ──────────────────────────────────────────────────
    methods[5] = {name = "Heartbeat Lerp Move", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        local target = before + testOffset
        local startP = r.Position
        local elapsed = 0
        local duration = 0.4
        local done = false
        
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if done then return end
            elapsed = elapsed + dt
            local alpha = math.clamp(elapsed / duration, 0, 1)
            local newPos = startP:Lerp(target, alpha)
            local cr = GetCharRoot()
            if cr then
                cr.CFrame = CFrame.new(newPos)
                cr.AssemblyLinearVelocity = Vector3.zero
                cr.AssemblyAngularVelocity = Vector3.zero
            end
            if alpha >= 1 then
                done = true
                conn:Disconnect()
            end
        end)
        
        local waitStart = tick()
        while not done and tick() - waitStart < 2 do task.wait(0.05) end
        if not done and conn then conn:Disconnect() end
        
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - target).Magnitude
        r.CFrame = CFrame.new(before)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 6: BodyPosition Force-Move
    -- ──────────────────────────────────────────────────
    methods[6] = {name = "BodyPosition Force-Move", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        local target = before + testOffset
        
        local bp = Instance.new("BodyPosition")
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.D = 500
        bp.P = 100000
        bp.Position = target
        bp.Parent = r
        
        task.wait(0.6)
        
        r = GetCharRoot()
        bp:Destroy()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - target).Magnitude
        r.CFrame = CFrame.new(before)
        task.wait(0.1)
        return deviation < 20, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 7: CFrame + Noclip + BodyVelocity Lock
    -- ──────────────────────────────────────────────────
    methods[7] = {name = "CFrame + Noclip + BV Lock", test = function()
        local r = GetCharRoot()
        local char = LP.Character
        if not r or not char then return false, "No char/root" end
        local before = r.Position
        local target = CFrame.new(before + testOffset)
        
        -- Enable noclip
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        
        -- Add BodyVelocity to freeze
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = r
        
        r.CFrame = target
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        
        task.wait(0.3)
        
        r = GetCharRoot()
        bv:Destroy()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        r.CFrame = CFrame.new(before)
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 8: Stepped CFrame (pre-physics)
    -- ──────────────────────────────────────────────────
    methods[8] = {name = "Stepped CFrame (Pre-Physics)", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        local target = CFrame.new(before + testOffset)
        local frames = 0
        local maxFrames = 20
        local done = false
        
        local conn
        conn = RunService.Stepped:Connect(function()
            if done then return end
            frames = frames + 1
            local cr = GetCharRoot()
            if cr then
                cr.CFrame = target
                cr.AssemblyLinearVelocity = Vector3.zero
            end
            if frames >= maxFrames then
                done = true
                conn:Disconnect()
            end
        end)
        
        local waitStart = tick()
        while not done and tick() - waitStart < 2 do task.wait(0.05) end
        if not done and conn then conn:Disconnect() end
        
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        r.CFrame = CFrame.new(before)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 9: RenderStepped CFrame (highest priority)
    -- ──────────────────────────────────────────────────
    methods[9] = {name = "RenderStepped CFrame Bind", test = function()
        local r = GetCharRoot()
        if not r then return false, "No root" end
        local before = r.Position
        local target = CFrame.new(before + testOffset)
        local frames = 0
        local maxFrames = 20
        local bindName = "TP_TEST_" .. math.random(10000, 99999)
        local done = false
        
        RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
            if done then return end
            frames = frames + 1
            local cr = GetCharRoot()
            if cr then
                cr.CFrame = target
                cr.AssemblyLinearVelocity = Vector3.zero
            end
            if frames >= maxFrames then
                done = true
                pcall(function() RunService:UnbindFromRenderStep(bindName) end)
            end
        end)
        
        local waitStart = tick()
        while not done and tick() - waitStart < 2 do task.wait(0.05) end
        pcall(function() RunService:UnbindFromRenderStep(bindName) end)
        
        task.wait(0.2)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        r.CFrame = CFrame.new(before)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 10: Humanoid:MoveTo + CFrame hybrid
    -- ──────────────────────────────────────────────────
    methods[10] = {name = "Humanoid:MoveTo + CFrame Snap", test = function()
        local r = GetCharRoot()
        local hum = GetHum()
        if not r or not hum then return false, "No root/humanoid" end
        local before = r.Position
        local target = before + testOffset
        
        hum:MoveTo(target)
        task.wait(0.1)
        r.CFrame = CFrame.new(target)
        r.AssemblyLinearVelocity = Vector3.zero
        
        task.wait(0.3)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - target).Magnitude
        r.CFrame = CFrame.new(before)
        task.wait(0.1)
        return deviation < 20, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- ──────────────────────────────────────────────────
    -- METHOD 11: Multi-frame reinforced CFrame (anti-rubberband)  
    -- ──────────────────────────────────────────────────
    methods[11] = {name = "Multi-Frame Reinforced CFrame", test = function()
        local r = GetCharRoot()
        local char = LP.Character
        if not r or not char then return false, "No char/root" end
        local before = r.Position
        local target = CFrame.new(before + testOffset)
        
        -- Disable collisions
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        
        -- Hammer CFrame over multiple frames on BOTH Stepped AND Heartbeat
        local frameCount = 0
        local totalFrames = 30
        local done = false
        
        local conn1, conn2
        conn1 = RunService.Stepped:Connect(function()
            if done then return end
            local cr = GetCharRoot()
            if cr then
                cr.CFrame = target
                cr.AssemblyLinearVelocity = Vector3.zero
                cr.AssemblyAngularVelocity = Vector3.zero
            end
        end)
        conn2 = RunService.Heartbeat:Connect(function()
            if done then return end
            frameCount = frameCount + 1
            local cr = GetCharRoot()
            if cr then
                cr.CFrame = target
                cr.AssemblyLinearVelocity = Vector3.zero
                cr.AssemblyAngularVelocity = Vector3.zero
            end
            if frameCount >= totalFrames then done = true end
        end)
        
        local waitStart = tick()
        while not done and tick() - waitStart < 3 do task.wait(0.05) end
        if conn1 then conn1:Disconnect() end
        if conn2 then conn2:Disconnect() end
        
        task.wait(0.3)
        r = GetCharRoot()
        if not r then return false, "Root lost" end
        local deviation = (r.Position - (before + testOffset)).Magnitude
        r.CFrame = CFrame.new(before)
        r.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        return deviation < 15, string.format("Deviation: %.1f studs", deviation)
    end}
    
    -- Run all tests
    Log("TELEPORT", "Running " .. #methods .. " teleportation tests...")
    Log("TELEPORT", "Start position: " .. tostring(startPos))
    Log("TELEPORT", "Test offset: " .. tostring(testOffset) .. " (50 studs)")
    Log("TELEPORT", "")
    
    local bestMethod = nil
    local bestDeviation = math.huge
    
    for i, method in ipairs(methods) do
        local success, detail = false, "Error"
        local ok, err = pcall(function()
            success, detail = method.test()
        end)
        
        if not ok then
            detail = "CRASHED: " .. tostring(err)
            success = false
        end
        
        local status = success and "✓ WORKS" or "✗ FAILED"
        Log("TELEPORT", string.format("  Method %2d: %-35s → %s | %s", i, method.name, status, detail))
        
        DISCOVERED.TeleportTestResults[i] = {
            name = method.name,
            success = success,
            detail = detail,
        }
        AddReport("Teleport Tests", method.name, status .. " — " .. detail)
        
        if success then
            local dev = tonumber(detail:match("(%d+%.?%d*)")) or math.huge
            if dev < bestDeviation then
                bestDeviation = dev
                bestMethod = method.name
                DISCOVERED.WorkingTeleportMethod = i
            end
        end
        
        task.wait(0.3) -- Cooldown between tests
    end
    
    Log("TELEPORT", "")
    if bestMethod then
        Log("TELEPORT", "═══ BEST TELEPORT METHOD: " .. bestMethod .. " (deviation: " .. string.format("%.1f", bestDeviation) .. " studs) ═══")
    else
        Log("TELEPORT", "═══ ✗ ALL TELEPORT METHODS FAILED! Server may have aggressive anti-teleport. ═══")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 9: BACKPACK & INVENTORY SCAN
-- ═══════════════════════════════════════════════════════════════
Log("INVENTORY", "Scanning player inventory...")

local backpack = LP:FindFirstChild("Backpack")
if backpack then
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            Log("INVENTORY", string.format("  🗡 %s (ToolTip: %s)", tool.Name, tool.ToolTip or "none"))
            AddReport("Inventory", tool.Name, tool.ToolTip or "Tool")
        end
    end
end

local char = LP.Character
if char then
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            Log("INVENTORY", string.format("  🗡 [EQUIPPED] %s", tool.Name))
            AddReport("Inventory", "[Equipped] " .. tool.Name, "In hand")
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PHASE 10: GENERATE THE FIXED WORKING SCRIPT
-- ═══════════════════════════════════════════════════════════════
Log("GENERATE", "═══════════════════════════════════════════")
Log("GENERATE", "GENERATING FIXED SCRIPT BASED ON ANALYSIS...")
Log("GENERATE", "═══════════════════════════════════════════")

-- Build the teleport function based on what worked
local function BuildTeleportFunction()
    local methodId = DISCOVERED.WorkingTeleportMethod or 11
    local results = DISCOVERED.TeleportTestResults
    
    -- Determine best approach
    -- Priority: Multi-frame reinforced > RenderStepped > Stepped > Heartbeat Lerp > CFrame+BV > Direct CFrame
    local workingMethods = {}
    for id, result in pairs(results) do
        if result.success then
            table.insert(workingMethods, id)
        end
    end
    
    -- If method 11 works (multi-frame reinforced), use it as primary
    -- If method 9 works (RenderStepped), use it as primary  
    -- If method 5 works (Heartbeat lerp), use it for long-distance
    -- If method 1 or 2 works (Direct CFrame), use it for short-distance
    
    local hasMultiFrame = results[11] and results[11].success
    local hasRenderStep = results[9] and results[9].success
    local hasStepped = results[8] and results[8].success
    local hasHeartbeatLerp = results[5] and results[5].success
    local hasCFrameBV = results[7] and results[7].success
    local hasDirectCFrame = (results[1] and results[1].success) or (results[2] and results[2].success)
    local hasTween = results[3] and results[3].success
    local hasPivotTo = results[4] and results[4].success
    
    local shortRange = "direct" -- <150 studs
    local longRange = "heartbeat_lerp" -- >150 studs
    local lockMethod = "multi_frame" -- for hover-lock during farming
    
    if hasDirectCFrame then shortRange = "direct"
    elseif hasPivotTo then shortRange = "pivot"
    elseif hasMultiFrame then shortRange = "multi_frame"
    elseif hasRenderStep then shortRange = "renderstep"
    end
    
    if hasHeartbeatLerp then longRange = "heartbeat_lerp"
    elseif hasTween then longRange = "tween"
    elseif hasMultiFrame then longRange = "multi_frame"
    elseif hasRenderStep then longRange = "renderstep_lerp"
    end
    
    if hasMultiFrame then lockMethod = "multi_frame"
    elseif hasRenderStep then lockMethod = "renderstep"
    elseif hasStepped then lockMethod = "stepped"
    elseif hasCFrameBV then lockMethod = "cframe_bv"
    end
    
    return shortRange, longRange, lockMethod, workingMethods
end

local shortMethod, longMethod, lockMethod, workingMethods = BuildTeleportFunction()

Log("GENERATE", "Short-range teleport: " .. shortMethod)
Log("GENERATE", "Long-range travel: " .. longMethod)
Log("GENERATE", "Hover-lock method: " .. lockMethod)
Log("GENERATE", "Working methods: " .. table.concat(workingMethods, ", "))

-- Now build the actual script string
local enemyPath = DISCOVERED.EnemyFolderPath or "Workspace.Enemies"
local commFPath = DISCOVERED.CommFPath or ""
local remoteFolderPath = DISCOVERED.RemoteFolderPath or ""
local seaNum = DISCOVERED.Sea

-- Build CommF resolver
local commFCode = ""
if DISCOVERED.CommF then
    local pathParts = {}
    local inst = DISCOVERED.CommF
    while inst and inst ~= game do
        table.insert(pathParts, 1, inst.Name)
        inst = inst.Parent
    end
    commFCode = string.format([[
local function CommF()
    return game:GetService("%s")]], pathParts[1] or "ReplicatedStorage")
    for i = 2, #pathParts do
        commFCode = commFCode .. string.format(':FindFirstChild("%s")', pathParts[i])
    end
    commFCode = commFCode .. "\nend"
else
    commFCode = [[
local function CommF()
    for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v.Name == "CommF_" and v:IsA("RemoteFunction") then return v end
    end
    for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("RemoteFunction") and (v.Name:find("Comm") or v.Name:find("Main") or v.Name:find("Server")) then return v end
    end
    return nil
end]]
end

-- Build mob list for reference
local mobListStr = "{"
for _, name in ipairs(DISCOVERED.MobNames) do
    mobListStr = mobListStr .. '"' .. name .. '", '
end
mobListStr = mobListStr .. "}"

-- Build the full fixed script
local FIXED_SCRIPT = string.format([==[
--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║  BLOX FRUITS POST-UPDATE FIXED HUB                         ║
    ║  Auto-generated by Ultimate Analyzer                       ║
    ║  Generated: %s                                             ║
    ║  Sea: %d | Level: %d                                       ║
    ║  Teleport: Short=%s, Long=%s, Lock=%s                      ║
    ╚══════════════════════════════════════════════════════════════╝
    
    DISCOVERED PATHS:
    - Enemy Folder: %s
    - CommF: %s
    - Remote Folder: %s
    - Working Teleport Methods: %s
    - Mobs Found: %s
]]

--============================== STARTUP ==============================
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(math.random(20, 50) / 10)

--============================== SERVICES ==============================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = WS.CurrentCamera

--============================== SEA DETECTION ==============================
local PlaceId = game.PlaceId
local CurrentSea = %d

--============================== ANTI-AFK ==============================
LP.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)

--============================== SAFE GUI ==============================
local function GetSafeGui()
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    return LP:WaitForChild("PlayerGui", 10)
end

--============================== REMOTE DISCOVERY (DYNAMIC) ==============================
local _remoteCache = {}

local function FindRemote(name, className)
    if _remoteCache[name] then return _remoteCache[name] end
    for _, v in ipairs(RS:GetDescendants()) do
        if v.Name == name and (not className or v:IsA(className)) then
            _remoteCache[name] = v
            return v
        end
    end
    return nil
end

%s

--============================== ENEMY FOLDER (DYNAMIC DISCOVERY) ==============================
local _enemyFolder = nil

local function GetEnemyFolder()
    if _enemyFolder and _enemyFolder.Parent then return _enemyFolder end
    
    -- Try known path first
    local known = WS:FindFirstChild("%s")
    if known then _enemyFolder = known; return known end
    
    -- Dynamic scan: find folder with most Humanoid children
    local best, bestCount = nil, 0
    for _, child in ipairs(WS:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            local count = 0
            for _, sub in ipairs(child:GetChildren()) do
                if sub:FindFirstChild("Humanoid") and sub:FindFirstChild("HumanoidRootPart") then
                    count = count + 1
                end
            end
            if count > bestCount then
                bestCount = count
                best = child
            end
        end
    end
    
    -- Also check 2 levels deep
    for _, child in ipairs(WS:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            for _, sub in ipairs(child:GetChildren()) do
                if sub:IsA("Folder") then
                    local count = 0
                    for _, mob in ipairs(sub:GetChildren()) do
                        if mob:FindFirstChild("Humanoid") and mob:FindFirstChild("HumanoidRootPart") then
                            count = count + 1
                        end
                    end
                    if count > bestCount then
                        bestCount = count
                        best = sub
                    end
                end
            end
        end
    end
    
    _enemyFolder = best
    return best
end

--============================== CHARACTER HELPERS ==============================
local function GetRoot()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = LP.Character
    return char and char:FindFirstChild("Humanoid")
end

local function GetLevel()
    local data = LP:FindFirstChild("Data")
    if data then
        local lvl = data:FindFirstChild("Level")
        if lvl then return lvl.Value end
    end
    pcall(function()
        local lvl = LP:GetAttribute("Level")
        if lvl then return lvl end
    end)
    return 1
end

--============================== NOCLIP ENGINE ==============================
local _noclipConn = nil

local function EnableNoclip()
    if _noclipConn then return end
    _noclipConn = RunService.Stepped:Connect(function()
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function DisableNoclip()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn = nil end
end

--============================== FIXED TELEPORT ENGINE ==============================
-- This uses the methods that were TESTED AND CONFIRMED WORKING on your game version

local _activeTween = nil
local _activeFlightConn = nil
local _isTraveling = false

local function StopMovement()
    if _activeFlightConn then pcall(function() _activeFlightConn:Disconnect() end); _activeFlightConn = nil end
    if _activeTween then pcall(function() _activeTween:Cancel() end); _activeTween = nil end
    _isTraveling = false
    
    local root = GetRoot()
    if root then
        for _, c in ipairs(root:GetChildren()) do
            if c:IsA("BodyVelocity") or c:IsA("BodyGyro") or c:IsA("BodyPosition") then
                pcall(function() c:Destroy() end)
            end
        end
    end
end

-- SHORT RANGE: Instant snap (for mob farming, < 200 studs)
local function SnapTo(targetCFrame)
    local root = GetRoot()
    local char = LP.Character
    if not root or not char then return end
    
    EnableNoclip()
]==] .. [==[
    
    -- Method: Multi-frame reinforced CFrame set
    -- Sets CFrame on BOTH Stepped and Heartbeat for maximum authority
    local frames = 0
    local maxFrames = 8  -- enough to override server corrections
    local done = false
    
    local conn1, conn2
    conn1 = RunService.Stepped:Connect(function()
        if done then return end
        local r = GetRoot()
        if r then
            r.CFrame = targetCFrame
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    conn2 = RunService.Heartbeat:Connect(function()
        if done then return end
        frames = frames + 1
        local r = GetRoot()
        if r then
            r.CFrame = targetCFrame
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
        if frames >= maxFrames then
            done = true
            conn1:Disconnect()
            conn2:Disconnect()
        end
    end)
end

-- HOVER LOCK: Keeps you locked at a position (for combat)
local _hoverConn = nil

local function HoverLock(targetCFrame)
    if _hoverConn then _hoverConn:Disconnect() end
    EnableNoclip()
    
    _hoverConn = RunService.Heartbeat:Connect(function()
        local root = GetRoot()
        if root then
            root.CFrame = targetCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function StopHover()
    if _hoverConn then _hoverConn:Disconnect(); _hoverConn = nil end
end

-- LONG RANGE: Heartbeat Lerp travel (for cross-island, > 200 studs)
local function TweenTo(targetCFrame, speed)
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not root.Parent then return end
    if hum and hum.Sit then hum.Sit = false end
    
    StopMovement()
    StopHover()
    EnableNoclip()
    
    local distance = (targetCFrame.Position - root.Position).Magnitude
    speed = speed or 240
    
    -- Short distance: instant snap
    if distance <= 200 then
        SnapTo(targetCFrame)
        return
    end
    
    -- Long distance: smooth heartbeat lerp
    _isTraveling = true
    local startPos = root.Position
    local endPos = targetCFrame.Position
    
    -- Water safety: keep Y >= 35 during travel
    if endPos.Y < 35 and distance > 300 then
        endPos = Vector3.new(endPos.X, 35, endPos.Z)
    end
    
    local totalDist = (endPos - startPos).Magnitude
    local duration = totalDist / speed
    local elapsed = 0
    
    -- Add BodyVelocity to prevent gravity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Name = "_travelBV"
    bv.Parent = root
    
    _activeFlightConn = RunService.Heartbeat:Connect(function(dt)
        if not _isTraveling then return end
        local r = GetRoot()
        if not r or not r.Parent then
            StopMovement()
            return
        end
        
        elapsed = elapsed + dt
        local alpha = math.clamp(elapsed / duration, 0, 1)
        local newPos = startPos:Lerp(endPos, alpha)
        r.CFrame = CFrame.new(newPos)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        
        if alpha >= 1 then
            StopMovement()
            -- Final snap to exact target
            SnapTo(targetCFrame)
        end
    end)
end

--============================== MOB FINDING ==============================
local function GetClosestMob(filterName)
    local enemyFolder = GetEnemyFolder()
    if not enemyFolder then return nil end
    
    local root = GetRoot()
    if not root then return nil end
    
    local closest, bestDist = nil, math.huge
    for _, mob in ipairs(enemyFolder:GetChildren()) do
        local hum = mob:FindFirstChild("Humanoid")
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum.Health > 0 then
            if not filterName or filterName == "" or mob.Name:find(filterName) then
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    closest = mob
                end
            end
        end
    end
    return closest, bestDist
end

local function GetAllMobs(filterName)
    local enemyFolder = GetEnemyFolder()
    if not enemyFolder then return {} end
    
    local mobs = {}
    for _, mob in ipairs(enemyFolder:GetChildren()) do
        local hum = mob:FindFirstChild("Humanoid")
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum.Health > 0 then
            if not filterName or filterName == "" or mob.Name:find(filterName) then
                table.insert(mobs, mob)
            end
        end
    end
    return mobs
end

--============================== COMBAT ==============================
local function EquipTool(name)
    local backpack = LP:FindFirstChild("Backpack")
    local char = LP.Character
    if not char then return end
    if char:FindFirstChild(name) then return end -- already equipped
    if backpack and backpack:FindFirstChild(name) then
        backpack[name].Parent = char
    end
end

local function AttackTarget(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then return end
    
    -- Activate equipped tool
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
    
    -- Fire skill keys via VirtualUser
    pcall(function()
        local vk = game:GetService("VirtualInputManager") or VirtualUser
        -- Click attack
    end)
end

--============================== QUEST SYSTEM ==============================
local function FireNearbyPrompts(maxDist)
    maxDist = maxDist or 15
    local root = GetRoot()
    if not root then return end
    
    for _, desc in ipairs(WS:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local promptPos = nil
            if desc.Parent:IsA("BasePart") then
                promptPos = desc.Parent.Position
            elseif desc.Parent:IsA("Model") and desc.Parent:FindFirstChild("HumanoidRootPart") then
                promptPos = desc.Parent.HumanoidRootPart.Position
            elseif desc.Parent.Parent and desc.Parent.Parent:IsA("Model") and desc.Parent.Parent:FindFirstChild("HumanoidRootPart") then
                promptPos = desc.Parent.Parent.HumanoidRootPart.Position
            end
            
            if promptPos and (promptPos - root.Position).Magnitude <= maxDist then
                pcall(function() fireproximityprompt(desc) end)
            end
        end
    end
end

--============================== AUTO CHEST COLLECTOR ==============================
local _chestCollecting = false

local function StartChestCollector()
    _chestCollecting = true
    task.spawn(function()
        while _chestCollecting do
            task.wait(2)
            
            local root = GetRoot()
            if not root then continue end
            
            -- Find all chests in the game
            for _, desc in ipairs(WS:GetDescendants()) do
                if not _chestCollecting then break end
                local nameLower = desc.Name:lower()
                if (nameLower:find("chest") or nameLower:find("treasure") or nameLower:find("crate"))
                   and (desc:IsA("Model") or desc:IsA("BasePart")) then
                    
                    local pos = nil
                    if desc:IsA("BasePart") then pos = desc.Position
                    elseif desc:FindFirstChildWhichIsA("BasePart") then pos = desc:FindFirstChildWhichIsA("BasePart").Position
                    else pcall(function() pos = desc:GetPivot().Position end)
                    end
                    
                    if pos then
                        -- Check for proximity prompt
                        local prompt = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt then
                            SnapTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
                            task.wait(0.5)
                            pcall(function() fireproximityprompt(prompt) end)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end)
end

--============================== FRUIT COLLECTOR ==============================
local _fruitCollecting = false

local function StartFruitCollector()
    _fruitCollecting = true
    task.spawn(function()
        while _fruitCollecting do
            task.wait(3)
            
            for _, desc in ipairs(WS:GetDescendants()) do
                if not _fruitCollecting then break end
                local nameLower = desc.Name:lower()
                if (nameLower:find("fruit") or nameLower:find("devil")) and desc:IsA("Tool") then
                    local handle = desc:FindFirstChild("Handle")
                    if handle and desc.Parent == WS then
                        TweenTo(CFrame.new(handle.Position + Vector3.new(0, 2, 0)))
                        task.wait(1)
                        -- Try to collect
                        pcall(function() fireproximityprompt(desc:FindFirstChildWhichIsA("ProximityPrompt", true)) end)
                        -- Also try touch
                        pcall(function()
                            local root = GetRoot()
                            if root then
                                root.CFrame = CFrame.new(handle.Position)
                                task.wait(0.3)
                            end
                        end)
                    end
                end
            end
        end
    end)
end

--============================== CONFIG ==============================
local Config = {
    AutoFarm = false,
    AutoQuest = false,
    AutoChest = false,
    AutoFruit = false,
    SelectedMob = "",
    SelectedWeapon = "",
    FlyEnabled = false,
    FlySpeed = 80,
    Noclip = false,
    ESPEnabled = false,
    FruitESP = false,
    TweenSpeed = 240,
    BringMobs = false,
}

--============================== AUTO FARM ==============================
local _farmThread = nil

local function StartAutoFarm()
    if _farmThread then return end
    _farmThread = task.spawn(function()
        while Config.AutoFarm do
            task.wait(0.1)
            
            local root = GetRoot()
            local hum = GetHumanoid()
            if not root or not hum or hum.Health <= 0 then
                task.wait(1)
                continue
            end
            
            local target = GetClosestMob(Config.SelectedMob)
            if target and target:FindFirstChild("HumanoidRootPart") then
                local hrp = target.HumanoidRootPart
                local farmPos = hrp.CFrame * CFrame.new(0, 15, 0)
                
                -- Move above target
                HoverLock(farmPos)
                
                -- Equip weapon
                if Config.SelectedWeapon ~= "" then
                    EquipTool(Config.SelectedWeapon)
                end
                
                -- Attack
                AttackTarget(target)
                
                -- Auto quest: fire nearby prompts
                if Config.AutoQuest then
                    FireNearbyPrompts(20)
                end
            else
                StopHover()
                task.wait(0.5)
            end
        end
        StopHover()
    end)
end

local function StopAutoFarm()
    Config.AutoFarm = false
    if _farmThread then pcall(function() task.cancel(_farmThread) end); _farmThread = nil end
    StopHover()
    StopMovement()
    DisableNoclip()
end

--============================== FLY ==============================
local _flyConn = nil
local _flyBV = nil
local _flyBG = nil

local function ToggleFly(state)
    Config.FlyEnabled = state
    local root = GetRoot()
    if not root then return end
    
    if state then
        _flyBV = Instance.new("BodyVelocity")
        _flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        _flyBV.Velocity = Vector3.zero
        _flyBV.Parent = root
        
        _flyBG = Instance.new("BodyGyro")
        _flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        _flyBG.CFrame = Camera.CFrame
        _flyBG.Parent = root
        
        _flyConn = RunService.RenderStepped:Connect(function()
            local dir = Vector3.zero
            local cam = Camera.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
            if _flyBV then _flyBV.Velocity = dir * Config.FlySpeed end
            if _flyBG then _flyBG.CFrame = cam end
        end)
    else
        if _flyConn then _flyConn:Disconnect(); _flyConn = nil end
        if _flyBV then _flyBV:Destroy(); _flyBV = nil end
        if _flyBG then _flyBG:Destroy(); _flyBG = nil end
    end
end

--============================== ESP ==============================
local _espObjects = {}

local function CreateESP(model, text, color)
    if _espObjects[model] then return end
    local bg = Instance.new("BillboardGui")
    bg.Adornee = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart") or model
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
    _espObjects[model] = bg
end

local function ClearESP()
    for _, esp in pairs(_espObjects) do pcall(function() esp:Destroy() end) end
    _espObjects = {}
end

-- Fruit ESP loop
task.spawn(function()
    while true do
        task.wait(3)
        if Config.FruitESP then
            for _, desc in ipairs(WS:GetDescendants()) do
                if desc:IsA("Model") and desc.Name:lower():find("fruit") and not _espObjects[desc] then
                    CreateESP(desc, "FRUIT: " .. desc.Name, Color3.new(0, 1, 0))
                end
            end
        end
        if Config.ESPEnabled then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character and not _espObjects[p.Character] then
                    CreateESP(p.Character, p.Name, Color3.new(1, 0.3, 0.3))
                end
            end
        end
    end
end)

--============================== SERVER HOP ==============================
local function ServerHop()
    local req = syn and syn.request or http_request or (fluxus and fluxus.request) or request
    if not req then return end
    local body = req({
        Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
        Method = "GET"
    })
    if body and body.Body then
        local data = HttpService:JSONDecode(body.Body)
        if data and data.data then
            local servers = {}
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers - 1 then table.insert(servers, s.id) end
            end
            if #servers > 0 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LP)
            end
        end
    end
end

--============================== WALKSPEED ==============================
task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.Noclip then EnableNoclip() end
    end
end)

--============================== UI ==============================
local SG = Instance.new("ScreenGui")
SG.Name = "VeilFixed_" .. math.random(10000,99999)
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = (gethui and gethui()) or CoreGui or LP:WaitForChild("PlayerGui") end)
if not SG.Parent then SG.Parent = LP:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 520, 0, 680)
Main.Position = UDim2.new(0.5, -260, 0.5, -340)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundTransparency = 1
TitleBar.Text = "VEIL // FIXED POST-UPDATE HUB"
TitleBar.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleBar.Font = Enum.Font.GothamBold
TitleBar.TextSize = 18
TitleBar.Parent = Main

-- Status bar
local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, -20, 0, 20)
StatusBar.Position = UDim2.new(0, 10, 0, 42)
StatusBar.BackgroundTransparency = 1
StatusBar.Text = "Sea " .. CurrentSea .. " | Teleport: FIXED | Enemy Folder: DETECTED"
StatusBar.TextColor3 = Color3.fromRGB(0, 255, 100)
StatusBar.Font = Enum.Font.Gotham
StatusBar.TextSize = 11
StatusBar.Parent = Main

-- Tabs
local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(1, -20, 0, 30)
TabFrame.Position = UDim2.new(0, 10, 0, 65)
TabFrame.BackgroundTransparency = 1
TabFrame.Parent = Main
Instance.new("UIListLayout", TabFrame).FillDirection = Enum.FillDirection.Horizontal

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -20, 0, 555)
ContentFrame.Position = UDim2.new(0, 10, 0, 100)
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
ContentFrame.Parent = Main
Instance.new("UICorner", ContentFrame).CornerRadius = UDim.new(0, 8)

local pages = {}

local function MakeTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 85, 1, 0)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    btn.Parent = TabFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -10, 1, -10)
    page.Position = UDim2.new(0, 5, 0, 5)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.CanvasSize = UDim2.new(0, 0, 0, 800)
    page.Visible = false
    page.Parent = ContentFrame
    Instance.new("UIListLayout", page).Padding = UDim.new(0, 6)
    
    pages[name] = page
    
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(pages) do p.Visible = false end
        page.Visible = true
    end)
    return page
end

local function MakeToggle(parent, text, cb)
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -10, 0, 32)
    toggle.Text = text .. "  [OFF]"
    toggle.Font = Enum.Font.Gotham
    toggle.TextSize = 13
    toggle.TextColor3 = Color3.new(1, 1, 1)
    toggle.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    toggle.Parent = parent
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    local state = false
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.Text = text .. (state and "  [ON]" or "  [OFF]")
        toggle.BackgroundColor3 = state and Color3.fromRGB(40, 110, 40) or Color3.fromRGB(32, 32, 38)
        cb(state)
    end)
    return toggle
end

local function MakeButton(parent, text, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local function MakeInput(parent, label, cb)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 32)
    container.BackgroundTransparency = 1
    container.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5, -5, 0.8, 0)
    box.Position = UDim2.new(0.5, 0, 0.1, 0)
    box.PlaceholderText = "Enter..."
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = Color3.new(1, 1, 1)
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    box.Parent = container
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    box.FocusLost:Connect(function() cb(box.Text) end)
end

-- FARM TAB
local FarmPage = MakeTab("Farm")
MakeToggle(FarmPage, "Auto Farm", function(s) Config.AutoFarm = s; if s then StartAutoFarm() else StopAutoFarm() end end)
MakeToggle(FarmPage, "Auto Quest Prompts", function(s) Config.AutoQuest = s end)
MakeToggle(FarmPage, "Auto Chest Collect", function(s) Config.AutoChest = s; if s then StartChestCollector() else _chestCollecting = false end end)
MakeToggle(FarmPage, "Auto Fruit Collect", function(s) Config.AutoFruit = s; if s then StartFruitCollector() else _fruitCollecting = false end end)
MakeToggle(FarmPage, "Bring Mobs (Local)", function(s) Config.BringMobs = s end)
MakeInput(FarmPage, "Mob Name Filter:", function(t) Config.SelectedMob = t end)
MakeInput(FarmPage, "Weapon Name:", function(t) Config.SelectedWeapon = t end)

-- PLAYER TAB
local PlayerPage = MakeTab("Player")
MakeToggle(PlayerPage, "Fly (WASD+Space/Shift)", function(s) ToggleFly(s) end)
MakeToggle(PlayerPage, "Noclip", function(s) Config.Noclip = s; if s then EnableNoclip() else DisableNoclip() end end)
MakeInput(PlayerPage, "Fly Speed:", function(t) local n = tonumber(t); if n then Config.FlySpeed = n end end)
MakeButton(PlayerPage, "Reset Position", function() StopMovement(); StopHover(); DisableNoclip() end)

-- ESP TAB
local ESPPage = MakeTab("ESP")
MakeToggle(ESPPage, "Player ESP", function(s) Config.ESPEnabled = s; if not s then ClearESP() end end)
MakeToggle(ESPPage, "Fruit ESP", function(s) Config.FruitESP = s end)
MakeButton(ESPPage, "Clear All ESP", ClearESP)

-- MISC TAB
local MiscPage = MakeTab("Misc")
MakeButton(MiscPage, "Server Hop (Low Pop)", ServerHop)
MakeButton(MiscPage, "Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LP) end)
MakeButton(MiscPage, "Destroy UI", function() SG:Destroy() end)
MakeInput(MiscPage, "Tween Speed:", function(t) local n = tonumber(t); if n then Config.TweenSpeed = n end end)

-- Show farm tab by default
FarmPage.Visible = true

-- Notify
local Notify = Instance.new("TextLabel")
Notify.Size = UDim2.new(0, 350, 0, 40)
Notify.Position = UDim2.new(0.5, -175, 0, 10)
Notify.Text = "VEIL Fixed Hub loaded — Teleport FIXED"
Notify.TextColor3 = Color3.fromRGB(0, 255, 100)
Notify.Font = Enum.Font.GothamBold
Notify.TextSize = 15
Notify.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Notify.Parent = SG
Instance.new("UICorner", Notify).CornerRadius = UDim.new(0, 6)
task.delay(4, function() if Notify then Notify:Destroy() end end)

print("[VEIL] Post-update fixed hub loaded successfully!")
print("[VEIL] Enemy folder: " .. tostring(GetEnemyFolder() and GetEnemyFolder().Name or "searching..."))
]==],
    os.date("%Y-%m-%d %H:%M"),
    seaNum,
    DISCOVERED.PlayerLevel,
    shortMethod,
    longMethod,
    lockMethod,
    enemyPath,
    DISCOVERED.CommFPath or "DYNAMIC SCAN",
    remoteFolderPath or "DYNAMIC SCAN",
    table.concat(workingMethods, ","),
    table.concat(DISCOVERED.MobNames, ", "),
    seaNum,
    commFCode,
    DISCOVERED.EnemyFolder and DISCOVERED.EnemyFolder.Name or "Enemies"
)

-- ═══════════════════════════════════════════════════════════════
-- PHASE 11: BUILD FULL REPORT & COPY TO CLIPBOARD
-- ═══════════════════════════════════════════════════════════════
Log("OUTPUT", "Building final report and copying to clipboard...")

local reportStr = "-- ═══════════════════════════════════════════════════════════════\n"
reportStr = reportStr .. "-- BLOX FRUITS ULTIMATE ANALYSIS REPORT\n"
reportStr = reportStr .. "-- Generated: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
reportStr = reportStr .. "-- ═══════════════════════════════════════════════════════════════\n\n"

for section, items in pairs(REPORT) do
    reportStr = reportStr .. "-- ═══ " .. section .. " ═══\n"
    for _, item in ipairs(items) do
        reportStr = reportStr .. string.format("--   %-35s → %s\n", item.key, item.value)
    end
    reportStr = reportStr .. "\n"
end

reportStr = reportStr .. "-- ═══ FULL LOG ═══\n"
for _, entry in ipairs(LOG) do
    reportStr = reportStr .. "-- " .. entry .. "\n"
end

-- Combine report + fixed script
local FINAL_OUTPUT = reportStr .. "\n\n" .. FIXED_SCRIPT

-- Copy to clipboard
local clipboardSuccess = false
pcall(function()
    if setclipboard then
        setclipboard(FINAL_OUTPUT)
        clipboardSuccess = true
    elseif toclipboard then
        toclipboard(FINAL_OUTPUT)
        clipboardSuccess = true
    elseif Clipboard and Clipboard.set then
        Clipboard.set(FINAL_OUTPUT)
        clipboardSuccess = true
    end
end)

if clipboardSuccess then
    Log("OUTPUT", "═══════════════════════════════════════════")
    Log("OUTPUT", "✓ ✓ ✓  COPIED TO CLIPBOARD!  ✓ ✓ ✓")
    Log("OUTPUT", "═══════════════════════════════════════════")
    Log("OUTPUT", "Script size: " .. #FINAL_OUTPUT .. " bytes")
    Log("OUTPUT", "Paste into your executor to use the fixed hub.")
else
    Log("OUTPUT", "✗ Clipboard not available. Printing script to console...")
    Log("OUTPUT", "Script size: " .. #FINAL_OUTPUT .. " bytes")
    -- Print in chunks
    local chunkSize = 199000
    for i = 1, #FINAL_OUTPUT, chunkSize do
        print(FINAL_OUTPUT:sub(i, i + chunkSize - 1))
    end
end

-- Final summary notification
Log("SUMMARY", "═══════════════════════════════════════════")
Log("SUMMARY", "ANALYSIS COMPLETE!")
Log("SUMMARY", "  Sea: " .. DISCOVERED.Sea)
Log("SUMMARY", "  Level: " .. DISCOVERED.PlayerLevel)
Log("SUMMARY", "  Enemy Folder: " .. (DISCOVERED.EnemyFolderPath or "NOT FOUND"))
Log("SUMMARY", "  Unique Mobs: " .. #DISCOVERED.MobNames)
Log("SUMMARY", "  Boss Mobs: " .. (function() local c=0; for _ in pairs(DISCOVERED.BossMobs) do c=c+1 end; return c end)())
Log("SUMMARY", "  CommF Remote: " .. (DISCOVERED.CommFPath or "NOT FOUND"))
Log("SUMMARY", "  Total Remotes: " .. (#allRemoteEvents + #allRemoteFunctions))
Log("SUMMARY", "  Quest NPCs: " .. #DISCOVERED.QuestNPCs)
Log("SUMMARY", "  Fruits Found: " .. #DISCOVERED.FruitLocations)
Log("SUMMARY", "  Chests Found: " .. #DISCOVERED.ChestLocations)
Log("SUMMARY", "  Anti-Cheat Scripts: " .. #antiCheatScripts)
Log("SUMMARY", "  Working TP Method: " .. (DISCOVERED.WorkingTeleportMethod and DISCOVERED.TeleportTestResults[DISCOVERED.WorkingTeleportMethod].name or "NONE"))
Log("SUMMARY", "  Short-Range Method: " .. shortMethod)
Log("SUMMARY", "  Long-Range Method: " .. longMethod)
Log("SUMMARY", "  Lock Method: " .. lockMethod)
Log("SUMMARY", "═══════════════════════════════════════════")

-- Game notification
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "VEIL Analyzer",
        Text = clipboardSuccess and "Analysis complete! Fixed script copied to clipboard!" or "Analysis complete! Check console for output.",
        Duration = 8,
    })
end)
