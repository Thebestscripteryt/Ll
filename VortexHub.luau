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
    Font = Enum.Font.Arcade,
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local activeTweens = setmetatable({}, {__mode = "k"})
local onceButtonStates = setmetatable({}, {__mode = "k"})
local instanceConnections = setmetatable({}, {__mode = "k"})

local themeRoleForColor

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
    local role = themeRoleForColor and themeRoleForColor(icon.ImageColor3)
    if role then icon:SetAttribute("ImageThemeRole", role) end
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
        Accent3 = Color3.fromRGB(124, 58, 237),
        Text = Color3.fromRGB(247, 246, 255),
        Muted = Color3.fromRGB(158, 157, 180),
        Danger = Color3.fromRGB(255, 90, 112),
        Glow = Color3.fromRGB(157, 104, 255),
    },
}

Vortex.Theme = Vortex.Themes.Vortex

themeRoleForColor = function(color)
    if typeof(color) ~= "Color3" then return nil end
    local theme = Vortex.Theme
    local order = {
        "Background", "Surface", "Surface2", "Border",
        "Accent", "Accent2", "Accent3",
        "Text", "Muted", "Danger", "Glow",
    }
    for _, role in ipairs(order) do
        local value = theme[role]
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
        local parent = button.Parent
        local underListLayout = parent and parent:FindFirstChildOfClass("UIListLayout") ~= nil
        if underListLayout then
            local slot = make("Frame", {
                Name = button.Name .. "Slot",
                Size = button.Size,
                LayoutOrder = button.LayoutOrder,
                BackgroundTransparency = 1,
                ClipsDescendants = false,
            }, parent)
            button.Size = UDim2.new(1, 0, 1, 0)
            button.Position = UDim2.new(0.5, 0, 0.5, 0)
            button.AnchorPoint = Vector2.new(0.5, 0.5)
            button.Parent = slot
            instanceConnections[slot] = button:GetPropertyChangedSignal("LayoutOrder"):Connect(function()
                slot.LayoutOrder = button.LayoutOrder
            end)
        else
            local size = button.AbsoluteSize
            if size.X <= 0 or size.Y <= 0 then
                local parentSize = button.Parent and button.Parent.AbsoluteSize or Vector2.new(0, 0)
                size = Vector2.new(
                    button.Size.X.Offset + button.Size.X.Scale * parentSize.X,
                    button.Size.Y.Offset + button.Size.Y.Scale * parentSize.Y
                )
            end
            local position = button.Position
            button.AnchorPoint = Vector2.new(0.5, 0.5)
            button.Position = UDim2.new(
                position.X.Scale,
                position.X.Offset + size.X / 2,
                position.Y.Scale,
                position.Y.Offset + size.Y / 2
            )
        end
        scale = make("UIScale", {Name = "VortexButtonScale", Scale = 1}, button)
    end
    local normalRole = themeRoleForColor(normalColor)
    local hoverRole = themeRoleForColor(hoverColor)
    local function currentNormalColor()
        return (normalRole and Vortex.Theme[normalRole]) or normalColor
    end
    local function currentHoverColor()
        return (hoverRole and Vortex.Theme[hoverRole]) or hoverColor or currentNormalColor()
    end
    button.MouseEnter:Connect(function()
        tween(button, 0.16, {BackgroundColor3 = currentHoverColor()})
        tween(scale, 0.16, {Scale = 1.025}, Enum.EasingStyle.Back)
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.2, {BackgroundColor3 = currentNormalColor()})
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
        selected = {}
        for key, value in pairs(self.Themes.Vortex) do selected[key] = value end
        for key, value in pairs(theme) do selected[key] = value end
    elseif type(theme) == "string" then
        local found = self.Themes[theme] or self.Themes[theme:lower()]
        if not found then
            for name, candidate in pairs(self.Themes) do
                if type(name) == "string" and name:lower() == theme:lower() then
                    found = candidate
                    break
                end
            end
        end
        if found then
            selected = {}
            for key, value in pairs(found) do selected[key] = value end
        end
    end
    if not selected then
        warn(("Unknown theme: %s"):format(tostring(theme)))
        return nil
    end
    self.Theme = selected
    self.ThemeName = typeof(theme) == "string" and theme or self.ThemeName
    Vortex.Theme = selected
    local function applyThemeToTree(root)
        for _, object in ipairs(root:GetDescendants()) do
            pcall(function()
                if object:IsA("GuiObject") then
                    local role = object:GetAttribute("ThemeRole")
                    local replacement = role and selected[role]
                    if replacement then object.BackgroundColor3 = replacement end
                    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                        local textRole = object:GetAttribute("TextThemeRole")
                        replacement = textRole and selected[textRole]
                        if replacement then object.TextColor3 = replacement end
                    elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                        local imageRole = object:GetAttribute("ImageThemeRole")
                        replacement = imageRole and selected[imageRole]
                        if replacement then object.ImageColor3 = replacement end
                    end
                elseif object:IsA("UIStroke") then
                    local role = object:GetAttribute("ThemeRole")
                    local replacement = role and selected[role]
                    if replacement then object.Color = replacement end
                elseif object:IsA("UIGradient") then
                    if object.Name == "VortexRainbowGradient" or object.Name == "VortexFadeGradient" then
                    elseif object.Name == "VortexStrokeGradient" then
                        object.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, selected.Accent),
                            ColorSequenceKeypoint.new(0.5, selected.Accent2),
                            ColorSequenceKeypoint.new(1, selected.Accent3 or selected.Accent),
                        })
                    elseif object.Parent and object.Parent:IsA("UIStroke") then
                        object.Color = ColorSequence.new(selected.Accent, selected.Accent2 or selected.Accent)
                    elseif object.Name == "VortexAccentGradient" then
                        object.Color = ColorSequence.new(selected.Accent, selected.Accent2 or selected.Accent)
                    elseif object.Name == "VortexBackgroundGradient" then
                        object.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, selected.Background),
                            ColorSequenceKeypoint.new(0.55, selected.Surface),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 18)),
                        })
                    else
                        object.Color = ColorSequence.new(selected.Background, selected.Surface)
                    end
                end
            end)
        end
    end
    for _, window in ipairs(self.Windows) do
        if window.Gui and window.Gui.Parent then
            applyThemeToTree(window.Gui)
        end
    end
    if self._NotificationGui and self._NotificationGui.Parent then
        applyThemeToTree(self._NotificationGui)
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
    local dead
    for object in pairs(self.TextObjects) do
        if object and object.Parent then
            pcall(function() object.Font = font end)
        else
            dead = dead or {}
            dead[#dead + 1] = object
        end
    end
    if dead then
        for _, object in ipairs(dead) do self.TextObjects[object] = nil end
    end
    return font
end

function Vortex:IsRunning()
    local hasNotifications = self._NotificationGui ~= nil and self._NotificationGui.Parent ~= nil
    return #self.Windows > 0 or hasNotifications
end

function Vortex:GetFlag(name)
    local control = self.Flags[name]
    if not control or not control.Get then return nil end
    local ok, result = pcall(control.Get, control)
    return ok and result or nil
end

function Vortex:SetFlag(name, value)
    local control = self.Flags[name]
    if not control or not control.Set then return false, false end
    local ok, result = pcall(control.Set, control, value)
    if not ok then
        warn(("Flag '%s' Set failed: %s"):format(tostring(name), tostring(result)))
        return true, false
    end
    return true, result ~= false
end

local function registerFlag(name, control, owner)
    if not name then return end
    if Vortex.Flags[name] and Vortex.Flags[name] ~= control then
        warn(("Duplicate flag '%s'; replacing previous control"):format(tostring(name)))
    end
    Vortex.Flags[name] = control
    if owner then
        owner.FlagOwners = owner.FlagOwners or {}
        owner.FlagOwners[name] = control
    end
end

local function unregisterOwnerFlags(owner)
    if not owner or not owner.FlagOwners then return end
    for name, control in pairs(owner.FlagOwners) do
        if Vortex.Flags[name] == control then
            Vortex.Flags[name] = nil
        end
    end
    owner.FlagOwners = {}
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
            local found, accepted = self:SetFlag(flagName, decoded)
            if not found then
                unknownFlags += 1
                warn(("Unknown flag in config: %s"):format(tostring(flagName)))
            elseif not accepted then
                warn(("Flag '%s' rejected the value from config"):format(tostring(flagName)))
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
            DisplayOrder = 100,
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
    table.sort(notificationFrames, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    local offscreenOffset = (self._NotificationList.AbsoluteSize.X or 300) + 30
    while #notificationFrames >= math.max(1, self.NotificationLimit or 5) do
        local oldest = table.remove(notificationFrames, 1)
        if oldest and oldest.Parent then
            local oldestCard = oldest:FindFirstChildWhichIsA("Frame")
            if oldestCard then
                tween(oldestCard, 0.18, {Position = UDim2.new(1, offscreenOffset, 0, 0)})
                task.delay(0.2, function()
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
    self._NotificationCounter = (self._NotificationCounter or 0) + 1
    local holder = make("Frame", {
        Size = UDim2.new(1, 0, 0, notificationHeight),
        BackgroundTransparency = 1,
        LayoutOrder = self._NotificationCounter,
    }, self._NotificationList)
    local card = make("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, offscreenOffset, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
    }, holder)
    corner(card, 9)
    stroke(card, theme.Accent, 0.35, 1)
    local bar = make("Frame", {
        Position = UDim2.new(0, 0, 0, 9),
        Size = UDim2.new(0, 3, 1, -18),
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
        tween(card, 0.2, {Position = UDim2.new(1, offscreenOffset, 0, 0)})
        task.delay(0.22, function()
            if holder.Parent then holder:Destroy() end
        end)
    end)
    return holder
end

function Vortex:CreateWindow(options)
    options = options or {}
    local theme = setmetatable({}, {__index = function(_, key) return Vortex.Theme[key] end})
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
    local panelTransparency = math.clamp(options.PanelTransparency or options.BackgroundColorTransparency or 0, 0, 1)
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    local isTouch = UserInputService.TouchEnabled
    local device = isTouch and (viewport.X < 600 and "Phone" or "Tablet") or "Desktop"
    local baseWidth, baseHeight = width, height
    local function responsiveSize(view)
        if not autoSize then return width, height end
        local marginX = device == "Phone" and 16 or 28
        local marginY = device == "Phone" and 28 or 40
        local maxWidth = math.max(260, view.X - marginX)
        local maxHeight = math.max(190, view.Y - marginY)
        local targetWidth = math.min(baseWidth, maxWidth)
        local targetHeight = math.min(baseHeight, maxHeight)
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
        for _, tab in ipairs(oldWindow.Tabs or {}) do
            for _, connection in ipairs(tab._connections or {}) do
                if connection and connection.Connected then connection:Disconnect() end
            end
            tab._connections = {}
        end
        if oldWindow.Gui then oldWindow.Gui:Destroy() end
    end
    table.clear(self.Windows)
    table.clear(self.Flags)
    table.clear(self.Keybinds)
    local old = getPlayerGui():FindFirstChild("VortexHub")
    if old then old:Destroy() end

    local gui = make("ScreenGui", {
        Name = "VortexHub",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.None,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, getPlayerGui())
    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, -height / 2),
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
        Name = "VortexBackgroundGradient",
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
        Name = "VortexStrokeGradient",
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.Accent),
            ColorSequenceKeypoint.new(0.5, theme.Accent2),
            ColorSequenceKeypoint.new(1, theme.Accent3 or theme.Accent),
        }),
        Rotation = 20,
    }, outline)
    local scanClip = make("CanvasGroup", {
        Name = "VortexScanClip",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 1,
    }, root)
    corner(scanClip, 14)
    local scanline = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(-0.28, 0, 1.18, 0),
        Size = UDim2.new(0.18, 0, 1.7, 0),
        Rotation = -38,
        BackgroundColor3 = theme.Accent2,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, scanClip)
    local scanGradient = make("UIGradient", {
        Name = "VortexAccentGradient",
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
        local scanDuration = 2.8
        while scanline.Parent do
            if not gui.Enabled or not scanline.Visible then task.wait(0.2) continue end
            scanline.Position = UDim2.new(-0.28, 0, 1.18, 0)
            tween(scanline, scanDuration, {Position = UDim2.new(1.28, 0, -0.18, 0)}, Enum.EasingStyle.Sine)
            task.wait(scanDuration + 0.05)
            task.wait(0.55)
        end
    end)
    local gradientConnection
    gradientConnection = RunService.RenderStepped:Connect(function(delta)
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
        Size = UDim2.new(1, -titleOffset - 110, 0, 22),
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

    local tabBarOutline = stroke(tabBar, theme.Border, 0.15, 1)
    corner(tabBar, 8)
    local tabBarOutlineGradient = make("UIGradient", {
        Name = "VortexRainbowGradient",
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }),
    }, tabBarOutline)
    local rainbowConnection
    rainbowConnection = RunService.RenderStepped:Connect(function(delta)
        if not tabBarOutline.Parent then rainbowConnection:Disconnect() return end
        if not gui.Enabled then return end
        tabBarOutlineGradient.Rotation = (tabBarOutlineGradient.Rotation + delta * 60) % 360
    end)

    local tabFadeLeft = make("Frame", {
        Name = "VortexTabFadeLeft",
        Position = UDim2.fromOffset(12, 66),
        Size = UDim2.fromOffset(20, 34),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ZIndex = 3,
        Visible = false,
    }, root)
    make("UIGradient", {
        Name = "VortexFadeGradient",
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, tabFadeLeft)
    local tabFadeRight = make("Frame", {
        Name = "VortexTabFadeRight",
        Position = UDim2.new(1, -32, 0, 66),
        Size = UDim2.fromOffset(20, 34),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ZIndex = 3,
        Visible = false,
    }, root)
    make("UIGradient", {
        Name = "VortexFadeGradient",
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, tabFadeRight)
    local function updateTabFades()
        if not tabBar.Parent then return end
        local viewport = tabBar.AbsoluteSize.X
        local canvas = tabBar.AbsoluteCanvasSize.X
        local overflow = canvas > viewport + 1
        local pos = tabBar.CanvasPosition.X
        tabFadeLeft.Visible = overflow and pos > 2
        tabFadeRight.Visible = overflow and pos < (canvas - viewport - 2)
    end
    local tabFadeConnections = {
        tabBar:GetPropertyChangedSignal("CanvasPosition"):Connect(updateTabFades),
        tabBar:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateTabFades),
        tabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTabFades),
    }
    updateTabFades()

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
        PanelTransparency = panelTransparency,
        _connections = {gradientConnection, rainbowConnection, tabFadeConnections[1], tabFadeConnections[2], tabFadeConnections[3]},
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
        self._BackgroundGeneration = (self._BackgroundGeneration or 0) + 1
        local generation = self._BackgroundGeneration
        tween(self.Background, 0.14, {ImageTransparency = 1})
        task.delay(0.14, function()
            if not self.Background or not self.Background.Parent then return end
            if self._BackgroundGeneration ~= generation then return end
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
    function window:SetPanelTransparency(value)
        local target = math.clamp(value or 0, 0, 1)
        self.PanelTransparency = target
        if self.IsOpen and self.Root.Visible then
            tween(self.Root, 0.18, {BackgroundTransparency = target})
        end
        return target
    end
    window.SetBackgroundColorTransparency = window.SetPanelTransparency
    window.SetWindowTransparency = window.SetPanelTransparency
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
        self.Root.Position = UDim2.fromOffset(x + size.X / 2, y)
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
    tween(root, 0.38, {Size = window.NormalSize, BackgroundTransparency = panelTransparency}, Enum.EasingStyle.Back)

    local dragging = false
    local dragBlocked = false
    local dragStart, startPosition, dragTarget, startAbsolute
    local dragSmoothing = RunService.RenderStepped:Connect(function()
        if dragging and dragTarget and root.Parent then
            root.Position = root.Position:Lerp(dragTarget, 0.24)
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
            local size = root.AbsoluteSize
            local view = camera and camera.ViewportSize or Vector2.new(800, 600)
            local grabMargin = 48
            local x = math.clamp(startAbsolute.X + delta.X, grabMargin - size.X, view.X - grabMargin)
            local y = math.clamp(startAbsolute.Y + delta.Y, grabMargin - size.Y, view.Y - grabMargin)
            dragTarget = UDim2.fromOffset(x + size.X / 2, y)
        end
    end))
    window:Track(UserInputService.InputEnded:Connect(function(input)
        if signal(input) then dragging = false dragTarget = nil end
    end))

    minimize.InputBegan:Connect(function(input) if signal(input) then dragBlocked = true end end)
    close.InputBegan:Connect(function(input) if signal(input) then dragBlocked = true end end)
    window:Track(UserInputService.InputEnded:Connect(function(input) if signal(input) then dragBlocked = false end end))
    minimize.MouseButton1Click:Connect(function()
        window:Minimize(not window.IsMinimized)
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
                if guiToDestroy.Parent then guiToDestroy:Destroy() end
            end)
            task.delay(1, function()
                if guiToDestroy.Parent then guiToDestroy:Destroy() end
            end)
        end
        for _, tab in ipairs(self.Tabs) do
            unregisterOwnerFlags(tab)
            for _, connection in ipairs(tab._connections or {}) do
                if connection and connection.Connected then connection:Disconnect() end
            end
            tab._connections = {}
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
        tween(self.Root, 0.28, {Size = self.IsMinimized and UDim2.fromOffset(width, 58) or self.NormalSize, BackgroundTransparency = self.PanelTransparency}, Enum.EasingStyle.Back)
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
        baseWidth, baseHeight = width, height
        self.NormalSize = UDim2.fromOffset(width, height)
        if not self.IsMinimized then tween(self.Root, 0.22, {Size = self.NormalSize}) end
        task.defer(function() if self.Root and self.Root.Parent then self:ClampToViewport() end end)
    end

    function window:Center()
        local currentHeight = self.Root.AbsoluteSize.Y
        tween(self.Root, 0.25, {Position = UDim2.new(0.5, 0, 0.5, -currentHeight / 2)})
    end

    function window:Minimize(value)
        if value == nil then value = not self.IsMinimized end
        self.IsMinimized = value == true
        tabBar.Visible = not self.IsMinimized
        content.Visible = not self.IsMinimized
        if self.IsMinimized then
            tabFadeLeft.Visible = false
            tabFadeRight.Visible = false
        else
            updateTabFades()
        end
        minimize.Text = self.IsMinimized and "+" or "—"
        topRepair.Visible = not self.IsMinimized
        tween(self.Root, 0.28, {Size = self.IsMinimized and UDim2.fromOffset(width, 58) or self.NormalSize}, Enum.EasingStyle.Quint)
    end

    function window:SetTitle(value)
        setText(titleLabel, value)
    end

    local tagPill, tagLabel
    function window:SetTag(text, tagColor)
        if not text or text == "" then
            if tagPill then tagPill:Destroy() tagPill, tagLabel = nil, nil end
            return
        end
        if not tagPill then
            tagPill = make("Frame", {
                Name = "VortexTag",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -78, 0, 19),
                Size = UDim2.fromOffset(0, 16),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = tagColor or theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, top)
            corner(tagPill, 5)
            make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, tagPill)
            tagLabel = make("TextLabel", {
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamBold,
                TextSize = 9,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 2,
            }, tagPill)
        else
            tagLabel.Text = text
            tagPill.BackgroundColor3 = tagColor or theme.Accent
        end
    end
    if options.Tag then window:SetTag(options.Tag, options.TagColor) end

    function window:SetToggleKeybind(key)
        if type(key) == "string" then key = Enum.KeyCode[key] end
        if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
            self._toggleKeybind = key
        else
            self._toggleKeybind = nil
        end
        return self._toggleKeybind
    end
    if options.ToggleKeybind then window:SetToggleKeybind(options.ToggleKeybind) end
    window:Track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not window._toggleKeybind then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == window._toggleKeybind then
            window:Toggle()
        end
    end))

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
        local tip = make("TextLabel", {Name = "VortexTooltip", AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = theme.Surface, Text = tostring(text or ""), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, Visible = false, TextTransparency = 1, ZIndex = 100}, gui)
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
                tip.Visible = false
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
            item.Button:SetAttribute("ThemeRole", "Surface2")
            item.Label:SetAttribute("TextThemeRole", "Muted")
            tween(item.Button, 0.12, {BackgroundColor3 = theme.Surface2})
            tween(item.Label, 0.12, {TextColor3 = theme.Muted})
        end
        if tab then
            tab.Page.Visible = true
            tab.Button:SetAttribute("ThemeRole", "Accent")
            tab.Label:SetAttribute("TextThemeRole", "Text")
            tween(tab.Button, 0.16, {BackgroundColor3 = theme.Accent})
            tween(tab.Label, 0.16, {TextColor3 = theme.Text})
            self.CurrentTab = tab
        else
            self.CurrentTab = nil
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
                unregisterOwnerFlags(item)
                for _, connection in ipairs(item._connections or {}) do
                    if connection and connection.Connected then connection:Disconnect() end
                end
                item._connections = {}
                table.remove(self.Tabs, index)
                local replacement
                if self.TabLookup[item.Name] == item or self.TabLookupLower[item.Name:lower()] == item then
                    for _, remaining in ipairs(self.Tabs) do
                        if remaining.Name == item.Name then replacement = remaining break end
                    end
                end
                if self.TabLookup[item.Name] == item then self.TabLookup[item.Name] = replacement end
                if self.TabLookupLower[item.Name:lower()] == item then self.TabLookupLower[item.Name:lower()] = replacement end
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
            PaddingBottom = UDim.new(0, 0),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
        }, page)
        make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        make("Frame", {Name = "VortexBottomSpacer", Size = UDim2.new(1, 0, 0, 10), BackgroundTransparency = 1, LayoutOrder = 9999}, page)
        local tab = {Window = self, Name = tabName, Button = button, Label = tabLabel, Icon = tabIcon, Page = page, Elements = {}, _connections = {}}
        function tab:Track(connection)
            if connection then table.insert(self._connections, connection) end
            return connection
        end
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
            local hasDescription = description ~= nil and description ~= ""
            local frame = make("Frame", {
                Size = UDim2.new(1, 0, 0, hasDescription and 44 or 25),
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
            if hasDescription then
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
            local padding = make("UIPadding", {PaddingLeft = UDim.new(0, 10)}, label)
            local icon = makeIcon(label, Vortex:GetIcon(iconValue) or iconValue, 13, theme.Accent2, "VortexLabelIcon")
            if icon then icon.Position = UDim2.fromOffset(8, 7); label.TextXAlignment = Enum.TextXAlignment.Left; padding.PaddingLeft = UDim.new(0, 28) end
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
            onceButtonStates[buttonFrame] = function(reset, targetButton)
                clicked = reset ~= false
                if not clicked and targetButton then targetButton.TextTransparency = 0 end
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
            if onceButtonStates[button] then onceButtonStates[button](false, button) end
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
                switch:SetAttribute("ThemeRole", value and "Accent" or "Surface2")
                knob:SetAttribute("ThemeRole", value and "Text" or "Muted")
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
                if value == newValue then return true end
                value = newValue
                update(true)
                return true
            end}
            if flagName then registerFlag(flagName, control, tab) end
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
            local fill = make("Frame", {Size = UDim2.fromScale((value - minimum) / math.max(0.000001, maximum - minimum), 1), BackgroundColor3 = theme.Accent}, track)
            corner(fill, 3)
            local draggingSlider = false
            local callbackRunning = false
            local pendingValue, hasPending = nil, false
            local function fireSliderCallback(v)
                if not callback then return end
                if callbackRunning then
                    pendingValue, hasPending = v, true
                    return
                end
                callbackRunning = true
                task.spawn(function()
                    local ok, err = pcall(callback, v)
                    if not ok then warn(err) end
                    callbackRunning = false
                    if hasPending then
                        local nextValue = pendingValue
                        hasPending = false
                        fireSliderCallback(nextValue)
                    end
                end)
            end
            local function setValueFromX(x, call)
                if track.AbsoluteSize.X <= 0 then return end
                if maximum == minimum then
                    value = minimum
                    valueLabel.Text = displayValue(value)
                    fill.Size = UDim2.fromScale(0, 1)
                    return
                end
                local ratio = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local raw = minimum + (maximum - minimum) * ratio
                value = math.floor((raw - minimum) / increment + 0.5) * increment + minimum
                value = math.clamp(value, minimum, maximum)
                valueLabel.Text = displayValue(value)
                local snappedRatio = (value - minimum) / math.max(0.000001, maximum - minimum)
                fill.Size = UDim2.fromScale(snappedRatio, 1)
                if call then fireSliderCallback(value) end
            end
            local function beginSlider(input) if signal(input) then draggingSlider = true setValueFromX(input.Position.X, true) end end
            track.InputBegan:Connect(beginSlider)
            fill.InputBegan:Connect(beginSlider)
            tab:Track(UserInputService.InputChanged:Connect(function(input) if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setValueFromX(input.Position.X, true) end end))
            tab:Track(UserInputService.InputEnded:Connect(function(input) if signal(input) then draggingSlider = false end end))
            frame.AncestryChanged:Connect(function(_, parent)
                if not parent then draggingSlider = false end
            end)
            local control = {Object = frame, Get = function() return value end, Set = function(_, newValue)
                if type(newValue) ~= "number" or newValue ~= newValue then return false end
                value = math.clamp(math.floor((newValue - minimum) / increment + 0.5) * increment + minimum, minimum, maximum)
                valueLabel.Text = displayValue(value)
                local ratio = math.clamp((value - minimum) / math.max(0.000001, maximum - minimum), 0, 1)
                fill.Size = UDim2.fromScale(ratio, 1)
                fireSliderCallback(value)
                return true
            end}
            if flagName then registerFlag(flagName, control, tab) end
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
            local focusLostRunning = false
            local function invokeFocusLostCallback(enterPressed)
                if not callback or focusLostRunning then return end
                focusLostRunning = true
                task.spawn(function()
                    local ok, err = pcall(callback, box.Text, enterPressed)
                    focusLostRunning = false
                    if not ok then warn(err) end
                end)
            end
            box.FocusLost:Connect(function(enterPressed)
                invokeFocusLostCallback(enterPressed)
            end)
            local control = {Object = box, Get = function() return box.Text end, Set = function(_, value, silent)
                box.Text = tostring(value or "")
                if not silent and callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, box.Text, false)
                        if not ok then warn(err) end
                    end)
                end
            end}
            if flagName then registerFlag(flagName, control, tab) end
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
            local function uniqueOptions(values)
                local result, seen = {}, {}
                for _, option in ipairs(values) do
                    local key = typeof(option) .. ":" .. tostring(option)
                    if not seen[key] then
                        seen[key] = true
                        table.insert(result, option)
                    end
                end
                return result
            end
            warnDuplicateOptions(options)
            local selected = default or options[1] or "Select"
            local open = false
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = theme.Surface, ClipsDescendants = true}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            local button = make("TextButton", {Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = theme.Background, Text = tostring(text or "Dropdown") .. ": " .. tostring(selected), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, frame)
            corner(button, 6)
            make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 20)}, button)
            local chevron = make("TextLabel", {
                Name = "VortexDropdownChevron",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = theme.Muted,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
            }, button)
            local uniqueOptionCount = #uniqueOptions(options)
            -- Smaller rows (20px, was 25) with a small inset (UIPadding) around the
            -- list itself, so each row's outline stroke has breathing room instead
            -- of sitting flush against the list's own rounded edge — flush edges
            -- were what made the outline look cut off.
            local rowPitch = 22
            local list = make("ScrollingFrame", {Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, math.min(130, uniqueOptionCount * rowPitch + 8)), BackgroundColor3 = theme.Surface2, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.fromOffset(0, uniqueOptionCount * rowPitch + 8), ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false}, frame)
            corner(list, 6)
            make("UIListLayout", {Padding = UDim.new(0, 2)}, list)
            make("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, list)
            local function closeDropdown()
                open = false
                list.Visible = false
                chevron.Text = "v"
                frame.Size = UDim2.new(1, 0, 0, 44)
            end
            local optionRows = {}
            local function highlightRow(option, row)
                local isSelected = option == selected
                row.BackgroundTransparency = isSelected and 0.85 or 1
                local rowStroke = row:FindFirstChildOfClass("UIStroke")
                if rowStroke then
                    -- Retag alongside the color reassignment (same reasoning as
                    -- SelectTab/AddToggle/AddRadio): otherwise a later SetTheme
                    -- would read the stale "Accent" tag on every row, even the
                    -- unselected ones that are currently showing theme.Border.
                    rowStroke:SetAttribute("ThemeRole", isSelected and "Accent" or "Border")
                    rowStroke.Color = isSelected and Vortex.Theme.Accent or Vortex.Theme.Border
                    rowStroke.Transparency = isSelected and 0 or 0.5
                end
            end
            local function refreshHighlights()
                for option, row in pairs(optionRows) do
                    highlightRow(option, row)
                end
            end
            local function rebuildOptions()
                closeDropdown()
                for _, child in ipairs(list:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                optionRows = {}
                local deduped = uniqueOptions(options)
                uniqueOptionCount = #deduped
                list.Size = UDim2.new(1, -20, 0, math.min(130, uniqueOptionCount * rowPitch + 8))
                list.CanvasSize = UDim2.fromOffset(0, uniqueOptionCount * rowPitch + 8)
                for _, option in ipairs(deduped) do
                    local optionButton = make("TextButton", {Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = theme.Accent, BackgroundTransparency = 1, Text = tostring(option), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false}, list)
                    corner(optionButton, 5)
                    stroke(optionButton, theme.Border, 0.5, 1)
                    make("UIPadding", {PaddingLeft = UDim.new(0, 6)}, optionButton)
                    optionRows[option] = optionButton
                    highlightRow(option, optionButton)
                    optionButton.MouseButton1Click:Connect(function()
                        selected = option
                        button.Text = tostring(text or "Dropdown") .. ": " .. tostring(selected)
                        refreshHighlights()
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
                list.Visible = open
                chevron.Text = open and "^" or "v"
                frame.Size = UDim2.new(1, 0, 0, open and 48 + math.min(130, uniqueOptionCount * rowPitch + 8) or 44)
            end)
            tab:Track(UserInputService.InputBegan:Connect(function(input)
                if open and signal(input) then
                    local position = input.Position
                    local bounds = frame.AbsolutePosition
                    local size = frame.AbsoluteSize
                    if position.X < bounds.X or position.X > bounds.X + size.X or position.Y < bounds.Y or position.Y > bounds.Y + size.Y then
                        closeDropdown()
                    end
                end
            end))
            local control = {Object = frame, Get = function() return selected end, Set = function(_, value)
                if not table.find(options, value) then return false end
                selected = value
                button.Text = tostring(text or "Dropdown") .. ": " .. tostring(selected)
                refreshHighlights()
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, selected)
                        if not ok then warn(err) end
                    end)
                end
                return true
            end}
            function control:Refresh(newOptions)
                options = newOptions or {}
                warnDuplicateOptions(options)
                local previousSelected = selected
                if selected == nil or not table.find(options, selected) then selected = options[1] or "Select" end
                button.Text = tostring(text or "Dropdown") .. ": " .. tostring(selected)
                rebuildOptions()
                if selected ~= previousSelected and callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, selected)
                        if not ok then warn(err) end
                    end)
                end
            end
            if flagName then registerFlag(flagName, control, tab) end
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
            local uniqueOptionsList = {}
            do
                local seen = {}
                for _, option in ipairs(options) do
                    if not seen[option] then
                        seen[option] = true
                        table.insert(uniqueOptionsList, option)
                    end
                end
            end
            local uniqueOptionCount = #uniqueOptionsList
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = theme.Surface, ClipsDescendants = true}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            local button = make("TextButton", {Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 30), BackgroundColor3 = theme.Background, TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, frame)
            corner(button, 6)
            make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 20)}, button)
            local chevron = make("TextLabel", {
                Name = "VortexDropdownChevron",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = theme.Muted,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
            }, button)
            local rowPitch = 22
            local list = make("ScrollingFrame", {Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, math.min(130, uniqueOptionCount * rowPitch + 8)), BackgroundColor3 = theme.Surface2, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.fromOffset(0, uniqueOptionCount * rowPitch + 8), ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false}, frame)
            corner(list, 6)
            make("UIListLayout", {Padding = UDim.new(0, 2)}, list)
            make("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, list)
            local function closeDropdown()
                open = false
                list.Visible = false
                chevron.Text = "v"
                frame.Size = UDim2.new(1, 0, 0, 44)
            end
            local optionButtons = {}
            local callbackUpdating = false
            local function highlightOption(option, optionButton)
                local isSelected = selected[option] == true
                optionButton.BackgroundTransparency = isSelected and 0.85 or 1
                local rowStroke = optionButton:FindFirstChildOfClass("UIStroke")
                if rowStroke then
                    rowStroke:SetAttribute("ThemeRole", isSelected and "Accent" or "Border")
                    rowStroke.Color = isSelected and Vortex.Theme.Accent or Vortex.Theme.Border
                    rowStroke.Transparency = isSelected and 0 or 0.5
                end
            end
            local function refresh(call)
                local names = {}
                for _, value in ipairs(uniqueOptionsList) do if selected[value] then table.insert(names, tostring(value)) end end
                button.Text = tostring(text or "Multi-select") .. ": " .. (#names > 0 and table.concat(names, ", ") or "None")
                for value, optionButton in pairs(optionButtons) do
                    optionButton.Text = (selected[value] and "■  " or "□  ") .. tostring(value)
                    highlightOption(value, optionButton)
                end
                if call and callback and not callbackUpdating then
                    callbackUpdating = true
                    task.spawn(function()
                        local ok, err = pcall(callback, table.clone(selected))
                        callbackUpdating = false
                        if not ok then warn(err) end
                    end)
                end
            end
            for _, option in ipairs(options) do
                if optionButtons[option] then
                    warn(("Duplicate MultiDropdown option: %s"):format(tostring(option)))
                else
                    local optionButton = make("TextButton", {Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = theme.Accent, BackgroundTransparency = 1, Text = "□  " .. tostring(option), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false}, list)
                    corner(optionButton, 5)
                    stroke(optionButton, theme.Border, 0.5, 1)
                    make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, optionButton)
                    optionButtons[option] = optionButton
                    highlightOption(option, optionButton)
                    optionButton.MouseButton1Click:Connect(function()
                        selected[option] = not selected[option]
                        optionButton.Text = (selected[option] and "■  " or "□  ") .. tostring(option)
                        highlightOption(option, optionButton)
                        refresh(true)
                    end)
                end
            end
            button.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = open
                chevron.Text = open and "^" or "v"
                frame.Size = UDim2.new(1, 0, 0, open and 48 + math.min(130, uniqueOptionCount * rowPitch + 8) or 44)
            end)
            tab:Track(UserInputService.InputBegan:Connect(function(input)
                if open and signal(input) then
                    local position = input.Position
                    local bounds = frame.AbsolutePosition
                    local size = frame.AbsoluteSize
                    if position.X < bounds.X or position.X > bounds.X + size.X or position.Y < bounds.Y or position.Y > bounds.Y + size.Y then
                        closeDropdown()
                    end
                end
            end))
            refresh(false)
            local control = {Object = frame, Get = function()
                return table.clone(selected)
            end, GetArray = function()
                local values = {}
                for _, option in ipairs(uniqueOptionsList) do if selected[option] then table.insert(values, option) end end
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
            if flagName then registerFlag(flagName, control, tab) end
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
            local control
            tab:Track(UserInputService.InputBegan:Connect(function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        listening = false
                        keyButton.Text = bind.Name
                        return
                    end
                    if reservedKeys[input.KeyCode] then return end
                    if Vortex.Keybinds[input.KeyCode] and Vortex.Keybinds[input.KeyCode] ~= control and Vortex.Keybinds[input.KeyCode].Object.Parent then
                        warn(("Duplicate keybind: %s"):format(input.KeyCode.Name))
                    end
                    if Vortex.Keybinds[bind] == control then Vortex.Keybinds[bind] = nil end
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
                    if Vortex.Keybinds[bind] == control then Vortex.Keybinds[bind] = nil end
                end
            end)
            control = {Object = frame, Get = function() return bind end, Set = function(_, value)
                if type(value) == "string" then value = Enum.KeyCode[value] end
                if typeof(value) ~= "EnumItem" or value.EnumType ~= Enum.KeyCode then
                    return false
                end
                if value ~= Enum.KeyCode.Unknown and Vortex.Keybinds[value] and Vortex.Keybinds[value] ~= control and Vortex.Keybinds[value].Object.Parent then
                    warn(("Duplicate keybind: %s"):format(value.Name))
                end
                if Vortex.Keybinds[bind] == control then Vortex.Keybinds[bind] = nil end
                bind = value
                if bind ~= Enum.KeyCode.Unknown then Vortex.Keybinds[bind] = control end
                cancelListening()
                keyButton.Text = bind.Name
                return true
            end}
            if bind ~= Enum.KeyCode.Unknown then
                if Vortex.Keybinds[bind] and Vortex.Keybinds[bind].Object.Parent then warn(("Duplicate keybind: %s"):format(bind.Name)) end
                Vortex.Keybinds[bind] = control
            end
            if flagName then registerFlag(flagName, control, tab) end
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
                if frame.AbsoluteSize.X <= 0 then
                    body.Text = value
                    return
                end
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
                if type(newValue) ~= "number" or newValue ~= newValue then return false end
                value = math.clamp(newValue, 0, 100)
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

        function tab:AddStat(name, value)
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, Text = tostring(name or "Stat"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local valueLabel = make("TextLabel", {Position = UDim2.new(1, -92, 0, 0), Size = UDim2.fromOffset(80, 40), BackgroundTransparency = 1, Text = tostring(value or 0), TextColor3 = theme.Accent, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right}, frame)
            local stat = {Object = frame, Value = value or 0}
            function stat:Set(newValue)
                self.Value = newValue
                valueLabel.Text = tostring(newValue)
                valueLabel.TextColor3 = theme.Accent2
                tween(valueLabel, 0.3, {TextColor3 = theme.Accent})
            end
            function stat:Get()
                return self.Value
            end
            return stat
        end

        function tab:AddConsole(config)
            config = config or {}
            local logHeight = config.Height or 120
            local maxLines = config.MaxLines or 200
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, logHeight + 34), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 10)
            stroke(frame, theme.Border, 0.35, 1)
            make("TextLabel", {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Text = config.Name or "Console", TextColor3 = theme.Text, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local scroller = make("ScrollingFrame", {
                Position = UDim2.fromOffset(12, 30),
                Size = UDim2.new(1, -24, 0, logHeight),
                BackgroundColor3 = theme.Background,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
            }, frame)
            corner(scroller, 8)
            make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, scroller)
            make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, scroller)
            local pinnedToBottom = true
            scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
                if pinnedToBottom then
                    scroller.CanvasPosition = Vector2.new(0, math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteSize.Y))
                end
            end)
            scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                local maxScroll = math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteSize.Y)
                pinnedToBottom = scroller.CanvasPosition.Y >= maxScroll - 4
            end)
            local lines = {}
            local console = {Object = frame}
            function console:Log(text, color)
                local lineLabel = make("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = tostring(text),
                    TextColor3 = color or theme.Text,
                    Font = Enum.Font.Code,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                }, scroller)
                table.insert(lines, lineLabel)
                if #lines > maxLines then
                    local old = table.remove(lines, 1)
                    old:Destroy()
                end
            end
            function console:Clear()
                for _, lineLabel in ipairs(lines) do lineLabel:Destroy() end
                table.clear(lines)
            end
            return console
        end

        function tab:AddStatus(text, state)
            local flagName
            if type(text) == "table" then
                local config = text
                flagName = config.Flag
                text, state = config.Name or config.Text or "Status", config.Default or config.State or state
            end
            local active = state == true
            local frame = make("Frame", {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = theme.Surface}, page)
            corner(frame, 8)
            stroke(frame, theme.Border, 0.35, 1)
            local dot = make("Frame", {Position = UDim2.new(0, 12, 0.5, -5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = active and Color3.fromRGB(70, 220, 140) or theme.Muted}, frame)
            corner(dot, 5)
            local label = make("TextLabel", {Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = tostring(text or "Status"), TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
            local control = {Object = frame, Get = function() return active end}
            function control:Set(newState)
                active = newState == true
                if active then
                    dot:SetAttribute("ThemeRole", nil)
                else
                    dot:SetAttribute("ThemeRole", "Muted")
                end
                tween(dot, 0.18, {BackgroundColor3 = active and Color3.fromRGB(70, 220, 140) or theme.Muted})
                return true
            end
            function control:SetText(newText) label.Text = tostring(newText or "") end
            if flagName then registerFlag(flagName, control, tab) end
            return control
        end

        function tab:AddSearchbox(placeholder)
            local flagName
            local defaultValue = ""
            if type(placeholder) == "table" then
                local config = placeholder
                flagName = config.Flag
                defaultValue = config.Default or ""
                placeholder = config.Placeholder or config.Name
            end
            local box = make("TextBox", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme.Surface, Text = defaultValue, PlaceholderText = placeholder or "Search...", PlaceholderColor3 = theme.Muted, TextColor3 = theme.Text, Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false}, page)
            corner(box, 8)
            stroke(box, theme.Border, 0.35, 1)
            make("UIPadding", {PaddingLeft = UDim.new(0, 12)}, box)
            local search = {Object = box}
            function search:Get() return box.Text end
            function search:Clear() box.Text = "" end
            function search:Set(value)
                box.Text = tostring(value or "")
                return true
            end
            if flagName then registerFlag(flagName, search, tab) end
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
                local found = false
                for position, paletteColor in ipairs(palette) do
                    if paletteColor == color then index = position found = true break end
                end
                if not found then index = 0 end
                swatch.BackgroundColor3 = color
                if callback then
                    task.spawn(function()
                        local ok, err = pcall(callback, color)
                        if not ok then warn(err) end
                    end)
                end
                return true
            end}
            if flagName then registerFlag(flagName, control, tab) end
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
            local group = {Items = {}}
            function group:Get() return selected end
            local function retint(object, role)
                object:SetAttribute("TextThemeRole", role)
                object.TextColor3 = Vortex.Theme[role]
            end
            local function refresh()
                for _, entry in ipairs(group.Items) do
                    local active = entry.Value == selected
                    entry.Object.Text = (active and "●  " or "○  ") .. tostring(entry.Value)
                    retint(entry.Object, active and "Accent2" or "Text")
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
            group.Object = group.Items[1] and group.Items[1].Object
            if flagName then registerFlag(flagName, group, tab) end
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
                body.Size = UDim2.new(1, -16, 0, math.min(130, #newItems * 27))
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
                end
                if descendant:IsA("TextBox") and descendant.PlaceholderText and descendant.PlaceholderText ~= "" then
                    table.insert(parts, descendant.PlaceholderText)
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
    if self._NotificationGui then
        self._NotificationGui:Destroy()
        self._NotificationGui = nil
        self._NotificationList = nil
    end
end

function Vortex:GetWindow(index)
    return self.Windows[index or 1]
end

function Vortex:SetScale(scale)
    self.Scale = math.clamp(scale or 1, 0.7, 1.5)
    for _, window in ipairs(self.Windows) do
        if window.Root and window.Root.Parent then
            local scaler = window.Root:FindFirstChild("VortexScale")
            window._ScaleGeneration = (window._ScaleGeneration or 0) + 1
            local generation = window._ScaleGeneration
            if self.Scale == 1 then
                if scaler then
                    tween(scaler, 0.22, {Scale = 1})
                    task.delay(0.24, function()
                        if window._ScaleGeneration ~= generation then return end
                        if scaler and scaler.Parent then scaler:Destroy() end
                    end)
                end
            else
                if not scaler then
                    scaler = make("UIScale", {Name = "VortexScale"}, window.Root)
                end
                tween(scaler, 0.22, {Scale = self.Scale})
            end
        end
    end
    return self.Scale
end

local function safeConfigName(name)
    if name == nil then return "VortexConfig" end
    if type(name) ~= "string" or name == "" or name:find("..", 1, true) or name:find("[/\\]", 1) then
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
    local ok, result = pcall(writefile, configName .. ".json", encoded)
    if not ok then
        return false, result
    end
    if result == false then
        return false, "writefile returned false"
    end
    return true
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
