local lu = require('luaunit')

local TestHelpers = {}

function table.contains(tbl, element)
	for _, value in pairs(tbl) do
		if value == element then
			return true
		end
	end
	return false
end

function TestHelpers.createBasicDeps(overrides)
	overrides = overrides or {}
	return {
		windowMoverFn = overrides.windowMoverFn or function() end,
		windowSpaceGetter = overrides.windowSpaceGetter or function() return {} end,
		telemetry = overrides.telemetry
	}
end

function TestHelpers.createMoveTracker()
	local moves = {}
	return {
		record = function(winId, spaceId)
			table.insert(moves, {winId = winId, spaceId = spaceId})
		end,
		getMoves = function() return moves end,
		clear = function() moves = {} end,
		count = function() return #moves end,
		findMove = function(winId)
			for _, move in ipairs(moves) do
				if move.winId == winId then
					return move
				end
			end
			return nil
		end
	}
end

function TestHelpers.withHsGlobal(hsConfig, fn)
	local oldHs = _G.hs
	_G.hs = hsConfig
	local success, result = pcall(fn)
	_G.hs = oldHs
	if not success then
		error(result)
	end
	return result
end

function TestHelpers.createWindow(id, tabCount, frame, appName)
	return {
		id = id,
		tabCount = tabCount or 1,
		frame = frame or {x = 0, y = 0, w = 800, h = 600},
		appName = appName or "TestApp"
	}
end

function TestHelpers.createSimpleWindow(id)
	return TestHelpers.createWindow(id, 1, {x = 0, y = 0, w = 800, h = 600}, "TestApp")
end

return TestHelpers
