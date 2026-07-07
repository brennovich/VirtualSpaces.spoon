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
		{name = "remove assigned window", assigned = true, windowId = 100},
		{name = "remove non-existent window", assigned = false, windowId = 999},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()
		if tc.assigned then
			model:assignWindowToVirtualSpace(tc.windowId, 1)
		end

		model:unregisterWindowById(tc.windowId)

		lu.assertNil(model:getVirtualSpaceForWindow(tc.windowId), tc.name)
	end
end

function TestSpacesModel:testGetWindowsInVirtualSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(300, 2)

	lu.assertEquals(model:getWindowsInVirtualSpace(1), {100, 200})
	lu.assertEquals(model:getWindowsInVirtualSpace(3), {})
end

function TestSpacesModel:testReassignWindowRemovesFromOldSpace()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(100, 2)

	lu.assertEquals(model:getWindowsInVirtualSpace(1), {200})
	lu.assertEquals(model:getWindowsInVirtualSpace(2), {100})
end

function TestSpacesModel:testReassignWindowToSameSpaceIsIdempotent()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(100, 1)

	lu.assertEquals(model:getWindowsInVirtualSpace(1), {100, 200})
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

function TestSpacesModel:testFocusHistoryMaintainsOrder()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)
	model:assignWindowToVirtualSpace(300, 1)

	model:saveFocusedWindowInVirtualSpace(1, 100)
	model:saveFocusedWindowInVirtualSpace(1, 200)
	model:saveFocusedWindowInVirtualSpace(1, 300)

	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 300)

	model:unregisterWindowById(300)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 200)

	model:unregisterWindowById(200)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 100)
end

function TestSpacesModel:testFocusHistoryNoDuplicates()
	local model = SpacesModel.new()

	model:assignWindowToVirtualSpace(100, 1)
	model:assignWindowToVirtualSpace(200, 1)

	model:saveFocusedWindowInVirtualSpace(1, 100)
	model:saveFocusedWindowInVirtualSpace(1, 200)
	model:saveFocusedWindowInVirtualSpace(1, 100)

	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 100)

	model:unregisterWindowById(100)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), 200)
end

function TestSpacesModel:testCategorizeWindowsForTransition()
	local cases = {
		{
			name = "no windows",
			assignments = {},
			target = 2,
			toActive = {},
			toStorage = {},
		},
		{
			name = "only target space windows",
			assignments = {{window = 100, space = 2}, {window = 200, space = 2}},
			target = 2,
			toActive = {100, 200},
			toStorage = {},
		},
		{
			name = "only current space windows",
			assignments = {{window = 100, space = 1}, {window = 200, space = 1}},
			target = 2,
			toActive = {},
			toStorage = {100, 200},
		},
		{
			name = "windows in both spaces",
			assignments = {{window = 100, space = 1}, {window = 200, space = 2}, {window = 300, space = 1}},
			target = 2,
			toActive = {200},
			toStorage = {100, 300},
		},
		{
			name = "windows in other spaces go to storage",
			assignments = {{window = 100, space = 3}, {window = 200, space = 4}},
			target = 2,
			toActive = {},
			toStorage = {100, 200},
		},
		{
			name = "target, current and other spaces",
			assignments = {{window = 100, space = 1}, {window = 200, space = 2}, {window = 300, space = 3}, {window = 400, space = 1}},
			target = 2,
			toActive = {200},
			toStorage = {100, 300, 400},
		},
		{
			name = "target equals current space",
			assignments = {{window = 100, space = 1}, {window = 200, space = 1}, {window = 300, space = 2}},
			target = 1,
			toActive = {100, 200},
			toStorage = {300},
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()
		for _, assignment in ipairs(tc.assignments) do
			model:assignWindowToVirtualSpace(assignment.window, assignment.space)
		end

		local result = model:categorizeWindowsForTransition(tc.target)

		lu.assertEquals(#result.toActive, #tc.toActive, tc.name)
		for _, winId in ipairs(tc.toActive) do
			lu.assertTrue(table.contains(result.toActive, winId), tc.name)
		end
		lu.assertEquals(#result.toStorage, #tc.toStorage, tc.name)
		for _, winId in ipairs(tc.toStorage) do
			lu.assertTrue(table.contains(result.toStorage, winId), tc.name)
		end
	end
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

function TestSpacesModel:testAssignWindowToSpaceClearsFocusedWindowAndVirtualSpaceEntry()
	local model = SpacesModel.new()
	local window = h.createWindow(100)

	model:assignWindowToSpace(window, 1)
	lu.assertEquals(model:getVirtualSpaceForWindow(window.id), 1)

	model:assignWindowToSpace(window, 2)
	lu.assertEquals(model:getFocusedWindowForVirtualSpace(2), window.id)
	lu.assertNil(model:getFocusedWindowForVirtualSpace(1))
	lu.assertEquals(model:getVirtualSpaceForWindow(window.id), 2)
end

function TestSpacesModel:testMoveWindowToVirtualSpaceMovesRegisteredWindow()
	local model = SpacesModel.new()
	local window = h.createWindow(100)

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
	local window = h.createWindow(100)

	model:assignWindowToSpace(window, 1)
	lu.assertNotNil(model:getTabGroupForWindow(100))

	model:unregisterWindowById(100)

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

	lu.assertNil(model:getTabGroupForWindow(100))
end

function TestSpacesModel:testUnregisterWindowByIdWithNonExistentWindow()
	local model = SpacesModel.new()

	model:unregisterWindowById(999)

	lu.assertNil(model:getTabGroupForWindow(999))
end

function TestSpacesModel:testEligibleWindowToBeFocused()
	local cases = {
		{
			name = "returns saved focused window when using assignWindowToSpace flow",
			targetSpace = 1,
			setup = function(model)
				model:assignWindowToSpace(h.createWindow(46), 1)
				model:assignWindowToSpace(h.createWindow(1375), 1)
				model:saveFocusedWindowInVirtualSpace(1, 1375)
			end,
			expectedWindowId = 1375,
			expectedFocusedWindowId = 1375,
		},
		{
			name = "returns saved focused window when still in current virtual space",
			targetSpace = 1,
			setup = function(model)
				model:assignWindowToVirtualSpace(100, 1)
				model:assignWindowToVirtualSpace(200, 1)
				model:saveFocusedWindowInVirtualSpace(1, 200)
			end,
			expectedWindowId = 200,
			expectedFocusedWindowId = 200,
		},
		{
			name = "returns first window when no saved focus",
			targetSpace = 1,
			setup = function(model)
				model:assignWindowToVirtualSpace(100, 1)
				model:assignWindowToVirtualSpace(200, 1)
			end,
			expectedWindowId = 100,
			expectedFocusedWindowId = 100,
		},
		{
			name = "returns first window when saved focus is in different virtual space",
			targetSpace = 1,
			setup = function(model)
				model:assignWindowToVirtualSpace(100, 1)
				model:assignWindowToVirtualSpace(200, 2)
				lu.assertNil(model:getFocusedWindowForVirtualSpace(1))
				model:saveFocusedWindowInVirtualSpace(1, 200)
			end,
			expectedWindowId = 100,
			expectedFocusedWindowId = 100,
		},
		{
			name = "skips focus-history entries that moved to another virtual space",
			targetSpace = 1,
			setup = function(model)
				model:assignWindowToVirtualSpace(100, 1)
				model:assignWindowToVirtualSpace(200, 1)
				model:assignWindowToVirtualSpace(300, 1)
				model:saveFocusedWindowInVirtualSpace(1, 100)
				model:saveFocusedWindowInVirtualSpace(1, 200)
				model:saveFocusedWindowInVirtualSpace(1, 300)
				model:assignWindowToVirtualSpace(300, 2)
			end,
			expectedWindowId = 200,
			expectedFocusedWindowId = 200,
		},
		{
			name = "returns nil when no windows in virtual space",
			targetSpace = 1,
			setup = function(_)end,
			expectedWindowId = nil,
			expectedFocusedWindowId = nil,
		},
		{
			name = "returns nil when windows exist but in other virtual spaces",
			targetSpace = 1,
			setup = function(model)
				model:assignWindowToVirtualSpace(100, 2)
				model:setCurrentVirtualSpace(1)
			end,
			expectedWindowId = nil,
			expectedFocusedWindowId = nil,
		},
	}

	for _, tc in ipairs(cases) do
		local model = SpacesModel.new()

		tc.setup(model)
		model:setCurrentVirtualSpace(tc.targetSpace)

		local windowId = model:prepareWindowToBeFocusedOnCurrentVirtualSpace()

		lu.assertEquals(model:getFocusedWindowForVirtualSpace(1), tc.expectedFocusedWindowId, tc.name)
		lu.assertEquals(windowId, tc.expectedWindowId, tc.name)
	end
end

return TestSpacesModel
