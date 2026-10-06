-- Tazen hub fast farm by TZ_THR (standalone UI)

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
local REBIRTH_COOLDOWN = 6       -- Game cooldown between two rebirths (seconds)
local IMAGE_ID = 79546688195352

-- Emojis
local E = {
    bolt = "\u{26A1}", muscle = "\u{1F4AA}", toolbox = "\u{1F9F0}",
    sleep = "\u{1F634}", rocket = "\u{1F680}", sparkles = "\u{2728}", heart = "\u{1F496}",
    wrench = "\u{1F527}", antenna = "\u{1F4E1}", game = "\u{1F3AE}", bulb = "\u{1F4A1}",
    clock = "\u{1F550}", hourglass = "\u{23F3}", sun = "\u{1F31E}", calendar = "\u{1F4C5}",
    trophy = "\u{1F3C6}", target = "\u{1F3AF}", chart = "\u{1F4CA}", broom = "\u{1F9F9}", loop = "\u{1F501}"
}

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
local repRunId = 0
local repRate = 700          -- Ajusté à 700 reps/s pour soulager le réseau
local repCounter = 0         
local repTotal = 0           

-- ===================== GAME HELPERS =====================
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

local repToggleObj = nil 

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
            if not muscleEvent.Parent then muscleEvent = findMuscleEvent(rEvents) or muscleEvent end
        end

        carry = carry + repRate * dt
        local n = math.floor(carry)
        carry = carry - n
        if n > 200 then n = 200 end

        for _ = 1, n do pcall(muscleEvent.FireServer, muscleEvent, "rep") end
        repCounter = repCounter + n
        repTotal = repTotal + n
    end
end

-- ===================== FAST REBIRTH =====================
local function fastRebirthLoop(myId)
    local function isRunning() return fastRunId == myId end

    local okT, errT = pcall(function()
        local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
        local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)
        local equipPetEvent = rEvents and rEvents:WaitForChild("equipPetEvent", 5)
        local FOLDERS = {"Unique", "Rare", "Epic", "Mythic", "Legendary"}
        local SLOTS = 12

        if not rebirthRemote or not equipPetEvent then return end

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
            for i = 1, math.min(#allHydras, SLOTS) do list[i] = allHydras[i] end
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
                            table.insert(repPets, { Instance = pet, Priority = priority, Score = getPetScore(pet) })
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
                if pet and pet.Parent then equipPetEvent:FireServer("equipPet", pet) end
            end
        end

        local function unequipSet(petList)
            for _, pet in ipairs(petList) do
                if pet and pet.Parent then equipPetEvent:FireServer("unequipPet", pet) end
            end
        end

        local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        while isRunning() and not petsFolder do
            task.wait(1)
            petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        end
        if not isRunning() then return end

        local hydraList = buildHydraList(petsFolder)
        local repList = buildRepList(petsFolder)

        if #hydraList == 0 then return end

        while isRunning() do
            local cycleStart = os.clock()

            -- 1. Équiper les Titanium Hydras
            unequipSet(repList)
            equipSet(hydraList)

            -- Temps d'attente réseau indispensable pour la validation des Hydras
            task.wait(0.08)

            -- 2. Lancer la requête de Rebirth (Asynchrone)
            task.spawn(function()
                pcall(function() rebirthRemote:InvokeServer("rebirthRequest") end)
            end)

            task.wait(0.02)

            -- 3. Remettre les Fast Rep pets
            unequipSet(hydraList)
            equipSet(repList)

            -- 4. Cooldown exact de 6 secondes
            local elapsed = os.clock() - cycleStart
            task.wait(math.max(0, REBIRTH_COOLDOWN - elapsed))
        end
    end)
end

-- ===================== CALCULATEUR STATS =====================
local tracker = { strGain = 0, rebGain = 0 }
local samples = {}
local WINDOW = 20

local function bindStat(statName, altName, key)
    task.spawn(function()
        local ls = LocalPlayer:WaitForChild("leaderstats", 10)
        if not ls then return end
        local stat = ls:WaitForChild(statName, 10) or (altName and ls:FindFirstChild(altName))
        if not stat then return end
        local last = tonumber(stat.Value) or 0
        connect(stat.Changed, function(v)
            v = tonumber(v) or last
            if v > last then tracker[key] = tracker[key] + (v - last) end
            last = v
        end)
    end)
end
bindStat("Strength", "Muscle", "strGain")
bindStat("Rebirths", "Rebirth", "rebGain")

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function fmt(n)
    if n ~= n or n == math.huge then return "--" end
    if n < 1000 then
        if n == 0 then return "0" end
        if n >= 100 then return string.format("%.0f", n) end
        if n >= 10 then return string.format("%.1f", n) end
        return string.format("%.2f", n)
    end
    local i = 1
    while n >= 1000 and i < #SUFFIX do
        n = n / 1000
        i = i + 1
    end
    return string.format("%.2f%s", n, SUFFIX[i])
end

local function pushSample()
    local now = tick()
    table.insert(samples, { t = now, str = tracker.strGain, reb = tracker.rebGain, rep = repTotal })
    while #samples > 2 and now - samples[1].t > WINDOW do
        table.remove(samples, 1)
    end
end

local function projections(rate)
    return { fmt(rate), fmt(rate * 60), fmt(rate * 3600), fmt(rate * 86400), fmt(rate * 604800) }
end

-- ===================== MISC =====================
local Lighting = game:GetService("Lighting")
local antiAfkConn = nil

local function setAntiAfk(state)
    if antiAfkConn then antiAfkConn:Disconnect() antiAfkConn = nil end
    if not state then return end
    local okV, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
    if not okV or not VirtualUser then return end

    antiAfkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end

local antiLagConn = nil
local function antiLagStart()
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.FogEnd = 9e9 end)
    antiLagConn = workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ParticleEmitter") or d:IsA("Trail") then d.Enabled = false end
    end)
end

local function antiLagStop()
    if antiLagConn then antiLagConn:Disconnect() antiLagConn = nil end
end

local fpsFrames = 0
connect(RunService.Heartbeat, function() fpsFrames = fpsFrames + 1 end)

-- ===================== THEME & UI =====================
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

-- Arrière-plan Logo
new("ImageLabel", {
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
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 3,
}, main)

-- Topbar
local topbar = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Topbar, ZIndex = 6 }, main)
textLabel({ Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 14, 0, 4), Text = E.sparkles .. " Tazen hub fast farm", Font = Enum.Font.GothamBlack, TextSize = 17, ZIndex = 6 }, topbar)
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
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
        Size = UDim2.fromOffset(150, 28),
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

local function addSlider(page, name, min, max, default, callback)
    local f = new("Frame", { Size = UDim2.new(1, -20, 0, 62), BackgroundColor3 = T.Element, ZIndex = 5 }, page)
    corner(f, 8)

    textLabel({ Size = UDim2.new(1, -100, 0, 24), Position = UDim2.new(0, 12, 0, 6), Text = name, ZIndex = 5 }, f)
    local valueLabel = textLabel({ Size = UDim2.fromOffset(80, 24), Position = UDim2.new(1, -92, 0, 6), Text = tostring(default), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Accent, Font = Enum.Font.GothamBold, ZIndex = 5 }, f)

    local track = new("Frame", { Size = UDim2.new(1, -24, 0, 8), Position = UDim2.new(0, 12, 0, 42), BackgroundColor3 = T.Off, ZIndex = 5 }, f)
    corner(track, 4)
    local fill = new("Frame", { Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3 = T.Accent, ZIndex = 5 }, track)
    corner(fill, 4)

    local hit = new("TextButton", { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0, 31), BackgroundTransparency = 1, Text = "", ZIndex = 6 }, f)
    local dragging = false
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        valueLabel.Text = tostring(value)
        callback(value)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function addStatBlock(page, title, rowNames)
    local h = 30 + #rowNames * 22 + 6
    local f = new("Frame", { Size = UDim2.new(1, -20, 0, h), BackgroundColor3 = T.Element, ZIndex = 5 }, page)
    corner(f, 8)
    stroke(f, T.Stroke, 1)

    textLabel({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 12, 0, 4), Text = title, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Accent, ZIndex = 5 }, f)

    local values = {}
    for i, name in ipairs(rowNames) do
        local y = 28 + (i - 1) * 22
        textLabel({ Size = UDim2.new(0.5, -12, 0, 20), Position = UDim2.new(0, 12, 0, y), Text = name, TextSize = 13, TextColor3 = T.SubText, ZIndex = 5 }, f)
        values[i] = textLabel({ Size = UDim2.new(0.5, -12, 0, 20), Position = UDim2.new(0.5, 0, 0, y), Text = "--", TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 }, f)
    end

    return {
        Set = function(_, list)
            for i, v in ipairs(list) do
                if values[i] then values[i].Text = v end
            end
        end,
    }
end

-- TABS CREATION
local fastPage = createTab(E.bolt .. " Fast Rebirth")
local strPage = createTab(E.muscle .. " Fast Strength")
local miscPage = createTab(E.toolbox .. " Misc")

local REB_ROWS = { E.bolt .. " Per second", E.clock .. " Per minute", E.hourglass .. " Per hour", E.sun .. " Per day", E.calendar .. " Per week", E.trophy .. " Total gained" }
local STR_ROWS = { E.bolt .. " Per second", E.clock .. " Per minute", E.hourglass .. " Per hour", E.sun .. " Per day", E.calendar .. " Per week", E.trophy .. " Total gained", E.target .. " Strength / rep" }

-- FAST REBIRTH
addToggle(fastPage, E.bolt .. " Fast Rebirth (6s)", function(v)
    fastRunId = fastRunId + 1
    if v then
        task.spawn(fastRebirthLoop, fastRunId)
        if repToggleObj and not repToggleObj.Value then
            repToggleObj:Set(true)
        end
    end
end)
local fastRebBlock = addStatBlock(fastPage, E.loop .. " CALCULATEUR REBIRTHS", REB_ROWS)

-- FAST STRENGTH
repToggleObj = addToggle(strPage, E.muscle .. " Fast Strength", function(v)
    repRunId = repRunId + 1
    if v then task.spawn(fastRepLoop, repRunId) end
end)
addSlider(strPage, E.wrench .. " Reps / seconde", 100, 3000, repRate, function(v) repRate = v end)
local repLabel = textLabel({ Size = UDim2.new(1, -20, 0, 30), Text = E.antenna .. " Real reps/s: --", ZIndex = 5 }, strPage)
local strBlock = addStatBlock(strPage, E.muscle .. " CALCULATEUR STRENGTH", STR_ROWS)

-- MISC
addToggle(miscPage, E.sleep .. " Anti AFK", setAntiAfk)
addToggle(miscPage, E.rocket .. " Anti Lag", function(v)
    if v then antiLagStart() else antiLagStop() end
end)
local fpsLabel = textLabel({ Size = UDim2.new(1, -20, 0, 30), Text = E.game .. " FPS: --", ZIndex = 5 }, miscPage)

selectTab(E.bolt .. " Fast Rebirth")

-- CALCULATEUR METRICS & TICKER
task.spawn(function()
    while alive do
        task.wait(1)
        repLabel.Text = E.antenna .. " Real reps/s: " .. (repCounter or 0)
        repCounter = 0
        fpsLabel.Text = E.game .. " FPS: " .. fpsFrames
        fpsFrames = 0

        pushSample()
        local a, b = samples[1], samples[#samples]
        if a and b and b.t - a.t >= 3 then
            local dt = b.t - a.t
            local strRate = (b.str - a.str) / dt
            local rebRate = (b.reb - a.reb) / dt
            local dRep = b.rep - a.rep

            local sList = projections(strRate)
            table.insert(sList, fmt(tracker.strGain))
            table.insert(sList, dRep > 0 and fmt((b.str - a.str) / dRep) or "--")
            strBlock:Set(sList)

            local rList = projections(rebRate)
            table.insert(rList, fmt(tracker.rebGain))
            fastRebBlock:Set(rList)
        else
            strBlock:Set({ "calcul...", "calcul...", "calcul...", "calcul...", "calcul...", fmt(tracker.strGain), "--" })
            fastRebBlock:Set({ "calcul...", "calcul...", "calcul...", "calcul...", "calcul...", fmt(tracker.rebGain) })
        end
    end
end)

closeBtn.Activated:Connect(function()
    alive = false
    gui:Destroy()
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        gui.Enabled = not gui.Enabled
    end
end)

print("[Tazen hub fast farm] Chargé !")

end)

if not ok then warn("[Tazen hub fast farm] Error: " .. tostring(err)) end
