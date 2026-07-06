-- Emulates the "active"/"storage" native Space distinction without ever
-- creating a second real macOS Space, since hs.spaces.moveWindowToSpace is
-- broken on macOS Sequoia (https://github.com/Hammerspoon/hammerspoon/issues/3698).
--
-- Instead of moving windows to a different Space, "storage" windows are
-- pushed into the bottom-right corner of the main screen and "active"
-- windows are restored to the exact frame captured right before hiding.
--
-- macOS clamps windows from being placed fully outside all screens: the
-- horizontal axis clamps to a 1px sliver, while the vertical axis keeps
-- ~38px of title bar reachable. Pushing to the corner (both axes) confines
-- the leftover strip to a tiny ~1x38px nub, instead of the full-height 1px
-- line a right-edge-only push would leave running down the whole screen.
local Telemetry = require("Telemetry")

local VirtualSpace = {}
VirtualSpace.__index = VirtualSpace

local ACTIVE = "active"
local STORAGE = "storage"
local HIDDEN_EDGE_EPSILON = 1
local HIDDEN_EDGE_DETECTION_MARGIN = 10
local TARGET_NATIVE_SPACE_COUNT = 1

function VirtualSpace.new(deps)
	deps = deps or {}
	local self = setmetatable({}, VirtualSpace)

	self._windowGetter = deps.windowGetter or function(winId) return hs.window.get(winId) end
	self._hsWindow = deps.hsWindow or hs.window
	self._hsScreen = deps.hsScreen or hs.screen
	self._hsSpaces = deps.hsSpaces or hs.spaces
	self._windowFilter = deps.windowFilter
	self._telemetry = deps.telemetry or Telemetry.NoOp.new()

	self._hiddenWindowFrames = {}

	return self
end

function VirtualSpace:setupForMainScreen()
	return self._telemetry:span("setupForMainScreen", function()
		self:_consolidateToSingleNativeSpace()
		self._managedSpaceId = self._hsSpaces.activeSpaceOnScreen()
		self:_recoverWindowsStuckAtHiddenEdge()
		return ACTIVE, STORAGE
	end)
end

function VirtualSpace:isOnManagedSpace()
	return self._hsSpaces.activeSpaceOnScreen() == self._managedSpaceId
end

function VirtualSpace:managesWindow(winId)
	local spaces = self._hsSpaces.windowSpaces(winId)
	if not spaces then return false end

	for _, spaceId in ipairs(spaces) do
		if spaceId == self._managedSpaceId then return true end
	end

	return false
end

function VirtualSpace:getActiveSpace()
	return ACTIVE
end

function VirtualSpace:getStorageSpace()
	return STORAGE
end

function VirtualSpace:moveWindowToSpace(winId, spaceId)
	return self._telemetry:span(string.format("moveWindowToSpace(%s)", tostring(winId)), function()
		local win = self._windowGetter(winId)
		if not win or win:isMinimized() then return end

		if spaceId == STORAGE then
			if self._hiddenWindowFrames[winId] then return end
			self._hiddenWindowFrames[winId] = win:frame()
			win:setFrame(self:_hiddenFrameFor(win:frame()))
		elseif spaceId == ACTIVE then
			local originalFrame = self._hiddenWindowFrames[winId]
			if not originalFrame then return end
			win:setFrame(originalFrame)
			self._hiddenWindowFrames[winId] = nil
		end
	end)
end

function VirtualSpace:windowSpaces(winId)
	if self._hiddenWindowFrames[winId] then
		return {STORAGE}
	end

	return {ACTIVE}
end

function VirtualSpace:startWatchingForManualNavigation(callback)
	self._windowFilter:subscribe(self._hsWindow.filter.windowFocused, function(window)
		if self._hiddenWindowFrames[window:id()] then
			callback(STORAGE)
		end
	end)
	return self._windowFilter
end

function VirtualSpace:forgetWindow(winId)
	self._hiddenWindowFrames[winId] = nil
end

function VirtualSpace:_consolidateToSingleNativeSpace()
	local mainScreen = self._hsScreen.mainScreen():getUUID()
	local spaces = self:_spacesForScreen(mainScreen)

	if #spaces == TARGET_NATIVE_SPACE_COUNT then return end

	local activeSpace = self._hsSpaces.activeSpaceOnScreen()
	self._hsSpaces.openMissionControl()

	for _, spaceID in ipairs(spaces) do
		if spaceID ~= activeSpace then
			self._telemetry:span(string.format("removeSpace(%s)", tostring(spaceID)), function()
				self._hsSpaces.removeSpace(spaceID, false)
			end)
		end
	end

	local refreshedSpaces = self:_spacesForScreen(mainScreen)
	if #refreshedSpaces ~= TARGET_NATIVE_SPACE_COUNT then
		error(string.format(
			"VirtualSpaces setup failed: expected exactly %d native Space after setup, but found %d. Try reloading Hammerspoon.",
			TARGET_NATIVE_SPACE_COUNT, #refreshedSpaces
		))
	end

	self._hsSpaces.closeMissionControl()
end

function VirtualSpace:_spacesForScreen(mainScreen)
	local spaces = self._hsSpaces.allSpaces()[mainScreen]
	if not spaces then
		error(
			"VirtualSpaces setup failed: unable to query spaces for the main screen. " ..
			"Check System Settings > Privacy & Security > Accessibility."
		)
	end
	return spaces
end

function VirtualSpace:_hiddenFrameFor(frame)
	local screenFrame = self._hsScreen.mainScreen():fullFrame()

	local hiddenX = screenFrame.x + screenFrame.w - HIDDEN_EDGE_EPSILON
	local hiddenY = screenFrame.y + screenFrame.h - HIDDEN_EDGE_EPSILON

	return {x = hiddenX, y = hiddenY, w = frame.w, h = frame.h}
end

function VirtualSpace:_recoverWindowsStuckAtHiddenEdge()
	local screenFrame = self._hsScreen.mainScreen():fullFrame()
	local visibleFrame = self._hsScreen.mainScreen():frame()
	local hiddenXThreshold = screenFrame.x + screenFrame.w - HIDDEN_EDGE_EPSILON - HIDDEN_EDGE_DETECTION_MARGIN

	for _, win in ipairs(self._hsWindow.allWindows()) do
		if not win:isMinimized() then
			local frame = win:frame()
			if frame.x >= hiddenXThreshold then
				local recoveredWidth = math.min(frame.w, visibleFrame.w)
				local recoveredHeight = math.min(frame.h, visibleFrame.h)

				win:setFrame({
					x = visibleFrame.x + (visibleFrame.w - recoveredWidth) / 2,
					y = visibleFrame.y + (visibleFrame.h - recoveredHeight) / 2,
					w = recoveredWidth,
					h = recoveredHeight
				})
			end
		end
	end
end

return VirtualSpace
