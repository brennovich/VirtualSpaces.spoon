local TestHelpers = {}

function table.contains(tbl, element)
	for _, value in pairs(tbl) do
		if value == element then
			return true
		end
	end
	return false
end

function TestHelpers.createMockWindow(id, options)
	options = options or {}
	return {
		id = function() return id end,
		isStandard = function() return options.isStandard ~= false end,
		isFullScreen = function() return options.isFullScreen or false end,
		isMinimized = function() return options.isMinimized or false end,
		focus = options.focus or function() end
	}
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

return TestHelpers
