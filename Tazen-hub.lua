-- Tazen hub (version autonome avec image d'arrière-plan : sans Rayfield, sans HttpGet)

local ok, err = pcall(function()

if game.PlaceId ~= 3623096087 then
    warn("[Tazen hub] Mauvais PlaceId : " .. tostring(game.PlaceId))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local PET_FOLDERS = { "Unique", "Rare", "Epic", "Mythic", "Legendary" }
local CYCLE_TIME = 6.2
local REP_DURATION = 5.5
local REP_INTERVAL = 0.5
local REPS_PER_BURST = 10

local repSpeedPetPriorities = {
    ["Omega Overlord"] = 1,
    ["Mythic Boss Pet"] = 2,
    ["Legendary Boss Pet"] = 3,
    ["Epic Boss Pet"] = 4,
}

local fastRunId = 0
local autoRunId = 0

-- ===================== LOGIQUE =====================

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
    if nameObj and nameObj:IsA("ValueBase") then return nameObj.Value end
    return pet.Name
end

local function getPetScore(pet)
    local o = pet:FindFirstChild("RepSpeed") or pet:FindFirstChild("Rep Speed")
    if o and (o:IsA("NumberValue") or o:IsA("IntValue")) then return o.Value end
    local attr = pet:GetAttribute("RepSpeed") or pet:GetAttribute("Rep Speed")
    if attr then return tonumber(attr) or 0 end
    local lvl = pet:FindFirstChild("Level") or pet:FindFirstChild("Lvl")
    if lvl and lvl.Value then return tonumber(lvl.Value) or 0 end
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

local function getSortedChildren(folder)
    local list = folder:GetChildren()
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end

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

            pcall(function() r.rebirth:InvokeServer("rebirthRequest") end)
            task.wait(0.1)
            if not isRunning() then return end

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
                            table.insert(repPets, { Instance = pet, Priority = priority, Score = getPetScore(pet) })
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

        local remaining = CYCLE_TIME - (tick() - cycleStart)
        task.wait(math.max(remaining, 0.5))
    end
end

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

-- ===================== INTERFACE =====================

-- IMAGE D'ARRIÈRE-PLAN
-- Option 1 : colle ici l'ID de ton image uploadée sur Roblox (juste le nombre)
local IMAGE_ID = 0
-- Option 2 : si tu n'as pas d'ID, mets le fichier dans le dossier "workspace" de ton executor
local IMAGE_FILE = "tazen_logo.png"

local PINK = Color3.fromRGB(240, 110, 160)

local function resolveImage()
    if IMAGE_ID and IMAGE_ID ~= 0 then
        return "rbxassetid://" .. tostring(IMAGE_ID)
    end
    local okF, asset = pcall(function()
        if isfile and getcustomasset and isfile(IMAGE_FILE) then
            return getcustomasset(IMAGE_FILE)
        end
    end)
    if okF and asset then return asset end
    return ""
end

local function getGuiParent()
    local okHui, hui = pcall(function() return gethui and gethui() end)
    if okHui and hui then return hui end
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then
        local test = Instance.new("ScreenGui")
        local okP = pcall(function() test.Parent = core end)
        test:Destroy()
        if okP then return core end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local old = getGuiParent():FindFirstChild("TazenHubGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "TazenHubGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = getGuiParent()

-- Fenêtre
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 270, 0, 330)
frame.Position = UDim2.new(0, 20, 0.5, -165)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ZIndex = 1
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = PINK
frameStroke.Thickness = 2
frameStroke.Parent = frame

-- Image de fond
local bg = Instance.new("ImageLabel")
bg.Name = "Background"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundTransparency = 1
bg.Image = resolveImage()
bg.ScaleType = Enum.ScaleType.Crop
bg.ZIndex = 2
bg.Parent = frame
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)

-- Voile sombre en dégradé : foncé en haut et en bas (texte lisible),
-- léger au centre (le logo reste visible)
local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.new(1, 0, 1, 0)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BorderSizePixel = 0
shade.ZIndex = 3
shade.Parent = frame
Instance.new("UICorner", shade).CornerRadius = UDim.new(0, 14)

local shadeGradient = Instance.new("UIGradient")
shadeGradient.Rotation = 90
shadeGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.15),
    NumberSequenceKeypoint.new(0.22, 0.45),
    NumberSequenceKeypoint.new(0.5, 0.8),
    NumberSequenceKeypoint.new(0.68, 0.45),
    NumberSequenceKeypoint.new(1, 0.1),
})
shadeGradient.Parent = shade

-- Textes (blanc + contour noir pour rester lisibles sur n'importe quel fond)
local function styleText(obj)
    obj.TextColor3 = Color3.new(1, 1, 1)
    obj.TextStrokeColor3 = Color3.new(0, 0, 0)
    obj.TextStrokeTransparency = 0.2
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 26)
title.Position = UDim2.new(0, 14, 0, 8)
title.BackgroundTransparency = 1
title.Text = "TAZEN HUB"
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 5
styleText(title)
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -50, 0, 16)
subtitle.Position = UDim2.new(0, 14, 0, 33)
subtitle.BackgroundTransparency = 1
subtitle.Text = "V1  •  by TZN_THR"
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 5
styleText(subtitle)
subtitle.TextColor3 = PINK
subtitle.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
closeBtn.BackgroundTransparency = 0.35
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.ZIndex = 5
styleText(closeBtn)
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Boutons
local function makeButton(y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -28, 0, 42)
    b.Position = UDim2.new(0, 14, 0, y)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.AutoButtonColor = true
    b.ZIndex = 5
    styleText(b)
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke")
    s.Color = PINK
    s.Thickness = 1.5
    s.Parent = b
    return b
end

local fastBtn = makeButton(226)
local autoBtn = makeButton(276)

local function paint(btn, label, state)
    btn.Text = label .. (state and "  •  ON" or "  •  OFF")
    if state then
        btn.BackgroundColor3 = PINK
        btn.BackgroundTransparency = 0.15
    else
        btn.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
        btn.BackgroundTransparency = 0.25
    end
end

paint(fastBtn, "Fast rebirth", false)
paint(autoBtn, "Auto rebirth", false)

local fastOn, autoOn = false, false

local function setFast(state)
    fastOn = state
    fastRunId = fastRunId + 1
    paint(fastBtn, "Fast rebirth", state)
    if state then
        autoOn = false
        autoRunId = autoRunId + 1
        paint(autoBtn, "Auto rebirth", false)
        task.spawn(fastRebirthLoop, fastRunId)
    end
end

local function setAuto(state)
    autoOn = state
    autoRunId = autoRunId + 1
    paint(autoBtn, "Auto rebirth", state)
    if state then
        fastOn = false
        fastRunId = fastRunId + 1
        paint(fastBtn, "Fast rebirth", false)
        task.spawn(autoRebirthLoop, autoRunId)
    end
end

fastBtn.Activated:Connect(function() setFast(not fastOn) end)
autoBtn.Activated:Connect(function() setAuto(not autoOn) end)
closeBtn.Activated:Connect(function()
    fastRunId = fastRunId + 1
    autoRunId = autoRunId + 1
    gui:Destroy()
end)

if bg.Image == "" then
    warn("[Tazen hub] Aucune image trouvée : renseigne IMAGE_ID ou ajoute " .. IMAGE_FILE .. " dans le workspace")
end
print("[Tazen hub] Interface chargée")

end)

if not ok then
    warn("[Tazen hub] Erreur : " .. tostring(err))
end
