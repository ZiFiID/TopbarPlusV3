-- // TOPBARPLUS V3 - FULL SCRIPT (LANGSUNG PAKAI)
-- // Copas seluruh script ini ke exploit dan jalankan

-- // SERVICES
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

-- // SIGNAL CLASS
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = { _handlers = {}, _connections = {} }
    setmetatable(self, Signal)
    return self
end

function Signal:Connect(fn)
    local connection = { _connected = true, _fn = fn, _signal = self }
    table.insert(self._handlers, connection)
    return {
        Disconnect = function()
            if connection._connected then
                connection._connected = false
                for i, handler in ipairs(self._handlers) do
                    if handler == connection then
                        table.remove(self._handlers, i)
                        break
                    end
                end
            end
        end
    }
end

function Signal:Fire(...)
    local handlers = {}
    for _, handler in ipairs(self._handlers) do
        if handler._connected then
            table.insert(handlers, handler)
        end
    end
    for _, handler in handlers do
        if handler._connected then
            local success, err = pcall(handler._fn, ...)
            if not success then
                warn("Signal error: " .. tostring(err))
            end
        end
    end
end

function Signal:Wait()
    local waiting, args = true, nil
    local connection = self:Connect(function(...)
        args = { ... }
        waiting = false
    end)
    repeat RunService.Heartbeat:Wait() until not waiting
    connection:Disconnect()
    return table.unpack(args or {})
end

function Signal:Destroy()
    for _, handler in ipairs(self._handlers) do
        handler._connected = false
    end
    self._handlers = {}
end

-- // JANITOR CLASS
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    local self = { _objects = {}, _indices = {}, _cleaning = false }
    setmetatable(self, Janitor)
    return self
end

function Janitor:Add(obj, method, index)
    if index then
        self:Remove(index)
        self._indices[index] = obj
    end
    
    local methodName = method
    if not methodName then
        local objType = typeof(obj)
        if objType == "RBXScriptConnection" then
            methodName = "Disconnect"
        elseif type(obj) == "function" then
            methodName = nil
        else
            methodName = "Destroy"
        end
    end
    
    self._objects[obj] = { method = methodName }
    return obj
end

function Janitor:Remove(index)
    local obj = self._indices[index]
    if obj then
        local data = self._objects[obj]
        if data then
            local method = data.method
            pcall(function()
                if method == nil and type(obj) == "function" then
                    obj()
                elseif obj[method] then
                    obj[method](obj)
                end
            end)
            self._objects[obj] = nil
        end
        self._indices[index] = nil
    end
    return self
end

function Janitor:Cleanup()
    if self._cleaning then return end
    self._cleaning = true
    
    for obj, data in pairs(self._objects) do
        local method = data.method
        pcall(function()
            if method == nil and type(obj) == "function" then
                obj()
            elseif obj and obj[method] then
                obj[method](obj)
            end
        end)
        self._objects[obj] = nil
    end
    
    for idx in pairs(self._indices) do
        self._indices[idx] = nil
    end
    
    self._cleaning = false
end

function Janitor:Destroy()
    self:Cleanup()
    self._objects = nil
    self._indices = nil
end

-- // UTILITY
local Utility = {}

function Utility.generateUID(length)
    length = length or 8
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""
    for i = 1, length do
        result = result .. string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return result
end

function Utility.formatStateName(name)
    if not name then return "Deselected" end
    return string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2))
end

function Utility.createStagger(delayTime, callback)
    delayTime = delayTime or 0.01
    local active = false
    local function staggered(...)
        if active then return end
        active = true
        local args = { ... }
        task.spawn(function()
            callback(table.unpack(args))
        end)
        task.delay(delayTime, function()
            active = false
        end)
    end
    return staggered
end

-- // THEMES
local Themes = {}

local baseTheme = {
    { "IconCorners", "CornerRadius", UDim.new(1, 0) },
    { "Widget", "MinimumWidth", 44 },
    { "Widget", "MinimumHeight", 44 },
    { "IconButton", "BackgroundColor3", Color3.fromRGB(18, 18, 21) },
    { "IconButton", "BackgroundTransparency", 0.08 },
    { "IconLabel", "TextSize", 16 },
    { "IconLabel", "TextColor3", Color3.fromRGB(255, 255, 255) },
    { "IconSpot", "BackgroundTransparency", 0.7, "Selected" },
    { "IconSpot", "BackgroundColor3", Color3.fromRGB(255, 255, 255), "Selected" },
}

function Themes.getModifications(mods)
    if type(mods[1]) ~= "table" then return { mods } end
    return mods
end

function Themes.apply(icon, instanceName, property, value)
    if not icon or icon.isDestroyed then return end
    local instances = icon:getInstanceOrCollective(instanceName)
    if not instances then return end
    
    for _, instance in pairs(instances) do
        if instance then
            pcall(function()
                if instance[property] ~= nil then
                    instance[property] = value
                else
                    instance:SetAttribute(property, value)
                end
            end)
        end
    end
end

function Themes.modify(icon, modifications, uid)
    uid = uid or Utility.generateUID()
    modifications = Themes.getModifications(modifications)
    
    for _, mod in ipairs(modifications) do
        local instanceName, property, value, state = table.unpack(mod)
        state = Utility.formatStateName(state or icon.activeState or "Deselected")
        
        if not icon.appearance[state] then
            icon.appearance[state] = {}
        end
        
        local found = false
        for i, detail in ipairs(icon.appearance[state]) do
            if detail[1] == instanceName and detail[2] == property then
                icon.appearance[state][i][3] = value
                found = true
                break
            end
        end
        
        if not found then
            table.insert(icon.appearance[state], { instanceName, property, value, state, uid })
        end
        
        if state == icon.activeState then
            Themes.apply(icon, instanceName, property, value)
        end
    end
    
    return uid
end

function Themes.set(icon, theme)
    icon.appliedTheme = theme or baseTheme
end

function Themes.change(icon)
    local stateGroup = icon.appearance[icon.activeState or "Deselected"]
    if not stateGroup then return end
    
    for _, detail in ipairs(stateGroup) do
        local instanceName, property, value = table.unpack(detail)
        Themes.apply(icon, instanceName, property, value)
    end
end

-- // ICON CLASS
local Icon = {}
Icon.__index = Icon

local iconsDict = {}
local totalIcons = 0

function Icon.new()
    local self = {}
    setmetatable(self, Icon)
    
    self.janitor = Janitor.new()
    self.UID = Utility.generateUID()
    self.isEnabled = true
    self.isSelected = false
    self.isViewing = false
    self.activeState = "Deselected"
    self.appearance = {}
    self.cachedInstances = {}
    self.cachedNames = {}
    self.cachedCollectives = {}
    self.customBehaviours = {}
    self.locked = false
    
    -- Signals
    self.selected = Signal.new()
    self.deselected = Signal.new()
    self.toggled = Signal.new()
    self.viewingStarted = Signal.new()
    self.viewingEnded = Signal.new()
    self.stateChanged = Signal.new()
    self.alignmentChanged = Signal.new()
    self.updateSize = Signal.new()
    
    iconsDict[self.UID] = self
    
    self:createWidget()
    Themes.set(self, baseTheme)
    Themes.change(self)
    
    totalIcons = totalIcons + 1
    return self
end

function Icon:createWidget()
    local widget = Instance.new("Frame")
    widget.Name = "Widget"
    widget.BackgroundTransparency = 1
    widget.Size = UDim2.new(0, 44, 0, 44)
    widget.ClipsDescendants = false
    self.widget = widget
    
    local button = Instance.new("Frame")
    button.Name = "IconButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    button.BackgroundTransparency = 0.08
    button.Parent = widget
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button
    
    local clickRegion = Instance.new("TextButton")
    clickRegion.Name = "ClickRegion"
    clickRegion.BackgroundTransparency = 1
    clickRegion.Text = ""
    clickRegion.Size = UDim2.new(1, 0, 1, 0)
    clickRegion.Parent = button
    self.clickRegion = clickRegion
    
    local iconSpot = Instance.new("Frame")
    iconSpot.Name = "IconSpot"
    iconSpot.Size = UDim2.new(1, 0, 1, 0)
    iconSpot.BackgroundTransparency = 1
    iconSpot.Parent = widget
    
    local image = Instance.new("ImageLabel")
    image.Name = "IconImage"
    image.Size = UDim2.new(0, 22, 0, 22)
    image.Position = UDim2.new(0.5, -11, 0.5, -11)
    image.BackgroundTransparency = 1
    image.Visible = false
    image.Parent = iconSpot
    self.iconImage = image
    
    local label = Instance.new("TextLabel")
    label.Name = "IconLabel"
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Text = ""
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Visible = false
    label.Parent = iconSpot
    self.iconLabel = label
    
    local lastToggle = 0
    local function handleToggle()
        if self.locked then return end
        if tick() - lastToggle < 0.1 then return end
        lastToggle = tick()
        if self.isSelected then self:deselect() else self:select() end
    end
    
    clickRegion.MouseButton1Click:Connect(handleToggle)
    clickRegion.TouchTap:Connect(handleToggle)
    
    clickRegion.MouseEnter:Connect(function()
        if not self.locked then
            self.isViewing = true
            self.viewingStarted:Fire()
        end
    end)
    
    clickRegion.MouseLeave:Connect(function()
        self.isViewing = false
        self.viewingEnded:Fire()
    end)
    
    self:cacheInstance("Widget", widget)
    self:cacheInstance("IconButton", button)
    self:cacheInstance("ClickRegion", clickRegion)
    self:cacheInstance("IconSpot", iconSpot)
    self:cacheInstance("IconImage", image)
    self:cacheInstance("IconLabel", label)
end

function Icon:cacheInstance(name, instance)
    self.cachedNames[name] = instance
    self.cachedInstances[instance] = true
    instance.Destroying:Once(function()
        self.cachedNames[name] = nil
        self.cachedInstances[instance] = nil
    end)
end

function Icon:getInstance(name)
    return self.cachedNames[name]
end

function Icon:getInstanceOrCollective(name)
    local inst = self:getInstance(name)
    if inst then return { inst } end
    
    local col = self.cachedCollectives[name]
    if not col then
        col = {}
        for inst, _ in pairs(self.cachedInstances) do
            if inst:GetAttribute("Collective") == name then
                table.insert(col, inst)
            end
        end
        self.cachedCollectives[name] = col
    end
    return col
end

function Icon:setState(stateName)
    local newState = Utility.formatStateName(stateName or (self.isSelected and "Selected" or "Deselected"))
    if self.activeState == newState then return end
    
    local wasSelected = self.isSelected
    self.activeState = newState
    
    if newState == "Selected" then
        self.isSelected = true
        if not wasSelected then
            self.toggled:Fire(true)
            self.selected:Fire()
        end
    elseif newState == "Deselected" then
        self.isSelected = false
        if wasSelected then
            self.toggled:Fire(false)
            self.deselected:Fire()
        end
    end
    
    self.stateChanged:Fire(newState)
    Themes.change(self)
end

function Icon:select() self:setState("Selected") return self end
function Icon:deselect() self:setState("Deselected") return self end

function Icon:setEnabled(bool)
    self.isEnabled = bool
    if self.widget then self.widget.Visible = bool end
    return self
end

function Icon:setImage(imageId, state)
    local img = tostring(imageId)
    if tonumber(img) then img = "rbxassetid://" .. img end
    Themes.modify(self, { "IconImage", "Image", img, state })
    if self.iconImage then
        self.iconImage.Image = img
        self.iconImage.Visible = img ~= ""
    end
    return self
end

function Icon:setLabel(text, state)
    Themes.modify(self, { "IconLabel", "Text", tostring(text or ""), state })
    if self.iconLabel then
        self.iconLabel.Text = tostring(text or "")
        self.iconLabel.Visible = text ~= nil and text ~= ""
    end
    return self
end

function Icon:setOrder(order)
    if self.widget then
        self.widget.LayoutOrder = math.floor((order or 0) * 100)
    end
    return self
end

function Icon:setCornerRadius(radius, state)
    Themes.modify(self, { "IconCorners", "CornerRadius", radius or UDim.new(1, 0), state })
    return self
end

function Icon:align(position)
    position = string.lower(tostring(position or "left"))
    if not self.widget then return self end
    
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return self end
    
    self.widget.Parent = playerGui
    
    if position == "left" then
        self.widget.Position = UDim2.new(0, 5, 0, 5)
    elseif position == "right" then
        self.widget.Position = UDim2.new(1, -49, 0, 5)
    else
        self.widget.Position = UDim2.new(0.5, -22, 0, 5)
    end
    
    self.alignment = position
    self.alignmentChanged:Fire(position)
    return self
end

function Icon:setLeft() return self:align("left") end
function Icon:setRight() return self:align("right") end
function Icon:setMid() return self:align("center") end

function Icon:lock()
    if self.clickRegion then self.clickRegion.Visible = false end
    self.locked = true
    return self
end

function Icon:unlock()
    if self.clickRegion then self.clickRegion.Visible = true end
    self.locked = false
    return self
end

function Icon:modifyTheme(modifications, uid)
    Themes.modify(self, modifications, uid)
    return self
end

function Icon:bindEvent(eventName, callback)
    local signal = self[eventName]
    if signal and signal.Connect then
        signal:Connect(function(...) callback(self, ...) end)
    end
    return self
end

function Icon:setTooltip(text)
    if self.clickRegion then
        self.clickRegion.Tooltip = tostring(text or "")
    end
    return self
end

function Icon:destroy()
    if self.isDestroyed then return end
    self.isDestroyed = true
    if self.janitor then self.janitor:Destroy() end
    if self.widget then self.widget:Destroy() end
    iconsDict[self.UID] = nil
end

-- // MODULE RETURN
local TopbarPlus = {
    new = Icon.new,
    Icon = Icon,
    getIcons = function() return iconsDict end,
    getIcon = function(name)
        for _, icon in pairs(iconsDict) do
            if icon.name == name then return icon end
        end
        return nil
    end
}
