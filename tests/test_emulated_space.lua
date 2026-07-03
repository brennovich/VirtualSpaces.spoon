local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local EmulatedSpace = require('EmulatedSpace')

TestEmulatedSpace = {}

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

local function mockedEmulatedSpace(options)
	options = options or {}
	local windows = options.windows or {}
	local allWindows = options.allWindows or {}
	local filterSubscriptions = options.filterSubscriptions or {}

	local mockScreen = {
		mainScreen = function()
			return {
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

	return EmulatedSpace.new({
		windowGetter = function(id) return windows[id] end,
		hsWindow = mockHsWindow,
		hsScreen = mockScreen,
		windowFilter = mockWindowFilter,
	})
end

function TestEmulatedSpace:testNew()
	local space = EmulatedSpace.new({
		windowGetter = function() end,
		hsWindow = {},
		hsScreen = {},
		telemetry = {}
	})

	lu.assertNotNil(space)
	lu.assertNotNil(space._windowGetter)
	lu.assertEquals(space._hsWindow, {})
	lu.assertEquals(space._hsScreen, {})
	lu.assertEquals(space._telemetry, {})
end

function TestEmulatedSpace:testNewWithDefaults()
	helpers.withHsGlobal({}, function()
		local space = EmulatedSpace.new()

		lu.assertNotNil(space)
		lu.assertNotNil(space._telemetry)
	end)
end

function TestEmulatedSpace:testGetActiveSpaceAndStorageSpaceReturnSentinels()
	local space = mockedEmulatedSpace()

	local active = space:getActiveSpace()
	local storage = space:getStorageSpace()

	lu.assertEquals(type(active), "string")
	lu.assertEquals(type(storage), "string")
	lu.assertNotEquals(active, storage)

	lu.assertEquals(space:getActiveSpace(), active)
	lu.assertEquals(space:getStorageSpace(), storage)
end

function TestEmulatedSpace:testSetupForMainScreenReturnsSentinels()
	local space = mockedEmulatedSpace()

	local active, storage = space:setupForMainScreen()

	lu.assertEquals(active, space:getActiveSpace())
	lu.assertEquals(storage, space:getStorageSpace())
end

function TestEmulatedSpace:testGetCurrentNativeSpaceAlwaysReturnsActiveSentinel()
	local space = mockedEmulatedSpace()

	lu.assertEquals(space:getCurrentNativeSpace(), space:getActiveSpace())

	space:moveWindowToSpace(100, space:getStorageSpace())
	lu.assertEquals(space:getCurrentNativeSpace(), space:getActiveSpace())
end

function TestEmulatedSpace:testUpdateSpacesIsNoOp()
	local space = mockedEmulatedSpace()
	local activeBefore = space:getActiveSpace()
	local storageBefore = space:getStorageSpace()

	space:updateSpaces("anything", "else")

	lu.assertEquals(space:getActiveSpace(), activeBefore)
	lu.assertEquals(space:getStorageSpace(), storageBefore)
end

function TestEmulatedSpace:testMoveWindowToSpaceCapturesFrameAndHidesWindow()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedEmulatedSpace({windows = {[100] = win}})

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

function TestEmulatedSpace:testMoveWindowToSpaceIsIdempotentOnDoubleHide()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedEmulatedSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())
	space:moveWindowToSpace(100, space:getStorageSpace())

	lu.assertEquals(#win._setFrameCalls, 1)

	space:moveWindowToSpace(100, space:getActiveSpace())

	lu.assertEquals(#win._setFrameCalls, 2)
	lu.assertEquals(win._setFrameCalls[2], originalFrame)
end

function TestEmulatedSpace:testMoveWindowToSpaceIsIdempotentOnDoubleShow()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedEmulatedSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())
	space:moveWindowToSpace(100, space:getActiveSpace())
	space:moveWindowToSpace(100, space:getActiveSpace())

	lu.assertEquals(#win._setFrameCalls, 2)
end

function TestEmulatedSpace:testMoveWindowToSpaceSkipsMinimizedWindows()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame, {isMinimized = true})
	local space = mockedEmulatedSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())

	lu.assertEquals(#win._setFrameCalls, 0)
	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})
end

function TestEmulatedSpace:testWindowSpacesReflectsHiddenState()
	local originalFrame = {x = 100, y = 100, w = 800, h = 600}
	local win = mockWindow(100, originalFrame)
	local space = mockedEmulatedSpace({windows = {[100] = win}})

	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})

	space:moveWindowToSpace(100, space:getStorageSpace())
	lu.assertEquals(space:windowSpaces(100), {space:getStorageSpace()})

	space:moveWindowToSpace(100, space:getActiveSpace())
	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})
end

function TestEmulatedSpace:testForgetWindowClearsHiddenState()
	local win = mockWindow(100, {x = 100, y = 100, w = 800, h = 600})
	local space = mockedEmulatedSpace({windows = {[100] = win}})

	space:moveWindowToSpace(100, space:getStorageSpace())
	space:forgetWindow(100)

	lu.assertEquals(space:windowSpaces(100), {space:getActiveSpace()})
end

function TestEmulatedSpace:testStartWatchingForManualNavigationFiresOnHiddenWindowFocus()
	local win = mockWindow(100, {x = 100, y = 100, w = 800, h = 600})
	local filterSubscriptions = {}
	local space = mockedEmulatedSpace({
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

function TestEmulatedSpace:testStartWatchingForManualNavigationIgnoresVisibleWindowFocus()
	local win = mockWindow(100, {x = 100, y = 100, w = 800, h = 600})
	local filterSubscriptions = {}
	local space = mockedEmulatedSpace({
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

function TestEmulatedSpace:testMoveWindowToSpaceHandlesMissingWindow()
	local space = mockedEmulatedSpace({windows = {}})

	local success = pcall(function()
		space:moveWindowToSpace(999, space:getStorageSpace())
	end)

	lu.assertTrue(success)
end

function TestEmulatedSpace:testSetupForMainScreenRecoversWindowsStuckInHiddenCorner()
	local stuckWindow = mockWindow(200, {x = 1791, y = 100, w = 800, h = 600})
	local normalWindow = mockWindow(300, {x = 100, y = 100, w = 800, h = 600})

	local space = mockedEmulatedSpace({
		allWindows = {stuckWindow, normalWindow}
	})

	space:setupForMainScreen()

	lu.assertEquals(#stuckWindow._setFrameCalls, 1)
	local recoveredFrame = stuckWindow._setFrameCalls[1]
	lu.assertTrue(recoveredFrame.x < SCREEN_FULL_FRAME.x + SCREEN_FULL_FRAME.w - 10)

	lu.assertEquals(#normalWindow._setFrameCalls, 0)
end

function TestEmulatedSpace:testInitPicksEmulatedSpace()
	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 15, minor = 0, patch = 0} end
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		lu.assertEquals(VirtualSpaces.spaceStrategy:getActiveSpace(), "emulated-active")
		lu.assertEquals(VirtualSpaces.spaceStrategy:getStorageSpace(), "emulated-storage")
	end)
end

function TestEmulatedSpace:testInitPicksNativeSpaceOnPreSequoia()
	helpers.withHsGlobal(helpers.createHsGlobal({
		operatingSystemVersion = function() return {major = 14, minor = 0, patch = 0} end
	}), function()
		package.loaded['init'] = nil
		local VirtualSpaces = require('init')
		VirtualSpaces:init()

		lu.assertEquals(VirtualSpaces.spaceStrategy:getActiveSpace(), 1)
		lu.assertEquals(VirtualSpaces.spaceStrategy:getStorageSpace(), 2)
	end)
end

function TestEmulatedSpace:testInitForgetsDestroyedHiddenWindows()
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
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(100), {"emulated-storage"})

		filterCallbacks[_G.hs.window.filter.windowDestroyed](win)

		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(100), {"emulated-active"})
	end)
end

function TestEmulatedSpace:testInitSwitchesVirtualSpaceWhenHiddenWindowFocused()
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
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(200), {"emulated-storage"})

		focusedWindow = win2
		for _, cb in ipairs(filterCallbacks[_G.hs.window.filter.windowFocused]) do
			cb(win2)
		end

		lu.assertEquals(VirtualSpaces.model:getCurrentVirtualSpace(), 2)
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(200), {"emulated-active"})
		lu.assertEquals(VirtualSpaces.spaceStrategy:windowSpaces(100), {"emulated-storage"})
	end)
end

function TestEmulatedSpace:testInitHidesWindowsThroughWindowCache()
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

return TestEmulatedSpace
