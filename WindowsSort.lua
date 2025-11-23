local Telemetry = require("Telemetry")

local WindowsSort = {}
WindowsSort.__index = WindowsSort

function WindowsSort.new(activeNativeSpaceId, storageNativeSpaceId, deps)
	deps = deps or {}
	local self = setmetatable({}, WindowsSort)
	self._activeNativeSpaceId = activeNativeSpaceId
	self._storageNativeSpaceId = storageNativeSpaceId

	self._windowMoverFn = deps.windowMoverFn or hs.spaces.moveWindowToSpace
	self._windowSpaceGetter = deps.windowSpaceGetter or hs.spaces.windowSpaces

	self._telemetry = deps.telemetry or Telemetry.NoOp.new()
	return self
end

function WindowsSort:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, currentNativeSpace)
	return self._telemetry:span("mapWindowsToNativeSpaces", function()
		if currentNativeSpace == self._storageNativeSpaceId then
			self._activeNativeSpaceId, self._storageNativeSpaceId = self._storageNativeSpaceId, self._activeNativeSpaceId
		end

		for _, winId in ipairs(categorizedWindows.toActive) do
			if not self:_isWindowInSpace(winId, self._activeNativeSpaceId) then
				self._telemetry:span(string.format("windowMoverFn(%d, toActive)", winId), function()
					self._windowMoverFn(winId, self._activeNativeSpaceId)
				end)
			end
		end

		for _, winId in ipairs(categorizedWindows.toStorage) do
			if not self:_isWindowInSpace(winId, self._storageNativeSpaceId) then
				self._telemetry:span(string.format("windowMoverFn(%d, toStorage)", winId), function()
					self._windowMoverFn(winId, self._storageNativeSpaceId)
				end)
			end
		end

		return self._activeNativeSpaceId, self._storageNativeSpaceId
	end)
end

function WindowsSort:_isWindowInSpace(winId, targetSpaceId)
	for _, spaceId in ipairs(self._windowSpaceGetter(winId) or {}) do
		if spaceId == targetSpaceId then
			return true
		end
	end

	return false
end


return WindowsSort
