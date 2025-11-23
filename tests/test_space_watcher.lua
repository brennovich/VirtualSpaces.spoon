local lu = require('luaunit')

TestSpaceWatcher = {}

function TestSpaceWatcher:setUp()
	self.spaces = {activeSpace = 1, storageSpace = 2}
	self.currentSpace = 1
	self.spaceWatcherCallback = nil
	self.focusedWindowValue = nil
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

	_G.hs = {
		spoons = {
			scriptPath = function() return "./" end
		},
		spaces = {
			moveWindowToSpace = function(win, space)
				table.insert(self.movedWindows, {windowId = win, space = space})
			end,
			activeSpaceOnScreen = function()
				return self.currentSpace
			end,
			allSpaces = function()
				return {["screen-123"] = {self.spaces.activeSpace, self.spaces.storageSpace}}
			end,
			openMissionControl = function() end,
			removeSpace = function() end,
			addSpaceToScreen = function() end,
			watcher = {
				new = function(callback)
					self.spaceWatcherCallback = callback
					return {start = function() end}
				end
			}
		},
		screen = {
			mainScreen = function()
				return { getUUID = function() return "screen-123" end }
			end
		},
		window = {
			focusedWindow = function()
				return self.focusedWindowValue
			end,
			get = function(id)
				if id == 100 then return self.window1 end
				if id == 200 then return self.window2 end
				return nil
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

function TestSpaceWatcher:testPreservesFocusWhenUserNavigatesViaDockToStorageSpace()
	self.obj.model:assignWindowToVirtualSpace(self.window1:id(), 1)
	self.obj.model:assignWindowToVirtualSpace(self.window2:id(), 2)
	self.obj.model:assignWindowToVirtualSpace(300, 3)
	self.obj.model:setCurrentVirtualSpace(1)
	self.focusedWindowValue = self.window1
	self.obj.model:saveFocusedWindowInVirtualSpace(1, self.window1:id())

	self.focusedWindowValue = self.window2
	self.focusCalls = {}
	self.movedWindows = {}

	self.currentSpace = 2
	self.spaceWatcherCallback()

	lu.assertEquals(self.obj.model:getCurrentVirtualSpace(), 2)
	lu.assertEquals(#self.focusCalls, 0)
	lu.assertEquals(#self.movedWindows, 3)
	lu.assertEquals(self.movedWindows[1], {windowId = 200, space = 2})
	lu.assertEquals(self.movedWindows[2], {windowId = 100, space = 1})
	lu.assertEquals(self.movedWindows[3], {windowId = 300, space = 1})
end

return TestSpaceWatcher
