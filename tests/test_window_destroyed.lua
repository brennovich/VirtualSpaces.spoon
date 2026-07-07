local lu = require('luaunit')

TestWindowDestroyed = {}

function TestWindowDestroyed:setUp()
	local helpers = require('tests/test_helpers')

	self.focusCalls = {}
	self.filterCallbacks = {}
	self.mockFocusedWindow = nil

	local filterCallbacks = self.filterCallbacks
	local focusCalls = self.focusCalls

	self.window1 = helpers.createHsWindow(100, "App1", {
		frame = {x = 0, y = 0, w = 800, h = 600},
		onFocus = function() table.insert(focusCalls, 100) end
	})

	self.window2 = helpers.createHsWindow(200, "App2", {
		frame = {x = 0, y = 200, w = 800, h = 600},
		onFocus = function() table.insert(focusCalls, 200) end
	})

	self.window3a = helpers.createHsWindow(300, "Terminal", {
		frame = {x = 400, y = 0, w = 800, h = 600},
		onFocus = function() table.insert(focusCalls, 300) end
	})

	self.window3b = helpers.createHsWindow(301, "Terminal", {
		frame = {x = 400, y = 0, w = 800, h = 600},
		tabCount = 2,
		onFocus = function() table.insert(focusCalls, 301) end
	})

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
			if id == 100 then return self.window1 end
			if id == 200 then return self.window2 end
			if id == 300 then return self.window3a end
			if id == 301 then return self.window3b end
			return nil
		end,
		focusedWindow = function() return self.mockFocusedWindow end
	})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	self.obj = VirtualSpaces
	self.obj:init()
end

function TestWindowDestroyed:_emit(eventType, window)
	for _, cb in ipairs(self.filterCallbacks[eventType] or {}) do
		cb(window)
	end
end

function TestWindowDestroyed:testNonTabbedWindowDestroyedRestoresFocus()
	self:_emit(1, self.window1)
	self:_emit(3, self.window1)
	self:_emit(1, self.window2)

	self:_emit(2, self.window2)

	lu.assertTrue(table.contains(self.focusCalls, 100))
end

function TestWindowDestroyed:testTabbedWindowDestroyedDoesNotRestoreFocus()
	self:_emit(1, self.window3a)
	self:_emit(3, self.window3a)
	self:_emit(1, self.window3b)
	self:_emit(3, self.window3b)
	self:_emit(1, self.window1)

	self:_emit(2, self.window3b)

	lu.assertEquals(self.focusCalls, {})
end

function TestWindowDestroyed:testTabSiblingFocusPreservedWhenSeparateWindowClosed()
	self:_emit(1, self.window3a)
	self:_emit(1, self.window3b)
	self:_emit(3, self.window3a)
	self:_emit(1, self.window1)
	self:_emit(3, self.window1)

	self.mockFocusedWindow = self.window3b
	self:_emit(2, self.window1)

	lu.assertEquals(self.obj.model:getFocusedWindowForVirtualSpace(1), 301)
	lu.assertFalse(table.contains(self.focusCalls, 300))
end

return TestWindowDestroyed
