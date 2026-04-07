--[[
    ╔══════════════════════════════════════════════════════════╗
    ║             ADMIN PANEL  •  v2.0.0                      ║
    ║        For private developer/testing use only           ║
    ╚══════════════════════════════════════════════════════════╝

    USAGE:
        loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL"))()

    KEYBIND:
        [INSERT]  →  Toggle menu visibility
]]

-- ═══════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════
--  GLOBAL STATE
-- ═══════════════════════════════════════════════════
local Config = {
    Primary         = Color3.fromRGB(13, 13, 13),
    Secondary       = Color3.fromRGB(22, 22, 22),
    Accent          = Color3.fromRGB(100, 180, 255),
    Text            = Color3.fromRGB(220, 220, 220),
    SubText         = Color3.fromRGB(110, 110, 110),
    Danger          = Color3.fromRGB(200, 40, 40),
    Width           = 700,
    Height          = 460,
}

local State = {
    ActiveCategory  = "Player",
    IsMinimized     = false,
    GuiVisible      = true,
    -- Player
    SpeedEnabled    = false, SpeedValue      = 16,
    FlyEnabled      = false, FlySpeed        = 50,
    JumpEnabled     = false, JumpType        = "Double",
    NoclipEnabled   = false,
    -- Visuals
    BoxESP          = false, SkeletonESP     = false,
    Tracer          = false, HealthBarESP    = false,
    DistanceESP     = false, NameESP         = false,
    Chams           = false, Fullbright      = false,
    NoFog           = false, XRay            = false,
    -- Combat
    SilentAim       = false, AimLock         = false,
    AimSmooth       = 0.5,   TargetPart      = "Head",
    Triggerbot      = false, KillAura        = false,
    KillAuraRange   = 20,    Reach           = false,
    ReachValue      = 10,    AutoClicker     = false,
    FastAttack      = false, NoRecoil        = false,
    InfiniteAmmo    = false, GodMode         = false,
    AntiStun        = false,
}

-- Connection / cleanup registry
local Connections = {}
local ESPObjects  = {}
local FlyBody     = nil

local function Track(conn)
    if conn then table.insert(Connections, conn) end
    return conn
end

local function Cleanup()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    for _, o in pairs(ESPObjects)  do pcall(function() if o and o.Parent then o:Destroy() end end) end
    ESPObjects = {}
    -- Restore humanoid defaults
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed     = 16
            hum.JumpPower     = 50
            hum.PlatformStand = false
        end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end)
    if FlyBody then
        pcall(function() FlyBody.bv:Destroy() end)
        pcall(function() FlyBody.bg:Destroy() end)
        FlyBody = nil
    end
end

-- Lighting originals for restore
local OrigLighting = {
    Brightness      = Lighting.Brightness,
    Ambient         = Lighting.Ambient,
    OutdoorAmbient  = Lighting.OutdoorAmbient,
    FogEnd          = Lighting.FogEnd,
    FogStart        = Lighting.FogStart,
}

-- ═══════════════════════════════════════════════════
--  ESP LIBRARY (DRAWING BASED) – INTEGRATION
-- ═══════════════════════════════════════════════════
local ESP_Lib = {}
do
    -- -------------------------------------------------------------
    --  Original ESP-Library (unverändert bis auf Namespace)
    -- -------------------------------------------------------------
    local Players = game:GetService("Players")
    local ESP = {
        Enabled = true,
        Settings = {
            RemoveOnDeath = true,
            MaxDistance = 300,
            MaxBoxSize = Vector3.new(15, 15, 0),
            DestroyOnRemove = true,
            TeamColors = false,
            TeamBased = false,
            BoxTopOffset = Vector3.new(0, 1, 0),
            Boxes = {
                Enabled = true,
                Color = Color3.new(1, 0, 1),
                Thickness = 1,
            },
            Names = {
                Distance = true,
                Health = true,
                Enabled = true,
                Resize = true,
                ResizeWeight = 0.05,
                Color = Color3.new(1, 1, 1),
                Size = 18,
                Font = 1,
                Center = true,
                Outline = true,
            },
            Tracers = {
                Enabled = true,
                Thickness = 0,
                Color = Color3.new(1, 0, 1),
            }
        },
        Objects = {}
    }

    local function Draw(Type, Properties)
        local Object = Drawing.new(Type)
        for Property, Value in next, Properties or {} do
            Object[Property] = Value
        end
        return Object
    end

    function ESP:GetScreenPosition(Position)
        local Position = typeof(Position) ~= "CFrame" and Position or Position.Position
        local ScreenPos, IsOnScreen = workspace.CurrentCamera:WorldToViewportPoint(Position)
        return Vector2.new(ScreenPos.X, ScreenPos.Y), IsOnScreen
    end

    function ESP:GetDistance(Position)
        local Magnitude = (workspace.CurrentCamera.CFrame.Position - Position).Magnitude
        local Metric = Magnitude * 0.28
        return math.round(Metric)
    end

    function ESP:GetHealth(Model)
        local Humanoid = Model:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            return Humanoid.Health, Humanoid.MaxHealth, (Humanoid.Health / Humanoid.MaxHealth) * 100
        end
        return 100, 100, 100
    end

    function ESP:GetPlayerFromCharacter(Model)
        return Players:GetPlayerFromCharacter(Model)
    end

    function ESP:GetTeam(Model)
        local Player = ESP:GetPlayerFromCharacter(Model)
        return Player and Player.Team or nil
    end

    function ESP:GetPlayerTeam(Player)
        return Player and Player.Team
    end

    function ESP:IsHostile(Model)
        local Player = ESP:GetPlayerFromCharacter(Model)
        local MyTeam, TheirTeam = ESP:GetPlayerTeam(Players.LocalPlayer), ESP:GetPlayerTeam(Player)
        return (MyTeam ~= TheirTeam)
    end

    function ESP:GetTeamColor(Model)
        local Team = Model:IsA("Model") and ESP:GetTeam(Model) or Model:IsA("Player") and ESP:GetPlayerTeam(Model)
        return Team and Team.TeamColor.Color or Color3.new(1, 0, 0)
    end

    function ESP:GetOffset(Model)
        local Humanoid = Model:FindFirstChild("Humanoid")
        if Humanoid and Humanoid.RigType == Enum.HumanoidRigType.R6 then
            return CFrame.new(0, -1.75, 0)
        end
        return CFrame.new(0, 0, 0)
    end

    function ESP:CharacterAdded(Player)
        return Player.CharacterAdded
    end

    function ESP:GetCharacter(Player)
        return Player.Character
    end

    local function Validate(Child, Type, ClassName, ExpectedName)
        return not (Type or ClassName or ExpectedName) or (not ExpectedName or (ExpectedName and Child.Name == ExpectedName)) and (not ClassName or (ClassName and Child.ClassName == ClassName)) and (not Type or (Type and Child:IsA(Type)))
    end

    function ESP:AddListener(Model, Validator, Settings)
        local Descendants = Settings.Descendants
        local Type, ClassName, ExpectedName = Settings.Type, Settings.ClassName, Settings.ExpectedName
        local ExtraSettings = Settings.Custom or {}
        local function ValidCheck(Child)
            if typeof(Validator) == "function" and Validator(Child) or not Validator then
                if Validate(Child, Type, ClassName, ExpectedName) then
                    ESP.Object:New(Child, ExtraSettings)
                end
            end
        end
        local Connection = Descendants and Model.DescendantAdded or Model.ChildAdded
        local ObjectsToCheck = Descendants and Model.GetDescendants or Model.GetChildren
        Connection:Connect(function(Child)
            task.spawn(ValidCheck, Child)
        end)
        for i, Child in next, ObjectsToCheck(Model) do
            task.spawn(ValidCheck, Child)
        end
    end

    local Object = {}
    Object.__index = Object
    ESP.Object = Object

    local function Clone(Table)
        local Ret = {}
        for i,v in next, Table do
            if typeof(v) == "table" then
                v = Clone(v)
            end
            Ret[i] = v
        end
        return Ret
    end

    local function GetValue(Local, Global, Name)
        local GlobalVal = Global[Name]
        local LocalVal = Local[Name]
        return LocalVal or ((LocalVal == nil or typeof(LocalVal) ~= "boolean") and GlobalVal)
    end

    function Object:New(Model, ExtraInfo)
        if not Model then return end
        local Settings = ESP.Settings
        local NewObject = {
            Connections = {},
            RenderSettings = {
                Boxes = {},
                Tracers = {},
                Names = {},
            },
            GlobalSettings = Settings,
            Model = Model,
            Name = Model.Name,
            Objects = {
                Box = {
                    Color = Settings.Boxes.Color,
                    Thickness = Settings.Boxes.Thickness,
                },
                Name = {
                    Color = Settings.Names.Color,
                    Outline = Settings.Names.Outline,
                    Text = Model.Name,
                    Size = Settings.Names.Size,
                    Font = Settings.Names.Font,
                    Center = Settings.Names.Center,
                },
                Tracer = {
                    Thickness = Settings.Tracers.Thickness,
                    Color = Settings.Tracers.Color,
                }
            },
        }
        for Property, Value in next, ExtraInfo or {} do
            if Property ~= "Settings" then
                NewObject[Property] = Value
            else
                for Name, Table in next, Value do
                    for Property, Value in next, Table do
                        NewObject.RenderSettings[Name][Property] = Value
                    end
                end
            end
        end
        NewObject = setmetatable(NewObject, Object)
        ESP.Objects[Model] = NewObject
        NewObject.Objects.Box = Draw("Quad", NewObject.Objects.Box)
        NewObject.Objects.Name = Draw("Text", NewObject.Objects.Name)
        NewObject.Objects.Tracer = Draw("Line", NewObject.Objects.Tracer)
        NewObject.Connections.Destroying = Model.Destroying:Connect(function()
            NewObject:Destroy()
        end)
        NewObject.Connections.AncestryChanged = Model.AncestryChanged:Connect(function(Old, New)
            if not Model:IsDescendantOf(workspace) and (NewObject.RenderSettings.DestroyOnRemove or NewObject.GlobalSettings.DestroyOnRemove) then
                NewObject:Destroy()
            end
        end)
        local Humanoid = Model:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            NewObject.Connections.Died = Humanoid.Died:Connect(function()
                if Settings.RemoveOnDeath then
                    NewObject:Destroy()
                end
            end)
        end
        NewObject.Connections.Removing = Model.AncestryChanged:Connect(function()
            if NewObject.RenderSettings.DestroyOnRemove or NewObject.GlobalSettings.DestroyOnRemove then
                NewObject:Destroy()
            end
        end)
        return NewObject
    end

    function Object:GetQuad()
        local RenderSettings = self.RenderSettings
        local GlobalSettings = self.GlobalSettings
        local MaxSize = GetValue(RenderSettings, GlobalSettings, "MaxBoxSize")
        local BoxTopOffset = GetValue(RenderSettings, GlobalSettings, "BoxTopOffset")
        local Model = self.Model
        local Pivot = Model:GetPivot()
        local BoxPosition, Size = Model:GetBoundingBox()
        Pivot = Pivot * ESP:GetOffset(Model)
        Size = Size * Vector3.new(1, 1, 0)
        local X, Y = math.clamp(Size.X, 1, MaxSize.X) / 2, math.clamp(Size.Y, 1, MaxSize.Y) / 2
        local PivotVector, PivotOnScreen = (ESP:GetScreenPosition(Pivot.Position))
        local BoxTop = ESP:GetScreenPosition((Pivot * CFrame.new(0, Y, 0)).Position + (BoxTopOffset))
        local BoxBottom = ESP:GetScreenPosition((Pivot * CFrame.new(0, -Y, 0)).Position)
        local TopRight, TopRightOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(-X, Y, 0)).Position)
        local TopLeft, TopLeftOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(X, Y, 0)).Position)
        local BottomLeft, BottomLeftOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(X, -Y, 0)).Position)
        local BottomRight, BottomRightOnScreen = ESP:GetScreenPosition((Pivot * CFrame.new(-X, -Y, 0)).Position)
        if TopRightOnScreen or TopLeftOnScreen or BottomLeftOnScreen or BottomRightOnScreen then
            local Positions = {
                BoxBottom = BoxBottom,
                Pivot = PivotVector,
                BoxTop = BoxTop,
                TopRight = TopRight,
                TopLeft = TopLeft,
                BottomLeft = BottomLeft,
                BottomRight = BottomRight,
            }
            return Positions, true
        end
        return false
    end

    function Object:DrawBox(Quad)
        local RenderSettings = self.RenderSettings
        local GlobalSettings = self.GlobalSettings
        local RenderBoxes = RenderSettings.Boxes
        local GlobalBoxes = GlobalSettings.Boxes
        local TeamColors = GetValue(RenderSettings, GlobalSettings, "TeamColors")
        local Thickness = GetValue(RenderBoxes, GlobalBoxes, "Thickness")
        local Color = GetValue(RenderBoxes, GlobalBoxes, "Color")
        local Properties = {
            Visible = true,
            Color = TeamColors and ESP:GetTeamColor(self.Model) or Color,
            Thickness = Thickness,
            PointA = Quad.TopRight,
            PointB = Quad.TopLeft,
            PointC = Quad.BottomLeft,
            PointD = Quad.BottomRight,
        }
        for Property, Value in next, Properties do
            self.Objects.Box[Property] = Value
        end
    end

    function Object:DrawName(Quad)
        local RenderSettings = self.RenderSettings
        local GlobalSettings = self.GlobalSettings
        local RenderNames = RenderSettings.Names
        local GlobalNames = GlobalSettings.Names
        local Settings = RenderNames or GlobalNames
        local ShowDistance = GetValue(RenderNames, GlobalNames, "Distance")
        local Size = GetValue(RenderNames, GlobalNames, "Size")
        local Resize = GetValue(RenderNames, GlobalNames, "Resize")
        local ResizeWeight = GetValue(RenderNames, GlobalNames, "ResizeWeight")
        local ShowHealth = GetValue(RenderNames, GlobalNames, "Health")
        local Font = GetValue(RenderNames, GlobalNames, "Font")
        local Center = GetValue(RenderNames, GlobalNames, "Center")
        local TeamColors = GetValue(RenderNames, GlobalNames, "TeamColors")
        local Color = GetValue(RenderNames, GlobalNames, "Color")
        local Outline = GetValue(RenderNames, GlobalNames, "Outline")
        local Distance = self.Model:GetPivot().Position
        local Properties = {
            Visible = true,
            Color = TeamColors and ESP:GetTeamColor(self.Model) or Color,
            Outline = Outline,
            Text = not (Size or ShowHealth) and self.Name or ("%s [%sm]%s"):format(self.Name, ShowDistance and tostring(ESP:GetDistance(Distance)) or "", ShowHealth and ("\n%d/%d (%d%%)"):format(ESP:GetHealth(self.Model)) or ""),
            Size = not Resize and Size or Size - math.clamp((ESP:GetDistance(Distance) * ResizeWeight), 1, Size * 0.75),
            Font = Font,
            Center = Center,
            Position = Quad.BoxTop,
        }
        for Property, Value in next, Properties do
            self.Objects.Name[Property] = Value
        end
    end

    function Object:DrawTracer(Quad)
        local RenderSettings = self.RenderSettings
        local GlobalSettings = self.GlobalSettings
        local RenderTracers = RenderSettings.Tracers
        local GlobalTracers = GlobalSettings.Tracers
        local TeamColors = GetValue(RenderTracers, GlobalTracers, "TeamColors")
        local Color = GetValue(RenderTracers, GlobalTracers, "Color")
        local Thickness = GetValue(RenderTracers, GlobalTracers, "Thickness")
        local Properties = {
            Visible = true,
            Color = TeamColors and ESP:GetTeamColor(self.Model) or Color,
            Thickness = Thickness,
            From = workspace.CurrentCamera.ViewportSize * Vector2.new(.5, 1),
            To = Quad.BoxBottom,
        }
        for Property, Value in next, Properties do
            self.Objects.Tracer[Property] = Value
        end
    end

    function Object:Destroy()
        ESP.Objects[self.Model] = nil
        self:ClearDrawings()
        for i,v in next, self.Objects do
            v:Remove()
        end
        for i,v in next, self.Connections do
            v:Disconnect()
        end
        table.clear(self.Objects)
    end

    function Object:ClearDrawings()
        for i,v in next, self.Objects do
            v.Visible = false
        end
    end

    function Object:Refresh()
        local Model = self.Model
        local Quad = self:GetQuad()
        local RenderSettings = self.RenderSettings
        local GlobalSettings = self.GlobalSettings
        local TeamBased = GetValue(RenderSettings, GlobalSettings, "TeamBased")
        local MaxDistance = GetValue(RenderSettings, GlobalSettings, "MaxDistance")
        local Boxes = GetValue(RenderSettings.Boxes, GlobalSettings.Boxes, "Enabled")
        local Names = GetValue(RenderSettings.Names, GlobalSettings.Names, "Enabled")
        local Tracers = GetValue(RenderSettings.Tracers, GlobalSettings.Tracers, "Enabled")
        if not ESP.Enabled then
            return self:ClearDrawings()
        end
        if not Model.Parent or not Model:IsDescendantOf(workspace) then
            return self:ClearDrawings()
        end
        if not Quad then
            return self:ClearDrawings()
        end
        if TeamBased and not ESP:IsHostile(Model) then
            return self:ClearDrawings()
        end
        if ESP:GetDistance(Model:GetPivot().Position) > MaxDistance then
            return self:ClearDrawings()
        end
        if Boxes then
            self:DrawBox(Quad)
        else
            self.Objects.Box.Visible = false
        end
        if Names then
            self:DrawName(Quad)
        else
            self.Objects.Name.Visible = false
        end
        if Tracers then
            self:DrawTracer(Quad)
        else
            self.Objects.Tracer.Visible = false
        end
    end

    game.RunService.Stepped:Connect(function()
        for i, Object in next, ESP.Objects do
            Object:Refresh()
        end
    end)

    ESP_Lib = ESP
end

-- ═══════════════════════════════════════════════════
--  GUI ROOT
-- ═══════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name              = "AdminPanel_" .. HttpService:GenerateGUID(false):sub(1, 8)
ScreenGui.ResetOnSpawn      = false
ScreenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset    = true

local ok = pcall(function() ScreenGui.Parent = CoreGui end)
if not ok or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ═══════════════════════════════════════════════════
--  UTILITY CONSTRUCTORS
-- ═══════════════════════════════════════════════════
local function NewInstance(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        inst[k] = v
    end
    return inst
end

local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function Stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or Color3.fromRGB(40, 40, 40)
    s.Thickness = thickness or 1
    s.Parent    = parent
    return s
end

local function HoverEffect(btn, hoverColor, normalColor)
    normalColor = normalColor or btn.BackgroundColor3
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = hoverColor}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = normalColor}):Play()
    end)
end

-- ═══════════════════════════════════════════════════
--  MAIN FRAME
-- ═══════════════════════════════════════════════════
local MainFrame = NewInstance("Frame", {
    Name                = "MainFrame",
    Size                = UDim2.new(0, Config.Width, 0, Config.Height),
    Position            = UDim2.new(0.5, -Config.Width/2, 0.5, -Config.Height/2),
    BackgroundColor3    = Config.Primary,
    BorderSizePixel     = 0,
    ClipsDescendants    = true,
    Parent              = ScreenGui,
})
Corner(MainFrame, 12)
Stroke(MainFrame, Color3.fromRGB(35, 35, 35), 1)

-- ─── TITLE BAR ───────────────────────────────────
local TitleBar = NewInstance("Frame", {
    Size                = UDim2.new(1, 0, 0, 46),
    BackgroundColor3    = Config.Secondary,
    BorderSizePixel     = 0,
    Parent              = MainFrame,
})
Corner(TitleBar, 12)
-- Cover the bottom corners of the title bar
NewInstance("Frame", {
    Size                = UDim2.new(1, 0, 0.5, 0),
    Position            = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3    = Config.Secondary,
    BorderSizePixel     = 0,
    Parent              = TitleBar,
})

NewInstance("TextLabel", {
    Size                = UDim2.new(1, -120, 1, 0),
    Position            = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text                = "  ⚡  ADMIN PANEL",
    TextColor3          = Config.Text,
    Font                = Enum.Font.GothamBold,
    TextSize            = 13,
    TextXAlignment      = Enum.TextXAlignment.Left,
    Parent              = TitleBar,
})

-- Window control buttons
local function MakeControlBtn(xOff, bg, text)
    local btn = NewInstance("TextButton", {
        Size                = UDim2.new(0, 28, 0, 28),
        Position            = UDim2.new(1, xOff, 0.5, -14),
        BackgroundColor3    = bg,
        Text                = text,
        TextColor3          = Color3.fromRGB(255, 255, 255),
        Font                = Enum.Font.GothamBold,
        TextSize            = 14,
        BorderSizePixel     = 0,
        Parent              = TitleBar,
    })
    Corner(btn, 7)
    return btn
end

local MinimizeBtn   = MakeControlBtn(-74, Color3.fromRGB(40, 40, 40),  "−")
local CloseBtn      = MakeControlBtn(-38, Color3.fromRGB(160, 36, 36), "✕")
HoverEffect(MinimizeBtn, Color3.fromRGB(60, 60, 60),         Color3.fromRGB(40, 40, 40))
HoverEffect(CloseBtn,    Color3.fromRGB(200, 50, 50),        Color3.fromRGB(160, 36, 36))

-- ─── SIDEBAR ─────────────────────────────────────
local Sidebar = NewInstance("Frame", {
    Name                = "Sidebar",
    Size                = UDim2.new(0, 164, 1, -46),
    Position            = UDim2.new(0, 0, 0, 46),
    BackgroundColor3    = Config.Secondary,
    BorderSizePixel     = 0,
    Parent              = MainFrame,
})
Corner(Sidebar, 12)
NewInstance("Frame", {  -- plug top-right corner
    Size             = UDim2.new(0.5, 0, 1, 0),
    Position         = UDim2.new(0.5, 0, 0, 0),
    BackgroundColor3 = Config.Secondary,
    BorderSizePixel  = 0,
    Parent           = Sidebar,
})
NewInstance("Frame", {  -- plug bottom-left corner
    Size             = UDim2.new(1, 0, 0.5, 0),
    Position         = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = Config.Secondary,
    BorderSizePixel  = 0,
    Parent           = Sidebar,
})

-- ─── PROFILE ─────────────────────────────────────
local ProfileSection = NewInstance("Frame", {
    Size             = UDim2.new(1, 0, 0, 100),
    BackgroundTransparency = 1,
    Parent           = Sidebar,
})

local AvatarHolder = NewInstance("Frame", {
    Size             = UDim2.new(0, 46, 0, 46),
    Position         = UDim2.new(0.5, -23, 0, 10),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BorderSizePixel  = 0,
    Parent           = ProfileSection,
})
Corner(AvatarHolder, 23)
Stroke(AvatarHolder, Color3.fromRGB(50, 50, 50), 1.5)

local AvatarImg = NewInstance("ImageLabel", {
    Size             = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Image            = "https://www.roblox.com/headshot-thumbnail/image?userId="
                        .. LocalPlayer.UserId
                        .. "&width=420&height=420&format=png",
    ScaleType        = Enum.ScaleType.Crop,
    Parent           = AvatarHolder,
})
Corner(AvatarImg, 23)

NewInstance("TextLabel", {
    Size             = UDim2.new(1, -10, 0, 16),
    Position         = UDim2.new(0, 5, 0, 58),
    BackgroundTransparency = 1,
    Text             = LocalPlayer.DisplayName,
    TextColor3       = Config.Text,
    Font             = Enum.Font.GothamBold,
    TextSize         = 11,
    TextTruncate     = Enum.TextTruncate.AtEnd,
    Parent           = ProfileSection,
})

NewInstance("TextLabel", {
    Size             = UDim2.new(1, -10, 0, 14),
    Position         = UDim2.new(0, 5, 0, 74),
    BackgroundTransparency = 1,
    Text             = "@" .. LocalPlayer.Name,
    TextColor3       = Config.SubText,
    Font             = Enum.Font.Gotham,
    TextSize         = 10,
    TextTruncate     = Enum.TextTruncate.AtEnd,
    Parent           = ProfileSection,
})

-- Divider
NewInstance("Frame", {
    Size             = UDim2.new(1, -24, 0, 1),
    Position         = UDim2.new(0, 12, 0, 100),
    BackgroundColor3 = Color3.fromRGB(38, 38, 38),
    BorderSizePixel  = 0,
    Parent           = Sidebar,
})

-- Category list
local CatList = NewInstance("Frame", {
    Size             = UDim2.new(1, 0, 1, -108),
    Position         = UDim2.new(0, 0, 0, 108),
    BackgroundTransparency = 1,
    Parent           = Sidebar,
})

local CatLayout = Instance.new("UIListLayout")
CatLayout.SortOrder = Enum.SortOrder.LayoutOrder
CatLayout.Padding   = UDim.new(0, 3)
CatLayout.Parent    = CatList

local CatPad = Instance.new("UIPadding")
CatPad.PaddingLeft   = UDim.new(0, 8)
CatPad.PaddingRight  = UDim.new(0, 8)
CatPad.PaddingTop    = UDim.new(0, 4)
CatPad.Parent        = CatList

-- ─── CONTENT AREA ────────────────────────────────
local ContentArea = NewInstance("Frame", {
    Name             = "ContentArea",
    Size             = UDim2.new(1, -164, 1, -46),
    Position         = UDim2.new(0, 164, 0, 46),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent           = MainFrame,
})

-- ═══════════════════════════════════════════════════
--  PANEL / WIDGET FACTORY
-- ═══════════════════════════════════════════════════
local Panels = {}

local function MakePanel(name)
    local scroll = NewInstance("ScrollingFrame", {
        Name                  = name .. "Panel",
        Size                  = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency= 1,
        BorderSizePixel       = 0,
        ScrollBarThickness    = 3,
        ScrollBarImageColor3  = Color3.fromRGB(55, 55, 55),
        CanvasSize            = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize   = Enum.AutomaticSize.Y,
        Visible               = false,
        Parent                = ContentArea,
    })
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 7)
    layout.Parent    = scroll
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent        = scroll
    return scroll
end

-- Section header label
local function SectionLabel(parent, text)
    local lbl = NewInstance("TextLabel", {
        Size                = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text                = text,
        TextColor3          = Config.SubText,
        Font                = Enum.Font.GothamBold,
        TextSize            = 9,
        TextXAlignment      = Enum.TextXAlignment.Left,
        Parent              = parent,
    })
    return lbl
end

-- Generic card wrapper
local function Card(parent, height)
    local f = NewInstance("Frame", {
        Size             = UDim2.new(1, 0, 0, height or 52),
        BackgroundColor3 = Config.Secondary,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    Corner(f, 8)
    return f
end

-- Toggle (with optional slider below)
local function MakeToggle(parent, opts)
    --[[
        opts = {
            label        = string,
            description  = string | nil,
            default      = bool,
            onToggle     = function(isOn),
            slider       = { min, max, default, label, onChange } | nil,
        }
    ]]
    local hasSlider = opts.slider ~= nil
    local cardH     = hasSlider and 82 or 52
    local card      = Card(parent, cardH)

    -- Toggle pill
    local isOn = opts.default or false

    local pill = NewInstance("TextButton", {
        Size             = UDim2.new(0, 40, 0, 22),
        Position         = UDim2.new(1, -50, 0, 15),
        BackgroundColor3 = isOn and Color3.fromRGB(60, 180, 100) or Color3.fromRGB(45, 45, 45),
        Text             = "",
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(pill, 11)

    local dot = NewInstance("Frame", {
        Size             = UDim2.new(0, 16, 0, 16),
        Position         = isOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        Parent           = pill,
    })
    Corner(dot, 8)

    NewInstance("TextLabel", {
        Size             = UDim2.new(1, -60, 0, 20),
        Position         = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text             = opts.label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })

    if opts.description then
        NewInstance("TextLabel", {
            Size             = UDim2.new(1, -60, 0, 13),
            Position         = UDim2.new(0, 12, 0, 30),
            BackgroundTransparency = 1,
            Text             = opts.description,
            TextColor3       = Config.SubText,
            Font             = Enum.Font.Gotham,
            TextSize         = 10,
            TextXAlignment   = Enum.TextXAlignment.Left,
            Parent           = card,
        })
    end

    -- Optional slider
    local sliderFrame = nil
    local sliderVal   = nil

    if hasSlider then
        local s          = opts.slider
        sliderVal        = s.default
        sliderFrame      = NewInstance("Frame", {
            Size             = UDim2.new(1, -24, 0, 22),
            Position         = UDim2.new(0, 12, 0, 56),
            BackgroundTransparency = 1,
            Visible          = isOn,
            Parent           = card,
        })

        local track = NewInstance("Frame", {
            Size             = UDim2.new(1, -48, 0, 4),
            Position         = UDim2.new(0, 0, 0.5, -2),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BorderSizePixel  = 0,
            Parent           = sliderFrame,
        })
        Corner(track, 2)

        local pct  = math.clamp((s.default - s.min) / (s.max - s.min), 0, 1)
        local fill = NewInstance("Frame", {
            Size             = UDim2.new(pct, 0, 1, 0),
            BackgroundColor3 = Config.Accent,
            BorderSizePixel  = 0,
            Parent           = track,
        })
        Corner(fill, 2)

        local knob = NewInstance("Frame", {
            Size             = UDim2.new(0, 13, 0, 13),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.new(pct, 0, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(240, 240, 240),
            BorderSizePixel  = 0,
            ZIndex           = track.ZIndex + 1,
            Parent           = track,
        })
        Corner(knob, 7)

        local valLbl = NewInstance("TextLabel", {
            Size             = UDim2.new(0, 42, 1, 0),
            Position         = UDim2.new(1, -42, 0, 0),
            BackgroundTransparency = 1,
            Text             = tostring(s.default),
            TextColor3       = Config.Text,
            Font             = Enum.Font.GothamBold,
            TextSize         = 11,
            TextXAlignment   = Enum.TextXAlignment.Right,
            Parent           = sliderFrame,
        })

        local sdrag = false
        local function moveSlider(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local v   = math.round(s.min + rel * (s.max - s.min))
            sliderVal = v
            fill.Size          = UDim2.new(rel, 0, 1, 0)
            knob.Position      = UDim2.new(rel, 0, 0.5, 0)
            valLbl.Text        = tostring(v)
            if s.onChange then s.onChange(v) end
        end

        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                sdrag = true; moveSlider(inp.Position.X)
            end
        end)
        Track(UserInputService.InputChanged:Connect(function(inp)
            if sdrag and inp.UserInputType == Enum.UserInputType.MouseMovement then
                moveSlider(inp.Position.X)
            end
        end))
        Track(UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then sdrag = false end
        end))
    end

    -- Toggle action
    pill.MouseButton1Click:Connect(function()
        isOn = not isOn
        local bg  = isOn and Color3.fromRGB(60, 180, 100) or Color3.fromRGB(45, 45, 45)
        local pos = isOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = bg}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.15), {Position = pos}):Play()
        if sliderFrame then
            sliderFrame.Visible = isOn
            card.Size           = UDim2.new(1, 0, 0, isOn and 82 or 52)
        end
        opts.onToggle(isOn, sliderVal)
    end)

    return card
end

-- Standalone slider
local function MakeSlider(parent, label, min, max, default, onChange)
    local card = Card(parent, 52)
    NewInstance("TextLabel", {
        Size             = UDim2.new(1, -60, 0, 18),
        Position         = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Text             = label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })

    local track = NewInstance("Frame", {
        Size             = UDim2.new(1, -60, 0, 4),
        Position         = UDim2.new(0, 12, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(track, 2)

    local pct  = math.clamp((default - min) / (max - min), 0, 1)
    local fill = NewInstance("Frame", {
        Size             = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel  = 0,
        Parent           = track,
    })
    Corner(fill, 2)

    local knob = NewInstance("Frame", {
        Size             = UDim2.new(0, 13, 0, 13),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(pct, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(240, 240, 240),
        BorderSizePixel  = 0,
        ZIndex           = track.ZIndex + 1,
        Parent           = track,
    })
    Corner(knob, 7)

    local valLbl = NewInstance("TextLabel", {
        Size             = UDim2.new(0, 42, 0, 18),
        Position         = UDim2.new(1, -50, 0, 7),
        BackgroundTransparency = 1,
        Text             = tostring(default),
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamBold,
        TextSize         = 11,
        TextXAlignment   = Enum.TextXAlignment.Right,
        Parent           = card,
    })

    local sdrag = false
    local function move(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v   = math.round(min + rel * (max - min))
        fill.Size     = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text   = tostring(v)
        onChange(v)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sdrag = true; move(i.Position.X) end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if sdrag and i.UserInputType == Enum.UserInputType.MouseMovement then move(i.Position.X) end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sdrag = false end
    end))

    return card
end

-- Dropdown
local function MakeDropdown(parent, label, options, default, onChange)
    local card = Card(parent, 52)

    NewInstance("TextLabel", {
        Size             = UDim2.new(0.55, 0, 0, 18),
        Position         = UDim2.new(0, 12, 0.5, -9),
        BackgroundTransparency = 1,
        Text             = label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })

    local selected = default
    local open     = false

    local btn = NewInstance("TextButton", {
        Size             = UDim2.new(0, 130, 0, 28),
        Position         = UDim2.new(1, -142, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        Text             = default .. " ▾",
        TextColor3       = Config.Text,
        Font             = Enum.Font.Gotham,
        TextSize         = 11,
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(btn, 6)

    local list = NewInstance("Frame", {
        Size             = UDim2.new(0, 130, 0, #options * 28),
        Position         = UDim2.new(1, -142, 1, 4),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        BorderSizePixel  = 0,
        Visible          = false,
        ZIndex           = 20,
        Parent           = card,
    })
    Corner(list, 6)
    Stroke(list, Color3.fromRGB(45, 45, 45), 1)

    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent    = list

    for _, opt in ipairs(options) do
        local ob = NewInstance("TextButton", {
            Size             = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text             = opt,
            TextColor3       = opt == selected and Config.Accent or Config.Text,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            ZIndex           = 21,
            Parent           = list,
        })
        ob.MouseEnter:Connect(function()  ob.TextColor3 = Config.Accent end)
        ob.MouseLeave:Connect(function()  ob.TextColor3 = opt == selected and Config.Accent or Config.Text end)
        ob.MouseButton1Click:Connect(function()
            selected  = opt
            btn.Text  = opt .. " ▾"
            list.Visible = false
            open = false
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then
                    c.TextColor3 = c.Text == opt and Config.Accent or Config.Text
                end
            end
            onChange(opt)
        end)
    end

    btn.MouseButton1Click:Connect(function()
        open = not open
        list.Visible = open
    end)

    return card
end

-- Action button
local function MakeButton(parent, label, onClick)
    local card = Card(parent, 44)
    local btn = NewInstance("TextButton", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = label,
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 13,
        BorderSizePixel  = 0,
        Parent           = card,
    })
    HoverEffect(card, Color3.fromRGB(32, 32, 32))
    btn.MouseButton1Click:Connect(onClick)
    return card
end

-- ═══════════════════════════════════════════════════
--  PLAYER PANEL
-- ═══════════════════════════════════════════════════
local PlayerPanel = MakePanel("Player")
Panels["Player"]  = PlayerPanel

SectionLabel(PlayerPanel, "MOVEMENT")

-- Speed
MakeToggle(PlayerPanel, {
    label       = "Speed",
    description = "Override humanoid walk speed",
    default     = false,
    onToggle    = function(on, val)
        State.SpeedEnabled = on
        if val then State.SpeedValue = val end
        if not on then
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end)
        end
    end,
    slider = { min = 0, max = 100, default = 16,
               onChange = function(v) State.SpeedValue = v end },
})

-- Fly
local function EnableFly()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if FlyBody then
        pcall(function() FlyBody.bv:Destroy() end)
        pcall(function() FlyBody.bg:Destroy() end)
    end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity  = Vector3.zero
    bv.Parent    = hrp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bg.D         = 100
    bg.Parent    = hrp

    FlyBody = { bv = bv, bg = bg }

    Track(RunService.RenderStepped:Connect(function()
        if not State.FlyEnabled or not FlyBody then return end
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        local dir = Vector3.zero
        local cf  = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir += cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir -= cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir -= cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir += cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir += Vector3.yAxis  end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis  end
        bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * State.FlySpeed
        bg.CFrame   = cf
    end))
end

local function DisableFly()
    if FlyBody then
        pcall(function() FlyBody.bv:Destroy() end)
        pcall(function() FlyBody.bg:Destroy() end)
        FlyBody = nil
    end
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end)
end

MakeToggle(PlayerPanel, {
    label       = "Fly",
    description = "Free-camera flight (WASD + Space/Shift)",
    default     = false,
    onToggle    = function(on, val)
        State.FlyEnabled = on
        if val then State.FlySpeed = val end
        if on then EnableFly() else DisableFly() end
    end,
    slider = { min = 0, max = 100, default = 50,
               onChange = function(v) State.FlySpeed = v end },
})

-- Jump (double / infinity)
do
    local card = Card(PlayerPanel, 52)
    local isOn = false

    local pill = NewInstance("TextButton", {
        Size             = UDim2.new(0, 40, 0, 22),
        Position         = UDim2.new(1, -50, 0, 15),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        Text             = "",
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(pill, 11)
    local dot = NewInstance("Frame", {
        Size             = UDim2.new(0, 16, 0, 16),
        Position         = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        Parent           = pill,
    })
    Corner(dot, 8)

    NewInstance("TextLabel", {
        Size             = UDim2.new(1, -60, 0, 20),
        Position         = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text             = "Jump",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })
    NewInstance("TextLabel", {
        Size             = UDim2.new(1, -60, 0, 13),
        Position         = UDim2.new(0, 12, 0, 30),
        BackgroundTransparency = 1,
        Text             = "Choose Double or Infinite jump mode",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.Gotham,
        TextSize         = 10,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })

    local optFrame = NewInstance("Frame", {
        Size             = UDim2.new(1, -24, 0, 28),
        Position         = UDim2.new(0, 12, 0, 50),
        BackgroundTransparency = 1,
        Visible          = false,
        Parent           = card,
    })
    local ol = Instance.new("UIListLayout")
    ol.FillDirection = Enum.FillDirection.Horizontal
    ol.Padding       = UDim.new(0, 8)
    ol.Parent        = optFrame

    local function JumpOptBtn(text)
        local b = NewInstance("TextButton", {
            Size             = UDim2.new(0, 110, 1, 0),
            BackgroundColor3 = State.JumpType == text and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(32, 32, 32),
            Text             = text,
            TextColor3       = State.JumpType == text and Config.Accent or Config.Text,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            BorderSizePixel  = 0,
            Parent           = optFrame,
        })
        Corner(b, 6)
        return b
    end

    local dblBtn = JumpOptBtn("Double Jump")
    local infBtn = JumpOptBtn("∞ Infinity")

    local function RefreshJumpBtns()
        for _, b in ipairs({dblBtn, infBtn}) do
            local active = b.Text == State.JumpType or
                           (b.Text == "Double Jump" and State.JumpType == "Double") or
                           (b.Text == "∞ Infinity"  and State.JumpType == "Infinity")
            b.TextColor3       = active and Config.Accent or Config.Text
            b.BackgroundColor3 = active and Color3.fromRGB(45,45,45) or Color3.fromRGB(32,32,32)
        end
    end

    dblBtn.MouseButton1Click:Connect(function() State.JumpType = "Double";   RefreshJumpBtns() end)
    infBtn.MouseButton1Click:Connect(function() State.JumpType = "Infinity"; RefreshJumpBtns() end)

    local jumpConns = {}
    local function ClearJumpConns()
        for _, c in ipairs(jumpConns) do pcall(function() c:Disconnect() end) end
        jumpConns = {}
    end

    local function ApplyJump()
        ClearJumpConns()
        if not isOn then return end
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        if State.JumpType == "Double" then
            local count = 0
            table.insert(jumpConns, hum.StateChanged:Connect(function(_, new)
                if new == Enum.HumanoidStateType.Jumping then count += 1 end
                if new == Enum.HumanoidStateType.Landed  then count = 0 end
                if new == Enum.HumanoidStateType.Freefall and count < 2 then
                    -- allow one extra jump request while in air
                end
            end))
            table.insert(jumpConns, UserInputService.JumpRequest:Connect(function()
                if count < 2 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
        elseif State.JumpType == "Infinity" then
            table.insert(jumpConns, UserInputService.JumpRequest:Connect(function()
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end))
        end
    end

    pill.MouseButton1Click:Connect(function()
        isOn = not isOn
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = isOn and Color3.fromRGB(60,180,100) or Color3.fromRGB(45,45,45)
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.15), {
            Position = isOn and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
        }):Play()
        optFrame.Visible = isOn
        card.Size        = UDim2.new(1, 0, 0, isOn and 86 or 52)
        ApplyJump()
    end)
end

-- Noclip
local noclipConn = nil
MakeToggle(PlayerPanel, {
    label       = "Noclip",
    description = "Disable collision detection",
    default     = false,
    onToggle    = function(on)
        State.NoclipEnabled = on
        if noclipConn then pcall(function() noclipConn:Disconnect() end); noclipConn = nil end
        if on then
            noclipConn = Track(RunService.Stepped:Connect(function()
                if not State.NoclipEnabled then return end
                local char = LocalPlayer.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end))
        else
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
            end)
        end
    end,
})

-- Respawn
MakeButton(PlayerPanel, "↺  Force Respawn", function()
    pcall(function()
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:TakeDamage(hum.MaxHealth + 1e6) end
    end)
end)

-- Speed heartbeat
Track(RunService.Heartbeat:Connect(function()
    if State.SpeedEnabled then
        pcall(function()
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = State.SpeedValue end
        end)
    end
end))

-- ═══════════════════════════════════════════════════
--  VISUALS PANEL (MIT ESP-LIBRARY)
-- ═══════════════════════════════════════════════════
local VisualsPanel = MakePanel("Visuals")
Panels["Visuals"]  = VisualsPanel

-- Hilfsfunktionen zum Steuern der ESP-Library
local function UpdateESPSettings()
    -- Haupt-ESP ein/aus basierend auf mindestens einer aktiven Funktion
    local anyActive = State.BoxESP or State.Tracer or State.NameESP or State.HealthBarESP or State.DistanceESP
    ESP_Lib.Enabled = anyActive

    -- Einzelne Features
    ESP_Lib.Settings.Boxes.Enabled = State.BoxESP
    ESP_Lib.Settings.Tracers.Enabled = State.Tracer
    ESP_Lib.Settings.Names.Enabled = State.NameESP or State.HealthBarESP or State.DistanceESP
    ESP_Lib.Settings.Names.Health = State.HealthBarESP
    ESP_Lib.Settings.Names.Distance = State.DistanceESP

    -- Optische Anpassungen (kannst du später über die GUI ergänzen)
    ESP_Lib.Settings.Boxes.Color = Color3.fromRGB(255, 0, 255)   -- Pink
    ESP_Lib.Settings.Tracers.Color = Color3.fromRGB(255, 0, 255)
    ESP_Lib.Settings.Names.Color = Color3.fromRGB(255, 255, 255)
end

-- Initialer Aufruf (alle Toggles sind noch aus)
UpdateESPSettings()

-- Skeleton- und Chams-Logik (eigenständig, da Library das nicht kann)
local skeletonObjects = {}   -- für 3D-Linien
local chamsHighlights = {}

local function UpdateSkeletonAndChams()
    -- Alte Objekte entfernen
    for _, obj in pairs(skeletonObjects) do pcall(function() if obj and obj.Parent then obj:Destroy() end end) end
    skeletonObjects = {}
    for _, hl in pairs(chamsHighlights) do pcall(function() if hl and hl.Parent then hl:Destroy() end end) end
    chamsHighlights = {}

    if not (State.SkeletonESP or State.Chams) then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end

        -- Skeleton ESP (3D-Linien mit SelectionBox + Beam)
        if State.SkeletonESP then
            local function getPart(name)
                return char:FindFirstChild(name)
            end
            local head = getPart("Head")
            local torso = getPart("UpperTorso") or getPart("Torso")
            local leftArm = getPart("LeftArm")
            local rightArm = getPart("RightArm")
            local leftLeg = getPart("LeftLeg")
            local rightLeg = getPart("RightLeg")

            local function createLine(partA, partB)
                if not partA or not partB then return end
                local box = Instance.new("SelectionBox")
                box.Color3 = Color3.fromRGB(200, 200, 200)
                box.LineThickness = 0.1
                box.Adornee = partA
                box.SurfaceTransparency = 1
                box.Parent = workspace
                local attA = Instance.new("Attachment", partA)
                local attB = Instance.new("Attachment", partB)
                local beam = Instance.new("Beam")
                beam.Attachment0 = attA
                beam.Attachment1 = attB
                beam.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
                beam.Width = 0.1
                beam.Parent = box
                table.insert(skeletonObjects, box)
                table.insert(skeletonObjects, attA)
                table.insert(skeletonObjects, attB)
            end

            createLine(head, torso)
            createLine(torso, leftArm)
            createLine(torso, rightArm)
            createLine(torso, leftLeg)
            createLine(torso, rightLeg)
        end

        -- Chams (Highlight)
        if State.Chams then
            local hl = Instance.new("Highlight")
            hl.Adornee = char
            hl.FillColor = Color3.fromRGB(220, 50, 50)
            hl.FillTransparency = 0.5
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.OutlineTransparency = 0.3
            hl.Parent = workspace
            table.insert(chamsHighlights, hl)
        end
    end
end

-- Automatische Aktualisierung bei Änderung der Toggles
local function RefreshAllVisuals()
    UpdateESPSettings()
    UpdateSkeletonAndChams()
end

-- Toggles für die ESP-Library
SectionLabel(VisualsPanel, "PLAYER ESP")

MakeToggle(VisualsPanel, {
    label = "Box ESP",
    description = "Draw a bounding box around each player",
    default = false,
    onToggle = function(on) State.BoxESP = on; RefreshAllVisuals() end,
})

MakeToggle(VisualsPanel, {
    label = "Tracer Lines",
    description = "Draw lines from screen bottom to players",
    default = false,
    onToggle = function(on) State.Tracer = on; RefreshAllVisuals() end,
})

MakeToggle(VisualsPanel, {
    label = "Health Bar & HP",
    description = "Show current HP above the player",
    default = false,
    onToggle = function(on) State.HealthBarESP = on; RefreshAllVisuals() end,
})

MakeToggle(VisualsPanel, {
    label = "Distance",
    description = "Show distance in Roblox studs",
    default = false,
    onToggle = function(on) State.DistanceESP = on; RefreshAllVisuals() end,
})

MakeToggle(VisualsPanel, {
    label = "Name & Tool",
    description = "Show username and held tool",
    default = false,
    onToggle = function(on) State.NameESP = on; RefreshAllVisuals() end,
})

MakeToggle(VisualsPanel, {
    label = "Skeleton ESP",
    description = "Visualize player joint lines",
    default = false,
    onToggle = function(on) State.SkeletonESP = on; RefreshAllVisuals() end,
})

MakeToggle(VisualsPanel, {
    label = "Chams / Highlight",
    description = "Colour players through walls",
    default = false,
    onToggle = function(on) State.Chams = on; RefreshAllVisuals() end,
})

SectionLabel(VisualsPanel, "WORLD")

MakeToggle(VisualsPanel, {
    label       = "Fullbright",
    description = "Remove all shadows and post-effects",
    default     = false,
    onToggle    = function(on)
        State.Fullbright = on
        if on then
            Lighting.Brightness     = 2
            Lighting.Ambient        = Color3.fromRGB(255,255,255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            for _, o in ipairs(Lighting:GetChildren()) do
                if o:IsA("PostEffect") then o.Enabled = false end
            end
        else
            Lighting.Brightness     = OrigLighting.Brightness
            Lighting.Ambient        = OrigLighting.Ambient
            Lighting.OutdoorAmbient = OrigLighting.OutdoorAmbient
            for _, o in ipairs(Lighting:GetChildren()) do
                if o:IsA("PostEffect") then o.Enabled = true end
            end
        end
    end,
})

MakeToggle(VisualsPanel, {
    label       = "No Fog",
    description = "Remove atmospheric fog for max view distance",
    default     = false,
    onToggle    = function(on)
        State.NoFog = on
        if on then
            Lighting.FogEnd   = 1e8
            Lighting.FogStart = 1e8
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = 0; atm.Offset = 0 end
        else
            Lighting.FogEnd   = OrigLighting.FogEnd
            Lighting.FogStart = OrigLighting.FogStart
        end
    end,
})

MakeToggle(VisualsPanel, {
    label       = "X-Ray",
    description = "Make world parts semi-transparent",
    default     = false,
    onToggle    = function(on)
        State.XRay = on
        for _, p in ipairs(workspace:GetDescendants()) do
            if p:IsA("BasePart") and not p:IsDescendantOf(LocalPlayer.Character or game) then
                p.LocalTransparencyModifier = on and 0.7 or 0
            end
        end
    end,
})

-- Initialer Aufruf, um ESP-Objekte zu erstellen (falls standardmäßig etwas an ist)
RefreshAllVisuals()

-- ═══════════════════════════════════════════════════
--  COMBAT PANEL
-- ═══════════════════════════════════════════════════
local CombatPanel = MakePanel("Combat")
Panels["Combat"]  = CombatPanel

local function NearestTarget()
    local best, bestDist = nil, math.huge
    local centre = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not plr.Character then continue end
        local part = plr.Character:FindFirstChild(State.TargetPart)
                  or plr.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local sp, vis = Camera:WorldToScreenPoint(part.Position)
        if vis then
            local d = (Vector2.new(sp.X, sp.Y) - centre).Magnitude
            if d < bestDist then bestDist = d; best = part end
        end
    end
    return best
end

SectionLabel(CombatPanel, "AIM ASSISTANCE")

MakeToggle(CombatPanel, { label = "Silent Aim",       description = "Redirect bullets to nearest target without moving crosshair",
    default = false, onToggle = function(on) State.SilentAim = on end })

MakeToggle(CombatPanel, { label = "Aimlock / Hard Lock", description = "Lock camera onto the nearest visible target",
    default = false, onToggle = function(on) State.AimLock = on end })

MakeSlider(CombatPanel, "Smoothness  (1 = instant, 100 = slow)", 1, 100, 50, function(v)
    State.AimSmooth = 1 - (v / 100)
end)

MakeDropdown(CombatPanel, "Target Part", {"Head","Torso","HumanoidRootPart","Random"}, "Head", function(v)
    State.TargetPart = v
end)

MakeToggle(CombatPanel, { label = "Triggerbot",   description = "Auto-fire the moment crosshair overlaps a target",
    default = false, onToggle = function(on) State.Triggerbot = on end })

SectionLabel(CombatPanel, "MELEE & RANGE")

MakeToggle(CombatPanel, {
    label       = "Kill Aura",
    description = "Auto-damage all players within radius",
    default     = false,
    onToggle    = function(on, val) State.KillAura = on; if val then State.KillAuraRange = val end end,
    slider      = { min = 0, max = 100, default = 20, onChange = function(v) State.KillAuraRange = v end },
})

MakeToggle(CombatPanel, {
    label       = "Reach / Hitbox Expander",
    description = "Increase effective weapon hitbox radius",
    default     = false,
    onToggle    = function(on, val) State.Reach = on; if val then State.ReachValue = val end end,
    slider      = { min = 0, max = 100, default = 10, onChange = function(v) State.ReachValue = v end },
})

MakeToggle(CombatPanel, { label = "Auto-Clicker / Auto-Swing", description = "Hold attack at maximum fire rate automatically",
    default = false, onToggle = function(on) State.AutoClicker = on end })

MakeToggle(CombatPanel, { label = "Fast Attack", description = "Suppress inter-attack animation delay",
    default = false, onToggle = function(on) State.FastAttack = on end })

SectionLabel(CombatPanel, "CHARACTER BUFFS")

MakeToggle(CombatPanel, { label = "No Recoil / No Spread", description = "Eliminate weapon recoil and bullet spread",
    default = false, onToggle = function(on) State.NoRecoil = on end })

MakeToggle(CombatPanel, { label = "Infinite Ammo", description = "Prevent ammunition depletion and reloading",
    default = false,
    onToggle = function(on)
        State.InfiniteAmmo = on
        if on then
            Track(RunService.Heartbeat:Connect(function()
                if not State.InfiniteAmmo then return end
                pcall(function()
                    local bp = LocalPlayer.Backpack
                    local char = LocalPlayer.Character
                    for _, holder in ipairs({bp, char}) do
                        if not holder then continue end
                        for _, item in ipairs(holder:GetDescendants()) do
                            if (item.Name == "Ammo" or item.Name == "AmmoValue" or item.Name == "AMMO")
                            and (item:IsA("IntValue") or item:IsA("NumberValue")) then
                                if item.Value < 999 then item.Value = 999 end
                            end
                        end
                    end
                end)
            end))
        end
    end,
})

MakeToggle(CombatPanel, {
    label       = "God Mode",
    description = "Continuously restore health to max — works on weak server validation",
    default     = false,
    onToggle    = function(on)
        State.GodMode = on
        if on then
            Track(RunService.Heartbeat:Connect(function()
                if not State.GodMode then return end
                pcall(function()
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health < hum.MaxHealth * 0.99 then
                        hum.Health = hum.MaxHealth
                    end
                end)
            end))
        end
    end,
})

MakeToggle(CombatPanel, {
    label       = "Anti-Stun / Anti-Knockback",
    description = "Cancel ragdoll and stun states instantly",
    default     = false,
    onToggle    = function(on)
        State.AntiStun = on
        if on then
            Track(RunService.Stepped:Connect(function()
                if not State.AntiStun then return end
                pcall(function()
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local s = hum:GetState()
                        if s == Enum.HumanoidStateType.FallingDown
                        or s == Enum.HumanoidStateType.Ragdoll then
                            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                        end
                    end
                end)
            end))
        end
    end,
})

-- AimLock loop
Track(RunService.RenderStepped:Connect(function()
    if not State.AimLock then return end
    local target = NearestTarget()
    if target then
        Camera.CFrame = Camera.CFrame:Lerp(
            CFrame.new(Camera.CFrame.Position, target.Position),
            1 - State.AimSmooth
        )
    end
end))

-- Kill Aura loop
Track(RunService.Heartbeat:Connect(function()
    if not State.KillAura then return end
    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lhrp then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not plr.Character then continue end
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hrp and hum and (hrp.Position - lhrp.Position).Magnitude <= State.KillAuraRange then
            pcall(function() hum:TakeDamage(1) end)
        end
    end
end))

-- ═══════════════════════════════════════════════════
--  GAME PANEL
-- ═══════════════════════════════════════════════════
local GamePanel = MakePanel("Game")
Panels["Game"]  = GamePanel

SectionLabel(GamePanel, "SERVER TOOLS")

MakeButton(GamePanel, "🔀  Server Hop", function()
    pcall(function()
        local servers = TeleportService:GetServersByServerIdAsync(game.PlaceId)
        if servers and servers[1] then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].Id, LocalPlayer)
        end
    end)
end)

MakeButton(GamePanel, "↩  Rejoin", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end)

-- ═══════════════════════════════════════════════════
--  SETTINGS PANEL
-- ═══════════════════════════════════════════════════
local SettingsPanel = MakePanel("Settings")
Panels["Settings"] = SettingsPanel

SectionLabel(SettingsPanel, "THEME & APPEARANCE")

-- Color picker card
do
    local card = Card(SettingsPanel, 200)

    local titleLbl = NewInstance("TextLabel", {
        Size             = UDim2.new(1, -16, 0, 20),
        Position         = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text             = "Color Picker",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamBold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })

    -- Target selector buttons
    local selFrame = NewInstance("Frame", {
        Size             = UDim2.new(1, -24, 0, 28),
        Position         = UDim2.new(0, 12, 0, 32),
        BackgroundTransparency = 1,
        Parent           = card,
    })
    local sl = Instance.new("UIListLayout")
    sl.FillDirection = Enum.FillDirection.Horizontal
    sl.Padding = UDim.new(0,8)
    sl.Parent = selFrame

    local colorTarget = "Primary"

    local function ColorSelBtn(text)
        local b = NewInstance("TextButton", {
            Size             = UDim2.new(0.5, -4, 1, 0),
            BackgroundColor3 = text == colorTarget and Color3.fromRGB(45,45,45) or Color3.fromRGB(32,32,32),
            Text             = text .. " Color",
            TextColor3       = text == colorTarget and Config.Text or Config.SubText,
            Font             = Enum.Font.Gotham,
            TextSize         = 11,
            BorderSizePixel  = 0,
            Parent           = selFrame,
        })
        Corner(b, 6)
        return b
    end

    local primBtn = ColorSelBtn("Primary")
    local secBtn  = ColorSelBtn("Secondary")

    local function UpdateColorBtns()
        primBtn.BackgroundColor3 = colorTarget == "Primary"   and Color3.fromRGB(45,45,45) or Color3.fromRGB(32,32,32)
        secBtn.BackgroundColor3  = colorTarget == "Secondary" and Color3.fromRGB(45,45,45) or Color3.fromRGB(32,32,32)
        primBtn.TextColor3 = colorTarget == "Primary"   and Config.Text or Config.SubText
        secBtn.TextColor3  = colorTarget == "Secondary" and Config.Text or Config.SubText
    end

    primBtn.MouseButton1Click:Connect(function() colorTarget = "Primary";   UpdateColorBtns() end)
    secBtn.MouseButton1Click:Connect(function()  colorTarget = "Secondary"; UpdateColorBtns() end)

    -- Hue bar
    local hueBar = NewInstance("Frame", {
        Size             = UDim2.new(1, -80, 0, 18),
        Position         = UDim2.new(0, 12, 0, 70),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(hueBar, 4)

    local hueGrad = Instance.new("UIGradient")
    hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromHSV(0,    1, 1)),
        ColorSequenceKeypoint.new(1/6,  Color3.fromHSV(1/6,  1, 1)),
        ColorSequenceKeypoint.new(2/6,  Color3.fromHSV(2/6,  1, 1)),
        ColorSequenceKeypoint.new(3/6,  Color3.fromHSV(3/6,  1, 1)),
        ColorSequenceKeypoint.new(4/6,  Color3.fromHSV(4/6,  1, 1)),
        ColorSequenceKeypoint.new(5/6,  Color3.fromHSV(5/6,  1, 1)),
        ColorSequenceKeypoint.new(1,    Color3.fromHSV(0,    1, 1)),
    })
    hueGrad.Parent = hueBar

    local hueKnob = NewInstance("Frame", {
        Size             = UDim2.new(0, 10, 1, 6),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        ZIndex           = hueBar.ZIndex + 1,
        Parent           = hueBar,
    })
    Corner(hueKnob, 3)
    Stroke(hueKnob, Color3.fromRGB(0,0,0), 1)

    -- Saturation × Value 2-axis area
    local svBox = NewInstance("Frame", {
        Size             = UDim2.new(1, -80, 0, 60),
        Position         = UDim2.new(0, 12, 0, 96),
        BackgroundColor3 = Color3.fromRGB(255,0,0),
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(svBox, 4)

    local satGrad = Instance.new("UIGradient")
    satGrad.Color      = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
    satGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    satGrad.Parent = svBox

    local valOverlay = NewInstance("Frame", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0,0,0),
        BackgroundTransparency = 0,
        BorderSizePixel  = 0,
        Parent           = svBox,
    })
    Corner(valOverlay, 4)
    local valGrad = Instance.new("UIGradient")
    valGrad.Color       = ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(0,0,0))
    valGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    valGrad.Rotation = 90
    valGrad.Parent = valOverlay

    local svKnob = NewInstance("Frame", {
        Size             = UDim2.new(0, 12, 0, 12),
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0,
        ZIndex           = svBox.ZIndex + 2,
        Parent           = svBox,
    })
    Corner(svKnob, 6)
    Stroke(svKnob, Color3.fromRGB(0,0,0), 1)

    -- Preview swatch
    local preview = NewInstance("Frame", {
        Size             = UDim2.new(0, 52, 0, 52),
        Position         = UDim2.new(1, -64, 0, 68),
        BackgroundColor3 = Config.Primary,
        BorderSizePixel  = 0,
        Parent           = card,
    })
    Corner(preview, 8)
    Stroke(preview, Color3.fromRGB(50,50,50), 1)

    -- State
    local H, S, V = 0, 0, 0.05
    local hueDrag = false
    local svDrag  = false

    local function CommitColor()
        local col = Color3.fromHSV(H, S, V)
        preview.BackgroundColor3 = col
        if colorTarget == "Primary" then
            Config.Primary = col
            MainFrame.BackgroundColor3 = col
        else
            Config.Secondary = col
            TitleBar.BackgroundColor3  = col
            Sidebar.BackgroundColor3   = col
        end
    end

    local function UpdateHueBar(x)
        local rel = math.clamp((x - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        H = rel
        hueKnob.Position         = UDim2.new(rel, 0, 0.5, 0)
        svBox.BackgroundColor3   = Color3.fromHSV(H, 1, 1)
        CommitColor()
    end

    local function UpdateSV(x, y)
        local rx = math.clamp((x - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
        local ry = math.clamp((y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
        S = rx; V = 1 - ry
        svKnob.Position = UDim2.new(rx, 0, ry, 0)
        CommitColor()
    end

    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then hueDrag = true; UpdateHueBar(i.Position.X) end
    end)
    svBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then svDrag = true; UpdateSV(i.Position.X, i.Position.Y) end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if hueDrag then UpdateHueBar(i.Position.X) end
        if svDrag  then UpdateSV(i.Position.X, i.Position.Y) end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then hueDrag = false; svDrag = false end
    end))
end

SectionLabel(SettingsPanel, "KEYBINDS")

do
    local card = Card(SettingsPanel, 44)
    NewInstance("TextLabel", {
        Size             = UDim2.new(1, -16, 1, 0),
        Position         = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text             = "[ INSERT ]  — Toggle menu visibility",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.Gotham,
        TextSize         = 11,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })
end

SectionLabel(SettingsPanel, "WINDOW SIZE")

do
    local card = Card(SettingsPanel, 52)

    NewInstance("TextLabel", {
        Size             = UDim2.new(0.42, 0, 1, 0),
        Position         = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text             = "Window Size",
        TextColor3       = Config.Text,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = card,
    })

    local function SizeInput(xOff, default)
        local tb = NewInstance("TextBox", {
            Size             = UDim2.new(0, 58, 0, 28),
            Position         = UDim2.new(1, xOff, 0.5, -14),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            Text             = tostring(default),
            TextColor3       = Config.Text,
            Font             = Enum.Font.Gotham,
            TextSize         = 12,
            BorderSizePixel  = 0,
            Parent           = card,
        })
        Corner(tb, 6)
        return tb
    end

    local wIn = SizeInput(-140, Config.Width)
    NewInstance("TextLabel", {
        Size             = UDim2.new(0, 14, 0, 28),
        Position         = UDim2.new(1, -80, 0.5, -14),
        BackgroundTransparency = 1,
        Text             = "×",
        TextColor3       = Config.SubText,
        Font             = Enum.Font.GothamBold,
        TextSize         = 14,
        Parent           = card,
    })
    local hIn = SizeInput(-66, Config.Height)

    local function Apply()
        local w = tonumber(wIn.Text)
        local h = tonumber(hIn.Text)
        if not w or not h then return end
        w = math.clamp(math.round(w), 300, 1400)
        h = math.clamp(math.round(h), 280, 900)
        Config.Width  = w
        Config.Height = h
        wIn.Text = tostring(w)
        hIn.Text = tostring(h)
        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, w, 0, h)
        }):Play()
    end

    wIn.FocusLost:Connect(Apply)
    hIn.FocusLost:Connect(Apply)
end

-- ─── PANIC BUTTON ────────────────────────────────
-- Placed inside SettingsPanel but pinned to bottom-right of the content area
local panicBtn = NewInstance("TextButton", {
    Size             = UDim2.new(0, 50, 0, 50),
    Position         = UDim2.new(1, -60, 1, -60),
    BackgroundColor3 = Color3.fromRGB(170, 28, 28),
    Text             = "🚨",
    TextSize         = 22,
    BorderSizePixel  = 0,
    ZIndex           = 50,
    Parent           = ContentArea,   -- parented to ContentArea so it's always visible
})
Corner(panicBtn, 25)
Stroke(panicBtn, Color3.fromRGB(220, 50, 50), 1.5)

local panicTip = NewInstance("Frame", {
    Size             = UDim2.new(0, 250, 0, 68),
    Position         = UDim2.new(1, -316, 1, -74),
    BackgroundColor3 = Color3.fromRGB(28, 28, 28),
    BorderSizePixel  = 0,
    Visible          = false,
    ZIndex           = 55,
    Parent           = ContentArea,
})
Corner(panicTip, 8)
Stroke(panicTip, Color3.fromRGB(200, 40, 40), 1)

NewInstance("TextLabel", {
    Size             = UDim2.new(1, -16, 1, -8),
    Position         = UDim2.new(0, 8, 0, 4),
    BackgroundTransparency = 1,
    Text             = "⚠  PANIC BUTTON\nPressing this immediately shuts down all\nactive scripts and closes the panel.",
    TextColor3       = Color3.fromRGB(230, 80, 80),
    Font             = Enum.Font.Gotham,
    TextSize         = 10,
    TextWrapped      = true,
    TextXAlignment   = Enum.TextXAlignment.Left,
    ZIndex           = 56,
    Parent           = panicTip,
})

panicBtn.MouseEnter:Connect(function()
    panicTip.Visible = true
    TweenService:Create(panicBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(210, 40, 40)}):Play()
end)
panicBtn.MouseLeave:Connect(function()
    panicTip.Visible = false
    TweenService:Create(panicBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(170, 28, 28)}):Play()
end)
panicBtn.MouseButton1Click:Connect(function()
    Cleanup()
    pcall(function() ScreenGui:Destroy() end)
end)

-- ═══════════════════════════════════════════════════
--  CATEGORY NAVIGATION
-- ═══════════════════════════════════════════════════
local catIcons = { Player = "👤", Visuals = "👁", Combat = "⚔", Game = "🎮", Settings = "⚙" }
local CatBtns  = {}

local function SwitchTo(name)
    for n, p in pairs(Panels) do p.Visible = n == name end
    State.ActiveCategory = name

    for n, btn in pairs(CatBtns) do
        local active = n == name
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3    = active and Color3.fromRGB(38, 38, 38) or Color3.fromRGB(0,0,0),
            BackgroundTransparency = active and 0 or 1,
        }):Play()
        local lbl = btn:FindFirstChildWhichIsA("TextLabel", true)
        if lbl then lbl.TextColor3 = active and Config.Text or Config.SubText end
    end

    -- Show panic button only on Settings
    panicBtn.Visible = (name == "Settings")
    panicTip.Visible = false
end

for i, name in ipairs({"Player","Visuals","Combat","Game","Settings"}) do
    local btn = NewInstance("TextButton", {
        Name             = name,
        Size             = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = name == "Player" and Color3.fromRGB(38,38,38) or Color3.fromRGB(0,0,0),
        BackgroundTransparency = name == "Player" and 0 or 1,
        Text             = "",
        BorderSizePixel  = 0,
        LayoutOrder      = i,
        Parent           = CatList,
    })
    Corner(btn, 7)

    NewInstance("TextLabel", {
        Size             = UDim2.new(0, 22, 1, 0),
        Position         = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text             = catIcons[name],
        TextColor3       = Config.Text,
        Font             = Enum.Font.Gotham,
        TextSize         = 15,
        Parent           = btn,
    })
    NewInstance("TextLabel", {
        Size             = UDim2.new(1, -38, 1, 0),
        Position         = UDim2.new(0, 36, 0, 0),
        BackgroundTransparency = 1,
        Text             = name,
        TextColor3       = name == "Player" and Config.Text or Config.SubText,
        Font             = Enum.Font.GothamSemibold,
        TextSize         = 12,
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = btn,
    })

    CatBtns[name] = btn
    btn.MouseButton1Click:Connect(function() SwitchTo(name) end)
    btn.MouseEnter:Connect(function()
        if State.ActiveCategory ~= name then
            TweenService:Create(btn, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(28,28,28),
                BackgroundTransparency = 0
            }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if State.ActiveCategory ~= name then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 1}):Play()
        end
    end)
end

SwitchTo("Player")

-- ═══════════════════════════════════════════════════
--  WINDOW DRAGGING
-- ═══════════════════════════════════════════════════
do
    local dragging = false
    local dragStart, startPos

    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = i.Position
            startPos  = MainFrame.Position
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

-- ═══════════════════════════════════════════════════
--  MINIMISE → CIRCLE
-- ═══════════════════════════════════════════════════
local BubbleBtn = NewInstance("TextButton", {
    Size             = UDim2.new(0, 54, 0, 54),
    Position         = UDim2.new(0, 18, 1, -72),
    BackgroundColor3 = Color3.fromRGB(16, 16, 16),
    Text             = "😈",
    TextSize         = 24,
    BorderSizePixel  = 0,
    Visible          = false,
    ZIndex           = 200,
    Parent           = ScreenGui,
})
Corner(BubbleBtn, 27)
Stroke(BubbleBtn, Color3.fromRGB(48, 48, 48), 1.5)

-- Draggable bubble
do
    local d = false; local ds, sp
    BubbleBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            d = true; ds = i.Position; sp = BubbleBtn.Position
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if d and i.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = i.Position - ds
            BubbleBtn.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end
    end))
end

MinimizeBtn.MouseButton1Click:Connect(function()
    State.IsMinimized = true
    local snap = UDim2.new(
        MainFrame.Position.X.Scale, MainFrame.Position.X.Offset + Config.Width  / 2,
        MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset + Config.Height / 2
    )
    local tw = TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0), Position = snap
    })
    tw:Play()
    tw.Completed:Connect(function()
        MainFrame.Visible = false
        MainFrame.Size     = UDim2.new(0, Config.Width, 0, Config.Height)
        MainFrame.Position = UDim2.new(0.5, -Config.Width/2, 0.5, -Config.Height/2)
        BubbleBtn.Visible  = true
        BubbleBtn.Size     = UDim2.new(0, 0, 0, 0)
        TweenService:Create(BubbleBtn, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 54, 0, 54)
        }):Play()
    end)
end)

local function RestoreFromBubble()
    State.IsMinimized = false
    BubbleBtn.Visible  = false
    MainFrame.Visible  = true
    MainFrame.Size     = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService:Create(MainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back), {
        Size     = UDim2.new(0, Config.Width, 0, Config.Height),
        Position = UDim2.new(0.5, -Config.Width/2, 0.5, -Config.Height/2),
    }):Play()
end

BubbleBtn.MouseButton1Click:Connect(RestoreFromBubble)

-- ─── CLOSE (hide UI, scripts continue) ───────────
CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
    task.delay(0.16, function()
        MainFrame.Visible = false
        MainFrame.BackgroundTransparency = 0
        State.GuiVisible = false
    end)
end)

-- ─── INSERT key toggle ────────────────────────────
Track(UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.Insert then
        if State.IsMinimized then
            RestoreFromBubble()
        else
            State.GuiVisible    = not State.GuiVisible
            MainFrame.Visible   = State.GuiVisible
        end
    end
end))

-- ═══════════════════════════════════════════════════
--  DONE
-- ═══════════════════════════════════════════════════
print("╔══════════════════════════════════╗")
print("║  Admin Panel loaded  •  v2.0.0  ║")
print("║  [INSERT] = toggle visibility   ║")
print("╚══════════════════════════════════╝")
