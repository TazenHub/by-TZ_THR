local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()
local Window = OrionLib:MakeWindow({Name = "pablo_DTH Hub", HidePremium = false, SaveConfig = true, ConfigFolder = "MusclePBL", IntroText = "Muscle Legends Rojo"})

-- Variables de Control
getgenv().autoWeight = false
getgenv().autoPunch = false

-- Funciones de Auto-Farm
function doWeight()
    spawn(function()
        while getgenv().autoWeight do
            local tool = game.Players.LocalPlayer.Backpack:FindFirstChild("Weight") or game.Players.LocalPlayer.Character:FindFirstChild("Weight")
            if tool then
                game.Players.LocalPlayer.Character.Humanoid:EquipTool(tool)
                tool:Activate()
            end
            task.wait(0.1) -- Velocidad del click
        end
    end)
end

function doPunch()
    spawn(function()
        while getgenv().autoPunch do
            local tool = game.Players.LocalPlayer.Backpack:FindFirstChild("Punch") or game.Players.LocalPlayer.Character:FindFirstChild("Punch")
            if tool then
                game.Players.LocalPlayer.Character.Humanoid:EquipTool(tool)
                tool:Activate()
            end
            task.wait(0.1)
        end
    end)
end

-- Interfaz
local Tab = Window:MakeTab({
	Name = "Auto Farm",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

Tab:AddSection({
	Name = "Entrenamiento"
})

Tab:AddToggle({
	Name = "Auto Pesas + AutoClick",
	Default = false,
	Callback = function(Value)
		getgenv().autoWeight = Value
        if Value then
            doWeight()
        end
	end    
})

Tab:AddToggle({
	Name = "Auto Puños + AutoClick",
	Default = false,
	Callback = function(Value)
		getgenv().autoPunch = Value
        if Value then
            doPunch()
        end
	end    
})

Tab:AddSection({
	Name = "Créditos: pablo_DTH"
})

OrionLib:Init()
