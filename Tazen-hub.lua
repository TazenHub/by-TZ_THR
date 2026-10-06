-- luacheck: globals game

if game.PlaceId == 3623096087 then

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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
      FolderName = nil,
      FileName = "Big Hub"
   },
   Discord = { Enabled = false },
   KeySystem = false
})
-- ONGLETS

local MainTab = Window:CreateTab("Fast Rebirth", 4483362458)
MainTab:CreateSection("Fast Rebirth (Pack)")

local RebTab = Window:CreateTab("Auto Rebirth", 4483362458)
RebTab:CreateSection("Auto Rebirth (No Pack)")

-- VARIABLES & FONCTIONS DE SÉCURITÉ

local fastRebirthActive = false
local simpleRebirthActive = false

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function canRebirth()
local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
if not leaderstats then return true end

local strength = leaderstats:FindFirstChild("Strength") or leaderstats:FindFirstChild("Muscle") or leaderstats:FindFirstChild("Multiplier")
if strength and strength.Value then
    return strength.Value > 0
end
return true
end

local repSpeedPetPriorities = {
["Omega Overlord"] = 1,
["Mythic Boss Pet"] = 2,
["Legendary Boss Pet"] = 3,
["Epic Boss Pet"] = 4,
}

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

-- 1. FAST REBIRTH (PACK) SÉCURISÉ

MainTab:CreateToggle({
Name = "Fast rebirth",
CurrentValue = false,
Flag = "Fast Rebirth Flag",
Callback = function(Value)
fastRebirthActive = Value

    if fastRebirthActive then
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
            if not rEvents then return end
            
            local rebirthRemote = rEvents:WaitForChild("rebirthRemote", 5)
            local equipPetEvent = rEvents:WaitForChild("equipPetEvent", 5)
            
            local function unequipAllPets(petsFolder)
                for _, folderName in ipairs({"Unique", "Rare", "Epic", "Mythic", "Legendary"}) do
                    local folder = petsFolder:FindFirstChild(folderName)
                    if folder then
                        for _, pet in ipairs(folder:GetChildren()) do
                            pcall(function()
                                equipPetEvent:FireServer("unequipPet", pet)
                            end)
                            task.wait(0.05)
                        end
                    end
                end
            end

            while fastRebirthActive do
                local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
                
                if petsFolder and canRebirth() then
                    unequipAllPets(petsFolder)
                    
                    for _, folderName in ipairs({"Unique", "Rare", "Epic", "Mythic", "Legendary"}) do
                        local folder = petsFolder:FindFirstChild(folderName)
                        if folder then
                            for _, pet in ipairs(folder:GetChildren()) do
                                local pName = pet.Name
                                if pet:FindFirstChild("PetName") then pName = pet.PetName.Value end
                                
                                if pName == "Titanium Hydra" then
                                    pcall(function()
                                        equipPetEvent:FireServer("equipPet", pet)
                                    end)
                                    task.wait(0.05)
                                end
                            end
                        end
                    end

                    pcall(function()
                        rebirthRemote:InvokeServer("rebirthRequest")
                    end)

                    unequipAllPets(petsFolder)

                    local repPets = {}
                    local uniqueFolder = petsFolder:FindFirstChild("Unique")
                    local priority4Pet = uniqueFolder and uniqueFolder:GetChildren()[4]

                    for _, folderName in ipairs({"Unique", "Rare", "Epic", "Mythic", "Legendary"}) do
                        local folder = petsFolder:FindFirstChild(folderName)
                        if folder then
                            for _, pet in ipairs(folder:GetChildren()) do
                                local pName = pet.Name
                                if pet:FindFirstChild("PetName") then pName = pet.PetName.Value end

                                local priority = repSpeedPetPriorities[pName] or 5
                                if priority4Pet and pet == priority4Pet then
                                    priority = 0
                                end

                                if priority < 5 or priority4Pet == pet then
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
                        if a.Priority == b.Priority then
                            return a.Score > b.Score
                        end
                        return a.Priority < b.Priority
                    end)

                    for _, entry in ipairs(repPets) do
                        pcall(function()
                            equipPetEvent:FireServer("equipPet", entry.Instance)
                        end)
                        task.wait(0.05)
                    end
                end
                
                task.wait(6)
            end
        end)
    end
end,
})

-- 2. AUTO REBIRTH (NO PACK) SÉCURISÉ ANTI-KICK

RebTab:CreateToggle({
Name = "Auto rebirth",
CurrentValue = false,
Flag = "Auto Rebirth Flag",
Callback = function(Value)
simpleRebirthActive = Value

    if simpleRebirthActive then
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local rEvents = ReplicatedStorage:WaitForChild("rEvents", 5)
            local rebirthRemote = rEvents and rEvents:WaitForChild("rebirthRemote", 5)
            
            if not rebirthRemote then return end

            while simpleRebirthActive do
                if canRebirth() then
                    local success = pcall(function()
                        rebirthRemote:InvokeServer("rebirthRequest")
                    end)
                    
                    if success then
                        task.wait(1.2)
                    else
                        task.wait(2)
                    end
                else
                    task.wait(1.5)
                end
            end
        end)
    end
end,
})

end
