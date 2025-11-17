local WindowsSort = {}
WindowsSort.__index = WindowsSort

function WindowsSort.new(windowMoverFn, activeNativeSpaceId, storageNativeSpaceId, instrumentation)
	local self = setmetatable({}, WindowsSort)
	self._windowMoverFn = windowMoverFn
	self._activeNativeSpaceId = activeNativeSpaceId
	self._storageNativeSpaceId = storageNativeSpaceId
	self._instrumentation = instrumentation
	return self
end

function WindowsSort:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, currentNativeSpace)
	local nativeSpaceSwitchHappened = currentNativeSpace == self._storageNativeSpaceId
	local activeSpace = self._activeNativeSpaceId
	local storageSpace = self._storageNativeSpaceId

	if nativeSpaceSwitchHappened then
		activeSpace, storageSpace = storageSpace, activeSpace
	end

	for _, winId in ipairs(categorizedWindows.toActive) do
		self:_timedCall("windowMoverFn(toActive)", function()
			self._windowMoverFn(winId, activeSpace)
		end)
	end

	for _, winId in ipairs(categorizedWindows.toStorage) do
		self:_timedCall("windowMoverFn(toStorage)", function()
			self._windowMoverFn(winId, storageSpace)
		end)
	end

	if nativeSpaceSwitchHappened then
		for _, winId in ipairs(categorizedWindows.others) do
			self:_timedCall("windowMoverFn(others)", function()
				self._windowMoverFn(winId, storageSpace)
			end)
		end

		self._activeNativeSpaceId = activeSpace
		self._storageNativeSpaceId = storageSpace
	end

	return activeSpace, storageSpace
end

function WindowsSort:_timedCall(operationName, fn)
	if not self._instrumentation then
		return fn()
	end
	return self._instrumentation:timed(operationName, fn)
end

return WindowsSort
