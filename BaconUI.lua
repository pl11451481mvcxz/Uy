-- ============================================================
-- BaconUI - 高质量 UI 库
-- 风格：圆角 / 白色羽化边框 / Wind 图标 / 高质量通知 / 悬浮最小化
-- 手机端适配：触摸拖动 / 滑块防冲突 / 滚动条动态变宽
-- 用法：
--   local UI = loadstring(game:HttpGet("你的库地址"))()
--   local Win = UI:CreateWindow({ Title = "Bacon Hub" })
--   local Tab = Win:CreateTab("玩家", UI.Icons.player)
--   Tab:CreateToggle({ Name = "穿墙", Icon = UI.Icons.noclip, Callback = function(s) end })
--   Tab:CreateSlider({ Name = "速度", Min = 16, Max = 200, Default = 16 })
--   Tab:CreateButton({ Name = "重置", Callback = function() end })
--   Win:Notify("标题", "内容", 3, "success")
--   Win:Minimize()   -- 最小化到悬浮按钮
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local BaconUI = {}

-- 默认配置
BaconUI.Config = {
    AccentColor = Color3.fromRGB(30, 110, 240),
    AccentLight = Color3.fromRGB(80, 150, 255),
    BgColor = Color3.fromRGB(22, 22, 26),
    PanelColor = Color3.fromRGB(32, 32, 38),
    TextColor = Color3.fromRGB(255, 255, 255),
    SubTextColor = Color3.fromRGB(170, 170, 180),
    CornerRadius = 10,
    StrokeTransparency = 0.55,
    SuccessColor = Color3.fromRGB(0, 190, 100),
    ErrorColor = Color3.fromRGB(230, 60, 60),
    WarnColor = Color3.fromRGB(240, 170, 30),
    SkipColor = Color3.fromRGB(130, 60, 220),
}

-- 内置 Wind 图标
BaconUI.Icons = {
    noclip  = "rbxassetid://6031091004",
    speed   = "rbxassetid://6031094667",
    jump    = "rbxassetid://6031075931",
    reset   = "rbxassetid://6031090990",
    gravity = "rbxassetid://6031075938",
    day     = "rbxassetid://6031075941",
    night   = "rbxassetid://6031091004",
    close   = "rbxassetid://6031090990",
    info    = "rbxassetid://6031075938",
    player  = "rbxassetid://6031094667",
    world   = "rbxassetid://6031075938",
    misc    = "rbxassetid://6031090990",
    success = "rbxassetid://6031090996",
    error   = "rbxassetid://6031090990",
    warn    = "rbxassetid://6031075931",
    skip    = "rbxassetid://6031094667",
}

local C = BaconUI.Config

-- ============================================================
-- 内部工具
-- ============================================================
local function getViewport()
    local cam = workspace.CurrentCamera
    if not cam then return Vector2.new(800, 600) end
    return cam.ViewportSize
end

local function applyStyle(element, opts)
    opts = opts or {}
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, opts.Radius or C.CornerRadius)
    corner.Parent = element
    if opts.Stroke ~= false then
        local stroke = Instance.new("UIStroke")
        stroke.Color = opts.StrokeColor or Color3.fromRGB(255, 255, 255)
        stroke.Thickness = opts.StrokeThickness or 1.5
        stroke.Transparency = opts.StrokeTransparency or C.StrokeTransparency
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = element
        return corner, stroke
    end
    return corner, nil
end

local function tween(obj, props, time, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(
        time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out
    ), props)
    t:Play()
    return t
end

-- ============================================================
-- 通知系统（全局独立 GUI，多窗口共享）
-- ============================================================
local NotifyGui
local NotifyHolder
local notifyOrder = 0
local activeNotifies = {}

local function ensureNotifyGui()
    if NotifyGui and NotifyGui.Parent then return end
    NotifyGui = Instance.new("ScreenGui")
    NotifyGui.Name = "BaconUINotify"
    NotifyGui.ResetOnSpawn = false
    NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    NotifyGui.IgnoreGuiInset = true
    local ok = pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(NotifyGui) end
        NotifyGui.Parent = game:GetService("CoreGui")
    end)
    if not ok or not NotifyGui.Parent then
        NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    NotifyHolder = Instance.new("Frame")
    NotifyHolder.AnchorPoint = Vector2.new(1, 0)
    NotifyHolder.Position = UDim2.new(1, -12, 0, 12)
    NotifyHolder.Size = UDim2.fromOffset(0, 0)
    NotifyHolder.BackgroundTransparency = 1
    NotifyHolder.ZIndex = 100
    NotifyHolder.Parent = NotifyGui

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.VerticalAlignment = Enum.VerticalAlignment.Top
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.Padding = UDim.new(0, 8)
    list.Parent = NotifyHolder

    getgenv().BaconUINotifyGui = NotifyGui
end

local TYPE_COLORS = {
    success = C.SuccessColor,
    error   = C.ErrorColor,
    warn    = C.WarnColor,
    info    = C.AccentColor,
    skip    = C.SkipColor,
}
local TYPE_ICONS = {
    success = BaconUI.Icons.success,
    error   = BaconUI.Icons.error,
    warn    = BaconUI.Icons.warn,
    info    = BaconUI.Icons.info,
    skip    = BaconUI.Icons.skip,
}

function BaconUI:Notify(title, text, duration, nType)
    ensureNotifyGui()
    duration = duration or 4
    nType = nType or "info"
    local color = TYPE_COLORS[nType] or C.AccentColor
    local iconId = TYPE_ICONS[nType] or BaconUI.Icons.info

    if #activeNotifies >= 4 then
        local oldest = table.remove(activeNotifies, 1)
        if oldest and oldest.Parent then pcall(function() oldest:Destroy() end) end
    end

    notifyOrder += 1
    local Card = Instance.new("Frame")
    Card.Size = UDim2.fromOffset(280, 64)
    Card.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    Card.BackgroundTransparency = 0.05
    Card.BorderSizePixel = 0
    Card.ZIndex = 101
    Card.LayoutOrder = notifyOrder
    Card.Parent = NotifyHolder
    table.insert(activeNotifies, Card)

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 10)
    cc.Parent = Card

    local cs = Instance.new("UIStroke")
    cs.Color = Color3.fromRGB(255, 255, 255)
    cs.Thickness = 1.5
    cs.Transparency = 1
    cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    cs.Parent = Card

    local AccentBar = Instance.new("Frame")
    AccentBar.Size = UDim2.new(0, 4, 1, -16)
    AccentBar.Position = UDim2.new(0, 8, 0, 8)
    AccentBar.BackgroundColor3 = color
    AccentBar.BorderSizePixel = 0
    AccentBar.ZIndex = 102
    AccentBar.Parent = Card
    local abc = Instance.new("UICorner")
    abc.CornerRadius = UDim.new(1, 0)
    abc.Parent = AccentBar

    local Icon = Instance.new("ImageLabel")
    Icon.Size = UDim2.fromOffset(22, 22)
    Icon.Position = UDim2.new(0, 20, 0, 10)
    Icon.BackgroundColor3 = color
    Icon.BackgroundTransparency = 1
    Icon.Image = iconId
    Icon.ImageColor3 = color
    Icon.ImageTransparency = 1
    Icon.ZIndex = 102
    Icon.Parent = Card
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(1, 0)
    ic.Parent = Icon

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -80, 0, 16)
    TitleLbl.Position = UDim2.new(0, 50, 0, 8)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = title or ""
    TitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLbl.TextSize = 12
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.TextTransparency = 1
    TitleLbl.ZIndex = 102
    TitleLbl.Parent = Card

    local TextLbl = Instance.new("TextLabel")
    TextLbl.Size = UDim2.new(1, -80, 0, 28)
    TextLbl.Position = UDim2.new(0, 50, 0, 26)
    TextLbl.BackgroundTransparency = 1
    TextLbl.Text = text or ""
    TextLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    TextLbl.TextSize = 10
    TextLbl.Font = Enum.Font.Gotham
    TextLbl.TextXAlignment = Enum.TextXAlignment.Left
    TextLbl.TextYAlignment = Enum.TextYAlignment.Top
    TextLbl.TextWrapped = true
    TextLbl.TextTransparency = 1
    TextLbl.ZIndex = 102
    TextLbl.Parent = Card

    local CloseX = Instance.new("TextButton")
    CloseX.Size = UDim2.fromOffset(18, 18)
    CloseX.Position = UDim2.new(1, -24, 0, 8)
    CloseX.BackgroundTransparency = 1
    CloseX.Text = "×"
    CloseX.TextColor3 = Color3.fromRGB(160, 160, 160)
    CloseX.TextSize = 16
    CloseX.Font = Enum.Font.GothamBold
    CloseX.AutoButtonColor = false
    CloseX.TextTransparency = 1
    CloseX.ZIndex = 103
    CloseX.Parent = Card

    local ProgressBg = Instance.new("Frame")
    ProgressBg.Size = UDim2.new(1, -16, 0, 2)
    ProgressBg.Position = UDim2.new(0, 8, 1, -5)
    ProgressBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    ProgressBg.BackgroundTransparency = 1
    ProgressBg.BorderSizePixel = 0
    ProgressBg.ZIndex = 102
    ProgressBg.Parent = Card
    local pbc = Instance.new("UICorner")
    pbc.CornerRadius = UDim.new(1, 0)
    pbc.Parent = ProgressBg

    local ProgressFill = Instance.new("Frame")
    ProgressFill.Size = UDim2.new(1, 0, 1, 0)
    ProgressFill.BackgroundColor3 = color
    ProgressFill.BorderSizePixel = 0
    ProgressFill.ZIndex = 103
    ProgressFill.Parent = ProgressBg
    local pfc = Instance.new("UICorner")
    pfc.CornerRadius = UDim.new(1, 0)
    pfc.Parent = ProgressFill

    Card.Size = UDim2.fromOffset(0, 64)
    Card.BackgroundTransparency = 1

    tween(Card, { Size = UDim2.fromOffset(280, 64), BackgroundTransparency = 0.05 }, 0.35, Enum.EasingStyle.Back)
    tween(cs, { Transparency = 0.65 }, 0.35)
    tween(Icon, { BackgroundTransparency = 0.85, ImageTransparency = 0 }, 0.3)
    tween(TitleLbl, { TextTransparency = 0 }, 0.3)
    tween(TextLbl, { TextTransparency = 0 }, 0.3)
    tween(CloseX, { TextTransparency = 0 }, 0.3)
    tween(ProgressBg, { BackgroundTransparency = 0 }, 0.3)
    TweenService:Create(ProgressFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.fromScale(0, 1)
    }):Play()

    local removed = false
    local function remove()
        if removed then return end
        removed = true
        for i, v in ipairs(activeNotifies) do
            if v == Card then table.remove(activeNotifies, i) break end
        end
        tween(Card, { Size = UDim2.fromOffset(0, 64), BackgroundTransparency = 1 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(TitleLbl, { TextTransparency = 1 }, 0.2)
        tween(TextLbl, { TextTransparency = 1 }, 0.2)
        tween(CloseX, { TextTransparency = 1 }, 0.2)
        tween(cs, { Transparency = 1 }, 0.2)
        task.delay(0.3, function()
            if Card and Card.Parent then pcall(function() Card:Destroy() end) end
        end)
    end
    CloseX.MouseButton1Click:Connect(remove)
    task.delay(duration, remove)
    return Card
end

function BaconUI:NotifySuccess(t, x, d) return self:Notify(t, x, d, "success") end
function BaconUI:NotifyError(t, x, d) return self:Notify(t, x, d, "error") end
function BaconUI:NotifyWarn(t, x, d) return self:Notify(t, x, d, "warn") end
function BaconUI:NotifyInfo(t, x, d) return self:Notify(t, x, d, "info") end

-- ============================================================
-- 创建窗口
-- ============================================================
function BaconUI:CreateWindow(cfg)
    cfg = cfg or {}
    local titleText = cfg.Title or "Bacon UI"
    local vp = getViewport()
    local uiWidth = cfg.Width or math.clamp(vp.X * 0.85, 280, 360)
    local uiHeight = cfg.Height or math.clamp(vp.Y * 0.62, 360, 500)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BaconUI_" .. tostring(os.time())
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    local ok = pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
        ScreenGui.Parent = game:GetService("CoreGui")
    end)
    if not ok or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- 主窗口
    local Main = Instance.new("Frame")
    Main.Size = UDim2.fromOffset(uiWidth, uiHeight)
    Main.Position = UDim2.new(0.5, -uiWidth/2, 0.5, -uiHeight/2)
    Main.BackgroundColor3 = C.BgColor
    Main.BackgroundTransparency = 0.05
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = true
    Main.Active = true
    Main.Parent = ScreenGui
    applyStyle(Main, { Radius = 14, StrokeThickness = 2 })

    -- 顶部栏
    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 46)
    TopBar.BackgroundColor3 = C.PanelColor
    TopBar.BackgroundTransparency = 0.1
    TopBar.BorderSizePixel = 0
    TopBar.Active = true
    TopBar.Parent = Main
    applyStyle(TopBar, { Radius = 14, Stroke = false })

    local TopBarFix = Instance.new("Frame")
    TopBarFix.Size = UDim2.new(1, 0, 0, 14)
    TopBarFix.Position = UDim2.new(0, 0, 1, -14)
    TopBarFix.BackgroundColor3 = C.PanelColor
    TopBarFix.BackgroundTransparency = 0.1
    TopBarFix.BorderSizePixel = 0
    TopBarFix.Parent = TopBar

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -160, 1, 0)
    Title.Position = UDim2.fromOffset(16, 0)
    Title.BackgroundTransparency = 1
    Title.Text = titleText
    Title.TextColor3 = C.TextColor
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.fromOffset(8, 8)
    StatusDot.Position = UDim2.new(1, -132, 0.5, -4)
    StatusDot.BackgroundColor3 = C.SuccessColor
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = TopBar
    local sdc = Instance.new("UICorner")
    sdc.CornerRadius = UDim.new(1, 0)
    sdc.Parent = StatusDot

    local StatusText = Instance.new("TextLabel")
    StatusText.Size = UDim2.fromOffset(52, 20)
    StatusText.Position = UDim2.new(1, -122, 0.5, -10)
    StatusText.BackgroundTransparency = 1
    StatusText.Text = "在线"
    StatusText.TextColor3 = C.SuccessColor
    StatusText.TextSize = 10
    StatusText.Font = Enum.Font.Gotham
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.Parent = TopBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.fromOffset(30, 30)
    MinBtn.Position = UDim2.new(1, -78, 0.5, -15)
    MinBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
    MinBtn.BackgroundTransparency = 0.3
    MinBtn.Text = "−"
    MinBtn.TextColor3 = Color3.fromRGB(150, 180, 255)
    MinBtn.TextSize = 20
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.AutoButtonColor = false
    MinBtn.Active = true
    MinBtn.Parent = TopBar
    applyStyle(MinBtn, { Radius = 8, Stroke = false })

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.fromOffset(30, 30)
    CloseBtn.Position = UDim2.new(1, -40, 0.5, -15)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
    CloseBtn.BackgroundTransparency = 0.3
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    CloseBtn.TextSize = 20
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.AutoButtonColor = false
    CloseBtn.Active = true
    CloseBtn.Parent = TopBar
    applyStyle(CloseBtn, { Radius = 8, Stroke = false })

    -- 拖动窗口
    do
        local dragging = false
        local dragStart, startPos
        TopBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Main.Position
            end
        end)
        TopBar.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                Main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end)
        TopBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    -- Tab 栏
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -24, 0, 32)
    TabBar.Position = UDim2.fromOffset(12, 56)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = Main

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0, 6)
    TabLayout.Parent = TabBar

    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -24, 1, -106)
    Content.Position = UDim2.fromOffset(12, 96)
    Content.BackgroundTransparency = 1
    Content.Parent = Main

    local ContentScroll = Instance.new("ScrollingFrame")
    ContentScroll.Size = UDim2.fromScale(1, 1)
    ContentScroll.BackgroundTransparency = 1
    ContentScroll.BorderSizePixel = 0
    ContentScroll.ScrollBarThickness = 3
    ContentScroll.ScrollBarImageColor3 = C.AccentColor
    ContentScroll.ScrollBarImageTransparency = 0.2
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ContentScroll.ScrollingEnabled = true
    ContentScroll.Active = true
    ContentScroll.Parent = Content

    local ContentLayout = Instance.new("UIListLayout")
    ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContentLayout.Padding = UDim.new(0, 8)
    ContentLayout.Parent = ContentScroll

    -- 滚动条动态变宽
    local scrollDragging = false
    ContentScroll.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseWheel then
            scrollDragging = true
            tween(ContentScroll, { ScrollBarThickness = 6, ScrollBarImageTransparency = 0 }, 0.15)
        end
    end)
    ContentScroll.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseWheel then
            scrollDragging = false
            task.delay(0.3, function()
                if not scrollDragging then
                    tween(ContentScroll, { ScrollBarThickness = 3, ScrollBarImageTransparency = 0.2 }, 0.25)
                end
            end)
        end
    end)

    -- 窗口 API
    local Window = {}
    Window.Gui = ScreenGui
    Window.Frame = Main
    local tabs = {}
    local tabRefs = {}
    local currentTab = nil
    local pages = {}

    Window.SetStatus = function(text, color)
        StatusText.Text = text or "在线"
        StatusText.TextColor3 = color or C.SuccessColor
        StatusDot.BackgroundColor3 = color or C.SuccessColor
    end

    Window.CreateTab = function(name, iconId)
        local tab = Instance.new("TextButton")
        tab.Size = UDim2.fromOffset(80, 32)
        tab.BackgroundColor3 = C.PanelColor
        tab.BackgroundTransparency = 0.4
        tab.Text = ""
        tab.AutoButtonColor = false
        tab.LayoutOrder = #tabs + 1
        tab.Active = true
        tab.Parent = TabBar
        applyStyle(tab, { Radius = 8, StrokeTransparency = 0.7 })

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.fromOffset(14, 14)
        icon.Position = UDim2.fromOffset(10, 9)
        icon.BackgroundTransparency = 1
        icon.Image = iconId or BaconUI.Icons.misc
        icon.ImageColor3 = C.SubTextColor
        icon.Parent = tab

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -30, 1, 0)
        lbl.Position = UDim2.fromOffset(28, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name or "Tab"
        lbl.TextColor3 = C.SubTextColor
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = tab

        local page = Instance.new("Frame")
        page.Size = UDim2.new(1, -6, 1, 0)
        page.BackgroundTransparency = 1
        page.LayoutOrder = #tabs + 1
        page.Visible = false
        page.Parent = ContentScroll
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        table.insert(tabs, tab)
        tabRefs[tab] = { icon = icon, label = lbl }
        pages[tab] = page

        local function switchTo()
            for b, pg in pairs(pages) do
                local active = (b == tab)
                pg.Visible = active
                tween(b, {
                    BackgroundColor3 = active and C.AccentColor or C.PanelColor,
                    BackgroundTransparency = active and 0 or 0.4,
                }, 0.2)
                local ref = tabRefs[b]
                if ref then
                    tween(ref.icon, { ImageColor3 = active and Color3.fromRGB(255,255,255) or C.SubTextColor }, 0.2)
                    tween(ref.label, { TextColor3 = active and Color3.fromRGB(255,255,255) or C.SubTextColor }, 0.2)
                end
            end
            ContentScroll.CanvasPosition = Vector2.new(0, 0)
            currentTab = tab
        end

        tab.MouseButton1Click:Connect(switchTo)

        local Tab = {}
        Tab.Page = page
        Tab.Show = switchTo

        -- 控件创建
        Tab.CreateSection = function(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Text = text or "Section"
            lbl.TextColor3 = C.AccentColor
            lbl.TextSize = 11
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.LayoutOrder = #page:GetChildren()
            lbl.Parent = page
            return lbl
        end

        Tab.CreateToggle = function(tcfg)
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 44)
            container.BackgroundColor3 = C.PanelColor
            container.BackgroundTransparency = 0.2
            container.LayoutOrder = #page:GetChildren()
            container.Active = true
            container.Parent = page
            applyStyle(container, { Radius = 8 })

            if tcfg.Icon then
                local icon = Instance.new("ImageLabel")
                icon.Size = UDim2.fromOffset(18, 18)
                icon.Position = UDim2.fromOffset(12, 13)
                icon.BackgroundTransparency = 1
                icon.Image = tcfg.Icon
                icon.ImageColor3 = C.AccentColor
                icon.Parent = container
            end

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -80, 1, 0)
            lbl.Position = UDim2.fromOffset(tcfg.Icon and 38 or 14, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = tcfg.Name or "Toggle"
            lbl.TextColor3 = C.TextColor
            lbl.TextSize = 12
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = container

            local track = Instance.new("Frame")
            track.Size = UDim2.fromOffset(42, 24)
            track.Position = UDim2.new(1, -56, 0.5, -12)
            track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            track.BorderSizePixel = 0
            track.Parent = container
            applyStyle(track, { Radius = 12, Stroke = false })

            local knob = Instance.new("Frame")
            knob.Size = UDim2.fromOffset(18, 18)
            knob.Position = UDim2.fromOffset(3, 3)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.BorderSizePixel = 0
            knob.Parent = track
            applyStyle(knob, { Radius = 9, Stroke = false })

            local clickBtn = Instance.new("TextButton")
            clickBtn.Size = UDim2.fromScale(1, 1)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Text = ""
            clickBtn.Active = true
            clickBtn.Parent = container

            local state = tcfg.Default or false
            local function update()
                tween(track, { BackgroundColor3 = state and C.AccentColor or Color3.fromRGB(60, 60, 70) }, 0.2)
                tween(knob, { Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3) }, 0.2)
            end
            update()

            clickBtn.MouseButton1Click:Connect(function()
                state = not state
                update()
                if tcfg.Callback then pcall(tcfg.Callback, state) end
            end)

            return {
                Set = function(v) state = v; update(); if tcfg.Callback then pcall(tcfg.Callback, state) end end,
                Get = function() return state end
            }
        end

        Tab.CreateSlider = function(scfg)
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, 58)
            container.BackgroundColor3 = C.PanelColor
            container.BackgroundTransparency = 0.2
            container.LayoutOrder = #page:GetChildren()
            container.Active = true
            container.Parent = page
            applyStyle(container, { Radius = 8 })

            if scfg.Icon then
                local icon = Instance.new("ImageLabel")
                icon.Size = UDim2.fromOffset(18, 18)
                icon.Position = UDim2.fromOffset(12, 10)
                icon.BackgroundTransparency = 1
                icon.Image = scfg.Icon
                icon.ImageColor3 = C.AccentColor
                icon.Parent = container
            end

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -24, 0, 18)
            lbl.Position = UDim2.fromOffset(scfg.Icon and 38 or 14, 8)
            lbl.BackgroundTransparency = 1
            lbl.Text = (scfg.Name or "Slider") .. ": " .. tostring(scfg.Default or scfg.Min)
            lbl.TextColor3 = C.TextColor
            lbl.TextSize = 11
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = container

            local touchArea = Instance.new("Frame")
            touchArea.Size = UDim2.new(1, -24, 0, 26)
            touchArea.Position = UDim2.fromOffset(12, 28)
            touchArea.BackgroundTransparency = 1
            touchArea.Active = true
            touchArea.Parent = container

            local barBg = Instance.new("Frame")
            barBg.Size = UDim2.new(1, 0, 0, 8)
            barBg.Position = UDim2.new(0, 0, 0.5, -4)
            barBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            barBg.BorderSizePixel = 0
            barBg.Parent = touchArea
            applyStyle(barBg, { Radius = 4, Stroke = false })

            local fill = Instance.new("Frame")
            fill.Size = UDim2.fromScale(0, 1)
            fill.BackgroundColor3 = C.AccentColor
            fill.BorderSizePixel = 0
            fill.Parent = barBg
            applyStyle(fill, { Radius = 4, Stroke = false })

            local grad = Instance.new("UIGradient")
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, C.AccentLight),
                ColorSequenceKeypoint.new(1, C.AccentColor),
            })
            grad.Parent = fill

            local knob = Instance.new("Frame")
            knob.Size = UDim2.fromOffset(18, 18)
            knob.AnchorPoint = Vector2.new(0.5, 0.5)
            knob.Position = UDim2.new(0, 0, 0.5, 0)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.BorderSizePixel = 0
            knob.ZIndex = 3
            knob.Parent = touchArea
            applyStyle(knob, { Radius = 9, Stroke = false })
            local ks = Instance.new("UIStroke")
            ks.Color = C.AccentColor
            ks.Thickness = 1.5
            ks.Transparency = 0.4
            ks.Parent = knob

            local clickBtn = Instance.new("TextButton")
            clickBtn.Size = UDim2.fromScale(1, 1)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Text = ""
            clickBtn.Active = true
            clickBtn.ZIndex = 5
            clickBtn.Parent = touchArea

            local minV, maxV = scfg.Min or 0, scfg.Max or 100
            local current = scfg.Default or minV
            local dragging = false

            local function updateFromX(x)
                local rel = math.clamp((x - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                local val = minV + (maxV - minV) * rel
                if scfg.Step then val = math.floor(val / scfg.Step + 0.5) * scfg.Step end
                val = math.clamp(val, minV, maxV)
                current = val
                local pct = (val - minV) / (maxV - minV)
                fill.Size = UDim2.fromScale(pct, 1)
                knob.Position = UDim2.new(pct, 0, 0.5, 0)
                lbl.Text = (scfg.Name or "Slider") .. ": " .. tostring(val)
                if scfg.Callback then pcall(scfg.Callback, val) end
            end

            clickBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    ContentScroll.ScrollingEnabled = false
                    updateFromX(input.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    updateFromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    if dragging then
                        dragging = false
                        ContentScroll.ScrollingEnabled = true
                    end
                end
            end)

            local initPct = (current - minV) / (maxV - minV)
            fill.Size = UDim2.fromScale(initPct, 1)
            knob.Position = UDim2.new(initPct, 0, 0.5, 0)

            return {
                Set = function(v)
                    v = math.clamp(v, minV, maxV)
                    current = v
                    local pct = (v - minV) / (maxV - minV)
                    fill.Size = UDim2.fromScale(pct, 1)
                    knob.Position = UDim2.new(pct, 0, 0.5, 0)
                    lbl.Text = (scfg.Name or "Slider") .. ": " .. tostring(v)
                    if scfg.Callback then pcall(scfg.Callback, v) end
                end,
                Get = function() return current end
            }
        end

        Tab.CreateButton = function(bcfg)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 42)
            btn.BackgroundColor3 = bcfg.Color or C.PanelColor
            btn.BackgroundTransparency = 0.15
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.LayoutOrder = #page:GetChildren()
            btn.Active = true
            btn.Parent = page
            applyStyle(btn, { Radius = 8 })

            if bcfg.Icon then
                local icon = Instance.new("ImageLabel")
                icon.Size = UDim2.fromOffset(18, 18)
                icon.Position = UDim2.fromOffset(12, 12)
                icon.BackgroundTransparency = 1
                icon.Image = bcfg.Icon
                icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                icon.Parent = btn
            end

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -40, 1, 0)
            lbl.Position = UDim2.fromOffset(bcfg.Icon and 38 or 14, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = bcfg.Name or "Button"
            lbl.TextColor3 = C.TextColor
            lbl.TextSize = 12
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = btn

            local baseColor = btn.BackgroundColor3
            btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = baseColor:Lerp(Color3.new(1,1,1), 0.12) }, 0.15) end)
            btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = baseColor }, 0.15) end)
            btn.MouseButton1Down:Connect(function() tween(btn, { BackgroundColor3 = baseColor:Lerp(Color3.new(1,1,1), 0.2) }, 0.08) end)
            btn.MouseButton1Up:Connect(function() tween(btn, { BackgroundColor3 = baseColor }, 0.12) end)
            btn.MouseButton1Click:Connect(function()
                if bcfg.Callback then pcall(bcfg.Callback) end
            end)
            return btn
        end

        Tab.CreateLabel = function(lcfg)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, lcfg.Height or 40)
            lbl.BackgroundColor3 = lcfg.Color or C.PanelColor
            lbl.BackgroundTransparency = 0.2
            lbl.Text = lcfg.Text or "Label"
            lbl.TextColor3 = lcfg.TextColor or C.SubTextColor
            lbl.TextSize = lcfg.TextSize or 10
            lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextYAlignment = Enum.TextYAlignment.Top
            lbl.TextWrapped = true
            lbl.LayoutOrder = #page:GetChildren()
            lbl.Parent = page
            applyStyle(lbl, { Radius = 8 })
            return lbl
        end

        return Tab
    end

    -- 最小化悬浮按钮
    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Size = UDim2.fromOffset(56, 56)
    FloatBtn.Position = UDim2.new(1, -76, 0.5, -28)
    FloatBtn.BackgroundColor3 = C.BgColor
    FloatBtn.BackgroundTransparency = 0.05
    FloatBtn.Text = titleText:sub(1,1)
    FloatBtn.TextColor3 = C.AccentColor
    FloatBtn.TextSize = 22
    FloatBtn.Font = Enum.Font.GothamBlack
    FloatBtn.AutoButtonColor = false
    FloatBtn.Active = true
    FloatBtn.Visible = false
    FloatBtn.Parent = ScreenGui
    applyStyle(FloatBtn, { Radius = 28, StrokeThickness = 2, StrokeTransparency = 0.4 })

    local GlowRing = Instance.new("Frame")
    GlowRing.Size = UDim2.fromScale(1, 1)
    GlowRing.AnchorPoint = Vector2.new(0.5, 0.5)
    GlowRing.Position = UDim2.fromScale(0.5, 0.5)
    GlowRing.BackgroundTransparency = 1
    GlowRing.BorderSizePixel = 0
    GlowRing.ZIndex = 0
    GlowRing.Parent = FloatBtn
    local gc = Instance.new("UICorner")
    gc.CornerRadius = UDim.new(1, 0)
    gc.Parent = GlowRing
    local gs = Instance.new("UIStroke")
    gs.Color = C.AccentColor
    gs.Thickness = 2
    gs.Transparency = 0.5
    gs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    gs.Parent = GlowRing

    RunService.Heartbeat:Connect(function()
        if not FloatBtn or not FloatBtn.Parent or not FloatBtn.Visible then return end
        local pulse = (math.sin(tick() * 2.5) + 1) / 2
        gs.Transparency = 0.3 + pulse * 0.5
        gs.Thickness = 2 + pulse * 2
        GlowRing.Size = UDim2.fromScale(1 + pulse * 0.08, 1 + pulse * 0.08)
    end)

    local innerGlow = Instance.new("Frame")
    innerGlow.Size = UDim2.fromScale(0.7, 0.7)
    innerGlow.AnchorPoint = Vector2.new(0.5, 0.5)
    innerGlow.Position = UDim2.fromScale(0.5, 0.5)
    innerGlow.BackgroundColor3 = C.AccentColor
    innerGlow.BackgroundTransparency = 0.85
    innerGlow.BorderSizePixel = 0
    innerGlow.ZIndex = 1
    innerGlow.Parent = FloatBtn
    local igc = Instance.new("UICorner")
    igc.CornerRadius = UDim.new(1, 0)
    igc.Parent = innerGlow

    local restoreFromFloat
    local floatDragging = false
    local floatDragStart, floatStartPos
    local dragThreshold = 8
    local dragMoved = false

    FloatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            floatDragging = true
            dragMoved = false
            floatDragStart = input.Position
            floatStartPos = FloatBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if floatDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - floatDragStart
            if math.abs(d.X) > dragThreshold or math.abs(d.Y) > dragThreshold then dragMoved = true end
            FloatBtn.Position = UDim2.new(
                floatStartPos.X.Scale, floatStartPos.X.Offset + d.X,
                floatStartPos.Y.Scale, floatStartPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if floatDragging then
                floatDragging = false
                if not dragMoved then
                    if restoreFromFloat then restoreFromFloat() end
                else
                    local vp2 = getViewport()
                    local abs = FloatBtn.AbsolutePosition
                    local size = FloatBtn.AbsoluteSize
                    local cx = math.clamp(abs.X, 0, vp2.X - size.X)
                    local cy = math.clamp(abs.Y, 0, vp2.Y - size.Y)
                    if cx ~= abs.X or cy ~= abs.Y then
                        tween(FloatBtn, { Position = UDim2.fromOffset(cx, cy) }, 0.15)
                    end
                end
            end
        end
    end)

    FloatBtn.MouseButton1Down:Connect(function() tween(FloatBtn, { Size = UDim2.fromOffset(50, 50) }, 0.08) end)
    FloatBtn.MouseButton1Up:Connect(function() tween(FloatBtn, { Size = UDim2.fromOffset(56, 56) }, 0.12) end)

    local isMinimized = false

    Window.Minimize = function()
        if isMinimized then return end
        isMinimized = true
        local mainPos = Main.Position
        local floatAbs = FloatBtn.AbsolutePosition

        tween(Main, {
            Size = UDim2.fromOffset(0, 0),
            Position = UDim2.new(0, floatAbs.X, 0, floatAbs.Y),
            BackgroundTransparency = 1
        }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)

        task.delay(0.28, function()
            Main.Visible = false
            FloatBtn.Visible = true
            FloatBtn.Size = UDim2.fromOffset(0, 0)
            tween(FloatBtn, { Size = UDim2.fromOffset(56, 56) }, 0.35, Enum.EasingStyle.Back)
        end)

        getgenv()["BaconUI_LastPos_" .. tostring(ScreenGui)] = mainPos
        BaconUI:NotifyInfo("最小化", "UI 已最小化到悬浮按钮", 2)
    end

    restoreFromFloat = function()
        if not isMinimized then return end
        isMinimized = false
        tween(FloatBtn, { Size = UDim2.fromOffset(0, 0) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.2, function() FloatBtn.Visible = false end)

        local restorePos = getgenv()["BaconUI_LastPos_" .. tostring(ScreenGui)] or UDim2.new(0.5, -uiWidth/2, 0.5, -uiHeight/2)
        Main.Position = restorePos
        Main.Size = UDim2.fromOffset(0, 0)
        Main.BackgroundTransparency = 1
        Main.Visible = true
        task.wait(0.05)
        tween(Main, { Size = UDim2.fromOffset(uiWidth, uiHeight), BackgroundTransparency = 0.05 }, 0.4, Enum.EasingStyle.Back)
    end

    Window.Restore = restoreFromFloat

    Window.Close = function()
        BaconUI:NotifyInfo("界面", "UI 已关闭", 2)
        tween(Main, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.wait(0.35)
        if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
        if getgenv().BaconHub == ScreenGui then getgenv().BaconHub = nil end
    end

    MinBtn.MouseEnter:Connect(function() tween(MinBtn, { BackgroundColor3 = Color3.fromRGB(60, 80, 120), BackgroundTransparency = 0 }, 0.15) end)
    MinBtn.MouseLeave:Connect(function() tween(MinBtn, { BackgroundColor3 = Color3.fromRGB(40, 50, 70), BackgroundTransparency = 0.3 }, 0.15) end)
    MinBtn.MouseButton1Click:Connect(Window.Minimize)

    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(200, 50, 50), BackgroundTransparency = 0 }, 0.15) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(60, 40, 40), BackgroundTransparency = 0.3 }, 0.15) end)
    CloseBtn.MouseButton1Click:Connect(Window.Close)

    -- 开场动画
    Main.Size = UDim2.fromOffset(0, 0)
    Main.BackgroundTransparency = 1
    task.spawn(function()
        task.wait(0.05)
        tween(Main, { Size = UDim2.fromOffset(uiWidth, uiHeight), BackgroundTransparency = 0.05 }, 0.4, Enum.EasingStyle.Back)
    end)

    getgenv().BaconHub = ScreenGui
    Window.ScreenGui = ScreenGui
    return Window
end

return BaconUI