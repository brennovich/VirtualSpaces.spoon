local lu = require('luaunit')
local helpers = require('tests/test_helpers')
local WindowCache = require('WindowCache')

TestWindowCache = {}

function TestWindowCache:testGet_ReturnsCachedWindow()
    local cache = WindowCache.new()
    local mockWindow = {
        id = function() return 123 end
    }
    local windowId = 123

    cache:add(windowId, mockWindow)
    local result = cache:get(windowId)

    lu.assertEquals(result, mockWindow)
end

function TestWindowCache:testGet_InvalidWindow_ReturnsCachedWindowWithoutValidation()
    local cache = WindowCache.new()
    local mockInvalidWindow = {
        isStandard = function() return false end,
        id = function() return 123 end
    }
    local windowId = 123

    cache:add(windowId, mockInvalidWindow)
    local result = cache:get(windowId)

    lu.assertEquals(result, mockInvalidWindow)
end

function TestWindowCache:testGet_ErrorAccessingWindow_RemovesFromCacheAndReturnsNil()
    local cache = WindowCache.new()
    local mockStaleWindow = {
        id = function() error("window destroyed") end
    }
    local windowId = 123

    cache:add(windowId, mockStaleWindow)
    local result = cache:get(windowId)

    lu.assertIsNil(result)
end

function TestWindowCache:testGet_CacheMiss_CallsWindowGetAndCachesResult()
    local mockWindow = {
        id = function() return 123 end
    }
    local windowId = 123
    local windowGetCalled = false

    helpers.withHsGlobal({
        window = {
            get = function(id)
                windowGetCalled = true
                lu.assertEquals(id, windowId)
                return mockWindow
            end
        }
    }, function()
        local cache = WindowCache.new()
        local result = cache:get(windowId)

        lu.assertTrue(windowGetCalled)
        lu.assertEquals(result, mockWindow)

        local cachedResult = cache._cache[windowId]
        lu.assertEquals(cachedResult, mockWindow)
    end)
end

function TestWindowCache:testRemove_RemovesWindowFromCache()
    local cache = WindowCache.new()
    local mockWindow = {
        id = function() return 123 end
    }
    local windowId = 123

    cache:add(windowId, mockWindow)
    lu.assertNotNil(cache._cache[windowId])

    cache:remove(windowId)

    lu.assertIsNil(cache._cache[windowId])
end

return TestWindowCache
