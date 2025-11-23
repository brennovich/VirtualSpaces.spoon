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

function WindowsSort:_isWindowInSpace(winId, targetSpaceId)
	if not self._windowSpaceGetter then
		return false
	end

	local spaces = self._windowSpaceGetter(winId)
	if not spaces then
		return false
	end

	for _, spaceId in ipairs(spaces) do
		if spaceId == targetSpaceId then
			return true
		end
	end

	return false
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
			if not self:_isWindowInSpace(winId, activeSpace) then
				self._telemetry:span(string.format("windowMoverFn(%d, toActive)", winId), function()
					self._windowMoverFn(winId, activeSpace)
				end)
			end
		end

		for _, winId in ipairs(categorizedWindows.toStorage) do
			if not self:_isWindowInSpace(winId, storageSpace) then
				self._telemetry:span(string.format("windowMoverFn(%d, toStorage)", winId), function()
					self._windowMoverFn(winId, storageSpace)
				end)
			end
		end

		if nativeSpaceSwitchHappened then
			for _, winId in ipairs(categorizedWindows.others) do
				if not self:_isWindowInSpace(winId, storageSpace) then
					self._telemetry:span(string.format("windowMoverFn(%d, others)", winId), function()
						self._windowMoverFn(winId, storageSpace)
					end)
				end
			end

			self._activeNativeSpaceId = activeSpace
			self._storageNativeSpaceId = storageSpace
		end

		return activeSpace, storageSpace
	end)
end

return WindowsSort
