-- Tazen hub V1 by TZN_THR (Template with Calculator & Fast Rep Slider)

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
local E = {
    bolt = "\u{26A1}", cycle = "\u{1F504}", muscle = "\u{1F4AA}", toolbox = "\u{1F9F0}",
    sleep = "\u{1F634}", rocket = "\u{1F680}", sparkles = "\u{2728}", heart = "\u{1F496}",
    ok = "\u{2705}", no = "\u{274C}", chart = "\u{1F4CA}", up = "\u{1F4C8}", broom = "\u{1F9F9}",
    clock = "\u{1F550}", hourglass = "\u{23F3}", sun = "\u{1F31E}", calendar = "\u{1F4C5}",
    trophy = "\u{1F3C6}", target = "\u{1F3AF}", wrench = "\u{1F527}", clip = "\u{1F4CB}",
    bulb = "\u{1F4A1}", fire = "\u{1F525}", loop = "\u{1F501}", antenna = "\u{1F4E1}",
    party = "\u{1F389}", game = "\u{1F3AE}", crown = "\u{1F451}",
}

local IMAGE_ID = 0
local IMAGE_FILE = "tazen_logo.png"

-- ===================== STATE =====================
local alive = true
local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

-- ===================== TES FONCTIONS SUR MESURE =====================

-- Variable pour stocker la valeur du slider Fast Rep
local fastRepSpeed = 659

-- 1. Ta fonction pour Fast Rebirth
local function myFastRebirthFunction(state)
    -- [TES FONCTIONS ICI]
    if state then
        print("[Tazen hub] Fast Rebirth active")
    else
        print("[Tazen hub] Fast Rebirth desactive")
    end
end

-- 2. Ta fonction pour le Slider Fast Rep (Vitesse/Rep)
local function myFastRepSpeedFunction(value)
    fastRepSpeed = value
    -- [TES FONCTIONS ICI]
    print("[Tazen hub] Fast Rep Speed modifie : " .. tostring(value))
end

-- 3. Ta fonction pour Auto Rebirth
local function myAutoRebirthFunction(state)
    -- [TES FONCTIONS ICI]
    if state then
        print("[Tazen hub] Auto Rebirth active")
    else
        print("[Tazen hub] Auto Rebirth desactive")
    end
end

-- 4. Ta fonction pour Fast Strength
local function myFastStrengthFunction(state)
    -- [TES FONCTIONS ICI]
    if state then
        print("[Tazen hub] Fast Strength active")
    else
        print("[Tazen hub] Fast Strength desactive")
    end
end

-- 5. Ta fonction pour Anti AFK
local function myAntiAfkFunction(state)
    -- [TES FONCTIONS ICI]
    if state then
        print("[Tazen hub] Anti AFK active")
    else
        print("[Tazen hub] Anti AFK desactive")
    end
end

-- 6. Ta fonction pour Anti Lag
local function myAntiLagFunction(state)
    -- [TES FONCTIONS ICI]
    if state then
        print("[Tazen hub] Anti Lag active")
    else
        print("[Tazen hub] Anti Lag desactive")
    end
end

-- ===================== THEME / UI HELPERS =====================
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

-- ===================== WINDOW =====================
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
local H = math.min(380, vp.Y - 30)

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

-- Background image
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

new("Frame", {
    Name = "Shade",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 3,
}, main)

if imageId == "" then
    bg.Visible = false
    local wm = textLabel({
        Name = "Watermark",
        Size = UDim2.new(1, 0, 0, 110),
        Position = UDim2.new(0, 0, 0.5, -40),
        Text = "TAZEN",
        Font = Enum.Font.GothamBlack,
        TextSize = 84,
        TextColor3 = Color3.new(1, 1, 1),
        TextTransparency = 0.5,
        TextStrokeTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    }, main)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.501, T.Accent),
            ColorSequenceKeypoint.new(1, T.Accent),
        }),
    }, wm)
end

-- Top bar
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
    Text = E.sparkles .. " Tazen hub V1",
    Font = Enum.Font.GothamBlack,
    TextSize = 17,
}, topbar)

textLabel({
    Size = UDim2.new(1, -110, 0, 14),
    Position = UDim2.new(0, 14, 0, 25),
    Text = E.heart .. " by TZN_THR  |  press K to hide",
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
local minBtn = topButton("-", -72)

-- Window dragging
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

-- Tab bar + pages
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
local tabCount = 0

local function selectTab(name)
    for tabName, t in pairs(tabs) do
        local on = (tabName == name)
        t.page.Visible = on
        t.button.BackgroundColor3 = on and T.Accent or T.Element
        t.button.BackgroundTransparency = on and 0.1 or 0.25
    end
end

local function createTab(name)
    tabCount = tabCount + 1
    local tabW = math.floor((W - 20 - 6 * 3) / 4)
    local button = new("TextButton", {
        Size = UDim2.fromOffset(tabW, 28),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.25,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextScaled = true,
        TextColor3 = T.Text,
        TextStrokeTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = tabCount,
    }, tabBar)
    corner(button, 8)
    new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, button)

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

-- ===================== ELEMENTS (Rayfield style) =====================
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
    }, sw)
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
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, T.Stroke, 1)

    textLabel({
        Size = UDim2.new(1, -80, 0, 22),
        Position = UDim2.new(0, 12, 0, 4),
        Text = name,
    }, f)

    local valLbl = textLabel({
        Size = UDim2.new(0, 60, 0, 22),
        Position = UDim2.new(1, -72, 0, 4),
        Text = tostring(default),
        TextColor3 = T.Accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        Font = Enum.Font.GothamBold,
    }, f)

    local track = new("Frame", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.new(0, 12, 0, 34),
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

    local dragging = false
    local function update(input)
        local posX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + posX * (max - min))
        fill.Size = UDim2.new(posX, 0, 1, 0)
        valLbl.Text = tostring(val)
        if callback then callback(val) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function addCredit(page, text)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, T.Accent, 1.5)
    textLabel({
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = T.Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, f)
end

-- ===================== CALCULATOR LOGIC =====================
local function formatNum(n)
    local s = tostring(math.floor(n))
    local k
    while true do
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

local function addCalculator(page)
    addSection(page, E.chart .. " Rebirth Calculator")

    local calcBox = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        Text = "",
        PlaceholderText = "Enter target Rebirths...",
        PlaceholderColor3 = T.SubText,
        TextColor3 = T.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        BorderSizePixel = 0,
    }, page)
    corner(calcBox, 8)
    stroke(calcBox, T.Stroke, 1)

    local resLbl = addLabel(page, E.hourglass .. " Result will appear here...", 50)

    calcBox.FocusLost:Connect(function()
        local target = tonumber(calcBox.Text)
        if not target then
            resLbl:SetText(E.no .. " Invalid number entered.")
            return
        end

        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        local currentRebirths = leaderstats and leaderstats:FindFirstChild("Rebirths") and leaderstats.Rebirths.Value or 0
        local needed = target - currentRebirths

        if needed <= 0 then
            resLbl:SetText(E.ok .. " Target already reached or exceeded!")
            return
        end

        -- Calcul estime base sur le Fast Rep Speed actuel
        local seconds = needed * (1 / (fastRepSpeed / 100))
        local mins = math.floor(seconds / 60)
        local hrs = math.floor(mins / 60)
        local days = math.floor(hrs / 24)

        local timeStr = ""
        if days > 0 then timeStr = timeStr .. days .. "d " end
        if hrs % 24 > 0 then timeStr = timeStr .. (hrs % 24) .. "h " end
        if mins % 60 > 0 then timeStr = timeStr .. (mins % 60) .. "m " end
        timeStr = timeStr .. math.floor(seconds % 60) .. "s"

        resLbl:SetText(E.target .. " Needed: " .. formatNum(needed) .. " Rebirths\n" .. E.clock .. " Est. Time: " .. timeStr)
    end)
end

-- ===================== TABS =====================
local TAB_FAST = E.bolt .. " Fast Rebirth"
local TAB_AUTO = E.cycle .. " Auto Rebirth"
local TAB_STR = E.muscle .. " Fast Strength"
local TAB_MISC = E.toolbox .. " Misc"

local fastPage = createTab(TAB_FAST)
local autoPage = createTab(TAB_AUTO)
local strPage = createTab(TAB_STR)
local miscPage = createTab(TAB_MISC)

-- Fast Rebirth
addSection(fastPage, E.fire .. " Fast Rebirth")
addToggle(fastPage, E.bolt .. " Fast rebirth", function(state)
    myFastRebirthFunction(state)
end)

-- Slider Fast Rep (659 -> 3000)
addSlider(fastPage, E.bolt .. " Fast Rep Speed", 659, 3000, 659, function(value)
    myFastRepSpeedFunction(value)
end)

-- Auto Rebirth
addSection(autoPage, E.cycle .. " Auto Rebirth")
addToggle(autoPage, E.cycle .. " Auto rebirth", function(state)
    myAutoRebirthFunction(state)
end)

-- Fast Strength
addSection(strPage, E.muscle .. " Fast Strength")
addToggle(strPage, E.muscle .. " Fast strength", function(state)
    myFastStrengthFunction(state)
end)

-- Misc
addSection(miscPage, E.toolbox .. " Utilities")
addToggle(miscPage, E.sleep .. " Anti AFK", function(state)
    myAntiAfkFunction(state)
end)

addToggle(miscPage, E.rocket .. " Anti Lag", function(state)
    myAntiLagFunction(state)
end)

-- Calculateur dans l'onglet Misc
addCalculator(miscPage)

addSection(miscPage, E.heart .. " Credits")
addCredit(miscPage, E.sparkles .. " Made by TZN_THR, Thank you for using my script have fun " .. E.party)

selectTab(TAB_FAST)

-- ===================== WINDOW BUTTONS =====================
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
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        gui.Enabled = not gui.Enabled
    end
end)

print("[Tazen hub] UI re-loaded with Calculator & Slider (659-3000)")

end)

if not ok then
    warn("[Tazen hub] Error: " .. tostring(err))
end
