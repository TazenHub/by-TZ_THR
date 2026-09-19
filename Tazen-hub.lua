--[[
    =======================================================================
    PROJECT: Muscle Legends - Advanced Automation Script
    DEVELOPER: DeepHat (Kindo AI)
    VERSION: 1.1.0 (PlaceID Secured)
    DESCRIPTION: UI-based automation script with PlaceID verification.
    =======================================================================
]]

-- Services Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration de Sécurité
local TARGET_PLACE_ID = 874427664 -- ID fourni pour Muscle Legends
local LocalPlayer = Players.LocalPlayer

-- Fonction de vérification de l'environnement
local function checkEnvironment()
    if game.PlaceId ~= TARGET_PLACE_ID then
        warn("[DeepHat] ERREUR : Ce script est optimisé pour Muscle Legends uniquement.")
        warn("[DeepHat] PlaceID détecté : " .. tostring(game.PlaceId))
        return false
    end
    return true
end

-- Si l'ID ne correspond pas, on arrête le script proprement
if not checkEnvironment() then
    return 
end

-- Variables de l'utilisateur
local Settings = {
    AutoLiftEnabled = false,
    LiftDelay = 0.1,
}

-- Chargement de la bibliothèque Rayfield
-- Note : Utilisation de pcall pour éviter le crash si la bibliothèque ne charge pas
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    warn("[DeepHat] Échec du chargement de la bibliothèque Rayfield.")
    return
end

-- Création de la fenêtre principale
local Window = Rayfield:CreateWindow({
   Name = "DeepHat | Muscle Legends",
   SubTitle = "Advanced Automation Suite",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "DeepHat_Config",
      FileName = "MuscleLegends_Settings"
   },
   Keybind = Enum.KeyCode.RightControl, 
   Discord = "", 
   Queueing = true 
})

-- Création de l'onglet principal
local MainTab = Window:CreateTab("Automation", 4483451102) 

-- SECTION: AUTO LIFT
MainTab:CreateSection("Core Features")

local AutoLiftToggle = MainTab:CreateToggle({
   Name = "Free Auto Lift (Gamepass Mode)",
   CurrentValue = false,
   Flag = "AutoLiftFlag", 
   Info = "Simule l'entraînement automatique pour augmenter vos statistiques.",
   Position = "Top",
   Callback = function(Value)
       Settings.AutoLiftEnabled = Value
       
       if Value then
           task.spawn(function()
               while Settings.AutoLiftEnabled do
                   local Character = LocalPlayer.Character
                   if Character then
                       -- Recherche de l'outil équipé
                       local Tool = Character:FindFirstChildOfClass("Tool")
                       if Tool then
                           Tool:Activate() 
                       end
                   end
                   task.wait(Settings.LiftDelay)
               end
           end)
           print("[DeepHat] Auto Lift : ACTIVÉ")
       else
           print("[DeepHat] Auto Lift : DÉSACTIVÉ")
       end
   end,
})

-- SECTION: CONFIGURATION
MainTab:CreateSection("Settings Optimization")

local SpeedSlider = MainTab:CreateSlider({
   Name = "Lift Speed (Delay)",
   Range = {0.01, 0.5},
   Increment = 0.01,
   Suffix = "s",
   CurrentValue = 0.1,
   Flag = "LiftSpeedFlag",
   Callback = function(Value)
       Settings.LiftDelay = Value
   end,
})

-- SECTION: INFO
local InfoTab = Window:CreateTab("Information", 4483451102)

InfoTab:CreateLabel("Developer: DeepHat (Kindo)")
InfoTab:CreateLabel("Status: Stable / Secured")
InfoTab:CreateLabel("Target Game ID: " .. tostring(TARGET_PLACE_ID))

-- Bouton de destruction de l'UI
InfoTab:CreateButton({
   Name = "Destroy UI",
   Callback = function()
       Rayfield:Destroy()
   end,
})

-- Console Log de démarrage
print("[DeepHat] Script injecté avec succès sur Muscle Legends.")
print("[DeepHat] Prêt pour l'automatisation.")
