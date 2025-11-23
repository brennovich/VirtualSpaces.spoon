local lu = require('luaunit')
local h = require('tests/test_helpers')

local SpacesModel = require('SpacesModel')

TestSpacesModel = {}

function TestSpacesModel:testNew()
	local model = SpacesModel.new()

	lu.assertNotNil(model)
	lu.assertNotNil(model._focusedWindows)
end

function TestSpacesModel:testCurrentVirtualSpace()
	local cases = {
		{name = "initial value is 1", setValues = {}, expected = 1},
		{name = "set to 2", setValues = {2}, expected = 2},
		{name = "set to 3", setValues = {3}, expected = 3},
		{name = "multiple sets uses last", setValues = {2, 5, 3}, expected = 3},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		for _, val in ipairs(tc.setValues) do
			model:setCurrentVirtualSpace(val)
		end

		lu.assertEquals(model:getCurrentVirtualSpace(), tc.expected, tc.name)
	end
end

function TestSpacesModel:testFocusedWindowManagement()
	local cases = {
		{
			name = "save and get single window",
			saves = {{space = 1, window = 100}},
			expected = {{space = 1, window = 100}}
		},
		{
			name = "get from non-existent space returns nil",
			saves = {},
			expected = {{space = 999, window = nil}}
		},
		{
			name = "overwrite window in same space",
			saves = {{space = 1, window = 100}, {space = 1, window = 200}},
			expected = {{space = 1, window = 200}}
		},
		{
			name = "multiple virtual spaces",
			saves = {{space = 1, window = 100}, {space = 2, window = 200}, {space = 3, window = 300}},
			expected = {{space = 1, window = 100}, {space = 2, window = 200}, {space = 3, window = 300}}
		},
		{
			name = "save nil window",
			saves = {{space = 1, window = nil}},
			expected = {{space = 1, window = nil}}
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()
		for _, save in ipairs(tc.saves) do
			model:saveFocusedWindowInVirtualSpace(save.space, save.window)
		end

		for _, assertion in ipairs(tc.expected) do
			lu.assertEquals(model:getFocusedWindowForVirtualSpace(assertion.space), assertion.window, tc.name)
		end
	end
end

function TestSpacesModel:testWindowAssignment()
	local cases = {
		{
			name = "assign single window",
			assignments = {{window = 100, space = 1}},
			expected = {{window = 100, space = 1}}
		},
		{
			name = "multiple windows to same space",
			assignments = {{window = 100, space = 1}, {window = 200, space = 1}, {window = 300, space = 2}},
			expected = {{window = 100, space = 1}, {window = 200, space = 1}, {window = 300, space = 2}}
		},
		{
			name = "reassign window to different space",
			assignments = {{window = 100, space = 1}, {window = 100, space = 2}},
			expected = {{window = 100, space = 2}}
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		for _, assignment in ipairs(tc.assignments) do
			model:assignWindowToVirtualSpace(assignment.window, assignment.space)
		end

		for _, assertion in ipairs(tc.expected) do
			lu.assertEquals(model:getVirtualSpaceForWindow(assertion.window), assertion.space, tc.name)
		end
	end
end

function TestSpacesModel:testUnregisterWindowsById()
	local cases = {
		{
			name = "remove assigned window",
			assignment = {window = 100, space = 1},
			removals = {100},
			expected = 100
		},
		{
			name = "remove non-existent window",
			assignment = {},
			removals = {999},
			expected = 999
		},
		{
			name = "get non-existent window",
			assignment = {},
			removals = {},
			expected = 999
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		model:assignWindowToVirtualSpace(tc.assignment.window, tc.assignment.space)

		for _, windowId in ipairs(tc.removals) do
			model:unregisterWindowById(windowId)
		end

		lu.assertNil(model:getVirtualSpaceForWindow(tc.expected), tc.name)
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

function TestSpacesModel:testgetWindowsInVirtualSpaceWhenVirtualSpaceIsEmpty()
	local model = SpacesModel.new()

	local windows = model:getWindowsInVirtualSpace(1)

	lu.assertEquals(#windows, 0)
end

function TestSpacesModel:testReassignWindowRemovesFromOldSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(100, 2)

	spaceOneWindows = model:getWindowsInVirtualSpace(1)
	spaceTwoWindows = model:getWindowsInVirtualSpace(2)

	lu.assertEquals(#spaceOneWindows, 1)
	lu.assertTrue(table.contains(spaceOneWindows, 200))

	lu.assertEquals(#spaceTwoWindows, 1)
	lu.assertTrue(table.contains(spaceTwoWindows, 100))
	lu.assertTrue(table.contains(spaceTwoWindows, 100))
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

function TestSpacesModel:testRemoveWindowFromSpaceWithMultipleWindows()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(300, 1)
	model:unregisterWindowById(200)

	local windows = model:getWindowsInVirtualSpace(1)

	lu.assertEquals(#windows, 2)
	lu.assertFalse(table.contains(windows, 200))
	lu.assertTrue(table.contains(windows, 100))
	lu.assertTrue(table.contains(windows, 300))
end

function TestSpacesModel:testRemoveLastWindowLeavesSpaceEmpty()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:unregisterWindowById(100)

	lu.assertEquals(#model:getWindowsInVirtualSpace(1), 0)
end

function TestSpacesModel:testRemoveWindowCleansUpFocusedWindowReference()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:saveFocusedWindowInVirtualSpace(1, 100)

	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 100)

	model:unregisterWindowById(100)

	lu.assertNil(model:getFocusedWindowForVirtualSpace(1))
end

function TestSpacesModel:testRemoveWindowDoesNotAffectFocusedWindowInOtherSpaces()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 2)
	model:saveFocusedWindowInVirtualSpace(1, 100)
	model:saveFocusedWindowInVirtualSpace(2, 200)

	model:unregisterWindowById(100)

	lu.assertNil(model:getFocusedWindowForVirtualSpace(1))
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(2), 200)
end

function TestSpacesModel:testCategorizeWindowsWithNoWindows()
	local model = SpacesModel.new()

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 0)
	lu.assertEquals(#result.toStorage, 0)
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
	lu.assertEquals(#result.toStorage, 2)
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
end

function TestSpacesModel:testCategorizeWindowsWithOtherSpaces()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 3)
	model:assignWindowToVirtualSpace(200, 4)

	local result = model:categorizeWindowsForTransition(2, 1)

	lu.assertEquals(#result.toActive, 0)
	lu.assertEquals(#result.toStorage, 2)
	lu.assertTrue(table.contains(result.toStorage, 100))
	lu.assertTrue(table.contains(result.toStorage, 200))
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
	lu.assertEquals(#result.toStorage, 3)
	lu.assertTrue(table.contains(result.toStorage, 100))
	lu.assertTrue(table.contains(result.toStorage, 300))
	lu.assertTrue(table.contains(result.toStorage, 400))
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
	lu.assertEquals(#result.toStorage, 1)
	lu.assertTrue(table.contains(result.toStorage, 300))
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

function TestSpacesModel:testAssignWindowToSpaceWithSingleWindow()
	local model = SpacesModel.new()
	local window = h.createWindow(100, 1, {x = 0, y = 0, w = 800, h = 600}, "Safari")

	model:assignWindowToSpace(window, 1)

	lu.assertEquals(model:getVirtualSpaceForWindow(100), 1)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 100)
end

function TestSpacesModel:testAssignWindowToSpaceWithTabbedWindows()
	local model = SpacesModel.new()
	local window1 = h.createWindow(100, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")
	local window2 = h.createWindow(200, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")

	model:assignWindowToSpace(window1, 1)
	model:assignWindowToSpace(window2, 2)

	lu.assertEquals(model:getVirtualSpaceForWindow(100), 2)
	lu.assertEquals(model:getVirtualSpaceForWindow(200), 2)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(2), 200)
end

function TestSpacesModel:testAssignWindowToSpaceDoesNotReassignRegisteredWindow()
	local model = SpacesModel.new()
	local window = h.createSimpleWindow(100)

	model:assignWindowToSpace(window, 1)
	lu.assertEquals(model:getVirtualSpaceForWindow(100), 1)

	model:assignWindowToSpace(window, 2)
	lu.assertEquals(model:getVirtualSpaceForWindow(100), 1)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 100)
	lu.assertNil(model:getFocusedWindowForVirtualSpace(2))
end

function TestSpacesModel:testMoveWindowToVirtualSpaceMovesRegisteredWindow()
	local model = SpacesModel.new()
	local window = h.createSimpleWindow(100)

	model:assignWindowToSpace(window, 1)
	lu.assertEquals(model:getVirtualSpaceForWindow(100), 1)

	model:moveWindowToVirtualSpace(100, 2)

	lu.assertEquals(model:getVirtualSpaceForWindow(100), 2)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(2), 100)
	lu.assertEquals(#model:getWindowsInVirtualSpace(1), 0)
	lu.assertEquals(#model:getWindowsInVirtualSpace(2), 1)
end

function TestSpacesModel:testMoveWindowToVirtualSpaceMovesTabGroup()
	local model = SpacesModel.new()
	local window1 = h.createWindow(100, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")
	local window2 = h.createWindow(200, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")

	model:assignWindowToSpace(window1, 1)
	model:assignWindowToSpace(window2, 1)

	lu.assertEquals(model:getVirtualSpaceForWindow(100), 1)
	lu.assertEquals(model:getVirtualSpaceForWindow(200), 1)

	model:moveWindowToVirtualSpace(100, 3)

	lu.assertEquals(model:getVirtualSpaceForWindow(100), 3)
	lu.assertEquals(model:getVirtualSpaceForWindow(200), 3)
	lu.assertEquals(#model:getWindowsInVirtualSpace(1), 0)
	lu.assertEquals(#model:getWindowsInVirtualSpace(3), 2)
end

function TestSpacesModel:testTerminalAppTabsWithSlightlyDifferentYCoordinatesAreGroupedTogether()
	local model = SpacesModel.new()
	local window1 = h.createWindow(3426, 1, {x = 155.0, y = 30.0, w = 748.0, h = 879.0}, "Terminal")
	local window2 = h.createWindow(3459, 2, {x = 155.0, y = 21.0, w = 748.0, h = 879.0}, "Terminal")

	model:assignWindowToSpace(window1, 1)
	model:assignWindowToSpace(window2, 2)

	local tabGroup1 = model:getTabGroupForWindow(3426)
	local tabGroup2 = model:getTabGroupForWindow(3459)

	lu.assertNotNil(tabGroup1)
	lu.assertNotNil(tabGroup2)
	lu.assertEquals(#tabGroup1, 2)
	lu.assertTrue(table.contains(tabGroup1, 3426))
	lu.assertTrue(table.contains(tabGroup1, 3459))
	lu.assertEquals(model:getVirtualSpaceForWindow(3426), model:getVirtualSpaceForWindow(3459))
end

function TestSpacesModel:testUnregisterWindowByIdWithSingleWindow()
	local model = SpacesModel.new()
	local window = h.createSimpleWindow(100)

	model:assignWindowToSpace(window, 1)
	lu.assertNotNil(model._windowToGroup[100])

	model:unregisterWindowById(100)

	lu.assertNil(model._windowToGroup[100])
	lu.assertNil(model:getTabGroupForWindow(100))
end

function TestSpacesModel:testUnregisterWindowByIdFromTabGroupWithRemainingWindows()
	local model = SpacesModel.new()
	local window1 = h.createWindow(100, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")
	local window2 = h.createWindow(200, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")

	model:assignWindowToSpace(window1, 1)
	model:assignWindowToSpace(window2, 1)

	local tabGroupBefore = model:getTabGroupForWindow(100)
	lu.assertNotNil(tabGroupBefore)
	lu.assertEquals(#tabGroupBefore, 2)

	model:unregisterWindowById(100)

	lu.assertNil(model._windowToGroup[100])
	lu.assertNil(model:getTabGroupForWindow(100))

	local tabGroupAfter = model:getTabGroupForWindow(200)
	lu.assertNotNil(tabGroupAfter)
	lu.assertEquals(#tabGroupAfter, 1)
	lu.assertTrue(table.contains(tabGroupAfter, 200))
	lu.assertFalse(table.contains(tabGroupAfter, 100))
end

function TestSpacesModel:testUnregisterWindowByIdRemovesEmptyTabGroup()
	local model = SpacesModel.new()
	local window = h.createWindow(100, 2, {x = 0, y = 0, w = 800, h = 600}, "Safari")

	model:assignWindowToSpace(window, 1)

	local tabGroupBefore = model:getTabGroupForWindow(100)
	lu.assertNotNil(tabGroupBefore)

	model:unregisterWindowById(100)

	lu.assertNil(model._windowToGroup[100])
	lu.assertNil(model:getTabGroupForWindow(100))
end

function TestSpacesModel:testUnregisterWindowByIdWithNonExistentWindow()
	local model = SpacesModel.new()

	model:unregisterWindowById(999)

	lu.assertNil(model._windowToGroup[999])
end

return TestSpacesModel
