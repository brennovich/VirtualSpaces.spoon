local lu = require('luaunit')
local helpers = require('tests/test_helpers')

TestMoveWindowToVirtualSpace = {}

local ACTIVE = "active"
local STORAGE = "storage"

function TestMoveWindowToVirtualSpace:setUp()
	self.focusedWindowValue = nil
	self.mockWindows = {
		[100] = helpers.createHsWindow(100, "TestApp"),
		[200] = helpers.createHsWindow(200, "TestApp"),
	}

	_G.hs = helpers.createHsGlobal({
		mockWindows = self.mockWindows,
		focusedWindow = function() return self.focusedWindowValue end,
		windowGet = function(id) return self.mockWindows[id] end,
	})

	package.loaded['init'] = nil
	self.obj = require('init')
	self.obj:init()
end

function TestMoveWindowToVirtualSpace:testMovesFocusedWindowWhenWindowParameterIsNil()
	self.focusedWindowValue = self.mockWindows[100]

	self.obj:moveWindowToVirtualSpace(nil, 2)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {STORAGE})
end

function TestMoveWindowToVirtualSpace:testMovesExplicitWindowWhenProvided()
	self.obj:moveWindowToVirtualSpace(self.mockWindows[200], 2)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(200), {STORAGE})
end

function TestMoveWindowToVirtualSpace:testDoesNothingWhenNoFocusedWindowAndWindowIsNil()
	self.focusedWindowValue = nil

	self.obj:moveWindowToVirtualSpace(nil, 2)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {ACTIVE})
end

function TestMoveWindowToVirtualSpace:testDoesNothingWhenVirtualSpaceIsInvalid()
	self.focusedWindowValue = self.mockWindows[100]

	self.obj:moveWindowToVirtualSpace(nil, 0)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {ACTIVE})
	lu.assertNil(self.obj.model:getVirtualSpaceForWindow(100))
end

function TestMoveWindowToVirtualSpace:testDoesNothingWhenVirtualSpaceIsNil()
	self.focusedWindowValue = self.mockWindows[100]

	self.obj:moveWindowToVirtualSpace(nil, nil)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {ACTIVE})
	lu.assertNil(self.obj.model:getVirtualSpaceForWindow(100))
end

function TestMoveWindowToVirtualSpace:testAssignsWindowToVirtualSpaceInModel()
	self.focusedWindowValue = self.mockWindows[100]

	self.obj:moveWindowToVirtualSpace(nil, 2)

	lu.assertEquals(self.obj.model:getVirtualSpaceForWindow(100), 2)
end

function TestMoveWindowToVirtualSpace:testMovesToActiveSpaceWhenTargetIsCurrentVirtualSpace()
	self.focusedWindowValue = self.mockWindows[100]

	self.obj:moveWindowToVirtualSpace(nil, 2)
	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {STORAGE})

	self.obj:moveWindowToVirtualSpace(nil, 1)

	lu.assertEquals(self.obj.spaceStrategy:windowSpaces(100), {ACTIVE})
end

return TestMoveWindowToVirtualSpace
