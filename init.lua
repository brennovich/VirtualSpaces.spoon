--- === VirtualSpaces ===
---
--- VirtualSpaces implements a virtual workspace system that tries to get rid of the annoying Spaces transitions of macOS Mission Control.
---
--- It creates multiple logical workspaces on a single macOS desktop by managing window visibility: windows belonging to the current workspace stay in place while windows from other workspaces are hidden off-screen. Its goal is to provide a instant switching experience between workspaces without the overhead of managing multiple physical desktops and superfulous macOS transition effects.
---
--- --- Download: [VirtualSpaces.spoon.zip](https://github.com/brennovich/VirtualSpaces.spoon/releases/latest/download/VirtualSpaces.spoon.zip)

local spoonPath = hs.spoons.scriptPath()
package.path = package.path .. ";" .. spoonPath .. "?.lua"

local Window = require("Window")
local SpacesModel = require("SpacesModel")
local VirtualSpace = require("VirtualSpace")
local Telemetry = require("Telemetry")
local WindowCache = require("WindowCache")

local obj = {}
obj.__index = obj

obj.name = "VirtualSpaces"
obj.version = "1.0"
obj.author = "brennovich"
obj.license = "MIT"

--- VirtualSpaces:init()
--- Method
--- Initializes the VirtualSpaces spoon. Sets up the space strategy, configures window tracking, and assigns existing windows to virtual space 1.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The VirtualSpaces object
---
--- Notes:
--- * Hides windows from other virtual spaces off-screen and restores them on switch
--- * Automatically assigns all existing windows to virtual space 1
--- * Sets up window filters to track window creation and destruction
--- * Implements space watcher to detect manual navigation to storage space
function obj:init()
	self._telemetry = Telemetry.new('VirtualSpaces', 'warning')
	self.windowCache = WindowCache.new(self._telemetry)
	self.windowFilter = hs.window.filter.new()

	self.spaceStrategy = VirtualSpace.new({
		telemetry = self._telemetry,
		windowGetter = function(winId) return self.windowCache:get(winId) end,
		windowFilter = self.windowFilter,
	})

	self.spaceStrategy:setupForMainScreen()

	self.model = SpacesModel.new()

	for _, win in ipairs(hs.window.allWindows()) do
		self:_assignWindowToVirtualSpace(win, 1)
	end

	self.windowFilter:subscribe(hs.window.filter.windowCreated, function(window)
		self:_assignWindowToVirtualSpace(window, self.model:getCurrentVirtualSpace())
	end)

	self.windowFilter:subscribe(hs.window.filter.windowFocused, function(window)
		self._telemetry:span(string.format("saveWindowFocus(%d)", window:id()), function()
			if not self:_isValidWindowForVirtualSpace(window) then return end

			if not self.model:getVirtualSpaceForWindow(window:id()) then
				self:_assignWindowToVirtualSpace(window, self.model:getCurrentVirtualSpace())
			end

			local virtualSpace = self.model:getVirtualSpaceForWindow(window:id())
				or self.model:getCurrentVirtualSpace()
			self.model:saveFocusedWindowInVirtualSpace(virtualSpace, window:id())
		end)
	end)

	self.windowFilter:subscribe(hs.window.filter.windowDestroyed, function(window)
		local hasTabSiblings = self.model:getTabSiblingsBeforeDestruction(window:id()) ~= nil
		self.model:unregisterWindowById(window:id())
		self.windowCache:remove(window:id())
		self.spaceStrategy:forgetWindow(window:id())

		if not hasTabSiblings then
			self:_restoreWindowsFocusForVirtualSpace()
		end
	end)

	self.spaceStrategy:startWatchingForManualNavigation(function(currentNativeSpace)
		self._telemetry:span(string.format("spaceWatcher(%s)", tostring(currentNativeSpace)), function()
			if currentNativeSpace == self.spaceStrategy:getStorageSpace() then
				if self._ignoreNextManualNavigation then
					self._ignoreNextManualNavigation = false
					return
				end

				if self:_currentVirtualSpaceIsClosing() then
					return
				end

				local win = hs.window.focusedWindow()
				if not win then return end

				local windowVirtualSpace = self.model:getVirtualSpaceForWindow(win:id()) or 1

				self:_switchSpaces(windowVirtualSpace)
			end
		end)
	end)

	self.subscribers = {
		virtualSpaceChanged = {}
	}

	self._ignoreNextManualNavigation = false

	return self
end

--- VirtualSpaces:switchToVirtualSpace(virtualSpace)
--- Method
--- Switches to the specified virtual workspace. Moves windows between active and storage spaces to simulate independent desktops.
---
--- Parameters:
--- * virtualSpace - The virtual workspace number to switch to (must be >= 1)
---
--- Returns:
--- * None
---
--- Notes:
--- * Saves currently focused window for the current workspace
--- * Moves all visible windows to storage space
--- * Retrieves windows belonging to target workspace from storage
--- * Moves them to active space and restores focus to last focused window
--- * Does nothing if already on the target virtual space
function obj:switchToVirtualSpace(virtualSpace)
	return self._telemetry:span(string.format("switchToVirtualSpace(%d)", virtualSpace), function()
		local onManagedSpace = self.spaceStrategy:isOnManagedSpace()

		if virtualSpace == self.model:getCurrentVirtualSpace() then
			if not onManagedSpace then
				self:_returnToManagedSpace()
			end
			return
		end

		self:_switchSpaces(virtualSpace)

		if onManagedSpace then
			self:_restoreWindowsFocusForVirtualSpace()
		else
			self:_returnToManagedSpace()
		end

		self:_dispatchEvent("virtualSpaceChanged")
	end)
end

--- VirtualSpaces:moveWindowToVirtualSpace(window, virtualSpace)
--- Method
--- Assigns a window to a different virtual space by moving it to the appropriate native space.
---
--- Parameters:
--- * window - Hammerspoon window object to move (optional). If nil or not provided, uses the currently focused window. If no focused window exists or the window is not valid (fullscreen or non-standard), the function returns without doing anything.
--- * virtualSpace - Target virtual workspace number (must be >= 1). If invalid, the function returns without doing anything.
---
--- Returns:
--- * None
---
--- Notes:
--- * If target is the current workspace, moves window to active space (visible)
--- * If target is a different workspace, moves window to storage space (hidden)
--- * Updates workspace mapping and restores focus appropriately
function obj:moveWindowToVirtualSpace(window, virtualSpace)
	if not virtualSpace or virtualSpace < 1 then return end

	return self._telemetry:span(string.format("moveWindowToVirtualSpace(%d)", virtualSpace), function()
		local window = window or hs.window.focusedWindow()
		if not self:_isValidWindowForVirtualSpace(window) then return end

		local targetNativeSpace = (virtualSpace == self.model:getCurrentVirtualSpace())
			and self.spaceStrategy:getActiveSpace()
			or self.spaceStrategy:getStorageSpace()

		self._telemetry:span(string.format("moveWindowToSpace(%d)", window:id()), function()
			self.spaceStrategy:moveWindowToSpace(window:id(), targetNativeSpace)
			self.model:moveWindowToVirtualSpace(window:id(), virtualSpace)
		end)

		self:_restoreWindowsFocusForVirtualSpace()
	end)
end

--- VirtualSpaces:getWindowsForCurrentVirtualSpace()
--- Method
--- Returns all windows in the current virtual space as window objects
---
--- Parameters:
--- * None
---
--- Returns:
--- * Array of hs.window objects for the current virtual space
---
--- Notes:
--- * Filters out destroyed/invalid windows
--- * Returns empty array if no windows in current space
--- * Used by WMUtils.spoon for tiling integration
function obj:getWindowsForCurrentVirtualSpace()
	local currentSpace = self.model:getCurrentVirtualSpace()
	local windowIds = self.model:getWindowsInVirtualSpace(currentSpace)
	local windows = {}

	for _, windowId in ipairs(windowIds) do
		local win = self.windowCache:get(windowId)
		if win then
			table.insert(windows, win)
		end
	end

	return windows
end

--- VirtualSpaces:getCurrentVirtualSpace()
--- Method
--- Returns the current virtual space ID
---
--- Parameters:
--- * None
---
--- Returns:
--- * Current virtual space ID (1-4)
function obj:getCurrentVirtualSpace()
	return self.model._currentVirtualSpace
end

--- VirtualSpaces:getCurrentVirtualSpaceMetadata()
--- Method
--- Returns detailed metadata for the current virtual space
---
--- Parameters:
--- * None
---
--- Returns:
--- * Table with keys:
---   * id - Current virtual space ID (1-4)
---   * windowCount - Number of windows in this space
---   * windows - Array of hs.window objects
---   * focusedWindow - Currently focused window (or nil)
function obj:getCurrentVirtualSpaceMetadata()
	local currentSpace = self:getCurrentVirtualSpace()
	local windows = self:getWindowsForCurrentVirtualSpace()
	local focusedWindow = hs.window.focusedWindow()

	return {
		id = currentSpace,
		windowCount = #windows,
		windows = windows,
		focusedWindow = focusedWindow
	}
end

--- VirtualSpaces:subscribe(eventType, callback)
--- Method
--- Subscribe to virtual space events
---
--- Parameters:
--- * eventType - Event type string (currently only "virtualSpaceChanged")
--- * callback - Function to call when event occurs. Receives eventData parameter
---
--- Returns:
--- * The VirtualSpaces object (for chaining)
---
--- Notes:
--- * Callbacks are wrapped in pcall() to prevent errors from breaking event dispatch
--- * Invalid event types log a warning
--- * Non-function callbacks log an error
function obj:subscribe(eventType, callback)
	if not self.subscribers[eventType] then
		hs.logger.new("VirtualSpaces"):w("Unknown event type: " .. eventType)
		return self
	end

	if type(callback) ~= "function" then
		hs.logger.new("VirtualSpaces"):e("Callback must be a function")
		return self
	end

	table.insert(self.subscribers[eventType], callback)
	return self
end

--- VirtualSpaces:unsubscribe(eventType, callback)
--- Method
--- Unsubscribe from virtual space events
---
--- Parameters:
--- * eventType - Event type string
--- * callback - The exact callback function to remove
---
--- Returns:
--- * The VirtualSpaces object (for chaining)
---
--- Notes:
--- * Removes only the first matching callback by reference equality
--- * Safe to call with non-existent event types or callbacks
function obj:unsubscribe(eventType, callback)
	if not self.subscribers[eventType] then
		return self
	end

	for i, cb in ipairs(self.subscribers[eventType]) do
		if cb == callback then
			table.remove(self.subscribers[eventType], i)
			break
		end
	end

	return self
end

--- VirtualSpaces:_dispatchEvent(eventType)
--- Method
--- Internal method to dispatch events to subscribed callbacks
---
--- Parameters:
--- * eventType - Event type string
---
--- Returns:
--- * None
---
--- Notes:
--- * Wraps each callback in pcall() to prevent errors from breaking dispatch
--- * Safely handles non-existent event types and missing subscribers
--- * Not intended for external use (internal API)
function obj:_dispatchEvent(eventType)
	if not self.subscribers or not self.subscribers[eventType] then
		return
	end

	local eventData = {
		eventType = eventType,
		currentSpace = self:getCurrentVirtualSpaceMetadata()
	}

	for _, callback in ipairs(self.subscribers[eventType]) do
		local success, err = pcall(callback, eventData)
		if not success then
			hs.logger.new("VirtualSpaces"):e("Error in subscriber callback: " .. tostring(err))
		end
	end
end

--- VirtualSpaces:instrument(logLevel)
--- Method
--- Sets the instrumentation log level to control logging behavior.
---
--- Parameters:
--- * logLevel - Log level string. Valid values: 'nothing', 'error', 'warning', 'info', 'debug', 'verbose'
---
--- Returns:
--- * None
---
--- Notes:
--- * Can be called at any time to change logging verbosity
--- * Default log level is 'warning' (no instrumentation)
--- * 'info' level: logs operation names only
--- * 'debug' level: logs both operation names and timing metrics
function obj:instrument(logLevel)
	self._telemetry:setLogLevel(logLevel)
end

function obj:_switchSpaces(virtualSpace)
	self._telemetry:span("captureCurrentFocusBeforeSwitch", function()
		local currentFocused = hs.window.focusedWindow()
		if currentFocused and self:_isValidWindowForVirtualSpace(currentFocused) then
			self.model:saveFocusedWindowInVirtualSpace(self.model:getCurrentVirtualSpace(), currentFocused:id())
		end
	end)

	self._telemetry:span("mapWindowsToNativeSpaces", function()
		local categorized = self.model:categorizeWindowsForTransition(
			virtualSpace, self.model:getCurrentVirtualSpace())

		for _, winId in ipairs(categorized.toActive) do
			self.spaceStrategy:moveWindowToSpace(winId, self.spaceStrategy:getActiveSpace())
		end

		for _, winId in ipairs(categorized.toStorage) do
			self.spaceStrategy:moveWindowToSpace(winId, self.spaceStrategy:getStorageSpace())
		end
	end)

	self.model:setCurrentVirtualSpace(virtualSpace)
end

function obj:_assignWindowToVirtualSpace(window, virtualSpace)
	if not self:_isValidWindowForVirtualSpace(window) then return end

	return self._telemetry:span(string.format("assignWindowToSpace(%d, %d)", window:id(), virtualSpace), function()
		self.model:assignWindowToSpace(Window.new(window), virtualSpace)
		self.windowCache:add(window)
	end)
end

function obj:_returnToManagedSpace()
	if not self:_restoreWindowsFocusForVirtualSpace() then
		self._ignoreNextManualNavigation = true
		self.spaceStrategy:activateManagedSpace()
	end
end

function obj:_restoreWindowsFocusForVirtualSpace()
	return self._telemetry:span("restoreWindowsFocus", function()
		local currentSpace = self.model:getCurrentVirtualSpace()
		local osFocused = hs.window.focusedWindow()
		if osFocused and self:_isValidWindowForVirtualSpace(osFocused)
			and self.model:getVirtualSpaceForWindow(osFocused:id()) == currentSpace then
			self.model:saveFocusedWindowInVirtualSpace(currentSpace, osFocused:id())
			return true
		end

		local win = self.windowCache:get(
			self.model:prepareWindownToBeFocusedOnCurrentVirtualSpace())

		if win then
			win:focus()
			return true
		end

		return false
	end)
end

function obj:_isValidWindowForVirtualSpace(window)
	return window and window:isStandard() and not window:isFullScreen()
		and self.spaceStrategy:managesWindow(window:id())
end

function obj:_currentVirtualSpaceIsClosing()
	local windowIds = self.model:getWindowsInVirtualSpace(self.model:getCurrentVirtualSpace())
	if #windowIds == 0 then
		return false
	end

	for _, windowId in ipairs(windowIds) do
		if hs.window.get(windowId) then
			return false
		end
	end

	return true
end

return obj
