local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local WindowsSort = require('WindowsSort')

TestWindowsSort = {}

function TestWindowsSort:testNew()
	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps())

	lu.assertEquals(sorter._activeNativeSpaceId, "active-123")
	lu.assertEquals(sorter._storageNativeSpaceId, "storage-456")
	lu.assertNotNil(sorter._telemetry)
end

function TestWindowsSort:testNewWithCustomDeps()
	local mockMover = function() end
	local mockGetter = function() end
	local mockTelemetry = {}

	local sorter = WindowsSort.new("active-123", "storage-456", {
		windowMoverFn = mockMover,
		windowSpaceGetter = mockGetter,
		telemetry = mockTelemetry
	})

	lu.assertEquals(sorter._windowMoverFn, mockMover)
	lu.assertEquals(sorter._windowSpaceGetter, mockGetter)
	lu.assertEquals(sorter._telemetry, mockTelemetry)
end

function TestWindowsSort:testMovesTargetVirtualSpaceWindowsToActiveSpace()
	local tracker = helpers.createMoveTracker()
	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = tracker.record}))

	local categorizedWindows = {
		toActive = {200, 300},
		toStorage = {100},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "active-123")

	local win2Move = tracker.findMove(200)
	local win3Move = tracker.findMove(300)

	lu.assertNotNil(win2Move)
	lu.assertNotNil(win3Move)
	lu.assertEquals(win2Move.spaceId, "active-123")
	lu.assertEquals(win3Move.spaceId, "active-123")
end

function TestWindowsSort:testMovesCurrentVirtualSpaceWindowsToStorageSpace()
	local tracker = helpers.createMoveTracker()
	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = tracker.record}))

	local categorizedWindows = {
		toActive = {200},
		toStorage = {100},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "active-123")

	local win1Move = tracker.findMove(100)

	lu.assertNotNil(win1Move)
	lu.assertEquals(win1Move.spaceId, "storage-456")
end

function TestWindowsSort:testSwapsSpacesWhenCurrentNativeSpaceIsStorage()
	local mockMover = function() end

	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = mockMover}))

	local categorizedWindows = {
		toActive = {200},
		toStorage = {100},
	}

	local newActive, newStorage = sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(
		categorizedWindows, "storage-456"
	)

	lu.assertEquals(newActive, "storage-456")
	lu.assertEquals(newStorage, "active-123")
end

function TestWindowsSort:testMovesWindowsToFormarActiveSpaceWhenSwapping()
	local tracker = helpers.createMoveTracker()
	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = tracker.record}))

	local categorizedWindows = {
		toActive = {200},
		toStorage = {100, 300},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "storage-456")

	local win3Move = tracker.findMove(300)
	local win1Move = tracker.findMove(100)

	lu.assertNotNil(win3Move)
	lu.assertEquals(win3Move.spaceId, "active-123")
	lu.assertNotNil(win1Move)
	lu.assertEquals(win1Move.spaceId, "active-123")
end

function TestWindowsSort:testDoesNotSwapWhenCurrentNativeSpaceIsActive()
	local mockMover = function() end

	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = mockMover}))

	local categorizedWindows = {
		toActive = {},
		toStorage = {},
	}

	local newActive, newStorage = sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(
		categorizedWindows, "active-123"
	)

	lu.assertEquals(newActive, "active-123")
	lu.assertEquals(newStorage, "storage-456")
end

function TestWindowsSort:testHandlesEmptyWindowMap()
	local tracker = helpers.createMoveTracker()
	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = tracker.record}))

	local categorizedWindows = {
		toActive = {},
		toStorage = {},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "active-123")

	lu.assertEquals(tracker.count(), 0)
end

function TestWindowsSort:testPersistsSwappedSpacesInInstance()
	local mockMover = function() end

	local sorter = WindowsSort.new("active-123", "storage-456", helpers.createBasicDeps({windowMoverFn = mockMover}))

	local categorizedWindows = {
		toActive = {},
		toStorage = {},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "storage-456")

	lu.assertEquals(sorter._activeNativeSpaceId, "storage-456")
	lu.assertEquals(sorter._storageNativeSpaceId, "active-123")
end

function TestWindowsSort:testSkipsWindowMoveWhenWindowAlreadyInTargetSpace()
	local tracker = helpers.createMoveTracker()

	local mockSpaceGetter = function(winId)
		if winId == 200 then
			return {"active-123"}
		elseif winId == 100 then
			return {"storage-456"}
		end
		return {}
	end

	local sorter = WindowsSort.new("active-123", "storage-456", {
		windowMoverFn = tracker.record,
		windowSpaceGetter = mockSpaceGetter
	})

	local categorizedWindows = {
		toActive = {200},
		toStorage = {100},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "active-123")

	lu.assertEquals(tracker.count(), 0)
end

function TestWindowsSort:testMovesWindowWhenWindowNotInTargetSpace()
	local tracker = helpers.createMoveTracker()

	local mockSpaceGetter = function(winId)
		if winId == 200 then
			return {"storage-456"}
		end
		return {}
	end

	local sorter = WindowsSort.new("active-123", "storage-456", {
		windowMoverFn = tracker.record,
		windowSpaceGetter = mockSpaceGetter
	})

	local categorizedWindows = {
		toActive = {200},
		toStorage = {},
	}

	sorter:mapWindowsToNativeSpacesFromCurrentNativeSpace(categorizedWindows, "active-123")

	lu.assertEquals(tracker.count(), 1)
	local win2Move = tracker.findMove(200)
	lu.assertNotNil(win2Move)
	lu.assertEquals(win2Move.spaceId, "active-123")
end

return TestWindowsSort
