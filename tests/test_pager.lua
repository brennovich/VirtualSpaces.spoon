local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local Pager = require('Pager')

TestPager = {}

local function screenReturning(frame)
	return {
		mainScreen = function()
			return {frame = function() return frame end}
		end
	}
end

local findText = helpers.findCanvasText

function TestPager:_newPager(frame)
	local canvas, created = helpers.createCanvasMock()
	local pager = Pager.new({
		hsCanvas = canvas,
		hsScreen = screenReturning(frame or {x = 0, y = 25, w = 1792, h = 1095}),
	})
	return pager, created, canvas
end

function TestPager:testUpdateCreatesSingleCanvas()
	local pager, created = self:_newPager()

	pager:update(2)

	lu.assertEquals(#created, 1)
end

function TestPager:testUpdateRendersSpaceNumber()
	local pager, created = self:_newPager()

	pager:update(2)

	lu.assertEquals(findText(created[1].elements), "2")
end

function TestPager:testUpdatePositionsFlushBottomRight()
	local pager, created = self:_newPager({x = 0, y = 25, w = 1792, h = 1095})

	pager:update(1)

	local f = created[1]:frame()
	lu.assertEquals(f.x + f.w, 1792)
	lu.assertEquals(f.y + f.h, 1120)
end

function TestPager:testUpdateCoversNubRegion()
	local pager, created = self:_newPager()

	pager:update(1)

	local f = created[1]:frame()
	lu.assertTrue(f.w >= 44)
	lu.assertTrue(f.h >= 44)
end

function TestPager:testUpdateShowsCanvasAtOverlayLevel()
	local pager, created, canvas = self:_newPager()

	pager:update(1)

	lu.assertTrue(created[1].shownCount >= 1)
	lu.assertEquals(created[1].levelValue, canvas.windowLevels.overlay)
end

function TestPager:testSecondUpdateReusesCanvasAndChangesNumber()
	local pager, created = self:_newPager()

	pager:update(2)
	pager:update(3)

	lu.assertEquals(#created, 1)
	lu.assertEquals(findText(created[1].elements), "3")
end

function TestPager:testUpdateStaysFlushOnSmallerScreen()
	local pager, created = self:_newPager({x = 0, y = 0, w = 800, h = 600})

	pager:update(1)

	local f = created[1]:frame()
	lu.assertEquals(f.x + f.w, 800)
	lu.assertEquals(f.y + f.h, 600)
	lu.assertTrue(f.w >= 44)
	lu.assertTrue(f.h >= 44)
end

function TestPager:testDeleteRemovesCanvas()
	local pager, created = self:_newPager()

	pager:update(1)
	pager:delete()

	lu.assertTrue(created[1].deleted)
end

function TestPager:testUpdateAfterDeleteCreatesNewCanvas()
	local pager, created = self:_newPager()

	pager:update(1)
	pager:delete()
	pager:update(1)

	lu.assertEquals(#created, 2)
end

return TestPager
