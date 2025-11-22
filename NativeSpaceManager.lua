-- VirtualSpaces.spoon core idea is to abstract the native macOS Spaces management.
--
-- For that it needs to ensure that there are exactly two native Spaces on the
-- main screen:
--   - the "active" Space where the windows from the current Virtual Space
--     are shown
--   - the "storage" Space where the all the other windows from the other
--     Virtual Spaces are kept hidden
--
-- This module makes setups the Native Spaces accordingly, ensuring that
-- indenpendently of your configuration before loading the spoon, you will end up
-- with exactly two Spaces on the main screen.
local Telemetry = require("Telemetry")

local NativeSpaceManager = {}
NativeSpaceManager.__index = NativeSpaceManager

local TARGET_NUMBER_OF_SPACES = 2

function NativeSpaceManager.new(deps)
	deps = deps or {}
	local self = setmetatable({}, NativeSpaceManager)

	self._hsSpaces = deps.hsSpaces or hs.spaces
	self._hsScreen = deps.hsScreen or hs.screen
	self._telemetry = deps.telemetry or Telemetry.NoOp.new()

	self._activeSpace = nil
	self._storageSpace = nil

	return self
end

function NativeSpaceManager:setupForMainScreen()
	return self._telemetry:span("setupForMainScreen", function()
		local mainScreen = self._hsScreen.mainScreen():getUUID()
		local allSpaces = self._telemetry:span("allSpaces()", function()
			return self._hsSpaces.allSpaces()
		end)

		local activeSpaceBeforeSetup = self._hsSpaces.activeSpaceOnScreen()
		self._hsSpaces.openMissionControl()

		for _, spaceID in ipairs(allSpaces[mainScreen]) do
			if spaceID ~= activeSpaceBeforeSetup then
				self._telemetry:span(string.format("removeSpace(%s)", spaceID), function()
					self._hsSpaces.removeSpace(spaceID, false) end)
			end
		end

		self._telemetry:span("addSpaceToScreen()", function()
			self._hsSpaces.addSpaceToScreen(mainScreen, true) end)

		local refreshedSpaces = self:_verify(mainScreen)

		self._activeSpace = refreshedSpaces[1]
		self._storageSpace = refreshedSpaces[2]

		return self._activeSpace, self._storageSpace
	end)
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

function NativeSpaceManager:_verify(mainScreen)
	local allSpaces = self._hsSpaces.allSpaces()
	local spaces = allSpaces[mainScreen]

	if not spaces then
		error(
			"VirtualSpaces setup failed: Unable to query spaces for main screen. " ..
			"Check System Preferences > Security & Privacy > Accessibility."
		)
	end

	if #spaces == TARGET_NUMBER_OF_SPACES then return spaces end

	error(string.format(
		"VirtualSpaces setup failed: Expected exactly %d spaces after setup, but found %d. Try reloading Hammerspoon.",
		TARGET_NUMBER_OF_SPACES, #spaces
	))
end

return NativeSpaceManager
