--[[
    VORTEX HUB
    Owner: Nexxy
    Original UI implementation

    A lightweight Roblox UI library with animated styling, draggable windows,
    tabs, notifications, and reusable controls.
]]

local Vortex = {
    Name = "Vortex Hub",
    Owner = "Nexxy",
    Creator = "Nexxy",
    Version = "1.0.0",
    Windows = {},
    Flags = {},
    NotificationLimit = 5,
    Icons = {},
    TextObjects = setmetatable({}, {__mode = "k"}),
    Keybinds = {},
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local activeTweens = setmetatable({}, {__mode = "k"})
local onceButtonStates = setmetatable({}, {__mode = "k"})

local function normalizeIcon(value)
    if type(value) ~= "string" or value == "" then return nil end
    if value:match("^rbxassetid://") or value:match("^rbxthumb://") then return value end
    if tonumber(value) then return "rbxassetid://" .. value end
    return nil
end

local function makeIcon(parent, value, size, color, name)
    local image = normalizeIcon(value)
    if not image then return nil end
    local icon = Instance.new("ImageLabel")
    icon.Name = name or "VortexIcon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.fromOffset(size or 16, size or 16)
    icon.Image = image
    icon.ImageColor3 = color or Color3.new(1, 1, 1)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = parent
    return icon
end

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
local function getPlayerGui()
    player = Players.LocalPlayer
    if not player then
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end
    playerGui = playerGui and playerGui.Parent == player and playerGui or player:WaitForChild("PlayerGui")
    return playerGui
end

Vortex.Themes = {
    Vortex = {
        Background = Color3.fromRGB(5, 5, 8),
        Surface = Color3.fromRGB(13, 13, 20),
        Surface2 = Color3.fromRGB(22, 25, 34),
        Border = Color3.fromRGB(0, 245, 255),
        Accent = Color3.fromRGB(0, 255, 136),
        Accent2 = Color3.fromRGB(0, 245, 255),
        Accent3 = Color3.fromRGB(124, 58, 237),
        Text = Color3.fromRGB(224, 232, 255),
        Muted = Color3.fromRGB(117, 125, 145),
        Danger = Color3.fromRGB(255, 68, 85),
        Glow = Color3.fromRGB(0, 255, 136),
    },
    Midnight = {
        Background = Color3.fromRGB(8, 9, 14),
        Surface = Color3.fromRGB(17, 18, 27),
        Surface2 = Color3.fromRGB(28, 29, 42),
        Border = Color3.fromRGB(67, 68, 91),
        Accent = Color3.fromRGB(157, 104, 255),
        Accent2 = Color3.fromRGB(77, 180, 255),
        Text = Color3.fromRGB(247, 246, 255),
        Muted = Color3.fromRGB(158, 157, 180),
        Danger = Color3.fromRGB(255, 90, 112),
    },
}

Vortex.Theme = Vortex.Themes.Vortex

local function themeRoleForColor(color)
    if typeof(color) ~= "Color3" then return nil end
    local theme = Vortex.Theme
    local roles = {
        Background = theme.Background,
        Surface = theme.Surface,
        Surface2 = theme.Surface2,
        Border = theme.Border,
        Accent = theme.Accent,
        Accent2 = theme.Accent2,
        Accent3 = theme.Accent3,
        Text = theme.Text,
        Muted = theme.Muted,
        Danger = theme.Danger,
        Glow = theme.Glow,
    }
    for role, value in pairs(roles) do
        if value and color == value then return role end
    end
    return nil
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        local ok, err = pcall(function()
            object[property] = value
        end)
        if not ok then warn(err) end
    end
    local isTextObject = object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")
    if isTextObject then
        Vortex.TextObjects[object] = true
        if Vortex.Font then pcall(function() object.Font = Vortex.Font end) end
    end
    local backgroundColor
    pcall(function() backgroundColor = object.BackgroundColor3 end)
    local backgroundRole = themeRoleForColor(backgroundColor)
    if backgroundRole then object:SetAttribute("ThemeRole", backgroundRole) end
    local textRole = isTextObject and themeRoleForColor(object.TextColor3)
    if textRole then object:SetAttribute("TextThemeRole", textRole) end
    local strokeColor
    if object:IsA("UIStroke") then pcall(function() strokeColor = object.Color end) end
    local strokeRole = themeRoleForColor(strokeColor)
    if strokeRole then object:SetAttribute("ThemeRole", strokeRole) end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

local function stroke(parent, color, transparency, thickness)
    return make("UIStroke", {
        Color = color or Vortex.Theme.Border,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function tween(object, duration, properties, style)
    local previous = activeTweens[object]
    if previous then
        pcall(function() previous:Cancel() end)
    end
    local animation = TweenService:Create(object, TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    ), properties)
    activeTweens[object] = animation
    animation:Play()
    animation.Completed:Once(function()
        if activeTweens[object] == animation then activeTweens[object] = nil end
    end)
    return animation
end

local function signal(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function animateButton(button, normalColor, hoverColor)
    local scale = button:FindFirstChild("VortexButtonScale")
    if not scale then
        local size = button.Size
        local position = button.Position
        button.AnchorPoint = Vector2.new(0.5, 0.5)
        button.Position = UDim2.new(
            position.X.Scale,
            position.X.Offset + size.X.Offset / 2,
            position.Y.Scale,
            position.Y.Offset + size.Y.Offset / 2
        )
        scale = make("UIScale", {Name = "VortexButtonScale", Scale = 1}, button)
    end
    button.MouseEnter:Connect(function()
        tween(button, 0.16, {BackgroundColor3 = hoverColor or normalColor})
        tween(scale, 0.16, {Scale = 1.025}, Enum.EasingStyle.Back)
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.2, {BackgroundColor3 = normalColor})
        tween(scale, 0.2, {Scale = 1}, Enum.EasingStyle.Quint)
    end)
    button.MouseButton1Down:Connect(function()
        tween(scale, 0.08, {Scale = 0.96}, Enum.EasingStyle.Quad)
    end)
    button.MouseButton1Up:Connect(function()
        tween(scale, 0.16, {Scale = 1.025}, Enum.EasingStyle.Back)
    end)
    button.InputEnded:Connect(function(input)
        if signal(input) then tween(scale, 0.16, {Scale = 1}, Enum.EasingStyle.Quint) end
    end)
end

local function setText(label, text)
    label.Text = tostring(text or "")
end

function Vortex:SetTheme(theme)
    local selected
    if typeof(theme) == "table" then
        selected = theme
    elseif type(theme) == "string" then
        selected = self.Themes[theme] or self.Themes[theme:lower()]
        if not selected then
            for name, candidate in pairs(self.Themes) do
                if type(name) == "string" and name:lower() == theme:lower() then
                    selected = candidate
                    break
                end
            end
        end
    end
    if not selected then
        warn(("Unknown theme: %s"):format(tostring(theme)))
        return nil
    end
    local previous = self.Theme or self.Themes.Vortex
    self.Theme = selected
    self.ThemeName = typeof(theme) == "string" and theme or self.ThemeName
    Vortex.Theme = selected
    local replacements = {
        [previous.Background] = selected.Background,
        [previous.Surface] = selected.Surface,
        [previous.Surface2] = selected.Surface2,
        [previous.Border] = selected.Border,
        [previous.Accent] = selected.Accent,
        [previous.Accent2] = selected.Accent2,
        [previous.Text] = selected.Text,
        [previous.Muted] = selected.Muted,
        [previous.Danger] = selected.Danger,
    }
    for _, window in ipairs(self.Windows) do
        if window.Gui and window.Gui.Parent then
            for _, object in ipairs(window.Gui:GetDescendants()) do
                if object:IsA("GuiObject") then
                    local role = object:GetAttribute("ThemeRole")
                    local replacement = role and selected[role]
                    if replacement then object.BackgroundColor3 = replacement end
                    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                        local textRole = object:GetAttribute("TextThemeRole")
                        replacement = textRole and selected[textRole]
                        if replacement then object.TextColor3 = replacement end
                    end
                elseif object:IsA("UIStroke") then
                    local role = object:GetAttribute("ThemeRole")
                    local replacement = role and selected[role]
                    if replacement then object.Color = replacement end
                elseif object:IsA("UIGradient") then
                    if object.Parent and object.Parent:IsA("UIStroke") then
                        object.Color = ColorSequence.new(selected.Accent, selected.Accent2 or selected.Accent)
                    else
                        object.Color = ColorSequence.new(selected.Background, selected.Surface)
                    end
                end
            end
        end
    end
    return selected
end

function Vortex:AddTheme(name, theme)
    if type(name) ~= "string" or type(theme) ~= "table" then return false end
    local merged = {}
    for key, value in pairs(self.Themes.Vortex) do merged[key] = value end
    for key, value in pairs(theme) do merged[key] = value end
    self.Themes[name] = merged
    return true
end

function Vortex:RegisterIcon(name, asset)
    if type(name) ~= "string" then return false end
    local normalized = normalizeIcon(asset)
    if not normalized then return false end
    local key = name:lower()
    if self.Icons[key] then
        warn(("Icon already registered; replacing: %s"):format(name))
    end
    self.Icons[key] = normalized
    return normalized
end

function Vortex:GetIcon(name)
    return self.Icons[type(name) == "string" and name:lower() or ""]
end

function Vortex:CreateIcon(parent, name, size, color)
    return makeIcon(parent, self:GetIcon(name) or name, size, color)
end

function Vortex:SetFont(font)
    if typeof(font) ~= "EnumItem" or font.EnumType ~= Enum.Font then
        warn("SetFont expects an Enum.Font value")
        return false
    end
    self.Font = font
    for object in pairs(self.TextObjects) do
        if object and object.Parent then
            pcall(function() object.Font = font end)
        else
            self.TextObjects[object] = nil
        end
    end
    return font
end

function Vortex:IsRunning()
    local hasNotifications = self._NotificationGui ~= nil and self._NotificationGui.Parent ~= nil
    return self._Running ~= false and (#self.Windows > 0 or hasNotifications)
end

function Vortex:GetFlag(name)
    local control = self.Flags[name]
    return control and control.Get and control:Get() or nil
end

function Vortex:SetFlag(name, value)
    local control = self.Flags[name]
    if control and control.Set then control:Set(value) return true end
    return false
end

local function registerFlag(name, control)
    if not name then return end
    if Vortex.Flags[name] and Vortex.Flags[name] ~= control then
        warn(("Duplicate flag '%s'; replacing previous control"):format(tostring(name)))
    end
    Vortex.Flags[name] = control
end

local function serializeSequence(sequence)
    local keypoints = {}
    for _, keypoint in ipairs(sequence.Keypoints) do
        table.insert(keypoints, {Time = keypoint.Time, Value = keypoint.Value, Envelope = keypoint.Envelope})
    end
    return keypoints
end

local function serializeFlag(value)
    if typeof(value) == "EnumItem" then
        local enumType = tostring(value.EnumType):match("%.([^%.]+)$")
        return {__type = "Enum", EnumType = enumType, Name = value.Name}
    elseif typeof(value) == "Color3" then
        return {__type = "Color3", R = value.R, G = value.G, B = value.B}
    elseif typeof(value) == "Vector2" then
        return {__type = "Vector2", X = value.X, Y = value.Y}
    elseif typeof(value) == "Vector3" then
        return {__type = "Vector3", X = value.X, Y = value.Y, Z = value.Z}
    elseif typeof(value) == "UDim" then
        return {__type = "UDim", Scale = value.Scale, Offset = value.Offset}
    elseif typeof(value) == "UDim2" then
        return {__type = "UDim2", X = serializeFlag(value.X), Y = serializeFlag(value.Y)}
    elseif typeof(value) == "ColorSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints) do
            table.insert(keypoints, {Time = keypoint.Time, Color = serializeFlag(keypoint.Value)})
        end
        return {__type = "ColorSequence", Keypoints = keypoints}
    elseif typeof(value) == "NumberSequence" then
        return {__type = "NumberSequence", Keypoints = serializeSequence(value)}
    end
    return value
end

local function deserializeFlag(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.R, value.G, value.B)
    elseif type(value) == "table" and value.__type == "Enum" then
        local enumType = Enum[value.EnumType]
        return enumType and enumType[value.Name] or nil
    elseif type(value) == "table" and value.__type == "Vector2" then
        return Vector2.new(value.X, value.Y)
    elseif type(value) == "table" and value.__type == "Vector3" then
        return Vector3.new(value.X, value.Y, value.Z)
    elseif type(value) == "table" and value.__type == "UDim" then
        return UDim.new(value.Scale, value.Offset)
    elseif type(value) == "table" and value.__type == "UDim2" then
        local x, y = deserializeFlag(value.X), deserializeFlag(value.Y)
        return x and y and UDim2.new(x.Scale, x.Offset, y.Scale, y.Offset) or nil
    elseif type(value) == "table" and value.__type == "ColorSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints or {}) do
            local color = deserializeFlag(keypoint.Color)
            if not color then return nil end
            table.insert(keypoints, ColorSequenceKeypoint.new(keypoint.Time, color))
        end
        return #keypoints > 0 and ColorSequence.new(keypoints) or nil
    elseif type(value) == "table" and value.__type == "NumberSequence" then
        local keypoints = {}
        for _, keypoint in ipairs(value.Keypoints or {}) do
            table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value, keypoint.Envelope or 0))
        end
        return #keypoints > 0 and NumberSequence.new(keypoints) or nil
    end
    return value
end

function Vortex:SaveFlags(name)
    local values = {}
    for flagName, control in pairs(self.Flags) do
        if control and control.Get then
            local ok, value = pcall(control.Get, control)
            if ok then
                values[flagName] = serializeFlag(value)
            else
                warn(("Failed to save flag %s: %s"):format(tostring(flagName), tostring(value)))
            end
        end
    end
    return self:SaveConfig(name or "VortexFlags", values)
end

function Vortex:LoadFlags(name)
    local values, err = self:LoadConfig(name or "VortexFlags")
    if not values then return false, err end
    local unknownFlags = 0
    for flagName, value in pairs(values) do
        local decoded = deserializeFlag(value)
        if decoded ~= nil then
            if not self:SetFlag(flagName, decoded) then
                unknownFlags += 1
                warn(("Unknown flag in config: %s"):format(tostring(flagName)))
            end
        else
            warn(("Skipping invalid value for flag: %s"):format(tostring(flagName)))
        end
    end
    return true, unknownFlags > 0 and unknownFlags or nil
end

function Vortex:Notify(title, message, duration)
    if type(title) == "table" then
        local config = title
        title, message, duration = config.Title or config.Name, config.Content or config.Message, config.Duration or duration
    end
    duration = duration or 3
    local gui = self._NotificationGui
    if not gui or not gui.Parent then
        gui = make("ScreenGui", {
            Name = "VortexNotifications",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        }, getPlayerGui())
        self._NotificationGui = gui
        self._NotificationList = make("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 16),
            Size = UDim2.fromOffset(300, 420),
            BackgroundTransparency = 1,
        }, gui)
        make("UIListLayout", {
            Padding = UDim.new(0, 8),
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, self._NotificationList)
    end

    local notificationFrames = {}
    for _, child in ipairs(self._NotificationList:GetChildren()) do
        if child:IsA("Frame") then table.insert(notificationFrames, child) end
    end
    while #notificationFrames >= math.max(1, self.NotificationLimit or 5) do
        local oldest = table.remove(notificationFrames, 1)
        if oldest and oldest.Parent then
            local oldestCard = oldest:FindFirstChildWhichIsA("Frame")
            if oldestCard then
                local removal = tween(oldestCard, 0.18, {Position = UDim2.new(1, 330, 0, 0)})
                task.spawn(function()
                    if oldestCard.Parent then removal.Completed:Wait() end
                    if oldest.Parent then oldest:Destroy() end
                end)
            else
                oldest:Destroy()
            end
        end
    end

    local theme = self.Theme
    local messageText = tostring(message or "")
    local notificationFont = self.Font or Enum.Font.Gotham
    local messageBounds = TextService:GetTextSize(messageText, 11, notificationFont, Vector2.new(270, 1000))
    local notificationHeight = math.max(64, 42 + messageBounds.Y)
    local holder = make("Frame", {
        Size = UDim2.new(1, 0, 0, notificationHeight),
        BackgroundTransparency = 1,
    }, self._NotificationList)
    local card = make("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 330, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
    }, holder)
    corner(card, 9)
    stroke(card, theme.Accent, 0.35, 1)
    local bar = make("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = theme.Accent2,
        BorderSizePixel = 0,
    }, card)
    corner(bar, 2)
    make("TextLabel", {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -24, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(title or "Vortex Hub"),
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    make("TextLabel", {
        Position = UDim2.fromOffset(14, 29),
        Size = UDim2.new(1, -24, 0, messageBounds.Y),
        BackgroundTransparency = 1,
        Text = messageText,
        TextColor3 = theme.Muted,
        Font = notificationFont,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, card)
    tween(card, 0.25, {Position = UDim2.new(1, 0, 0, 0)})
    task.delay(duration, function()
        if not card.Parent or not card:IsDescendantOf(game) then return end
        local out = tween(card, 0.2, {Position = UDim2.new(1, 330, 0, 0)})
        if card.Parent then out.Completed:Wait() end
        if holder.Parent then holder:Destroy() end
    end)
    return holder
end

function Vortex:CreateWindow(options)
    options = options or {}
    local theme = self.Theme
    local title = options.Title or "Vortex Hub"
    local subtitle = options.Subtitle or "Owned by Nexxy"
    local width = options.Width or 430
    local height = options.Height or 330
    local backgroundImage = options.BackgroundImage or options.Image
    local backgroundTransparency = options.BackgroundImageTransparency
    if backgroundTransparency == nil then backgroundTransparency = 0.72 end
    local backgroundTint = options.BackgroundImageColor or Color3.new(1, 1, 1)
    local backgroundScaleType = options.BackgroundScaleType or Enum.ScaleType.Crop
    local autoSize = options.AutoSize ~= false
    local mobileHeightRatio = math.clamp(options.MobileHeightRatio or 0.78, 0.62, 0.9)
    local mobileAspectRatio = math.clamp(options.MobileAspectRatio or (width / height), 0.72, 1.5)
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    local isTouch = UserInputService.TouchEnabled
    local device = isTouch and (viewport.X < 600 and "Phone" or "Tablet") or "Desktop"
    local function responsiveSize(view)
        if not autoSize then return width, height end
        local marginX = device == "Phone" and 16 or 28
        local marginY = device == "Phone" and 28 or 40
        local maxWidth = math.max(260, view.X - marginX)
        local maxHeight = math.max(190, view.Y - marginY)
        local targetWidth = math.min(width, maxWidth)
        local targetHeight = math.min(height, maxHeight)
        if device == "Phone" then
            targetHeight = math.min(targetHeight, view.Y * mobileHeightRatio)
            targetWidth = targetHeight * mobileAspectRatio
            if targetWidth > maxWidth then
                targetWidth = maxWidth
                targetHeight = targetWidth / mobileAspectRatio
            end
        elseif device == "Tablet" then
            targetWidth = math.min(targetWidth, view.X * 0.88)
            targetHeight = math.min(targetHeight, view.Y * 0.78)
        end
        return math.floor(targetWidth), math.floor(targetHeight)
    end
    width, height = responsiveSize(viewport)

    for _, oldWindow in ipairs(self.Windows) do
        oldWindow._Destroyed = true
        for _, connection in ipairs(oldWindow._connections or {}) do
            if connection and connection.Connected then connection:Disconnect() end
        end
        if oldWindow.Gui then oldWindow.Gui:Destroy() end
    end
    table.clear(self.Windows)
    table.clear(self.Flags)
    local old = getPlayerGui():FindFirstChild("VortexHub")
    if old then old:Destroy() end

    local gui = make("ScreenGui", {
        Name = "VortexHub",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, getPlayerGui())
    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    if self.Scale and self.Scale ~= 1 then
        make("UIScale", {Name = "VortexScale", Scale = self.Scale}, root)
    end
    corner(root, 14)
    make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Background),
            ColorSequenceKeypoint.new(0.55, theme.Surface),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 18)),
        }),
        Rotation = 135,
    }, root)
    local background = make("ImageLabel", {
        Name = "VortexBackground",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = backgroundImage or "",
        ImageColor3 = backgroundTint,
        ImageTransparency = backgroundTransparency,
        ScaleType = backgroundScaleType,
        ZIndex = 0,
    }, root)
    corner(background, 14)
    local backgroundDim = make("Frame", {
        Name = "VortexBackgroundDim",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Background,
        BackgroundTransparency = options.BackgroundDimTransparency or 0.3,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, root)
    corner(backgroundDim, 14)
    local glowFrame = make("Frame", {
        Name = "VortexInnerGlow",
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 1,
    }, root)
    corner(glowFrame, 10)
    local outline = stroke(glowFrame, theme.Border, 0.1, 2)
    local gradient = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Accent),
            ColorSequenceKeypoint.new(0.5, theme.Accent2),
            ColorSequenceKeypoint.new(1, theme.Accent3 or theme.Accent),
        }),
        Rotation = 20,
    }, outline)
    local scanline = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.12, 0, 0.88, 0),
        Size = UDim2.new(0.12, 0, 1.15, 0),
        Rotation = -38,
        BackgroundColor3 = theme.Accent2,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, root)
    local scanGradient = make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(theme.Accent, theme.Accent2),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.45, 0.15),
            NumberSequenceKeypoint.new(0.55, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, scanline)
    corner(scanline, 12)
    task.spawn(function()
        while scanline.Parent do
            if not gui.Enabled or not scanline.Visible then task.wait(0.2) continue end
            scanline.Position = UDim2.new(0.12, 0, 0.88, 0)
            local pass = tween(scanline, 2.8, {Position = UDim2.new(0.88, 0, 0.12, 0)}, Enum.EasingStyle.Sine)
            pass.Completed:Wait()
            task.wait(0.55)
        end
    end)
    local gradientConnection = RunService.RenderStepped:Connect(function(delta)
        if not root.Parent then gradientConnection:Disconnect() return end
        if not gui.Enabled then return end
        gradient.Rotation = (gradient.Rotation + delta * 35) % 360
    end)

    local top = make("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, root)
    corner(top, 14)
    local topRepair = make("Frame", {
        Position = UDim2.new(0, 0, 1, -14),
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
    }, top)
    local titleOffset = 16
    local titleIcon = makeIcon(top, self:GetIcon(options.TitleIcon) or options.TitleIcon, 16, theme.Accent, "VortexTitleIcon")
    if titleIcon then
        titleIcon.Position = UDim2.fromOffset(16, 21)
        titleIcon.AnchorPoint = Vector2.new(0, 0.5)
        titleOffset = 38
    end
    local titleLabel = make("TextLabel", {
        Position = UDim2.fromOffset(titleOffset, 8),
        Size = UDim2.new(1, titleOffset - 110, 0, 22),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, top)
    make("TextLabel", {
        Name = "VortexAuthor",
        Position = UDim2.fromOffset(17, 31),
        Size = UDim2.new(1, -110, 0, 16),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = theme.Muted,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)
    local minimize = make("TextButton", {
        Position = UDim2.new(1, -70, 0, 17),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = theme.Surface2,
        Text = "—",
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        AutoButtonColor = false,
    }, top)
    corner(minimize, 6)
    animateButton(minimize, theme.Surface2, theme.Border)
    local close = make("TextButton", {
        Position = UDim2.new(1, -40, 0, 17),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = theme.Danger,
        BackgroundTransparency = 0.15,
        Text = "×",
        TextColor3 = theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        AutoButtonColor = false,
    }, top)
    corner(close, 6)
    animateButton(close, theme.Danger, Color3.fromRGB(255, 110, 125))

    local tabBar = make("ScrollingFrame", {
        Position = UDim2.fromOffset(12, 66),
        Size = UDim2.new(1, -24, 0, 34),
        BackgroundTransparency = 1,
        ZIndex = 2,
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 0,
    }, root)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabBar)
    local content = make("Frame", {
        Position = UDim2.fromOffset(12, 108),
        Size = UDim2.new(1, -24, 1, -120),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2,
    }, root)

    local window = {
        Gui = gui,
        Root = root,
        Tabs = {},
        TabLookup = {},
        TabLookupLower = {},
        CurrentTab = nil,
        NormalSize = UDim2.fromOffset(width, height),
        IsOpen = true,
        IsMinimized = false,
        _connections = {gradientConnection},
    }
    table.insert(self.Windows, window)
    function window:Track(connection)
        if connection then table.insert(self._connections, connection) end
        return connection
    end

    window.Background = background
    window.BackgroundDim = backgroundDim
    function window:SetBackground(image, transparency, tint, scaleType)
        local targetTransparency = transparency ~= nil and math.clamp(transparency, 0, 1) or self.Background.ImageTransparency
        tween(self.Background, 0.14, {ImageTransparency = 1})
        task.delay(0.14, function()
            if not self.Background or not self.Background.Parent then return end
            self.Background.Image = image or ""
            tween(self.Background, 0.18, {ImageTransparency = targetTransparency})
        end)
        if tint then self.Background.ImageColor3 = tint end
        if scaleType then self.Background.ScaleType = scaleType end
        return self.Background
    end
    function window:SetBackgroundTransparency(value)
        self.Background.ImageTransparency = math.clamp(value or 0, 0, 1)
    end
    function window:SetBackgroundDim(value)
        self.BackgroundDim.BackgroundTransparency = math.clamp(value or 0, 0, 1)
    end
    function window:RemoveBackground()
        self.Background.Image = ""
    end

    window.Device = device
    window.AutoSize = autoSize
    function window:ClampToViewport()
        local currentCamera = workspace.CurrentCamera
        if not currentCamera or not self.Root or not self.Root.Parent then return end
        local view, size = currentCamera.ViewportSize, self.Root.AbsoluteSize
        local x = math.clamp(self.Root.AbsolutePosition.X, 8, math.max(8, view.X - size.X - 8))
        local y = math.clamp(self.Root.AbsolutePosition.Y, 8, math.max(8, view.Y - size.Y - 8))
        self.Root.Position = UDim2.fromOffset(x + size.X / 2, y + size.Y / 2)
    end
    function window:ResponsiveSize()
        local currentCamera = workspace.CurrentCamera
        if not currentCamera then return self.NormalSize end
        local view = currentCamera.ViewportSize
        device = isTouch and (view.X < 600 and "Phone" or "Tablet") or "Desktop"
        self.Device = device
        width, height = responsiveSize(view)
        self.NormalSize = UDim2.fromOffset(width, height)
        if not self.IsMinimized then tween(self.Root, 0.24, {Size = self.NormalSize}) end
        task.defer(function() if self.Root and self.Root.Parent then self:ClampToViewport() end end)
        return self.NormalSize
    end
    local viewportConnection
    if camera and autoSize then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            if window.Gui and window.Gui.Parent then window:ResponsiveSize() end
        end)
        table.insert(window._connections, viewportConnection)
    end

    root.Size = UDim2.fromOffset(math.max(1, width - 80), math.max(1, height - 80))
    root.BackgroundTransparency = 1
    tween(root, 0.38, {Size = window.NormalSize, BackgroundTransparency = 0}, Enum.EasingStyle.Back)
    task.defer(function()
        if root.Parent then window:ClampToViewport() end
    end)

    local dragging = false
    local dragBlocked = false
    local dragStart, startPosition, dragTarget, startAbsolute
    local dragSmoothing = RunService.RenderStepped:Connect(function()
        if dragging and dragTarget and root.Parent then
            root.Position = root.Position:Lerp(dragTarget, 0.24)
            window:ClampToViewport()
        end
    end)
    table.insert(window._connections, dragSmoothing)
    window:Track(top.InputBegan:Connect(function(input)
        if signal(input) and not dragBlocked then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
            startAbsolute = root.AbsolutePosition
            dragTarget = root.Position
        end
    end))
    window:Track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local view = camera and camera.ViewportSize or Vector2.new(800, 600)
            local size = root.AbsoluteSize
            local x = math.clamp(startAbsolute.X + delta.X, 8, math.max(8, view.X - size.X - 8))
            local y = math.clamp(startAbsolute.Y + delta.Y, 8, math.max(8, view.Y - size.Y - 8))
            dragTarget = UDim2.fromOffset(x + size.X / 2, y + size.Y / 2)
        end
    end))
    window:Track(UserInputService.InputEnded:Connect(function(input)
        if signal(input) then dragging = false dragTarget = nil end
    end))

    local minimized = false
    minimize.InputBegan:Connect(function(input) if signal(input) then dragBlocked = true end end)
    close.InputBegan:Connect(function(input) if signal(input) then dragBlocked = true end end)
    window:Track(UserInputService.InputEnded:Connect(function(input) if signal(input) then dragBlocked = false end end))
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        window:Minimize(minimized)
    end)
    close.MouseButton1Click:Connect(function() window:Destroy() end)

    function window:Destroy()
        if self._Destroyed then return end
        self._Destroyed = true
        dragging = false
        dragTarget = nil
        self.IsOpen = false
        for _, connection in ipairs(self._connections) do
            if connection and connection.Connected then connection:Disconnect() end
        end
        if self.Gui then
            local closing = tween(self.Root, 0.2, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1})
            local guiToDestroy = self.Gui
            closing.Completed:Connect(function()
                if guiToDestroy.Parent and self._Destroyed then guiToDestroy:Destroy() end
            end)
        end
        for index, item in ipairs(Vortex.Windows) do
            if item == self then table.remove(Vortex.Windows, index) break end
        end
    end

    function window:Open()
        if self._Destroyed or (self.IsOpen and self.Root.Visible) then return end
        self.IsOpen = true
        self.Gui.Enabled = true
        self.Root.Visible = true
        scanline.Visible = true
        tween(self.Root, 0.28, {Size = self.IsMinimized and UDim2.fromOffset(width, 58) or self.NormalSize, BackgroundTransparency = 0}, Enum.EasingStyle.Back)
    end

    function window:Close()
        if self._Destroyed or (not self.IsOpen and not self.Root.Visible) then return end
        self.IsOpen = false
        scanline.Visible = false
        local closing = tween(self.Root, 0.22, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}, Enum.EasingStyle.Quint)
        closing.Completed:Connect(function()
            if not self.IsOpen and self.Gui then self.Gui.Enabled = false end
        end)
    end

    function window:Toggle()
        if self.IsOpen then self:Close() else self:Open() end
    end

    function window:SetVisible(visible)
        if visible then self:Open() else self:Close() end
    end

    function window:SetSize(newWidth, newHeight)
        width, height = math.max(280, newWidth or width), math.max(180, newHeight or height)
        self.NormalSize = UDim2.fromOffset(width, height)
        if not self.IsMinimized then tween(self.Root, 0.22, {Size = self.NormalSize}) end
        task.defer(function() if self.Root and self.Root.Parent then self:ClampToViewport() end end)
    end

    function window:Center()
        tween(self.Root, 0.25, {Position = UDim2.fromScale(0.5, 0.5)})
    end

    function window:Minimize(value)
        if value == nil then value = not self.IsMinimized end
        self.IsMinimized = value == true
        tabBar.Visible = not self.IsMinimized
        content.Visible = not self.IsMinimized
        minimize.Text = self.IsMinimized and "+" or "—"
        topRepair.Visible = not self.IsMinimized
        tween(self.Root, 0.28, {Size = self.IsMinimized and UDim2.fromOffset(width, 58) or self.NormalSize}, Enum.EasingStyle.Quint)
    end

    function window:SetTitle(value)
        setText(titleLabel, value)
    end

    function window:SetAuthor(value)
        local authorLabel = top:FindFirstChild("VortexAuthor")
        if not authorLabel then
            authorLabel = make("TextLabel", {Name = "VortexAuthor", Position = UDim2.fromOffset(17, 31), Size = UDim2.new(1, -110, 0, 16), BackgroundTransparency = 1, TextColor3 = theme.Muted, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left}, top)
        end
        authorLabel.Text = tostring(value or "")
        return authorLabel
    end

    function window:SetPanelBackground(visible)
        top.BackgroundTransparency = visible == false and 1 or 0
        return visible ~= false
    end

    function window:Dialog(dialogOptions)
        dialogOptions = dialogOptions or {}
        local overlay = make("Frame", {Name = "VortexDialog", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 50}, root)
        local card = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.new(0.86, 0, 0, 150), BackgroundColor3 = theme.Surface, BackgroundTransparency = 1, ZIndex = 51}, overlay)
        corner(card, 12)
        stroke(card, theme.Accent, 0.2, 1)
        local titleObject = make("TextLabel", {Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22), BackgroundTransparency = 1, Text = tostring(dialogOptions.Title or "Vortex Hub"), TextColor3 = theme.Text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52}, card)
        local messageObject = make("TextLabel", {Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 52), BackgroundTransparency = 1, Text = tostring(dialogOptions.Content or dialogOptions.Message or ""), TextColor3 = theme.Muted, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 52}, card)
        local actions = make("Frame", {Position = UDim2.new(0, 16, 1, -44), Size = UDim2.new(1, -32, 0, 30), BackgroundTransparency = 1, ZIndex = 52}, card)
        make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 7)}, actions)
        local dialog = {Object = overlay, Title = titleObject, Message = messageObject}
        local function close(result)
            if dialog.Closed then return end
            dialog.Closed = true
            local out = tween(card, 0.16, {Position = UDim2.fromScale(0.5, 0.54), BackgroundTransparency = 1})
            tween(overlay, 0.16, {BackgroundTransparency = 1})
            out.Completed:Connect(function() if overlay.Parent then overlay:Destroy() end end)
            if dialogOptions.Callback then task.spawn(dialogOptions.Callback, result) end
        end
        for _, action in ipairs(dialogOptions.Actions or {{Name = "Close", Value = false}}) do
            local actionButton = make("TextButton", {Size = UDim2.fromOffset(action.Width or 78, 30), BackgroundColor3 = action.Primary and theme.Accent or theme.Surface2, Text = tostring(action.Name or "OK"), TextColor3 = theme.Text, Font = Enum.Font.GothamMedium, TextSize = 10, AutoButtonColor = false, ZIndex = 53}, actions)
            corner(actionButton, 7)
            animateButton(actionButton, action.Primary and theme.Accent or theme.Surface2, theme.Accent2)
            actionButton.MouseButton1Click:Connect(function() close(action.Value == nil and action.Name or action.Value) end)
        end
        tween(overlay, 0.2, {BackgroundTransparency = 0.38})
        tween(card, 0.26, {Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0}, Enum.EasingStyle.Back)
        function dialog:Close(result) close(result) end
        return dialog
    end

    window.Popup = window.Dialog

    function window:Tooltip(target, text)
        if not target or not target:IsA("GuiObject") then return nil end
        local tip = make("TextLabel", {Name = "VortexTooltip", AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = theme.Surface, Text = tostring(text or ""), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, Visible = false, ZIndex = 100}, gui)
        corner(tip, 6)
        stroke(tip, theme.Accent, 0.35, 1)
        make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)}, tip)
        local hovered = false
        local function place()
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
            local x = math.clamp(target.AbsolutePosition.X, 6, math.max(6, viewport.X - tip.AbsoluteSize.X - 6))
            local above = target.AbsolutePosition.Y - tip.AbsoluteSize.Y - 6
            local below = target.AbsolutePosition.Y + target.AbsoluteSize.Y + 6
            local y = above >= 6 and above or math.min(below, viewport.Y - tip.AbsoluteSize.Y - 6)
            tip.Position = UDim2.fromOffset(x, math.max(6, y))
        end
        window:Track(target.MouseEnter:Connect(function() hovered = true tip.Visible = true place() tween(tip, 0.15, {TextTransparency = 0}) end))
        window:Track(target.MouseLeave:Connect(function()
            hovered = false
            tween(tip, 0.12, {TextTransparency = 1}).Completed:Connect(function()
                if hovered or not tip.Parent then return end
                tip:Destroy()
            end)
        end))
        return tip
    end

    function window:SelectTab(tab)
        if tab ~= nil then
            local belongsToWindow = false
            for _, item in ipairs(self.Tabs) do
                if item == tab then belongsToWindow = true break end
            end
            if not belongsToWindow or tab.Destroyed or not tab.Page or not tab.Page.Parent then return false end
        end
        for _, item in ipairs(self.Tabs) do
            item.Page.Visible = false
            tween(item.Button, 0.12, {BackgroundColor3 = theme.Surface2})
            tween(item.Label, 0.12, {TextColor3 = theme.Muted})
        end
        if tab then
            tab.Page.Visible = true
            tween(tab.Button, 0.16, {BackgroundColor3 = theme.Accent})
            tween(tab.Label, 0.16, {TextColor3 = theme.Text})
            self.CurrentTab = tab
        end
        return tab ~= nil
    end

    function window:SelectTabByName(name)
        if type(name) ~= "string" then return nil end
        local tab = self.TabLookup[name] or self.TabLookupLower[name:lower()]
        if tab and self:SelectTab(tab) then return tab end
    end

    function window:RemoveTab(tab)
        for index, item in ipairs(self.Tabs) do
            if item == tab or item.Name == tab then
                item.Destroyed = true
                if item.Button then item.Button:Destroy() end
                if item.Page then item.Page:Destroy() end
                if self.TabLookup[item.Name] == item then self.TabLookup[item.Name] = nil end
                if self.TabLookupLower[item.Name:lower()] == item then self.TabLookupLower[item.Name:lower()] = nil end
                table.remove(self.Tabs, index)
                if self.CurrentTab == item then self:SelectTab(self.Tabs[1]) end
                return true
            end
        end
        return false
    end

    function window:AddTab(tabOptions)
        if type(tabOptions) == "string" then
            tabOptions = {Name = tabOptions}
        else
            tabOptions = tabOptions or {}
        end
        local tabName = tostring(tabOptions.Name or tabOptions.Title or "Tab")
        local tabNameKey = tabName:lower()
        if self.TabLookupLower[tabNameKey] then
            warn(("Duplicate tab name: %s"):format(tabName))
        end
        local tabIconValue = Vortex:GetIcon(tabOptions.Icon or tabOptions.Image) or tabOptions.Icon or tabOptions.Image
        local tabTextWidth = TextService:GetTextSize(tabName, 11, Enum.Font.GothamMedium, Vector2.new(200, 24)).X
        local tabHasIcon = tabIconValue ~= nil
        local button = make("TextButton", {
            Size = UDim2.fromOffset(math.max(70, tabTextWidth + (tabHasIcon and 48 or 24)), 30),
            BackgroundColor3 = theme.Surface2,
            Text = "",
            AutoButtonColor = false,
        }, tabBar)
        corner(button, 7)
        local tabIcon = makeIcon(button, tabIconValue, 13, theme.Accent2, "VortexTabIcon")
        if tabIcon then
            tabIcon.Position = UDim2.fromOffset(8, 8)
        end
        local tabLabelLeft = tabIcon and 27 or 9
        local tabLabel = make("TextLabel", {
            Name = "VortexTabLabel",
            Position = UDim2.fromOffset(tabLabelLeft, 0),
            Size = UDim2.new(1, -tabLabelLeft - 8, 1, 0),
            BackgroundTransparency = 1,
            Text = tabName,
            TextColor3 = theme.Muted,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, button)
        local page = make("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.Accent,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, content)
        make("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
        }, page)
        make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        local tab = {Window = self, Name = tabName, Button = button, Label = tabLabel, Icon = tabIcon, Page = page, Elements = {}}
        table.insert(self.Tabs, tab)
        self.TabLookup[tabName] = self.TabLookup[tabName] or tab
        self.TabLookupLower[tabNameKey] = self.TabLookupLower[tabNameKey] or tab
        button.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
        button.MouseEnter:Connect(function()
            if self.CurrentTab ~= tab then
                tween(button, 0.14, {BackgroundColor3 = theme.Border})
                tween(tabLabel, 0.14, {TextColor3 = theme.Text})
            end
        end)
        button.MouseLeave:Connect(function()
            if self.CurrentTab ~= tab then
                tween(button, 0.18, {BackgroundColor3 = theme.Surface2})
                tween(tabLabel, 0.18, {TextColor3 = theme.Muted})
            end
        end)
        if #self.Tabs == 1 then self:SelectTab(tab) end

        function tab:AddSection(name, description)
            local sectionIcon
            if type(name) == "table" then
                local config = name
                name, description, sectionIcon = config.Name or "Section", config.Description or config.Content, config.Icon or config.Image
            end
            local frame = make("Frame", {
                Size = UDim2.new(1, 0, 0, description and 44 or 25),
                BackgroundTransparency = 1,
            }, page)
            local icon = makeIcon(frame, Vortex:GetIcon(sectionIcon) or sectionIcon, 14, theme.Accent2, "VortexSectionIcon")
            make("TextLabel", {
                Position = UDim2.fromOffset(icon and 20 or 0, 0),
                Size = UDim2.new(1, icon and -20 or 0, 0, 20),
                BackgroundTransparency = 1,
                Text = name or "Section",
                TextColor3 = theme.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, frame)
            if icon then icon.Position = UDim2.fromOffset(0, 3) end
            if description then
                make("TextLabel", {
                    Position = UDim2.fromOffset(0, 20),
                    Size = UDim2.new(1, 0, 0, 17),
                    BackgroundTransparency = 1,
                    Text = description,
                    TextColor3 = theme.Muted,
                    Font = Enum.Font.Gotham,
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                }, frame)
            end
            return frame
        end

        function tab:AddLabel(text)
            local iconValue
            if type(text) == "table" then
                iconValue = text.Icon or text.Image
                text = text.Text or text.Name or ""
            end
            local label = make("TextLabel", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = theme.Surface,
                Text = tostring(text or ""),
                TextColor3 = theme.Muted,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, page)
            corner(label, 7)
            make("UIPadding", {PaddingLeft = UDim.new(0, 10)}, label)
            local icon = makeIcon(label, Vortex:GetIcon(iconValue) or iconValue, 13, theme.Accent2, "VortexLabelIcon")
            if icon then icon.Position = UDim2.fromOffset(8, 7); label.TextXAlignment = Enum.TextXAlignment.Left; make("UIPadding", {PaddingLeft = UDim.new(0, 28)}, label) end
            return {Object = label, Set = function(_, value) label.Text = tostring(value) end}
        end

        function tab:AddButton(text, callback)
            local flagName
            local once = false
            local iconValue
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                once = config.Once == true or config.OneTime == true
                iconValue = config.Icon or config.Image
                text, callback = config.Name or "Button", config.Callback or callback
            end
            local buttonFrame = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = theme.Surface,
                Text = tostring(text or "Button"),
                TextColor3 = theme.Text,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
                AutoButtonColor = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, page)
            corner(buttonFrame, 8)
            stroke(buttonFrame, theme.Border, 0.35, 1)
            animateButton(buttonFrame, theme.Surface, theme.Surface2)
            local icon = makeIcon(buttonFrame, Vortex:GetIcon(iconValue) or iconValue, 14, theme.Accent2, "VortexButtonIcon")
            if icon then icon.Position = UDim2.fromOffset(10, 11); buttonFrame.TextXAlignment = Enum.TextXAlignment.Left; make("UIPadding", {PaddingLeft = UDim.new(0, 32)}, buttonFrame) end
            local clicked = false
            onceButtonStates[buttonFrame] = function(reset)
                clicked = reset ~= false
                if not clicked then buttonFrame.TextTransparency = 0 end
            end
            buttonFrame.MouseButton1Click:Connect(function()
                if once and clicked then return end
                clicked = true
                if once then
                    buttonFrame.AutoButtonColor = false
                    buttonFrame.TextTransparency = 0.35
                end
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback)
                        if not ok then warn(err) end
                    end)
                end
            end)
            if flagName then
                warn(("Button flags are action-only and are not persisted: %s"):format(tostring(flagName)))
            end
            return buttonFrame
        end

        function tab:ResetButton(button)
            if onceButtonStates[button] then onceButtonStates[button](false) end
        end

        function tab:AddOnceButton(text, callback)
            if type(text) == "table" then
                text.Once = true
                return self:AddButton(text)
            end
            return self:AddButton({Name = text, Callback = callback, Once = true})
        end

        function tab:AddToggle(text, default, callback)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, default, callback = config.Name or "Toggle", config.Default == true, config.Callback or callback
            end
            local value = default == true
            local buttonFrame = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = theme.Surface,
                Text = "",
                AutoButtonColor = false,
            }, page)
            corner(buttonFrame, 8)
            stroke(buttonFrame, theme.Border, 0.35, 1)
            animateButton(buttonFrame, theme.Surface, theme.Surface2)
            local toggleLabel = make("TextLabel", {
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.new(1, -72, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(text or "Toggle"),
                TextColor3 = theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, buttonFrame)
            local switch = make("Frame", {
                Position = UDim2.new(1, -52, 0.5, -10),
                Size = UDim2.fromOffset(40, 20),
                BackgroundColor3 = theme.Surface2,
            }, buttonFrame)
            corner(switch, 10)
            local knob = make("Frame", {Size = UDim2.fromOffset(14, 14), BackgroundColor3 = theme.Muted}, switch)
            corner(knob, 7)
            local function update(call)
                tween(switch, 0.16, {BackgroundColor3 = value and theme.Accent or theme.Surface2})
                tween(knob, 0.16, {Position = value and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = value and theme.Text or theme.Muted})
                if call and callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, value)
                        if not ok then warn(err) end
                    end)
                end
            end
            buttonFrame.MouseButton1Click:Connect(function() value = not value update(true) end)
            update(false)
            local control = {Object = buttonFrame, Get = function() return value end, Set = function(_, newValue)
                newValue = newValue == true
                if value == newValue then return false end
                value = newValue
                update(true)
                return true
            end}
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddSlider(text, minimum, maximum, default, callback)
            local flagName
            local valueName = ""
            local increment = 1
            if type(text) == "table" then
                local config = text
                flagName, valueName, increment = config.Flag, config.ValueName or "", config.Increment or 1
                text, minimum, maximum, default, callback = config.Name or "Slider", config.Min or 0, config.Max or 100, config.Default or config.Min or 0, config.Callback or callback
            end
            minimum, maximum = minimum or 0, maximum or 100
            if maximum < minimum then minimum, maximum = maximum, minimum end
            increment = math.max(math.abs(tonumber(increment) or 1), 0.000001)
            local value = math.clamp(default or minimum, minimum, maximum)
            local function displayValue(number)
                local formatted = string.format("%.6f", number):gsub("0+$", ""):gsub("%.$", "")
                return formatted .. valueName
            end
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -70, 0, 16), BackgroundTransparency = 1, Text = tostring(text or "Slider"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, frame)
            local valueLabel = make("TextLabel", {Position = UDim2.new(1, -58, 0, 7), Size = UDim2.fromOffset(46, 16), BackgroundTransparency = 1, Text = displayValue(value), TextColor3 = theme.Accent2, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right}, frame)
            local track = make("Frame", {Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = theme.Surface2}, frame)
            corner(track, 3)
            local fill = make("Frame", {Size = UDim2.fromScale((value - minimum) / math.max(1, maximum - minimum), 1), BackgroundColor3 = theme.Accent}, track)
            corner(fill, 3)
            local draggingSlider = false
            local function setValueFromX(x, call)
                if track.AbsoluteSize.X <= 0 then return end
                if maximum == minimum then
                    value = minimum
                    valueLabel.Text = displayValue(value)
                    fill.Size = UDim2.fromScale(0, 1)
                    return
                end
                local ratio = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                value = math.floor((minimum + (maximum - minimum) * ratio) / increment + 0.5) * increment
                value = math.clamp(value, minimum, maximum)
                value = math.clamp(value, minimum, maximum)
                valueLabel.Text = displayValue(value)
                local snappedRatio = (value - minimum) / math.max(1, maximum - minimum)
                fill.Size = UDim2.fromScale(snappedRatio, 1)
                if call and callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, value)
                        if not ok then warn(err) end
                    end)
                end
            end
            local function beginSlider(input) if signal(input) then draggingSlider = true setValueFromX(input.Position.X, true) end end
            track.InputBegan:Connect(beginSlider)
            fill.InputBegan:Connect(beginSlider)
            tab.Window:Track(UserInputService.InputChanged:Connect(function(input) if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setValueFromX(input.Position.X, true) end end))
            tab.Window:Track(UserInputService.InputEnded:Connect(function(input) if signal(input) then draggingSlider = false end end))
            frame.AncestryChanged:Connect(function(_, parent)
                if not parent then draggingSlider = false end
            end)
            local control = {Object = frame, Get = function() return value end, Set = function(_, newValue)
                value = math.clamp(newValue, minimum, maximum)
                if track.AbsoluteSize.X <= 0 then
                    task.defer(function()
                        if track.Parent and track.AbsoluteSize.X > 0 then setValueFromX(track.AbsolutePosition.X + ((value - minimum) / math.max(1, maximum - minimum)) * track.AbsoluteSize.X, true) end
                    end)
                else
                    setValueFromX(track.AbsolutePosition.X + ((value - minimum) / math.max(1, maximum - minimum)) * track.AbsoluteSize.X, true)
                end
            end}
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddTextbox(text, placeholder, callback)
            local flagName
            local defaultValue = ""
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                defaultValue = tostring(config.Default or "")
                text, placeholder, callback = config.Name or "Input", config.Placeholder or "Type here...", config.Callback or callback
            end
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.42, 0, 1, 0), BackgroundTransparency = 1, Text = tostring(text or "Input"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local box = make("TextBox", {Position = UDim2.new(0.44, 0, 0.5, -14), Size = UDim2.new(0.52, -8, 0, 28), BackgroundColor3 = theme.Background, Text = defaultValue, PlaceholderText = placeholder or "Type here...", PlaceholderColor3 = theme.Muted, TextColor3 = theme.Text, Font = Enum.Font.Code, TextSize = 11, ClearTextOnFocus = false}, frame)
            corner(box, 6)
            local internalUpdate = false
            local callbackRunning = false
            local function invokeCallback(enterPressed)
                if not callback or callbackRunning then return end
                callbackRunning = true
                task.spawn(function()
                    local ok, err = pcall(callback, box.Text, enterPressed)
                    callbackRunning = false
                    if not ok then warn(err) end
                end)
            end
            box.FocusLost:Connect(function(enterPressed)
                if internalUpdate then return end
                invokeCallback(enterPressed)
            end)
            local control = {Object = box, Get = function() return box.Text end, Set = function(_, value, silent)
                internalUpdate = true
                box.Text = tostring(value or "")
                internalUpdate = false
                if not silent then invokeCallback(true) end
            end}
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddDropdown(text, options, default, callback)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, options, default, callback = config.Name or "Dropdown", config.Options or {}, config.Default, config.Callback or callback
            end
            options = options or {}
            local function warnDuplicateOptions(values)
                local seen = {}
                for _, option in ipairs(values) do
                    local key = typeof(option) .. ":" .. tostring(option)
                    if seen[key] then
                        warn(("Duplicate dropdown option: %s"):format(tostring(option)))
                    end
                    seen[key] = true
                end
            end
            warnDuplicateOptions(options)
            local selected = default or options[1] or "Select"
            local open = false
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = theme.Surface, ClipsDescendants = true}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            local button = make("TextButton", {Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = theme.Background, Text = tostring(text or "Dropdown") .. ": " .. tostring(selected), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, frame)
            corner(button, 6)
            make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, button)
            local list = make("Frame", {Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, #options * 27), BackgroundColor3 = theme.Surface2}, frame)
            corner(list, 6)
            make("UIListLayout", {Padding = UDim.new(0, 2)}, list)
            local function closeDropdown()
                open = false
                frame.Size = UDim2.new(1, 0, 0, 44)
            end
            local function rebuildOptions()
                closeDropdown()
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                list.Size = UDim2.new(1, -20, 0, #options * 27)
                for _, option in ipairs(options) do
                    local optionButton = make("TextButton", {Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, Text = tostring(option), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false}, list)
                    optionButton.MouseButton1Click:Connect(function()
                        selected = option
                        button.Text = tostring(text or "Dropdown") .. ": " .. tostring(selected)
                        closeDropdown()
                        if callback then
                            task.spawn(function()
                                local ok, err = pcall(callback, selected)
                                if not ok then warn(err) end
                            end)
                        end
                    end)
                end
            end
            rebuildOptions()
            button.MouseButton1Click:Connect(function()
                open = not open
                frame.Size = UDim2.new(1, 0, 0, open and 48 + #options * 27 or 44)
            end)
            tab.Window:Track(UserInputService.InputBegan:Connect(function(input)
                if open and signal(input) then
                    local position = input.Position
                    local bounds = frame.AbsolutePosition
                    local size = frame.AbsoluteSize
                    if position.X < bounds.X or position.X > bounds.X + size.X or position.Y < bounds.Y or position.Y > bounds.Y + size.Y then
                        open = false
                        frame.Size = UDim2.new(1, 0, 0, 44)
                    end
                end
            end))
            local control = {Object = frame, Get = function() return selected end, Set = function(_, value)
                selected = value
                button.Text = tostring(text or "Dropdown") .. ": " .. tostring(selected)
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, selected)
                        if not ok then warn(err) end
                    end)
                end
            end}
            function control:Refresh(newOptions)
                options = newOptions or {}
                warnDuplicateOptions(options)
                if selected == nil or not table.find(options, selected) then selected = options[1] or "Select" end
                button.Text = tostring(text or "Dropdown") .. ": " .. tostring(selected)
                rebuildOptions()
            end
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddMultiDropdown(text, options, defaults, callback)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, options, defaults, callback = config.Name or "Multi-select", config.Options or {}, config.Default or config.Values, config.Callback or callback
            end
            options = options or {}
            local selected = {}
            for _, value in ipairs(defaults or {}) do selected[value] = true end
            local open = false
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = theme.Surface, ClipsDescendants = true}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            local button = make("TextButton", {Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = theme.Background, TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, frame)
            corner(button, 6)
            make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, button)
            local list = make("ScrollingFrame", {Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, math.min(130, #options * 27)), BackgroundColor3 = theme.Surface2, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.fromOffset(0, #options * 27), ScrollingDirection = Enum.ScrollingDirection.Y}, frame)
            corner(list, 6)
            make("UIListLayout", {Padding = UDim.new(0, 2)}, list)
            local optionButtons = {}
            local callbackUpdating = false
            local function refresh(call)
                local names = {}
                for _, value in ipairs(options) do if selected[value] then table.insert(names, tostring(value)) end end
                button.Text = tostring(text or "Multi-select") .. ": " .. (#names > 0 and table.concat(names, ", ") or "None")
                for value, optionButton in pairs(optionButtons) do
                    optionButton.Text = (selected[value] and "■  " or "□  ") .. tostring(value)
                end
                if call and callback and not callbackUpdating then
                    callbackUpdating = true
                    task.spawn(function()
                        local ok, err = pcall(callback, selected)
                        callbackUpdating = false
                        if not ok then warn(err) end
                    end)
                end
            end
            for _, option in ipairs(options) do
                local optionButton = make("TextButton", {Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, Text = "□  " .. tostring(option), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, list)
                make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, optionButton)
                optionButtons[option] = optionButton
                optionButton.MouseButton1Click:Connect(function()
                    selected[option] = not selected[option]
                    optionButton.Text = (selected[option] and "■  " or "□  ") .. tostring(option)
                    refresh(true)
                end)
            end
            button.MouseButton1Click:Connect(function()
                open = not open
                frame.Size = UDim2.new(1, 0, 0, open and 48 + math.min(130, #options * 27) or 44)
            end)
            tab.Window:Track(UserInputService.InputBegan:Connect(function(input)
                if open and signal(input) then
                    local position = input.Position
                    local bounds = frame.AbsolutePosition
                    local size = frame.AbsoluteSize
                    if position.X < bounds.X or position.X > bounds.X + size.X or position.Y < bounds.Y or position.Y > bounds.Y + size.Y then
                        open = false
                        frame.Size = UDim2.new(1, 0, 0, 44)
                    end
                end
            end))
            refresh(false)
            local control = {Object = frame, Get = function() return selected end, GetArray = function()
                local values = {}
                for _, option in ipairs(options) do if selected[option] then table.insert(values, option) end end
                return values
            end, Set = function(_, values)
                selected = {}
                if type(values) == "table" then
                    local allowed = {}
                    for _, option in ipairs(options) do allowed[option] = true end
                    for key, item in pairs(values) do
                        local candidate = type(key) == "number" and item or key
                        if allowed[candidate] then selected[candidate] = type(key) == "number" and true or item == true end
                    end
                end
                refresh(true)
            end}
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddKeybind(text, default, callback)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, default, callback = config.Name or "Keybind", config.Default or config.Key, config.Callback or callback
            end
            local bind = default
            if type(bind) == "string" then bind = Enum.KeyCode[bind] end
            if typeof(bind) ~= "EnumItem" or bind.EnumType ~= Enum.KeyCode then bind = Enum.KeyCode.Unknown end
            local reservedKeys = {
                [Enum.KeyCode.Unknown] = true,
                [Enum.KeyCode.LeftShift] = true,
                [Enum.KeyCode.RightShift] = true,
                [Enum.KeyCode.LeftControl] = true,
                [Enum.KeyCode.RightControl] = true,
                [Enum.KeyCode.LeftAlt] = true,
                [Enum.KeyCode.RightAlt] = true,
                [Enum.KeyCode.LeftSuper] = true,
                [Enum.KeyCode.RightSuper] = true,
            }
            local listening = false
            local function cancelListening()
                listening = false
                if keyButton and keyButton.Parent then keyButton.Text = bind.Name end
            end
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0), BackgroundTransparency = 1, Text = tostring(text or "Keybind"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, frame)
            local keyButton = make("TextButton", {Position = UDim2.new(1, -74, 0.5, -12), Size = UDim2.fromOffset(62, 24), BackgroundColor3 = theme.Background, Text = bind.Name, TextColor3 = theme.Accent2, Font = Enum.Font.Code, TextSize = 10, AutoButtonColor = false}, frame)
            corner(keyButton, 6)
            keyButton.MouseButton1Click:Connect(function() listening = true keyButton.Text = "Press key" end)
            tab.Window:Track(UserInputService.InputBegan:Connect(function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        listening = false
                        keyButton.Text = bind.Name
                        return
                    end
                    if reservedKeys[input.KeyCode] then return end
                    if Vortex.Keybinds[input.KeyCode] and Vortex.Keybinds[input.KeyCode].Object.Parent then
                        warn(("Duplicate keybind: %s"):format(input.KeyCode.Name))
                    end
                    Vortex.Keybinds[bind] = nil
                    bind, listening = input.KeyCode, false
                    Vortex.Keybinds[bind] = control
                    keyButton.Text = bind.Name
                elseif not processed and bind ~= Enum.KeyCode.Unknown and input.KeyCode == bind and Vortex.Keybinds[bind] == control and callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, bind)
                        if not ok then warn(err) end
                    end)
                end
            end))
            frame.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    cancelListening()
                    if Vortex.Keybinds[bind] then Vortex.Keybinds[bind] = nil end
                end
            end)
            local control = {Object = frame, Get = function() return bind end, Set = function(_, value)
                if type(value) == "string" then value = Enum.KeyCode[value] end
                if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
                    if value ~= Enum.KeyCode.Unknown and Vortex.Keybinds[value] and Vortex.Keybinds[value] ~= control and Vortex.Keybinds[value].Object.Parent then
                        warn(("Duplicate keybind: %s"):format(value.Name))
                    end
                    Vortex.Keybinds[bind] = nil
                    bind = value
                    if bind ~= Enum.KeyCode.Unknown then Vortex.Keybinds[bind] = control end
                end
                cancelListening()
                keyButton.Text = bind.Name
            end}
            if bind ~= Enum.KeyCode.Unknown then
                if Vortex.Keybinds[bind] and Vortex.Keybinds[bind].Object.Parent then warn(("Duplicate keybind: %s"):format(bind.Name)) end
                Vortex.Keybinds[bind] = control
            end
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddParagraph(titleText, bodyText)
            local bodyValue = tostring(bodyText or "")
            local bodyHeight = 30
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 32 + bodyHeight), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 17), BackgroundTransparency = 1, Text = tostring(titleText or "Information"), TextColor3 = theme.Text, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local body = make("TextLabel", {Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, bodyHeight), BackgroundTransparency = 1, Text = bodyValue, TextColor3 = theme.Muted, Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, frame)
            local resizing = false
            local function resizeParagraph(value)
                if resizing then return end
                resizing = true
                local availableWidth = math.max(80, frame.AbsoluteSize.X - 24)
                local nextHeight = math.max(30, TextService:GetTextSize(value, 10, Enum.Font.Gotham, Vector2.new(availableWidth, 1000)).Y)
                body.Text = value
                body.Size = UDim2.new(1, -24, 0, nextHeight)
                frame.Size = UDim2.new(1, 0, 0, 32 + nextHeight)
                resizing = false
            end
            frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                if body.Parent then resizeParagraph(body.Text) end
            end)
            task.defer(function() if body.Parent then resizeParagraph(bodyValue) end end)
            return {Object = frame, Set = function(_, value) resizeParagraph(tostring(value or "")) end}
        end

        function tab:AddDivider()
            return make("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = theme.Border, BorderSizePixel = 0}, page)
        end

        function tab:AddProgress(text, default, callback)
            local value = math.clamp(default or 0, 0, 100)
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            local label = make("TextLabel", {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -70, 0, 15), BackgroundTransparency = 1, Text = tostring(text or "Progress"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local valueLabel = make("TextLabel", {Position = UDim2.new(1, -58, 0, 6), Size = UDim2.fromOffset(46, 15), BackgroundTransparency = 1, TextColor3 = theme.Accent2, Text = tostring(value) .. "%", Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right}, frame)
            local track = make("Frame", {Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 7), BackgroundColor3 = theme.Surface2}, frame)
            corner(track, 4)
            local fill = make("Frame", {Size = UDim2.fromScale(value / 100, 1), BackgroundColor3 = theme.Accent}, track)
            corner(fill, 4)
            local control = {}
            function control:Set(newValue)
                if type(newValue) ~= "number" then return false end
                local numericValue = newValue
                value = math.clamp(numericValue, 0, 100)
                valueLabel.Text = tostring(value) .. "%"
                tween(fill, 0.25, {Size = UDim2.fromScale(value / 100, 1)})
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, value)
                        if not ok then warn(err) end
                    end)
                end
                return true
            end
            function control:Get() return value end
            control.Object = frame
            return control
        end

        function tab:AddStatus(text, state)
            local active = state == true
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            local dot = make("Frame", {Position = UDim2.new(0, 12, 0.5, -5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = active and Color3.fromRGB(70, 220, 140) or theme.Muted}, frame)
            corner(dot, 5)
            local label = make("TextLabel", {Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = tostring(text or "Status"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local control = {Object = frame}
            function control:Set(newState)
                active = newState == true
                tween(dot, 0.18, {BackgroundColor3 = active and Color3.fromRGB(70, 220, 140) or theme.Muted})
            end
            function control:SetText(newText) label.Text = tostring(newText or "") end
            return control
        end

        function tab:AddSearchbox(placeholder)
            local box = make("TextBox", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme.Surface, Text = "", PlaceholderText = placeholder or "Search...", PlaceholderColor3 = theme.Muted, TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false}, page)
            corner(box, 8)
            stroke(box, theme.Border, 0.35, 1)
            make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, box)
            local search = {Object = box}
            function search:Get() return box.Text end
            function search:Clear() box.Text = "" end
            return search
        end

        function tab:AddTooltip(target, text)
            return self.Window:Tooltip(target, text)
        end

        function tab:AddColorPicker(text, default, callback)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, default, callback = config.Name or "Color", config.Default or config.Color, config.Callback or callback
            end
            local color = typeof(default) == "Color3" and default or theme.Accent
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0), BackgroundTransparency = 1, Text = tostring(text or "Color"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local swatch = make("TextButton", {Position = UDim2.new(1, -54, 0.5, -11), Size = UDim2.fromOffset(42, 22), BackgroundColor3 = color, Text = "", AutoButtonColor = false}, frame)
            corner(swatch, 6)
            local palette = {Color3.fromRGB(75, 140, 255), Color3.fromRGB(0, 218, 255), Color3.fromRGB(157, 104, 255), Color3.fromRGB(70, 220, 140), Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 90, 112)}
            local index = 1
            for position, item in ipairs(palette) do if item == color then index = position end end
            swatch.MouseButton1Click:Connect(function()
                index = index % #palette + 1
                color = palette[index]
                tween(swatch, 0.18, {BackgroundColor3 = color})
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, color)
                        if not ok then warn(err) end
                    end)
                end
            end)
            local control = {Object = frame, Get = function() return color end, Set = function(_, value)
                if typeof(value) ~= "Color3" then return false end
                color = value
                for position, paletteColor in ipairs(palette) do
                    if paletteColor == color then index = position break end
                end
                swatch.BackgroundColor3 = color
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, color)
                        if not ok then warn(err) end
                    end)
                end
                return true
            end}
            if flagName then registerFlag(flagName, control) end
            return control
        end

        function tab:AddCheckbox(text, default, callback)
            return tab:AddToggle(text, default, callback)
        end

        function tab:AddRadio(text, options, default, callback)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, options, default, callback = config.Name or "Radio", config.Options or {}, config.Default, config.Callback or callback
            end
            options = options or {}
            local selected = default or options[1]
            local group = {Items = {}, Get = function() return selected end}
            local function refresh()
                for _, entry in ipairs(group.Items) do
                    local active = entry.Value == selected
                    entry.Object.Text = (active and "●  " or "○  ") .. tostring(entry.Value)
                    entry.Object.TextColor3 = active and theme.Accent2 or theme.Text
                end
            end
            for _, option in ipairs(options) do
                local item = make("TextButton", {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = theme.Surface, Text = "○  " .. tostring(option), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false}, page)
                corner(item, 7)
                make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, item)
                table.insert(group.Items, {Value = option, Object = item})
                item.MouseButton1Click:Connect(function()
                    selected = option
                    refresh()
                    if callback then
                        task.spawn(function()
                            local ok, err = pcall(callback, selected)
                            if not ok then warn(err) end
                        end)
                    end
                end)
            end
            function group:Set(value)
                for _, entry in ipairs(group.Items) do
                    if entry.Value == value then
                        selected = value
                        refresh()
                        if callback then
                            task.spawn(function()
                                local ok, err = pcall(callback, selected)
                                if not ok then warn(err) end
                            end)
                        end
                        return true
                    end
                end
                return false
            end
            refresh()
            if flagName then registerFlag(flagName, group) end
            return group
        end

        function tab:AddList(text, items, callback)
            items = items or {}
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme.Surface, ClipsDescendants = true}, page)
            corner(frame, 8)
            local header = make("TextButton", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = tostring(text or "List") .. "  ▼", TextColor3 = theme.Text, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, frame)
            make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, header)
            local body = make("ScrollingFrame", {Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 0, math.min(130, #items * 27)), BackgroundColor3 = theme.Background, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(0, 0, 0, #items * 27)}, frame)
            corner(body, 6)
            make("UIListLayout", {Padding = UDim.new(0, 2)}, body)
            for _, value in ipairs(items) do
                local item = make("TextButton", {Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, Text = tostring(value), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false}, body)
                make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, item)
                item.MouseButton1Click:Connect(function()
                    if callback then
                        task.spawn(function()
                            local ok, err = pcall(callback, value)
                            if not ok then warn(err) end
                        end)
                    end
                end)
            end
            local open = false
            header.MouseButton1Click:Connect(function()
                open = not open
                header.Text = tostring(text or "List") .. (open and "  ▲" or "  ▼")
                frame.Size = UDim2.new(1, 0, 0, open and 44 + math.min(130, #items * 27) or 34)
            end)
            local control = {Object = frame}
            function control:Refresh(newItems)
                newItems = newItems or {}
                items = newItems
                for _, child in ipairs(body:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for _, value in ipairs(newItems) do
                    local item = make("TextButton", {Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, Text = tostring(value), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false}, body)
                    make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, item)
                    item.MouseButton1Click:Connect(function()
                        if callback then
                            task.spawn(function()
                                local ok, err = pcall(callback, value)
                                if not ok then warn(err) end
                            end)
                        end
                    end)
                end
                body.CanvasSize = UDim2.fromOffset(0, #newItems * 27)
                if open then frame.Size = UDim2.new(1, 0, 0, 44 + math.min(130, #newItems * 27)) end
                header.Text = tostring(text or "List") .. (open and "  ▲" or "  ▼")
            end
            return control
        end

        function tab:AddSpacer(height)
            return make("Frame", {Size = UDim2.new(1, 0, 0, height or 8), BackgroundTransparency = 1}, page)
        end

        tab.CreateButton = tab.AddButton
        tab.CreateOnceButton = tab.AddOnceButton
        tab.AddOneTimeButton = tab.AddOnceButton
        tab.CreateToggle = tab.AddToggle
        tab.CreateSlider = tab.AddSlider
        tab.CreateDropdown = tab.AddDropdown
        tab.CreateTextbox = tab.AddTextbox
        tab.CreateTextBox = tab.AddTextbox
        tab.AddTextBox = tab.AddTextbox
        tab.AddInput = tab.AddTextbox
        tab.AddProgressBar = tab.AddProgress
        tab.AddColor = tab.AddColorPicker
        tab.AddSearch = tab.AddSearchbox
        tab.AddCheck = tab.AddCheckbox
        tab.AddRadioButton = tab.AddRadio
        tab.AddListBox = tab.AddList
        tab.NewSection = tab.AddSection
        tab.Section = tab.AddSection

        return tab
    end

    function window:CreateTab(name)
        return self:AddTab({Name = name})
    end

    function window:CreateSearchTab(name, placeholder)
        local tab = self:AddTab({Name = name or "Search"})
        local search = tab:AddSearchbox(placeholder or "Search this tab...")
        local contentLayout = tab.Page:FindFirstChildOfClass("UIListLayout")
        local searchRevision = 0
        local function searchableText(object)
            local parts = {object.Name}
            for _, descendant in ipairs(object:GetDescendants()) do
                if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                    if descendant.Text and descendant.Text ~= "" then table.insert(parts, descendant.Text) end
                    if descendant.PlaceholderText and descendant.PlaceholderText ~= "" then table.insert(parts, descendant.PlaceholderText) end
                end
            end
            return string.lower(table.concat(parts, " "))
        end
        search.Object:GetPropertyChangedSignal("Text"):Connect(function()
            searchRevision += 1
            local revision = searchRevision
            task.delay(0.05, function()
                if revision ~= searchRevision or not tab.Page.Parent then return end
                local query = string.lower(search.Object.Text or "")
                for _, child in ipairs(tab.Page:GetChildren()) do
                    if child:IsA("GuiObject") and child ~= search.Object and child ~= contentLayout then
                        child.Visible = query == "" or string.find(searchableText(child), query, 1, true) ~= nil
                    end
                end
            end)
        end)
        return tab
    end

    window.NewSection = window.AddTab
    window.CreateSection = window.AddTab
    window.CreatePage = window.AddTab
    window.AddPage = window.AddTab
    window.CreateSearchPage = window.CreateSearchTab
    window.SetBackgroundImage = window.SetBackground
    window.SetBackgroundImageTransparency = window.SetBackgroundTransparency

    return window
end

function Vortex:Init(title)
    return self:CreateWindow({Title = title or "Vortex Hub", Subtitle = "Owned by Nexxy"})
end

function Vortex:SendNotification(title, message, duration)
    return self:Notify(title, message, duration)
end

function Vortex:DestroyAll()
    local windows = table.clone(self.Windows)
    for _, window in ipairs(windows) do
        if window and window.Destroy then
            window:Destroy()
        end
    end
    table.clear(self.Windows)
end

function Vortex:GetWindow(index)
    return self.Windows[index or 1]
end

function Vortex:SetScale(scale)
    self.Scale = math.clamp(scale or 1, 0.7, 1.5)
    for _, window in ipairs(self.Windows) do
        if window.Root and window.Root.Parent then
            local scaler = window.Root:FindFirstChild("VortexScale")
            if not scaler then
                scaler = make("UIScale", {Name = "VortexScale"}, window.Root)
            end
            tween(scaler, 0.22, {Scale = self.Scale})
        end
    end
    return self.Scale
end

local function safeConfigName(name)
    if name == nil then return "VortexConfig" end
    if type(name) ~= "string" or name == "" or name:find("%.%.", 1, true) or name:find("[/\\]", 1) then
        return nil
    end
    return name:gsub("%.json$", "")
end

function Vortex:SaveConfig(name, data)
    if type(writefile) ~= "function" then return false, "writefile is unavailable" end
    local configName = safeConfigName(name)
    if not configName then return false, "invalid config name" end
    local ok, encoded = pcall(function() return game:GetService("HttpService"):JSONEncode(data or {}) end)
    if not ok then return false, encoded end
    local success, err = pcall(writefile, configName .. ".json", encoded)
    return success, err
end

function Vortex:LoadConfig(name)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil, "readfile is unavailable" end
    local configName = safeConfigName(name)
    if not configName then return nil, "invalid config name" end
    local path = configName .. ".json"
    if not isfile(path) then return nil, "config does not exist" end
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(path)) end)
    if not ok then return nil, data end
    return data
end

Vortex.Create = Vortex.CreateWindow
Vortex.NewWindow = Vortex.CreateWindow

return Vortex
