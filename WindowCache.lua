local WindowCache = {}
WindowCache.__index = WindowCache

function WindowCache.new(telemetry)
    local self = setmetatable({}, WindowCache)
    self._cache = {}
    self._telemetry = telemetry or require('Telemetry').NoOp.new()
    return self
end

function WindowCache:add(windowId, window)
    self._cache[windowId] = window
end

function WindowCache:get(windowId)
    local cached = self._cache[windowId]

    if cached then
        local success = pcall(function()
            cached:id()
        end)

        if success then
            return cached
        else
            self:remove(windowId)
        end
    end

    if hs and hs.window then
        local window = hs.window.get(windowId)
        if window then
            self:add(windowId, window)
        end
        return window
    end

    return nil
end

function WindowCache:remove(windowId)
    self._cache[windowId] = nil
end

return WindowCache
