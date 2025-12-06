local lu = require('luaunit')
local Window = require('Window')
local helpers = require('tests/test_helpers')

TestGetWindowsApi = {}

function TestGetWindowsApi:setUp()
	self.spaces = {activeSpace = 1, storageSpace = 2}
	self.movedWindows = {}
	self.mockWindows = {}

	 for i, id in ipairs({100, 200, 300}) do
		 self.mockWindows[id] = helpers.createHsWindow(id, string.format("App%d", i))
	 end

	_G.hs = {
		spoons = {
			scriptPath = function() return "./" end
		},
		spaces = {
			moveWindowToSpace = function(window, space)
				table.insert(self.movedWindows, {window = window, space = space})
			end,
			windowSpaces = function(winId)
				return {self.spaces.activeSpace}
			end,
			activeSpaceOnScreen = function() return self.spaces.activeSpace end,
			allSpaces = function()
				return {["screen-123"] = {self.spaces.activeSpace, self.spaces.storageSpace}}
			end,
			openMissionControl = function() end,
			removeSpace = function() end,
			addSpaceToScreen = function() end,
			watcher = { new = function() return {start = function() end} end }
		},
		screen = {
			mainScreen = function()
				return { getUUID = function() return "screen-123" end }
			end
		},
		window = {
			focusedWindow = function() return nil end,
			get = function(id)
				return self.mockWindows[id]
			end,
			allWindows = function() return {} end,
			filter = {
				new = function()
					return {
						subscribe = function() end,
						setCurrentSpace = function() end
					}
				end,
				windowCreated = 1,
				windowDestroyed = 2
			}
		}
	}

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestGetWindowsApi:_registerWindow(window)
	self.obj.model:assignWindowToSpace(Window.new(window), self.obj.model:getCurrentVirtualSpace())
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

function TestGetWindowsApi:testGetWindowsForCurrentVirtualSpaceReturnsCorrectWindowObjects()
	self.obj:switchToVirtualSpace(1)
	self:_registerWindow(self.mockWindows[100])
	self:_registerWindow(self.mockWindows[200])

	local windows = self.obj:getWindowsForCurrentVirtualSpace()

	lu.assertEquals(#windows, 2)
	lu.assertEquals(windows[1], self.mockWindows[100])
	lu.assertEquals(windows[2], self.mockWindows[200])
end

return TestGetWindowsApi
