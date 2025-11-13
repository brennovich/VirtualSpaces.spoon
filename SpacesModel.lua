-- SpacesModel is responsible for managing virtual spaces and their associated
-- windows. It keeps track of which windows belong to which virtual spaces
-- exposing convenient API over the datastructures needed.
local SpacesModel = {}
SpacesModel.__index = SpacesModel

function SpacesModel.new()
	local self = setmetatable({}, SpacesModel)
	self._focusedWindows = {}
	self._windowVirtualSpaceMap = {}
	self._virtualSpaceWindowsMap = {}
	self._currentVirtualSpace = 1
	return self
end

-- Save the focused window for a given virtual space
function SpacesModel:saveFocusedWindowInVirtualSpace(virtualSpace, windowId)
	self._focusedWindows[virtualSpace] = windowId
end

-- Get the focused window for a given virtual space
function SpacesModel:getFocusedWindowForVirtualSpace(virtualSpace)
	return self._focusedWindows[virtualSpace]
end

-- Assign a window to a virtual space
function SpacesModel:assignWindowToVirtualSpace(windowId, virtualSpace)
	local oldSpace = self._windowVirtualSpaceMap[windowId]

	if oldSpace then
		self:_removeWindowFromList(oldSpace, windowId)
	end

	if not self._virtualSpaceWindowsMap[virtualSpace] then
		self._virtualSpaceWindowsMap[virtualSpace] = {}
	end
	table.insert(self._virtualSpaceWindowsMap[virtualSpace], windowId)

	self._windowVirtualSpaceMap[windowId] = virtualSpace
end

-- Remove a window from its assigned virtual space
function SpacesModel:removeWindow(windowId)
	local virtualSpace = self._windowVirtualSpaceMap[windowId]

	if virtualSpace then
		self:_removeWindowFromList(virtualSpace, windowId)

		if self._focusedWindows[virtualSpace] == windowId then
			self._focusedWindows[virtualSpace] = nil
		end
	end

	self._windowVirtualSpaceMap[windowId] = nil
end

-- Get the virtual space assigned to a window
function SpacesModel:getVirtualSpaceForWindow(windowId)
	return self._windowVirtualSpaceMap[windowId]
end

-- Get all windows assigned to a virtual space
function SpacesModel:getWindowsInVirtualSpace(virtualSpace)
	return self._virtualSpaceWindowsMap[virtualSpace] or {}
end

-- Categorize windows based on their virtual space assignments for transition
-- between two native spaces.
function SpacesModel:categorizeWindowsForTransition(targetVirtualSpace, currentVirtualSpace)
	local toActive = {}
	local toStorage = {}
	local others = {}

	for windowId, virtualSpace in pairs(self._windowVirtualSpaceMap) do
		if virtualSpace == targetVirtualSpace then
			table.insert(toActive, windowId)
		elseif virtualSpace == currentVirtualSpace then
			table.insert(toStorage, windowId)
		else
			table.insert(others, windowId)
		end
	end

	return {
		toActive = toActive,
		toStorage = toStorage,
		others = others
	}
end

-- Get the current virtual space
function SpacesModel:getCurrentVirtualSpace()
	return self._currentVirtualSpace
end

-- Set the current virtual space
function SpacesModel:setCurrentVirtualSpace(virtualSpace)
	self._currentVirtualSpace = virtualSpace
end

function SpacesModel:_removeWindowFromList(virtualSpace, windowId)
	local windows = self._virtualSpaceWindowsMap[virtualSpace]
	if not windows then return end

	for i, wId in ipairs(windows) do
		if wId == windowId then
			table.remove(windows, i)
			return
		end
	end
end

return SpacesModel
