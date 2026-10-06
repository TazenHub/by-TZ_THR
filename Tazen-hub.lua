-- Tazen hub V1 by TZ_THR (standalone: Rayfield-style UI, no HttpGet needed)

local ok, err = pcall(function()

if game.PlaceId ~= 3623096087 then
    warn("[Tazen hub] Wrong PlaceId: " .. tostring(game.PlaceId))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ===================== SETTINGS =====================
local REBIRTH_COOLDOWN = 6       -- game cooldown between two rebirths (seconds)

-- Emojis
local E = {
    bolt = "\u{26A1}", cycle = "\u{1F504}", muscle = "\u{1F4AA}", toolbox = "\u{1F9F0}",
    sleep = "\u{1F634}", rocket = "\u{1F680}", sparkles = "\u{2728}", heart = "\u{1F496}",
    ok = "\u{2705}", no = "\u{274C}", chart = "\u{1F4CA}", up = "\u{1F4C8}", broom = "\u{1F9F9}",
    clock = "\u{1F550}", hourglass = "\u{23F3}", sun = "\u{1F31E}", calendar = "\u{1F4C5}",
    trophy = "\u{1F3C6}", target = "\u{1F3AF}", wrench = "\u{1F527}", clip = "\u{1F4CB}",
    bulb = "\u{1F4A1}", fire = "\u{1F525}", loop = "\u{1F501}", antenna = "\u{1F4E1}",
    party = "\u{1F389}", game = "\u{1F3AE}", crown = "\u{1F451}",
}

local IMAGE_ID = 79546688195352

local repSpeedPetPriorities = {
    ["Omega Overlord"] = 1,
    ["Mythic Boss Pet"] = 2,
    ["Legendary Boss Pet"] = 3,
    ["Epic Boss Pet"] = 4,
}

-- ===================== STATE =====================
local alive = true
local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local fastRunId = 0
local autoRunId = 0
local repRunId = 0
local repRate = 660          
local repCounter = 0         
local repTotal = 0           
local fastStatus = "Waiting..."
local autoStatus = "Waiting..."

-- ===================== GAME HELPERS =====================
local function canRebirth()
    local okC, result = pcall(function()
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if not leaderstats then return true end
        local strength = leaderstats:FindFirstChild("Strength")
            or leaderstats:FindFirstChild("Muscle")
            or leaderstats:FindFirstChild("Multiplier")
        if strength and strength.Value then
            local v = tonumber(strength.Value)
            if v then return v > 0 end
        end
        return true
    end)
    if okC then return result end
    return true
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

local function findMuscleEvent(rEvents)
    return LocalPlayer:FindFirstChild("muscleEvent")
        or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("muscleEvent"))
        or rEvents:FindFirstChild("muscleEvent")
end

-- ===================== FAST REBIRTH (CODE REUSSI) =====================
local function fastRebirthLoop(myId)
    local function isRunning() return fastRunId == myId end

    local okT, errT = pcall(function()
        local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
        local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)
        local equipPetEvent = rEvents and rEvents:WaitForChild("equipPetEvent", 5)
        local FOLDERS = {"Unique", "Rare", "Epic", "Mythic", "Legendary"}
        local SLOTS = 12

        if not rebirthRemote or not equipPetEvent then
            fastStatus = "Remotes non trouvees !"
            return
        end

        local function petRealName(pet)
            if pet:FindFirstChild("PetName") then return pet.PetName.Value end
            return pet.Name
        end

        local function buildHydraList(petsFolder)
            local allHydras = {}
            for _, folderName in ipairs(FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        if petRealName(pet) == "Titanium Hydra" then
                            table.insert(allHydras, pet)
                        end
                    end
                end
            end
            local list = {}
            for i = 1, math.min(#allHydras, SLOTS) do
                list[i] = allHydras[i]
            end
            return list
        end

        local function buildRepList(petsFolder)
            local repPets = {}
            for _, folderName in ipairs(FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        local priority = repSpeedPetPriorities[petRealName(pet)] or 5
                        if priority < 5 then
                            table.insert(repPets, {
                                Instance = pet,
                                Priority = priority,
                                Score = getPetScore(pet)
                            })
                        end
                    end
                end
            end

            table.sort(repPets, function(a, b)
                if a.Priority == b.Priority then return a.Score > b.Score end
                return a.Priority < b.Priority
            end)

            local list = {}
            for _, entry in ipairs(repPets) do
                if #list >= SLOTS then break end
                table.insert(list, entry.Instance)
            end
            return list
        end

        local function equipSet(petList)
            for _, pet in ipairs(petList) do
                if pet and pet.Parent then
                    equipPetEvent:FireServer("equipPet", pet)
                end
            end
        end

        local function unequipSet(petList)
            for _, pet in ipairs(petList) do
                if pet and pet.Parent then
                    equipPetEvent:FireServer("unequipPet", pet)
                end
            end
        end

        local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        while isRunning() and not petsFolder do
            fastStatus = "petsFolder non trouve..."
            task.wait(1)
            petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        end
        if not isRunning() then return end

        local hydraList = buildHydraList(petsFolder)
        local repList = buildRepList(petsFolder)

        if #hydraList == 0 then
            fastStatus = "Pas de Titanium Hydra trouve !"
            warn("[Tazen hub] " .. fastStatus)
            return
        end

        local cycle = 0

        while isRunning() do
            cycle = cycle + 1
            local cycleStart = os.clock()

            -- 1. Équiper Titanium Hydras (x2 Rebirth)
            unequipSet(repList)
            equipSet(hydraList)

            task.wait(0.04)

            -- 2. Rebirth en ASYNCHRONE pour éviter le blocage à 28s
            task.spawn(function()
                pcall(function()
                    rebirthRemote:InvokeServer("rebirthRequest")
                end)
            end)

            -- 3. Remettre immédiatement les pets de Fast Rep
            unequipSet(hydraList)
            equipSet(repList)

            fastStatus = string.format("Cycle %d lance (6s)", cycle)

            -- 4. Attente exacte du cooldown de 6 secondes
            local elapsed = os.clock() - cycleStart
            local timeToWait = math.max(0, REBIRTH_COOLDOWN - elapsed)
            task.wait(timeToWait)
        end
    end)

    if not okT then
        fastStatus = "ERROR: " .. tostring(errT)
        warn("[Tazen hub] " .. fastStatus)
    end
end

-- ===================== AUTO REBIRTH =====================
local function autoRebirthLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)

    if not rebirthRemote then return end

    local tries = 0
    while autoRunId == myId do
        if canRebirth() then
            tries = tries + 1
            task.spawn(function()
                pcall(function()
                    rebirthRemote:InvokeServer("rebirthRequest")
                end)
            end)
        end
        task.wait(REBIRTH_COOLDOWN)
    end
end

-- ===================== FAST STRENGTH (REP) =====================
local function fastRepLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    if not rEvents then return end
    local muscleEvent = findMuscleEvent(rEvents)
    if not muscleEvent then return end

    local carry = 0
    local lastCheck = tick()
    while repRunId == myId and alive do
        local dt = RunService.Heartbeat:Wait()

        if tick() - lastCheck > 1 then
            lastCheck = tick()
            if not muscleEvent.Parent then
                muscleEvent = findMuscleEvent(rEvents) or muscleEvent
            end
        end

        carry = carry + repRate * dt
        local n = math.floor(carry)
        carry = carry - n
        if n > 200 then n = 200 end

        for _ = 1, n do
            pcall(muscleEvent.FireServer, muscleEvent, "rep")
        end
        repCounter = repCounter + n
        repTotal = repTotal + n
    end
end

-- ===================== THEME & UI (STRUCTURE NETTE) =====================
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

local function getGuiParent()
    local okHui, hui = pcall(function() return gethui and gethui() end)
    if okHui and hui then return hui end
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then return core end
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
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for k, v in pairs(props) do p[k] = v end
    return new("TextLabel", p, parent)
end

local parentGui = getGuiParent()
local old = parentGui:FindFirstChild("TazenHubGui")
if old then old:Destroy() end

local gui = new("ScreenGui", { Name = "TazenHubGui", ResetOnSpawn = false }, parentGui)

local W, H = 520, 360
local main = new("Frame", {
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = T.Background,
    ClipsDescendants = true,
}, gui)
corner(main, 12)
stroke(main, T.Stroke, 1.5)

-- Arrière-plan Logo TZ/TAZEN
local bg = new("ImageLabel", {
    Name = "BackgroundLogo",
    Size = UDim2.new(0.7, 0, 0.7, 0),
    Position = UDim2.new(0.5, 0, 0.55, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://" .. IMAGE_ID,
    ImageTransparency = 0.35,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 2,
}, main)

new("Frame", {
    Name = "Shade",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 3,
}, main)

local topbar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Topbar, ZIndex = 6 }, main)
textLabel({ Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 14, 0, 4), Text = E.sparkles .. " Tazen hub V1", Font = Enum.Font.GothamBlack, TextSize = 17, ZIndex = 6 }, topbar)
textLabel({ Size = UDim2.new(1, -110, 0, 14), Position = UDim2.new(0, 14, 0, 25), Text = E.heart .. " by TZ_THR | press K to hide", TextSize = 11, TextColor3 = T.Accent, ZIndex = 6 }, topbar)

local closeBtn = new("TextButton", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 7), BackgroundColor3 = T.Element, Text = "X", TextColor3 = T.Text, Font = Enum.Font.GothamBold, ZIndex = 6 }, topbar)
corner(closeBtn, 8)

do
    local dragging, dragStart, startPos = false, nil, nil
    connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local tabBar = new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 46), BackgroundTransparency = 1, ZIndex = 6 }, main)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabBar)

local pagesHolder = new("Frame", { Size = UDim2.new(1, 0, 1, -86), Position = UDim2.new(0, 0, 0, 84), BackgroundTransparency = 1, ZIndex = 5 }, main)

local tabs = {}

local function selectTab(name)
    for tabName, t in pairs(tabs) do
        local on = (tabName == name)
        t.page.Visible = on
        t.button.BackgroundColor3 = on and T.Accent or T.Element
    end
end

local function createTab(name)
    local button = new("TextButton", {
        Size = UDim2.fromOffset(120, 28),
        BackgroundColor3 = T.Element,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = T.Text,
        ZIndex = 6,
    }, tabBar)
    corner(button, 8)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 5,
    }, pagesHolder)
    new("UIListLayout", { Padding = UDim.new(0, 6) }, page)

    tabs[name] = { button = button, page = page }
    button.Activated:Connect(function() selectTab(name) end)
    return page
end

local function addToggle(page, name, callback)
    local f = new("Frame", { Size = UDim2.new(1, -20, 0, 44), BackgroundColor3 = T.Element, ZIndex = 5 }, page)
    corner(f, 8)
    textLabel({ Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0), Text = name, ZIndex = 5 }, f)

    local sw = new("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = T.Off, ZIndex = 5 }, f)
    corner(sw, 10)
    local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5 }, sw)
    corner(knob, 8)

    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 6 }, f)
    local obj = { Value = false }
    function obj:Set(v)
        self.Value = v
        knob.Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
        sw.BackgroundColor3 = v and T.Accent or T.Off
        if callback then callback(v) end
    end
    hit.Activated:Connect(function() obj:Set(not obj.Value) end)
    return obj
end

local fastPage = createTab(E.bolt .. " Fast Rebirth")
local autoPage = createTab(E.cycle .. " Auto Rebirth")
local strPage = createTab(E.muscle .. " Fast Strength")

local fastToggle, autoToggle, repToggle

fastToggle = addToggle(fastPage, E.bolt .. " Fast rebirth (6s)", function(v)
    fastRunId = fastRunId + 1
    if v then
        autoRunId = autoRunId + 1
        if autoToggle then autoToggle:Set(false) end
        task.spawn(fastRebirthLoop, fastRunId)
    end
end)

autoToggle = addToggle(autoPage, E.cycle .. " Auto rebirth", function(v)
    autoRunId = autoRunId + 1
    if v then
        fastRunId = fastRunId + 1
        if fastToggle then fastToggle:Set(false) end
        task.spawn(autoRebirthLoop, autoRunId)
    end
end)

repToggle = addToggle(strPage, E.muscle .. " Fast strength", function(v)
    repRunId = repRunId + 1
    if v then task.spawn(fastRepLoop, repRunId) end
end)

selectTab(E.bolt .. " Fast Rebirth")

closeBtn.Activated:Connect(function()
    alive = false
    gui:Destroy()
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        gui.Enabled = not gui.Enabled
    end
end)

print("[Tazen hub] UI chargée et prête !")

end)

if not ok then warn("[Tazen hub] Error: " .. tostring(err)) end
