local WindowCache = {}
WindowCache.__index = WindowCache

function WindowCache.new(telemetry, deps)
	local self = setmetatable({}, WindowCache)
	local deps = deps or {}

	self._cache = {}
	self._hsWindow = deps.hsWindow or hs.window
	self._telemetry = telemetry or require('Telemetry').NoOp.new()

	return self
end

function WindowCache:add(window)
	self._cache[window:id()] = window
	return window
end

function WindowCache:get(windowId)
	local cached = self._cache[windowId]

	if cached then
		if pcall(function() cached:id() end) then return cached end

		self:remove(windowId)
	end

	local window = self._hsWindow.get(windowId)
	if window then return self:add(window) end

	return nil
end

function WindowCache:remove(windowId)
	self._cache[windowId] = nil
end

return WindowCache
