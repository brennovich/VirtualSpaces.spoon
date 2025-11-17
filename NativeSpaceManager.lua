-- VirtualSpaces.spoon core idea is to abstract the native macOS Spaces management.
--
-- For that it needs to ensure that there are exactly two native Spaces on the
-- main screen:
--   - the "active" Space where the windows from the current Virtual Space
--     are shown
--   - the "storage" Space where the all the other windows from the other
--     Virtual Spaces are kept hidden
--
-- This module makes sure to setup the Native Spaces accordingly, ensuring that
-- indenpendently of your configuration before loading the spoon, you will end up
-- with exactly two Spaces on the main screen.
local NativeSpaceManager = {}
NativeSpaceManager.__index = NativeSpaceManager

local MISSION_CONTROL_WAIT_TIME_S = 0.5
local SPACE_REMOVAL_DELAY_US = 100000
local SPACE_CREATION_DELAY_US = 10000

function NativeSpaceManager.new(hsSpaces, hsScreen, hsTimer, hsEventtap, instrumentation)
	local self = setmetatable({}, NativeSpaceManager)
	self._hsSpaces = hsSpaces or hs.spaces
	self._hsScreen = hsScreen or hs.screen
	self._hsTimer = hsTimer or hs.timer
	self._hsEventtap = hsEventtap or hs.eventtap
	self._instrumentation = instrumentation
	self._activeSpace = nil
	self._storageSpace = nil
	return self
end

function NativeSpaceManager:setupForMainScreen()
	self._hsSpaces.setDefaultMCwaitTime(MISSION_CONTROL_WAIT_TIME_S)

	local mainScreen = self._hsScreen.mainScreen():getUUID()
	local allSpaces = self:_timedCall("allSpaces()", function()
		return self._hsSpaces.allSpaces()
	end)
	local screenSpaces = allSpaces[mainScreen]

	self:_ensureOnFirstSpace(screenSpaces)
	self:_removeExtraSpaces(screenSpaces)
	self:_createStorageSpace(mainScreen)

	local refreshedSpaces = self:_verifySpaceCount(mainScreen, 2, 3)

	self._activeSpace = refreshedSpaces[1]
	self._storageSpace = refreshedSpaces[2]

	return self._activeSpace, self._storageSpace
end

function NativeSpaceManager:getActiveSpace()
	return self._activeSpace
end

function NativeSpaceManager:getStorageSpace()
	return self._storageSpace
end

function NativeSpaceManager:updateSpaces(activeSpace, storageSpace)
	self._activeSpace = activeSpace
	self._storageSpace = storageSpace
end

function NativeSpaceManager:_ensureOnFirstSpace(screenSpaces)
	local activeSpace = self:_timedCall("activeSpaceOnScreen()", function()
		return self._hsSpaces.activeSpaceOnScreen()
	end)

	if activeSpace ~= screenSpaces[1] then
		self:_timedCall("gotoSpace()", function()
			self._hsSpaces.gotoSpace(screenSpaces[1])
		end)
		self:_timedCall("keyStroke(escape)", function()
			self._hsEventtap.keyStroke({}, "escape")
		end)
	end
end

function NativeSpaceManager:_removeExtraSpaces(screenSpaces)
	if #screenSpaces > 1 then
		for i = 2, #screenSpaces do
			self._hsTimer.usleep(SPACE_REMOVAL_DELAY_US)
			self:_timedCall("removeSpace()", function()
				self._hsSpaces.removeSpace(screenSpaces[i], false)
			end)
		end
	end
end

function NativeSpaceManager:_createStorageSpace(mainScreen)
	self._hsTimer.usleep(SPACE_CREATION_DELAY_US)
	self:_timedCall("addSpaceToScreen()", function()
		self._hsSpaces.addSpaceToScreen(mainScreen, true)
	end)
end

function NativeSpaceManager:_verifySpaceCount(mainScreen, expectedCount, maxRetries)
	maxRetries = maxRetries or 3

	for attempt = 1, maxRetries do
		self._hsTimer.usleep(SPACE_REMOVAL_DELAY_US)
		local allSpaces = self:_timedCall("allSpaces()", function()
			return self._hsSpaces.allSpaces()
		end)
		local spaces = allSpaces[mainScreen]

		if not spaces then
			if attempt == maxRetries then
				error(
					"VirtualSpaces setup failed: Unable to query spaces for main screen. " ..
					"Check System Preferences > Security & Privacy > Accessibility."
				)
			end
		elseif #spaces == expectedCount then
			return spaces
		elseif attempt == maxRetries then
			error(string.format(
				"VirtualSpaces setup failed: Expected exactly %d spaces after %d retries, but found %d",
				expectedCount,
				maxRetries,
				#spaces
			))
		end
	end
end

function NativeSpaceManager:_timedCall(operationName, fn)
	if not self._instrumentation then
		return fn()
	end
	return self._instrumentation:timed(operationName, fn)
end

return NativeSpaceManager
