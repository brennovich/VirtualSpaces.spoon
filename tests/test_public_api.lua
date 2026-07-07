local lu = require('luaunit')
local helpers = require('tests/test_helpers')

TestPublicApi = {}

function TestPublicApi:setUp()
	self.spaces = {activeSpace = 1}
	self.mockWindows = {}

	for i, id in ipairs({100, 200, 300}) do
		self.mockWindows[id] = helpers.createHsWindow(id, string.format("App%d", i))
	end

	_G.hs = helpers.createHsGlobal({
		spaces = self.spaces,
		mockWindows = self.mockWindows,
		focusedWindow = function() return self.mockWindows[100] end,
		windowGet = function(id)
			return self.mockWindows[id]
		end
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestPublicApi:_registerWindow(window)
	helpers.registerWindow(self.obj, window)
end

function TestPublicApi:testGetCurrentVirtualSpaceReturnsDefaultSpaceOne()
	local currentSpace = self.obj:getCurrentVirtualSpace()

	lu.assertEquals(currentSpace, 1)
end

function TestPublicApi:testGetCurrentVirtualSpaceReturnsCurrentSpace()
	self.obj:switchToVirtualSpace(3)

	local currentSpace = self.obj:getCurrentVirtualSpace()

	lu.assertEquals(currentSpace, 3)
end

function TestPublicApi:testGetCurrentVirtualSpaceMetadataReturnsCorrectStructure()
	self.obj:switchToVirtualSpace(1)

	local metadata = self.obj:getCurrentVirtualSpaceMetadata()

	lu.assertNotNil(metadata.id)
	lu.assertNotNil(metadata.windowCount)
	lu.assertNotNil(metadata.windows)
	lu.assertNotNil(metadata.focusedWindow)
end

function TestPublicApi:testGetCurrentVirtualSpaceMetadataReturnsCorrectId()
	self.obj:switchToVirtualSpace(2)

	local metadata = self.obj:getCurrentVirtualSpaceMetadata()

	lu.assertEquals(metadata.id, 2)
end

function TestPublicApi:testGetCurrentVirtualSpaceMetadataReturnsCorrectWindowCount()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])
	self:_registerWindow(self.mockWindows[200])

	local metadata = self.obj:getCurrentVirtualSpaceMetadata()

	lu.assertEquals(metadata.windowCount, 2)
end

function TestPublicApi:testGetCurrentVirtualSpaceMetadataReturnsWindowsArray()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])
	self:_registerWindow(self.mockWindows[200])

	local metadata = self.obj:getCurrentVirtualSpaceMetadata()

	lu.assertEquals(#metadata.windows, 2)
	lu.assertEquals(metadata.windows[1], self.mockWindows[100])
	lu.assertEquals(metadata.windows[2], self.mockWindows[200])
end

function TestPublicApi:testGetCurrentVirtualSpaceMetadataReturnsFocusedWindow()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])

	local metadata = self.obj:getCurrentVirtualSpaceMetadata()

	lu.assertEquals(metadata.focusedWindow, self.mockWindows[100])
end

function TestPublicApi:testGetCurrentVirtualSpaceMetadataReturnsNilWhenNoFocusedWindow()
	_G.hs.window.focusedWindow = function() return nil end
	self.obj:switchToVirtualSpace(1)

	local metadata = self.obj:getCurrentVirtualSpaceMetadata()

	lu.assertNil(metadata.focusedWindow)
end

function TestPublicApi:testInitializesSubscriberSystemWithVirtualSpaceChangedEvent()
	lu.assertNotNil(self.obj.subscribers)
	lu.assertNotNil(self.obj.subscribers.virtualSpaceChanged)
	lu.assertEquals(type(self.obj.subscribers.virtualSpaceChanged), "table")
end

function TestPublicApi:testSubscriberSystemStartsEmpty()
	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 0)
end

function TestPublicApi:testSubscribeAddsCallbackToVirtualSpaceChanged()
	local called = false
	local callback = function(eventData) called = true end

	self.obj:subscribe("virtualSpaceChanged", callback)

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 1)
	lu.assertEquals(self.obj.subscribers.virtualSpaceChanged[1], callback)
end

function TestPublicApi:testSubscribeReturnselfForChaining()
	local callback = function(eventData) end

	local result = self.obj:subscribe("virtualSpaceChanged", callback)

	lu.assertEquals(result, self.obj)
end

function TestPublicApi:testSubscribeWithInvalidEventTypeDoesNotAddCallback()
	local callback = function(eventData) end
	self.obj:subscribe("invalidEvent", callback)

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 0)
end

function TestPublicApi:testSubscribeWithNonFunctionCallbackDoesNotAddCallback()
	self.obj:subscribe("virtualSpaceChanged", "not a function")

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 0)
end

function TestPublicApi:testUnsubscribeRemovesCallback()
	local callback = function(eventData) end
	self.obj:subscribe("virtualSpaceChanged", callback)

	self.obj:unsubscribe("virtualSpaceChanged", callback)

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 0)
end

function TestPublicApi:testUnsubscribeRemovesOnlySpecificCallback()
	local callback1 = function(eventData) end
	local callback2 = function(eventData) end
	local callback3 = function(eventData) end

	self.obj:subscribe("virtualSpaceChanged", callback1)
	self.obj:subscribe("virtualSpaceChanged", callback2)
	self.obj:subscribe("virtualSpaceChanged", callback3)

	self.obj:unsubscribe("virtualSpaceChanged", callback2)

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 2)
	lu.assertEquals(self.obj.subscribers.virtualSpaceChanged[1], callback1)
	lu.assertEquals(self.obj.subscribers.virtualSpaceChanged[2], callback3)
end

function TestPublicApi:testUnsubscribeReturnselfForChaining()
	local callback = function(eventData) end
	self.obj:subscribe("virtualSpaceChanged", callback)

	local result = self.obj:unsubscribe("virtualSpaceChanged", callback)

	lu.assertEquals(result, self.obj)
end

function TestPublicApi:testUnsubscribeWithInvalidEventTypeDoesNotError()
	local callback = function(eventData) end

	self.obj:unsubscribe("invalidEvent", callback)

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 0)
end

function TestPublicApi:testUnsubscribeWithNonExistentCallbackDoesNotError()
	local callback1 = function(eventData) end
	local callback2 = function(eventData) end
	self.obj:subscribe("virtualSpaceChanged", callback1)

	self.obj:unsubscribe("virtualSpaceChanged", callback2)

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 1)
end

function TestPublicApi:testDispatchEventSendsEventDataToSubscribers()
	self.obj:switchToVirtualSpace(2)
	self:_registerWindow(self.mockWindows[100])

	local callCount = 0
	local receivedEventData = nil
	self.obj:subscribe("virtualSpaceChanged", function(eventData)
		callCount = callCount + 1
		receivedEventData = eventData
	end)

	self.obj:_dispatchEvent("virtualSpaceChanged")

	lu.assertEquals(callCount, 1)
	lu.assertEquals(receivedEventData.eventType, "virtualSpaceChanged")
	lu.assertEquals(receivedEventData.currentSpace.id, 2)
	lu.assertEquals(receivedEventData.currentSpace.windowCount, 1)
	lu.assertNotNil(receivedEventData.currentSpace.windows)
	lu.assertNotNil(receivedEventData.currentSpace.focusedWindow)
end

function TestPublicApi:testDispatchEventCallsAllSubscribersDespiteCallbackError()
	local callCount1 = 0
	local callCount2 = 0

	self.obj:subscribe("virtualSpaceChanged", function() callCount1 = callCount1 + 1 end)
	self.obj:subscribe("virtualSpaceChanged", function() error("test error") end)
	self.obj:subscribe("virtualSpaceChanged", function() callCount2 = callCount2 + 1 end)

	self.obj:_dispatchEvent("virtualSpaceChanged")

	lu.assertEquals(callCount1, 1)
	lu.assertEquals(callCount2, 1)
end

function TestPublicApi:testDispatchEventWithNoSubscribersOrInvalidEventTypeDoesNotError()
	self.obj:_dispatchEvent("virtualSpaceChanged")
	self.obj:_dispatchEvent("invalidEvent")

	lu.assertEquals(#self.obj.subscribers.virtualSpaceChanged, 0)
end

function TestPublicApi:testSwitchToVirtualSpaceNotifiesSubscribersAfterSpaceChange()
	local callCount = 0
	local receivedSpaceId = nil
	local currentSpaceDuringCallback = nil

	self.obj:subscribe("virtualSpaceChanged", function(eventData)
		callCount = callCount + 1
		receivedSpaceId = eventData.currentSpace.id
		currentSpaceDuringCallback = self.obj.model:getCurrentVirtualSpace()
	end)

	self.obj:switchToVirtualSpace(3)

	lu.assertEquals(callCount, 1)
	lu.assertEquals(receivedSpaceId, 3)
	lu.assertEquals(currentSpaceDuringCallback, 3)
end

function TestPublicApi:testSwitchToVirtualSpaceHidesCurrentSpaceWindowsAndShowsTargetWindows()
	self.obj.windowCache:add(self.mockWindows[100])
	self.obj.windowCache:add(self.mockWindows[200])
	self.obj.model:assignWindowToVirtualSpace(100, 1)
	self.obj.model:assignWindowToVirtualSpace(200, 2)

	self.obj:switchToVirtualSpace(2)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {"storage"})
	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(200), {"active"})
end

function TestPublicApi:_switchWhileOffManagedSpace(targetVirtualSpace)
	local gotoCalls = {}
	local activeNativeSpace = 1

	_G.hs = helpers.createHsGlobal({
		spaces = {activeSpace = 1},
		windowSpaces = function() return {1} end,
		activeSpaceOnScreen = function() return activeNativeSpace end,
		gotoSpace = function(spaceID) table.insert(gotoCalls, spaceID) end,
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	VirtualSpaces:init()

	activeNativeSpace = 99
	VirtualSpaces:switchToVirtualSpace(targetVirtualSpace)

	return gotoCalls
end

function TestPublicApi:testSwitchToEmptyVirtualSpaceWhileOffManagedNavigatesToManagedSpace()
	for _, target in ipairs({1, 2}) do
		lu.assertEquals(self:_switchWhileOffManagedSpace(target), {1})
	end
end

function TestPublicApi:testGotoSpaceInducedFocusDoesNotSwitchAwayFromEmptySpace()
	local filterNew, filterCallbacks = helpers.createFilterCapture()
	local activeNativeSpace = 1
	local focused = nil
	local windows = {}
	for _, id in ipairs({72, 88, 187}) do
		windows[id] = helpers.createHsWindow(id, "App")
	end

	_G.hs = helpers.createHsGlobal({
		spaces = {activeSpace = 1},
		windowSpaces = function() return {1} end,
		activeSpaceOnScreen = function() return activeNativeSpace end,
		filterNew = filterNew,
		windowGet = function(id) return windows[id] end,
		focusedWindow = function() return focused end,
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	VirtualSpaces:init()

	for _, id in ipairs({72, 88, 187}) do
		VirtualSpaces.windowCache:add(windows[id])
		VirtualSpaces.model:assignWindowToVirtualSpace(id, 1)
	end

	activeNativeSpace = 99
	VirtualSpaces:switchToVirtualSpace(3)

	focused = windows[187]
	helpers.emit(filterCallbacks, _G.hs.window.filter.windowFocused, windows[187])

	lu.assertEquals(VirtualSpaces:getCurrentVirtualSpace(), 3)
end

function TestPublicApi:testSwitchToNonEmptyVirtualSpaceWhileOffManagedRestoresFocusWithoutGotoSpace()
	local gotoCalls = {}
	local activeNativeSpace = 1
	local win = helpers.createHsWindow(700, "App")
	local focusCalls = {}
	win.focus = function() table.insert(focusCalls, 700) end

	_G.hs = helpers.createHsGlobal({
		spaces = {activeSpace = 1},
		windowSpaces = function() return {1} end,
		activeSpaceOnScreen = function() return activeNativeSpace end,
		gotoSpace = function(spaceID) table.insert(gotoCalls, spaceID) end,
		windowGet = function(id) return id == 700 and win or nil end,
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	VirtualSpaces:init()

	VirtualSpaces.windowCache:add(win)
	VirtualSpaces.model:assignWindowToVirtualSpace(700, 2)

	activeNativeSpace = 99
	VirtualSpaces:switchToVirtualSpace(2)

	lu.assertEquals(gotoCalls, {})
	lu.assertEquals(focusCalls, {700})
end

function TestPublicApi:testSwitchToSameVirtualSpaceDoesNotTriggerEvent()
	local callCount = 0
	local callback = function(eventData) callCount = callCount + 1 end

	self.obj:subscribe("virtualSpaceChanged", callback)
	self.obj:switchToVirtualSpace(1)

	lu.assertEquals(callCount, 0)
end

function TestPublicApi:testSwitchingAwayCapturesCurrentFocusedWindowBeforeLeaving()
	local focusCalls = {}

	local tab1 = helpers.createHsWindow(100, "Terminal")
	local tab2 = helpers.createHsWindow(200, "Terminal")
	tab1.focus = function() table.insert(focusCalls, 100) end
	tab2.focus = function() table.insert(focusCalls, 200) end

	self.mockWindows[100] = tab1
	self.mockWindows[200] = tab2
	self.obj.windowCache:add(tab1)
	self.obj.windowCache:add(tab2)
	self.obj.model:assignWindowToVirtualSpace(100, 1)
	self.obj.model:assignWindowToVirtualSpace(200, 1)
	self.obj.model:saveFocusedWindowInVirtualSpace(1, 200)

	_G.hs.window.focusedWindow = function() return tab1 end
	self.obj:switchToVirtualSpace(2)

	_G.hs.window.focusedWindow = function() return nil end
	self.obj:switchToVirtualSpace(1)

	lu.assertEquals(focusCalls[#focusCalls], 100)
end

return TestPublicApi
