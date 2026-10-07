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

-- Emojis (escaped)
local E = {
    bolt = "\u{26A1}", cycle = "\u{1F504}", muscle = "\u{1F4AA}", toolbox = "\u{1F9F0}",
    sleep = "\u{1F634}", rocket = "\u{1F680}", sparkles = "\u{2728}", heart = "\u{1F496}",
    ok = "\u{2705}", no = "\u{274C}", chart = "\u{1F4CA}", up = "\u{1F4C8}", broom = "\u{1F9F9}",
    clock = "\u{1F550}", hourglass = "\u{23F3}", sun = "\u{1F31E}", calendar = "\u{1F4C5}",
    trophy = "\u{1F3C6}", target = "\u{1F3AF}", wrench = "\u{1F527}", clip = "\u{1F4CB}",
    bulb = "\u{1F4A1}", fire = "\u{1F525}", loop = "\u{1F501}", antenna = "\u{1F4E1}",
    party = "\u{1F389}", game = "\u{1F3AE}", crown = "\u{1F451}", egg = "\u{1F95A}",
    wheel = "\u{1F3A1}", skull = "\u{1F480}", rainbow = "\u{1F308}", chest = "\u{1F381}"
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
local bossRunId = 0

local repRate = 659          
local repCounter = 0         
local repTotal = 0           
local fastStatus = "Waiting..."
local autoStatus = "Waiting..."
local bossStatus = "Waiting..."

local bossKills = {
    Common = 0,
    Rare = 0,
    Epic = 0,
    Legendary = 0,
    Mythic = 0,
    Rainbow = 0,
    Total = 0
}

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

local function getBossRarity(boss)
    local name = boss.Name:lower()
    local rarityAttr = boss:GetAttribute("Rarity") or boss:GetAttribute("Type")
    if rarityAttr then
        local r = tostring(rarityAttr):lower()
        if r:find("rainbow") or r:find("arc") then return "Rainbow" end
        if r:find("mythic") or r:find("mythique") then return "Mythic" end
        if r:find("legendary") or r:find("légendaire") or r:find("legendaire") then return "Legendary" end
        if r:find("epic") or r:find("épique") or r:find("epique") then return "Epic" end
        if r:find("rare") then return "Rare" end
        if r:find("common") or r:find("commun") then return "Common" end
    end

    if name:find("rainbow") or name:find("arc") then return "Rainbow" end
    if name:find("mythic") or name:find("mythique") then return "Mythic" end
    if name:find("legendary") or name:find("légendaire") or name:find("legendaire") then return "Legendary" end
    if name:find("epic") or name:find("épique") or name:find("epique") then return "Epic" end
    if name:find("rare") then return "Rare" end
    return "Common"
end

-- Équiper uniquement le poing (Fight/Punch)
local function equipFists()
    local char = LocalPlayer.Character
    if not char then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name ~= "Fight" and tool.Name ~= "Punch" then
            tool.Parent = backpack
        end
    end

    local punchTool = char:FindFirstChild("Fight") or char:FindFirstChild("Punch")
    if not punchTool and backpack then
        punchTool = backpack:FindFirstChild("Fight") or backpack:FindFirstChild("Punch") or backpack:FindFirstChildOfClass("Tool")
        if punchTool then
            punchTool.Parent = char
        end
    end
end

-- Équiper uniquement le poids (Weight)
local function equipWeight()
    local char = LocalPlayer.Character
    if not char then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name ~= "Weight" then
            tool.Parent = backpack
        end
    end

    local weightTool = char:FindFirstChild("Weight")
    if not weightTool and backpack then
        weightTool = backpack:FindFirstChild("Weight") or backpack:FindFirstChildOfClass("Tool")
        if weightTool then
            weightTool.Parent = char
        end
    end
end

-- Claim le coffre spécifique du Boss
local function claimBossChest()
    local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
    local chestRemote = rEvents and (rEvents:FindFirstChild("checkChestRemote") or rEvents:FindFirstChild("collectChestRemote") or rEvents:FindFirstChild("openChestRemote") or rEvents:FindFirstChild("chestRemote"))
    
    pcall(function()
        if chestRemote then
            chestRemote:InvokeServer("collectBossChest")
            chestRemote:FireServer("collectBossChest")
            chestRemote:InvokeServer("collectChest", "Boss Chest")
            chestRemote:FireServer("collectChest", "Boss Chest")
        end
    end)
end

-- ===================== AUTO FARM BOSS + AUTO WEIGHT =====================
local function autoFarmBossLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local attackRemote = rEvents and (rEvents:FindFirstChild("attackEvent") or rEvents:FindFirstChild("muscleEvent"))
    local muscleEvent = findMuscleEvent(rEvents)

    while bossRunId == myId and alive do
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")

        if not hrp then
            bossStatus = "En attente du personnage..."
            task.wait(1)
        else
            local bossesFolder = workspace:FindFirstChild("Bosses") or workspace:FindFirstChild("NPCs") or workspace:FindFirstChild("Monsters")
            local targetBoss = nil
            local minDistance = math.huge

            if bossesFolder then
                for _, npc in ipairs(bossesFolder:GetChildren()) do
                    local head = npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart")
                    local hum = npc:FindFirstChildOfClass("Humanoid")
                    if head and hum and hum.Health > 0 then
                        local dist = (hrp.Position - head.Position).Magnitude
                        if dist < minDistance then
                            minDistance = dist
                            targetBoss = npc
                        end
                    end
                end
            end

            if targetBoss then
                local hum = targetBoss:FindFirstChildOfClass("Humanoid")
                local targetHrp = targetBoss:FindFirstChild("HumanoidRootPart") or targetBoss:FindFirstChild("Head")
                local rarity = getBossRarity(targetBoss)
                bossStatus = string.format("Attaque (Poings): %s [%s]", targetBoss.Name, rarity)

                equipFists()

                local deathConn
                deathConn = hum.Died:Connect(function()
                    bossKills[rarity] = bossKills[rarity] + 1
                    bossKills.Total = bossKills.Total + 1
                    if deathConn then deathConn:Disconnect() end
                    
                    claimBossChest()
                end)

                while bossRunId == myId and alive and hum and hum.Health > 0 do
                    equipFists()
                    if hrp and targetHrp then
                        hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 4, 2)
                    end
                    if attackRemote then
                        pcall(function() attackRemote:FireServer("punch", targetBoss) end)
                    end
                    task.wait(0.1)
                end

                if deathConn then deathConn:Disconnect() end
                claimBossChest()
            else
                bossStatus = "Boss vaincu / Repos -> Farm au Weight"
                equipWeight()
                if muscleEvent then
                    pcall(muscleEvent.FireServer, muscleEvent, "rep")
                end
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
            fastStatus = "petsFolder not found"
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
            fastStatus = "Pack required: no Titanium Hydra found. Use Auto Rebirth instead."
            warn("[Tazen hub] " .. fastStatus)
            return
        end

        fastStatus = "Starting: cleaning pets..."
        unequipAllPets(petsFolder)
        if not isRunning() then return end
        setEquipped(repTarget, true)

        local cycle = 0
        local rebirthResult = "-"
        local prevFire = nil
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
                rebirthResult = okR and res or ("error: " .. tostring(res))
            end)

            waitUntil(tFire + HYDRA_TAIL)
            setEquipped(offList, true)
            waitUntil(tFire + REP_ON_DELAY)
            setEquipped(repTarget, true)

            local interval = prevFire and (tFire - prevFire) or 0
            prevFire = tFire
            fastStatus = string.format("Cycle %d | Rebirth: %s | Slots %d | Rep %d | Hydras %d | %.2fs",
                cycle, tostring(rebirthResult), slots, #repTarget, #hydraList, interval)

            if cycle % LIST_REFRESH_EVERY == 0 then
                petsFolder = LocalPlayer:FindFirstChild("petsFolder") or petsFolder
                rebuild()
            end

            rebirthAt = tFire + REBIRTH_COOLDOWN + REBIRTH_MARGIN
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

    if not rebirthRemote then
        autoStatus = "rEvents / rebirthRemote not found"
        warn("[Tazen hub] " .. autoStatus)
        return
    end

    local tries = 0
    while autoRunId == myId do
        local okC, errC = pcall(function()
            if canRebirth() then
                tries = tries + 1
                local okR, res = pcall(function()
                    return rebirthRemote:InvokeServer("rebirthRequest")
                end)
                autoStatus = string.format("Attempts: %d | last result: %s",
                    tries, okR and tostring(res) or ("error: " .. tostring(res)))
            else
                autoStatus = "canRebirth = false"
            end
        end)
        if not okC then
            autoStatus = "ERROR: " .. tostring(errC)
            warn("[Tazen hub] " .. autoStatus)
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

-- ===================== MISC LOOPS =====================
local function autoWheelLoop(myId)
    local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
    local wheelRemote = rEvents and rEvents:FindFirstChild("openFortuneWheelRemote")
    
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

-- ===================== CALCULATOR =====================
local tracker = { strGain = 0, rebGain = 0 }
local samples = {}
local WINDOW = 20

local function bindStat(statName, altName, key)
    task.spawn(function()
        local ls = LocalPlayer:WaitForChild("leaderstats", 10)
        if not ls then warn("[Tazen hub] leaderstats not found") return end
        local stat = ls:WaitForChild(statName, 10) or (altName and ls:FindFirstChild(altName))
        if not stat then warn("[Tazen hub] stat not found: " .. statName) return end
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
local H = math.min(360, vp.Y - 30)

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
new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, tabBar)

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
    local tabW = math.floor((W - 16 - 4 * 4) / 5)
    local button = new("TextButton", {
        Size = UDim2.fromOffset(tabW, 28),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.25,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextScaled = true,
        TextColor3 = T.Text,
        TextStrokeTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = tabCount,
    }, tabBar)
    corner(button, 8)
    new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 7 }, button)

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
end

local repSliderUpdate = nil

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

local function addStatBlock(page, title, rowNames)
    local h = 30 + #rowNames * 22 + 6
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, h),
        BackgroundColor3 = T.Element,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, T.Stroke, 1)
    textLabel({
        Size = UDim2.new(1, -20, 0, 24),
        Position = UDim2.new(0, 12, 0, 4),
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.Accent,
    }, f)

    local values = {}
    for i, name in ipairs(rowNames) do
        local y = 28 + (i - 1) * 22
        textLabel({
            Size = UDim2.new(0.5, -12, 0, 20),
            Position = UDim2.new(0, 12, 0, y),
            Text = name,
            TextSize = 13,
            TextColor3 = T.SubText,
        }, f)
        values[i] = textLabel({
            Size = UDim2.new(0.5, -12, 0, 20),
            Position = UDim2.new(0.5, 0, 0, y),
            Text = "0",
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Right,
        }, f)
    end

    return {
        Set = function(_, list)
            for i, v in ipairs(list) do
                if values[i] then values[i].Text = tostring(v) end
            end
        end,
    }
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
local TAB_FAST = E.bolt .. " Fast Reb"
local TAB_AUTO = E.cycle .. " Auto Reb"
local TAB_STR = E.muscle .. " Strength"
local TAB_BOSS = E.skull .. " Boss"
local TAB_MISC = E.toolbox .. " Misc"

local fastPage = createTab(TAB_FAST)
local autoPage = createTab(TAB_AUTO)
local strPage = createTab(TAB_STR)
local bossPage = createTab(TAB_BOSS)
local miscPage = createTab(TAB_MISC)

local fastToggle, autoToggle, repToggle, bossToggle, antiAfkToggle, antiLagToggle, autoWheelToggle, autoEggToggle

local function notifyState(title, v)
    notify(title, v and (E.ok .. " Enabled") or (E.no .. " Disabled"))
end

local function resetStats()
    tracker.strGain = 0
    tracker.rebGain = 0
    samples = {}
    notify(E.broom .. " Calculator", E.ok .. " Stats reset")
end

local function resetBossStats()
    bossKills.Common = 0
    bossKills.Rare = 0
    bossKills.Epic = 0
    bossKills.Legendary = 0
    bossKills.Mythic = 0
    bossKills.Rainbow = 0
    bossKills.Total = 0
    notify(E.broom .. " Boss Counter", E.ok .. " Compteur réinitialisé")
end

local function enableAutoFastRep()
    if repSliderUpdate then repSliderUpdate(659) end
    if repToggle and not repToggle.Value then
        repToggle:Set(true)
    end
end

local REB_ROWS = {
    E.bolt .. " Per second", E.clock .. " Per minute", E.hourglass .. " Per hour",
    E.sun .. " Per day", E.calendar .. " Per week", E.trophy .. " Total gained",
}
local STR_ROWS = {
    E.bolt .. " Per second", E.clock .. " Per minute", E.hourglass .. " Per hour",
    E.sun .. " Per day", E.calendar .. " Per week", E.trophy .. " Total gained",
    E.target .. " Strength per rep (avg)",
}
local BOSS_ROWS = {
    "⚪ Commun", "🔵 Rare", "🟣 Épique", "🟡 Légendaire", "🔴 Mythique", E.rainbow .. " Arc-en-ciel", E.trophy .. " Total Tués"
}

-- Fast Rebirth
addSection(fastPage, E.fire .. " Fast Rebirth (Pack)")
addLabel(fastPage, "\u{26A0}\u{FE0F} You need pack for fast rebirth", 34)
addLabel(fastPage, "\u{26A0}\u{FE0F} Use a 659 rep speed for no delay", 34)
fastToggle = addToggle(fastPage, E.bolt .. " Fast rebirth", function(v)
    fastRunId = fastRunId + 1
    if v then
        autoRunId = autoRunId + 1
        if autoToggle then autoToggle:Set(false) end
        enableAutoFastRep()
        fastStatus = "Starting..."
        notifyState(E.bolt .. " Fast rebirth", true)
        task.spawn(fastRebirthLoop, fastRunId)
    else
        notifyState(E.bolt .. " Fast rebirth", false)
    end
end)
local fastStatusLabel = addLabel(fastPage, E.clip .. " " .. fastStatus, 60)
addSection(fastPage, E.chart .. " Rebirth calculator")
local fastRebBlock = addStatBlock(fastPage, E.loop .. " REBIRTHS (measured over 20 s)", REB_ROWS)
addButton(fastPage, E.broom .. " Reset stats", resetStats)

-- Auto Rebirth
addSection(autoPage, E.cycle .. " Auto Rebirth (No Pack)")
addLabel(autoPage, "\u{26A0}\u{FE0F} This tab can be used by everyone", 34)
addLabel(autoPage, "\u{26A0}\u{FE0F} Use a 659 rep speed for no delay", 34)
autoToggle = addToggle(autoPage, E.cycle .. " Auto rebirth", function(v)
    autoRunId = autoRunId + 1
    if v then
        fastRunId = fastRunId + 1
        if fastToggle then fastToggle:Set(false) end
        enableAutoFastRep()
        autoStatus = "Starting..."
        notifyState(E.cycle .. " Auto rebirth", true)
        task.spawn(autoRebirthLoop, autoRunId)
    else
        notifyState(E.cycle .. " Auto rebirth", false)
    end
end)
local autoStatusLabel = addLabel(autoPage, E.clip .. " " .. autoStatus, 40)
addSection(autoPage, E.chart .. " Rebirth calculator")
local autoRebBlock = addStatBlock(autoPage, E.loop .. " REBIRTHS (measured over 20 s)", REB_ROWS)
addButton(autoPage, E.broom .. " Reset stats", resetStats)

-- Fast Strength
addSection(strPage, E.muscle .. " Fast Strength")
repToggle = addToggle(strPage, E.muscle .. " Fast strength", function(v)
    repRunId = repRunId + 1
    if v then
        notify(E.muscle .. " Fast strength", E.target .. " " .. repRate .. " reps/s targeted")
        task.spawn(fastRepLoop, repRunId)
    else
        notifyState(E.muscle .. " Fast strength", false)
    end
end)
repSliderUpdate = addSlider(strPage, E.wrench .. " Reps per second", 659, 3000, repRate, function(v) repRate = v end)
local repLabel = addLabel(strPage, E.antenna .. " Real reps/s: --", 34)
addSection(strPage, E.up .. " Strength calculator")
local strBlock = addStatBlock(strPage, E.muscle .. " STRENGTH (measured over 20 s)", STR_ROWS)
addButton(strPage, E.broom .. " Reset stats", resetStats)

-- Boss Tab (Auto Farm Boss + Claim Coffre Boss exclusif)
addSection(bossPage, E.skull .. " Auto Farm Boss & Claim Boss Chest")
bossToggle = addToggle(bossPage, E.target .. " Activer Auto Boss + Weight", function(v)
    bossRunId = bossRunId + 1
    if v then
        notifyState(E.target .. " Auto Farm Boss", true)
        task.spawn(autoFarmBossLoop, bossRunId)
    else
        notifyState(E.target .. " Auto Farm Boss", false)
    end
end)
local bossStatusLabel = addLabel(bossPage, E.clip .. " " .. bossStatus, 40)

addSection(bossPage, E.chart .. " Compteur de Boss Tués")
local bossBlock = addStatBlock(bossPage, E.skull .. " BOSS KILLS", BOSS_ROWS)
addButton(bossPage, E.broom .. " Réinitialiser compteur boss", resetBossStats)

-- Misc Tab
addSection(miscPage, E.toolbox .. " Utilities")
antiAfkToggle = addToggle(miscPage, E.sleep .. " Anti AFK (IY Method)", function(v)
    setAntiAfk(v)
    notifyState(E.sleep .. " Anti AFK", v)
end)
addLabel(miscPage, E.bulb .. " Empêche la déconnexion d'inactivité de Roblox via la méthode Infinite Yield.", 34)

antiLagToggle = addToggle(miscPage, E.rocket .. " Anti Lag (low-end devices)", function(v)
    if v then antiLagStart() else antiLagStop() end
    notifyState(E.rocket .. " Anti Lag", v)
end)
addLabel(miscPage, E.bulb .. " Lowers graphics (particles, shadows, textures, effects). Fully reverted when turned off.", 46)

autoWheelToggle = addToggle(miscPage, E.wheel .. " Auto Wheel", function(v)
    wheelRunId = wheelRunId + 1
    if v then
        notifyState(E.wheel .. " Auto Wheel", true)
        task.spawn(autoWheelLoop, wheelRunId)
    else
        notifyState(E.wheel .. " Auto Wheel", false)
    end
end)

autoEggToggle = addToggle(miscPage, E.egg .. " Auto eat protein egg", function(v)
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

-- ===================== UPDATE =====================
task.spawn(function()
    while alive do
        task.wait(1)

        repLabel:SetText(E.antenna .. (repToggle.Value and (" Real reps/s: " .. repCounter) or " Real reps/s: --"))
        repCounter = 0

        fpsLabel:SetText(E.game .. " FPS: " .. fpsFrames)
        fpsFrames = 0

        fastStatusLabel:SetText(E.clip .. " " .. fastStatus)
        autoStatusLabel:SetText(E.clip .. " " .. autoStatus)
        bossStatusLabel:SetText(E.clip .. " " .. bossStatus)

        bossBlock:Set({
            bossKills.Common,
            bossKills.Rare,
            bossKills.Epic,
            bossKills.Legendary,
            bossKills.Mythic,
            bossKills.Rainbow,
            bossKills.Total
        })

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
            autoRebBlock:Set(rList)
        else
            strBlock:Set({ "measuring...", "measuring...", "measuring...", "measuring...", "measuring...", fmt(tracker.strGain), "--" })
            local pending = { "measuring...", "measuring...", "measuring...", "measuring...", "measuring...", fmt(tracker.rebGain) }
            fastRebBlock:Set(pending)
            autoRebBlock:Set(pending)
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
    bossRunId = bossRunId + 1
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
