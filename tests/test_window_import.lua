local lu = require('luaunit')

TestWindowImport = {}

function TestWindowImport:setUp()
	local helpers = require('tests/test_helpers')

	self.helpers = helpers
	self.mockFocusedWindow = nil

	local filterNew
	filterNew, self.filterCallbacks = helpers.createFilterCapture()

	self.standardWindow = helpers.createHsWindow(100, "App1")

	self.nonStandardWindow = helpers.createHsWindow(200, "App2")
	self.nonStandardWindow.isStandard = function() return false end

	self.otherSpaceWindow = helpers.createHsWindow(300, "App3")

	_G.hs = helpers.createHsGlobal({
		filterNew = filterNew,
		windowGet = function(id)
			if id == 100 then return self.standardWindow end
			if id == 200 then return self.nonStandardWindow end
			if id == 300 then return self.otherSpaceWindow end
			return nil
		end,
		focusedWindow = function() return self.mockFocusedWindow end
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestWindowImport:_emit(eventType, window)
	self.helpers.emit(self.filterCallbacks, eventType, window)
end

function TestWindowImport:testFocusingUnknownWindowAssignsItToCurrentVirtualSpace()
	self:_emit(hs.window.filter.windowFocused, self.standardWindow)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 1)
end

function TestWindowImport:testFocusingUnknownWindowCachesIt()
	self:_emit(hs.window.filter.windowFocused, self.standardWindow)

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 1)
	lu.assertEquals(windows[1], self.standardWindow)
end

function TestWindowImport:testFocusingUnknownWindowAssignsItToActiveVirtualSpace()
	self.obj:switchToVirtualSpace(2)

	self:_emit(hs.window.filter.windowFocused, self.standardWindow)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 2)
end

function TestWindowImport:testFocusingKnownWindowDoesNotReassignIt()
	self.obj.model:assignWindowToVirtualSpace(100, 2)

	self:_emit(hs.window.filter.windowFocused, self.standardWindow)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 2)
end

function TestWindowImport:testFocusingNonStandardWindowDoesNotImportIt()
	self:_emit(hs.window.filter.windowFocused, self.nonStandardWindow)

	lu.assertNil(self.obj.model:getVirtualSpaceForWindow(200))
end

return TestWindowImport
