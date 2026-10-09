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
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ===================== CONFIG & SAVE SYSTEM (KILLING ONLY) =====================
local CONFIG_FILE_PREFIX = "TazenHub_Config_"

local function loadCategoryConfig(categoryName)
    local success, result = pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE_PREFIX .. categoryName .. ".json") then
            return HttpService:JSONDecode(readfile(CONFIG_FILE_PREFIX .. categoryName .. ".json"))
        end
    end)
    if success and type(result) == "table" then
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
local REBIRTH_COOLDOWN = 6

local E = {
    bolt = "\u{26A1}", cycle = "\u{1F504}", muscle = "\u{1F4AA}", toolbox = "\u{1F9F0}",
    sleep = "\u{1F634}", rocket = "\u{1F680}", sparkles = "\u{2728}", heart = "\u{1F496}",
    ok = "\u{2705}", no = "\u{274C}", chart = "\u{1F4CA}", up = "\u{1F4C8}", broom = "\u{1F9F9}",
    clock = "\u{1F550}", hourglass = "\u{23F3}", sun = "\u{1F31E}", calendar = "\u{1F4C5}",
    trophy = "\u{1F3C6}", target = "\u{1F3AF}", wrench = "\u{1F527}", clip = "\u{1F4CB}",
    bulb = "\u{1F4A1}", fire = "\u{1F525}", loop = "\u{1F501}", antenna = "\u{1F4E1}",
    party = "\u{1F389}", game = "\u{1F3AE}", crown = "\u{1F451}", egg = "\u{1F95A}",
    wheel = "\u{1F3A1}", skull = "\u{1F480}", rainbow = "\u{1F308}", chest = "\u{1F381}",
    sword = "\u{2694}\u{FE0F}", shield = "\u{1F6E1}\u{FE0F}", crosshairs = "\u{1F3AF}",
    shieldAlt = "\u{1F6E1}"
}

local IMAGE_ASSET = "rbxassetid://91265185075125"

local repSpeedPetPriorities = {
    ["Omega Overlord"] = 1,
    ["Mythic Boss Pet"] = 1,
    ["Legendary Boss Pet"] = 2,
    ["Epic Boss Pet"] = 3,
}

local alive = true
local connections = {}
local function connect(signal, fn)
    local success, c = pcall(function() return signal:Connect(fn) end)
    if success and c then
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

local repRate = 659
local repTotal = 0

local RebirthTracker = {} -- défini plus bas (compteur fiable basé sur la stat Rebirths)
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

local function equipFists()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end

        local punchTool = char:FindFirstChild("Fight") or char:FindFirstChild("Punch")
        if not punchTool then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and (tool.Name:lower():find("fight") or tool.Name:lower():find("punch")) then
                    tool.Parent = char
                    break
                end
            end
        end
    end)
end

local function serverHop()
    killStatus = "Changement de serveur..."
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
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local attackRemote = rEvents and (rEvents:FindFirstChild("attackEvent") or rEvents:FindFirstChild("muscleEvent"))
    lastKillTick = tick()

    while killRunId == myId and alive do
        pcall(function()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then
                killStatus = "En attente du personnage..."
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
                        equipFists()
                        if hrp and pHrp then
                            hrp.CFrame = pHrp.CFrame * CFrame.new(0, 3, 2)
                        end
                        if attackRemote then
                            pcall(function() attackRemote:FireServer("punch", targetPlayer.Character) end)
                        end
                        task.wait(0.03)
                    end

                    if deathConn then deathConn:Disconnect() end
                else
                    killStatus = "Aucune cible dispo..."
                    task.wait(0.5)
                end
            end

            if tick() - lastKillTick > 60 then
                serverHop()
            end
        end)
        task.wait(0.1)
    end
end

local function killTargetPlayerLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local attackRemote = rEvents and (rEvents:FindFirstChild("attackEvent") or rEvents:FindFirstChild("muscleEvent"))
    lastKillTick = tick()

    while killRunId == myId and alive do
        pcall(function()
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then
                killStatus = "En attente du personnage..."
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

                    killStatus = "Cible : " .. targetPlayer.Name
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
                        equipFists()
                        if hrp and pHrp then
                            hrp.CFrame = pHrp.CFrame * CFrame.new(0, 3, 2)
                        end
                        if attackRemote then
                            pcall(function() attackRemote:FireServer("punch", targetPlayer.Character) end)
                        end
                        task.wait(0.03)
                    end

                    if deathConn then deathConn:Disconnect() end
                else
                    killStatus = "Aucune Target connectée..."
                    task.wait(0.5)
                end
            end
        end)
        task.wait(0.1)
    end
end

local function fastRebirthLoop(myId)
    local function isRunning() return fastRunId == myId end
    pcall(function()
        local rebirthRemote = ReplicatedStorage.rEvents.rebirthRemote
        local equipPetEvent = ReplicatedStorage.rEvents.equipPetEvent
        local FOLDERS = {"Unique", "Rare", "Epic", "Mythic", "Legendary"}

        local HYDRA_LEAD = 0.10             
        local HYDRA_TAIL = 0.05             
        local REP_OFF_LEAD = 0.10           
        local REP_ON_DELAY = 0.05           
        local REBIRTH_MARGIN = 0.03         
        local SLOTS = 12                    
        local AUTO_TRY = 20                 
        local FULL_SWAP = true              
        local STARTUP_UNEQUIP_PER_FRAME = 20
        local LIST_REFRESH_EVERY = 5        

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
                        if #list < slots and petRealName(pet) == "Titanium Hydra" then
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
                        local priority = repSpeedPetPriorities[petRealName(pet)] or 5
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

        local function setEquipped(wanted, burst, equipFirst)
            local want, have = {}, {}
            for _, pet in ipairs(wanted) do want[pet] = true end
            for _, pet in ipairs(equipped) do have[pet] = true end

            local outList, inList = {}, {}
            for _, pet in ipairs(equipped) do
                if not want[pet] and pet.Parent then table.insert(outList, pet) end
            end
            local newEquipped = {}
            for _, pet in ipairs(wanted) do
                if pet.Parent then
                    if not have[pet] then table.insert(inList, pet) end
                    table.insert(newEquipped, pet)
                end
            end

            local function fire(kind, pet)
                pcall(function() equipPetEvent:FireServer(kind, pet) end)
                if not burst then task.wait() end
            end

            local firstN = equipFirst and math.min(#inList, #outList) or #outList
            for i = 1, firstN do fire("unequipPet", outList[i]) end
            for _, pet in ipairs(inList) do fire("equipPet", pet) end
            for i = firstN + 1, #outList do fire("unequipPet", outList[i]) end

            equipped = newEquipped
        end

        local function waitUntil(t)
            while isRunning() and os.clock() < t do
                task.wait()
            end
        end

        local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        while isRunning() and not petsFolder do
            task.wait(1)
            petsFolder = LocalPlayer:FindFirstChild("petsFolder")
        end
        if not isRunning() then return end

        local autoSlots = (SLOTS <= 0)
        local slots = autoSlots and AUTO_TRY or SLOTS

        local hydraList, repTarget, swapList, offList
        local function rebuild()
            hydraList = buildHydraList(petsFolder, slots)
            local keep = math.max(0, slots - #hydraList)
            repTarget = buildRepList(petsFolder, slots)
            offList = {}
            if not FULL_SWAP and not autoSlots then
                for i = 1, math.min(keep, #repTarget) do table.insert(offList, repTarget[i]) end
            end
            swapList = {}
            for _, pet in ipairs(offList) do table.insert(swapList, pet) end
            for _, h in ipairs(hydraList) do table.insert(swapList, h) end
        end
        rebuild()

        if #hydraList == 0 then return end

        unequipAllPets(petsFolder)
        if not isRunning() then return end
        setEquipped(repTarget, true)

        local cycle = 0
        local rebirthAt = os.clock() + HYDRA_LEAD

        while isRunning() do
            cycle = cycle + 1

            local repOffLead = math.max(REP_OFF_LEAD, HYDRA_LEAD)
            if repOffLead > HYDRA_LEAD + 0.001 then
                waitUntil(rebirthAt - repOffLead)
                if not isRunning() then break end
                setEquipped(offList, true)
            end

            waitUntil(rebirthAt - HYDRA_LEAD)
            if not isRunning() then break end
            setEquipped(swapList, true, true)

            waitUntil(rebirthAt)
            if not isRunning() then break end
            local tFire = os.clock()
            task.spawn(function()
                pcall(function()
                    local okR, res = pcall(function()
                        return rebirthRemote:InvokeServer("rebirthRequest")
                    end)
                    if okR then RebirthTracker.onRemote(res) end
                end)
            end)

            waitUntil(tFire + HYDRA_TAIL)
            setEquipped(offList, true)
            waitUntil(tFire + REP_ON_DELAY)
            setEquipped(repTarget, true)

            if cycle % LIST_REFRESH_EVERY == 0 then
                petsFolder = LocalPlayer:FindFirstChild("petsFolder") or petsFolder
                rebuild()
            end

            rebirthAt = tFire + REBIRTH_COOLDOWN + REBIRTH_MARGIN
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
                local okR, res = pcall(function()
                    return rebirthRemote:InvokeServer("rebirthRequest")
                end)
                if okR then RebirthTracker.onRemote(res) end
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

        if repRate > 0 then
            carry = carry + repRate * dt
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
            local wheelRemote = rEvents and (rEvents:FindFirstChild("openFortuneWheel") or rEvents:FindFirstChild("openFortuneWheelRemote"))
            if wheelRemote then
                local shared = ReplicatedStorage:FindFirstChild("shared")
                local catalogs = shared and shared:FindFirstChild("catalogs")
                local chances = catalogs and catalogs:FindFirstChild("fortuneWheelChances")
                local fortuneWheel = chances and chances:FindFirstChild("Fortune Wheel")
                if fortuneWheel then
                    wheelRemote:InvokeServer("openFortuneWheel", fortuneWheel)
                end
            end
        end)
        task.wait(1)
    end
end

local function autoEggLoop(myId)
    while eggRunId == myId and alive do
        pcall(function()
            local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
            local eggRemote = rEvents and (rEvents:FindFirstChild("useItemRemote") or rEvents:FindFirstChild("eatEggRemote") or rEvents:FindFirstChild("itemRemote"))
            if eggRemote then
                eggRemote:InvokeServer("Protein Egg")
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

-- ===================== STAT TRACKER (Strength / Durability) =====================
-- Détecte les gains réels du joueur (uniquement quand Fast strength est actif)
-- puis prédit les gains futurs à partir du rythme observé.
local StatTracker = {}
do
    local SUFFIX = {
        k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18,
        sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33,
    }
    local WINDOW = 30 -- secondes utilisées pour la prédiction "récente"

    -- Accepte un nombre, "1234", "1,234" ou "1.5K" / "2.3Qa"
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

    -- Cherche la stat dans leaderstats, puis directement sur le joueur (Durability y est souvent),
    -- puis dans quelques dossiers courants, puis dans les attributs.
    local function findSource(names)
        local containers = {}
        local candidates = {
            LocalPlayer:FindFirstChild("leaderstats"),
            LocalPlayer,
            LocalPlayer:FindFirstChild("Data"),
            LocalPlayer:FindFirstChild("Stats"),
            LocalPlayer:FindFirstChild("stats"),
        }
        for i = 1, 5 do
            if candidates[i] then containers[#containers + 1] = candidates[i] end
        end

        for _, name in ipairs(names) do
            for _, c in ipairs(containers) do
                local inst = c:FindFirstChild(name)
                if inst and inst:IsA("ValueBase") and parse(inst.Value) ~= nil then
                    return function()
                        if not inst.Parent then return nil end
                        return parse(inst.Value)
                    end, ((c == LocalPlayer) and "Player" or c.Name) .. "." .. name
                end
            end
        end
        for _, name in ipairs(names) do
            if LocalPlayer:GetAttribute(name) ~= nil then
                return function() return parse(LocalPlayer:GetAttribute(name)) end, "Attribut." .. name
            end
        end
        return nil
    end

    StatTracker.findSource = findSource

    local stats = {
        strength   = { names = { "Strength", "Muscle" } },
        durability = { names = { "Durability" } },
    }
    StatTracker.stats = stats

    function StatTracker.reset()
        for _, st in pairs(stats) do
            st.read = nil
            st.last = nil
            st.gained = 0
            st.history = {}
        end
    end
    StatTracker.reset()

    -- Lit les stats et cumule uniquement les hausses (les baisses = rebirth/reset, on ignore)
    function StatTracker.poll()
        for _, st in pairs(stats) do
            if not st.read then
                st.read = findSource(st.names)
                st.last = nil
            end
            if st.read then
                local ok, cur = pcall(st.read)
                if ok and cur then
                    if st.last and cur > st.last then
                        st.gained = st.gained + (cur - st.last)
                    end
                    st.last = cur
                else
                    st.read = nil -- source perdue : on la recherchera au prochain tour
                    st.last = nil
                end
            end
        end
    end

    -- Enregistre un point par seconde pour calculer le rythme récent
    function StatTracker.record(now)
        for _, st in pairs(stats) do
            local h = st.history
            h[#h + 1] = { t = now, g = st.gained }
            while #h > 2 and now - h[2].t >= WINDOW do
                table.remove(h, 1)
            end
        end
    end

    -- Gains par seconde : rythme des 30 dernières secondes si dispo, sinon moyenne de session
    function StatTracker.rate(st, now, startT)
        local elapsed = math.max(1, now - startT)
        local h = st.history
        if elapsed > WINDOW and #h >= 2 then
            local old = h[1]
            local dt = now - old.t
            if dt >= 5 then
                return math.max(0, (st.gained - old.g) / dt)
            end
        end
        return st.gained / elapsed
    end

    function StatTracker.text(icon, label, st, now, startT)
        if not st.read then
            return string.format("%s %s : stat introuvable", icon, label)
        end
        local r = StatTracker.rate(st, now, startT)
        return string.format("%s %s Tot: %s (+%s/s) | 1m: %s | 1h: %s | 1j: %s | 1sem: %s | 1mois: %s",
            icon, label, formatNumber(st.gained), formatNumber(r),
            formatNumber(r * 60), formatNumber(r * 3600), formatNumber(r * 86400),
            formatNumber(r * 604800), formatNumber(r * 2592000))
    end

    -- Boucle de détection : tourne en continu mais ne compte que si Fast strength est actif
    task.spawn(function()
        local lastRecord = 0
        while alive do
            task.wait(0.2)
            if repStartTime then
                pcall(StatTracker.poll)
                local now = tick()
                if now - lastRecord >= 1 then
                    lastRecord = now
                    pcall(StatTracker.record, now)
                end
            end
        end
    end)
end

-- ===================== REBIRTH TRACKER =====================
-- Deux signaux sont surveillés :
--  1) la stat "Rebirths" du joueur (méthode préférée, la plus fiable)
--  2) les réponses "true" du serveur à la demande de renaissance
-- Si la stat n'existe pas ou ne bouge pas alors que le serveur confirme des renaissances,
-- on bascule automatiquement sur le signal serveur pour que le compteur ne reste jamais bloqué.
do
    local T = RebirthTracker

    local function clear()
        T.count, T.startT, T.firstT, T.lastT, T.gap = 0, tick(), nil, nil, nil
        T.read, T.last, T.desc = nil, nil, nil
        T.statMoved, T.mode = false, "stat"
        T.srvTrue, T.srvTotal = 0, 0
    end
    clear()

    local function register(now, n)
        if T.lastT then T.gap = now - T.lastT end
        T.count = T.count + n
        T.firstT = T.firstT or now
        T.lastT = now
    end

    function T.poll()
        if not T.read then
            T.read, T.desc = StatTracker.findSource({ "Rebirths", "Rebirth" })
            T.last = nil
        end
        if T.read then
            local ok, cur = pcall(T.read)
            if ok and cur then
                if T.last and cur > T.last then
                    local n = math.max(1, math.floor(cur - T.last + 0.5))
                    if T.mode == "srv" then
                        -- déjà compté via le serveur : la stat bouge enfin, on repasse sur elle
                        T.mode = "stat"
                    else
                        register(tick(), n)
                    end
                    T.statMoved = true
                end
                T.last = cur
            else
                T.read, T.last = nil, nil
            end
        end
    end

    function T.reset()
        clear()
        pcall(T.poll) -- baseline immédiate pour ne pas rater la 1re renaissance
    end

    -- Appelé à chaque réponse du serveur à "rebirthRequest"
    function T.onRemote(res)
        T.srvTotal = T.srvTotal + 1
        if res ~= true then return end
        T.srvTrue = T.srvTrue + 1
        if T.statMoved then return end -- la stat fait déjà le travail
        if (not T.read) or T.srvTrue >= 3 then
            if T.mode ~= "srv" then
                T.mode = "srv"
                T.count = math.max(T.count, T.srvTrue - 1) -- rattrape les premières confirmations
            end
            register(tick(), 1)
        end
    end

    function T.lastText()
        return T.gap and string.format("%.2fs", T.gap) or "--"
    end

    -- Rythme observé entre la 1re et la dernière renaissance, plafonné par le cooldown
    function T.rate(now)
        if T.count < 2 or not T.firstT then return 0 end
        local r = (T.count - 1) / math.max(1, now - T.firstT)
        return math.min(r, 1 / REBIRTH_COOLDOWN)
    end

    function T.text(icon, now)
        local r = T.rate(now)
        local function p(x) return formatNumber(math.floor(x + 0.5)) end
        local src = (T.mode == "srv") and "serveur" or (T.desc or "stat introuvable")
        return string.format("%s Tot: %s | 1m: %s | 1h: %s | 1j: %s | 1sem: %s | 1mois: %s\n[source: %s | serveur ok: %d/%d]",
            icon, formatNumber(T.count), p(r * 60), p(r * 3600), p(r * 86400), p(r * 604800), p(r * 2592000),
            src, T.srvTrue, T.srvTotal)
    end

    task.spawn(function()
        while alive do
            task.wait(0.2)
            if fastStartTime or autoStartTime then pcall(T.poll) end
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

local fpsFrames = 0
connect(RunService.Heartbeat, function() fpsFrames = fpsFrames + 1 end)

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

new("ImageLabel", {
    Name = "Background",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Image = IMAGE_ASSET,
    ImageTransparency = 0.25,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 2,
}, main)

new("Frame", {
    Name = "Shade",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ZIndex = 3,
}, main)

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
    Text = E.heart .. " by TZ_THR  |  press K to hide",
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
    Size = UDim2.new(1, 0, 0, 34),
    Position = UDim2.new(0, 0, 0, 46),
    BackgroundTransparency = 1,
    ZIndex = 6,
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)
new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, tabBar)

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
    local tabW = math.floor((W - 12 - 4 * 4) / 5)
    local button = new("TextButton", {
        Size = UDim2.fromOffset(tabW, 28),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.25,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextScaled = true,
        TextColor3 = T.Text,
        TextStrokeTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = tabCount,
    }, tabBar)
    corner(button, 8)
    new("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 6 }, button)

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

local function addToggle(page, name, defaultState, callback)
    local initialState = defaultState
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
        BackgroundColor3 = initialState and T.Accent or T.Off,
        BorderSizePixel = 0,
    }, f)
    corner(sw, 10)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = initialState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, sw)
    corner(knob, 8)

    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, f)

    local obj = { Value = initialState }
    function obj:Set(v, noSave)
        if v == self.Value and not noSave then return end
        self.Value = v
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, { Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) }):Play()
        TweenService:Create(sw, info, { BackgroundColor3 = v and T.Accent or T.Off }):Play()
        if callback then callback(v) end
    end

    hit.Activated:Connect(function() obj:Set(not obj.Value) end)
    return obj
end

local function addKillingToggle(page, name, categoryKey, settingKey, defaultState, callback)
    local configData = loadCategoryConfig(categoryKey)
    local initialState = defaultState
    if configData[settingKey] ~= nil then initialState = configData[settingKey] end

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
        BackgroundColor3 = initialState and T.Accent or T.Off,
        BorderSizePixel = 0,
    }, f)
    corner(sw, 10)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = initialState and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, sw)
    corner(knob, 8)

    local hit = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, f)

    local obj = { Value = initialState }
    function obj:Set(v, noSave)
        if v == self.Value and not noSave then return end
        self.Value = v
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, { Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) }):Play()
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

local function addButton(page, name, callback)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = T.Text,
        TextStrokeTransparency = 0.5,
        BorderSizePixel = 0,
    }, page)
    corner(b, 8)
    stroke(b, T.Accent, 1)
    b.Activated:Connect(callback)
    return b
end

local repSliderUpdate = nil
local function addSlider(page, name, min, max, default, callback)
    local initialVal = default
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
        Text = tostring(initialVal),
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
        Size = UDim2.new((initialVal - min) / (max - min), 0, 1, 0),
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

local function notify(title, text)
    if not alive then return end
    pcall(function()
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
    end)
end

local TAB_FAST = E.bolt .. " Fast"
local TAB_AUTO = E.cycle .. " Auto"
local TAB_STR = E.muscle .. " Strength"
local TAB_KILL = E.sword .. " Killing"
local TAB_MISC = E.toolbox .. " Misc"

local fastPage = createTab(TAB_FAST)
local autoPage = createTab(TAB_AUTO)
local strPage = createTab(TAB_STR)
local killPage = createTab(TAB_KILL)
local miscPage = createTab(TAB_MISC)

local fastToggle, autoToggle, repToggle, killAllToggle, killTargetToggle, antiAfkToggle, antiLagToggle, autoWheelToggle, autoEggToggle

local function notifyState(title, v)
    notify(title, v and (E.ok .. " Enabled") or (E.no .. " Disabled"))
end

local function enableAutoFastRep()
    if repSliderUpdate then repSliderUpdate(659) end
    if repToggle and not repToggle.Value then repToggle:Set(true) end
end

-- Fast Rebirth
addSection(fastPage, E.fire .. " Fast Rebirth (Pack)")
addLabel(fastPage, "\u{26A0}\u{FE0F} You need pack for fast rebirth", 34)
fastToggle = addToggle(fastPage, E.bolt .. " Fast rebirth", false, function(v)
    fastRunId = fastRunId + 1
    if v then
        fastStartTime = tick()
        RebirthTracker.reset()
        autoRunId = autoRunId + 1
        if autoToggle then autoToggle:Set(false) end
        enableAutoFastRep()
        notifyState(E.bolt .. " Fast rebirth", true)
        task.spawn(fastRebirthLoop, fastRunId)
    else
        fastStartTime = nil
        notifyState(E.bolt .. " Fast rebirth", false)
    end
end)
local fastTimerLabel = addLabel(fastPage, E.clock .. " Session Time: 0s | Dernière renaissance : --", 36)
local fastCalcLabel = addLabel(fastPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55)

-- Auto Rebirth
addSection(autoPage, E.cycle .. " Auto Rebirth (No Pack)")
addLabel(autoPage, "\u{26A0}\u{FE0F} This tab can be used by everyone", 34)
autoToggle = addToggle(autoPage, E.cycle .. " Auto rebirth", false, function(v)
    autoRunId = autoRunId + 1
    if v then
        autoStartTime = tick()
        RebirthTracker.reset()
        fastRunId = fastRunId + 1
        if fastToggle then fastToggle:Set(false) end
        enableAutoFastRep()
        notifyState(E.cycle .. " Auto rebirth", true)
        task.spawn(autoRebirthLoop, autoRunId)
    else
        autoStartTime = nil
        notifyState(E.cycle .. " Auto rebirth", false)
    end
end)
local autoTimerLabel = addLabel(autoPage, E.clock .. " Session Time: 0s | Dernière renaissance : --", 36)
local autoCalcLabel = addLabel(autoPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55)

-- Fast Strength & Durability (Groupés dans l'onglet Strength)
addSection(strPage, E.muscle .. " Fast Strength & Durability Predictor")
repToggle = addToggle(strPage, E.muscle .. " Fast strength", false, function(v)
    repRunId = repRunId + 1
    if v then
        repStartTime = tick()
        repTotal = 0
        StatTracker.reset()
        notify(E.muscle .. " Fast strength", E.target .. " " .. repRate .. " reps/s targeted")
        task.spawn(fastRepLoop, repRunId)
    else
        repStartTime = nil
        notifyState(E.muscle .. " Fast strength", false)
    end
end)
repSliderUpdate = addSlider(strPage, E.wrench .. " Reps per second", 0, 1050, repRate, function(v) repRate = v end)
local repTimerLabel = addLabel(strPage, E.clock .. " Session Time: 0s | Moy. Reps/s: 0", 36)
local repCalcLabel = addLabel(strPage, E.muscle .. " Strength Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55)
local durabilityCalcLabel = addLabel(strPage, E.shieldAlt .. " Durability Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55)

-- Killing Tab
addSection(killPage, E.sword .. " Module de Combat / Killing")
killAllToggle = addKillingToggle(killPage, E.sword .. " Auto Kill All Players", "Killing", "AutoKillAll", false, function(v)
    killRunId = killRunId + 1
    if v then
        if killTargetToggle and killTargetToggle.Value then killTargetToggle:Set(false) end
        notifyState("Auto Kill All", true)
        task.spawn(autoKillAllLoop, killRunId)
    else
        notifyState("Auto Kill All", false)
    end
end)

killTargetToggle = addKillingToggle(killPage, E.target .. " Kill Target Players Only", "Killing", "KillTarget", false, function(v)
    killRunId = killRunId + 1
    if v then
        if killAllToggle and killAllToggle.Value then killAllToggle:Set(false) end
        notifyState("Kill Target Only", true)
        task.spawn(killTargetPlayerLoop, killRunId)
    else
        notifyState("Kill Target Only", false)
    end
end)

addButton(killPage, E.wrench .. " Save Config (Killing)", function()
    local cfg = { AutoKillAll = killAllToggle.Value, KillTarget = killTargetToggle.Value }
    saveCategoryConfig("Killing", cfg)
    notify("Config", E.ok .. " Killing sauvegardé !")
end)

local killStatusLabel = addLabel(killPage, E.clip .. " " .. killStatus, 40)

addSection(killPage, E.shield .. " Système Whitelist & Amis")
addButton(killPage, E.heart .. " Auto Whitelist Friends", function()
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr:IsFriendsWith(LocalPlayer.UserId) then
            whitelistPlayers[plr.Name] = true
            count = count + 1
        end
    end
    notify("Whitelist", E.ok .. " " .. count .. " ami(s) ajouté(s) à la whitelist !")
end)

addSection(killPage, E.crosshairs .. " Gestion des Joueurs Connectés")
local playerListContainer = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 160),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, killPage)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, playerListContainer)

local function refreshPlayerListUI()
    pcall(function()
        for _, c in ipairs(playerListContainer:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local row = new("Frame", {
                    Size = UDim2.new(1, -6, 0, 36),
                    BackgroundColor3 = T.Topbar,
                    BorderSizePixel = 0,
                }, playerListContainer)
                corner(row, 6)
                
                textLabel({
                    Size = UDim2.new(0.38, 0, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    Text = plr.Name,
                    TextSize = 12,
                    TextColor3 = T.Text,
                }, row)

                local wBtn = new("TextButton", {
                    Size = UDim2.fromOffset(65, 24),
                    Position = UDim2.new(0.40, 0, 0.5, -12),
                    BackgroundColor3 = whitelistPlayers[plr.Name] and T.Accent or T.Off,
                    Text = "Safe",
                    Font = Enum.Font.GothamBold,
                    TextSize = 10,
                    TextColor3 = T.Text,
                    BorderSizePixel = 0,
                }, row)
                corner(wBtn, 4)

                wBtn.Activated:Connect(function()
                    whitelistPlayers[plr.Name] = not whitelistPlayers[plr.Name]
                    wBtn.BackgroundColor3 = whitelistPlayers[plr.Name] and T.Accent or T.Off
                    notify("Whitelist", plr.Name .. (whitelistPlayers[plr.Name] and " protégé." or " retiré."))
                end)

                local tBtn = new("TextButton", {
                    Size = UDim2.fromOffset(65, 24),
                    Position = UDim2.new(0.70, 0, 0.5, -12),
                    BackgroundColor3 = targetPlayers[plr.Name] and Color3.fromRGB(220, 50, 50) or T.Off,
                    Text = "Target",
                    Font = Enum.Font.GothamBold,
                    TextSize = 10,
                    TextColor3 = T.Text,
                    BorderSizePixel = 0,
                }, row)
                corner(tBtn, 4)

                tBtn.Activated:Connect(function()
                    targetPlayers[plr.Name] = not targetPlayers[plr.Name]
                    tBtn.BackgroundColor3 = targetPlayers[plr.Name] and Color3.fromRGB(220, 50, 50) or T.Off
                    notify("Target", plr.Name .. (targetPlayers[plr.Name] and " ciblé !" or " retiré."))
                end)
            end
        end
    end)
end

connect(Players.PlayerAdded, refreshPlayerListUI)
connect(Players.PlayerRemoving, refreshPlayerListUI)
task.spawn(refreshPlayerListUI)

-- Misc Tab
addSection(miscPage, E.toolbox .. " Utilities")
antiAfkToggle = addToggle(miscPage, E.sleep .. " Anti AFK (IY Method)", false, function(v)
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

autoEggToggle = addToggle(miscPage, E.egg .. " Auto eat protein egg", false, function(v)
    eggRunId = eggRunId + 1
    if v then
        notifyState(E.egg .. " Auto eat protein egg", true)
        task.spawn(autoEggLoop, eggRunId)
    else
        notifyState(E.egg .. " Auto eat protein egg", false)
    end
end)

local fpsLabel = addLabel(miscPage, E.game .. " FPS: --", 34)
addSection(miscPage, E.heart .. " Credits")
addCredit(miscPage, E.sparkles .. " Made by TZ_THR, Have fun " .. E.party)

selectTab(TAB_FAST)

-- ===================== CALCULATEUR ET DÉTECTION ROBUSTE DES STATS =====================
task.spawn(function()
    while alive do
        task.wait(1)
        pcall(function()
            fpsLabel:SetText(E.game .. " FPS: " .. tostring(fpsFrames))
            fpsFrames = 0
            killStatusLabel:SetText(E.clip .. " " .. killStatus)

            -- Calculateur Renaissances (basé sur les renaissances réellement détectées)
            local rbNow = tick()
            if fastStartTime then
                fastTimerLabel:SetText(string.format("%s Session Time: %s | Dernière renaissance : %s",
                    E.clock, formatSeconds(rbNow - fastStartTime), RebirthTracker.lastText()))
                fastCalcLabel:SetText(RebirthTracker.text(E.chart, rbNow))
            else
                fastTimerLabel:SetText(E.clock .. " Session Time: 0s | Dernière renaissance : --")
                fastCalcLabel:SetText(E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
            end

            if autoStartTime then
                autoTimerLabel:SetText(string.format("%s Session Time: %s | Dernière renaissance : %s",
                    E.clock, formatSeconds(rbNow - autoStartTime), RebirthTracker.lastText()))
                autoCalcLabel:SetText(RebirthTracker.text(E.chart, rbNow))
            else
                autoTimerLabel:SetText(E.clock .. " Session Time: 0s | Dernière renaissance : --")
                autoCalcLabel:SetText(E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
            end

            -- Calculateur Force & Durabilité (Actif dès que Fast Strength est enclenché)
            if repStartTime then
                local elapsed = math.max(1, tick() - repStartTime)
                local avgReps = math.floor(repTotal / elapsed)
                repTimerLabel:SetText(string.format("%s Session Time: %s | Moy. Reps/s: %d", E.clock, formatSeconds(elapsed), avgReps))
                
                local now = tick()
                repCalcLabel:SetText(StatTracker.text(E.muscle, "Strength", StatTracker.stats.strength, now, repStartTime))
                durabilityCalcLabel:SetText(StatTracker.text(E.shieldAlt, "Durability", StatTracker.stats.durability, now, repStartTime))
            else
                repTimerLabel:SetText(E.clock .. " Session Time: 0s | Moy. Reps/s: 0")
                repCalcLabel:SetText(E.muscle .. " Strength Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
                durabilityCalcLabel:SetText(E.shieldAlt .. " Durability Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
            end
        end)
    end
end)

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
if not ok then
    warn("[Tazen hub] Error: " .. tostring(err))
end
