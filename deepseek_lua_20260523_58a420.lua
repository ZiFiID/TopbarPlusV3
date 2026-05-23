-- // MERGED LUA SCRIPT - FIXED FOR EXPLOITS
-- // Total Files: 8

-- // Fix untuk environment exploit
local OriginalEnvironment = getfenv and getfenv() or _G
local moduleScript = {}
local running = true

-- // SERVICES
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

-- // Helper Functions untuk menghindari nil value
local function safeRequire(module)
    local success, result = pcall(function()
        return require(module)
    end)
    if success then
        return result
    end
    return nil
end

-- // Signal Class (Fixed)
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = {
        _handlers = {},
        _connections = {}
    }
    setmetatable(self, Signal)
    return self
end

function Signal:Connect(fn)
    local connection = {
        _connected = true,
        _fn = fn,
        _signal = self
    }
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
            local success, err = pcall(function()
                handler._fn(...)
            end)
            if not success then
                warn("Signal handler error:", err)
            end
        end
    end
end

function Signal:Wait()
    local waiting = true
    local args = nil
    local connection = self:Connect(function(...)
        args = {...}
        waiting = false
    end)
    repeat
        RunService.Heartbeat:Wait()
    until not waiting
    connection:Disconnect()
    return table.unpack(args or {})
end

function Signal:Destroy()
    for _, handler in ipairs(self._handlers) do
        handler._connected = false
    end
    self._handlers = {}
end

-- // Janitor Class (Fixed)
local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    local self = {
        _objects = {},
        _indices = {},
        _cleaning = false
    }
    setmetatable(self, Janitor)
    return self
end

function Janitor:Add(obj, method, index)
    if index then
        self:Remove(index)
        self._indices[index] = obj
    end
    
    local objType = typeof(obj)
    local methodName = method
    
    if not methodName then
        if objType == "RBXScriptConnection" then
            methodName = "Disconnect"
        elseif type(obj) == "function" then
            methodName = nil
        else
            methodName = "Destroy"
        end
    end
    
    self._objects[obj] = {method = methodName, trace = debug and debug.traceback and debug.traceback("") or "unknown"}
    return obj
end

function Janitor:Remove(index)
    local obj = self._indices[index]
    if obj then
        local data = self._objects[obj]
        if data then
            local method = data.method
            local success, err = pcall(function()
                if method == nil and type(obj) == "function" then
                    obj()
                elseif obj[method] then
                    obj[method](obj)
                end
            end)
            if not success then
                warn("Janitor cleanup error:", err)
            end
            self._objects[obj] = nil
        end
        self._indices[index] = nil
    end
    return self
end

function Janitor:Cleanup()
    if self._cleaning then
        return
    end
    self._cleaning = true
    
    local objects = {}
    for obj, data in pairs(self._objects) do
        objects[obj] = data
    end
    
    for obj, data in pairs(objects) do
        local method = data.method
        local success, err = pcall(function()
            if method == nil and type(obj) == "function" then
                obj()
            elseif obj and obj[method] then
                obj[method](obj)
            end
        end)
        if not success then
            warn("Janitor cleanup error:", err)
        end
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

-- // Utility Functions
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

function Utility.createStagger(delayTime, callback, delayInitially)
    if not delayTime or delayTime == 0 then
        delayTime = 0.01
    end
    local staggerActive = false
    local multipleCalls = false
    local packedArgs = nil
    
    local function staggeredCallback(...)
        if staggerActive then
            multipleCalls = true
            packedArgs = {...}
            return
        end
        local args = {...}
        staggerActive = true
        multipleCalls = false
        
        local function execute()
            local success, err = pcall(function()
                callback(table.unpack(args))
            end)
            if not success then
                warn("Stagger callback error:", err)
            end
        end
        
        if delayInitially then
            task.wait(delayTime)
            execute()
        else
            execute()
        end
        
        task.delay(delayTime, function()
            staggerActive = false
            if multipleCalls and packedArgs then
                staggeredCallback(table.unpack(packedArgs))
                packedArgs = nil
            end
        end)
    end
    return staggeredCallback
end

function Utility.copyTable(t)
    local new = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            new[k] = Utility.copyTable(v)
        else
            new[k] = v
        end
    end
    return new
end

function Utility.localPlayerRespawned(callback)
    local player = Players.LocalPlayer
    if player then
        player.CharacterRemoving:Connect(callback)
    end
end

-- // Theme Manager
local Themes = {}

local baseTheme = {
    {"IconCorners", "CornerRadius", UDim.new(1, 0)},
    {"IconImage", "Image", "", "Deselected"},
    {"IconLabel", "Text", "", "Deselected"},
    {"Widget", "MinimumWidth", 44, "Deselected"},
    {"Widget", "MinimumHeight", 44, "Deselected"},
    {"Widget", "BorderSize", 4, "Deselected"},
    {"IconButton", "BackgroundColor3", Color3.fromRGB(18, 18, 21), "Deselected"},
    {"IconButton", "BackgroundTransparency", 0.08, "Deselected"},
    {"IconImageScale", "Value", 0.5, "Deselected"},
    {"IconLabel", "TextSize", 16, "Deselected"},
    {"IconSpot", "BackgroundTransparency", 0.7, "Selected"},
    {"IconSpot", "BackgroundColor3", Color3.fromRGB(255, 255, 255), "Selected"},
}

function Themes.getModifications(modifications)
    if type(modifications[1]) ~= "table" then
        return {modifications}
    end
    return modifications
end

function Themes.apply(icon, instanceName, property, value, forceApply)
    if not icon or icon.isDestroyed then
        return
    end
    
    local instances = icon:getInstanceOrCollective(instanceName)
    if not instances then
        return
    end
    
    local key = tostring(instanceName) .. "-" .. tostring(property)
    local customBehaviour = icon.customBehaviours and icon.customBehaviours[key]
    
    for _, instance in ipairs(instances) do
        if instance then
            local newValue = value
            if customBehaviour then
                local customResult = customBehaviour(value, instance, property)
                if customResult ~= nil then
                    newValue = customResult
                end
            end
            
            local success, err = pcall(function()
                if instance[property] ~= nil then
                    instance[property] = newValue
                else
                    instance:SetAttribute(property, newValue)
                end
            end)
            if not success then
                -- Silently fail
            end
        end
    end
end

function Themes.modify(icon, modifications, modificationsUID)
    modificationsUID = modificationsUID or Utility.generateUID()
    modifications = Themes.getModifications(modifications)
    
    for _, mod in ipairs(modifications) do
        local instanceName, property, value, iconState = table.unpack(mod)
        local state = Utility.formatStateName(iconState or "Deselected")
        
        if not icon.appearance[state] then
            icon.appearance[state] = {}
        end
        
        local found = false
        for i, detail in ipairs(icon.appearance[state]) do
            if detail[1] == instanceName and detail[2] == property then
                icon.appearance[state][i][3] = value
                icon.appearance[state][i][5] = modificationsUID
                found = true
                break
            end
        end
        
        if not found then
            table.insert(icon.appearance[state], {instanceName, property, value, state, modificationsUID})
        end
        
        if state == icon.activeState then
            Themes.apply(icon, instanceName, property, value)
        end
    end
    
    return modificationsUID
end

function Themes.set(icon, theme)
    icon.appliedTheme = theme or baseTheme
end

function Themes.change(icon)
    local stateGroup = icon:getStateGroup()
    if not stateGroup then
        return
    end
    
    for _, detail in ipairs(stateGroup) do
        local instanceName, property, value = table.unpack(detail)
        Themes.apply(icon, instanceName, property, value)
    end
end

-- // Main Icon Class
local Icon = {}
Icon.__index = Icon

local iconsDict = {}
local totalCreatedIcons = 0

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
    self.cachedNamesToInstances = {}
    self.cachedCollectives = {}
    self.customBehaviours = {}
    self.childIconsDict = {}
    self.deselectWhenOtherIconSelected = true
    self.overlayDisabled = false
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
    
    -- Create widget UI
    self:createWidget()
    
    -- Apply theme
    Themes.set(self, baseTheme)
    Themes.change(self)
    
    totalCreatedIcons = totalCreatedIcons + 1
    
    return self
end

function Icon:createWidget()
    local widget = Instance.new("Frame")
    widget.Name = "Widget"
    widget.BackgroundTransparency = 1
    widget.Visible = true
    widget.Size = UDim2.new(0, 44, 0, 44)
    widget.Parent = nil
    self.widget = widget
    
    -- Button
    local button = Instance.new("Frame")
    button.Name = "IconButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 0.08
    button.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
    button.Parent = widget
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button
    
    -- Click region
    local clickRegion = Instance.new("TextButton")
    clickRegion.Name = "ClickRegion"
    clickRegion.BackgroundTransparency = 1
    clickRegion.Text = ""
    clickRegion.Size = UDim2.new(1, 0, 1, 0)
    clickRegion.Parent = button
    self.clickRegion = clickRegion
    
    -- Image
    local image = Instance.new("ImageLabel")
    image.Name = "IconImage"
    image.Size = UDim2.new(0, 22, 0, 22)
    image.Position = UDim2.new(0.5, -11, 0.5, -11)
    image.BackgroundTransparency = 1
    image.Visible = false
    image.Parent = widget
    self.iconImage = image
    
    -- Label
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
    label.Parent = widget
    self.iconLabel = label
    
    -- Events
    local lastToggle = 0
    local DEBOUNCE = 0.1
    
    local function handleToggle()
        if self.locked then
            return
        end
        local now = tick()
        if now - lastToggle < DEBOUNCE then
            return
        end
        lastToggle = now
        
        if self.isSelected then
            self:deselect()
        else
            self:select()
        end
    end
    
    clickRegion.MouseButton1Click:Connect(handleToggle)
    clickRegion.TouchTap:Connect(handleToggle)
    
    clickRegion.MouseEnter:Connect(function()
        if self.locked then
            return
        end
        self.isViewing = true
        self.viewingStarted:Fire()
    end)
    
    clickRegion.MouseLeave:Connect(function()
        self.isViewing = false
        self.viewingEnded:Fire()
    end)
    
    self:cacheInstance("Widget", widget)
    self:cacheInstance("IconButton", button)
    self:cacheInstance("ClickRegion", clickRegion)
    self:cacheInstance("IconImage", image)
    self:cacheInstance("IconLabel", label)
end

function Icon:cacheInstance(name, instance)
    self.cachedNamesToInstances[name] = instance
    self.cachedInstances[instance] = true
    
    instance.Destroying:Once(function()
        self.cachedNamesToInstances[name] = nil
        self.cachedInstances[instance] = nil
    end)
end

function Icon:getInstance(name)
    local instance = self.cachedNamesToInstances[name]
    if instance then
        return instance
    end
    
    local function search(parent)
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == name then
                self:cacheInstance(name, child)
                return child
            end
            local found = search(child)
            if found then
                return found
            end
        end
        return nil
    end
    
    return search(self.widget)
end

function Icon:getInstanceOrCollective(name)
    local instance = self:getInstance(name)
    if instance then
        return {instance}
    end
    
    local collective = self.cachedCollectives[name]
    if not collective then
        collective = {}
        for instance, _ in pairs(self.cachedInstances) do
            if instance:GetAttribute("Collective") == name then
                table.insert(collective, instance)
            end
        end
        self.cachedCollectives[name] = collective
    end
    
    return collective
end

function Icon:getStateGroup()
    local stateGroup = self.appearance[self.activeState]
    if not stateGroup then
        stateGroup = {}
        self.appearance[self.activeState] = stateGroup
    end
    return stateGroup
end

function Icon:setState(stateName)
    if not stateName then
        stateName = (self.isSelected and "Selected") or "Deselected"
    end
    
    local newState = Utility.formatStateName(stateName)
    if self.activeState == newState then
        return
    end
    
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

function Icon:select()
    self:setState("Selected")
    return self
end

function Icon:deselect()
    self:setState("Deselected")
    return self
end

function Icon:setEnabled(bool)
    self.isEnabled = bool
    if self.widget then
        self.widget.Visible = bool
    end
    return self
end

function Icon:setImage(imageId, state)
    local img = tostring(imageId)
    if tonumber(img) then
        img = "rbxassetid://" .. img
    end
    Themes.modify(self, {"IconImage", "Image", img, state or "Deselected"})
    return self
end

function Icon:setLabel(text, state)
    Themes.modify(self, {"IconLabel", "Text", tostring(text), state or "Deselected"})
    self.iconLabel.Visible = text ~= ""
    return self
end

function Icon:setOrder(order, state)
    local int = math.floor(order * 100)
    if self.widget then
        self.widget.LayoutOrder = int
    end
    return self
end

function Icon:align(position)
    position = string.lower(tostring(position))
    local screenGui = self.screenGui or game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    if not self.widget then
        return self
    end
    
    if not self.alignmentHolder then
        self.alignmentHolder = screenGui
    end
    
    self.widget.Parent = self.alignmentHolder
    self.alignment = position
    self.alignmentChanged:Fire(position)
    
    return self
end

function Icon:setLeft()
    return self:align("left")
end

function Icon:setRight()
    return self:align("right")
end

function Icon:setMid()
    return self:align("center")
end

function Icon:lock()
    if self.clickRegion then
        self.clickRegion.Visible = false
    end
    self.locked = true
    return self
end

function Icon:unlock()
    if self.clickRegion then
        self.clickRegion.Visible = true
    end
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
        signal:Connect(function(...)
            callback(self, ...)
        end)
    end
    return self
end

function Icon:destroy()
    if self.isDestroyed then
        return
    end
    self.isDestroyed = true
    
    if self.janitor then
        self.janitor:Destroy()
    end
    
    if self.widget then
        self.widget:Destroy()
    end
    
    iconsDict[self.UID] = nil
end

function Icon.getIcon(name)
    for _, icon in pairs(iconsDict) do
        if icon.name == name then
            return icon
        end
    end
    return nil
end

function Icon.getIcons()
    return iconsDict
end

-- // Module Return
local TopbarPlus = {
    new = function()
        return Icon.new()
    end,
    Icon = Icon,
    getIcons = Icon.getIcons,
    getIcon = Icon.getIcon
}

return TopbarPlus