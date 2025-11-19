local lu = require("luaunit")
local TabbedWindows = require("TabbedWindows")

TestTabbedWindows = {}

function TestTabbedWindows:testSingleWindowWithoutTabsIsNotTracked()
	local tracker = TabbedWindows.new()

	local mockWindow = {
		id = function() return 1 end,
		tabCount = function() return 1 end,
		frame = function() return { x = 100, y = 100, w = 800, h = 600 } end,
		application = function() return { name = function() return "Ghostty" end } end
	}

	tracker:onWindowCreated(mockWindow)

	local tabGroup = tracker:getTabGroupForWindow(1)
	lu.assertIsNil(tabGroup)
end

function TestTabbedWindows:testWindowWithMultipleTabsCreatesTabGroup()
	local tracker = TabbedWindows.new()

	local mockWindow = {
		id = function() return 1 end,
		tabCount = function() return 2 end,
		frame = function() return { x = 100, y = 100, w = 800, h = 600 } end,
		application = function() return { name = function() return "Ghostty" end } end
	}

	tracker:onWindowCreated(mockWindow)

	local tabGroup = tracker:getTabGroupForWindow(1)
	lu.assertNotNil(tabGroup)
	lu.assertEquals(#tabGroup, 1)
	lu.assertEquals(tabGroup[1], 1)
end

function TestTabbedWindows:testSecondTabJoinsExistingGroup()
	local tracker = TabbedWindows.new()

	local mockApp = { name = function() return "Ghostty" end }
	local frame = { x = 100, y = 100, w = 800, h = 600 }

	local firstTab = {
		id = function() return 1 end,
		tabCount = function() return 2 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	local secondTab = {
		id = function() return 2 end,
		tabCount = function() return 2 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	tracker:onWindowCreated(firstTab)
	tracker:onWindowCreated(secondTab)

	local tabGroup1 = tracker:getTabGroupForWindow(1)
	local tabGroup2 = tracker:getTabGroupForWindow(2)

	lu.assertEquals(#tabGroup1, 2)
	lu.assertEquals(#tabGroup2, 2)
	lu.assertEquals(tabGroup1[1], 1)
	lu.assertEquals(tabGroup1[2], 2)
	lu.assertEquals(tabGroup2[1], 1)
	lu.assertEquals(tabGroup2[2], 2)
end

function TestTabbedWindows:testWindowDestructionRemovesFromTabGroup()
	local tracker = TabbedWindows.new()

	local mockApp = { name = function() return "Ghostty" end }
	local frame = { x = 100, y = 100, w = 800, h = 600 }

	local firstTab = {
		id = function() return 1 end,
		tabCount = function() return 2 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	local secondTab = {
		id = function() return 2 end,
		tabCount = function() return 2 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	tracker:onWindowCreated(firstTab)
	tracker:onWindowCreated(secondTab)
	tracker:onWindowDestroyed(2)

	local tabGroup1 = tracker:getTabGroupForWindow(1)
	local tabGroup2 = tracker:getTabGroupForWindow(2)

	lu.assertNotNil(tabGroup1)
	lu.assertEquals(#tabGroup1, 1)
	lu.assertEquals(tabGroup1[1], 1)
	lu.assertIsNil(tabGroup2)
end

function TestTabbedWindows:testGetTabSiblingsBeforeDestruction()
	local tracker = TabbedWindows.new()

	local mockApp = { name = function() return "Ghostty" end }
	local frame = { x = 100, y = 100, w = 800, h = 600 }

	local firstTab = {
		id = function() return 1 end,
		tabCount = function() return 3 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	local secondTab = {
		id = function() return 2 end,
		tabCount = function() return 3 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	local thirdTab = {
		id = function() return 3 end,
		tabCount = function() return 3 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	tracker:onWindowCreated(firstTab)
	tracker:onWindowCreated(secondTab)
	tracker:onWindowCreated(thirdTab)

	local siblings = tracker:getTabSiblingsBeforeDestruction(2)

	lu.assertNotNil(siblings)
	lu.assertEquals(#siblings, 2)
	lu.assertTrue(siblings[1] == 1 or siblings[1] == 3)
	lu.assertTrue(siblings[2] == 1 or siblings[2] == 3)
end

function TestTabbedWindows:testRetroactivelyGroupsExistingSingleTab()
	local tracker = TabbedWindows.new()

	local mockApp = { name = function() return "Ghostty" end }
	local frame = { x = 100, y = 100, w = 800, h = 600 }

	local firstTab = {
		id = function() return 1 end,
		tabCount = function() return 1 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	local secondTab = {
		id = function() return 2 end,
		tabCount = function() return 2 end,
		frame = function() return frame end,
		application = function() return mockApp end
	}

	tracker:onWindowCreated(firstTab)
	tracker:onWindowCreated(secondTab)

	local tabGroup1 = tracker:getTabGroupForWindow(1)
	local tabGroup2 = tracker:getTabGroupForWindow(2)

	lu.assertNotNil(tabGroup1)
	lu.assertNotNil(tabGroup2)
	lu.assertEquals(#tabGroup1, 2)
	lu.assertEquals(#tabGroup2, 2)
end

return TestTabbedWindows
