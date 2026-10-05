local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoRepGui"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0.5, -100, 0.5, -50)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Parent = screenGui

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -20, 0, 40)
toggleButton.Position = UDim2.new(0, 10, 0, 10)
toggleButton.Text = "Start Auto Rep"
toggleButton.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
toggleButton.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 40)
statusLabel.Position = UDim2.new(0, 10, 0, 60)
statusLabel.Text = "Status: Stopped"
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Parent = frame

local repRemote = ReplicatedStorage:FindFirstChild("RepRemote")
if not repRemote then
    warn("[AutoRep] RepRemote not found in ReplicatedStorage.")
end

local autoRepEnabled = false
local repThread

local function startAutoRep()
    if autoRepEnabled or not repRemote then return end
    autoRepEnabled = true
    statusLabel.Text = "Status: Running"
    toggleButton.Text = "Stop Auto Rep"
    repThread = task.spawn(function()
        while autoRepEnabled do
            repRemote:FireServer()
            task.wait(1 / 700)
        end
    end)
end

local function stopAutoRep()
    if not autoRepEnabled then return end
    autoRepEnabled = false
    statusLabel.Text = "Status: Stopped"
    toggleButton.Text = "Start Auto Rep"
    repThread = nil
end

toggleButton.MouseButton1Click:Connect(function()
    if autoRepEnabled then
        stopAutoRep()
    else
        startAutoRep()
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        if autoRepEnabled then
            stopAutoRep()
        else
            startAutoRep()
        end
    end
end)

player.AncestryChanged:Connect(function(child, parent)
    if not parent then
        stopAutoRep()
        screenGui:Destroy()
    end
end)
