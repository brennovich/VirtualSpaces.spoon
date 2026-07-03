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

function TestHelpers.createHsWindow(id, appName)
	local currentFrame = {x = 0, y = 0, w = 800, h = 600}

	return {
		id = function() return id end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		focus = function() end,
		tabCount = function() return 1 end,
		frame = function() return currentFrame end,
		setFrame = function(_, newFrame) currentFrame = newFrame end,
		application = function() return {name = function() return appName end} end
	}
end

function TestHelpers.createSimpleWindow(id)
	return TestHelpers.createWindow(id, 1, {x = 0, y = 0, w = 800, h = 600}, "TestApp")
end

function TestHelpers.createHsGlobal(overrides)
	overrides = overrides or {}

	local spaces = overrides.spaces or {activeSpace = 1, storageSpace = 2}
	local movedWindows = overrides.movedWindows or {}
	local mockWindows = overrides.mockWindows or {}

	return {
		spoons = {
			scriptPath = overrides.scriptPath or function() return "./" end
		},
		host = {
			operatingSystemVersion = overrides.operatingSystemVersion or function()
				return {major = 14, minor = 0, patch = 0}
			end
		},
		spaces = {
			moveWindowToSpace = overrides.moveWindowToSpace or function(window, space)
				table.insert(movedWindows, {window = window, space = space})
			end,
			windowSpaces = overrides.windowSpaces or function(winId)
				return {spaces.activeSpace}
			end,
			activeSpaceOnScreen = overrides.activeSpaceOnScreen or function()
				return spaces.activeSpace
			end,
			allSpaces = overrides.allSpaces or function()
				return {["screen-123"] = {spaces.activeSpace, spaces.storageSpace}}
			end,
			openMissionControl = overrides.openMissionControl or function() end,
			removeSpace = overrides.removeSpace or function() end,
			addSpaceToScreen = overrides.addSpaceToScreen or function() end,
			watcher = overrides.watcher or {
				new = function()
					return {start = function() end}
				end
			}
		},
		screen = {
			mainScreen = overrides.mainScreen or function()
				return {
					getUUID = function() return "screen-123" end,
					fullFrame = function() return {x = 0, y = 0, w = 1792, h = 1120} end,
					frame = function() return {x = 0, y = 25, w = 1792, h = 1095} end,
				}
			end
		},
		window = {
			focusedWindow = overrides.focusedWindow or function() return nil end,
			get = overrides.windowGet or function(id)
				return mockWindows[id]
			end,
			allWindows = overrides.allWindows or function() return {} end,
			filter = {
				new = overrides.filterNew or function()
					return {
						subscribe = function() end,
						setCurrentSpace = function() end
					}
				end,
				windowCreated = 1,
				windowDestroyed = 2,
				windowFocused = 3
			}
		},
		logger = {
			new = overrides.loggerNew or function()
				return {
					w = function() end,
					e = function() end,
					level = 0
				}
			end
		}
	}
end

return TestHelpers
