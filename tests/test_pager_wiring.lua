local lu = require('luaunit')
local helpers = require('tests/test_helpers')

TestPagerWiring = {}

local findText = helpers.findCanvasText

function TestPagerWiring:_initWith(pagerConfig)
	local canvas, created = helpers.createCanvasMock()

	_G.hs = helpers.createHsGlobal({canvas = canvas})

	package.loaded['init'] = nil
	local VirtualSpaces = require('init')
	VirtualSpaces.pager = pagerConfig
	VirtualSpaces:init()

	return VirtualSpaces, created
end

function TestPagerWiring:testEnabledPagerRendersCurrentSpaceOnInit()
	local _, created = self:_initWith({enabled = true})

	lu.assertEquals(#created, 1)
	lu.assertEquals(findText(created[1].elements), "1")
end

function TestPagerWiring:testDisabledPagerCreatesNoCanvas()
	local _, created = self:_initWith({enabled = false})

	lu.assertEquals(#created, 0)
end

function TestPagerWiring:testMissingPagerConfigCreatesNoCanvas()
	local _, created = self:_initWith(nil)

	lu.assertEquals(#created, 0)
end

function TestPagerWiring:testSwitchingVirtualSpaceUpdatesPager()
	local obj, created = self:_initWith({enabled = true})

	obj:switchToVirtualSpace(3)

	lu.assertEquals(findText(created[1].elements), "3")
end

return TestPagerWiring
