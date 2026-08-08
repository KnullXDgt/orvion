-- ==========================================
-- ORVION LIBRARY v1.0
-- Standalone UI Library
-- ==========================================

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local CONFIG_FONT_SECTION  = 14
local CONFIG_FONT_GENERAL  = 13
local CONFIG_FONT_DROPDOWN = 12
local CONFIG_ELEMENT_HEIGHT = 48

local COLOR_WHITE        = Color3.fromRGB(255, 255, 255)
local COLOR_DARK_GRAY    = Color3.fromRGB(170, 170, 185)
local COLOR_SIDEBAR_LOG  = Color3.fromRGB(200, 200, 215)
local COLOR_SECTION_BG   = Color3.fromRGB(35, 35, 45)
local COLOR_INTERACTIVE_BG = Color3.fromRGB(25, 25, 32)

local OrvionLib = {}
OrvionLib.Assets = {
    Icons = {
        Minimize = "rbxassetid://9886659276",
        Close    = "rbxassetid://9886659671",
        Arrow    = "rbxassetid://16851841101"
    }
}

-- ==========================================
-- NOTIFICATION SYSTEM (RIGHT BOTTOM)
-- ==========================================
function OrvionLib:Notify(title, text, duration)
    duration = duration or 3

    if CoreGui:FindFirstChild("OrvionLibNotifyGui") then
        CoreGui.OrvionLibNotifyGui:Destroy()
    end

    local NotifyGui = Instance.new("ScreenGui")
    NotifyGui.Name = "OrvionLibNotifyGui"
    NotifyGui.Parent = CoreGui
    NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local Container = Instance.new("Frame", NotifyGui)
    Container.Name = "Container"
    Container.BackgroundTransparency = 1
    Container.Size = UDim2.new(0, 300, 1, 0)
    Container.Position = UDim2.new(1, -300, 0, 0)

    local ListLayout = Instance.new("UIListLayout", Container)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    ListLayout.Padding = UDim.new(0, 10)

    local Padding = Instance.new("UIPadding", Container)
    Padding.PaddingBottom = UDim.new(0, 20)
    Padding.PaddingRight  = UDim.new(0, 20)
    Padding.PaddingLeft   = UDim.new(0, 10)

    local Holder = Instance.new("Frame", Container)
    Holder.BackgroundTransparency = 1
    Holder.Size = UDim2.new(1, 0, 0, 60)

    local NoteFrame = Instance.new("Frame", Holder)
    NoteFrame.BackgroundColor3 = COLOR_SECTION_BG
    NoteFrame.BackgroundTransparency = 0.1
    NoteFrame.Size = UDim2.new(1, 0, 1, 0)
    NoteFrame.Position = UDim2.new(1, 320, 0, 0)
    NoteFrame.BorderSizePixel = 0

    local NoteCorner = Instance.new("UICorner", NoteFrame)
    NoteCorner.CornerRadius = UDim.new(0, 6)

    local NoteStroke = Instance.new("UIStroke", NoteFrame)
    NoteStroke.Color = Color3.fromRGB(80, 80, 100)
    NoteStroke.Thickness = 1.5

    local TitleLabel = Instance.new("TextLabel", NoteFrame)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.Size = UDim2.new(1, -20, 0, 20)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = title
    TitleLabel.TextColor3 = COLOR_WHITE
    TitleLabel.TextSize = CONFIG_FONT_SECTION
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local TextLabel = Instance.new("TextLabel", NoteFrame)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Position = UDim2.new(0, 10, 0, 25)
    TextLabel.Size = UDim2.new(1, -20, 1, -30)
    TextLabel.Font = Enum.Font.Gotham
    TextLabel.Text = text
    TextLabel.TextColor3 = COLOR_SIDEBAR_LOG
    TextLabel.TextSize = CONFIG_FONT_GENERAL
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.TextYAlignment = Enum.TextYAlignment.Top
    TextLabel.TextWrapped = true

    local slideIn = TweenService:Create(NoteFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)})
    slideIn:Play()

    task.delay(duration, function()
        local slideOut = TweenService:Create(NoteFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(1, 320, 0, 0)})
        slideOut:Play()
        slideOut.Completed:Connect(function()
            NotifyGui:Destroy()
        end)
    end)
end

-- ==========================================
-- CREATE WINDOW
-- ==========================================
function OrvionLib:CreateWindow(config)
    config = config or {}
    local titleText = config.Title or "Orvion"
    local size = UDim2.fromOffset(470, 270)

    if CoreGui:FindFirstChild("OrvionGui") then
        CoreGui.OrvionGui:Destroy()
    end
    if CoreGui:FindFirstChild("OrvionDropdownOverlay") then
        CoreGui.OrvionDropdownOverlay:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "OrvionGui"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local DropdownOverlayGui = Instance.new("ScreenGui")
    DropdownOverlayGui.Name = "OrvionDropdownOverlay"
    DropdownOverlayGui.Parent = CoreGui
    DropdownOverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    DropdownOverlayGui.DisplayOrder = 999

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.Position = UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2)
    MainFrame.Size = size
    MainFrame.BorderSizePixel = 0

    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = UDim.new(0, 8)

    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Color3.fromRGB(80, 80, 100)
    MainStroke.LineJoinMode = Enum.LineJoinMode.Round
    MainStroke.Thickness = 1.5
    MainStroke.Transparency = 0

    local ImageWrapper = Instance.new("Frame", MainFrame)
    ImageWrapper.Name = "ImageWrapper"
    ImageWrapper.Size = UDim2.new(1, 0, 1, 0)
    ImageWrapper.BackgroundTransparency = 1
    ImageWrapper.ClipsDescendants = true
    ImageWrapper.ZIndex = 0

    local ImageCorner = Instance.new("UICorner", ImageWrapper)
    ImageCorner.CornerRadius = UDim.new(0, 8)

    local ThemeImage = Instance.new("ImageLabel", ImageWrapper)
    ThemeImage.Name = "ThemeImage"
    ThemeImage.Size = UDim2.new(0, 305.5, 0, 256.5)
    ThemeImage.Position = UDim2.new(1, -305.5, 1, -256.5)
    ThemeImage.BackgroundTransparency = 1
    ThemeImage.Image = "rbxassetid://108370878353673"
    ThemeImage.ZIndex = 0

    local ThemeCorner = Instance.new("UICorner", ThemeImage)
    ThemeCorner.CornerRadius = UDim.new(0, 8)

    local UIGradient = Instance.new("UIGradient", ThemeImage)
    UIGradient.Rotation = 45
    UIGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.6, 0.95),
        NumberSequenceKeypoint.new(1, 0.4)
    })

    -- Drag
    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local Top = Instance.new("Frame", MainFrame)
    Top.Name = "Top"
    Top.Size = UDim2.new(1, 0, 0, 38)
    Top.BackgroundTransparency = 1
    Top.ZIndex = 2

    local DecideFrame = Instance.new("Frame", MainFrame)
    DecideFrame.Name = "DecideFrame"
    DecideFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DecideFrame.BackgroundTransparency = 0.85
    DecideFrame.Position = UDim2.new(0, 0, 0, 38)
    DecideFrame.Size = UDim2.new(1, 0, 0, 1)
    DecideFrame.BorderSizePixel = 0
    DecideFrame.ZIndex = 2

    local IconLabel = Instance.new("ImageLabel", Top)
    IconLabel.BackgroundTransparency = 1
    IconLabel.Size = UDim2.new(0, 16, 0, 16)
    IconLabel.Position = UDim2.new(0, 6, 0.5, 0)
    IconLabel.AnchorPoint = Vector2.new(0, 0.5)
    IconLabel.Image = config.Icon or ""
    IconLabel.Visible = config.Icon ~= nil
    IconLabel.ScaleType = Enum.ScaleType.Fit

    local IconCorner = Instance.new("UICorner", IconLabel)
    IconCorner.CornerRadius = UDim.new(1, 0)

    local TitleLabel = Instance.new("TextLabel", Top)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = config.Icon and UDim2.new(0, 28, 0, 9) or UDim2.new(0, 10, 0, 9)
    TitleLabel.Size = UDim2.new(0, 250, 0, 20)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = titleText
    TitleLabel.TextColor3 = COLOR_WHITE
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("ImageButton", Top)
    CloseBtn.Size = UDim2.new(0, 18, 0, 18)
    CloseBtn.AnchorPoint = Vector2.new(1, 0.5)
    CloseBtn.Position = UDim2.new(1, -15, 0.5, 0)
    CloseBtn.Image = OrvionLib.Assets.Icons.Close
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        if CoreGui:FindFirstChild("OrvionDropdownOverlay") then CoreGui.OrvionDropdownOverlay:Destroy() end
    end)

    local MinBtn = Instance.new("ImageButton", Top)
    MinBtn.Size = UDim2.new(0, 18, 0, 18)
    MinBtn.AnchorPoint = Vector2.new(1, 0.5)
    MinBtn.Position = UDim2.new(1, -45, 0.5, 0)
    MinBtn.Image = OrvionLib.Assets.Icons.Minimize
    MinBtn.BackgroundTransparency = 1

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        MainFrame:TweenSize(
            minimized and UDim2.new(0, 470, 0, 38) or size,
            Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true
        )
        if CoreGui:FindFirstChild("OrvionDropdownOverlay") then CoreGui.OrvionDropdownOverlay:ClearAllChildren() end
        if MainFrame:FindFirstChild("ActiveDropdown") then MainFrame:FindFirstChild("ActiveDropdown"):Destroy() end
        if MainFrame:FindFirstChild("DropOutsideClick") then MainFrame:FindFirstChild("DropOutsideClick"):Destroy() end
    end)

    -- Sidebar
    local LayersTab = Instance.new("Frame", MainFrame)
    LayersTab.Name = "LayersTab"
    LayersTab.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
    LayersTab.BackgroundTransparency = 0.55
    LayersTab.Position = UDim2.new(0, 0, 0, 39)
    LayersTab.Size = UDim2.new(0, 120, 1, -39)
    LayersTab.BorderSizePixel = 0
    LayersTab.ZIndex = 2
    local layersCorner = Instance.new("UICorner", LayersTab)
    layersCorner.CornerRadius = UDim.new(0, 8)

    local LayersTabTopCover = Instance.new("Frame", LayersTab)
    LayersTabTopCover.Size = UDim2.new(1, 0, 0, 10)
    LayersTabTopCover.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
    LayersTabTopCover.BackgroundTransparency = 0.55
    LayersTabTopCover.BorderSizePixel = 0
    LayersTabTopCover.ZIndex = 2

    local SearchBarFrame = Instance.new("Frame", LayersTab)
    SearchBarFrame.Name = "SearchBarFrame"
    SearchBarFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    SearchBarFrame.BackgroundTransparency = 0
    SearchBarFrame.Position = UDim2.new(0, 12, 0, 14)
    SearchBarFrame.Size = UDim2.new(1, -24, 0, 26)
    SearchBarFrame.BorderSizePixel = 0
    local sc = Instance.new("UICorner", SearchBarFrame) sc.CornerRadius = UDim.new(0, 4)
    local sbs = Instance.new("UIStroke", SearchBarFrame) sbs.Color = Color3.fromRGB(60, 60, 75) sbs.Thickness = 1

    local SearchInput = Instance.new("TextBox", SearchBarFrame)
    SearchInput.BackgroundTransparency = 1
    SearchInput.Size = UDim2.new(1, 0, 1, 0)
    SearchInput.Position = UDim2.new(0, 0, 0, 0)
    SearchInput.Font = Enum.Font.Gotham
    SearchInput.PlaceholderText = "Search..."
    SearchInput.Text = ""
    SearchInput.TextColor3 = COLOR_WHITE
    SearchInput.TextSize = 12
    SearchInput.TextXAlignment = Enum.TextXAlignment.Center

    local ScrollTab = Instance.new("ScrollingFrame", LayersTab)
    ScrollTab.Name = "ScrollTab"
    ScrollTab.BackgroundTransparency = 1
    ScrollTab.Position = UDim2.new(0, 6, 0, 46)
    ScrollTab.Size = UDim2.new(1, -12, 1, -90)
    ScrollTab.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollTab.ScrollBarThickness = 0

    local TabListLayout = Instance.new("UIListLayout", ScrollTab)
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabListLayout.Padding = UDim.new(0, 2)
    TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, TabListLayout.AbsoluteContentSize.Y)
    end)

    -- Player footer
    local PlayerFooter = Instance.new("Frame", LayersTab)
    PlayerFooter.Name = "PlayerFooter"
    PlayerFooter.BackgroundTransparency = 1
    PlayerFooter.Position = UDim2.new(0, 6, 1, -42)
    PlayerFooter.Size = UDim2.new(1, -12, 0, 38)
    PlayerFooter.BorderSizePixel = 0

    local AvatarContainer = Instance.new("Frame", PlayerFooter)
    AvatarContainer.BackgroundTransparency = 1
    AvatarContainer.Position = UDim2.new(0, 6, 0.5, -2)
    AvatarContainer.AnchorPoint = Vector2.new(0, 0.5)
    AvatarContainer.Size = UDim2.new(0, 24, 0, 24)

    local AvatarImg = Instance.new("ImageLabel", AvatarContainer)
    AvatarImg.BackgroundTransparency = 1
    AvatarImg.Size = UDim2.new(1, 0, 1, 0)
    AvatarImg.Image = "rbxassetid://0"
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        local content, isReady = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if isReady then AvatarImg.Image = content end
    end)
    local aic = Instance.new("UICorner", AvatarImg) aic.CornerRadius = UDim.new(1, 0)

    local AvatarStroke = Instance.new("UIStroke", AvatarImg)
    AvatarStroke.Color = Color3.fromRGB(120, 120, 135)
    AvatarStroke.Thickness = 1.5
    AvatarStroke.Transparency = 0.2

    local WelcomeLabel = Instance.new("TextLabel", PlayerFooter)
    WelcomeLabel.BackgroundTransparency = 1
    WelcomeLabel.Position = UDim2.new(0, 36, 0.5, -2)
    WelcomeLabel.AnchorPoint = Vector2.new(0, 0.5)
    WelcomeLabel.Size = UDim2.new(1, -40, 0, 16)
    WelcomeLabel.Font = Enum.Font.Gotham
    WelcomeLabel.TextColor3 = Color3.fromRGB(155, 155, 170)
    WelcomeLabel.TextSize = 10
    WelcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
    WelcomeLabel.TextWrapped = false
    WelcomeLabel.TextTruncate = Enum.TextTruncate.AtEnd
    pcall(function()
        local rawName = tostring(game:GetService("Players").LocalPlayer.Name)
        local maskedName = string.sub(rawName, 1, 3) .. "***"
        WelcomeLabel.Text = "Welcome, " .. maskedName
    end)

    -- Content container
    local Container = Instance.new("Frame", MainFrame)
    Container.Name = "Layers"
    Container.BackgroundTransparency = 1
    Container.Position = UDim2.new(0, 128, 0, 42)
    Container.Size = UDim2.new(0, 330, 0, 205)
    Container.BorderSizePixel = 0
    Container.ZIndex = 2

    local Window = {}
    local tabs = {}
    local firstTab = true

    function Window:AddTab(tabName)
        local TabButton = Instance.new("TextButton", ScrollTab)
        TabButton.BackgroundColor3 = COLOR_SECTION_BG
        TabButton.BackgroundTransparency = 1
        TabButton.Size = UDim2.new(1, 0, 0, 26)
        TabButton.Font = Enum.Font.GothamBold
        TabButton.Text = "     " .. tabName
        TabButton.TextColor3 = Color3.fromRGB(160, 160, 175)
        TabButton.TextSize = CONFIG_FONT_GENERAL
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.BorderSizePixel = 0
        local tabCorner = Instance.new("UICorner", TabButton)
        tabCorner.CornerRadius = UDim.new(0, 4)

        local Indicator = Instance.new("Frame", TabButton)
        Indicator.BackgroundColor3 = COLOR_DARK_GRAY
        Indicator.Size = UDim2.new(0, 5, 0.7, 0)
        Indicator.AnchorPoint = Vector2.new(0, 0.5)
        Indicator.Position = UDim2.new(0, 0, 0.5, 0)
        Indicator.BorderSizePixel = 0
        Indicator.Visible = false
        local indCorner = Instance.new("UICorner", Indicator) indCorner.CornerRadius = UDim.new(1, 0)

        local TabContent = Instance.new("ScrollingFrame", Container)
        TabContent.Name = "ScrollLayers"
        TabContent.BackgroundTransparency = 1
        TabContent.Size = UDim2.new(1, 0, 1, 0)
        TabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
        TabContent.ScrollBarThickness = 2
        TabContent.Visible = false

        TabContent:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            if MainFrame:FindFirstChild("ActiveDropdown") then MainFrame:FindFirstChild("ActiveDropdown"):Destroy() end
            if MainFrame:FindFirstChild("DropOutsideClick") then MainFrame:FindFirstChild("DropOutsideClick"):Destroy() end
        end)

        local ContentLayout = Instance.new("UIListLayout", TabContent)
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Padding = UDim.new(0, 5)
        ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        local ContentPadding = Instance.new("UIPadding", TabContent)
        ContentPadding.PaddingLeft  = UDim.new(0, 4)
        ContentPadding.PaddingRight = UDim.new(0, 4)
        ContentPadding.PaddingTop   = UDim.new(0, 4)

        ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabContent.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 10)
        end)

        if firstTab then
            TabContent.Visible = true
            TabButton.BackgroundTransparency = 0.4
            TabButton.TextColor3 = COLOR_WHITE
            Indicator.Visible = true
            firstTab = false
        end

        TabButton.MouseButton1Click:Connect(function()
            if MainFrame:FindFirstChild("ActiveDropdown") then MainFrame:FindFirstChild("ActiveDropdown"):Destroy() end
            if MainFrame:FindFirstChild("DropOutsideClick") then MainFrame:FindFirstChild("DropOutsideClick"):Destroy() end
            for _, t in pairs(tabs) do
                t.Content.Visible = false
                t.Button.BackgroundTransparency = 1
                t.Button.TextColor3 = Color3.fromRGB(160, 160, 175)
                t.Indicator.Visible = false
            end
            TabContent.Visible = true
            TabButton.BackgroundTransparency = 0.4
            TabButton.TextColor3 = COLOR_WHITE
            Indicator.Visible = true
        end)

        table.insert(tabs, {Button = TabButton, Indicator = Indicator, Content = TabContent})

        local TabAPI = {}

        local function createElementAPI(parentContainer)
            local ElementAPI = {}

            function ElementAPI:AddParagraph(cfg)
                cfg = cfg or {}
                local ParaFrame = Instance.new("Frame", parentContainer)
                ParaFrame.BackgroundColor3 = COLOR_SECTION_BG
                ParaFrame.BackgroundTransparency = 0.4
                ParaFrame.Size = UDim2.new(1, 0, 0, 0)
                ParaFrame.AutomaticSize = Enum.AutomaticSize.Y
                ParaFrame.BorderSizePixel = 0
                local paraCorner = Instance.new("UICorner", ParaFrame) paraCorner.CornerRadius = UDim.new(0, 6)
                local paraStroke = Instance.new("UIStroke", ParaFrame) paraStroke.Color = Color3.fromRGB(60, 60, 75) paraStroke.Thickness = 1 paraStroke.Transparency = 0.5

                local paraPadding = Instance.new("UIPadding", ParaFrame)
                paraPadding.PaddingTop    = UDim.new(0, 8)
                paraPadding.PaddingBottom = UDim.new(0, 8)
                paraPadding.PaddingLeft   = UDim.new(0, 10)
                paraPadding.PaddingRight  = UDim.new(0, 10)

                local paraLayout = Instance.new("UIListLayout", ParaFrame)
                paraLayout.SortOrder = Enum.SortOrder.LayoutOrder
                paraLayout.Padding = UDim.new(0, 4)
                paraLayout.FillDirection = Enum.FillDirection.Vertical

                local TitleContainer = Instance.new("Frame", ParaFrame)
                TitleContainer.LayoutOrder = 1
                TitleContainer.BackgroundTransparency = 1
                TitleContainer.Size = UDim2.new(1, 0, 0, 20)

                local Title = Instance.new("TextLabel", TitleContainer)
                Title.BackgroundTransparency = 1
                Title.Size = UDim2.new(1, cfg.Icon and -24 or 0, 1, 0)
                Title.Font = Enum.Font.GothamBold
                Title.Text = cfg.Title or "Title"
                Title.TextColor3 = COLOR_WHITE
                Title.TextSize = CONFIG_FONT_SECTION
                Title.TextXAlignment = Enum.TextXAlignment.Left

                if cfg.Icon then
                    local iconId = cfg.Icon
                    if string.match(iconId, "rbxassetid://(%d+)") then
                        local extractedId = string.match(iconId, "rbxassetid://(%d+)")
                        iconId = "rbxthumb://type=Asset&id=" .. extractedId .. "&w=150&h=150"
                    elseif string.match(iconId, "^%d+$") then
                        iconId = "rbxthumb://type=Asset&id=" .. iconId .. "&w=150&h=150"
                    end
                    local ParaIcon = Instance.new("ImageLabel", TitleContainer)
                    ParaIcon.BackgroundTransparency = 1
                    ParaIcon.AnchorPoint = Vector2.new(1, 0.5)
                    ParaIcon.Position = UDim2.new(1, 0, 0.5, 0)
                    ParaIcon.Size = UDim2.new(0, 16, 0, 16)
                    ParaIcon.Image = iconId
                    ParaIcon.ScaleType = Enum.ScaleType.Fit
                end

                local Desc = Instance.new("TextLabel", ParaFrame)
                Desc.LayoutOrder = 2
                Desc.BackgroundTransparency = 1
                Desc.Size = UDim2.new(1, 0, 0, 0)
                Desc.AutomaticSize = Enum.AutomaticSize.Y
                Desc.Font = Enum.Font.Gotham
                Desc.Text = cfg.Content or "Content"
                Desc.TextColor3 = COLOR_SIDEBAR_LOG
                Desc.TextSize = CONFIG_FONT_GENERAL
                Desc.TextXAlignment = Enum.TextXAlignment.Left
                Desc.TextYAlignment = Enum.TextYAlignment.Top
                Desc.TextWrapped = true

                local f = {}
                function f:SetDesc(txt) Desc.Text = txt end
                return f
            end

            function ElementAPI:AddButton(cfg)
                cfg = cfg or {}
                local Btn = Instance.new("TextButton", parentContainer)
                Btn.BackgroundColor3 = COLOR_SECTION_BG
                Btn.BackgroundTransparency = 0.4
                Btn.Size = UDim2.new(1, 0, 0, CONFIG_ELEMENT_HEIGHT)
                Btn.Text = ""
                Btn.AutoButtonColor = true
                Btn.BorderSizePixel = 0
                local bc = Instance.new("UICorner", Btn) bc.CornerRadius = UDim.new(0, 6)
                local bcs = Instance.new("UIStroke", Btn) bcs.Color = Color3.fromRGB(60, 60, 75) bcs.Thickness = 1 bcs.Transparency = 0.5

                local Title = Instance.new("TextLabel", Btn)
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 0)
                Title.Size = UDim2.new(1, -40, 1, 0)
                Title.Font = Enum.Font.GothamBold
                Title.Text = cfg.Title or "Button"
                Title.TextColor3 = COLOR_WHITE
                Title.TextSize = CONFIG_FONT_GENERAL
                Title.TextXAlignment = Enum.TextXAlignment.Left

                if cfg.Icon then
                    local iconId = cfg.Icon
                    if string.match(iconId, "rbxassetid://(%d+)") then
                        local extractedId = string.match(iconId, "rbxassetid://(%d+)")
                        iconId = "rbxthumb://type=Asset&id=" .. extractedId .. "&w=150&h=150"
                    elseif string.match(iconId, "^%d+$") then
                        iconId = "rbxthumb://type=Asset&id=" .. iconId .. "&w=150&h=150"
                    end
                    local BtnIcon = Instance.new("ImageLabel", Btn)
                    BtnIcon.BackgroundTransparency = 1
                    BtnIcon.AnchorPoint = Vector2.new(1, 0.5)
                    BtnIcon.Position = UDim2.new(1, -12, 0.5, 0)
                    BtnIcon.Size = UDim2.new(0, 15, 0, 15)
                    BtnIcon.Image = iconId
                    BtnIcon.ScaleType = Enum.ScaleType.Fit
                end

                Btn.MouseButton1Click:Connect(function()
                    if cfg.Callback then pcall(cfg.Callback) end
                end)
            end

            function ElementAPI:AddButtonGrid(btn1Config, btn2Config)
                local GridFrame = Instance.new("Frame", parentContainer)
                GridFrame.BackgroundTransparency = 1
                GridFrame.Size = UDim2.new(1, 0, 0, CONFIG_ELEMENT_HEIGHT)
                GridFrame.BorderSizePixel = 0

                local layout = Instance.new("UIListLayout", GridFrame)
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Padding = UDim.new(0, 6)
                layout.VerticalAlignment = Enum.VerticalAlignment.Center

                local function createHalfButton(cfg, order)
                    cfg = cfg or {}
                    local Btn = Instance.new("TextButton", GridFrame)
                    Btn.LayoutOrder = order
                    Btn.BackgroundColor3 = COLOR_SECTION_BG
                    Btn.BackgroundTransparency = 0.4
                    Btn.Size = UDim2.new(0.5, -3, 1, 0)
                    Btn.Text = ""
                    Btn.AutoButtonColor = true
                    Btn.BorderSizePixel = 0
                    local bc = Instance.new("UICorner", Btn) bc.CornerRadius = UDim.new(0, 6)
                    local bcs = Instance.new("UIStroke", Btn) bcs.Color = Color3.fromRGB(60, 60, 75) bcs.Thickness = 1 bcs.Transparency = 0.5

                    local Title = Instance.new("TextLabel", Btn)
                    Title.BackgroundTransparency = 1
                    Title.Size = UDim2.new(1, 0, 1, 0)
                    Title.Font = Enum.Font.GothamBold
                    Title.Text = cfg.Title or "Button"
                    Title.TextColor3 = COLOR_WHITE
                    Title.TextSize = CONFIG_FONT_GENERAL
                    Title.TextXAlignment = Enum.TextXAlignment.Center

                    Btn.MouseButton1Click:Connect(function()
                        if cfg.Callback then pcall(cfg.Callback) end
                    end)
                end

                createHalfButton(btn1Config, 1)
                createHalfButton(btn2Config, 2)
            end

            function ElementAPI:AddToggle(cfg)
                cfg = cfg or {}
                local ToggleFrame = Instance.new("Frame", parentContainer)
                ToggleFrame.BackgroundColor3 = COLOR_SECTION_BG
                ToggleFrame.BackgroundTransparency = 0.4
                ToggleFrame.Size = UDim2.new(1, 0, 0, CONFIG_ELEMENT_HEIGHT)
                ToggleFrame.BorderSizePixel = 0
                local tfc = Instance.new("UICorner", ToggleFrame) tfc.CornerRadius = UDim.new(0, 6)
                local tfcs = Instance.new("UIStroke", ToggleFrame) tfcs.Color = Color3.fromRGB(60, 60, 75) tfcs.Thickness = 1 tfcs.Transparency = 0.5

                local Title = Instance.new("TextLabel", ToggleFrame)
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 0)
                Title.Size = UDim2.new(1, -55, 1, 0)
                Title.Font = Enum.Font.GothamBold
                Title.Text = cfg.Title or "Toggle"
                Title.TextColor3 = COLOR_WHITE
                Title.TextSize = CONFIG_FONT_GENERAL
                Title.TextXAlignment = Enum.TextXAlignment.Left

                local SwitchBg = Instance.new("Frame", ToggleFrame)
                SwitchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                SwitchBg.Position = UDim2.new(1, -38, 0.5, -9)
                SwitchBg.Size = UDim2.new(0, 32, 0, 18)
                local sbc = Instance.new("UICorner", SwitchBg) sbc.CornerRadius = UDim.new(1, 0)

                local Knob = Instance.new("Frame", SwitchBg)
                Knob.BackgroundColor3 = COLOR_WHITE
                Knob.Position = UDim2.new(0, 2, 0.5, -7)
                Knob.Size = UDim2.new(0, 14, 0, 14)
                local kc = Instance.new("UICorner", Knob) kc.CornerRadius = UDim.new(1, 0)

                local state = cfg.Default == true
                local function updateVisual(anim)
                    if state then
                        SwitchBg.BackgroundColor3 = COLOR_DARK_GRAY
                        Knob.BackgroundColor3 = COLOR_WHITE
                        if anim then TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(1, -16, 0.5, -7)}):Play()
                        else Knob.Position = UDim2.new(1, -16, 0.5, -7) end
                    else
                        SwitchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                        Knob.BackgroundColor3 = COLOR_WHITE
                        if anim then TweenService:Create(Knob, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -7)}):Play()
                        else Knob.Position = UDim2.new(0, 2, 0.5, -7) end
                    end
                end
                updateVisual(false)

                local btn = Instance.new("TextButton", ToggleFrame)
                btn.BackgroundTransparency = 1
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.Text = ""
                btn.MouseButton1Click:Connect(function()
                    state = not state
                    updateVisual(true)
                    if cfg.Callback then pcall(cfg.Callback, state) end
                end)

                local tAPI = {}
                function tAPI:SetValue(val)
                    state = val
                    updateVisual(true)
                    if cfg.Callback then pcall(cfg.Callback, state) end
                end
                return tAPI
            end

            function ElementAPI:AddInput(cfg)
                cfg = cfg or {}
                local InputFrame = Instance.new("Frame", parentContainer)
                InputFrame.BackgroundColor3 = COLOR_SECTION_BG
                InputFrame.BackgroundTransparency = 0.4
                InputFrame.Size = UDim2.new(1, 0, 0, 64)
                InputFrame.BorderSizePixel = 0
                local ifc = Instance.new("UICorner", InputFrame) ifc.CornerRadius = UDim.new(0, 6)
                local ifcs = Instance.new("UIStroke", InputFrame) ifcs.Color = Color3.fromRGB(60, 60, 75) ifcs.Thickness = 1 ifcs.Transparency = 0.5

                local Title = Instance.new("TextLabel", InputFrame)
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 6)
                Title.Size = UDim2.new(1, -20, 0, 20)
                Title.Font = Enum.Font.GothamBold
                Title.Text = cfg.Title or "Input"
                Title.TextColor3 = COLOR_WHITE
                Title.TextSize = CONFIG_FONT_GENERAL
                Title.TextXAlignment = Enum.TextXAlignment.Left

                local TextBoxBg = Instance.new("Frame", InputFrame)
                TextBoxBg.BackgroundColor3 = COLOR_INTERACTIVE_BG
                TextBoxBg.BackgroundTransparency = 0.2
                TextBoxBg.Position = UDim2.new(0, 10, 0, 31)
                TextBoxBg.Size = UDim2.new(1, -20, 0, 26)
                TextBoxBg.BorderSizePixel = 0
                local tbc = Instance.new("UICorner", TextBoxBg) tbc.CornerRadius = UDim.new(0, 4)

                local TextBox = Instance.new("TextBox", TextBoxBg)
                TextBox.BackgroundTransparency = 1
                TextBox.Position = UDim2.new(0, 8, 0, 0)
                TextBox.Size = UDim2.new(1, -16, 1, 0)
                TextBox.Font = Enum.Font.GothamBold
                TextBox.Text = cfg.Default or ""
                TextBox.PlaceholderText = cfg.Placeholder or "Enter..."
                TextBox.TextColor3 = COLOR_WHITE
                TextBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 165)
                TextBox.TextSize = CONFIG_FONT_GENERAL
                TextBox.TextXAlignment = Enum.TextXAlignment.Left
                TextBox.BorderSizePixel = 0

                TextBox:GetPropertyChangedSignal("Text"):Connect(function()
                    if cfg.Callback then pcall(cfg.Callback, TextBox.Text) end
                end)

                local iAPI = {}
                function iAPI:GetValue() return TextBox.Text end
                function iAPI:SetValue(val)
                    TextBox.Text = tostring(val)
                    if cfg.Callback then pcall(cfg.Callback, TextBox.Text) end
                end
                return iAPI
            end

            function ElementAPI:AddDropdown(cfg)
                cfg = cfg or {}
                local DropFrame = Instance.new("Frame", parentContainer)
                DropFrame.BackgroundColor3 = COLOR_SECTION_BG
                DropFrame.BackgroundTransparency = 0.4
                DropFrame.Size = UDim2.new(1, 0, 0, CONFIG_ELEMENT_HEIGHT)
                DropFrame.BorderSizePixel = 0
                local dfc = Instance.new("UICorner", DropFrame) dfc.CornerRadius = UDim.new(0, 6)
                local dfcs = Instance.new("UIStroke", DropFrame) dfcs.Color = Color3.fromRGB(60, 60, 75) dfcs.Thickness = 1 dfcs.Transparency = 0.5

                local Title = Instance.new("TextLabel", DropFrame)
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 10)
                Title.Size = UDim2.new(0.45, 0, 1, 0)
                Title.Font = Enum.Font.GothamBold
                Title.Text = cfg.Title or "Dropdown"
                Title.TextColor3 = COLOR_WHITE
                Title.TextSize = CONFIG_FONT_GENERAL
                Title.TextXAlignment = Enum.TextXAlignment.Left
                Title.TextYAlignment = Enum.TextYAlignment.Top

                local SelectBox = Instance.new("Frame", DropFrame)
                SelectBox.BackgroundColor3 = COLOR_INTERACTIVE_BG
                SelectBox.BackgroundTransparency = 0.2
                SelectBox.Size = UDim2.new(0.48, 0, 0, 26)
                SelectBox.Position = UDim2.new(1, -4, 0.5, 0)
                SelectBox.AnchorPoint = Vector2.new(1, 0.5)
                SelectBox.BorderSizePixel = 0
                local sbc2 = Instance.new("UICorner", SelectBox) sbc2.CornerRadius = UDim.new(0, 4)

                local selectedVal = cfg.DefaultValue or ""

                local SelectLabel = Instance.new("TextLabel", SelectBox)
                SelectLabel.BackgroundTransparency = 1
                SelectLabel.Size = UDim2.new(1, -26, 1, 0)
                SelectLabel.Position = UDim2.new(0, 8, 0, 0)
                SelectLabel.Font = Enum.Font.GothamBold
                SelectLabel.Text = tostring(selectedVal)
                SelectLabel.TextColor3 = COLOR_SIDEBAR_LOG
                SelectLabel.TextScaled = true
                SelectLabel.TextXAlignment = Enum.TextXAlignment.Left
                SelectLabel.BorderSizePixel = 0
                local _tsc = Instance.new("UITextSizeConstraint", SelectLabel)
                _tsc.MinTextSize = 8
                _tsc.MaxTextSize = CONFIG_FONT_DROPDOWN

                local DropArrow = Instance.new("ImageLabel", SelectBox)
                DropArrow.BackgroundTransparency = 1
                DropArrow.AnchorPoint = Vector2.new(1, 0.5)
                DropArrow.Position = UDim2.new(1, -4, 0.5, 0)
                DropArrow.Size = UDim2.new(0, 24, 0, 24)
                DropArrow.Image = OrvionLib.Assets.Icons.Arrow
                DropArrow.ImageTransparency = 0.4
                DropArrow.Rotation = 0

                local SelectBtn = Instance.new("TextButton", SelectBox)
                SelectBtn.BackgroundTransparency = 1
                SelectBtn.Size = UDim2.new(1, 0, 1, 0)
                SelectBtn.Text = ""

                local function closeDropdown()
                    local existing = MainFrame:FindFirstChild("ActiveDropdown")
                    if existing then existing:Destroy() end
                    local oc = MainFrame:FindFirstChild("DropOutsideClick")
                    if oc then oc:Destroy() end
                end

                SelectBtn.MouseButton1Click:Connect(function()
                    if MainFrame:FindFirstChild("ActiveDropdown") then
                        closeDropdown()
                        return
                    end

                    local OutsideClick = Instance.new("TextButton", MainFrame)
                    OutsideClick.Name = "DropOutsideClick"
                    OutsideClick.Size = UDim2.new(0, 296, 1, 0)
                    OutsideClick.Position = UDim2.new(0, 0, 0, 0)
                    OutsideClick.BackgroundTransparency = 1
                    OutsideClick.Text = ""
                    OutsideClick.ZIndex = 9
                    OutsideClick.MouseButton1Click:Connect(function()
                        closeDropdown()
                    end)

                    local popStartY = 42
                    local popHeight = MainFrame.AbsoluteSize.Y - popStartY - 4
                    local PopFrame = Instance.new("ScrollingFrame", MainFrame)
                    PopFrame.Name = "ActiveDropdown"
                    PopFrame.BackgroundColor3 = COLOR_INTERACTIVE_BG
                    PopFrame.BackgroundTransparency = 0.05
                    PopFrame.Position = UDim2.new(0, 296, 0, popStartY)
                    PopFrame.Size = UDim2.new(0, 162, 0, popHeight)
                    PopFrame.CanvasSize = UDim2.new(0, 0, 0, #(cfg.Values or {}) * 36)
                    PopFrame.ScrollBarThickness = 2
                    PopFrame.BorderSizePixel = 0
                    PopFrame.ZIndex = 10
                    local pfc = Instance.new("UICorner", PopFrame) pfc.CornerRadius = UDim.new(0, 6)
                    local pfs = Instance.new("UIStroke", PopFrame) pfs.Color = Color3.fromRGB(70, 70, 90) pfs.Thickness = 1.2

                    local popLayout = Instance.new("UIListLayout", PopFrame)
                    popLayout.SortOrder = Enum.SortOrder.LayoutOrder

                    local optionElements = {}

                    local function refreshHighlights()
                        for val, elements in pairs(optionElements) do
                            if val == selectedVal then
                                elements.Btn.BackgroundColor3 = COLOR_SECTION_BG
                                elements.Btn.BackgroundTransparency = 0.3
                                elements.Indicator.Visible = true
                            else
                                elements.Btn.BackgroundColor3 = COLOR_INTERACTIVE_BG
                                elements.Btn.BackgroundTransparency = 1
                                elements.Indicator.Visible = false
                            end
                        end
                    end

                    for _, val in ipairs(cfg.Values or {}) do
                        local optBtn = Instance.new("TextButton", PopFrame)
                        optBtn.BackgroundColor3 = COLOR_INTERACTIVE_BG
                        optBtn.BackgroundTransparency = 1
                        optBtn.Size = UDim2.new(1, 0, 0, 36)
                        optBtn.Text = ""
                        optBtn.AutoButtonColor = false
                        optBtn.BorderSizePixel = 0
                        optBtn.ZIndex = 11
                        local optCorner = Instance.new("UICorner", optBtn) optCorner.CornerRadius = UDim.new(0, 4)

                        local ind = Instance.new("Frame", optBtn)
                        ind.BackgroundColor3 = COLOR_DARK_GRAY
                        ind.Size = UDim2.new(0, 3, 0, 16)
                        ind.Position = UDim2.new(0, 2, 0.5, -8)
                        ind.BorderSizePixel = 0
                        ind.Visible = false
                        local indCorner2 = Instance.new("UICorner", ind) indCorner2.CornerRadius = UDim.new(1, 0)

                        local lbl = Instance.new("TextLabel", optBtn)
                        lbl.BackgroundTransparency = 1
                        lbl.Position = UDim2.new(0, 12, 0, 0)
                        lbl.Size = UDim2.new(1, -12, 1, 0)
                        lbl.Font = Enum.Font.GothamBold
                        lbl.Text = tostring(val)
                        lbl.TextColor3 = COLOR_SIDEBAR_LOG
                        lbl.TextSize = CONFIG_FONT_DROPDOWN
                        lbl.TextXAlignment = Enum.TextXAlignment.Left

                        optionElements[val] = {Btn = optBtn, Indicator = ind}

                        optBtn.MouseButton1Click:Connect(function()
                            selectedVal = val
                            SelectLabel.Text = tostring(val)
                            refreshHighlights()
                            if cfg.Callback then pcall(cfg.Callback, val) end
                        end)
                    end

                    refreshHighlights()
                end)

                local dAPI = {}
                function dAPI:SetValue(val)
                    selectedVal = val
                    SelectLabel.Text = tostring(val)
                    if cfg.Callback then pcall(cfg.Callback, val) end
                end
                function dAPI:SetValues(newVals)
                    cfg.Values = newVals
                end
                return dAPI
            end

            function ElementAPI:AddCollapsibleSection(title, defaultOpen)
                defaultOpen = defaultOpen == true

                local SectionFrame = Instance.new("Frame", parentContainer)
                SectionFrame.BackgroundTransparency = 1
                SectionFrame.Size = UDim2.new(1, 0, 0, 34)
                SectionFrame.BorderSizePixel = 0
                SectionFrame.ClipsDescendants = true

                local HeaderBtn = Instance.new("TextButton", SectionFrame)
                HeaderBtn.BackgroundTransparency = 1
                HeaderBtn.Size = UDim2.new(1, 0, 0, 34)
                HeaderBtn.Font = Enum.Font.GothamBold
                HeaderBtn.Text = "  " .. (title or "Section")
                HeaderBtn.TextColor3 = defaultOpen and COLOR_WHITE or COLOR_DARK_GRAY
                HeaderBtn.TextSize = CONFIG_FONT_SECTION
                HeaderBtn.TextXAlignment = Enum.TextXAlignment.Left

                local SectionArrow = Instance.new("ImageLabel", HeaderBtn)
                SectionArrow.BackgroundTransparency = 1
                SectionArrow.AnchorPoint = Vector2.new(1, 0.5)
                SectionArrow.Position = UDim2.new(1, -6, 0.5, 0)
                SectionArrow.Size = UDim2.new(0, 22, 0, 22)
                SectionArrow.Image = OrvionLib.Assets.Icons.Arrow
                SectionArrow.ImageTransparency = 0.4
                SectionArrow.Rotation = defaultOpen and 0 or -90

                local InnerContainer = Instance.new("Frame", SectionFrame)
                InnerContainer.BackgroundTransparency = 1
                InnerContainer.Position = UDim2.new(0, 0, 0, 34)
                InnerContainer.Size = UDim2.new(1, 0, 0, 0)

                local TheInnerLayout = Instance.new("UIListLayout", InnerContainer)
                TheInnerLayout.SortOrder = Enum.SortOrder.LayoutOrder
                TheInnerLayout.Padding = UDim.new(0, 5)
                TheInnerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
                local InnerPadding = Instance.new("UIPadding", InnerContainer)
                InnerPadding.PaddingLeft  = UDim.new(0, 0)
                InnerPadding.PaddingRight = UDim.new(0, 0)

                local isOpen = defaultOpen

                local function closeDropdown()
                    local existing = MainFrame:FindFirstChild("ActiveDropdown")
                    if existing then existing:Destroy() end
                    local oc = MainFrame:FindFirstChild("DropOutsideClick")
                    if oc then oc:Destroy() end
                end

                local function updateSize()
                    local contentHeight = TheInnerLayout.AbsoluteContentSize.Y + 8
                    if isOpen then
                        InnerContainer.Size = UDim2.new(1, 0, 0, contentHeight)
                        SectionFrame.Size = UDim2.new(1, 0, 0, 34 + contentHeight)
                        TweenService:Create(SectionArrow, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = 0}):Play()
                        TweenService:Create(HeaderBtn, TweenInfo.new(0.2), {TextColor3 = COLOR_WHITE}):Play()
                    else
                        InnerContainer.Size = UDim2.new(1, 0, 0, 0)
                        SectionFrame.Size = UDim2.new(1, 0, 0, 34)
                        TweenService:Create(SectionArrow, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Rotation = -90}):Play()
                        TweenService:Create(HeaderBtn, TweenInfo.new(0.2), {TextColor3 = COLOR_DARK_GRAY}):Play()
                    end
                end

                TheInnerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    if isOpen then updateSize() end
                end)

                HeaderBtn.MouseButton1Click:Connect(function()
                    closeDropdown()
                    isOpen = not isOpen
                    updateSize()
                end)

                updateSize()
                return createElementAPI(InnerContainer)
            end

            return ElementAPI
        end

        local mainTabAPI = createElementAPI(TabContent)
        for k, v in pairs(mainTabAPI) do TabAPI[k] = v end

        return TabAPI
    end

    -- ==========================================
    -- CONFIG TAB (generic, reusable)
    -- ==========================================
    -- options = {
    --   TabName   = "Configuration",          -- optional
    --   Folder    = "OrvionFishIt",           -- required (root folder)
    --   SubFolder = "Config",                 -- optional, default "Config"
    --   Settings  = {                          -- required
    --     { Key="AutoAccept",   Type="toggle",   Get=function() ... end, Set=function(v) ... end },
    --     { Key="ByName_Amount",Type="input",    Get=..., Set=... },
    --     { Key="TargetPlayer", Type="dropdown", Get=..., Set=... },
    --   },
    --   OnLoaded  = function(name) ... end,    -- optional callback
    -- }
    function Window:AddConfigTab(options)
        options = options or {}
        local HttpService = game:GetService("HttpService")

        local ROOT_FOLDER = options.Folder or "OrvionConfig"
        local SUB_FOLDER  = options.SubFolder or "Config"
        local CONFIG_DIR  = ROOT_FOLDER .. "/" .. SUB_FOLDER
        local AUTOLOAD_FILE = CONFIG_DIR .. "/_autoload.txt"
        local SETTINGS    = options.Settings or {}

        if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end
        if not isfolder(CONFIG_DIR)  then makefolder(CONFIG_DIR)  end

        local selectedConfigName = ""
        local inputConfigName    = ""

        local ConfigTab = Window:AddTab(options.TabName or "Configuration")

        local ConfigInfoParagraph = ConfigTab:AddParagraph({
            Title   = "Config Manager",
            Icon    = "rbxassetid://129719449898933",
            Content = "Current: None | Autoload: None"
        })

        ConfigTab:AddInput({
            Title       = "Config Name",
            Placeholder = "Enter config name...",
            Default     = "",
            Callback    = function(v) inputConfigName = v end
        })

        local function getExistingConfigs()
            local list = {}
            if isfolder(CONFIG_DIR) then
                for _, file in ipairs(listfiles(CONFIG_DIR)) do
                    if string.sub(file, -5) == ".json" then
                        local name = file:match("([^/\\]+)%.json$")
                        if name then table.insert(list, name) end
                    end
                end
            end
            table.sort(list)
            return list
        end

        local function getAutoloadName()
            if isfile(AUTOLOAD_FILE) then
                local c = readfile(AUTOLOAD_FILE)
                if c and c ~= "" then return c end
            end
            return "None"
        end

        local function updateConfigStatus()
            local cur = (selectedConfigName ~= "" and selectedConfigName ~= nil) and selectedConfigName or "None"
            ConfigInfoParagraph:SetDesc(string.format("Current: %s | Autoload: %s", cur, getAutoloadName()))
        end

        local function buildConfigData()
            local data = {}
            for _, s in ipairs(SETTINGS) do
                if s.Get then
                    local ok, v = pcall(s.Get)
                    if ok and v ~= nil and v ~= "" then
                        data[s.Key] = v
                    end
                end
            end
            return data
        end

        local function applyConfigData(decoded)
            for _, s in ipairs(SETTINGS) do
                local v = decoded[s.Key]
                if v ~= nil and s.Set then
                    pcall(s.Set, v)
                end
            end
        end

        local SelectConfigDropdown = ConfigTab:AddDropdown({
            Title        = "Select Config",
            Values       = getExistingConfigs(),
            DefaultValue = "Select Option",
            Callback     = function(v)
                if v and v ~= "" and v ~= "Select Option" then
                    selectedConfigName = v
                    updateConfigStatus()
                end
            end
        })

        ConfigTab:AddButtonGrid(
            {
                Title = "Save Config",
                Callback = function()
                    local targetName = inputConfigName ~= "" and inputConfigName or selectedConfigName
                    if not targetName or targetName == "" then
                        OrvionLib:Notify("Config Error", "Enter or select a config name first!", 3)
                        return
                    end
                    local filePath = CONFIG_DIR .. "/" .. targetName .. ".json"
                    local ok, encoded = pcall(function()
                        return HttpService:JSONEncode(buildConfigData())
                    end)
                    if ok then
                        writefile(filePath, encoded)
                        selectedConfigName = targetName
                        SelectConfigDropdown:SetValues(getExistingConfigs())
                        SelectConfigDropdown:SetValue(targetName)
                        updateConfigStatus()
                        OrvionLib:Notify("Config Manager", string.format("Config '%s' saved!", targetName), 3)
                    else
                        OrvionLib:Notify("Config Error", "Failed to encode config data!", 3)
                    end
                end
            },
            {
                Title = "Load Config",
                Callback = function()
                    if not selectedConfigName or selectedConfigName == "" then
                        OrvionLib:Notify("Config Error", "Please select a config first!", 3)
                        return
                    end
                    local filePath = CONFIG_DIR .. "/" .. selectedConfigName .. ".json"
                    if isfile(filePath) then
                        local ok, decoded = pcall(function()
                            return HttpService:JSONDecode(readfile(filePath))
                        end)
                        if ok and type(decoded) == "table" then
                            applyConfigData(decoded)
                            updateConfigStatus()
                            if options.OnLoaded then pcall(options.OnLoaded, selectedConfigName) end
                            OrvionLib:Notify("Config Manager", string.format("Config '%s' loaded!", selectedConfigName), 3)
                        else
                            OrvionLib:Notify("Config Error", "Failed to decode config file!", 3)
                        end
                    else
                        OrvionLib:Notify("Config Error", "Config file not found!", 3)
                    end
                end
            }
        )

        ConfigTab:AddButtonGrid(
            {
                Title = "Delete Config",
                Callback = function()
                    if not selectedConfigName or selectedConfigName == "" then
                        OrvionLib:Notify("Config Error", "Please select a config first!", 3)
                        return
                    end
                    local filePath = CONFIG_DIR .. "/" .. selectedConfigName .. ".json"
                    if isfile(filePath) then
                        delfile(filePath)
                        local deletedName = selectedConfigName
                        selectedConfigName = ""
                        SelectConfigDropdown:SetValues(getExistingConfigs())
                        updateConfigStatus()
                        OrvionLib:Notify("Config Manager", string.format("Config '%s' deleted!", deletedName), 3)
                    else
                        OrvionLib:Notify("Config Error", "Config file not found!", 3)
                    end
                end
            },
            {
                Title = "Set Autoload",
                Callback = function()
                    if not selectedConfigName or selectedConfigName == "" then
                        OrvionLib:Notify("Config Error", "Please select a config first!", 3)
                        return
                    end
                    writefile(AUTOLOAD_FILE, selectedConfigName)
                    updateConfigStatus()
                    OrvionLib:Notify("Config Manager", string.format("Autoload set to '%s'!", selectedConfigName), 3)
                end
            }
        )

        ConfigTab:AddButtonGrid(
            {
                Title = "Refresh List",
                Callback = function()
                    SelectConfigDropdown:SetValues(getExistingConfigs())
                    updateConfigStatus()
                    OrvionLib:Notify("Config Manager", "Config list refreshed!", 3)
                end
            },
            {
                Title = "Clear Autoload",
                Callback = function()
                    if isfile(AUTOLOAD_FILE) then
                        writefile(AUTOLOAD_FILE, "")
                    end
                    updateConfigStatus()
                    OrvionLib:Notify("Config Manager", "Autoload cleared!", 3)
                end
            }
        )

        -- Autoload on startup
        task.spawn(function()
            task.wait(1)
            if isfolder(CONFIG_DIR) and isfile(AUTOLOAD_FILE) then
                local autoloadName = readfile(AUTOLOAD_FILE)
                if autoloadName and autoloadName ~= "" then
                    local filePath = CONFIG_DIR .. "/" .. autoloadName .. ".json"
                    if isfile(filePath) then
                        local ok, decoded = pcall(function()
                            return HttpService:JSONDecode(readfile(filePath))
                        end)
                        if ok and type(decoded) == "table" then
                            applyConfigData(decoded)
                            selectedConfigName = autoloadName
                            SelectConfigDropdown:SetValues(getExistingConfigs())
                            SelectConfigDropdown:SetValue(autoloadName)
                            updateConfigStatus()
                            if options.OnLoaded then pcall(options.OnLoaded, autoloadName) end
                            OrvionLib:Notify("Autoload", string.format("Successfully loaded config '%s'!", autoloadName), 4)
                        end
                    end
                end
            end
        end)

        return ConfigTab
    end

    return Window
end

return OrvionLib
