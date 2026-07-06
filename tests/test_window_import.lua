local lu = require('luaunit')

TestWindowImport = {}

function TestWindowImport:setUp()
	local helpers = require('tests/test_helpers')

	self.filterCallbacks = {}
	self.mockFocusedWindow = nil

	local filterCallbacks = self.filterCallbacks

	self.standardWindow = helpers.createHsWindow(100, "App1")

	self.nonStandardWindow = helpers.createHsWindow(200, "App2")
	self.nonStandardWindow.isStandard = function() return false end

	self.otherSpaceWindow = helpers.createHsWindow(300, "App3")

	_G.hs = helpers.createHsGlobal({
		filterNew = function()
			return {
				subscribe = function(_, eventType, cb)
					filterCallbacks[eventType] = filterCallbacks[eventType] or {}
					table.insert(filterCallbacks[eventType], cb)
				end,
				setCurrentSpace = function() end
			}
		end,
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
	for _, cb in ipairs(self.filterCallbacks[eventType] or {}) do
		cb(window)
	end
end

function TestWindowImport:testFocusingUnknownWindowAssignsItToCurrentVirtualSpace()
	self:_emit(3, self.standardWindow)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 1)
end

function TestWindowImport:testFocusingUnknownWindowCachesIt()
	self:_emit(3, self.standardWindow)

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 1)
	lu.assertEquals(windows[1], self.standardWindow)
end

function TestWindowImport:testFocusingUnknownWindowAssignsItToActiveVirtualSpace()
	self.obj:switchToVirtualSpace(2)

	self:_emit(3, self.standardWindow)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 2)
end

function TestWindowImport:testFocusingKnownWindowDoesNotReassignIt()
	self.obj.model:assignWindowToVirtualSpace(100, 2)

	self:_emit(3, self.standardWindow)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 2)
end

function TestWindowImport:testFocusingNonStandardWindowDoesNotImportIt()
	self:_emit(3, self.nonStandardWindow)

	lu.assertNil(self.obj.model:getVirtualSpaceForWindow(200))
end

return TestWindowImport
