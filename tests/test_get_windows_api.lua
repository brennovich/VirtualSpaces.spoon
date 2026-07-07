local lu = require('luaunit')
local helpers = require('tests/test_helpers')

TestGetWindowsApi = {}

function TestGetWindowsApi:setUp()
	self.spaces = {activeSpace = 1}
	self.mockWindows = {}

	for i, id in ipairs({100, 200, 300}) do
		self.mockWindows[id] = helpers.createHsWindow(id, string.format("App%d", i))
	end

	_G.hs = helpers.createHsGlobal({
		spaces = self.spaces,
		mockWindows = self.mockWindows,
		windowGet = function(id)
			return self.mockWindows[id]
		end
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestGetWindowsApi:_registerWindow(window)
	helpers.registerWindow(self.obj, window)
end

function TestGetWindowsApi:testGetWindowsForCurrentVirtualSpaceReturnsEmptyArrayWhenNoWindows()
	self.obj:switchToVirtualSpace(1)

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 0)
end

function TestGetWindowsApi:testGetWindowsForCurrentVirtualSpaceReturnsWindowObjects()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])
	self:_registerWindow(self.mockWindows[200])
	self:_registerWindow(self.mockWindows[300])

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 3)
	lu.assertEquals(windows[1].id(), 100)
	lu.assertEquals(windows[2].id(), 200)
	lu.assertEquals(windows[3].id(), 300)
	lu.assertEquals(windows[1], self.mockWindows[100])
	lu.assertEquals(windows[2], self.mockWindows[200])
	lu.assertEquals(windows[3], self.mockWindows[300])
end

function TestGetWindowsApi:testGetWindowsForCurrentVirtualSpaceFiltersDestroyedWindows()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])
	self:_registerWindow(self.mockWindows[200])
	self:_registerWindow(self.mockWindows[300])

	self.mockWindows[200].id = function() error("window destroyed") end
	self.mockWindows[200] = nil

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 2)
	lu.assertEquals(windows[1].id(), 100)
	lu.assertEquals(windows[2].id(), 300)
end

function TestGetWindowsApi:testGetWindowsForCurrentVirtualSpaceUsesCurrentSpace()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])
	self:_registerWindow(self.mockWindows[200])

	self.obj:switchToVirtualSpace(2)
	self:_registerWindow(self.mockWindows[300])

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 1)
	lu.assertEquals(windows[1].id(), 300)
end

return TestGetWindowsApi
