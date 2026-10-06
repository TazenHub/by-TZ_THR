-- Tazen hub V1 by TZN_THR (autonome : UI style Rayfield, sans HttpGet)

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
            local priority4Pet = uniqueFolder and uniqueFolder:GetChildren()[4]

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

-- ===================== SERVICES UI =====================
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local alive = true
local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

-- ===================== FAST REP =====================
local repRunId = 0
local repRate = 660      -- rep par seconde (minimum 659)
local repCounter = 0

local function fastRepLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    if not rEvents then warn("[Tazen hub] rEvents introuvable") return end
    local muscleEvent = findMuscleEvent(rEvents)
    if not muscleEvent then warn("[Tazen hub] muscleEvent introuvable") return end

    local carry = 0
    local lastCheck = tick()
    while repRunId == myId and alive do
        local dt = RunService.Heartbeat:Wait()

        -- le remote peut changer de parent (respawn) : on le retrouve
        if tick() - lastCheck > 1 then
            lastCheck = tick()
            if not muscleEvent.Parent then
                muscleEvent = findMuscleEvent(rEvents) or muscleEvent
            end
        end

        -- accumulateur basé sur le temps : garde le débit moyen même si les FPS varient
        carry = carry + repRate * dt
        local n = math.floor(carry)
        carry = carry - n
        if n > 200 then n = 200 end

        for _ = 1, n do
            pcall(muscleEvent.FireServer, muscleEvent, "rep")
        end
        repCounter = repCounter + n
    end
end

-- ===================== THÈME / IMAGE =====================
-- Colle ici l'ID de ton image Roblox (juste le nombre), ex : 123456789
local IMAGE_ID = 0
-- Ou mets le fichier dans le dossier "workspace" de ton executor
local IMAGE_FILE = "tazen_logo.png"

local T = {
    Background = Color3.fromRGB(16, 8, 30),
    Topbar = Color3.fromRGB(30, 16, 56),
    Element = Color3.fromRGB(40, 24, 72),
    Stroke = Color3.fromRGB(95, 60, 160),
    Accent = Color3.fromRGB(240, 110, 160),
    Text = Color3.new(1, 1, 1),
    SubText = Color3.fromRGB(205, 190, 235),
    Off = Color3.fromRGB(75, 58, 108),
}

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

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, color, th) return new("UIStroke", { Color = color, Thickness = th }, o) end

local function textLabel(props, parent)
    local p = {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextColor3 = T.Text,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.5,
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for k, v in pairs(props) do p[k] = v end
    return new("TextLabel", p, parent)
end

-- ===================== FENÊTRE =====================
local parentGui = getGuiParent()
local old = parentGui:FindFirstChild("TazenHubGui")
if old then old:Destroy() end

local gui = new("ScreenGui", {
    Name = "TazenHubGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parentGui)

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(900, 600)
local W = math.min(520, vp.X - 30)
local H = math.min(340, vp.Y - 30)

local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = T.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(main, 12)
stroke(main, T.Stroke, 1.5)

-- Image de fond (ou "TZ" de secours si aucune image)
local imageId = resolveImage()
local bg = new("ImageLabel", {
    Name = "Background",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Image = imageId,
    ImageTransparency = 0.45,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 2,
}, main)

if imageId == "" then
    bg.Visible = false
    textLabel({
        Size = UDim2.new(1, 0, 1, 0),
        Text = "TZ",
        Font = Enum.Font.GothamBlack,
        TextSize = 170,
        TextColor3 = T.Accent,
        TextTransparency = 0.88,
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 2,
    }, main)
    warn("[Tazen hub] Aucune image : renseigne IMAGE_ID ou ajoute " .. IMAGE_FILE .. " dans le workspace")
end

-- Voile sombre pour garder le texte lisible
new("Frame", {
    Name = "Shade",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 3,
}, main)

-- Barre du haut
local topbar = new("Frame", {
    Name = "Topbar",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = T.Topbar,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    ZIndex = 6,
}, main)

textLabel({
    Size = UDim2.new(1, -110, 0, 22),
    Position = UDim2.new(0, 14, 0, 4),
    Text = "Tazen hub V1",
    Font = Enum.Font.GothamBlack,
    TextSize = 17,
}, topbar)

textLabel({
    Size = UDim2.new(1, -110, 0, 14),
    Position = UDim2.new(0, 14, 0, 25),
    Text = "by TZN_THR  •  K pour masquer",
    TextSize = 11,
    TextColor3 = T.Accent,
}, topbar)

local function topButton(text, xOffset)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, xOffset, 0, 7),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = T.Text,
        BorderSizePixel = 0,
    }, topbar)
    corner(b, 8)
    return b
end

local closeBtn = topButton("X", -38)
local minBtn = topButton("–", -72)

-- Déplacement de la fenêtre (souris + tactile)
do
    local dragging, dragStart, startPos = false, nil, nil
    connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Barre d'onglets + conteneur de pages
local tabBar = new("Frame", {
    Name = "TabBar",
    Size = UDim2.new(1, 0, 0, 34),
    Position = UDim2.new(0, 0, 0, 46),
    BackgroundTransparency = 1,
    ZIndex = 6,
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, tabBar)

local pagesHolder = new("Frame", {
    Name = "Pages",
    Size = UDim2.new(1, 0, 1, -86),
    Position = UDim2.new(0, 0, 0, 84),
    BackgroundTransparency = 1,
    ZIndex = 5,
}, main)

local tabs = {}

local function selectTab(name)
    for tabName, t in pairs(tabs) do
        local on = (tabName == name)
        t.page.Visible = on
        t.button.BackgroundColor3 = on and T.Accent or T.Element
        t.button.BackgroundTransparency = on and 0.1 or 0.25
    end
end

local function createTab(name)
    local button = new("TextButton", {
        Size = UDim2.fromOffset(124, 28),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.25,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.Text,
        TextStrokeTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = #tabBar:GetChildren(),
    }, tabBar)
    corner(button, 8)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, pagesHolder)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 8),
    }, page)

    tabs[name] = { button = button, page = page }
    button.Activated:Connect(function() selectTab(name) end)
    return page
end

-- ===================== ÉLÉMENTS (style Rayfield) =====================
local function addSection(page, text)
    textLabel({
        Size = UDim2.new(1, 0, 0, 20),
        Text = string.upper(text),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = T.Accent,
    }, page)
end

local function addLabel(page, text, height)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 40),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, T.Stroke, 1)
    local l = textLabel({
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Text = text,
        TextSize = 12,
        TextColor3 = T.SubText,
        TextWrapped = true,
    }, f)
    return { SetText = function(_, t) l.Text = t end }
end

local function addToggle(page, name, callback)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, T.Stroke, 1)

    textLabel({
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        Text = name,
    }, f)

    local sw = new("Frame", {
        Size = UDim2.fromOffset(40, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = T.Off,
        BorderSizePixel = 0,
    }, f)
    corner(sw, 10)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, sw)
    corner(knob, 8)

    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, f)

    local obj = { Value = false }
    function obj:Set(v)
        if v == self.Value then return end
        self.Value = v
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, { Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) }):Play()
        TweenService:Create(sw, info, { BackgroundColor3 = v and T.Accent or T.Off }):Play()
        if callback then callback(v) end
    end
    hit.Activated:Connect(function() obj:Set(not obj.Value) end)
    return obj
end

local function addSlider(page, name, min, max, default, callback)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, T.Stroke, 1)

    textLabel({ Size = UDim2.new(1, -100, 0, 24), Position = UDim2.new(0, 12, 0, 6), Text = name }, f)
    local valueLabel = textLabel({
        Size = UDim2.fromOffset(80, 24),
        Position = UDim2.new(1, -92, 0, 6),
        Text = tostring(default),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = T.Accent,
        Font = Enum.Font.GothamBold,
    }, f)

    local track = new("Frame", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 42),
        BackgroundColor3 = T.Off,
        BorderSizePixel = 0,
    }, f)
    corner(track, 4)
    local fill = new("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 4)

    local hit = new("TextButton", {
        Size = UDim2.new(1, -12, 0, 30),
        Position = UDim2.new(0, 6, 0, 31),
        BackgroundTransparency = 1,
        Text = "",
    }, f)

    local dragging = false
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        valueLabel.Text = tostring(value)
        callback(value)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            page.ScrollingEnabled = false
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            page.ScrollingEnabled = true
        end
    end)
end

-- Notifications
local function notify(title, text)
    if not alive then return end
    local n = new("Frame", {
        Size = UDim2.fromOffset(250, 56),
        Position = UDim2.new(1, 20, 1, -76),
        BackgroundColor3 = T.Topbar,
        BorderSizePixel = 0,
    }, gui)
    corner(n, 10)
    stroke(n, T.Accent, 1.5)
    textLabel({
        Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 10, 0, 5),
        Text = title, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.Accent,
    }, n)
    textLabel({
        Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 10, 0, 27),
        Text = text, TextSize = 12, TextColor3 = T.SubText,
    }, n)
    local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
    TweenService:Create(n, info, { Position = UDim2.new(1, -270, 1, -76) }):Play()
    task.delay(2.5, function()
        if n and n.Parent then
            TweenService:Create(n, info, { Position = UDim2.new(1, 20, 1, -76) }):Play()
            task.wait(0.3)
            n:Destroy()
        end
    end)
end

-- ===================== ONGLETS =====================
local fastPage = createTab("Fast Rebirth")
local autoPage = createTab("Auto Rebirth")
local repPage = createTab("Fast Rep")

local fastToggle, autoToggle, repToggle

-- Fast Rebirth
addSection(fastPage, "Fast Rebirth (Pack)")
addLabel(fastPage, "Équipe Titanium Hydra, rebirth, puis rééquipe tes pets de rep (cycle ~6,2 s).", 44)
fastToggle = addToggle(fastPage, "Fast rebirth", function(v)
    fastRunId = fastRunId + 1
    if v then
        autoRunId = autoRunId + 1
        if autoToggle then autoToggle:Set(false) end
        notify("Fast rebirth", "Activé")
        task.spawn(fastRebirthLoop, fastRunId)
    else
        notify("Fast rebirth", "Désactivé")
    end
end)

-- Auto Rebirth
addSection(autoPage, "Auto Rebirth (No Pack)")
autoToggle = addToggle(autoPage, "Auto rebirth", function(v)
    autoRunId = autoRunId + 1
    if v then
        fastRunId = fastRunId + 1
        if fastToggle then fastToggle:Set(false) end
        notify("Auto rebirth", "Activé")
        task.spawn(autoRebirthLoop, autoRunId)
    else
        notify("Auto rebirth", "Désactivé")
    end
end)

-- Fast Rep
addSection(repPage, "Fast Rep")
repToggle = addToggle(repPage, "Fast rep", function(v)
    repRunId = repRunId + 1
    if v then
        notify("Fast rep", repRate .. " rep/s visés")
        task.spawn(fastRepLoop, repRunId)
    else
        notify("Fast rep", "Désactivé")
    end
end)
addSlider(repPage, "Rep par seconde", 659, 3000, repRate, function(v) repRate = v end)
local repLabel = addLabel(repPage, "Rep/s réel : --", 34)

task.spawn(function()
    while alive do
        task.wait(1)
        if repToggle.Value then
            repLabel:SetText("Rep/s réel : " .. repCounter)
        else
            repLabel:SetText("Rep/s réel : --")
        end
        repCounter = 0
    end
end)

selectTab("Fast Rebirth")

-- ===================== BOUTONS FENÊTRE =====================
local minimized = false
minBtn.Activated:Connect(function()
    minimized = not minimized
    tabBar.Visible = not minimized
    pagesHolder.Visible = not minimized
    TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.fromOffset(W, minimized and 42 or H),
    }):Play()
end)

closeBtn.Activated:Connect(function()
    alive = false
    fastRunId = fastRunId + 1
    autoRunId = autoRunId + 1
    repRunId = repRunId + 1
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)

-- Touche K : masquer / afficher
connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        gui.Enabled = not gui.Enabled
    end
end)

print("[Tazen hub] Interface chargée")

end)

if not ok then
    warn("[Tazen hub] Erreur : " .. tostring(err))
end
