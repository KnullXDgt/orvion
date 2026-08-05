local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ABU_GELAP = Color3.fromRGB(0, 0, 0)
local WATCHED_REGISTRY = setmetatable({}, {__mode = "k"})
local GuiControl = require(ReplicatedStorage.Modules.GuiControl)
local BATCH_SIZE = 30

local gs = UserSettings():GetService("UserGameSettings")
local rs = settings().Rendering

local function applyAutoSettings()
    local success1 = pcall(function()
        gs.MasterVolume = 0
        gs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        rs.QualityLevel = Enum.QualityLevel.Level01
    end)
    if success1 then return end

    local success2 = pcall(function()
        gs.MasterVolume = 0
        gs.SavedQualityLevel = 1
        rs.QualityLevel = 1
    end)
    if success2 then return end

    if type(sethiddenproperty) == "function" then
        pcall(function()
            sethiddenproperty(gs, "MasterVolume", 0)
            sethiddenproperty(gs, "SavedQualityLevel", Enum.SavedQualitySetting.QualityLevel1)
            sethiddenproperty(rs, "QualityLevel", Enum.QualityLevel.Level01)
        end)
    end
end

local ui = Instance.new("ScreenGui")
ui.Name = "PingTimerUI"
ui.ResetOnSpawn = false
ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ui.Parent = (gethui and gethui()) or CoreGui

local frame = Instance.new("Frame", ui)
frame.Size = UDim2.new(0, 220, 0, 40)
frame.Position = UDim2.new(0.015, 0, 0.165, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Active = true

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(1, 0)

local textLabel = Instance.new("TextLabel", frame)
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.BackgroundTransparency = 1
textLabel.Font = Enum.Font.GothamBold
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextSize = 16
textLabel.Text = "Ping: 0 ms | 0:00:00"

local LynxButton = Instance.new("ImageButton", ui)
LynxButton.Name = "ToggleBtn"
LynxButton.Size = UDim2.new(0, 45, 0, 45)
LynxButton.Position = UDim2.new(0.015, 0, 0.1, 0)
LynxButton.BackgroundTransparency = 1
LynxButton.Image = "rbxassetid://118176705805619"
LynxButton.Active = true
LynxButton.ZIndex = 2147483647

LynxButton.MouseButton1Click:Connect(function()
    pcall(function()
        local targetLynx = CoreGui:FindFirstChild("LynxGui")
        if targetLynx then
            targetLynx.Enabled = not targetLynx.Enabled
        end
    end)
end)

local startTime = os.time()
task.spawn(function()
    while task.wait(1) do
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        local elapsed = os.time() - startTime
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60
        textLabel.Text = string.format("Ping: %d ms | %d:%02d:%02d", ping, h, m, s)
    end
end)

local DECORATIVE = {
    ParticleEmitter = true, Smoke = true, Fire = true, Sparkles = true,
    Beam = true, Trail = true, Explosion = true, Discharge = true,
    Dust = true, PointLight = true, SpotLight = true, SurfaceLight = true,
    Decal = true, Texture = true, SurfaceAppearance = true,
    Highlight = true, SelectionBox = true, RopeConstraint = true,
    BillboardGui = true, SurfaceGui = true
}

local CORE_LIMBS = {
    ["Head"] = true, ["Torso"] = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
    ["HumanoidRootPart"] = true, ["UpperTorso"] = true, ["LowerTorso"] = true, 
    ["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
    ["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
    ["LeftUpperLeg"] = true, ["LeftLowerLeg"] = true, ["LeftFoot"] = true,
    ["RightUpperLeg"] = true, ["RightLowerLeg"] = true, ["RightFoot"] = true
}

local function cleanChar(char)
    if not char then return end
    for _, inst in ipairs(char:GetDescendants()) do
        if inst:IsA("Accessory") or inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") or inst:IsA("BodyColors") or inst:IsA("CharacterMesh") then
            pcall(inst.Destroy, inst)
        elseif inst:IsA("BasePart") then
            if not CORE_LIMBS[inst.Name] then
                inst.Transparency = 1
                inst.LocalTransparencyModifier = 1
            else
                inst.Color = Color3.fromRGB(150, 150, 150)
                inst.Material = Enum.Material.SmoothPlastic
                inst.Transparency = 0
            end
        elseif DECORATIVE[inst.ClassName] then
            pcall(inst.Destroy, inst)
        end
    end
end

local TARGET_CLASSES = {
    Atmosphere = true, ColorCorrectionEffect = true, Sky = true,
    SunRaysEffect = true, BloomEffect = true, BlurEffect = true, Clouds = true
}

local function neutralizeTarget(obj)
    if obj.Name == "BaseGrayCC" then
        if obj.Brightness ~= 0.07843 then obj.Brightness = 0.07843 end
        if obj.Contrast ~= 0 then obj.Contrast = 0 end
        if obj.Saturation ~= -1 then obj.Saturation = -1 end
        if obj.Enabled ~= true then obj.Enabled = true end
        return
    end
    if obj.Name == "BaseNormalSky" then
        if obj.CelestialBodiesShown ~= false then obj.CelestialBodiesShown = false end
        if obj.StarCount ~= 0 then obj.StarCount = 0 end
        return
    end

    if obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("Clouds") then
        if obj.Enabled ~= false then obj.Enabled = false end
    elseif obj:IsA("Atmosphere") then
        if obj.Density ~= 0 then obj.Density = 0 end
        if obj.Glare ~= 0 then obj.Glare = 0 end
        if obj.Haze ~= 0 then obj.Haze = 0 end
    elseif obj:IsA("Sky") then
        if obj.CelestialBodiesShown ~= false then obj.CelestialBodiesShown = false end
        if obj.StarCount ~= 0 then obj.StarCount = 0 end
        if obj.SkyboxBk ~= "rbxassetid://0" then obj.SkyboxBk = "rbxassetid://0" end
        if obj.SkyboxDn ~= "rbxassetid://0" then obj.SkyboxDn = "rbxassetid://0" end
        if obj.SkyboxFt ~= "rbxassetid://0" then obj.SkyboxFt = "rbxassetid://0" end
        if obj.SkyboxLf ~= "rbxassetid://0" then obj.SkyboxLf = "rbxassetid://0" end
        if obj.SkyboxRt ~= "rbxassetid://0" then obj.SkyboxRt = "rbxassetid://0" end
        if obj.SkyboxUp ~= "rbxassetid://0" then obj.SkyboxUp = "rbxassetid://0" end
        if obj.SunTextureId ~= "rbxassetid://0" then obj.SunTextureId = "rbxassetid://0" end
        if obj.MoonTextureId ~= "rbxassetid://0" then obj.MoonTextureId = "rbxassetid://0" end
    end
end

local function handleDescendant(inst)
    if inst:IsDescendantOf(LocalPlayer.Character) or inst:IsDescendantOf(CoreGui) then return end

    if inst:IsA("BasePart") then
        pcall(function()
            inst.Transparency = 1
            inst.Color = Color3.fromRGB(0, 0, 0)
            inst.CastShadow = false
            inst.Material = Enum.Material.SmoothPlastic
        end)
    elseif DECORATIVE[inst.ClassName] or inst:IsA("PostEffect") then
        pcall(function() inst:Destroy() end)
    elseif TARGET_CLASSES[inst.ClassName] then
        pcall(neutralizeTarget, inst)
        if not WATCHED_REGISTRY[inst] then
            WATCHED_REGISTRY[inst] = true
            inst.Changed:Connect(function()
                pcall(neutralizeTarget, inst)
            end)
        end
    elseif inst:IsA("Humanoid") then
        local model = inst.Parent
        if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
            task.defer(function() pcall(function() model:Destroy() end) end)
        end
    end
end

Lighting.DescendantAdded:Connect(handleDescendant)
workspace.DescendantAdded:Connect(handleDescendant)

for _, obj in ipairs(Lighting:GetDescendants()) do handleDescendant(obj) end

local FORCED_LIGHTING = {
    GlobalShadows = false,
    Brightness = 0,
    Ambient = ABU_GELAP,
    OutdoorAmbient = ABU_GELAP,
    ExposureCompensation = 0,
    EnvironmentDiffuseScale = 0,
    EnvironmentSpecularScale = 0,
    TimeOfDay = "00:00:00",
    FogStart = 999999,
    FogEnd = 999999,
}

local function applyLightingOverride()
    for property, value in pairs(FORCED_LIGHTING) do
        if Lighting[property] ~= value then
             Lighting[property] = value
        end
    end
end

local function ensureBaseEffects()
    if not Lighting:FindFirstChild("BaseNormalSky") then
        local normalSky = Instance.new("Sky")
        normalSky.Name = "BaseNormalSky"
        normalSky.CelestialBodiesShown = false
        normalSky.StarCount = 0
        normalSky.Parent = Lighting
    end

    if not Lighting:FindFirstChild("BaseGrayCC") then
        local grayCC = Instance.new("ColorCorrectionEffect")
        grayCC.Name = "BaseGrayCC"
        grayCC.Brightness = 0.07843
        grayCC.Contrast = 0
        grayCC.Saturation = -1
        grayCC.Parent = Lighting
    end
end

applyLightingOverride()
ensureBaseEffects()

Lighting.Changed:Connect(applyLightingOverride)

Lighting.ChildRemoved:Connect(function(child)
    if child.Name == "BaseNormalSky" or child.Name == "BaseGrayCC" then
        ensureBaseEffects()
    end
end)

if setfpscap then
    setfpscap(30)
    task.spawn(function()
        while true do
           task.wait(10)
            setfpscap(30)
        end
    end)
end

task.spawn(function()
    pcall(function()
        workspace.Terrain:Clear()
    end)
    
    local objectsProcessed = 0
    for _, inst in ipairs(workspace:GetDescendants()) do
        if not inst:IsDescendantOf(LocalPlayer.Character) and not inst:IsDescendantOf(CoreGui) then
            handleDescendant(inst)
            
            objectsProcessed = objectsProcessed + 1
            if objectsProcessed % BATCH_SIZE == 0 then
                RunService.Heartbeat:Wait()
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(cleanChar)
if LocalPlayer.Character then
    cleanChar(LocalPlayer.Character)
end

task.spawn(function()
    while task.wait(1) do
        local dailyUI = PlayerGui:FindFirstChild("!!! Daily Login")
        if dailyUI and dailyUI.Enabled == true then
            pcall(function()
                GuiControl:Close()
            end)
            task.wait(3)
        end
    end
end)

--[[
    Delta Hider
    Last Updated: 29th July 2026
]]

if identifyexecutor() ~= "Delta" then 
    warn("You are not using Delta.")
    return
end

local i = 0

for _, v in pairs(gethui():GetChildren()) do
    if v:IsA("ScreenGui") then

        local ImageButton = v:FindFirstChildOfClass("ImageButton");

        if ImageButton and tostring(ImageButton.Image):find("Logo.png", 1, true) then
            v.Enabled = false
            i = i + 1
        end

        if v:FindFirstChild("Console") and v:FindFirstChild("IsTween") and v:FindFirstChild("Executor") then
            v.Enabled = false
            i = i + 1
        end

        if i == 2 then 
            break
        end

    end
end

applyAutoSettings()
