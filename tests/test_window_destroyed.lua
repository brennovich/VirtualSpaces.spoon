local lu = require('luaunit')

TestWindowDestroyed = {}

function TestWindowDestroyed:setUp()
	local helpers = require('tests/test_helpers')

	self.focusCalls = {}
	self.filterCallbacks = {}

	local filterCallbacks = self.filterCallbacks
	local focusCalls = self.focusCalls

	self.window1 = {
		id = function() return 100 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		tabCount = function() return 1 end,
		frame = function() return {x = 0, y = 0, w = 800, h = 600} end,
		application = function() return {name = function() return "App1" end} end,
		focus = function() table.insert(focusCalls, 100) end
	}

	self.window2 = {
		id = function() return 200 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		tabCount = function() return 1 end,
		frame = function() return {x = 0, y = 200, w = 800, h = 600} end,
		application = function() return {name = function() return "App2" end} end,
		focus = function() table.insert(focusCalls, 200) end
	}

	self.window3a = {
		id = function() return 300 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		tabCount = function() return 1 end,
		frame = function() return {x = 400, y = 0, w = 800, h = 600} end,
		application = function() return {name = function() return "Terminal" end} end,
		focus = function() table.insert(focusCalls, 300) end
	}

	self.window3b = {
		id = function() return 301 end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		tabCount = function() return 2 end,
		frame = function() return {x = 400, y = 0, w = 800, h = 600} end,
		application = function() return {name = function() return "Terminal" end} end,
		focus = function() table.insert(focusCalls, 301) end
	}

	_G.hs = helpers.createHsGlobal({
		filterNew = function()
			return {
				subscribe = function(_, eventType, cb)
					filterCallbacks[eventType] = cb
				end,
				setCurrentSpace = function() end
			}
		end,
		windowGet = function(id)
			if id == 100 then return self.window1 end
			if id == 200 then return self.window2 end
			if id == 300 then return self.window3a end
			if id == 301 then return self.window3b end
			return nil
		end,
		focusedWindow = function() return nil end
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestWindowDestroyed:testNonTabbedWindowDestroyedRestoresFocus()
	self.filterCallbacks[1](self.window1)
	self.filterCallbacks[3](self.window1)
	self.filterCallbacks[1](self.window2)

	self.filterCallbacks[2](self.window2)

	lu.assertTrue(table.contains(self.focusCalls, 100))
end

function TestWindowDestroyed:testTabbedWindowDestroyedDoesNotRestoreFocus()
	self.filterCallbacks[1](self.window3a)
	self.filterCallbacks[3](self.window3a)
	self.filterCallbacks[1](self.window3b)
	self.filterCallbacks[3](self.window3b)
	self.filterCallbacks[1](self.window1)

	self.filterCallbacks[2](self.window3b)

	lu.assertEquals(self.focusCalls, {})
end

return TestWindowDestroyed
