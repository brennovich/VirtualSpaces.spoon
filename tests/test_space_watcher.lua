local lu = require('luaunit')

TestSpaceWatcher = {}

function TestSpaceWatcher:setUp()
	local helpers = require('tests/test_helpers')

	self.spaces = {activeSpace = 1, storageSpace = 2}
	self.currentSpace = 1
	self.spaceWatcherCallback = nil
	self.focusedWindowValue = nil
	self.windowSpaces = {}
	self.focusCalls = {}
	self.movedWindows = {}

	self.window1 = {
		id = function() return 100 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		focus = function()
			table.insert(self.focusCalls, 100)
		end
	}

	self.window2 = {
		id = function() return 200 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		focus = function()
			table.insert(self.focusCalls, 200)
		end
	}

	_G.hs = helpers.createHsGlobal({
		spaces = self.spaces,
		moveWindowToSpace = function(win, space)
			table.insert(self.movedWindows, {windowId = win, space = space})
		end,
		activeSpaceOnScreen = function()
			return self.currentSpace
		end,
		windowSpaces = function(win)
			return self.windowSpaces[win] or {}
		end,
		watcher = {
			new = function(callback)
				self.spaceWatcherCallback = callback
				return {start = function() end}
			end
		},
		focusedWindow = function()
			return self.focusedWindowValue
		end,
		windowGet = function(id)
			if id == 100 then return self.window1 end
			if id == 200 then return self.window2 end
			return nil
		end
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestSpaceWatcher:testUserNavigatesViaDockToStorageSpace()
	self.obj.model:assignWindowToVirtualSpace(self.window1:id(), 1)
	self.obj.model:assignWindowToVirtualSpace(self.window2:id(), 2)
	self.obj.model:assignWindowToVirtualSpace(300, 3)
	self.obj.model:setCurrentVirtualSpace(1)

	self.focusedWindowValue = self.window1
	self.obj.model:saveFocusedWindowInVirtualSpace(1, self.window1:id())

	self.focusedWindowValue = self.window2
	self.focusCalls = {}
	self.movedWindows = {}

	self.windowSpaces = {
		[100] = {1},
		[200] = {2},
		[300] = {2}
	}

	self.currentSpace = 2
	self.spaceWatcherCallback()

	lu.assertEquals(self.obj.model:getCurrentVirtualSpace(), 2)
	lu.assertEquals(self.obj.model:getFocusedWindowForVirtualSpace(2), nil, "Focus must be saved when switching spaces")
	lu.assertEquals(#self.focusCalls, 0, "Respect native focus and don't restore previously focused window")
	lu.assertEquals(#self.movedWindows, 1)
	lu.assertEquals(self.movedWindows[1], {windowId = 300, space = 1})
end

return TestSpaceWatcher
