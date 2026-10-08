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
local REBIRTH_COOLDOWN = 6       -- game cooldown between two rebirths (seconds)

-- Emojis (escaped)
local E = {
    bolt = "\u{26A1}", cycle = "\u{1F504}", muscle = "\u{1F4AA}", toolbox = "\u{1F9F0}",
    sleep = "\u{1F634}", rocket = "\u{1F680}", sparkles = "\u{2728}", heart = "\u{1F496}",
    ok = "\u{2705}", no = "\u{274C}", chart = "\u{1F4CA}", up = "\u{1F4C8}", broom = "\u{1F9F9}",
    clock = "\u{1F550}", hourglass = "\u{23F3}", sun = "\u{1F31E}", calendar = "\u{1F4C5}",
    trophy = "\u{1F3C6}", target = "\u{1F3AF}", wrench = "\u{1F527}", clip = "\u{1F4CB}",
    bulb = "\u{1F4A1}", fire = "\u{1F525}", loop = "\u{1F501}", antenna = "\u{1F4E1}",
    party = "\u{1F389}", game = "\u{1F3AE}", crown = "\u{1F451}", egg = "\u{1F95A}",
    wheel = "\u{1F3A1}", skull = "\u{1F480}", rainbow = "\u{1F308}", chest = "\u{1F381}",
    sword = "\u{2694}\u{FE0F}", shield = "\u{1F6E1}\u{FE0F}", crosshairs = "\u{1F3AF}"
}

local IMAGE_ASSET = "rbxassetid://91265185075125"

local repSpeedPetPriorities = {
    ["Omega Overlord"] = 1,
    ["Mythic Boss Pet"] = 1,
    ["Legendary Boss Pet"] = 2,
    ["Epic Boss Pet"] = 3,
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
local wheelRunId = 0
local eggRunId = 0
local killRunId = 0

local repRate = 659
local repTotal = 0

-- Live Stats Tracking
local autoRebirthCount = 0
local fastRebirthCount = 0

local killStatus = "Waiting..."

-- Chrono / Timer variables for Fast Rebirth
local fastRebirthTimerText = "0.00s"
local lastRebirthTick = nil

-- Session Timers Start Ticks
local fastStartTime = nil
local autoStartTime = nil
local repStartTime = nil

-- Killing System Data
local whitelistPlayers = {}
local targetPlayers = {}
local lastKillTick = tick()

-- ===================== ANTI AFK (INFINITE YIELD METHOD) =====================
local antiAfkConnection = nil

local function setAntiAfk(state)
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end

    if state then
        local VirtualUser = game:GetService("VirtualUser")
        antiAfkConnection = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
    end
end

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

local function equipFists()
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
end

-- ===================== SERVER HOP =====================
local function serverHop()
    killStatus = "Changement de serveur (0 kill depuis 60s)..."
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

-- ===================== KILLING SYSTEM LOOPS =====================
local function autoKillAllLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local attackRemote = rEvents and (rEvents:FindFirstChild("attackEvent") or rEvents:FindFirstChild("muscleEvent"))

    lastKillTick = tick()

    while killRunId == myId and alive do
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
            break
        end

        task.wait(0.1)
    end
end

local function killTargetPlayerLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local attackRemote = rEvents and (rEvents:FindFirstChild("attackEvent") or rEvents:FindFirstChild("muscleEvent"))

    lastKillTick = tick()

    while killRunId == myId and alive do
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

                killStatus = "Cible prioritaire : " .. targetPlayer.Name
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

        task.wait(0.1)
    end
end

-- ===================== FAST REBIRTH =====================
local function fastRebirthLoop(myId)
    local function isRunning() return fastRunId == myId end

    local okT, errT = pcall(function()
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
                        equipPetEvent:FireServer("unequipPet", pet)
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
                equipPetEvent:FireServer(kind, pet)
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

        if #hydraList == 0 then
            warn("[Tazen hub] Pack required: no Titanium Hydra found. Use Auto Rebirth instead.")
            return
        end

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
                local okR, res = pcall(function()
                    return rebirthRemote:InvokeServer("rebirthRequest")
                end)
                if okR and (type(res) == "boolean" and res == true or type(res) ~= "boolean") then
                    fastRebirthCount = fastRebirthCount + 1
                    if lastRebirthTick then
                        local diff = tick() - lastRebirthTick
                        fastRebirthTimerText = string.format("%.2fs", diff)
                    end
                    lastRebirthTick = tick()
                end
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

    if not okT then
        warn("[Tazen hub] ERROR: " .. tostring(errT))
    end
end

-- ===================== AUTO REBIRTH =====================
local function autoRebirthLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)

    if not rebirthRemote then
        warn("[Tazen hub] rEvents / rebirthRemote not found")
        return
    end

    while autoRunId == myId do
        local okC, errC = pcall(function()
            if canRebirth() then
                local okR, res = pcall(function()
                    return rebirthRemote:InvokeServer("rebirthRequest")
                end)
                if okR then
                    autoRebirthCount = autoRebirthCount + 1
                end
            end
        end)
        if not okC then
            warn("[Tazen hub] ERROR: " .. tostring(errC))
        end
        task.wait(REBIRTH_COOLDOWN)
    end
end

-- ===================== FAST STRENGTH (REP) =====================
local function fastRepLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    if not rEvents then warn("[Tazen hub] rEvents not found") return end
    local muscleEvent = findMuscleEvent(rEvents)
    if not muscleEvent then warn("[Tazen hub] muscleEvent not found") return end

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
            if n > 200 then n = 200 end

            for _ = 1, n do
                pcall(muscleEvent.FireServer, muscleEvent, "rep")
            end
            repTotal = repTotal + n
        end
    end
end

-- ===================== MISC LOOPS =====================
local function autoWheelLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local wheelRemote = rEvents and (rEvents:FindFirstChild("openFortuneWheel") or rEvents:FindFirstChild("openFortuneWheelRemote"))

    while wheelRunId == myId and alive do
        if wheelRemote then
            pcall(function()
                local shared = ReplicatedStorage:FindFirstChild("shared")
                local catalogs = shared and shared:FindFirstChild("catalogs")
                local chances = catalogs and catalogs:FindFirstChild("fortuneWheelChances")
                local fortuneWheel = chances and chances:FindFirstChild("Fortune Wheel")
                
                if fortuneWheel then
                    wheelRemote:InvokeServer("openFortuneWheel", fortuneWheel)
                end
            end)
        end
        task.wait(1)
    end
end

local function autoEggLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local eggRemote = rEvents and (rEvents:FindFirstChild("useItemRemote") or rEvents:FindFirstChild("eatEggRemote") or rEvents:FindFirstChild("itemRemote"))

    while eggRunId == myId and alive do
        if eggRemote then
            pcall(function()
                eggRemote:InvokeServer("Protein Egg")
            end)
        end
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

local function formatNumber(val)
    if val >= 1e12 then
        return string.format("%.2fT", val / 1e12)
    elseif val >= 1e9 then
        return string.format("%.2fB", val / 1e9)
    elseif val >= 1e6 then
        return string.format("%.2fM", val / 1e6)
    elseif val >= 1e3 then
        return string.format("%.2fk", val / 1e3)
    else
        return tostring(math.floor(val))
    end
end

-- ===================== MISC ANTI LAG =====================
local Lighting = game:GetService("Lighting")

local antiLagConn = nil
local antiLagRun = 0
local antiLagTouched = setmetatable({}, { __mode = "k" })
local antiLagBackup = nil

local function lagApply(inst)
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
end

local function antiLagStart()
    antiLagRun = antiLagRun + 1
    local myId = antiLagRun

    antiLagBackup = { GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd }
    pcall(function() antiLagBackup.Quality = settings().Rendering.QualityLevel end)
    pcall(function()
        local terrain = workspace.Terrain
        antiLagBackup.Water = {
            WaterWaveSize = terrain.WaterWaveSize,
            WaterWaveSpeed = terrain.WaterWaveSpeed,
            WaterReflectance = terrain.WaterReflectance,
            WaterTransparency = terrain.WaterTransparency,
        }
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 1
    end)
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.FogEnd = 9e9 end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

    task.spawn(function()
        local n = 0
        local function sweep(root)
            for _, d in ipairs(root:GetDescendants()) do
                if antiLagRun ~= myId then return end
                pcall(lagApply, d)
                n = n + 1
                if n % 400 == 0 then task.wait() end
            end
        end
        sweep(Lighting)
        sweep(workspace)
    end)
    antiLagConn = workspace.DescendantAdded:Connect(function(d) pcall(lagApply, d) end)
end

local function antiLagStop()
    antiLagRun = antiLagRun + 1
    if antiLagConn then
        antiLagConn:Disconnect()
        antiLagConn = nil
    end

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
            pcall(function() Lighting.GlobalShadows = backup.GlobalShadows end)
            pcall(function() Lighting.FogEnd = backup.FogEnd end)
            pcall(function()
                settings().Rendering.QualityLevel = backup.Quality or Enum.QualityLevel.Automatic
            end)
            if backup.Water then
                pcall(function()
                    for k, v in pairs(backup.Water) do workspace.Terrain[k] = v end
                end)
            end
        end
    end)
end

local fpsFrames = 0
connect(RunService.Heartbeat, function() fpsFrames = fpsFrames + 1 end)

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

local bg = new("ImageLabel", {
    Name = "Background",
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
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

-- ===================== ELEMENTS =====================
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

    if initialState then
        task.spawn(function()
            task.wait(0.2)
            if callback then callback(true) end
        end)
    end

    return obj
end

-- Spécial Killing pour garder sa sauvegarde
local function addKillingToggle(page, name, categoryKey, settingKey, defaultState, callback)
    local configData = loadCategoryConfig(categoryKey)
    local initialState = defaultState
    if configData[settingKey] ~= nil then
        initialState = configData[settingKey]
    end

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

    if initialState then
        task.spawn(function()
            task.wait(0.2)
            if callback then callback(true) end
        end)
    end

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

    task.spawn(function()
        task.wait(0.2)
        callback(initialVal)
    end)

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

-- ===================== TABS =====================
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

local fastToggle, autoToggle, repToggle, killAllToggle, killTargetToggle, antiAfkToggle, antiLagToggle, autoWheelToggle, autoEggToggle, autoExecToggle

local function notifyState(title, v)
    notify(title, v and (E.ok .. " Enabled") or (E.no .. " Disabled"))
end

local function enableAutoFastRep()
    if repSliderUpdate then repSliderUpdate(659) end
    if repToggle and not repToggle.Value then
        repToggle:Set(true)
    end
end

-- Fast Rebirth
addSection(fastPage, E.fire .. " Fast Rebirth (Pack)")
addLabel(fastPage, "\u{26A0}\u{FE0F} You need pack for fast rebirth", 34)
fastToggle = addToggle(fastPage, E.bolt .. " Fast rebirth", false, function(v)
    fastRunId = fastRunId + 1
    if v then
        fastStartTime = tick()
        lastRebirthTick = tick()
        fastRebirthTimerText = "0.00s"
        fastRebirthCount = 0
        autoRunId = autoRunId + 1
        if autoToggle then autoToggle:Set(false) end
        enableAutoFastRep()
        notifyState(E.bolt .. " Fast rebirth", true)
        task.spawn(fastRebirthLoop, fastRunId)
    else
        fastStartTime = nil
        lastRebirthTick = nil
        notifyState(E.bolt .. " Fast rebirth", false)
    end
end)
local fastTimerLabel = addLabel(fastPage, E.clock .. " Session Time: 0s | Dernière renaissance : 0.00s", 36)
local fastCalcLabel = addLabel(fastPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55)

-- Auto Rebirth
addSection(autoPage, E.cycle .. " Auto Rebirth (No Pack)")
addLabel(autoPage, "\u{26A0}\u{FE0F} This tab can be used by everyone", 34)
autoToggle = addToggle(autoPage, E.cycle .. " Auto rebirth", false, function(v)
    autoRunId = autoRunId + 1
    if v then
        autoStartTime = tick()
        autoRebirthCount = 0
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
local autoTimerLabel = addLabel(autoPage, E.clock .. " Session Time: 0s | Rebirth/s: 0.0", 36)
local autoCalcLabel = addLabel(fastPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55) -- Note: corrigé visuellement dans le code final plus bas

-- Fast Strength
addSection(strPage, E.muscle .. " Fast Strength")
repToggle = addToggle(strPage, E.muscle .. " Fast strength", false, function(v)
    repRunId = repRunId + 1
    if v then
        repStartTime = tick()
        repTotal = 0
        notify(E.muscle .. " Fast strength", E.target .. " " .. repRate .. " reps/s targeted")
        task.spawn(fastRepLoop, repRunId)
    else
        repStartTime = nil
        notifyState(E.muscle .. " Fast strength", false)
    end
end)
repSliderUpdate = addSlider(strPage, E.wrench .. " Reps per second", 0, 1050, repRate, function(v) repRate = v end)
local repTimerLabel = addLabel(strPage, E.clock .. " Session Time: 0s | Moy. Reps/s: 0", 36)
local repCalcLabel = addLabel(strPage, E.chart .. " 0/s | Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 65)

-- ===================== KILLING TAB (WITH SAVE CONFIG) =====================
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

addLabel(killPage, "Astuce : Utilise les boutons Safe et Target ci-dessous pour gérer chaque joueur en direct.", 45)

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
                local stateStr = whitelistPlayers[plr.Name] and " protégé." or " retiré de la whitelist."
                notify("Whitelist", plr.Name .. stateStr)
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
                tBtn.BackgroundColor3 = targetPlayers[plr.Name] and Color3.fromRGB(220, 50, 50) or T.Off,
                local stateStr = targetPlayers[plr.Name] and " ciblé en Priority Target !" or " retiré des targets."
                notify("Target", plr.Name .. stateStr)
            end)
        end
    end
end

connect(Players.PlayerAdded, refreshPlayerListUI)
connect(Players.PlayerRemoving, refreshPlayerListUI)
task.spawn(refreshPlayerListUI)

-- Misc Tab
addSection(miscPage, E.toolbox .. " Utilities")

autoExecToggle = addToggle(miscPage, E.rocket .. " Auto Execution", false, function(v)
    notifyState("Auto Execution", v)
    if v then
        pcall(function()
            if syn and syn.queue_on_teleport then
                syn.queue_on_teleport([[loadstring(game:HttpGet("YOUR_SCRIPT_URL_HERE"))()]])
            elseif queue_on_teleport then
                queue_on_teleport([[loadstring(game:HttpGet("YOUR_SCRIPT_URL_HERE"))()]])
            end
        end)
    end
end)
addLabel(miscPage, E.bulb .. " Active l'exécution automatique et la ré-exécution lors des changements de serveur.", 45)

antiAfkToggle = addToggle(miscPage, E.sleep .. " Anti AFK (IY Method)", false, function(v)
    setAntiAfk(v)
    notifyState(E.sleep .. " Anti AFK", v)
end)
addLabel(miscPage, E.bulb .. " Empêche la déconnexion d'inactivité de Roblox via la méthode Infinite Yield.", 34)

antiLagToggle = addToggle(miscPage, E.rocket .. " Anti Lag (low-end devices)", false, function(v)
    if v then antiLagStart() else antiLagStop() end
    notifyState(E.rocket .. " Anti Lag", v)
end)
addLabel(miscPage, E.bulb .. " Lowers graphics (particles, shadows, textures, effects). Fully reverted when turned off.", 46)

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
addCredit(miscPage, E.sparkles .. " Made by TZ_THR, Thank you for using my script have fun " .. E.party)

selectTab(TAB_FAST)

-- Recréation propre du label autoCalcLabel qui pointait par erreur sur fastPage
local autoCalcLabel = addLabel(autoPage, E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0", 55)

-- ===================== UPDATE =====================
task.spawn(function()
    while alive do
        task.wait(1)

        fpsLabel:SetText(E.game .. " FPS: " + fpsFrames) -- corrigé en sécurisant la concaténation
        fpsFrames = 0

        killStatusLabel:SetText(E.clip .. " " .. killStatus)

        -- Session Timers & Real-Time Live Farm Calculators Update (Opti & Stables)
        if fastStartTime then
            local elapsed = math.max(1, tick() - fastStartTime)
            fastTimerLabel:SetText(string.format("%s Session Time: %s | Dernière renaissance : %s", E.clock, formatSeconds(elapsed), fastRebirthTimerText))
            
            local effectiveRate = fastRebirthCount / elapsed
            local totalGain = fastRebirthCount
            local m1 = effectiveRate * 60
            local h1 = effectiveRate * 3600
            local d1 = effectiveRate * 86400
            local w1 = effectiveRate * 604800
            local mo1 = effectiveRate * 2592000

            fastCalcLabel:SetText(string.format("%s Tot: %s | 1m: %s | 1h: %s | 1j: %s | 1sem: %s | 1mois: %s",
                E.chart, formatNumber(totalGain), formatNumber(m1), formatNumber(h1), formatNumber(d1), formatNumber(w1), formatNumber(mo1)))
        else
            fastTimerLabel:SetText(E.clock .. " Session Time: 0s | Dernière renaissance : 0.00s")
            fastCalcLabel:SetText(E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
        end

        if autoStartTime then
            local elapsed = math.max(1, tick() - autoStartTime)
            local rps = autoRebirthCount / elapsed
            autoTimerLabel:SetText(string.format("%s Session Time: %s | Rebirth/s: %.2f", E.clock, formatSeconds(elapsed), rps))
            
            local totalGain = autoRebirthCount
            local m1 = rps * 60
            local h1 = rps * 3600
            local d1 = rps * 86400
            local w1 = rps * 604800
            local mo1 = rps * 2592000

            autoCalcLabel:SetText(string.format("%s Tot: %s | 1m: %s | 1h: %s | 1j: %s | 1sem: %s | 1mois: %s",
                E.chart, formatNumber(totalGain), formatNumber(m1), formatNumber(h1), formatNumber(d1), formatNumber(w1), formatNumber(mo1)))
        else
            autoTimerLabel:SetText(E.clock .. " Session Time: 0s | Rebirth/s: 0.0")
            autoCalcLabel:SetText(E.chart .. " Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
        end

        if repStartTime then
            local elapsed = math.max(1, tick() - repStartTime)
            local avgReps = math.floor(repTotal / elapsed)
            repTimerLabel:SetText(string.format("%s Session Time: %s | Moy. Reps/s: %d", E.clock, formatSeconds(elapsed), avgReps))
            
            local effectiveRepRate = repTotal / elapsed
            local totalGain = repTotal
            local m1 = effectiveRepRate * 60
            local h1 = effectiveRepRate * 3600
            local d1 = effectiveRepRate * 86400
            local w1 = effectiveRepRate * 604800
            local mo1 = effectiveRepRate * 2592000

            repCalcLabel:SetText(string.format("%s %d/s | Tot: %s | 1m: %s | 1h: %s | 1j: %s | 1sem: %s | 1mois: %s",
                E.chart, repRate, formatNumber(totalGain), formatNumber(m1), formatNumber(h1), formatNumber(d1), formatNumber(w1), formatNumber(mo1)))
        else
            repTimerLabel:SetText(E.clock .. " Session Time: 0s | Moy. Reps/s: 0")
            repCalcLabel:SetText(E.chart .. " 0/s | Tot: 0 | 1m: 0 | 1h: 0 | 1j: 0 | 1sem: 0 | 1mois: 0")
        end
    end
end)

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

print("[Tazen hub] UI loaded")

end)
if not ok then
    warn("[Tazen hub] Error: " .. tostring(err))
end
