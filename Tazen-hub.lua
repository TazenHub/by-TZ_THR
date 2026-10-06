-- luacheck: globals game

if game.PlaceId ~= 3623096087 then return end

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok or not Rayfield then
    warn("[Tazen hub] Impossible de charger Rayfield")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "Tazen hub V1 by TZN_THR",
    Icon = 0,
    LoadingTitle = "Welcome to Tazen hub",
    LoadingSubtitle = "by TZN_THR",
    ShowText = "Rayfield",
    Theme = "Amethyst",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TazenHub",
        FileName = "Big Hub",
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ONGLETS
local MainTab = Window:CreateTab("Fast Rebirth", 4483362458)
MainTab:CreateSection("Fast Rebirth (Pack)")

local RebTab = Window:CreateTab("Auto Rebirth", 4483362458)
RebTab:CreateSection("Auto Rebirth (No Pack)")

-- SERVICES / CONSTANTES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local PET_FOLDERS = { "Unique", "Rare", "Epic", "Mythic", "Legendary" }
local CYCLE_TIME = 6.2      -- durée totale d'un cycle fast rebirth
local REP_DURATION = 5.5    -- temps passé à rep par cycle
local REP_INTERVAL = 0.5    -- délai entre deux salves de rep
local REPS_PER_BURST = 10

local repSpeedPetPriorities = {
    ["Omega Overlord"] = 1,
    ["Mythic Boss Pet"] = 2,
    ["Legendary Boss Pet"] = 3,
    ["Epic Boss Pet"] = 4,
}

-- État (un "run id" par fonctionnalité pour éviter les boucles en double)
local fastRunId = 0
local autoRunId = 0
local FastToggle, AutoToggle

-- FONCTIONS UTILITAIRES
local function canRebirth()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then return true end

    local strength = leaderstats:FindFirstChild("Strength")
        or leaderstats:FindFirstChild("Muscle")
        or leaderstats:FindFirstChild("Multiplier")
    if strength and strength.Value then
        return strength.Value > 0
    end
    return true
end

local function getPetName(pet)
    local nameObj = pet:FindFirstChild("PetName")
    if nameObj and nameObj:IsA("ValueBase") then
        return nameObj.Value
    end
    return pet.Name
end

local function getPetScore(pet)
    local repSpeedObj = pet:FindFirstChild("RepSpeed") or pet:FindFirstChild("Rep Speed")
    if repSpeedObj and (repSpeedObj:IsA("NumberValue") or repSpeedObj:IsA("IntValue")) then
        return repSpeedObj.Value
    end

    local attr = pet:GetAttribute("RepSpeed") or pet:GetAttribute("Rep Speed")
    if attr then return tonumber(attr) or 0 end

    local levelObj = pet:FindFirstChild("Level") or pet:FindFirstChild("Lvl")
    if levelObj and levelObj.Value then
        return tonumber(levelObj.Value) or 0
    end

    return 1
end

local function getRemotes()
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    if not rEvents then return nil end
    return {
        rEvents = rEvents,
        rebirth = rEvents:WaitForChild("rebirthRemote", 5),
        equip = rEvents:WaitForChild("equipPetEvent", 5),
    }
end

local function findMuscleEvent(rEvents)
    return LocalPlayer:FindFirstChild("muscleEvent")
        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("muscleEvent"))
        or rEvents:FindFirstChild("muscleEvent")
end

-- Liste stable (triée par nom) des pets d'un dossier
local function getSortedChildren(folder)
    local list = folder:GetChildren()
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end

-- 1. FAST REBIRTH (PACK)
local function fastRebirthLoop(myId)
    local r = getRemotes()
    if not r or not r.rebirth or not r.equip then
        warn("[Tazen hub] Remotes introuvables")
        return
    end

    local function isRunning() return fastRunId == myId end

    while isRunning() do
        local cycleStart = tick()
        local petsFolder = LocalPlayer:FindFirstChild("petsFolder")

        if petsFolder and canRebirth() then
            -- 1. Équiper le Titanium Hydra
            for _, folderName in ipairs(PET_FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        if getPetName(pet) == "Titanium Hydra" then
                            pcall(function() r.equip:FireServer("equipPet", pet) end)
                            task.wait(0.05)
                        end
                    end
                end
                if not isRunning() then return end
            end

            -- 2. Rebirth
            pcall(function() r.rebirth:InvokeServer("rebirthRequest") end)
            task.wait(0.1)
            if not isRunning() then return end

            -- 3. Équiper les pets de rep (priorité au Unique n°4)
            local repPets = {}
            local uniqueFolder = petsFolder:FindFirstChild("Unique")
            local priority4Pet = uniqueFolder and getSortedChildren(uniqueFolder)[4]

            for _, folderName in ipairs(PET_FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        local priority = repSpeedPetPriorities[getPetName(pet)] or 5
                        if priority4Pet and pet == priority4Pet then priority = 0 end

                        if priority < 5 then
                            table.insert(repPets, {
                                Instance = pet,
                                Priority = priority,
                                Score = getPetScore(pet),
                            })
                        end
                    end
                end
            end

            table.sort(repPets, function(a, b)
                if a.Priority == b.Priority then return a.Score > b.Score end
                return a.Priority < b.Priority
            end)

            for _, entry in ipairs(repPets) do
                pcall(function() r.equip:FireServer("equipPet", entry.Instance) end)
                task.wait(0.05)
                if not isRunning() then return end
            end

            -- 4. Rep régulé pendant ~5.5 s
            local muscleEvent = findMuscleEvent(r.rEvents)
            if muscleEvent then
                local repStart = tick()
                while tick() - repStart < REP_DURATION and isRunning() do
                    for _ = 1, REPS_PER_BURST do
                        pcall(function() muscleEvent:FireServer("rep") end)
                    end
                    task.wait(REP_INTERVAL)
                end
            end
        end

        -- Compléter le cycle à CYCLE_TIME secondes
        local remaining = CYCLE_TIME - (tick() - cycleStart)
        task.wait(math.max(remaining, 0.5))
    end
end

FastToggle = MainTab:CreateToggle({
    Name = "Fast rebirth",
    CurrentValue = false,
    Flag = "FastRebirthFlag",
    Callback = function(Value)
        fastRunId = fastRunId + 1 -- invalide toute ancienne boucle

        if Value then
            -- exclusion mutuelle avec Auto Rebirth
            autoRunId = autoRunId + 1
            if AutoToggle then AutoToggle:Set(false) end

            local myId = fastRunId
            task.spawn(fastRebirthLoop, myId)
        end
    end,
})

-- 2. AUTO REBIRTH (NO PACK)
local function autoRebirthLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)
    if not rebirthRemote then
        warn("[Tazen hub] rebirthRemote introuvable")
        return
    end

    while autoRunId == myId do
        if canRebirth() then
            pcall(function() rebirthRemote:InvokeServer("rebirthRequest") end)
        end
        task.wait(6)
    end
end

AutoToggle = RebTab:CreateToggle({
    Name = "Auto rebirth",
    CurrentValue = false,
    Flag = "AutoRebirthFlag",
    Callback = function(Value)
        autoRunId = autoRunId + 1

        if Value then
            -- exclusion mutuelle avec Fast Rebirth
            fastRunId = fastRunId + 1
            if FastToggle then FastToggle:Set(false) end

            local myId = autoRunId
            task.spawn(autoRebirthLoop, myId)
        end
    end,
})
