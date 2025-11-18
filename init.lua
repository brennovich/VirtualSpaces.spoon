--- === VirtualSpaces ===
---
--- VirtualSpaces implements a virtual workspace system that tries to get rid of the annoying Spaces transitions of macOS Mission Control.
---
--- It creates multiple logical workspaces on a single macOS desktop by managing window visibility across two macOS spaces: one active and one for storage. Its goal is to provide a instant switching experience between workspaces without the overhead of managing multiple physical desktops and superfulous macOS transition effects.
---
--- --- Download: [VirtualSpaces.spoon.zip](https://github.com/brennovich/VirtualSpaces.spoon/releases/latest/download/VirtualSpaces.spoon.zip)

local spoonPath = hs.spoons.scriptPath()
package.path = package.path .. ";" .. spoonPath .. "?.lua"

local WindowsSort = require("WindowsSort")
local SpacesModel = require("SpacesModel")
local NativeSpaceManager = require("NativeSpaceManager")
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
--- Initializes the VirtualSpaces spoon. Sets up two native macOS spaces, configures window tracking, and assigns existing windows to virtual space 1.
---
--- Parameters:
--- * None
---
--- Returns:
--- * The VirtualSpaces object
---
--- Notes:
--- * Ensures exactly two native macOS spaces exist on the main screen
--- * Automatically assigns all existing windows to virtual space 1
--- * Sets up window filters to track window creation and destruction
--- * Implements space watcher to detect manual navigation to storage space
function obj:init()
	self._telemetry = Telemetry.new('VirtualSpaces', 'warning')

	self.nativeSpaceManager = NativeSpaceManager.new({
		telemetry = self._telemetry
	})

	-- Ensure we have exactly two native spaces on the main screen
	local activeSpace, storageSpace = self.nativeSpaceManager:setupForMainScreen()

	self._windowSorter = WindowsSort.new(activeSpace, storageSpace, {
		telemetry = self._telemetry
	})

	self.model = SpacesModel.new()
	self.windowCache = WindowCache.new(self._telemetry)
	self.windowFilter = hs.window.filter.new()

	-- This filter is unused but it seems to help address this bug:
	-- https://github.com/Hammerspoon/hammerspoon/issues/3276
	self.windowFilterOther = hs.window.filter.new()
	self.windowFilterOther:setCurrentSpace(true)

	for _, win in ipairs(hs.window.allWindows()) do
		if win:isStandard() then
			self:_assignWindowToVirtualSpace(win, 1)
			self.windowCache:add(win:id(), win)
		end
	end

	self.windowFilter:subscribe(hs.window.filter.windowCreated, function(window)
		self:_assignWindowToVirtualSpace(window, self.model:getCurrentVirtualSpace())
		self.windowCache:add(window:id(), window)
	end)
	self.windowFilter:subscribe(hs.window.filter.windowDestroyed, function(window)
		local windowId = window:id()
		self.model:removeWindow(windowId)
		self.windowCache:remove(windowId)
		self:_restoreWindowsFocusForVirtualSpace()
	end)

	self.spaceWatcher = hs.spaces.watcher.new(function(spaceId)
		local actualSpace = hs.spaces.activeSpaceOnScreen()

		if actualSpace == self.nativeSpaceManager:getStorageSpace() then
			local focusedWindow = hs.window.focusedWindow()
			if not focusedWindow then
				return
			end

			local windowVirtualSpace = self.model:getVirtualSpaceForWindow(focusedWindow:id())

			if windowVirtualSpace and windowVirtualSpace ~= self.model:getCurrentVirtualSpace() then
				self.model:setCurrentVirtualSpace(windowVirtualSpace)
				self.model:saveFocusedWindowInVirtualSpace(windowVirtualSpace, focusedWindow:id())
			end
		end
	end)
	self.spaceWatcher:start()

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
	if not virtualSpace or virtualSpace < 1 then
		return
	end

	return self._telemetry:span(string.format("switchToVirtualSpace(%d)", virtualSpace), function()
		local currentSpace = hs.spaces.activeSpaceOnScreen()

		if virtualSpace == self.model:getCurrentVirtualSpace() and currentSpace == self.nativeSpaceManager:getActiveSpace() then
			return
		end

		local focusedWin = hs.window.focusedWindow()
		if focusedWin then
			self._telemetry:span("saveFocusedWindow", function()
				self.model:saveFocusedWindowInVirtualSpace(self.model:getCurrentVirtualSpace(), focusedWin:id())
			end)
		end

		local categorizedWindows = self.model:categorizeWindowsForTransition(virtualSpace, self.model:getCurrentVirtualSpace())
		local activeSpace, storageSpace = self._windowSorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(
			categorizedWindows,
			currentSpace
		)
		self.nativeSpaceManager:updateSpaces(activeSpace, storageSpace)
		self.model:setCurrentVirtualSpace(virtualSpace)

		self:_restoreWindowsFocusForVirtualSpace()
	end)
end

--- VirtualSpaces:moveWindowToVirtualSpace(window, virtualSpace)
--- Method
--- Assigns a window to a different virtual workspace and moves it to the appropriate native space.
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
--- * When window parameter is nil, this is NOT an error condition - it intentionally uses the focused window as a convenience feature
function obj:moveWindowToVirtualSpace(window, virtualSpace)
	if not virtualSpace or virtualSpace < 1 then return end

	return self._telemetry:span(string.format("moveWindowToVirtualSpace(%d)", virtualSpace), function()
		if not window then
			window = self._telemetry:span("focusedWindow()", function()
				return hs.window.focusedWindow()
			end)
			if not window then return end
		end

		self:_assignWindowToVirtualSpace(window, virtualSpace)

		local targetNativeSpace = (virtualSpace == self.model:getCurrentVirtualSpace())
			and self.nativeSpaceManager:getActiveSpace()
			or self.nativeSpaceManager:getStorageSpace()

		self._telemetry:span("moveWindowToSpace()", function()
			hs.spaces.moveWindowToSpace(window, targetNativeSpace)
		end)

		self:_restoreWindowsFocusForVirtualSpace()
	end)
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

function obj:_assignWindowToVirtualSpace(window, virtualSpace)
	if not self:_isValidWindowForVirtualSpace(window) then return end

	return self._telemetry:span("assignWindowToVirtualSpace", function()
		local winId = window:id()
		self.model:assignWindowToVirtualSpace(winId, virtualSpace)
		self.model:saveFocusedWindowInVirtualSpace(virtualSpace, winId)
	end)
end

function obj:_restoreWindowsFocusForVirtualSpace()
	return self._telemetry:span("restoreWindowsFocus", function()
		local currentVirtualSpace = self.model:getCurrentVirtualSpace()
		local windowId = self.model:getFocusedWindowForVirtualSpace(currentVirtualSpace)
		if windowId and self.model:getVirtualSpaceForWindow(windowId) == currentVirtualSpace then
			if self:_focusWindowById(windowId) then
				return
			end
		end

		local remainingWindows = self.model:getWindowsInVirtualSpace(currentVirtualSpace)
		if #remainingWindows > 0 then
			if self:_focusWindowById(remainingWindows[1]) then
				self.model:saveFocusedWindowInVirtualSpace(currentVirtualSpace, remainingWindows[1])
			end
		end
	end)
end

function obj:_isValidWindowForVirtualSpace(window)
	return window and window:isStandard() and not window:isFullScreen()
end

function obj:_focusWindowById(windowId)
	local win = self._telemetry:span("windowCache:get()", function()
		return self.windowCache:get(windowId)
	end)
	if win and not win:isMinimized() then
		self._telemetry:span("window:focus()", function()
			win:focus()
		end)
		return true
	end
	return false
end

return obj
