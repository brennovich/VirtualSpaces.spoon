local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local NativeSpace = require('NativeSpace')

TestNativeSpace = {}

local function mockedNativeSpace(options)
	options = options or {}
	local screenUUID = options.screenUUID or "screen-uuid-123"
	local initialSpaces = options.initialSpaces or {"space-1", "space-2"}
	local finalSpaces = options.finalSpaces or initialSpaces
	local activeSpace = options.activeSpace or "space-1"

	local initialAllSpacesData = {}
	initialAllSpacesData[screenUUID] = initialSpaces

	local finalAllSpacesData = {}
	finalAllSpacesData[screenUUID] = finalSpaces

	local removedSpaces, addSpaceCalls = {}, {}
	local counters = {
		allSpacesCalls = 0,
		openMissionControlCalls = 0
	}

	local mockScreen = {
		mainScreen = function() return { getUUID = function() return screenUUID end } end
	}

	local movedWindows, windowSpacesCalls = {}, {}
	local watcherCallback, watcherStartCalls = nil, 0

	local mockSpaces = {
		activeSpaceOnScreen = function() return activeSpace end,
		allSpaces = function()
			counters.allSpacesCalls = counters.allSpacesCalls + 1
			if counters.allSpacesCalls == 1 then
				return initialAllSpacesData
			else
				return finalAllSpacesData
			end
		end,
		removeSpace = function(spaceId, destroyMC)
			table.insert(removedSpaces, {id = spaceId, destroyMC = destroyMC})
		end,
		openMissionControl = function()
			counters.openMissionControlCalls = counters.openMissionControlCalls + 1
		end,
		addSpaceToScreen = function(screenUUID, toEnd)
			table.insert(addSpaceCalls, {screen = screenUUID, toEnd = toEnd})
		end,
		moveWindowToSpace = function(winId, spaceId)
			table.insert(movedWindows, {winId = winId, spaceId = spaceId})
		end,
		windowSpaces = function(winId)
			table.insert(windowSpacesCalls, winId)
			return {activeSpace}
		end,
		watcher = {
			new = function(callback)
				watcherCallback = callback
				return {
					start = function() watcherStartCalls = watcherStartCalls + 1 end
				}
			end
		}
	}

	return NativeSpace.new({
		hsSpaces = mockSpaces,
		hsScreen = mockScreen,
	}), {
		screenUUID = screenUUID,
		removedSpaces = removedSpaces,
		counters = counters,
		addSpaceCalls = addSpaceCalls,
		movedWindows = movedWindows,
		windowSpacesCalls = windowSpacesCalls,
		fireWatcher = function() watcherCallback() end,
		watcherStartCalls = function() return watcherStartCalls end,
		setActiveSpace = function(newActiveSpace) activeSpace = newActiveSpace end,
	}
end

function TestNativeSpace:testNew()
	local space = NativeSpace.new({
		hsSpaces = {},
		hsScreen = {},
		telemetry = {}
	})

	lu.assertNotNil(space)
	lu.assertEquals(space._hsSpaces, {})
	lu.assertEquals(space._hsScreen, {})
	lu.assertEquals(space._telemetry, {})
end

function TestNativeSpace:testNewWithDefaults()
	helpers.withHsGlobal({}, function()
		local space = NativeSpace.new()

		lu.assertNotNil(space)
		lu.assertNotNil(space._telemetry)

		lu.assertNil(space:getActiveSpace())
		lu.assertNil(space:getStorageSpace())
	end)
end

function TestNativeSpace:testUpdateSpaces()
	helpers.withHsGlobal({}, function()
		local space = NativeSpace.new()

		space:updateSpaces("321", "123")
		lu.assertEquals(space:getActiveSpace(), "321")
		lu.assertEquals(space:getStorageSpace(), "123")

		space:updateSpaces("123", "321")
		lu.assertEquals(space:getActiveSpace(), "123")
		lu.assertEquals(space:getStorageSpace(), "321")
	end)
end

function TestNativeSpace:testSetupForMainScreenWithExactlyTwoSpaces()
	local space, inspect = mockedNativeSpace({
		initialSpaces = {"space-1", "space-2"}
	})

	local active, storage = space:setupForMainScreen()

	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-2")
	lu.assertEquals(space:getActiveSpace(), "space-1")
	lu.assertEquals(space:getStorageSpace(), "space-2")
end

function TestNativeSpace:testSetupForMainScreenRemovesExtraSpaces()
	local space, inspect = mockedNativeSpace({
		initialSpaces = {"space-1", "space-2", "space-3", "space-4"},
		finalSpaces = {"space-1", "space-new"}
	})

	local active, storage = space:setupForMainScreen()

	lu.assertEquals(#inspect.removedSpaces, 3)
	lu.assertEquals(inspect.removedSpaces[1].id, "space-2")
	lu.assertEquals(inspect.removedSpaces[1].destroyMC, false)
	lu.assertEquals(inspect.removedSpaces[2].id, "space-3")
	lu.assertEquals(inspect.removedSpaces[3].id, "space-4")
	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-new")
end

function TestNativeSpace:testSetupForMainScreenInitiatesMissionControl()
	local space, inspect = mockedNativeSpace()

	space:setupForMainScreen()

	lu.assertEquals(inspect.counters.openMissionControlCalls, 1)
end

function TestNativeSpace:testSetupForMainScreenCreatesStorageSpace()
	local space, inspect = mockedNativeSpace()

	space:setupForMainScreen()

	lu.assertEquals(#inspect.addSpaceCalls, 1)
	lu.assertEquals(inspect.addSpaceCalls[1].screen, inspect.screenUUID)
	lu.assertEquals(inspect.addSpaceCalls[1].toEnd, true)
end

function TestNativeSpace:testSetupForMainScreenWithOneSpaceInitially()
	local space = mockedNativeSpace({
		initialSpaces = {"space-1"},
		finalSpaces = {"space-1", "space-storage"}
	})

	local active, storage = space:setupForMainScreen()

	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-storage")
	lu.assertEquals(space:getActiveSpace(), "space-1")
	lu.assertEquals(space:getStorageSpace(), "space-storage")
end

function TestNativeSpace:testSetupFailsWhenOnlyOneSpaceExists()
	local space = mockedNativeSpace({
		initialSpaces = {"space-1"},
		finalSpaces = {"space-1"}
	})

	local success, err = pcall(function()
		space:setupForMainScreen()
	end)

	lu.assertFalse(success)
	lu.assertStrContains(err, "Expected exactly 2 spaces")
end

function TestNativeSpace:testSetupFailsWhenMoreThanTwoSpacesExist()
	local space = mockedNativeSpace({
		initialSpaces = {"space-1", "space-2", "space-3"},
		finalSpaces = {"space-1", "space-2", "space-3"}
	})

	local success, err = pcall(function()
		space:setupForMainScreen()
	end)

	lu.assertFalse(success)
	lu.assertStrContains(err, "Expected exactly 2 spaces")
end

function TestNativeSpace:testMoveWindowToSpaceDelegatesToHsSpaces()
	local space, inspect = mockedNativeSpace()

	space:moveWindowToSpace(100, "space-2")

	lu.assertEquals(#inspect.movedWindows, 1)
	lu.assertEquals(inspect.movedWindows[1], {winId = 100, spaceId = "space-2"})
end

function TestNativeSpace:testWindowSpacesDelegatesToHsSpaces()
	local space, inspect = mockedNativeSpace({activeSpace = "space-1"})

	local spaces = space:windowSpaces(100)

	lu.assertEquals(spaces, {"space-1"})
	lu.assertEquals(inspect.windowSpacesCalls, {100})
end

function TestNativeSpace:testGetCurrentNativeSpaceDelegatesToHsSpaces()
	local space = mockedNativeSpace({activeSpace = "space-2"})

	lu.assertEquals(space:getCurrentNativeSpace(), "space-2")
end

function TestNativeSpace:testForgetWindowDoesNotTouchNativeSpaces()
	local space, inspect = mockedNativeSpace()

	space:forgetWindow(100)

	lu.assertEquals(#inspect.movedWindows, 0)
	lu.assertEquals(#inspect.windowSpacesCalls, 0)
end

function TestNativeSpace:testStartWatchingForManualNavigationStartsWatcher()
	local space, inspect = mockedNativeSpace()

	space:startWatchingForManualNavigation(function() end)

	lu.assertEquals(inspect.watcherStartCalls(), 1)
end

function TestNativeSpace:testStartWatchingForManualNavigationPassesCurrentNativeSpaceToCallback()
	local space, inspect = mockedNativeSpace({activeSpace = "space-1"})

	local receivedSpace = nil
	space:startWatchingForManualNavigation(function(currentNativeSpace)
		receivedSpace = currentNativeSpace
	end)

	inspect.setActiveSpace("space-2")
	inspect.fireWatcher()

	lu.assertEquals(receivedSpace, "space-2")
end

return TestNativeSpace
