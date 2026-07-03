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

local EmulatedSpace = {}
EmulatedSpace.__index = EmulatedSpace

local ACTIVE = "emulated-active"
local STORAGE = "emulated-storage"
local HIDDEN_EDGE_EPSILON = 1
local HIDDEN_EDGE_DETECTION_MARGIN = 10

function EmulatedSpace.new(deps)
	deps = deps or {}
	local self = setmetatable({}, EmulatedSpace)

	self._windowGetter = deps.windowGetter or function(winId) return hs.window.get(winId) end
	self._hsWindow = deps.hsWindow or hs.window
	self._hsScreen = deps.hsScreen or hs.screen
	self._windowFilter = deps.windowFilter
	self._telemetry = deps.telemetry or Telemetry.NoOp.new()

	self._hiddenWindowFrames = {}

	return self
end

function EmulatedSpace:setupForMainScreen()
	return self._telemetry:span("setupForMainScreen", function()
		self:_recoverWindowsStuckAtHiddenEdge()
		return ACTIVE, STORAGE
	end)
end

function EmulatedSpace:getActiveSpace()
	return ACTIVE
end

function EmulatedSpace:getStorageSpace()
	return STORAGE
end

function EmulatedSpace:updateSpaces(activeSpace, storageSpace)
end

function EmulatedSpace:getCurrentNativeSpace()
	return ACTIVE
end

function EmulatedSpace:moveWindowToSpace(winId, spaceId)
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

function EmulatedSpace:windowSpaces(winId)
	if self._hiddenWindowFrames[winId] then
		return {STORAGE}
	end

	return {ACTIVE}
end

function EmulatedSpace:startWatchingForManualNavigation(callback)
	self._windowFilter:subscribe(self._hsWindow.filter.windowFocused, function(window)
		if self._hiddenWindowFrames[window:id()] then
			callback(STORAGE)
		end
	end)
	return self._windowFilter
end

function EmulatedSpace:forgetWindow(winId)
	self._hiddenWindowFrames[winId] = nil
end

function EmulatedSpace:_hiddenFrameFor(frame)
	local screenFrame = self._hsScreen.mainScreen():fullFrame()

	local hiddenX = screenFrame.x + screenFrame.w - HIDDEN_EDGE_EPSILON
	local hiddenY = screenFrame.y + screenFrame.h - HIDDEN_EDGE_EPSILON

	return {x = hiddenX, y = hiddenY, w = frame.w, h = frame.h}
end

function EmulatedSpace:_recoverWindowsStuckAtHiddenEdge()
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

return EmulatedSpace
