local lu = require('luaunit')

TestMoveWindowToVirtualSpace = {}

function TestMoveWindowToVirtualSpace:setUp()
	self.spaces = {activeSpace = 1, storageSpace = 2}
	self.movedWindows = {}
	self.focusedWindowValue = nil

	self.mockWindow = {
		id = function() return 100 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		focus = function() end,
		tabCount = function() return 1 end,
		frame = function() return {x = 0, y = 0, w = 800, h = 600} end,
		application = function() return {name = function() return "TestApp" end} end
	}

	_G.hs = {
		spoons = {
			scriptPath = function() return "./" end
		},
		spaces = {
			moveWindowToSpace = function(window, space)
				table.insert(self.movedWindows, {window = window, space = space})
			end,
			activeSpaceOnScreen = function() return self.spaces.activeSpace end,
			setDefaultMCwaitTime = function() end,
			allSpaces = function()
				return {["screen-123"] = {self.spaces.activeSpace, self.spaces.storageSpace}}
			end,
			removeSpace = function() end,
			gotoSpace = function() end,
			addSpaceToScreen = function() end,
			watcher = { new = function() return {start = function() end} end }
		},
		screen = {
			mainScreen = function()
				return { getUUID = function() return "screen-123" end }
			end
		},
		timer = {
			usleep = function() end
		},
		eventtap = {
			keyStroke = function() end
		},
		window = {
			focusedWindow = function() return self.focusedWindowValue end,
			get = function(id)
				if id == 100 then
					return {
						id = function() return 100 end,
						isStandard = function() return true end,
						isMinimized = function() return false end,
						focus = function() end,
						tabCount = function() return 1 end,
						frame = function() return {x = 0, y = 0, w = 800, h = 600} end,
						application = function() return {name = function() return "TestApp" end} end
					}
				elseif id == 200 then
					return {
						id = function() return 200 end,
						isStandard = function() return true end,
						isMinimized = function() return false end,
						focus = function() end,
						tabCount = function() return 1 end,
						frame = function() return {x = 0, y = 0, w = 800, h = 600} end,
						application = function() return {name = function() return "TestApp" end} end
					}
				end
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

function TestMoveWindowToVirtualSpace:testMovesFocusedWindowWhenWindowParameterIsNil()
	self.focusedWindowValue = self.mockWindow
	self.obj:switchToVirtualSpace(1)
	self.movedWindows = {}

	self.obj:moveWindowToVirtualSpace(nil, 2)

	lu.assertEquals(#self.movedWindows, 1)
	lu.assertEquals(self.movedWindows[1].window.id(), 100)
	lu.assertEquals(self.movedWindows[1].space, self.spaces.storageSpace)
end

function TestMoveWindowToVirtualSpace:testMovesExplicitWindowWhenProvided()
	local explicitWindow = {
		id = function() return 200 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		focus = function() end,
		tabCount = function() return 1 end,
		frame = function() return {x = 0, y = 0, w = 800, h = 600} end,
		application = function() return {name = function() return "TestApp" end} end
	}

	self.obj:switchToVirtualSpace(1)
	self.movedWindows = {}

	self.obj:moveWindowToVirtualSpace(explicitWindow, 2)

	lu.assertEquals(#self.movedWindows, 1)
	lu.assertEquals(self.movedWindows[1].window.id(), 200)
	lu.assertEquals(self.movedWindows[1].space, self.spaces.storageSpace)
end

function TestMoveWindowToVirtualSpace:testDoesNothingWhenNoFocusedWindowAndWindowIsNil()
	self.focusedWindowValue = nil
	self.obj:switchToVirtualSpace(1)
	self.movedWindows = {}

	self.obj:moveWindowToVirtualSpace(nil, 2)

	lu.assertEquals(#self.movedWindows, 0)
end

function TestMoveWindowToVirtualSpace:testDoesNothingWhenVirtualSpaceIsInvalid()
	self.focusedWindowValue = self.mockWindow
	self.obj:switchToVirtualSpace(1)
	self.movedWindows = {}

	self.obj:moveWindowToVirtualSpace(nil, 0)

	lu.assertEquals(#self.movedWindows, 0)
end

function TestMoveWindowToVirtualSpace:testDoesNothingWhenVirtualSpaceIsNil()
	self.focusedWindowValue = self.mockWindow
	self.obj:switchToVirtualSpace(1)
	self.movedWindows = {}

	self.obj:moveWindowToVirtualSpace(nil, nil)

	lu.assertEquals(#self.movedWindows, 0)
end

function TestMoveWindowToVirtualSpace:testAssignsWindowToVirtualSpaceInModel()
	self.focusedWindowValue = self.mockWindow
	self.obj:switchToVirtualSpace(1)

	self.obj:moveWindowToVirtualSpace(nil, 2)

	local virtualSpace = self.obj.model:getVirtualSpaceForWindow(100)
	lu.assertEquals(virtualSpace, 2)
end

function TestMoveWindowToVirtualSpace:testMovesToActiveSpaceWhenTargetIsCurrentVirtualSpace()
	self.focusedWindowValue = self.mockWindow
	self.obj:switchToVirtualSpace(1)
	self.movedWindows = {}

	self.obj:moveWindowToVirtualSpace(nil, 1)

	lu.assertEquals(#self.movedWindows, 1)
	lu.assertEquals(self.movedWindows[1].space, self.spaces.activeSpace)
end

return TestMoveWindowToVirtualSpace
