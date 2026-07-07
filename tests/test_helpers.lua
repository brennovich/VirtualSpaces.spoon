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

function TestHelpers.createHsWindow(id, appName, opts)
	opts = opts or {}
	local currentFrame = opts.frame or {x = 0, y = 0, w = 800, h = 600}

	return {
		id = function() return id end,
		isStandard = function() return true end,
		isFullScreen = function() return false end,
		isMinimized = function() return false end,
		focus = opts.onFocus or function() end,
		tabCount = function() return opts.tabCount or 1 end,
		frame = function() return currentFrame end,
		setFrame = function(_, newFrame) currentFrame = newFrame end,
		application = function() return {name = function() return appName end} end
	}
end

function TestHelpers.createFilterCapture()
	local callbacks = {}
	local filterNew = function()
		return {
			subscribe = function(_, eventType, cb)
				callbacks[eventType] = callbacks[eventType] or {}
				table.insert(callbacks[eventType], cb)
			end
		}
	end
	return filterNew, callbacks
end

function TestHelpers.emit(callbacks, eventType, window)
	for _, cb in ipairs(callbacks[eventType] or {}) do
		cb(window)
	end
end

function TestHelpers.registerWindow(obj, window)
	local Window = require('Window')
	obj.model:assignWindowToSpace(Window.new(window), obj.model:getCurrentVirtualSpace())
end

function TestHelpers.findCanvasText(elements)
	for _, element in ipairs(elements) do
		if element.type == "text" then return element.text end
	end
	return nil
end

function TestHelpers.createCanvasMock()
	local created = {}

	local canvas = {
		windowLevels = {overlay = 21},
		new = function(frame)
			local frameValue = frame
			local c = {
				elements = {},
				shownCount = 0,
				hiddenCount = 0,
				deleted = false,
				levelValue = nil,
			}
			function c:frame(newFrame)
				if newFrame then frameValue = newFrame; return self end
				return frameValue
			end
			function c:replaceElements(elements) self.elements = elements; return self end
			function c:show() self.shownCount = self.shownCount + 1; return self end
			function c:hide() self.hiddenCount = self.hiddenCount + 1; return self end
			function c:delete() self.deleted = true; return self end
			function c:level(value) self.levelValue = value; return self end
			table.insert(created, c)
			return c
		end,
	}

	return canvas, created
end

function TestHelpers.createHsGlobal(overrides)
	overrides = overrides or {}

	local spaces = overrides.spaces or {activeSpace = 1}
	local mockWindows = overrides.mockWindows or {}

	return {
		spoons = {
			scriptPath = overrides.scriptPath or function() return "./" end
		},
		spaces = {
			windowSpaces = overrides.windowSpaces or function(winId)
				return {spaces.activeSpace}
			end,
			activeSpaceOnScreen = overrides.activeSpaceOnScreen or function()
				return spaces.activeSpace
			end,
			gotoSpace = overrides.gotoSpace or function() end,
			allSpaces = overrides.allSpaces or function()
				return {["screen-123"] = {spaces.activeSpace}}
			end,
			openMissionControl = overrides.openMissionControl or function() end,
			removeSpace = overrides.removeSpace or function() end
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
						subscribe = function() end
					}
				end,
				windowCreated = 1,
				windowDestroyed = 2,
				windowFocused = 3
			}
		},
		canvas = overrides.canvas or TestHelpers.createCanvasMock(),
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
