local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local NativeSpaceManager = require('NativeSpaceManager')

TestNativeSpaceManager = {}

local function mokedNativeSpaceManager(options)
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
		end
	}

	return NativeSpaceManager.new({
		hsSpaces = mockSpaces,
		hsScreen = mockScreen,
	}), {
		screenUUID = screenUUID,
		removedSpaces = removedSpaces,
		counters = counters,
		addSpaceCalls = addSpaceCalls,
	}
end

function TestNativeSpaceManager:testNew()
	local manager = NativeSpaceManager.new({
		hsSpaces = {},
		hsScreen = {},
		telemetry = {}
	})

	lu.assertNotNil(manager)
	lu.assertEquals(manager._hsSpaces, {})
	lu.assertEquals(manager._hsScreen, {})
	lu.assertEquals(manager._telemetry, {})
end

function TestNativeSpaceManager:testNewWithDefaults()
	helpers.withHsGlobal({}, function()
		local manager = NativeSpaceManager.new()

		lu.assertNotNil(manager)
		lu.assertNotNil(manager._telemetry)

		lu.assertNil(manager:getActiveSpace())
		lu.assertNil(manager:getStorageSpace())
	end)
end

function TestNativeSpaceManager:testUpdateSpaces()
	helpers.withHsGlobal({}, function()
		local manager = NativeSpaceManager.new()

		manager:updateSpaces("321", "123")
		lu.assertEquals(manager:getActiveSpace(), "321")
		lu.assertEquals(manager:getStorageSpace(), "123")

		manager:updateSpaces("123", "321")
		lu.assertEquals(manager:getActiveSpace(), "123")
		lu.assertEquals(manager:getStorageSpace(), "321")
	end)
end

function TestNativeSpaceManager:testSetupForMainScreenWithExactlyTwoSpaces()
	local manager, inspect = mokedNativeSpaceManager({
		initialSpaces = {"space-1", "space-2"}
	})

	local active, storage = manager:setupForMainScreen()

	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-2")
	lu.assertEquals(manager:getActiveSpace(), "space-1")
	lu.assertEquals(manager:getStorageSpace(), "space-2")
end

function TestNativeSpaceManager:testSetupForMainScreenRemovesExtraSpaces()
	local manager, inspect = mokedNativeSpaceManager({
		initialSpaces = {"space-1", "space-2", "space-3", "space-4"},
		finalSpaces = {"space-1", "space-new"}
	})

	local active, storage = manager:setupForMainScreen()

	lu.assertEquals(#inspect.removedSpaces, 3)
	lu.assertEquals(inspect.removedSpaces[1].id, "space-2")
	lu.assertEquals(inspect.removedSpaces[1].destroyMC, false)
	lu.assertEquals(inspect.removedSpaces[2].id, "space-3")
	lu.assertEquals(inspect.removedSpaces[3].id, "space-4")
	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-new")
end

function TestNativeSpaceManager:testSetupForMainScreenInitiatesMissionControl()
	local manager, inspect = mokedNativeSpaceManager()

	manager:setupForMainScreen()

	lu.assertEquals(inspect.counters.openMissionControlCalls, 1)
end

function TestNativeSpaceManager:testSetupForMainScreenCreatesStorageSpace()
	local manager, inspect = mokedNativeSpaceManager()

	manager:setupForMainScreen()

	lu.assertEquals(#inspect.addSpaceCalls, 1)
	lu.assertEquals(inspect.addSpaceCalls[1].screen, inspect.screenUUID)
	lu.assertEquals(inspect.addSpaceCalls[1].toEnd, true)
end

function TestNativeSpaceManager:testSetupForMainScreenWithOneSpaceInitially()
	local manager = mokedNativeSpaceManager({
		initialSpaces = {"space-1"},
		finalSpaces = {"space-1", "space-storage"}
	})

	local active, storage = manager:setupForMainScreen()

	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-storage")
	lu.assertEquals(manager:getActiveSpace(), "space-1")
	lu.assertEquals(manager:getStorageSpace(), "space-storage")
end

function TestNativeSpaceManager:testSetupFailsWhenOnlyOneSpaceExists()
	local manager = mokedNativeSpaceManager({
		initialSpaces = {"space-1"},
		finalSpaces = {"space-1"}
	})

	local success, err = pcall(function()
		manager:setupForMainScreen()
	end)

	lu.assertFalse(success)
	lu.assertStrContains(err, "Expected exactly 2 spaces")
end

function TestNativeSpaceManager:testSetupFailsWhenMoreThanTwoSpacesExist()
	local manager = mokedNativeSpaceManager({
		initialSpaces = {"space-1", "space-2", "space-3"},
		finalSpaces = {"space-1", "space-2", "space-3"}
	})

	local success, err = pcall(function()
		manager:setupForMainScreen()
	end)

	lu.assertFalse(success)
	lu.assertStrContains(err, "Expected exactly 2 spaces")
end

return TestNativeSpaceManager
