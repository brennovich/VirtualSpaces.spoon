local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local VirtualSpace = require('VirtualSpace')

TestVirtualSpace = {}

local SCREEN_FULL_FRAME = {x = 0, y = 0, w = 1792, h = 1120}

local function mockWindow(id, frame, opts)
	opts = opts or {}
	local currentFrame = frame
	local setFrameCalls = {}

	return {
		id = function() return id end,
		frame = function() return currentFrame end,
		setFrame = function(_, newFrame)
			table.insert(setFrameCalls, newFrame)
			currentFrame = newFrame
		end,
		isMinimized = function() return opts.isMinimized or false end,
		_setFrameCalls = setFrameCalls,
	}
end

local SCREEN_UUID = "screen-uuid"

local function mockHsSpaces(options)
	options = options or {}
	local spaces = options.spaces or {1}
	local removesEffective = options.removesEffective ~= false
	local calls = {openMissionControl = 0, closeMissionControl = 0, removed = {}}

	return {
		allSpaces = function()
			local copy = {}
			for i, id in ipairs(spaces) do copy[i] = id end
			return {[SCREEN_UUID] = copy}
		end,
		activeSpaceOnScreen = function() return options.active or spaces[1] end,
		openMissionControl = function() calls.openMissionControl = calls.openMissionControl + 1 end,
		closeMissionControl = function() calls.closeMissionControl = calls.closeMissionControl + 1 end,
		removeSpace = function(spaceID)
			table.insert(calls.removed, spaceID)
			if not removesEffective then return end
			for i, id in ipairs(spaces) do
				if id == spaceID then
					table.remove(spaces, i)
					break
				end
			end
		end,
		_spaces = spaces,
		_calls = calls,
	}
end

local function mockedVirtualSpace(options)
	options = options or {}
	local windows = options.windows or {}
	local allWindows = options.allWindows or {}
	local filterSubscriptions = options.filterSubscriptions or {}
	local hsSpaces = options.hsSpaces or mockHsSpaces()

	local mockScreen = {
		mainScreen = function()
			return {
				getUUID = function() return SCREEN_UUID end,
				fullFrame = function() return SCREEN_FULL_FRAME end,
				frame = function() return SCREEN_FULL_FRAME end,
			}
		end
	}

	local mockHsWindow = {
		allWindows = function() return allWindows end,
		filter = {windowFocused = "windowFocused"}
	}

	local mockWindowFilter = {
		subscribe = function(_, eventType, cb)
			filterSubscriptions[eventType] = cb
		end
	}

	return VirtualSpace.new({
		windowGetter = function(id) return windows[id] end,
		hsWindow = mockHsWindow,
		hsScreen = mockScreen,
		hsSpaces = hsSpaces,
		windowFilter = mockWindowFilter,
	})
end

function TestVirtualSpace:testNew()
	local space = VirtualSpace.new({
		windowGetter = function() end,
		hsWindow = {},
		hsScreen = {},
		hsSpaces = {},
		telemetry = {}
	})

	lu.assertNotNil(space)
	lu.assertNotNil(space._windowGetter)
	lu.assertEquals(space._hsWindow, {})
	lu.assertEquals(space._hsScreen, {})
	lu.assertEquals(space._hsSpaces, {})
	lu.assertEquals(space._telemetry, {})
end

function TestVirtualSpace:testNewWithDefaults()
	helpers.withHsGlobal({}, function()
		local space = VirtualSpace.new()

		lu.assertNotNil(space)
		lu.assertNotNil(space._telemetry)
	end)
end

function TestVirtualSpace:testGetActiveSpaceAndStorageSpaceReturnSentinels()
	local space = mockedVirtualSpace()

	local active = space:getActiveSpace()
	local storage = space:getStorageSpace()

	lu.assertEquals(type(active), "string")
	lu.assertEquals(type(storage), "string")
	lu.assertNotEquals(active, storage)

	lu.assertEquals(space:getActiveSpace(), active)
	lu.assertEquals(space:getStorageSpace(), storage)
end

function TestVirtualSpace:testSetupForMainScreenReturnsSentinels()
	local space = mockedVirtualSpace()

	local active, storage = space:setupForMainScreen()

	lu.assertEquals(active, space:getActiveSpace())
	lu.assertEquals(storage, space:getStorageSpace())
end

function TestVirtualSpace:testMoveWindowToSpaceCapturesFrameAndHidesWindow()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedVirtualSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())

	lu.assertEquals(#win._setFrameCalls, 1)
	local hiddenFrame = win._setFrameCalls[1]
	lu.assertEquals(hiddenFrame.x, SCREEN_FULL_FRAME.x + SCREEN_FULL_FRAME.w - 1)
	lu.assertEquals(hiddenFrame.y, SCREEN_FULL_FRAME.y + SCREEN_FULL_FRAME.h - 1)
	lu.assertEquals(hiddenFrame.w, originalFrame.w)
	lu.assertEquals(hiddenFrame.h, originalFrame.h)

	space:moveWindowToSpace(100, space:getActiveSpace())

	lu.assertEquals(#win._setFrameCalls, 2)
	local restoredFrame = win._setFrameCalls[2]
	lu.assertEquals(restoredFrame, originalFrame)
end

function TestVirtualSpace:testMoveWindowToSpaceIsIdempotentOnDoubleHide()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedVirtualSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())
	space:moveWindowToSpace(100, space:getStorageSpace())

	lu.assertEquals(#win._setFrameCalls, 1)

	space:moveWindowToSpace(100, space:getActiveSpace())

	lu.assertEquals(#win._setFrameCalls, 2)
	lu.assertEquals(win._setFrameCalls[2], originalFrame)
end

function TestVirtualSpace:testMoveWindowToSpaceIsIdempotentOnDoubleShow()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedVirtualSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())
	space:moveWindowToSpace(100, space:getActiveSpace())
	space:moveWindowToSpace(100, space:getActiveSpace())

	lu.assertEquals(#win._setFrameCalls, 2)
end

function TestVirtualSpace:testMoveWindowToSpaceSkipsMinimizedWindows()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame, {isMinimized = true})
	local space = mockedVirtualSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())

	lu.assertEquals(#win._setFrameCalls, 0)
	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})
end

function TestVirtualSpace:testWindowSpacesReflectsHiddenState()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedVirtualSpace({windows = {[100] = win}})

	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})

	space:moveWindowToSpace(100, space:getStorageSpace())
	lu.assertEquals(space:windowSpaces(100), {space:getStorageSpace()})

	space:moveWindowToSpace(100, space:getActiveSpace())
	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})
end

function TestVirtualSpace:testForgetWindowClearsHiddenState()
	local win = mockWindow(100, {x = 100, y = 100, w = 800, h = 600})
	local space = mockedVirtualSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())
	space:forgetWindow(100)

	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})
end

function TestVirtualSpace:testStartWatchingForManualNavigationFiresOnHiddenWindowFocus()
	local win = mockWindow(100, {x = 100, y = 100, w = 800, h = 600})
	local filterSubscriptions = {}
	local space = mockedVirtualSpace({
		windows = {[100] = win},
		filterSubscriptions = filterSubscriptions
	})
	local callbackSpaces = {}

	space:startWatchingForManualNavigation(function(spaceId)
		table.insert(callbackSpaces, spaceId)
	end)
	space:moveWindowToSpace(100, space:getStorageSpace())

	filterSubscriptions["windowFocused"](win)

	lu.assertEquals(callbackSpaces, {space:getStorageSpace()})
end

function TestVirtualSpace:testStartWatchingForManualNavigationIgnoresVisibleWindowFocus()
	local win = mockWindow(100, {x = 100, y = 100, w = 800, h = 600})
	local filterSubscriptions = {}
	local space = mockedVirtualSpace({
		windows = {[100] = win},
		filterSubscriptions = filterSubscriptions
	})
	local callbackSpaces = {}

	space:startWatchingForManualNavigation(function(spaceId)
		table.insert(callbackSpaces, spaceId)
	end)

	filterSubscriptions["windowFocused"](win)

	lu.assertEquals(callbackSpaces, {})
end

function TestVirtualSpace:testMoveWindowToSpaceHandlesMissingWindow()
	local space = mockedVirtualSpace({windows = {}})

	local success = pcall(function()
		space:moveWindowToSpace(999, space:getStorageSpace())
	end)

	lu.assertTrue(success)
end

function TestVirtualSpace:testSetupForMainScreenRecoversWindowsStuckInHiddenCorner()
	local stuckWindow = mockWindow(200, {x = 1791, y = 100, w = 800, h = 600})
	local normalWindow = mockWindow(300, {x = 100, y = 100, w = 800, h = 600})

	local space = mockedVirtualSpace({
		allWindows = {stuckWindow, normalWindow}
	})

	space:setupForMainScreen()

	lu.assertEquals(#stuckWindow._setFrameCalls, 1)
	local recoveredFrame = stuckWindow._setFrameCalls[1]
	lu.assertTrue(recoveredFrame.x < SCREEN_FULL_FRAME.x + SCREEN_FULL_FRAME.w - 10)

	lu.assertEquals(#normalWindow._setFrameCalls, 0)
end

function TestVirtualSpace:testInitPicksVirtualSpace()
	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 15, minor = 0, patch = 0} end
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		lu.assertEquals(VirtualSpaces.spaceStrategy:getActiveSpace(), "active")
		lu.assertEquals(VirtualSpaces.spaceStrategy:getStorageSpace(), "storage")
	end)
end

function TestVirtualSpace:testInitForgetsDestroyedHiddenWindows()
	local filterCallbacks = {}
	local win = helpers.createHsWindow(100, "App1")

	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 15, minor = 0, patch = 0} end,
		allWindows = function() return {win} end,
		mockWindows = {[100] = win},
		filterNew = function()
			return {
				subscribe = function(_, eventType, cb) filterCallbacks[eventType] = cb end,
				setCurrentSpace = function() end
			}
		end,
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		VirtualSpaces:moveWindowToVirtualSpace(win, 2)
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(100), {"storage"})

		filterCallbacks[_G.hs.window.filter.windowDestroyed](win)

		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(100), {"active"})
	end)
end

function TestVirtualSpace:testInitSwitchesVirtualSpaceWhenHiddenWindowFocused()
	local filterCallbacks = {}
	local win1 = helpers.createHsWindow(100, "App1")
	local win2 = helpers.createHsWindow(200, "App2")
	local focusedWindow = nil

	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 15, minor = 0, patch = 0} end,
		allWindows = function() return {win1, win2} end,
		mockWindows = {[100] = win1, [200] = win2},
		focusedWindow = function() return focusedWindow end,
		filterNew = function()
			return {
				subscribe = function(_, eventType, cb)
					filterCallbacks[eventType] = filterCallbacks[eventType] or {}
					table.insert(filterCallbacks[eventType], cb)
				end,
				setCurrentSpace = function() end
			}
		end,
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		focusedWindow = win1
		VirtualSpaces:moveWindowToVirtualSpace(win2, 2)
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(200), {"storage"})

		focusedWindow = win2
		for _, cb in ipairs(filterCallbacks[_G.hs.window.filter.windowFocused]) do
			cb(win2)
		end

		lu.assertEquals(VirtualSpaces.model:getCurrentVirtualSpace(), 2)
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(200), {"active"})
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(100), {"storage"})
	end)
end

function TestVirtualSpace:testInitStaysOnEmptySpaceWhenLastWindowClosedAndHiddenWindowAutoFocused()
	local filterCallbacks = {}
	local win1 = helpers.createHsWindow(100, "App1")
	local win2 = helpers.createHsWindow(200, "App2")
	local focusedWindow = nil
	local deadWindows = {}

	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 15, minor = 0, patch = 0} end,
		allWindows = function() return {win1, win2} end,
		focusedWindow = function() return focusedWindow end,
		windowGet = function(id)
			if deadWindows[id] then return nil end
			if id == 100 then return win1 end
			if id == 200 then return win2 end
			return nil
		end,
		filterNew = function()
			return {
				subscribe = function(_, eventType, cb)
					filterCallbacks[eventType] = filterCallbacks[eventType] or {}
					table.insert(filterCallbacks[eventType], cb)
				end,
				setCurrentSpace = function() end
			}
		end,
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		focusedWindow = win1
		VirtualSpaces:moveWindowToVirtualSpace(win2, 2)

		deadWindows[100] = true
		focusedWindow = win2
		for _, cb in ipairs(filterCallbacks[_G.hs.window.filter.windowFocused]) do
			cb(win2)
		end

		lu.assertEquals(VirtualSpaces.model:getCurrentVirtualSpace(), 1)
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(200), {"storage"})
	end)
end

function TestVirtualSpace:testInitHidesWindowsThroughWindowCache()
	local win = helpers.createHsWindow(100, "App1")
	local windowGetCalls = 0

	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 15, minor = 0, patch = 0} end,
		allWindows = function() return {win} end,
		windowGet = function(id)
			if id == 100 then
				windowGetCalls = windowGetCalls + 1
				return win
			end
			return nil
		end,
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		VirtualSpaces:moveWindowToVirtualSpace(win, 2)

		lu.assertEquals(windowGetCalls, 0)
		lu.assertEquals(win:frame().x, 1792 - 1)
	end)
end

function TestVirtualSpace:testSetupConsolidatesMultipleNativeSpacesToOne()
	local hsSpaces = mockHsSpaces({spaces = {1, 2, 3}, active = 1})
	local space = mockedVirtualSpace({hsSpaces = hsSpaces})

	space:setupForMainScreen()

	lu.assertEquals(hsSpaces._calls.openMissionControl, 1)
	lu.assertEquals(hsSpaces._calls.closeMissionControl, 1)
	lu.assertEquals(hsSpaces._calls.removed, {2, 3})
	lu.assertEquals(hsSpaces._spaces, {1})
end

function TestVirtualSpace:testSetupLeavesSingleNativeSpaceUntouched()
	local hsSpaces = mockHsSpaces({spaces = {1}, active = 1})
	local space = mockedVirtualSpace({hsSpaces = hsSpaces})

	space:setupForMainScreen()

	lu.assertEquals(hsSpaces._calls.openMissionControl, 0)
	lu.assertEquals(hsSpaces._calls.closeMissionControl, 0)
	lu.assertEquals(hsSpaces._calls.removed, {})
end

function TestVirtualSpace:testSetupErrorsWhenConsolidationFails()
	local hsSpaces = mockHsSpaces({spaces = {1, 2, 3}, active = 1, removesEffective = false})
	local space = mockedVirtualSpace({hsSpaces = hsSpaces})

	local success = pcall(function() space:setupForMainScreen() end)

	lu.assertFalse(success)
end

function TestVirtualSpace:testSetupErrorsWhenSpacesUnavailableForMainScreen()
	local hsSpaces = mockHsSpaces()
	hsSpaces.allSpaces = function() return {} end
	local space = mockedVirtualSpace({hsSpaces = hsSpaces})

	local success = pcall(function() space:setupForMainScreen() end)

	lu.assertFalse(success)
end

return TestVirtualSpace
