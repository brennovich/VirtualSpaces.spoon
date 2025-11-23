local lu = require('luaunit')
local helpers = require('tests/test_helpers')
local WindowCache = require('WindowCache')

TestWindowCache = {}

function TestWindowCache:testGetCachedWindow()
    local callCount = 0
    local cases = {
        {
            name = "returns cached window",
            mockWindow = { id = function() return 123 end },
            expected = 123,
            remainsInCache = true,
        },
        {
            name = "returns invalid window without validation",
            mockWindow = {
                isStandard = function() return false end,
                id = function() return 123 end
            },
            expected = 123,
            remainsInCache = true,
        },
        {
            name = "returns nil and removes stale window that errors on access",
            mockWindow = {
                id = function()
                    callCount = callCount + 1
                    if callCount == 1 then return 123 end
                    error("window destroyed")
                end
            },
            expectedResult = nil,
            remainsInCache = false,
        },
    }

    for _, tc in ipairs(cases) do
        local cache = WindowCache.new()

        cache:add(tc.mockWindow)
        local result = cache:get(123)

        lu.assertEquals(result and result:id() or nil, tc.expected, tc.name)
        lu.assertEquals(cache._cache[123] ~= nil, tc.remainsInCache, tc.name .. " - cache state")
    end
end

function TestWindowCache:testGetCacheMissCallsWindowGet()
    local mockWindow = { id = function() return 123 end }
    local windowGetCalled = false

    helpers.withHsGlobal({
        window = {
            get = function(id)
                windowGetCalled = true
                lu.assertEquals(id, 123)
                return mockWindow
            end
        }
    }, function()
        local cache = WindowCache.new()

        local result = cache:get(123)

        lu.assertTrue(windowGetCalled)
        lu.assertEquals(result, mockWindow)
        lu.assertEquals(cache._cache[123], mockWindow)
    end)
end

function TestWindowCache:testRemove()
    local cache = WindowCache.new()
    local mockWindow = { id = function() return 123 end }

    cache:add(mockWindow)
    lu.assertNotNil(cache._cache[123])

    cache:remove(123)

    lu.assertIsNil(cache._cache[123])
end

return TestWindowCache
