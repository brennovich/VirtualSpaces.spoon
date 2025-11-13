local lu = require('luaunit')

local NativeSpaceManager = require('NativeSpaceManager')

TestNativeSpaceManager = {}

local function createMocksForSetup(options)
	options = options or {}
	local screenUUID = options.screenUUID or "screen-uuid-123"
	local initialSpaces = options.initialSpaces or {"space-1", "space-2"}
	local finalSpaces = options.finalSpaces or initialSpaces
	local activeSpace = options.activeSpace or "space-1"

	local initialAllSpacesData = {}
	initialAllSpacesData[screenUUID] = initialSpaces

	local finalAllSpacesData = {}
	finalAllSpacesData[screenUUID] = finalSpaces

	local allSpacesCalls = 0
	local usleepCalls = {}
	local removedSpaces = {}
	local addSpaceCalls = {}
	local gotoSpaceCalls = {}
	local keyStrokeCalls = {}
	local waitTimeCalls = {}

	local mockScreen = {
		mainScreen = function()
			return {
				getUUID = function() return screenUUID end
			}
		end
	}

	local mockSpaces = {
		setDefaultMCwaitTime = options.setDefaultMCwaitTime or function(time)
			table.insert(waitTimeCalls, time)
		end,
		allSpaces = options.allSpaces or function()
			allSpacesCalls = allSpacesCalls + 1
			if allSpacesCalls == 1 then
				return initialAllSpacesData
			else
				return finalAllSpacesData
			end
		end,
		activeSpaceOnScreen = options.activeSpaceOnScreen or function()
			return activeSpace
		end,
		removeSpace = options.removeSpace or function(spaceId, animated)
			table.insert(removedSpaces, {id = spaceId, animated = animated})
		end,
		gotoSpace = options.gotoSpace or function(spaceId)
			table.insert(gotoSpaceCalls, spaceId)
		end,
		addSpaceToScreen = options.addSpaceToScreen or function(screenUUID, toEnd)
			table.insert(addSpaceCalls, {screen = screenUUID, toEnd = toEnd})
		end
	}

	local mockTimer = {
		usleep = options.usleep or function(delay)
			table.insert(usleepCalls, delay)
		end
	}

	local mockEventtap = {
		keyStroke = options.keyStroke or function(modifiers, key)
			table.insert(keyStrokeCalls, {modifiers = modifiers, key = key})
		end
	}

	local manager = NativeSpaceManager.new(mockSpaces, mockScreen, mockTimer, mockEventtap)

	return {
		manager = manager,
		screenUUID = screenUUID,
		usleepCalls = usleepCalls,
		removedSpaces = removedSpaces,
		addSpaceCalls = addSpaceCalls,
		gotoSpaceCalls = gotoSpaceCalls,
		keyStrokeCalls = keyStrokeCalls,
		waitTimeCalls = waitTimeCalls
	}
end

function TestNativeSpaceManager:testNew()
	local mockSpaces = {}
	local mockScreen = {}
	local mockTimer = {}
	local mockEventtap = {}

	local manager = NativeSpaceManager.new(mockSpaces, mockScreen, mockTimer, mockEventtap)

	lu.assertNotNil(manager)
	lu.assertEquals(manager._hsSpaces, mockSpaces)
	lu.assertEquals(manager._hsScreen, mockScreen)
	lu.assertEquals(manager._hsTimer, mockTimer)
	lu.assertEquals(manager._hsEventtap, mockEventtap)
end

function TestNativeSpaceManager:testGetActiveSpaceBeforeSetup()
	local manager = NativeSpaceManager.new({}, {}, {}, {})

	lu.assertNil(manager:getActiveSpace())
end

function TestNativeSpaceManager:testGetStorageSpaceBeforeSetup()
	local manager = NativeSpaceManager.new({}, {}, {}, {})

	lu.assertNil(manager:getStorageSpace())
end

function TestNativeSpaceManager:testUpdateSpaces()
	local manager = NativeSpaceManager.new({}, {}, {}, {})

	manager:updateSpaces("active-123", "storage-456")

	lu.assertEquals(manager:getActiveSpace(), "active-123")
	lu.assertEquals(manager:getStorageSpace(), "storage-456")
end

function TestNativeSpaceManager:testUpdateSpacesMultipleTimes()
	local manager = NativeSpaceManager.new({}, {}, {}, {})

	manager:updateSpaces("active-1", "storage-1")
	lu.assertEquals(manager:getActiveSpace(), "active-1")
	lu.assertEquals(manager:getStorageSpace(), "storage-1")

	manager:updateSpaces("active-2", "storage-2")
	lu.assertEquals(manager:getActiveSpace(), "active-2")
	lu.assertEquals(manager:getStorageSpace(), "storage-2")
end

function TestNativeSpaceManager:testSetupForMainScreenWithExactlyTwoSpaces()
	local mocks = createMocksForSetup({
		initialSpaces = {"space-1", "space-2"}
	})

	local active, storage = mocks.manager:setupForMainScreen()

	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-2")
	lu.assertEquals(mocks.manager:getActiveSpace(), "space-1")
	lu.assertEquals(mocks.manager:getStorageSpace(), "space-2")
	lu.assertEquals(#mocks.usleepCalls, 2)
end

function TestNativeSpaceManager:testSetupForMainScreenRemovesExtraSpaces()
	local mocks = createMocksForSetup({
		initialSpaces = {"space-1", "space-2", "space-3", "space-4"},
		finalSpaces = {"space-1", "space-new"}
	})

	local active, storage = mocks.manager:setupForMainScreen()

	lu.assertEquals(#mocks.removedSpaces, 3)
	lu.assertEquals(mocks.removedSpaces[1].id, "space-2")
	lu.assertEquals(mocks.removedSpaces[1].animated, false)
	lu.assertEquals(mocks.removedSpaces[2].id, "space-3")
	lu.assertEquals(mocks.removedSpaces[3].id, "space-4")
	lu.assertEquals(#mocks.usleepCalls, 4)
	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-new")
end

function TestNativeSpaceManager:testSetupForMainScreenNavigatesToFirstSpace()
	local mocks = createMocksForSetup({
		activeSpace = "space-2"
	})

	mocks.manager:setupForMainScreen()

	lu.assertEquals(#mocks.gotoSpaceCalls, 1)
	lu.assertEquals(mocks.gotoSpaceCalls[1], "space-1")
	lu.assertEquals(#mocks.keyStrokeCalls, 1)
	lu.assertEquals(mocks.keyStrokeCalls[1].key, "escape")
end

function TestNativeSpaceManager:testSetupForMainScreenCreatesStorageSpace()
	local mocks = createMocksForSetup()

	mocks.manager:setupForMainScreen()

	lu.assertEquals(#mocks.addSpaceCalls, 1)
	lu.assertEquals(mocks.addSpaceCalls[1].screen, mocks.screenUUID)
	lu.assertEquals(mocks.addSpaceCalls[1].toEnd, true)
end

function TestNativeSpaceManager:testSetupForMainScreenSetsDefaultMCwaitTime()
	local mocks = createMocksForSetup()

	mocks.manager:setupForMainScreen()

	lu.assertEquals(#mocks.waitTimeCalls, 1)
	lu.assertEquals(mocks.waitTimeCalls[1], 0.5)
end

function TestNativeSpaceManager:testSetupForMainScreenWithOneSpaceInitially()
	local mocks = createMocksForSetup({
		initialSpaces = {"space-1"},
		finalSpaces = {"space-1", "space-storage"}
	})

	local active, storage = mocks.manager:setupForMainScreen()

	lu.assertEquals(active, "space-1")
	lu.assertEquals(storage, "space-storage")
	lu.assertEquals(mocks.manager:getActiveSpace(), "space-1")
	lu.assertEquals(mocks.manager:getStorageSpace(), "space-storage")
end

return TestNativeSpaceManager
