local lu = require('luaunit')
local WindowCache = require('WindowCache')

TestWindowCache = {}

function TestWindowCache:testGet_ReturnsCachedWindow()
    local cache = WindowCache.new()
    local mockWindow = {
        isStandard = function() return true end
    }
    local windowId = 123

    cache:add(windowId, mockWindow)
    local result = cache:get(windowId)

    lu.assertEquals(result, mockWindow)
end

function TestWindowCache:testGet_InvalidWindow_RemovesFromCacheAndReturnsNil()
    local cache = WindowCache.new()
    local mockInvalidWindow = {
        isStandard = function() return false end
    }
    local windowId = 123

    cache:add(windowId, mockInvalidWindow)
    local result = cache:get(windowId)

    lu.assertIsNil(result)
end

function TestWindowCache:testGet_ErrorAccessingWindow_RemovesFromCacheAndReturnsNil()
    local cache = WindowCache.new()
    local mockStaleWindow = {
        isStandard = function() error("window destroyed") end
    }
    local windowId = 123

    cache:add(windowId, mockStaleWindow)
    local result = cache:get(windowId)

    lu.assertIsNil(result)
end

function TestWindowCache:testGet_CacheMiss_CallsWindowGetAndCachesResult()
    local mockWindow = {
        isStandard = function() return true end
    }
    local windowId = 123
    local windowGetCalled = false

    _G.hs = {
        window = {
            get = function(id)
                windowGetCalled = true
                lu.assertEquals(id, windowId)
                return mockWindow
            end
        }
    }

    local cache = WindowCache.new()
    local result = cache:get(windowId)

    lu.assertTrue(windowGetCalled)
    lu.assertEquals(result, mockWindow)

    local cachedResult = cache._cache[windowId]
    lu.assertEquals(cachedResult, mockWindow)

    _G.hs = nil
end

function TestWindowCache:testRemove_RemovesWindowFromCache()
    local cache = WindowCache.new()
    local mockWindow = {
        isStandard = function() return true end
    }
    local windowId = 123

    cache:add(windowId, mockWindow)
    lu.assertNotNil(cache._cache[windowId])

    cache:remove(windowId)

    lu.assertIsNil(cache._cache[windowId])
end

return TestWindowCache
