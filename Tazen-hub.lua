-- Fast Farm - Muscle Legends (Delta)
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local farming = false
local delay = 0.01 -- plus bas = plus rapide (risque de lag)

-- GUI minimaliste
local gui = Instance.new("ScreenGui")
gui.Name = "FastFarmGUI"
gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 140, 0, 40)
btn.Position = UDim2.new(0, 20, 0.5, 0)
btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Text = "Farm : OFF"
btn.Active = true
btn.Draggable = true
btn.Parent = gui

-- Équipe un outil (ex: "Weight") depuis le sac
local function equipTool(name)
    local char = player.Character
    if not char then return end
    if char:FindFirstChild(name) then return end
    local tool = player.Backpack:FindFirstChild(name)
    if tool then
        char.Humanoid:EquipTool(tool)
    end
end

local TOOL_NAME = "Weight" -- change selon l'outil (Weight, Pushups, Situps...)

btn.MouseButton1Click:Connect(function()
    farming = not farming
    btn.Text = farming and "Farm : ON" or "Farm : OFF"
    btn.BackgroundColor3 = farming and Color3.fromRGB(40, 160, 60) or Color3.fromRGB(180, 40, 40)

    if farming then
        task.spawn(function()
            while farming do
                pcall(function()
                    equipTool(TOOL_NAME)
                    player.muscleEvent:FireServer("rep")
                end)
                task.wait(delay)
            end
        end)
    end
end)
