-- luacheck: globals game

if game.PlaceId == 3623096087 then

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Tazen hub V1 by TZN_THR",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "Welcome to Tazen hub",
   LoadingSubtitle = "by TZN_THR",
   ShowText = "Rayfield", -- for mobile users to unhide Rayfield, change if you'd like
   Theme = "Amethyst", -- Check https://docs.sirius.menu/rayfield/configuration/themes

   ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false, -- Prevents Rayfield from emitting warnings when the script has a version mismatch with the interface.

   -- Heartbeat = "https://www.sentivel.com/api/heartbeat/<your token>", -- Pings your Sentivel heartbeat while Rayfield is open, so you can see whether your script is running

   -- ScriptID = "sid_xxxxxxxxxxxx", -- Your Script ID from developer.sirius.menu — enables analytics, managed keys, and script hosting

   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "Big Hub"
   },

   Discord = {
      Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "noinvitelink", -- The Discord invite code, do not include Discord.gg/. E.g. Discord.gg/ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the Discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique, as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"Hello"} -- List of keys that the system will accept, can be RAW file links (pastebin, github, etc.) or simple strings ("hello", "key22")
   }
})

local MainTab = Window:CreateTab("Fast Rebirth", nil) -- Title, Image
    local MainSection = MainTab:CreateSection("Fast Rebirth (Pack)")

local autoRebirthActive = false

-- Priorités des pets Rep Speed (0 = Priorité absolue, 5 = Dernier recours)
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

local Toggle = MainTab:CreateToggle({
    Name = "Auto rebirth",
    CurrentValue = false,
    Flag = "Auto Rebirth",
    Callback = function(Value)
        autoRebirthActive = Value
        
        if autoRebirthActive then
            task.spawn(function()
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local Players = game:GetService("Players")
                local LocalPlayer = Players.LocalPlayer
                
                local rebirthRemote = ReplicatedStorage.rEvents.rebirthRemote
                local equipPetEvent = ReplicatedStorage.rEvents.equipPetEvent
                
                local function unequipAllPets(petsFolder)
                    for _, folderName in ipairs({"Unique", "Rare", "Epic", "Mythic", "Legendary"}) do
                        local folder = petsFolder:FindFirstChild(folderName)
                        if folder then
                            for _, pet in ipairs(folder:GetChildren()) do
                                equipPetEvent:FireServer("unequipPet", pet)
                                task.wait()
                            end
                        end
                    end
                end

                while autoRebirthActive do
                    local petsFolder = LocalPlayer:FindFirstChild("petsFolder")
                    
                    if petsFolder then
                        -- 1. ÉQUIPEMENT ULTRA-RAPIDE DES TITANIUM HYDRA (AVANT RENAISSANCE)
                        unequipAllPets(petsFolder)
                        
                        for _, folderName in ipairs({"Unique", "Rare", "Epic", "Mythic", "Legendary"}) do
                            local folder = petsFolder:FindFirstChild(folderName)
                            if folder then
                                for _, pet in ipairs(folder:GetChildren()) do
                                    local pName = pet.Name
                                    if pet:FindFirstChild("PetName") then pName = pet.PetName.Value end
                                    
                                    if pName == "Titanium Hydra" then
                                        equipPetEvent:FireServer("equipPet", pet)
                                        task.wait()
                                    end
                                end
                            end
                        end

                        -- 2. RENAISSANCE
                        rebirthRemote:InvokeServer("rebirthRequest")

                        -- 3. ÉQUIPEMENT PAR PRIORITÉ DES PETS REP SPEED (APRÈS RENAISSANCE)
                        unequipAllPets(petsFolder)

                        local repPets = {}
                        local uniqueFolder = petsFolder:FindFirstChild("Unique")
                        local priority4Pet = uniqueFolder and uniqueFolder:GetChildren()[4] -- Pet ciblé dans la vidéo

                        for _, folderName in ipairs({"Unique", "Rare", "Epic", "Mythic", "Legendary"}) do
                            local folder = petsFolder:FindFirstChild(folderName)
                            if folder then
                                for _, pet in ipairs(folder:GetChildren()) do
                                    local pName = pet.Name
                                    if pet:FindFirstChild("PetName") then pName = pet.PetName.Value end

                                    local priority = repSpeedPetPriorities[pName] or 5
                                    
                                    -- Si c'est le pet exact [4] du dossier Unique, priorité absolue (0)
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

                        -- Tri : Priorité 0 en premier, puis 1, 2, 3, 4
                        table.sort(repPets, function(a, b)
                            if a.Priority == b.Priority then
                                return a.Score > b.Score
                            end
                            return a.Priority < b.Priority
                        end)

                        -- Équipement automatique ultra-rapide
                        for _, entry in ipairs(repPets) do
                            equipPetEvent:FireServer("equipPet", entry.Instance)
                            task.wait()
                        end
                    end
                    
                    -- 4. COOLDOWN EXACT (6 SECONDES)
                    task.wait(6)
                end
            end)
        end
    end,
})end
