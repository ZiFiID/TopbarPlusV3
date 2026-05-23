-- // MERGED LUA SCRIPT
-- // Total Files: 8

-- // init.lua
--!nonstrict
--[[
	
	The majority of this code is an interface designed to make it easy for you to
	work with TopbarPlus (most methods for instance reference :modifyTheme()).
	The processing overhead mainly consists of applying themes and calculating 
	appearance (such as size and width of labels) which is handled in about
	200 lines of code here and the Widget UI module. This has been achieved
	in v3 by outsourcing a majority of previous calculations to inbuilt Roblox
	features like UIListLayouts.


	v3 provides inbuilt support for controllers (simply press DPadUp),
	touch devices (phones, tablets , etc), localization (automatic resizing
	of widgets, autolocalize for relevant labels), backwards compatability
	with the old topbar, and more.


	My primary goals for the v3 re-write have been to:
		
	1. Improve code readability and organisation (reduced lines of code within
	   Icon+IconController from 3200 to ~950, separated UI elements, etc)
		
	2. Improve ease-of-use (themes now actually make sense and can account
	   for any modifications you want, converted to a package for
	   quick installation and easy-comparisons of new updates, etc)
	
	3. Provide support for all key features of the new Roblox topbar
	   while improving performance of the module (deferring and collecting
	   changes then calling as a singular, utilizing inbuilt Roblox features
	   such as UILIstLayouts, etc)

--]]



-- SERVICES
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Types = require(script.Types)



-- TYPES
export type Icon = Types.Icon



-- REFERENCE HANDLER
-- Multiple Icons packages may exist at runtime (for instance if the developer additionally uses HD Admin)
-- therefore this ensures that the first required package becomes the dominant and only functioning module
local iconModule = script
local Reference = require(iconModule.Reference)
local referenceObject = Reference.getObject()
local leadPackage = referenceObject and referenceObject.Value
if leadPackage and leadPackage ~= iconModule then
	return require(leadPackage) :: Types.StaticIcon
end
if not referenceObject then
	Reference.addToReplicatedStorage()
end



-- MODULES
local Signal = require(iconModule.Packages.GoodSignal)
local Janitor = require(iconModule.Packages.Janitor)
local Utility = require(iconModule.Utility)
local Themes = require(iconModule.Features.Themes)
local Gamepad = require(iconModule.Features.Gamepad)
local Overflow = require(iconModule.Features.Overflow)
local Icon = {}
Icon.__index = Icon



--- LOCAL
local localPlayer = Players.LocalPlayer
local themes = iconModule.Features.Themes
local iconsDict = {}
local anyIconSelected = Signal.new()
local elements = iconModule.Elements
local totalCreatedIcons = 0
local preferredInput = {
	mobile = Enum.PreferredInput.Touch,
	desktop = Enum.PreferredInput.KeyboardAndMouse,
	console = Enum.PreferredInput.Gamepad
}



-- PUBLIC VARIABLES
Icon.baseDisplayOrderChanged = Signal.new()
Icon.baseDisplayOrder = 10
Icon.baseTheme = require(themes.Default)
Icon.isOldTopbar = false -- Logic has been moved to Container
Icon.iconsDictionary = iconsDict
Icon.insetHeightChanged = Signal.new()
Icon.container = require(elements.Container)(Icon)
Icon.topbarEnabled = true
Icon.iconAdded = Signal.new()
Icon.iconRemoved = Signal.new()
Icon.iconChanged = Signal.new()



-- PUBLIC FUNCTIONS
function Icon.getIcons()
	return Icon.iconsDictionary
end

function Icon.getIconByUID(UID)
	local match = Icon.iconsDictionary[UID]
	if match then
		return match
	end
	return nil
end

function Icon.getIcon(nameOrUID)
	local match = Icon.getIconByUID(nameOrUID)
	if match then
		return match
	end
	for _, icon in pairs(iconsDict) do
		if icon.name == nameOrUID then
			return icon
		end
	end
	return nil
end

function Icon.setTopbarEnabled(bool, isInternal)
	if typeof(bool) ~= "boolean" then
		bool = Icon.topbarEnabled
	end
	if not isInternal then
		Icon.topbarEnabled = bool
	end
	for _, screenGui in pairs(Icon.container) do
		screenGui.Enabled = bool
	end
end

function Icon.modifyBaseTheme(modifications)
	modifications = Themes.getModifications(modifications)
	for _, modification in pairs(modifications) do
		for _, detail in pairs(Icon.baseTheme) do
			Themes.merge(detail, modification)
		end
	end
	for _, icon in pairs(iconsDict) do
		icon:setTheme(Icon.baseTheme)
	end
end

function Icon.setDisplayOrder(int)
	Icon.baseDisplayOrder = int
	Icon.baseDisplayOrderChanged:Fire(int)
end



-- SETUP
task.defer(Gamepad.start, Icon)
task.defer(Overflow.start, Icon)
task.defer(function()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	for _, screenGui in pairs(Icon.container) do
		screenGui.Parent = playerGui
	end
	require(iconModule.Attribute)
end)



-- CONSTRUCTOR
function Icon.new()
	local self = {}
	setmetatable(self, Icon)

	--- Janitors (for cleanup)
	local janitor = Janitor.new()
	self.janitor = janitor
	self.themesJanitor = janitor:add(Janitor.new())
	self.singleClickJanitor = janitor:add(Janitor.new())
	self.captionJanitor = janitor:add(Janitor.new())
	self.joinJanitor = janitor:add(Janitor.new())
	self.menuJanitor = janitor:add(Janitor.new())
	self.dropdownJanitor = janitor:add(Janitor.new())

	-- Register
	local iconUID = Utility.generateUID()
	iconsDict[iconUID] = self
	janitor:add(function()
		iconsDict[iconUID] = nil
	end)

	-- Signals (events)
	self.selected = janitor:add(Signal.new())
	self.deselected = janitor:add(Signal.new())
	self.toggled = janitor:add(Signal.new())
	self.viewingStarted = janitor:add(Signal.new())
	self.viewingEnded = janitor:add(Signal.new())
	self.stateChanged = janitor:add(Signal.new())
	self.notified = janitor:add(Signal.new())
	self.noticeStarted = janitor:add(Signal.new())
	self.noticeChanged = janitor:add(Signal.new())
	self.endNotices = janitor:add(Signal.new())
	self.toggleKeyAdded = janitor:add(Signal.new())
	self.fakeToggleKeyChanged = janitor:add(Signal.new())
	self.alignmentChanged = janitor:add(Signal.new())
	self.updateSize = janitor:add(Signal.new())
	self.resizingComplete = janitor:add(Signal.new())
	self.joinedParent = janitor:add(Signal.new())
	self.menuSet = janitor:add(Signal.new())
	self.dropdownSet = janitor:add(Signal.new())
	self.updateMenu = janitor:add(Signal.new())
	self.startMenuUpdate = janitor:add(Signal.new())
	self.childThemeModified = janitor:add(Signal.new())
	self.indicatorSet = janitor:add(Signal.new())
	self.dropdownChildAdded = janitor:add(Signal.new())
	self.menuChildAdded = janitor:add(Signal.new())

	-- Properties
	self.iconModule = iconModule
	self.UID = iconUID
	self.isEnabled = true
	self.enabled = self.isEnabled -- Backwards compatability
	self.isSelected = false
	self.isViewing = false
	self.joinedFrame = false
	self.parentIconUID = false
	self.deselectWhenOtherIconSelected = true
	self.totalNotices = 0
	self.activeState = "Deselected"
	self.alignment = ""
	self.originalAlignment = ""
	self.appliedTheme = {}
	self.appearance = {}
	self.cachedInstances = {}
	self.cachedNamesToInstances = {}
	self.cachedCollectives = {}
	self.bindedToggleKeys = {}
	self.customBehaviours = {}
	self.toggleItems = {}
	self.bindedEvents = {}
	self.notices = {}
	self.menuIcons = {}
	self.dropdownIcons = {}
	self.childIconsDict = {}
	self.creationTime = os.clock()

	-- Widget is the new name for an icon
	local widget = janitor:add(require(elements.Widget)(self, Icon))
	self.widget = widget
	self:setAlignment()
	
	-- It's important we set an order otherwise icons will not align
	-- correctly within menus
	totalCreatedIcons += 1
	local ourOrder = 1+(totalCreatedIcons*0.01)
	self:setOrder(ourOrder, "deselected")
	self:setOrder(ourOrder, "selected")

	-- This applies the default them
	self:setTheme(Icon.baseTheme)

	-- Button Clicked (for states "Selected" and "Deselected")
	local clickRegion = self:getInstance("ClickRegion")
	local hasUsedMouseButton1Click = false
	local lastToggleTime = 0
	local DEBOUNCE_TIME = 0.1 -- 100ms debounce to prevent rapid toggles

	local function handleToggle()
		if self.locked then
			return
		end

		-- Debounce logic to prevent rapid toggling
		local currentTime = tick()
		if currentTime - lastToggleTime < DEBOUNCE_TIME then
			return
		end
		lastToggleTime = currentTime

		if self.isSelected then
			self:deselect("User", self)
		else
			self:select("User", self)
		end
	end

	clickRegion.MouseButton1Click:Connect(function()
		hasUsedMouseButton1Click = true
		handleToggle()
	end)

	clickRegion.TouchTap:Connect(function()
		-- This resolves the bug report by @28Pixels:
		-- https://devforum.roblox.com/t/topbarplus/1017485/1104
		-- Only use TouchTap if MouseButton1Click has never fired
		-- This handles edge cases where ONLY TouchTap works
		-- Also prevents double-toggle bug with multi-touch on mobile
		-- Credit to @sayer80 for this fix
		if not hasUsedMouseButton1Click then
			handleToggle()
		end
	end)

	-- Keys can be bound to toggle between Selected and Deselected
	janitor:add(UserInputService.InputBegan:Connect(function(input, touchingAnObject)
		if self.locked then
			return
		end
		if self.bindedToggleKeys[input.KeyCode] and not touchingAnObject then
			handleToggle()
		end
	end))

	-- Button Hovering (for state "Viewing")
	-- Hovering is a state only for devices with keyboards
	-- and controllers (not touchpads)
	local function viewingStarted(dontSetState)
		if self.locked then
			return
		end
		self.isViewing = true
		self.viewingStarted:Fire(true)
		if not dontSetState then
			self:setState("Viewing", "User", self)
		end
	end
	local function viewingEnded()
		if self.locked then
			return
		end
		self.isViewing = false
		self.viewingEnded:Fire(true)
		self:setState(nil, "User", self)
	end
	self.joinedParent:Connect(function()
		if self.isViewing then
			viewingEnded()
		end
	end)
	clickRegion.MouseEnter:Connect(function()
		local dontSetState = UserInputService.PreferredInput ~= preferredInput.desktop
		viewingStarted(dontSetState)
	end)
	local touchCount = 0
	janitor:add(UserInputService.TouchEnded:Connect(viewingEnded))
	clickRegion.MouseLeave:Connect(viewingEnded)
	clickRegion.SelectionGained:Connect(viewingStarted)
	clickRegion.SelectionLost:Connect(viewingEnded)
	clickRegion.MouseButton1Down:Connect(function()
		if not self.locked and UserInputService.PreferredInput == preferredInput.mobile then
			touchCount += 1
			local myTouchCount = touchCount
			task.delay(0.2, function()
				if myTouchCount == touchCount then
					viewingStarted()
				end
			end)
		end
	end)
	clickRegion.MouseButton1Up:Connect(function()
		touchCount += 1
	end)

	-- Handle overlay on viewing
	local iconOverlay = self:getInstance("IconOverlay")
	self.viewingStarted:Connect(function()
		iconOverlay.Visible = not self.overlayDisabled
	end)
	self.viewingEnded:Connect(function()
		iconOverlay.Visible = false
	end)

	-- Deselect when another icon is selected
	janitor:add(anyIconSelected:Connect(function(incomingIcon)
		if incomingIcon ~= self and self.deselectWhenOtherIconSelected and incomingIcon.deselectWhenOtherIconSelected then
			self:deselect("AutoDeselect", incomingIcon)
		end
	end))

	-- This checks if the script calling this module is a descendant of a ScreenGui
	-- with 'ResetOnSpawn' set to true. If it is, then we destroy the icon the
	-- client respawns. This solves one of the most asked about questions on the post
	-- The only caveat this may not work if the player doesn't uniquely name their ScreenGui and the frames
	-- the LocalScript rests within
	local source =  debug.info(2, "s")
	local sourcePath = string.split(source, ".")
	local origin = game
	local originsScreenGui
	for i, sourceName in pairs(sourcePath) do
		origin = origin:FindFirstChild(sourceName)
		if not origin then
			break
		end
		if origin:IsA("ScreenGui") then
			originsScreenGui = origin
		end
	end
	if origin and originsScreenGui and originsScreenGui.ResetOnSpawn == true then
		self.originsScreenGui = originsScreenGui
		Utility.localPlayerRespawned(function()
			self:destroy()
		end)
	end

	-- Additional children behaviour when toggled (mostly notices)
	self.toggled:Connect(function(isSelected)
		self.noticeChanged:Fire(self.totalNotices)
		for childIconUID, _ in pairs(self.childIconsDict) do
			local childIcon = Icon.getIconByUID(childIconUID)
			childIcon.noticeChanged:Fire(childIcon.totalNotices)
			if not isSelected and childIcon.isSelected then
				-- If an icon within a menu or dropdown is also
				-- a dropdown or menu, then close it
				for _, _ in pairs(childIcon.childIconsDict) do
					childIcon:deselect("HideParentFeature", self)
				end
			end
		end
	end)
	
	-- This closes/reopens the chat or playerlist if the icon is a dropdown
	-- In the future I'd prefer to use the position+size of the chat
	-- to determine whether to close dropdown (instead of non-right-set)
	-- but for reasons mentioned here it's unreliable at the time of
	-- writing this: https://devforum.roblox.com/t/here/2794915
	-- I could also make this better by accounting for multiple
	-- dropdowns being open (not just this one) but this will work
	-- fine for almost every use case for now.
	self.selected:Connect(function()
		local isDropdown = #self.dropdownIcons > 0
		if isDropdown then
			if StarterGui:GetCore("ChatActive") and self.alignment ~= "Right" then
				self.chatWasPreviouslyActive = true
				StarterGui:SetCore("ChatActive", false)
			end
			if StarterGui:GetCoreGuiEnabled("PlayerList") and self.alignment ~= "Left" then
				self.playerlistWasPreviouslyActive = true
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end
		end
	end)
	self.deselected:Connect(function()
		if self.chatWasPreviouslyActive then
			self.chatWasPreviouslyActive = nil
			StarterGui:SetCore("ChatActive", true)
		end
		if self.playerlistWasPreviouslyActive then
			self.playerlistWasPreviouslyActive = nil
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
		end
	end)
	
	-- There's a rare occassion where the appearance is not
	-- fully set to deselected so this ensures the icons
	-- appearance is fully as it should be
	task.delay(0.1, function()
		if self.activeState == "Deselected" then
			self.stateChanged:Fire("Deselected")
			self:refresh()
		end
	end)
	
	-- Call icon added
	Icon.iconAdded:Fire(self)

	return self
end



-- METHODS
function Icon:setName(name)
	self.widget.Name = name
	self.name = name
	return self
end

function Icon:setState(incomingStateName, fromSource, sourceIcon)
	-- This is responsible for acknowleding a change in stage (such as from "Deselected" to "Viewing" when
	-- a users mouse enters the widget), then informing other systems of this state change to then act upon
	-- (such as the theme handler applying the theme which corresponds to that state).
	if not incomingStateName then
		incomingStateName = (self.isSelected and "Selected") or "Deselected"
	end
	local stateName = Utility.formatStateName(incomingStateName)
	local previousStateName = self.activeState
	if previousStateName == stateName then
		return
	end
	local currentIsSelected = self.isSelected
	self.activeState = stateName
	if stateName == "Deselected" then
		self.isSelected = false
		if currentIsSelected then
			self.toggled:Fire(false, fromSource, sourceIcon)
			self.deselected:Fire(fromSource, sourceIcon)
		end
		self:_setToggleItemsVisible(false, fromSource, sourceIcon)
	elseif stateName == "Selected" then
		self.isSelected = true
		if not currentIsSelected then
			self.toggled:Fire(true, fromSource, sourceIcon)
			self.selected:Fire(fromSource, sourceIcon)
			anyIconSelected:Fire(self, fromSource, sourceIcon)
		end
		self:_setToggleItemsVisible(true, fromSource, sourceIcon)
	end
	self.stateChanged:Fire(stateName, fromSource, sourceIcon)
end

function Icon:getInstance(name)
	-- This enables us to easily retrieve instances located within the icon simply by passing its name.
	-- Every important/significant instance is named uniquely therefore this is no worry of overlap.
	-- We cache the result for more performant retrieval in the future.
	local instance = self.cachedNamesToInstances[name]
	if instance then
		return instance
	end
	local function cacheInstance(childName, child)
		local currentCache = self.cachedInstances[child]
		if not currentCache then
			local collectiveName = child:GetAttribute("Collective")
			local cachedCollective = collectiveName and self.cachedCollectives[collectiveName]
			if cachedCollective then
				table.insert(cachedCollective, child)
			end
			self.cachedNamesToInstances[childName] = child
			self.cachedInstances[child] = true
			child.Destroying:Once(function()
				self.cachedNamesToInstances[childName] = nil
				self.cachedInstances[child] = nil
			end)
		end
	end
	local widget = self.widget
	cacheInstance("Widget", widget)
	if name == "Widget" then
		return widget
	end

	local returnChild
	local function scanChildren(parentInstance)
		for _, child in pairs(parentInstance:GetChildren()) do
			local widgetUID = child:GetAttribute("WidgetUID")
			if widgetUID and widgetUID ~= self.UID then
				-- This prevents instances within other icons from being recorded
				-- (for instance when other icons are added to this icons menu)
				continue
			end
			-- If the child is a fake placeholder instance (such as dropdowns, notices, etc)
			-- then its important we scan the real original instance instead of this clone
			local realChild = Themes.getRealInstance(child)
			if realChild then
				child = realChild
			end
			-- Finally scan its children
			scanChildren(child)
			if child:IsA("GuiBase") or child:IsA("UIBase") or child:IsA("ValueBase") then
				local childName = child.Name
				cacheInstance(childName, child)
				if childName == name then
					returnChild = child
				end
			end
		end
	end
	scanChildren(widget)
	return returnChild
end

function Icon:getCollective(name)
	-- A collective is an array of instances within the Widget that have been
	-- grouped together based on a given name. This just makes it easy
	-- to act on multiple instances at once which share similar behaviours.
	-- For instance, if we want to change the icons corner size, all corner instances
	-- with the attribute "Collective" and value "WidgetCorner" could be updated
	-- instantly by doing Themes.apply(icon, "WidgetCorner", newSize)
	local collective = self.cachedCollectives[name]
	if collective then
		return collective
	end
	collective = {}
	for instance, _ in pairs(self.cachedInstances) do
		if instance:GetAttribute("Collective") == name then
			table.insert(collective, instance)
		end
	end
	self.cachedCollectives[name] = collective
	return collective
end

function Icon:getInstanceOrCollective(collectiveOrInstanceName)
	-- Similar to :getInstance but also accounts for 'Collectives', such as UICorners and returns
	-- an array of instances instead of a single instance
	local instances = {}
	local instance = self:getInstance(collectiveOrInstanceName)
	if instance then
		table.insert(instances, instance)
	end
	if #instances == 0 then
		instances = self:getCollective(collectiveOrInstanceName)
	end
	return instances
end

function Icon:getStateGroup(iconState)
	local chosenState = iconState or self.activeState
	local stateGroup = self.appearance[chosenState]
	if not stateGroup then
		stateGroup = {}
		self.appearance[chosenState] = stateGroup
	end
	return stateGroup
end

function Icon:refreshAppearance(instance, specificProperty)
	Themes.refresh(self, instance, specificProperty)
	return self
end

function Icon:refresh()
	self:refreshAppearance(self.widget)
	self.updateSize:Fire()
	return self
end

function Icon:updateParent()
	local parentIcon = Icon.getIconByUID(self.parentIconUID)
	if parentIcon then
		parentIcon.updateSize:Fire()
	end
end

function Icon:setBehaviour(collectiveOrInstanceName, property, callback, refreshAppearance)
	-- You can specify your own custom callback to handle custom logic just before
	-- an instances property is changed by using :setBehaviour()
	local key = collectiveOrInstanceName.."-"..property
	self.customBehaviours[key] = callback
	if refreshAppearance then
		local instances = self:getInstanceOrCollective(collectiveOrInstanceName)
		for _, instance in pairs(instances) do
			self:refreshAppearance(instance, property)
		end
	end
end

function Icon:modifyTheme(modifications, customModificationUID)
	local modificationUID = Themes.modify(self, modifications, customModificationUID)
	return self, modificationUID
end

function Icon:modifyChildTheme(modifications, modificationUID)
	-- Same as modifyTheme except for its children (i.e. icons
	-- within its dropdown or menu)
	self.childModifications = modifications
	self.childModificationsUID = modificationUID
	for childIconUID, _ in pairs(self.childIconsDict) do
		local childIcon = Icon.getIconByUID(childIconUID)
		childIcon:modifyTheme(modifications, modificationUID)
	end
	self.childThemeModified:Fire()
	return self
end

function Icon:removeModification(modificationUID)
	Themes.remove(self, modificationUID)
	return self
end

function Icon:removeModificationWith(instanceName, property, state)
	Themes.removeWith(self, instanceName, property, state)
	return self
end

function Icon:setTheme(theme)
	Themes.set(self, theme)
	return self
end

function Icon:setEnabled(bool)
	self.isEnabled = bool
	self.enabled = self.isEnabled
	self.widget.Visible = bool
	self:updateParent()
	return self
end

function Icon:select(fromSource, sourceIcon)
	self:setState("Selected", fromSource, sourceIcon)
	return self
end

function Icon:deselect(fromSource, sourceIcon)
	self:setState("Deselected", fromSource, sourceIcon)
	return self
end

function Icon:notify(customClearSignal, noticeId)
	-- Generates a notification which appears in the top right of the icon. Useful for example for prompting
	-- users of changes/updates within your UI such as a Catalog
	-- 'customClearSignal' is a signal object (e.g. icon.deselected) or
	-- Roblox event (e.g. Instance.new("BindableEvent").Event)
	local notice = self.notice
	if not notice then
		notice = require(elements.Notice)(self, Icon)
		self.notice = notice
	end
	self.noticeStarted:Fire(customClearSignal, noticeId)
	return self
end

function Icon:clearNotices()
	self.endNotices:Fire()
	return self
end

function Icon:disableOverlay(bool)
	self.overlayDisabled = bool
	return self
end
Icon.disableStateOverlay = Icon.disableOverlay

function Icon:setImage(imageId, iconState)
	self:modifyTheme({"IconImage", "Image", imageId, iconState})
	
	-- This code ensures icon images are preloaded if they haven't been fetched yet
	task.spawn(function()
		local newIdContent = if tonumber(imageId) then `rbxassetid://{imageId}` else imageId
		local initialAssetFetchStatus = ContentProvider:GetAssetFetchStatus(newIdContent)
	
		if initialAssetFetchStatus ~= Enum.AssetFetchStatus.Success then
			pcall(ContentProvider.PreloadAsync, ContentProvider, { newIdContent })
		end
	end)
		
	return self
end

function Icon:setLabel(text, iconState)
	self:modifyTheme({"IconLabel", "Text", text, iconState})
	return self
end

function Icon:setOrder(int, iconState)
	-- We multiply by 100 to allow for custom increments inbetween
	-- (.01, .02, etc) as LayoutOrders only support integers
	local newInt = int*100
	self:modifyTheme({"IconSpot", "LayoutOrder", newInt, iconState})
	self:modifyTheme({"Widget", "LayoutOrder", newInt, iconState})
	return self
end

function Icon:setCornerRadius(udim, iconState)
	self:modifyTheme({"IconCorners", "CornerRadius", udim, iconState})
	return self
end

function Icon:align(leftCenterOrRight, isFromParentIcon)
	-- Determines the side of the screen the icon will be ordered
	local direction = tostring(leftCenterOrRight):lower()
	if direction == "mid" or direction == "centre" then
		direction = "center"
	end
	if direction ~= "left" and direction ~= "center" and direction ~= "right" then
		direction = "left"
	end
	local screenGui = (direction == "center" and Icon.container.TopbarCentered) or Icon.container.TopbarStandard
	local holders = screenGui.Holders
	local finalDirection = string.upper(string.sub(direction, 1, 1))..string.sub(direction, 2)
	if not isFromParentIcon then
		self.originalAlignment = finalDirection
	end
	local joinedFrame = self.joinedFrame
	local alignmentHolder = holders[finalDirection]
	self.screenGui = screenGui
	self.alignmentHolder = alignmentHolder
	if not self.isDestroyed then
		self.widget.Parent = joinedFrame or alignmentHolder
	end
	self.alignment = finalDirection
	self.alignmentChanged:Fire(finalDirection)
	Icon.iconChanged:Fire(self)
	return self
end
Icon.setAlignment = Icon.align

function Icon:setLeft()
	self:setAlignment("Left")
	return self
end

function Icon:setMid()
	self:setAlignment("Center")
	return self
end

function Icon:setRight()
	self:setAlignment("Right")
	return self
end

function Icon:setWidth(offsetMinimum, iconState)
	-- This sets a minimum X offset size for the widget, useful
	-- for example if you're constantly changing the label
	-- but don't want the icon to resize every time
	self:modifyTheme({"Widget", "DesiredWidth", offsetMinimum, iconState})
	return self
end

function Icon:setImageScale(number, iconState)
	self:modifyTheme({"IconImageScale", "Value", number, iconState})
	return self
end

function Icon:setImageRatio(number, iconState)
	self:modifyTheme({"IconImageRatio", "AspectRatio", number, iconState})
	return self
end

function Icon:setTextSize(number, iconState)
	self:modifyTheme({"IconLabel", "TextSize", number, iconState})
	return self
end

function Icon:setTextFont(font, fontWeight, fontStyle, iconState)
	fontWeight = fontWeight or Enum.FontWeight.Regular
	fontStyle = fontStyle or Enum.FontStyle.Normal
	local fontFace
	local fontType = typeof(font)
	if fontType == "number" then
		fontFace = Font.fromId(font, fontWeight, fontStyle)
	elseif fontType == "EnumItem" then
		fontFace = Font.fromEnum(font)
	elseif fontType == "string" then
		if not font:match("rbxasset") then
			fontFace = Font.fromName(font, fontWeight, fontStyle)
		end
	end
	if not fontFace then
		fontFace = Font.new(font, fontWeight, fontStyle)
	end
	self:modifyTheme({"IconLabel", "FontFace", fontFace, iconState})
	return self
end

function Icon:setTextColor(Color, iconState)
	if Color == nil or Color == "" or (type(Color) ~= "userdata" or typeof(Color) ~= "Color3") then
		if Color ~= nil and Color ~= "" then
			warn("setTextColor item must be a Color3 value! Changed the color to white.")
		end
		Color = Color3.fromRGB(255, 255, 255)
	end

	self:modifyTheme({"IconLabel", "TextColor3", Color, iconState})
	return self
end

function Icon:bindToggleItem(guiObjectOrLayerCollector)
	if not guiObjectOrLayerCollector:IsA("GuiObject") and not guiObjectOrLayerCollector:IsA("LayerCollector") then
		error("Toggle item must be a GuiObject or LayerCollector!")
	end
	self.toggleItems[guiObjectOrLayerCollector] = true
	self:_updateSelectionInstances()
	return self
end

function Icon:unbindToggleItem(guiObjectOrLayerCollector)
	self.toggleItems[guiObjectOrLayerCollector] = nil
	self:_updateSelectionInstances()
	return self
end

function Icon:_updateSelectionInstances()
	-- This is to assist with controller navigation and selection
	-- It converts the value true to an array
	for guiObjectOrLayerCollector, _ in pairs(self.toggleItems) do
		local buttonInstancesArray = {}
		for _, instance in pairs(guiObjectOrLayerCollector:GetDescendants()) do
			if (instance:IsA("TextButton") or instance:IsA("ImageButton")) and instance.Active then
				table.insert(buttonInstancesArray, instance)
			end
		end
		self.toggleItems[guiObjectOrLayerCollector] = buttonInstancesArray
	end
end

function Icon:_setToggleItemsVisible(bool, fromSource, sourceIcon)
	for toggleItem, _ in pairs(self.toggleItems) do
		if not sourceIcon or sourceIcon == self or sourceIcon.toggleItems[toggleItem] == nil then
			local property = "Visible"
			if toggleItem:IsA("LayerCollector") then
				property = "Enabled"
			end
			toggleItem[property] = bool
		end
	end
end

function Icon:bindEvent(iconEventName, eventFunction)
	local event = self[iconEventName]
	assert(event and typeof(event) == "table" and event.Connect, "argument[1] must be a valid topbarplus icon event name!")
	assert(typeof(eventFunction) == "function", "argument[2] must be a function!")
	self.bindedEvents[iconEventName] = event:Connect(function(...)
		eventFunction(self, ...)
	end)
	return self
end

function Icon:unbindEvent(iconEventName)
	local eventConnection = self.bindedEvents[iconEventName]
	if eventConnection then
		eventConnection:Disconnect()
		self.bindedEvents[iconEventName] = nil
	end
	return self
end

function Icon:bindToggleKey(keyCodeEnum)
	assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
	self.bindedToggleKeys[keyCodeEnum] = true
	self.toggleKeyAdded:Fire(keyCodeEnum)
	self:setCaption("_hotkey_")
	return self
end

function Icon:unbindToggleKey(keyCodeEnum)
	assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
	self.bindedToggleKeys[keyCodeEnum] = nil
	return self
end

function Icon:call(callback, ...)
	local packedArgs = table.pack(...)
	task.spawn(function()
		callback(self, table.unpack(packedArgs))
	end)
	return self
end

function Icon:addToJanitor(callback, methodName, index)
	self.janitor:add(callback, methodName, index)
	return self
end

function Icon:lock()
	-- This disables all user inputs related to the icon (such as clicking buttons, pressing keys, etc)
	local clickRegion = self:getInstance("ClickRegion")
	clickRegion.Visible = false
	self.locked = true
	return self
end

function Icon:unlock()
	local clickRegion = self:getInstance("ClickRegion")
	clickRegion.Visible = true
	self.locked = false
	return self
end

function Icon:debounce(seconds)
	self:lock()
	task.wait(seconds)
	self:unlock()
	return self
end

function Icon:autoDeselect(bool)
	-- When set to true the icon will deselect itself automatically whenever
	-- another icon is selected
	if bool == nil then
		bool = true
	end
	self.deselectWhenOtherIconSelected = bool
	return self
end

function Icon:oneClick(bool)
	-- When set to true the icon will automatically deselect when selected, this creates
	-- the effect of a single click button
	local singleClickJanitor = self.singleClickJanitor
	singleClickJanitor:clean()
	if bool or bool == nil then
		singleClickJanitor:add(self.selected:Connect(function()
			self:deselect("OneClick", self)
		end))
	end
	self.oneClickEnabled = true
	return self
end

function Icon:setCaption(text)
	if text == "_hotkey_" and (self.captionText) then
		return self
	end
	local captionJanitor = self.captionJanitor
	self.captionJanitor:clean()
	if not text or text == "" then
		self.caption = nil
		self.captionText = nil
		return self
	end
	local caption = captionJanitor:add(require(elements.Caption)(self))
	caption:SetAttribute("CaptionText", text)
	self.caption = caption
	self.captionText = text
	return self
end

function Icon:setCaptionHint(keyCodeEnum)
	assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
	self.fakeToggleKey = keyCodeEnum
	self.fakeToggleKeyChanged:Fire(keyCodeEnum)
	self:setCaption("_hotkey_")
	return self
end

function Icon:leave()
	local joinJanitor = self.joinJanitor
	joinJanitor:clean()
	return self
end

function Icon:joinMenu(parentIcon)
	Utility.joinFeature(self, parentIcon, parentIcon.menuIcons, parentIcon:getInstance("Menu"))
	parentIcon.menuChildAdded:Fire(self)
	return self
end

function Icon:setMenu(arrayOfIcons)
	self.menuSet:Fire(arrayOfIcons)
	return self
end

function Icon:setFixedMenu(arrayOfIcons)
	self:freezeMenu(arrayOfIcons)
	self:setMenu(arrayOfIcons)
end
Icon.setFrozenMenu = Icon.setFixedMenu

function Icon:freezeMenu()
	-- A frozen menu is a menu which is permanently locked in the
	-- the selected state (with its toggle hidden)
	self:select("FrozenMenu", self)
	self:bindEvent("deselected", function(icon)
		icon:select("FrozenMenu", self)
	end)
	self:modifyTheme({"IconSpot", "Visible", false})
end

function Icon:joinDropdown(parentIcon)
	parentIcon:getDropdown()
	Utility.joinFeature(self, parentIcon, parentIcon.dropdownIcons, parentIcon:getInstance("DropdownScroller"))
	parentIcon.dropdownChildAdded:Fire(self)
	return self
end

function Icon:getDropdown()
	local dropdown = self.dropdown
	if not dropdown then
		dropdown = require(elements.Dropdown)(self)
		self.dropdown = dropdown
		self:clipOutside(dropdown)
	end
	return dropdown
end

function Icon:setDropdown(arrayOfIcons)
	self:getDropdown()
	self.dropdownSet:Fire(arrayOfIcons)
	return self
end

function Icon:clipOutside(instance)
	-- This is essential for items such as notices and dropdowns which will exceed the bounds of the widget. This is an issue
	-- because the widget must have ClipsDescendents enabled to hide items for instance when the menu is closing or opening.
	-- This creates an invisible frame which matches the size and position of the instance, then the instance is parented outside of
	-- the widget and tracks the clone to match its size and position. In order for themes, etc to work the applying system checks
	-- to see if an instance is a clone, then if it is, it applies it to the original instance instead of the clone.
	local instanceClone = Utility.clipOutside(self, instance)
	self:refreshAppearance(instance)
	return self, instanceClone
end

function Icon:setIndicator(keyCode)
	-- An indicator is a direction button prompt with an image of the given keycode. This is useful for instance
	-- with controllers to show the user what button to press to highlight the topbar. You don't need
	-- to set an indicator for controllers as this is handled internally within the Gamepad module
	local indicator = self.indicator
	if not indicator then
		indicator = self.janitor:add(require(elements.Indicator)(self, Icon))
		self.indicator = indicator
	end
	self.indicatorSet:Fire(keyCode)
end

function Icon:convertLabelToNumberSpinner(numberSpinner, callback)
	task.defer(function()
		
		local label = self:getInstance("IconLabel")
		label.Transparency = 1
		numberSpinner.Parent = label.Parent
		numberSpinner.Size = UDim2.fromScale(1, 1)
		numberSpinner.AnchorPoint = Vector2.new(0.5, 0.5)
		numberSpinner.Position = UDim2.new(0.5, 0, 0.5, 0)
		numberSpinner.TextXAlignment = Enum.TextXAlignment.Center
		numberSpinner.ClipsDescendants = false

		local propertiesToChangeLabel = {
			"FontFace",
			"BorderSizePixel",
			"BorderColor3",
			"Rotation",
			"TextStrokeTransparency",
			"TextStrokeColor3",
			"TextStrokeTransparency",
			"TextColor3",
		}
		for _, property in ipairs(propertiesToChangeLabel) do
			numberSpinner[property] = label[property]
			self:addToJanitor(label:GetPropertyChangedSignal(property):Connect(function()
				numberSpinner[property] = label[property]
			end))
		end

		local minDigits = 0
		local maxDigits = 8
		local function getSpinnerSizeAndDigitCount()
			local TotalSize = 0
			local numOfDigits = 0
			for i, child in numberSpinner.Frame:GetChildren() do
				local name = string.lower(child.Name)
				if name == "digit" then
					TotalSize += child.AbsoluteSize.X
					numOfDigits += 1
				elseif name == "prefix" or name == "suffix" or name == "comma" then
					if child.Text ~= "" then
						TotalSize += child.AbsoluteSize.X
						numOfDigits += 1
					end
				end
			end
			return TotalSize, numOfDigits
		end
		
		local function getLabelParentContainerXSize()
			local firstParent = label.Parent
			local nextParent = firstParent and firstParent.Parent
			if nextParent == nil then
				return 0
			end
			if nextParent.IconImage.Visible == true then
				return numberSpinner.Frame.AbsoluteSize.X + label.Parent.Parent.IconImage.AbsoluteSize.X
			else
				return nextParent.AbsoluteSize.X
			end
		end
		local function getNumberSpinnerXSize()
			return numberSpinner.Frame.AbsoluteSize.X
		end

		local function adjustSize()
			local totalDigitXSize, numOfDigits = getSpinnerSizeAndDigitCount()
			if numOfDigits < 18 then
				self:setLabel(numberSpinner.Value)
			end

			local NumberSpinnerXSize = getNumberSpinnerXSize()

			while totalDigitXSize < NumberSpinnerXSize and self.isDestroyed ~= true do
				task.wait(0.05)
				if numOfDigits > minDigits and numOfDigits < maxDigits then
					numberSpinner.TextSize = label.TextSize
					break
				else
					numberSpinner.TextSize += 1
				end

				NumberSpinnerXSize = getNumberSpinnerXSize()
				totalDigitXSize, numOfDigits = getSpinnerSizeAndDigitCount()
			end

			local labelParentContainerXSize = getLabelParentContainerXSize()
			while totalDigitXSize > labelParentContainerXSize and self.isDestroyed ~= true do
				task.wait(0.05)
				if numOfDigits < maxDigits and numOfDigits > minDigits then
					numberSpinner.TextSize = label.TextSize
					break
				else
					numberSpinner.TextSize -= 1
				end

				labelParentContainerXSize = getLabelParentContainerXSize()
				totalDigitXSize, numOfDigits = getSpinnerSizeAndDigitCount()
			end
		end

		self:addToJanitor(numberSpinner.Frame.ChildAdded:Connect(adjustSize))
		self:addToJanitor(numberSpinner.Frame.ChildRemoved:Connect(adjustSize))
		self:addToJanitor(self.iconAdded:Connect(function()
			task.wait(1)
			adjustSize()
		end))

		self:updateParent()

		-- This corrects text to the size of a normal label
		numberSpinner.Name = "LabelSpinner"
		numberSpinner.Prefix = "$"
		numberSpinner.Commas = true
		numberSpinner.Decimals = 0
		numberSpinner.Duration = 0.25
		numberSpinner.Value = 10
		task.wait(0.2)
		
		if typeof(callback) == "function" then
			callback()
		end
		
	end)
	return self
end



-- DESTROY/CLEANUP
function Icon:destroy()
	if self.isDestroyed then
		return
	end
	self:clearNotices()
	if self.parentIconUID then
		self:leave()
	end
	self.isDestroyed = true
	self.janitor:clean()
	Icon.iconRemoved:Fire(self)
end
Icon.Destroy = Icon.destroy

return Icon :: Types.StaticIcon


-- // GoodSignal.lua
--------------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- API:                                                                       --
--   local Signal = require(THIS MODULE)                                      --
--   local sig = Signal.new()                                                 --
--   local connection = sig:Connect(function(arg1, arg2, ...) ... end)        --
--   sig:Fire(arg1, arg2, ...)                                                --
--   connection:Disconnect()                                                  --
--   sig:DisconnectAll()                                                      --
--   local arg1, arg2, ... = sig:Wait()                                       --
--                                                                            --
-- Licence:                                                                   --
--   Licenced under the MIT licence.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--------------------------------------------------------------------------------

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be 
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread()
	-- Note: We cannot use the initial set of arguments passed to
	-- runEventHandlerInFreeThread for a call to the handler, because those
	-- arguments would stay on the stack for the duration of the thread's
	-- existence, temporarily leaking references. Without access to raw bytecode
	-- there's no way for us to clear the "..." references from the stack.
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

-- Connection class
local Connection = {}
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({
		_connected = true,
		_signal = signal,
		_fn = fn,
		_next = false,
	}, Connection)
end

function Connection:Disconnect()
	self._connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end
Connection.Destroy = Connection.Disconnect

-- Make Connection strict
setmetatable(Connection, {
	__index = function(tb, key)
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(tb, key, value)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end
})

-- Signal class
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_handlerListHead = false,
	}, Signal)
end

function Signal:Connect(fn)
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
function Signal:DisconnectAll()
	self._handlerListHead = false
end
Signal.Destroy = Signal.DisconnectAll

-- Signal:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
function Signal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item._connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
				-- Get the freeRunnerThread to the first yield
				coroutine.resume(freeRunnerThread)
			end
			task.spawn(freeRunnerThread, item._fn, ...)
		end
		item = item._next
	end
end

-- Implement Signal:Wait() in terms of a temporary connection using
-- a Signal:Connect() which disconnects itself.
function Signal:Wait()
	local waitingCoroutine = coroutine.running()
	local cn;
	cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

-- Implement Signal:Once() in terms of a connection which disconnects
-- itself before running the handler.
function Signal:Once(fn)
	local cn;
	cn = self:Connect(function(...)
		if cn._connected then
			cn:Disconnect()
		end
		fn(...)
	end)
	return cn
end

-- Make signal strict
setmetatable(Signal, {
	__index = function(tb, key)
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(tb, key, value)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end
})

return Signal

-- // Janitor.lua
--[[
-------------------------------------
This package was modified by ForeverHD.

PACKAGE MODIFICATIONS:
	1. Added pascalCase aliases for all methods
	2. Modified behaviour of :add so that it takes both objects and promises (previously only objects)
	3. Slight change to how promises are tracked
	4. Added isAnInstanceBeingDestroyed check to line 228
	5. Added 'OriginalTraceback' to help determine where an error was added to the janitor
	6. Likely some additional changes which weren't record here
	7. Removed comments as these were detected by Moonwave
-------------------------------------
--]]



-- Janitor
-- Original by Validark
-- Modifications by pobammer
-- roblox-ts support by OverHash and Validark
-- LinkToInstance fixed by Elttob.

local RunService = game:GetService("RunService")
local Heartbeat = RunService.Heartbeat
local function getPromiseReference()
	return false
end

local IndicesReference = newproxy(true)
getmetatable(IndicesReference).__tostring = function()
	return "IndicesReference"
end

local LinkToInstanceIndex = newproxy(true)
getmetatable(LinkToInstanceIndex).__tostring = function()
	return "LinkToInstanceIndex"
end

local METHOD_NOT_FOUND_ERROR = "Object %s doesn't have method %s, are you sure you want to add it? Traceback: %s"
local NOT_A_PROMISE = "Invalid argument #1 to 'Janitor:AddPromise' (Promise expected, got %s (%s))"

local Janitor = {
	IGNORE_MEMORY_DEBUG = true,
	ClassName = "Janitor";
	__index = {
		CurrentlyCleaning = true;
		[IndicesReference] = nil;
	};
}

local TypeDefaults = {
	["function"] = true;
	["Promise"] = "cancel";
	RBXScriptConnection = "Disconnect";
}

function Janitor.new()
	return setmetatable({
		CurrentlyCleaning = false;
		[IndicesReference] = nil;
	}, Janitor)
end

function Janitor.Is(Object)
	return type(Object) == "table" and getmetatable(Object) == Janitor
end

Janitor.is = Janitor.Is

function Janitor.__index:Add(Object, MethodName, Index)
	if Index then
		self:Remove(Index)

		local This = self[IndicesReference]
		if not This then
			This = {}
			self[IndicesReference] = This
		end

		This[Index] = Object
	end

	local objectType = typeof(Object)
	if objectType == "table" and string.match(tostring(Object), "Promise") then
		objectType = "Promise"
		--local status = Object:getStatus()
		--print("status =", status, status == "Rejected")
	end
	MethodName = MethodName or TypeDefaults[objectType] or "Destroy"
	if type(Object) ~= "function" and not Object[MethodName] then
		warn(string.format(METHOD_NOT_FOUND_ERROR, tostring(Object), tostring(MethodName), debug.traceback(nil :: any, 2)))
	end

	local OriginalTraceback = debug.traceback("")
	self[Object] = {MethodName, OriginalTraceback}
	return Object
end
Janitor.__index.Give = Janitor.__index.Add

-- My version of Promise has PascalCase, but I converted it to use lowerCamelCase for this release since obviously that's important to do.

function Janitor.__index:AddPromise(PromiseObject)
	local Promise = getPromiseReference()
	if Promise then
		if not Promise.is(PromiseObject) then
			error(string.format(NOT_A_PROMISE, typeof(PromiseObject), tostring(PromiseObject)))
		end
		if PromiseObject:getStatus() == Promise.Status.Started then
			local Id = newproxy(false)
			local NewPromise = self:Add(Promise.new(function(Resolve, _, OnCancel)
				if OnCancel(function()
						PromiseObject:cancel()
					end) then
					return
				end

				Resolve(PromiseObject)
			end), "cancel", Id)

			NewPromise:finallyCall(self.Remove, self, Id)
			return NewPromise
		else
			return PromiseObject
		end
	else
		return PromiseObject
	end
end
Janitor.__index.GivePromise = Janitor.__index.AddPromise

-- This will assume whether or not the object is a Promise or a regular object.
function Janitor.__index:AddObject(Object)
	local Id = newproxy(false)
	local Promise = getPromiseReference()
	if Promise and Promise.is(Object) then
		if Object:getStatus() == Promise.Status.Started then
			local NewPromise = self:Add(Promise.resolve(Object), "cancel", Id)
			NewPromise:finallyCall(self.Remove, self, Id)
			return NewPromise, Id
		else
			return Object
		end
	else
		return self:Add(Object, false, Id), Id
	end
end

Janitor.__index.GiveObject = Janitor.__index.AddObject

function Janitor.__index:Remove(Index)
	local This = self[IndicesReference]
	if This then
		local Object = This[Index]

		if Object then
			local ObjectDetail = self[Object]
			local MethodName = ObjectDetail and ObjectDetail[1]

			if MethodName then
				if MethodName == true then
					Object()
				else
					local ObjectMethod = Object[MethodName]
					if ObjectMethod then
						ObjectMethod(Object)
					end
				end

				self[Object] = nil
			end

			This[Index] = nil
		end
	end

	return self
end

function Janitor.__index:Get(Index)
	local This = self[IndicesReference]
	if This then
		return This[Index]
	end
	return nil
end

function Janitor.__index:Cleanup()
	if not self.CurrentlyCleaning then
		self.CurrentlyCleaning = nil
		for Object, ObjectDetail in next, self do
			if Object == IndicesReference then
				continue
			end

			-- Weird decision to rawset directly to the janitor in Agent. This should protect against it though.
			local TypeOf = type(Object)
			if TypeOf == "string" or TypeOf == "number" then
				self[Object] = nil
				continue
			end

			local MethodName = ObjectDetail[1]
			local OriginalTraceback = ObjectDetail[2]
			local function warnUser(warning)
				local cleanupLine = debug.traceback("", 3)--string.gsub(debug.traceback("", 3), "%c", "")
				local addedLine = OriginalTraceback
				warn("-------- Janitor Error --------".."\n"..tostring(warning).."\n"..cleanupLine..""..addedLine)
			end
			if MethodName == true then
				local success, warning = pcall(Object)
				if not success then
					warnUser(warning)
				end
			else
				local ObjectMethod = Object[MethodName]
				if ObjectMethod then
					local success, warning = pcall(ObjectMethod, Object)
					local isAnInstanceBeingDestroyed = typeof(Object) == "Instance" and ObjectMethod == "Destroy"
					if not success and not isAnInstanceBeingDestroyed then
						warnUser(warning)
					end
				end
			end

			self[Object] = nil
		end

		local This = self[IndicesReference]
		if This then
			for Index in next, This do
				This[Index] = nil
			end

			self[IndicesReference] = {}
		end

		self.CurrentlyCleaning = false
	end
end

Janitor.__index.Clean = Janitor.__index.Cleanup

function Janitor.__index:Destroy()
	self:Cleanup()
	--table.clear(self)
	--setmetatable(self, nil)
end

Janitor.__call = Janitor.__index.Cleanup

local Disconnect = {Connected = true}
Disconnect.__index = Disconnect
function Disconnect:Disconnect()
	if self.Connected then
		self.Connected = false
		self.Connection:Disconnect()
	end
end

function Disconnect:__tostring()
	return "Disconnect<" .. tostring(self.Connected) .. ">"
end

function Janitor.__index:LinkToInstance(Object, AllowMultiple)
	local Connection
	local IndexToUse = AllowMultiple and newproxy(false) or LinkToInstanceIndex
	local IsNilParented = Object.Parent == nil
	local ManualDisconnect = setmetatable({}, Disconnect)

	local function ChangedFunction(_DoNotUse, NewParent)
		if ManualDisconnect.Connected then
			_DoNotUse = nil
			IsNilParented = NewParent == nil

			if IsNilParented then
				coroutine.wrap(function()
					Heartbeat:Wait()
					if not ManualDisconnect.Connected then
						return
					elseif not Connection.Connected then
						self:Cleanup()
					else
						while IsNilParented and Connection.Connected and ManualDisconnect.Connected do
							Heartbeat:Wait()
						end

						if ManualDisconnect.Connected and IsNilParented then
							self:Cleanup()
						end
					end
				end)()
			end
		end
	end

	Connection = Object.AncestryChanged:Connect(ChangedFunction)
	ManualDisconnect.Connection = Connection

	if IsNilParented then
		ChangedFunction(nil, Object.Parent)
	end

	Object = nil
	return self:Add(ManualDisconnect, "Disconnect", IndexToUse)
end

function Janitor.__index:LinkToInstances(...)
	local ManualCleanup = Janitor.new()
	for _, Object in ipairs({...}) do
		ManualCleanup:Add(self:LinkToInstance(Object, true), "Disconnect")
	end

	return ManualCleanup
end

for FunctionName, Function in next, Janitor.__index do
	local NewFunctionName = string.sub(string.lower(FunctionName), 1, 1) .. string.sub(FunctionName, 2)
	Janitor.__index[NewFunctionName] = Function
end

return Janitor

-- // Widget.lua
-- I named this 'Widget' instead of 'Icon' to make a clear difference between the icon *object* and
-- the icon (aka Widget) instance.
-- This contains the core components of the icon such as the button, image, label and notice. It's
-- also responsible for handling the automatic resizing of the widget (based upon image visibility and text length)

return function(icon, Icon)

	local widget = Instance.new("Frame")
	widget:SetAttribute("WidgetUID", icon.UID)
	widget.Name = "Widget"
	widget.BackgroundTransparency = 1
	widget.Visible = true
	widget.ZIndex = 20
	widget.Active = false
	widget.ClipsDescendants = true

	local button = Instance.new("Frame")
	button.Name = "IconButton"
	button.Visible = true
	button.ZIndex = 2
	button.BorderSizePixel = 0
	button.Parent = widget
	button.ClipsDescendants = true
	button.Active = false -- This is essential for mobile scrollers to work when dragging
	icon.deselected:Connect(function()
		button.ClipsDescendants = true
		task.delay(0.2, function()
			if icon.isSelected then
				button.ClipsDescendants = false
			end
		end)
	end)

	-- Account for PreferredTransparency which can be set by every player
	local GuiService = game:GetService("GuiService")
	icon:setBehaviour("IconButton", "BackgroundTransparency", function(value)
		local preference = GuiService.PreferredTransparency
		local newValue = value * preference
		if value == 1 then
			return value
		end
		return newValue
	end)
	icon.janitor:add(GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
		icon:refreshAppearance(button, "BackgroundTransparency")
	end))

	local iconCorner = Instance.new("UICorner")
	iconCorner:SetAttribute("Collective", "IconCorners")
	iconCorner.Name = "UICorner"
	iconCorner.Parent = button

	local menu = require(script.Parent.Menu)(icon)
	local menuUIListLayout = menu.MenuUIListLayout
	local menuGap = menu.MenuGap
	menu.Parent = button

	local iconSpot = Instance.new("Frame")
	iconSpot.Name = "IconSpot"
	iconSpot.BackgroundColor3 = Color3.fromRGB(225, 225, 225)
	iconSpot.BackgroundTransparency = 0.9
	iconSpot.Visible = true
	iconSpot.AnchorPoint = Vector2.new(0, 0.5)
	iconSpot.ZIndex = 5
	iconSpot.Parent = menu

	local iconSpotCorner = iconCorner:Clone()
	iconSpotCorner.Parent = iconSpot

	local overlay = iconSpot:Clone()
	overlay.UICorner.Name = "OverlayUICorner"
	overlay.Name = "IconOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.ZIndex = iconSpot.ZIndex + 1
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.AnchorPoint = Vector2.new(0, 0)
	overlay.Visible = false
	overlay.Parent = iconSpot

	local clickRegion = Instance.new("TextButton")
	clickRegion:SetAttribute("CorrespondingIconUID", icon.UID)
	clickRegion.Name = "ClickRegion"
	clickRegion.BackgroundTransparency = 1
	clickRegion.Visible = true
	clickRegion.Text = ""
	clickRegion.ZIndex = 20
	clickRegion.Selectable = true
	clickRegion.SelectionGroup = true
	clickRegion.Parent = iconSpot
	
	local Gamepad = require(script.Parent.Parent.Features.Gamepad)
	Gamepad.registerButton(clickRegion)

	local clickRegionCorner = iconCorner:Clone()
	clickRegionCorner.Parent = clickRegion

	local contents = Instance.new("Frame")
	contents.Name = "Contents"
	contents.BackgroundTransparency = 1
	contents.Size = UDim2.fromScale(1, 1)
	contents.Parent = iconSpot

	local contentsList = Instance.new("UIListLayout")
	contentsList.Name = "ContentsList"
	contentsList.FillDirection = Enum.FillDirection.Horizontal
	contentsList.VerticalAlignment = Enum.VerticalAlignment.Center
	contentsList.SortOrder = Enum.SortOrder.LayoutOrder
	contentsList.VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly
	contentsList.Padding = UDim.new(0, 3)
	contentsList.Parent = contents

	local paddingLeft = Instance.new("Frame")
	paddingLeft.Name = "PaddingLeft"
	paddingLeft.LayoutOrder = 1
	paddingLeft.ZIndex = 5
	paddingLeft.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paddingLeft.BackgroundTransparency = 1
	paddingLeft.BorderSizePixel = 0
	paddingLeft.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paddingLeft.Parent = contents

	local paddingCenter = Instance.new("Frame")
	paddingCenter.Name = "PaddingCenter"
	paddingCenter.LayoutOrder = 3
	paddingCenter.ZIndex = 5
	paddingCenter.Size = UDim2.new(0, 0, 1, 0)
	paddingCenter.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paddingCenter.BackgroundTransparency = 1
	paddingCenter.BorderSizePixel = 0
	paddingCenter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paddingCenter.Parent = contents

	local paddingRight = Instance.new("Frame")
	paddingRight.Name = "PaddingRight"
	paddingRight.LayoutOrder = 5
	paddingRight.ZIndex = 5
	paddingRight.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paddingRight.BackgroundTransparency = 1
	paddingRight.BorderSizePixel = 0
	paddingRight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paddingRight.Parent = contents

	local iconLabelContainer = Instance.new("Frame")
	iconLabelContainer.Name = "IconLabelContainer"
	iconLabelContainer.LayoutOrder = 4
	iconLabelContainer.ZIndex = 3
	iconLabelContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconLabelContainer.Size = UDim2.new(0, 0, 0.5, 0)
	iconLabelContainer.BackgroundTransparency = 1
	iconLabelContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconLabelContainer.Parent = contents

	local iconLabel = Instance.new("TextLabel")
	local viewportX = workspace.CurrentCamera.ViewportSize.X+200
	iconLabel.Name = "IconLabel"
	iconLabel.LayoutOrder = 4
	iconLabel.ZIndex = 15
	iconLabel.AnchorPoint = Vector2.new(0, 0)
	iconLabel.Size = UDim2.new(0, viewportX, 1, 0)
	iconLabel.ClipsDescendants = false
	iconLabel.BackgroundTransparency = 1
	iconLabel.Position = UDim2.fromScale(0, 0)
	iconLabel.RichText = true
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Left
	iconLabel.Text = ""
	iconLabel.TextWrapped = true
	iconLabel.TextWrap = true
	iconLabel.TextScaled = false
	iconLabel.Active = false
	iconLabel.AutoLocalize = true
	iconLabel.Parent = iconLabelContainer

	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "IconImage"
	iconImage.LayoutOrder = 2
	iconImage.ZIndex = 15
	iconImage.AnchorPoint = Vector2.new(0, 0.5)
	iconImage.Size = UDim2.new(0, 0, 0.5, 0)
	iconImage.BackgroundTransparency = 1
	iconImage.Position = UDim2.new(0, 11, 0.5, 0)
	iconImage.ScaleType = Enum.ScaleType.Stretch
	iconImage.Active = false
	iconImage.Parent = contents

	local iconImageCorner = iconCorner:Clone()
	iconImageCorner:SetAttribute("Collective", nil)
	iconImageCorner.CornerRadius = UDim.new(0, 0)
	iconImageCorner.Name = "IconImageCorner"
	iconImageCorner.Parent = iconImage

	local TweenService = game:GetService("TweenService")
	local resizingCount = 0
	local function handleLabelAndImageChangesUnstaggered(forceUpdateString)

		-- We defer changes by a frame to eliminate all but 1 requests which
		-- could otherwise stack up to 20+ requests in a single frame
		-- We then repeat again once to account for any final changes
		-- Deferring is also essential because properties are set immediately
		-- afterwards (therefore calculations will use the correct values)
		task.defer(function()
			local indicator = icon.indicator
			local usingIndicator = indicator and indicator.Visible
			local usingText = usingIndicator or iconLabel.Text ~= ""
			local usingImage = iconImage.Image ~= "" and iconImage.Image ~= nil
			local _alignment = Enum.HorizontalAlignment.Center
			local NORMAL_BUTTON_SIZE = UDim2.fromScale(1, 1)
			local buttonSize = NORMAL_BUTTON_SIZE
			if usingImage and not usingText then
				iconLabelContainer.Visible = false
				iconImage.Visible = true
				paddingLeft.Visible = false
				paddingCenter.Visible = false
				paddingRight.Visible = false
			elseif not usingImage and usingText then
				iconLabelContainer.Visible = true
				iconImage.Visible = false
				paddingLeft.Visible = true
				paddingCenter.Visible = false
				paddingRight.Visible = true
			elseif usingImage and usingText then
				iconLabelContainer.Visible = true
				iconImage.Visible = true
				paddingLeft.Visible = true
				paddingCenter.Visible = not usingIndicator
				paddingRight.Visible = not usingIndicator
				_alignment = Enum.HorizontalAlignment.Left
			end
			button.Size = buttonSize

			local function getItemWidth(item)
				local targetWidth = item:GetAttribute("TargetWidth") or item.AbsoluteSize.X
				return targetWidth
			end
			local contentsPadding = contentsList.Padding.Offset
			local initialWidgetWidth = contentsPadding --0
			local textWidth = iconLabel.TextBounds.X
			iconLabelContainer.Size = UDim2.new(0, textWidth, iconLabel.Size.Y.Scale, 0)
			for _, child in pairs(contents:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible == true then
					local itemWidth = getItemWidth(child)
					initialWidgetWidth += itemWidth + contentsPadding
				end
			end
			local widgetMinimumWidth = widget:GetAttribute("MinimumWidth")
			local widgetMinimumHeight = widget:GetAttribute("MinimumHeight")
			local widgetBorderSize = widget:GetAttribute("BorderSize")
			local widgetWidth = math.clamp(initialWidgetWidth, widgetMinimumWidth, viewportX)
			local menuIcons = icon.menuIcons
			local additionalWidth = 0
			local hasMenu = #menuIcons > 0
			local showMenu = hasMenu and icon.isSelected
			if showMenu then
				for _, frame in pairs(menu:GetChildren()) do
					if frame ~= iconSpot and frame:IsA("GuiObject") and frame.Visible then
						additionalWidth += getItemWidth(frame) + menuUIListLayout.Padding.Offset
					end
				end
				if not iconSpot.Visible then
					widgetWidth -= (getItemWidth(iconSpot) + menuUIListLayout.Padding.Offset*2 + widgetBorderSize)
				end
				additionalWidth -= (widgetBorderSize*0.5)
				widgetWidth += additionalWidth - (widgetBorderSize*0.75)
			end
			menuGap.Visible = showMenu and iconSpot.Visible
			local desiredWidth = widget:GetAttribute("DesiredWidth")
			if desiredWidth and widgetWidth < desiredWidth then
				widgetWidth = desiredWidth
			end

			icon.updateMenu:Fire()
			local preWidth = math.max(widgetWidth-additionalWidth, widgetMinimumWidth)
			local spotWidth = preWidth-(widgetBorderSize*2)
			local menuWidth = menu:GetAttribute("MenuWidth")
			local totalMenuWidth = menuWidth and menuWidth + spotWidth + menuUIListLayout.Padding.Offset + 10
			if totalMenuWidth then
				local maxWidth = menu:GetAttribute("MaxWidth")
				if maxWidth then
					totalMenuWidth = math.max(maxWidth, widgetMinimumWidth)
				end
				menu:SetAttribute("MenuCanvasWidth", widgetWidth)
				if totalMenuWidth < widgetWidth then
					widgetWidth = totalMenuWidth
				end
			end

			local style = Enum.EasingStyle.Quint
			local direction = Enum.EasingDirection.Out
			local spotWidthMax = math.max(spotWidth, getItemWidth(iconSpot), iconSpot.AbsoluteSize.X)
			local widgetWidthMax = math.max(widgetWidth, getItemWidth(widget), widget.AbsoluteSize.X)
			local SPEED = 750
			local spotTweenInfo = TweenInfo.new(spotWidthMax/SPEED, style, direction)
			local widgetTweenInfo = TweenInfo.new(widgetWidthMax/SPEED, style, direction)
			TweenService:Create(iconSpot, spotTweenInfo, {
				Position = UDim2.new(0, widgetBorderSize, 0.5, 0),
				Size = UDim2.new(0, spotWidth, 1, -widgetBorderSize*2),
			}):Play()
			TweenService:Create(clickRegion, spotTweenInfo, {
				Size = UDim2.new(0, spotWidth, 1, 0),
			}):Play()
			local newWidgetSize = UDim2.fromOffset(widgetWidth, widgetMinimumHeight)
			local updateInstantly = widget.Size.Y.Offset ~= widgetMinimumHeight
			if updateInstantly then
				widget.Size = newWidgetSize
			end
			widget:SetAttribute("TargetWidth", newWidgetSize.X.Offset)
			local movingTween = TweenService:Create(widget, widgetTweenInfo, {
				Size = newWidgetSize,
			})
			movingTween:Play()
			resizingCount += 1
			for i = 1, widgetTweenInfo.Time * 100 do
				task.delay(i/100, function()
					Icon.iconChanged:Fire(icon)
				end)
			end
			task.delay(widgetTweenInfo.Time-0.2, function()
				resizingCount -= 1
				task.defer(function()
					if resizingCount == 0 then
						icon.resizingComplete:Fire()
					end
				end)
			end)
			icon:updateParent()
		end)
	end
	local Utility = require(script.Parent.Parent.Utility)
	local handleLabelAndImageChanges = Utility.createStagger(0.01, handleLabelAndImageChangesUnstaggered)
	local firstTimeSettingFontFace = true
	icon:setBehaviour("IconLabel", "Text", handleLabelAndImageChanges)
	icon:setBehaviour("IconLabel", "FontFace", function(value)
		local previousFontFace = iconLabel.FontFace
		if previousFontFace == value then
			return
		end
		task.spawn(function()
			--[[
			local fontLink = value.Family
			if string.match(fontLink, "rbxassetid://") then
				local ContentProvider = game:GetService("ContentProvider")
				local assets = {fontLink}
				ContentProvider:PreloadAsync(assets)
			end--]]

			-- Afaik there's no way to determine when a Font Family has
			-- loaded (even with ContentProvider), so we just have to try
			-- a few times and hope it loads within the refresh period
			handleLabelAndImageChanges()
			if firstTimeSettingFontFace then
				firstTimeSettingFontFace = false
				for i = 1, 10 do
					task.wait(1)
					handleLabelAndImageChanges()
				end
			end
		end)
	end)
	local function updateBorderSize()
		task.defer(function()
			local borderOffset = widget:GetAttribute("BorderSize")
			local alignment = icon.alignment
			local alignmentOffset = (iconSpot.Visible == false and 0) or (alignment == "Right" and -borderOffset) or borderOffset
			menu.Position = UDim2.new(0, alignmentOffset, 0, 0)
			menuGap.Size = UDim2.fromOffset(borderOffset, 0)
			menuUIListLayout.Padding = UDim.new(0, 0)
			handleLabelAndImageChanges()
		end)
	end
	icon:setBehaviour("Widget", "BorderSize", updateBorderSize)
	icon:setBehaviour("IconSpot", "Visible", updateBorderSize)
	icon.startMenuUpdate:Connect(handleLabelAndImageChanges)
	icon.updateSize:Connect(handleLabelAndImageChanges)
	icon:setBehaviour("ContentsList", "HorizontalAlignment", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "Visible", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "DesiredWidth", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "MinimumWidth", handleLabelAndImageChanges)
	icon:setBehaviour("Widget", "MinimumHeight", handleLabelAndImageChanges)
	icon:setBehaviour("Indicator", "Visible", handleLabelAndImageChanges)
	icon:setBehaviour("IconImageRatio", "AspectRatio", handleLabelAndImageChanges)
	icon:setBehaviour("IconImage", "Image", function(value)
		local textureId = (tonumber(value) and "http://www.roblox.com/asset/?id="..value) or value or ""
		if iconImage.Image ~= textureId then
			handleLabelAndImageChanges()
		end
		return textureId
	end)
	icon.alignmentChanged:Connect(function(newAlignment)
		if newAlignment == "Center" then
			newAlignment = "Left"
		end
		menuUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment[newAlignment]
		updateBorderSize()
	end)

	-- Localization support (refresh icon size whenever player changes language changes in-game)
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local lastLocaleId = localPlayer.LocaleId
	icon.janitor:add(localPlayer:GetPropertyChangedSignal("LocaleId"):Connect(function()
		task.delay(0.2, function()
			local newLocaleId = localPlayer.LocaleId
			if newLocaleId ~= lastLocaleId then
				lastLocaleId = newLocaleId
				icon:refresh()
				task.wait(0.5)
				icon:refresh()
			end
		end)
	end))
	
	local iconImageScale = Instance.new("NumberValue")
	iconImageScale.Name = "IconImageScale"
	iconImageScale.Parent = iconImage
	iconImageScale:GetPropertyChangedSignal("Value"):Connect(function()
		iconImage.Size = UDim2.new(iconImageScale.Value, 0, iconImageScale.Value, 0)
	end)

	local UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	UIAspectRatioConstraint.Name = "IconImageRatio"
	UIAspectRatioConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
	UIAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
	UIAspectRatioConstraint.Parent = iconImage

	local iconGradient = Instance.new("UIGradient")
	iconGradient.Name = "IconGradient"
	iconGradient.Enabled = true
	iconGradient.Parent = button

	local iconSpotGradient = Instance.new("UIGradient")
	iconSpotGradient.Name = "IconSpotGradient"
	iconSpotGradient.Enabled = true
	iconSpotGradient.Parent = iconSpot

	return widget
end

-- // Utility.lua
-- Just generic utility functions which I use and repeat across all my projects



-- LOCAL
local Utility = {}
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer



-- FUNCTIONS
function Utility.createStagger(delayTime, callback, delayInitially)
	-- This creates and returns a function which when called
	-- acts identically to callback, however will only be called
	-- for a maximum of once per delayTime. If the returned function
	-- is called more than once during the delayTime, then it will
	-- wait until the expiryTime then perform another recall.
	-- This is useful for visual interfaces and effects which may be
	-- triggered multiple times within a frame or short period, but which
	-- we don't necessary need to (for performance reasons).
	local staggerActive = false
	local multipleCalls = false
	if not delayTime or delayTime == 0 then
		-- We make 0.01 instead of 0 because devices can now run at
		-- different frame rates
		delayTime = 0.01
	end
	local function staggeredCallback(...)
		if staggerActive then
			multipleCalls = true
			return
		end
		local packedArgs = table.pack(...)
		staggerActive = true
		multipleCalls = false
		task.spawn(function()
			if delayInitially then
				task.wait(delayTime)
			end
			callback(table.unpack(packedArgs))
		end)
		task.delay(delayTime, function()
			staggerActive = false
			if multipleCalls then
				-- This means it has been called at least once during
				-- the stagger period, so call again
				staggeredCallback(table.unpack(packedArgs))
			end
		end)
	end
	return staggeredCallback
end

function Utility.round(n)
	-- Credit to Darkmist101 for this
	return math.floor(n + 0.5)
end

function Utility.reverseTable(t)
	for i = 1, math.floor(#t/2) do
		local j = #t - i + 1
		t[i], t[j] = t[j], t[i]
	end
end

function Utility.copyTable(t)
	-- Credit to Stephen Leitnick (September 13, 2017) for this function from TableUtil
	assert(type(t) == "table", "First argument must be a table")
	local tCopy = table.create(#t)
	for k,v in pairs(t) do
		if (type(v) == "table") then
			tCopy[k] = Utility.copyTable(v)
		else
			tCopy[k] = v
		end
	end
	return tCopy
end

local validCharacters = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","1","2","3","4","5","6","7","8","9","0","<",">","?","@","{","}","[","]","!","(",")","=","+","~","#"}
function Utility.generateUID(length)
	length = length or 8
	local UID = ""
	local list = validCharacters
	local total = #list
	for i = 1, length do
		local randomCharacter = list[math.random(1, total)]
		UID = UID..randomCharacter
	end
	return UID
end

local instanceTrackers = {}
function Utility.setVisible(instance, bool, sourceUID)
	-- This effectively works like a buff object but
	-- incredibly simplified. It stacks false values
	-- so that if there is more than more than, the 
	-- instance remains hidden even if set visible true
	local tracker = instanceTrackers[instance]
	if not tracker then
		tracker = {}
		instanceTrackers[instance] = tracker
		instance.Destroying:Once(function()
			instanceTrackers[instance] = nil
		end)
	end
	if not bool then
		tracker[sourceUID] = true
	else
		tracker[sourceUID] = nil
	end
	local isVisible = bool
	if bool then
		for sourceUID, _ in pairs(tracker) do
			isVisible = false
			break
		end
	end
	instance.Visible = isVisible
end

function Utility.formatStateName(incomingStateName)
	return string.upper(string.sub(incomingStateName, 1, 1))..string.lower(string.sub(incomingStateName, 2))
end

function Utility.localPlayerRespawned(callback)
	-- The client localscript may be located under a ScreenGui with ResetOnSpawn set to true
	-- In these scenarios, traditional methods like CharacterAdded won't be called by the
	-- time the localscript has been destroyed, therefore we listen for removing instead
	-- If humanoid and health == 0, then reset/died normally, else was
	-- forcefully reset via a method such as LoadCharacter
	-- We wrap this behaviour in case any additional quirks need to be accounted for
	localPlayer.CharacterRemoving:Connect(callback)
end

function Utility.getClippedContainer(screenGui)
	-- We always want clipped items to display in front hence
	-- why we have this
	local clippedContainer = screenGui:FindFirstChild("ClippedContainer")
	if not clippedContainer then
		clippedContainer = Instance.new("Folder")
		clippedContainer.Name = "ClippedContainer"
		clippedContainer.Parent = screenGui
	end
	return clippedContainer
end

local Janitor = require(script.Parent.Packages.Janitor)
local GuiService = game:GetService("GuiService")
function Utility.clipOutside(icon, instance)
	local cloneJanitor = icon.janitor:add(Janitor.new())
	instance.Destroying:Once(function()
		cloneJanitor:Destroy()
	end)
	icon.janitor:add(instance)

	local originalParent = instance.Parent
	local clone = cloneJanitor:add(Instance.new("Frame"))
	clone:SetAttribute("IsAClippedClone", true)
	clone.Name = instance.Name
	clone.AnchorPoint = instance.AnchorPoint
	clone.Size = instance.Size
	clone.Position = instance.Position
	clone.BackgroundTransparency = 1
	clone.LayoutOrder = instance.LayoutOrder
	clone.Parent = originalParent

	local valueInstance = Instance.new("ObjectValue")
	valueInstance.Name = "OriginalInstance"
	valueInstance.Value = instance
	valueInstance.Parent = clone

	local valueInstanceCopy = valueInstance:Clone()
	instance:SetAttribute("HasAClippedClone", true)
	valueInstanceCopy.Name = "ClippedClone"
	valueInstanceCopy.Value = clone
	valueInstanceCopy.Parent = instance

	local screenGui
	local Icon = require(icon.iconModule)
	local container = Icon.container
	local function updateScreenGui()
		local originalScreenGui = originalParent:FindFirstAncestorWhichIsA("ScreenGui")
		screenGui = if string.match(originalScreenGui.Name, "Clipped") then originalScreenGui else container[originalScreenGui.Name.."Clipped"]
		instance.AnchorPoint = Vector2.new(0, 0)
		instance.Parent = Utility.getClippedContainer(screenGui)
	end
	cloneJanitor:add(icon.alignmentChanged:Connect(updateScreenGui))
	updateScreenGui()

	-- Lets copy over children that modify size
	for _, child in pairs(instance:GetChildren()) do
		if child:IsA("UIAspectRatioConstraint") then
			child:Clone().Parent = clone
		end
	end

	-- If the icon is hidden, its important we are too (as
	-- setting a parent to visible = false no longer makes
	-- this hidden)
	local widget = icon.widget
	local isOutsideParent = false
	local ignoreVisibilityUpdater = instance:GetAttribute("IgnoreVisibilityUpdater")
	local function updateVisibility()
		if ignoreVisibilityUpdater then
			return
		end
		local isVisible = widget.Visible
		if isOutsideParent then
			isVisible = false
		end
		Utility.setVisible(instance, isVisible, "ClipHandler")
	end
	cloneJanitor:add(widget:GetPropertyChangedSignal("Visible"):Connect(updateVisibility))

	local previousScroller
	local function checkIfOutsideParentXBounds()
		-- Defer so that roblox's properties reflect their true values
		task.defer(function()
			-- If the instance is within a parent item (such as a dropdown or menu)
			-- then we hide it if it exceeds the bounds of that parent
			local parentInstance
			local ourUID = icon.UID
			local nextIconUID = ourUID
			local shouldClipToParent = instance:GetAttribute("ClipToJoinedParent")
			if shouldClipToParent then
				for i = 1, 10 do -- This is safer than while true do and should never be > 4 parents
					local nextIcon = Icon.getIconByUID(nextIconUID)
					if not nextIcon then
						break
					end
					local nextParentInstance = nextIcon.joinedFrame
					nextIconUID = nextIcon.parentIconUID
					if not nextParentInstance then
						break
					end
					parentInstance = nextParentInstance
					if parentInstance and parentInstance.Name == "DropdownScroller" then
						break
					end
				end
			end
			if not parentInstance then
				isOutsideParent = false
				updateVisibility()
				return
			end
			local pos = instance.AbsolutePosition
			local halfSize = instance.AbsoluteSize/2
			local parentPos = parentInstance.AbsolutePosition
			local parentSize = parentInstance.AbsoluteSize
			local posHalf = (pos + halfSize)
			local exceededLeft = posHalf.X < parentPos.X
			local exceededRight = posHalf.X > (parentPos.X + parentSize.X)
			local exceededTop = posHalf.Y < parentPos.Y
			local exceededBottom = posHalf.Y > (parentPos.Y + parentSize.Y)
			local hasExceeded = exceededLeft or exceededRight or exceededTop or exceededBottom
			if hasExceeded ~= isOutsideParent then
				isOutsideParent = hasExceeded
				updateVisibility()
			end
			if parentInstance:IsA("ScrollingFrame") and previousScroller ~= parentInstance then
				previousScroller = parentInstance
				local connection = parentInstance:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
					checkIfOutsideParentXBounds()
				end)
				cloneJanitor:add(connection, "Disconnect", "TrackUtilityScroller-"..ourUID)
			end
		end)
	end

	local camera = workspace.CurrentCamera
	local additionalOffsetX = instance:GetAttribute("AdditionalOffsetX") or 0
	local function trackProperty(property)
		local absoluteProperty = "Absolute"..property
		local function updateProperty()
			local cloneValue = clone[absoluteProperty]
			local absoluteValue = UDim2.fromOffset(cloneValue.X, cloneValue.Y)
			if property == "Position" then

				-- This binds the instances within the bounds of the screen
				local SIDE_PADDING = 4
				local limitX = camera.ViewportSize.X - instance.AbsoluteSize.X - SIDE_PADDING
				local inputX = absoluteValue.X.Offset
				if inputX < SIDE_PADDING then
					inputX = SIDE_PADDING
				elseif inputX > limitX then
					inputX = limitX
				end
				absoluteValue = UDim2.fromOffset(inputX, absoluteValue.Y.Offset)

				-- AbsolutePosition does not perfectly match with TopbarInsets enabled
				-- This corrects this
				local topbarInset = GuiService.TopbarInset
				local viewportWidth = workspace.CurrentCamera.ViewportSize.X
				local guiWidth = screenGui.AbsoluteSize.X
				local guiOffset = screenGui.AbsolutePosition.X
				--local widthDifference = guiOffset - topbarInset.Min.X
				local oldTopbarCenterOffset = 0--widthDifference/30
				local offsetX = if Icon.isOldTopbar then guiOffset else viewportWidth - guiWidth - oldTopbarCenterOffset
				
				-- Also add additionalOffset
				offsetX -= additionalOffsetX
				absoluteValue += UDim2.fromOffset(-offsetX, topbarInset.Height)

				-- Finally check if within its direct parents bounds
				checkIfOutsideParentXBounds()

			end
			instance[property] = absoluteValue
		end
		
		-- This defer is essential as the listener may be in a different screenGui to the actor
		local updatePropertyStaggered = Utility.createStagger(0.01, updateProperty)
		cloneJanitor:add(clone:GetPropertyChangedSignal(absoluteProperty):Connect(updatePropertyStaggered))
		cloneJanitor:add(clone:GetAttributeChangedSignal("ForceUpdate"):Connect(function()
			updatePropertyStaggered()
		end))

		-- This is to patch a weirddddd bug with ScreenGuis with SreenInsets set to
		-- 'TopbarSafeInsets'. For some reason the absolute position of gui instances
		-- within this type of screenGui DO NOT accurately update to match their new
		-- real world position; instead they jump around almost randomly for a few frames.
		-- I have spent way too many hours trying to solve this bug, I think the only way
		-- for the time being is to not use ScreenGuis with TopbarSafeInsets, but I don't
		-- have time to redesign the entire system around that at the moment.
		-- Here's a GIF of this bug: https://i.imgur.com/VitHdC1.gif
		local updatePropertyPatch = Utility.createStagger(0.5, updateProperty, true)
		cloneJanitor:add(clone:GetPropertyChangedSignal(absoluteProperty):Connect(updatePropertyPatch))
		
		-- When the screenGui is resized (such as when chat is hidden/shown), we need
		-- to update the position of the clone. Ths especially fixes the following:
		-- https://devforum.roblox.com/t/bug/1017485/1732
		if property == "Position" then
			cloneJanitor:add(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				updatePropertyStaggered()
			end))
		end

	end
	task.delay(0.1, checkIfOutsideParentXBounds)
	checkIfOutsideParentXBounds()
	updateVisibility()
	trackProperty("Position")
	
	-- Track visiblity changes
	cloneJanitor:add(instance:GetPropertyChangedSignal("Visible"):Connect(function()
		--print("Visiblity changed:", instance, clone, instance.Visible)
		--clone.Visible = instance.Visible
	end))

	-- To ensure accurate positioning, it's important the clone also remains the same size as the instance
	local shouldTrackCloneSize = instance:GetAttribute("TrackCloneSize")
	if shouldTrackCloneSize then
		trackProperty("Size")
	else
		cloneJanitor:add(instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local absolute = instance.AbsoluteSize
			clone.Size = UDim2.fromOffset(absolute.X, absolute.Y)
		end))
	end

	return clone
end

function Utility.joinFeature(originalIcon, parentIcon, iconsArray, scrollingFrameOrFrame)

	-- This is resonsible for moving the icon under a feature like a dropdown
	local joinJanitor = originalIcon.joinJanitor
	joinJanitor:clean()
	if not scrollingFrameOrFrame then
		originalIcon:leave()
		return
	end
	originalIcon.parentIconUID = parentIcon.UID
	originalIcon.joinedFrame = scrollingFrameOrFrame
	local function updateAlignent()
		local parentAlignment = parentIcon.alignment
		if parentAlignment == "Center" then
			parentAlignment = "Left"
		end
		originalIcon:setAlignment(parentAlignment, true)
	end
	joinJanitor:add(parentIcon.alignmentChanged:Connect(updateAlignent))
	updateAlignent()
	originalIcon:modifyTheme({"IconButton", "BackgroundTransparency", 1}, "JoinModification")
	originalIcon:modifyTheme({"ClickRegion", "Active", false}, "JoinModification")
	if parentIcon.childModifications then
		-- We defer so that the default values (such as dropdown
		-- minimum width can be applied before any custom
		-- child modifications from the user)
		task.defer(function()
			originalIcon:modifyTheme(parentIcon.childModifications, parentIcon.childModificationsUID)
		end)
	end
	--
	local clickRegion = originalIcon:getInstance("ClickRegion")
	local function makeSelectable()
		clickRegion.Selectable = parentIcon.isSelected
	end
	joinJanitor:add(parentIcon.toggled:Connect(makeSelectable))
	task.defer(makeSelectable)
	joinJanitor:add(function()
		clickRegion.Selectable = true
	end)
	--

	-- We track icons in arrays and dictionaries using their UID instead of the icon
	-- itself to prevent heavy cyclical tables when printing the icons
	local originalIconUID = originalIcon.UID
	table.insert(iconsArray, originalIconUID)
	parentIcon:autoDeselect(false)
	parentIcon.childIconsDict[originalIconUID] = true
	if not parentIcon.isEnabled then
		parentIcon:setEnabled(true)
	end
	originalIcon.joinedParent:Fire(parentIcon)

	-- This is responsible for removing it from that feature and updating
	-- their parent icon so its informed of the icon leaving it
	joinJanitor:add(function()
		local joinedFrame = originalIcon.joinedFrame
		if not joinedFrame then
			return
		end
		for i, iconUID in pairs(iconsArray) do
			if iconUID == originalIconUID then
				table.remove(iconsArray, i)
				break
			end
		end
		local Icon = require(originalIcon.iconModule)
		local parentIcon = Icon.getIconByUID(originalIcon.parentIconUID)
		if not parentIcon then
			return
		end
		originalIcon:setAlignment(originalIcon.originalAlignment)
		originalIcon.parentIconUID = false
		originalIcon.joinedFrame = false
		--originalIcon:setBehaviour("IconButton", "BackgroundTransparency", nil, true)
		originalIcon:removeModification("JoinModification")
		
		local parentHasNoChildren = true
		local parentChildIcons = parentIcon.childIconsDict
		parentChildIcons[originalIconUID] = nil
		for childIconUID, _ in pairs(parentChildIcons) do
			parentHasNoChildren = false
			break
		end
		if parentHasNoChildren and not parentIcon.isAnOverflow then
			parentIcon:setEnabled(false)
		end
		updateAlignent()

	end)

end



return Utility

-- // init(1).lua
-- The functions here are dedicated solely to managing theme state
-- and updating the appearance of instances to match that state.
-- You don't need to use any of these functions, the useful ones
-- have been abstracted as icon methods



-- LOCAL
local Themes = {}
local Utility = require(script.Parent.Parent.Utility)
local baseTheme = require(script.Default)



-- FUNCTIONS
function Themes.getThemeValue(stateGroup, instanceName, property, iconState)
	if stateGroup then
		for _, detail in pairs(stateGroup) do
			local checkingInstanceName, checkingPropertyName, checkingValue = unpack(detail)
			if instanceName == checkingInstanceName and property == checkingPropertyName then
				return checkingValue
			end
		end
	end
	return nil
end

function Themes.getInstanceValue(instance, property)
	local success, value = pcall(function()
		return instance[property]
	end)
	if not success then
		value = instance:GetAttribute(property)
	end
	return value
end

function Themes.getRealInstance(instance)
	if not instance:GetAttribute("IsAClippedClone") then
		return
	end
	local originalInstance = instance:FindFirstChild("OriginalInstance")
	if not originalInstance then
		return
	end
	return originalInstance.Value
end

function Themes.getClippedClone(instance)
	if not instance:GetAttribute("HasAClippedClone") then
		return
	end
	local clippedClone = instance:FindFirstChild("ClippedClone")
	if not clippedClone then
		return
	end
	return clippedClone.Value
end

function Themes.refresh(icon, instance, specificProperty)
	-- Some instances such as notices need immediate refreshing upon creation as
	-- they're added in after the initial refresh period
	if specificProperty then
		local stateGroup = icon:getStateGroup()
		local value = Themes.getThemeValue(stateGroup, instance.Name, specificProperty) or Themes.getInstanceValue(instance, specificProperty)
		Themes.apply(icon, instance, specificProperty, value, true)
		return
	end
	-- If no property is specified we update all properties that exist within
	-- the applied theme appearance
	local stateGroup = icon:getStateGroup()
	if not stateGroup then
		return
	end
	local validInstances = {[instance.Name] = instance}
	for _, child in pairs(instance:GetDescendants()) do
		local collective = child:GetAttribute("Collective")
		if collective then
			validInstances[collective] = child
		end
		validInstances[child.Name] = child
	end
	for _, detail in pairs(stateGroup) do
		local checkingInstanceName, checkingPropertyName, checkingValue = unpack(detail)
		local instanceToUpdate = validInstances[checkingInstanceName]
		if instanceToUpdate then
			Themes.apply(icon, instanceToUpdate.Name, checkingPropertyName, checkingValue, true)
		end
	end
	return
end

function Themes.apply(icon, collectiveOrInstanceNameOrInstance, property, value, forceApply)
	-- This is responsible for **applying** appearance changes to instances within the icon
	-- however it IS NOT responsible for updating themes. Use :modifyTheme for that.
	-- This also calls callbacks given by :setBehaviour before applying these property changes
	-- to the given instances
	if icon.isDestroyed then
		return
	end
	local instances
	local collectiveOrInstanceName = collectiveOrInstanceNameOrInstance
	if typeof(collectiveOrInstanceNameOrInstance) == "Instance" then
		instances = {collectiveOrInstanceNameOrInstance}
		collectiveOrInstanceName = collectiveOrInstanceNameOrInstance.Name
	else
		instances = icon:getInstanceOrCollective(collectiveOrInstanceNameOrInstance)
	end
	local key = collectiveOrInstanceName.."-"..property
	local customBehaviour = icon.customBehaviours[key]
	for _, instance in pairs(instances) do
		local clippedClone = Themes.getClippedClone(instance)
		if clippedClone then
			-- This means theme effects are applied to both the original
			-- instance and its clone (instead of just the instance).
			-- This is important for some properties such as position
			-- and size which might be dictated by the clone
			table.insert(instances, clippedClone)
		end
	end
	for _, instance in pairs(instances) do
		if property == "Position" and Themes.getClippedClone(instance) then
			-- The clone manages the position of the real instance so ignore
			continue
		elseif property == "Size" and Themes.getRealInstance(instance) then
			-- The real instance manages the size of the clone so ignore
			continue
		end
		local currentValue = Themes.getInstanceValue(instance, property)
		if not forceApply and value == currentValue then
			continue
		end
		if customBehaviour then
			local newValue = customBehaviour(value, instance, property)
			if newValue ~= nil then
				value = newValue
			end
		end
		local success = pcall(function()
			instance[property] = value
		end)
		if not success then
			-- If property is not a real property, we set
			-- the value as an attribute instead. This is useful
			-- for instance in :setWidth where we also want to
			-- specify a desired width for every state which can
			-- then be easily read by the widget element
			instance:SetAttribute(property, value)
		end
	end
end

function Themes.getModifications(modifications)
	if typeof(modifications[1]) ~= "table" then
		-- This enables users to do :modifyTheme({a,b,c,d})
		-- in addition of :modifyTheme({{a,b,c,d}})
		modifications = {modifications}
	end
	return modifications
end

function Themes.merge(detail, modification, callback)
	local instanceName, property, value, stateName = table.unpack(modification)
	local checkingInstanceName, checkingPropertyName, _, checkingStateName = table.unpack(detail)
	if instanceName == checkingInstanceName and property == checkingPropertyName and Themes.statesMatch(stateName, checkingStateName) then
		detail[3] = value
		if callback then
			callback(detail)
		end
		return true
	end
	return false
end

function Themes.modify(icon, modifications, modificationsUID)
	-- This is what the 'old set' used to do (although for clarity that behaviour has now been
	-- split into two methods, .modifyTheme and .apply).
	-- modifyTheme is responsible for UPDATING the internal values within a theme for a particular
	-- state, then checking to see if the appearance of the icon needs to be updated.
	-- If no iconState is specified, the change is applied to both Deselected and Selected
	-- A modification can also be 'undone' using :removeModification and passing in
	-- the UID returned from this method
	task.spawn(function()
		modificationsUID = modificationsUID or Utility.generateUID()
		modifications = Themes.getModifications(modifications)
		for _, modification in pairs(modifications) do
			local instanceName, property, value, iconState = table.unpack(modification)
			if iconState == nil then
				-- If no state specified, apply to all states
				Themes.modify(icon, {instanceName, property, value, "Selected"}, modificationsUID)
				Themes.modify(icon, {instanceName, property, value, "Viewing"}, modificationsUID)
			end
			local chosenState = Utility.formatStateName(iconState or "Deselected")
			local stateGroup = icon:getStateGroup(chosenState)
			local function nowSetIt()
				if chosenState == icon.activeState then
					Themes.apply(icon, instanceName, property, value)
				end
			end
			local function updateRecord()
				for stateName, detail in pairs(stateGroup) do
					local didMerge = Themes.merge(detail, modification, function(detail)
						detail[5] = modificationsUID
						nowSetIt()
					end)
					if didMerge then
						return
					end
				end
				local detail = {instanceName, property, value, chosenState, modificationsUID}
				table.insert(stateGroup, detail)
				nowSetIt()
			end
			updateRecord()
		end
	end)
	return modificationsUID
end

function Themes.remove(icon, modificationsUID)
	for iconState, stateGroup in pairs(icon.appearance) do
		for i = #stateGroup, 1, -1 do
			local detail = stateGroup[i]
			local checkingUID = detail[5]
			if checkingUID == modificationsUID then
				table.remove(stateGroup, i)
			end
		end
	end
	Themes.rebuild(icon)
end

function Themes.removeWith(icon, instanceName, property, state)
	for iconState, stateGroup in pairs(icon.appearance) do
		if state == iconState or not state then
			for i = #stateGroup, 1, -1 do
				local detail = stateGroup[i]
				local detailName = detail[1]
				local detailProperty = detail[2]
				if detailName == instanceName and detailProperty == property then
					table.remove(stateGroup, i)
				end
			end
		end
	end
	Themes.rebuild(icon)
end

function Themes.change(icon)
	-- This changes the theme to the appearance of whatever
	-- state is currently active
	local stateGroup = icon:getStateGroup()
	for _, detail in pairs(stateGroup) do
		local instanceName, property, value = unpack(detail)
		Themes.apply(icon, instanceName, property, value)
	end
end

function Themes.set(icon, theme)
	-- This is responsible for processing the final appearance of a given theme (such as
	-- ensuring Deselected merge into missing Selected, saving that internal state,
	-- then checking to see if the appearance of the icon needs to be updated
	local themesJanitor = icon.themesJanitor
	themesJanitor:clean()
	themesJanitor:add(icon.stateChanged:Connect(function()
		Themes.change(icon)
	end))
	if typeof(theme) == "Instance" and theme:IsA("ModuleScript") then
		theme = require(theme)
	end
	icon.appliedTheme = theme
	Themes.rebuild(icon)
end

function Themes.statesMatch(state1, state2)
	-- States match if they have the same name OR if nil (because unspecified represents all states)
	local state1lower = (state1 and string.lower(state1))
	local state2lower = (state2 and string.lower(state2))
	return state1lower == state2lower or not state1 or not state2
end

function Themes.rebuild(icon)
	-- A note for my future self: this code can be optimised further by
	-- converting appearance into a instanceName-property dictionary
	-- as apposed to an array of every potential change. When converting
	-- in the future, .modify and .apply would also have to be updated.
	local appliedTheme = icon.appliedTheme
	local statesArray = {"Deselected", "Selected", "Viewing"}
	local function generateTheme()
		for _, stateName in pairs(statesArray) do
			-- This applies themes in layers
			-- The last layers take higher priority as they overwrite
			-- any duplicate earlier applied effects
			local stateAppearance = {}
			local function updateDetails(theme, incomingStateName)
				-- This ensures there's always a base 'default' layer
				if not theme then
					return
				end
				for _, detail in pairs(theme) do
					local modificationsUID = detail[5]
					local detailStateName = detail[4]
					if Themes.statesMatch(incomingStateName, detailStateName) then
						local key = detail[1].."-"..detail[2]
						local newDetail = Utility.copyTable(detail)
						newDetail[5] = modificationsUID
						stateAppearance[key] = newDetail
					end
				end
			end
			-- First we apply the base theme (i.e. the Default module)
			if stateName == "Selected" then
				updateDetails(baseTheme, "Deselected")
			end
			updateDetails(baseTheme, "Empty")
			updateDetails(baseTheme, stateName)
			-- Next we apply any custom themes by the games developer
			if appliedTheme ~= baseTheme then
				if stateName == "Selected" then
					updateDetails(appliedTheme, "Deselected")
				end
				updateDetails(baseTheme, "Empty")
				updateDetails(appliedTheme, stateName)
			end
			-- Finally we apply any modifications that have already been made
			-- Modifiers are all the changes made using icon:modifyTheme(...)
			local alreadyAppliedTheme = {}
			local alreadyAppliedGroup = icon.appearance[stateName]
			if alreadyAppliedGroup then
				for _, modifier in pairs(alreadyAppliedGroup) do
					local modificationsUID = modifier[5]
					if modificationsUID ~= nil then
						local modification = {modifier[1], modifier[2], modifier[3], stateName, modificationsUID}
						table.insert(alreadyAppliedTheme, modification)
					end
				end
			end
			updateDetails(alreadyAppliedTheme, stateName)
			-- This now converts it into our final appearance
			local finalStateAppearance = {}
			for _, detail in pairs(stateAppearance) do
				table.insert(finalStateAppearance, detail)
			end
			icon.appearance[stateName] = finalStateAppearance
		end
		Themes.change(icon)
	end
	generateTheme()
end



return Themes

-- // Default.lua
-- Themes in v3 work simply by applying the value (agument[3])
-- to the property (agument[2]) of an instance within the icon which
-- matches the name of argument[1]. Argument[1] can also be used to
-- specify a collection of instances with a corresponding 'collective'
-- value. A colletive is simply an attribute applied to some instances
-- within the icon to group them together (such as "IconCorners").
-- If the property (argument[2]) does not exist within the instance,
-- it will instead be applied as an attribute on the instance:
-- (i.e. ``instance:SetAttribute(argument[2], [argument[3])``)
-- Use argument[4] to specify a state: "Deselected", "Selected"
-- or "Viewing". If argument[4] is empty the state will default
-- to "Deselected".
-- I've designed themes this way so you have full control over
-- the appearance of the widget and its descendants


return {
	
	-- When no state is specified the modification is applied to *all* states (Deselected, Selected and Viewing)
	{"IconCorners", "CornerRadius", UDim.new(1, 0)},
	{"Selection", "RotationSpeed", 1},
	{"Selection", "Size", UDim2.new(1, 0, 1, 1)},
	{"Selection", "Position", UDim2.new(0, 0, 0, 0)},
	{"SelectionGradient", "Color", ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 86, 86)),
	})},
	
	-- When the icon is deselected
	{"IconImage", "Image", "", "Deselected"},
	{"IconLabel", "Text", "", "Deselected"},
	{"IconLabel", "Position", UDim2.fromOffset(0, 0), "Deselected"}, -- 0, -1
	{"Widget", "DesiredWidth", 44, "Deselected"},
	{"Widget", "MinimumWidth", 44, "Deselected"},
	{"Widget", "MinimumHeight", 44, "Deselected"},
	{"Widget", "BorderSize", 4, "Deselected"},
  	{"IconButton", "BackgroundColor3", Color3.fromRGB(18, 18, 21), "Deselected"},
	{"IconButton", "BackgroundTransparency", 0.08, "Deselected"},
	{"IconImageScale", "Value", 0.5, "Deselected"},
	{"IconImageCorner", "CornerRadius", UDim.new(0, 0), "Deselected"},
	{"IconImage", "ImageColor3", Color3.fromRGB(255, 255, 255), "Deselected"},
	{"IconImage", "ImageTransparency", 0, "Deselected"},
	{"IconImageRatio", "AspectRatio", 1, "Deselected"},
	{"IconLabel", "FontFace", Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal), "Deselected"},
	{"IconLabel", "TextSize", 16, "Deselected"},
	{"IconSpot", "BackgroundTransparency", 1, "Deselected"},
	{"IconOverlay", "BackgroundTransparency", 0.85, "Deselected"},
	{"IconSpotGradient", "Enabled", false, "Deselected"},
	{"IconGradient", "Enabled", false, "Deselected"},
	{"ClickRegion", "Active", true, "Deselected"},  -- This is set to false within scrollers to ensure scroller can be dragged on mobile
	{"Menu", "Active", false, "Deselected"},
	{"ContentsList", "HorizontalAlignment", Enum.HorizontalAlignment.Center, "Deselected"},
  	{"Dropdown", "BackgroundColor3", Color3.fromRGB(18, 18, 21), "Deselected"},
	{"Dropdown", "BackgroundTransparency", 0.08, "Deselected"},
	{"Dropdown", "MaxIcons", 4.5, "Deselected"},
	{"Menu", "MaxIcons", 4, "Deselected"},
	{"Notice", "Position", UDim2.new(1, -12, 0, -1), "Deselected"},
	{"Notice", "Size", UDim2.new(0, 20, 0, 20), "Deselected"},
	{"NoticeLabel", "TextSize", 13, "Deselected"},
	{"PaddingLeft", "Size", UDim2.new(0, 9, 1, 0), "Deselected"},
	{"PaddingRight", "Size", UDim2.new(0, 11, 1, 0), "Deselected"},
	
	-- When the icon is selected
	-- Selected also inherits everything from Deselected if nothing is set
	{"IconSpot", "BackgroundTransparency", 0.7, "Selected"},
	{"IconSpot", "BackgroundColor3", Color3.fromRGB(255, 255, 255), "Selected"},
	{"IconSpotGradient", "Enabled", true, "Selected"},
	{"IconSpotGradient", "Rotation", 45, "Selected"},
	{"IconSpotGradient", "Color", ColorSequence.new(Color3.fromRGB(96, 98, 100), Color3.fromRGB(77, 78, 80)), "Selected"},
	
	
	-- When a cursor is hovering above, a controller highlighting, or touchpad (mobile) pressing (but not released)
	--{"IconSpot", "BackgroundTransparency", 0.75, "Viewing"},
	
}

-- // Classic.lua
-- This is to provide backwards compatability with the old Roblox
-- topbar while experiences transition over to the new topbar
-- You don't need to apply this yourself, topbarplus automatically
-- applies it if the old roblox topbar is detected


return {
	{"Selection", "Size", UDim2.new(1, -6, 1, -5)},
	{"Selection", "Position", UDim2.new(0, 3, 0, 3)},
	
	{"Widget", "MinimumWidth", 32, "Deselected"},
	{"Widget", "MinimumHeight", 32, "Deselected"},
	{"Widget", "BorderSize", 0, "Deselected"},
	{"IconCorners", "CornerRadius", UDim.new(0, 9), "Deselected"},
	{"IconButton", "BackgroundTransparency", 0.5, "Deselected"},
	{"IconLabel", "TextSize", 14, "Deselected"},
	{"Dropdown", "BackgroundTransparency", 0.5, "Deselected"},
	{"Notice", "Position", UDim2.new(1, -12, 0, -3), "Deselected"},
	{"Notice", "Size", UDim2.new(0, 15, 0, 15), "Deselected"},
	{"NoticeLabel", "TextSize", 11, "Deselected"},
	
	{"IconSpot", "BackgroundColor3", Color3.fromRGB(0, 0, 0), "Selected"},
	{"IconSpot", "BackgroundTransparency", 0.702, "Selected"},
	{"IconSpotGradient", "Enabled", false, "Selected"},
	{"IconOverlay", "BackgroundTransparency", 0.97, "Selected"},
	
}

