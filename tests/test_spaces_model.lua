local lu = require('luaunit')
require('tests/test_helpers')

local SpacesModel = require('SpacesModel')

TestSpacesModel = {}

function TestSpacesModel:testNew()
	local model = SpacesModel.new()

	lu.assertNotNil(model)
	lu.assertNotNil(model._focusedWindows)
end

function TestSpacesModel:testCurrentVirtualSpace()
	local cases = {
		{name = "initial value is 1", setValues = nil, expected = 1},
		{name = "set to 2", setValues = {2}, expected = 2},
		{name = "set to 3", setValues = {3}, expected = 3},
		{name = "multiple sets uses last", setValues = {2, 5, 3}, expected = 3},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		if tc.setValues then
			for _, val in ipairs(tc.setValues) do
				model:setCurrentVirtualSpace(val)
			end
		end

		lu.assertEquals(model:getCurrentVirtualSpace(), tc.expected, tc.name)
	end
end

function TestSpacesModel:testFocusedWindowManagement()
	local cases = {
		{
			name = "save and get single window",
			saves = {{space = 1, window = 100}},
			assertions = {{space = 1, expected = 100}}
		},
		{
			name = "get from non-existent space returns nil",
			saves = {},
			assertions = {{space = 999, expected = nil}}
		},
		{
			name = "overwrite window in same space",
			saves = {{space = 1, window = 100}, {space = 1, window = 200}},
			assertions = {{space = 1, expected = 200}}
		},
		{
			name = "multiple virtual spaces",
			saves = {{space = 1, window = 100}, {space = 2, window = 200}, {space = 3, window = 300}},
			assertions = {{space = 1, expected = 100}, {space = 2, expected = 200}, {space = 3, expected = 300}}
		},
		{
			name = "save nil window",
			saves = {{space = 1, window = nil}},
			assertions = {{space = 1, expected = nil}}
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		for _, save in ipairs(tc.saves) do
			model:saveFocusedWindowInVirtualSpace(save.space, save.window)
		end

		for _, assertion in ipairs(tc.assertions) do
			lu.assertEquals(model:getFocusedWindowForVirtualSpace(assertion.space), assertion.expected, tc.name)
		end
	end
end

function TestSpacesModel:testWindowAssignment()
	local cases = {
		{
			name = "assign single window",
			assignments = {{window = 100, space = 1}},
			assertions = {{window = 100, expected = 1}}
		},
		{
			name = "multiple windows to same space",
			assignments = {{window = 100, space = 1}, {window = 200, space = 1}, {window = 300, space = 2}},
			assertions = {{window = 100, expected = 1}, {window = 200, expected = 1}, {window = 300, expected = 2}}
		},
		{
			name = "reassign window to different space",
			assignments = {{window = 100, space = 1}, {window = 100, space = 2}},
			assertions = {{window = 100, expected = 2}}
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		for _, assignment in ipairs(tc.assignments) do
			model:assignWindowToVirtualSpace(assignment.window, assignment.space)
		end

		for _, assertion in ipairs(tc.assertions) do
			lu.assertEquals(model:getVirtualSpaceForWindow(assertion.window), assertion.expected, tc.name)
		end
	end
end

function TestSpacesModel:testWindowRemoval()
	local cases = {
		{
			name = "remove assigned window",
			assignments = {{window = 100, space = 1}},
			removals = {100},
			assertions = {{window = 100, expected = nil}}
		},
		{
			name = "remove non-existent window",
			assignments = {},
			removals = {999},
			assertions = {{window = 999, expected = nil}}
		},
		{
			name = "get non-existent window",
			assignments = {},
			removals = {},
			assertions = {{window = 999, expected = nil}}
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		for _, assignment in ipairs(tc.assignments) do
			model:assignWindowToVirtualSpace(assignment.window, assignment.space)
		end

		for _, windowId in ipairs(tc.removals) do
			model:removeWindow(windowId)
		end

		for _, assertion in ipairs(tc.assertions) do
			lu.assertNil(model:getVirtualSpaceForWindow(assertion.window), tc.name)
		end
	end
end

function TestSpacesModel:testGetWindowsInVirtualSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(300, 2)

	local windows = model:getWindowsInVirtualSpace(1)

	lu.assertEquals(#windows, 2)
	lu.assertTrue(table.contains(windows, 100))
	lu.assertTrue(table.contains(windows, 200))
end

function TestSpacesModel:testGetWindowsInEmptyVirtualSpace()
	local model = SpacesModel.new()

	local windows = model:getWindowsInVirtualSpace(1)

	lu.assertEquals(#windows, 0)
end

function TestSpacesModel:testReassignWindowRemovesFromOldSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(100, 2)

	local space1Windows = model:getWindowsInVirtualSpace(1)
	local space2Windows = model:getWindowsInVirtualSpace(2)

	lu.assertEquals(#space1Windows, 1)
	lu.assertTrue(table.contains(space1Windows, 200))
	lu.assertFalse(table.contains(space1Windows, 100))

	lu.assertEquals(#space2Windows, 1)
	lu.assertTrue(table.contains(space2Windows, 100))
end

function TestSpacesModel:testRemoveWindowFromSpaceWithMultipleWindows()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(300, 1)
	model:removeWindow(200)

	local windows = model:getWindowsInVirtualSpace(1)

	lu.assertEquals(#windows, 2)
	lu.assertTrue(table.contains(windows, 100))
	lu.assertTrue(table.contains(windows, 300))
	lu.assertFalse(table.contains(windows, 200))
end

function TestSpacesModel:testRemoveLastWindowLeavesSpaceEmpty()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:removeWindow(100)

	local windows = model:getWindowsInVirtualSpace(1)

	lu.assertEquals(#windows, 0)
end

function TestSpacesModel:testRemoveWindowCleansUpFocusedWindowReference()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:saveFocusedWindowInVirtualSpace(1, 100)

	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 100)

	model:removeWindow(100)

	lu.assertNil(model:getFocusedWindowForVirtualSpace(1))
end

function TestSpacesModel:testRemoveWindowDoesNotAffectFocusedWindowInOtherSpaces()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 2)
	model:saveFocusedWindowInVirtualSpace(1, 100)
	model:saveFocusedWindowInVirtualSpace(2, 200)

	model:removeWindow(100)

	lu.assertNil(model:getFocusedWindowForVirtualSpace(1))
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(2), 200)
end

function TestSpacesModel:testCategorizeWindowsWithNoWindows()
	local model = SpacesModel.new()

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 0)
	lu.assertEquals(#result.toStorage, 0)
	lu.assertEquals(#result.others, 0)
end

function TestSpacesModel:testCategorizeWindowsWithOnlyTargetSpaceWindows()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 2)
	model:assignWindowToVirtualSpace(200, 2)

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 2)
	lu.assertTrue(table.contains(result.toActive, 100))
	lu.assertTrue(table.contains(result.toActive, 200))
	lu.assertEquals(#result.toStorage, 0)
	lu.assertEquals(#result.others, 0)
end

function TestSpacesModel:testCategorizeWindowsWithOnlyCurrentSpaceWindows()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 0)
	lu.assertEquals(#result.toStorage, 2)
	lu.assertTrue(table.contains(result.toStorage, 100))
	lu.assertTrue(table.contains(result.toStorage, 200))
	lu.assertEquals(#result.others, 0)
end

function TestSpacesModel:testCategorizeWindowsWithBothSpaces()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 2)
	model:assignWindowToVirtualSpace(300, 1)

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 1)
	lu.assertTrue(table.contains(result.toActive, 200))
	lu.assertEquals(#result.toStorage, 2)
	lu.assertTrue(table.contains(result.toStorage, 100))
	lu.assertTrue(table.contains(result.toStorage, 300))
	lu.assertEquals(#result.others, 0)
end

function TestSpacesModel:testCategorizeWindowsWithOtherSpaces()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 3)
	model:assignWindowToVirtualSpace(200, 4)

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 0)
	lu.assertEquals(#result.toStorage, 0)
	lu.assertEquals(#result.others, 2)
	lu.assertTrue(table.contains(result.others, 100))
	lu.assertTrue(table.contains(result.others, 200))
end

function TestSpacesModel:testCategorizeWindowsWithAllThreeCategories()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 2)
	model:assignWindowToVirtualSpace(300, 3)
	model:assignWindowToVirtualSpace(400, 1)

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 1)
	lu.assertTrue(table.contains(result.toActive, 200))
	lu.assertEquals(#result.toStorage, 2)
	lu.assertTrue(table.contains(result.toStorage, 100))
	lu.assertTrue(table.contains(result.toStorage, 400))
	lu.assertEquals(#result.others, 1)
	lu.assertTrue(table.contains(result.others, 300))
end

function TestSpacesModel:testCategorizeWindowsWhenTargetEqualsCurrentSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(300, 2)

	local result = model:categorizeWindowsForTransition(1, 1)

	lu.assertEquals(#result.toActive, 2)
	lu.assertTrue(table.contains(result.toActive, 100))
	lu.assertTrue(table.contains(result.toActive, 200))
	lu.assertEquals(#result.toStorage, 0)
	lu.assertEquals(#result.others, 1)
	lu.assertTrue(table.contains(result.others, 300))
end

function TestSpacesModel:testReassignWindowToSameSpaceIsIdempotent()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)

	model:assignWindowToVirtualSpace(100, 1)

	local windows = model:getWindowsInVirtualSpace(1)

	local count100 = 0
	for _, winId in ipairs(windows) do
		if winId == 100 then
			count100 = count100 + 1
		end
	end

	lu.assertEquals(#windows, 2)
	lu.assertEquals(count100, 1)
	lu.assertTrue(table.contains(windows, 100))
	lu.assertTrue(table.contains(windows, 200))
end

function TestSpacesModel:testAssignWindowWithNilWindowId()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(nil, 1)

	lu.assertEquals(#model:getWindowsInVirtualSpace(1), 0)
end

function TestSpacesModel:testAssignWindowWithNilVirtualSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, nil)

	lu.assertNil(model:getVirtualSpaceForWindow(100))
end

function TestSpacesModel:testTerminalAppTabsWithSlightlyDifferentYCoordinatesAreGroupedTogether()
	local model = SpacesModel.new()

	local window1 = {
		id = function() return 3426 end,
		tabCount = function() return 1 end,
		frame = function() return {x = 155.0, y = 30.0, w = 748.0, h = 879.0} end,
		application = function() return {name = function() return "Terminal" end} end
	}

	local window2 = {
		id = function() return 3459 end,
		tabCount = function() return 2 end,
		frame = function() return {x = 155.0, y = 21.0, w = 748.0, h = 879.0} end,
		application = function() return {name = function() return "Terminal" end} end
	}

	model:registerWindowObject(window1)
	model:registerWindowObject(window2)

	local tabGroup1 = model:getTabGroupForWindow(3426)
	local tabGroup2 = model:getTabGroupForWindow(3459)

	lu.assertNotNil(tabGroup1, "Window 3426 should be in a tab group")
	lu.assertNotNil(tabGroup2, "Window 3459 should be in a tab group")
	lu.assertEquals(#tabGroup1, 2, "Tab group should contain 2 windows")
	lu.assertTrue(table.contains(tabGroup1, 3426), "Tab group should contain window 3426")
	lu.assertTrue(table.contains(tabGroup1, 3459), "Tab group should contain window 3459")
end

return TestSpacesModel
