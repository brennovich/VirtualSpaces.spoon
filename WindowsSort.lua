local Telemetry = require("Telemetry")

local WindowsSort = {}
WindowsSort.__index = WindowsSort

function WindowsSort.new(windowMoverFn, activeNativeSpaceId, storageNativeSpaceId, telemetry)
	local self = setmetatable({}, WindowsSort)
	self._windowMoverFn = windowMoverFn
	self._activeNativeSpaceId = activeNativeSpaceId
	self._storageNativeSpaceId = storageNativeSpaceId
	self._telemetry = telemetry or Telemetry.NoOp.new()
	return self
end

function WindowsSort:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, currentNativeSpace)
	return self._telemetry:span("mapWindowsToNativeSpaces", function()
		local nativeSpaceSwitchHappened = currentNativeSpace == self._storageNativeSpaceId
		local activeSpace = self._activeNativeSpaceId
		local storageSpace = self._storageNativeSpaceId

		if nativeSpaceSwitchHappened then
			activeSpace, storageSpace = storageSpace, activeSpace
		end

		for _, winId in ipairs(categorizedWindows.toActive) do
			self._telemetry:span("windowMoverFn(toActive)", function()
				self._windowMoverFn(winId, activeSpace)
			end)
		end

		for _, winId in ipairs(categorizedWindows.toStorage) do
			self._telemetry:span("windowMoverFn(toStorage)", function()
				self._windowMoverFn(winId, storageSpace)
			end)
		end

		if nativeSpaceSwitchHappened then
			for _, winId in ipairs(categorizedWindows.others) do
				self._telemetry:span("windowMoverFn(others)", function()
					self._windowMoverFn(winId, storageSpace)
				end)
			end

			self._activeNativeSpaceId = activeSpace
			self._storageNativeSpaceId = storageSpace
		end

		return activeSpace, storageSpace
	end)
end

return WindowsSort
