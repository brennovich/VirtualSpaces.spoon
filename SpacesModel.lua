-- SpacesModel is responsible for managing virtual spaces and their associated
-- windows. It keeps track of which windows belong to which virtual spaces
-- exposing convenient API over the datastructures needed.
local Window = require("Window")

local SpacesModel = {}
SpacesModel.__index = SpacesModel

local function removeValue(list, value)
	for i, v in ipairs(list) do
		if v == value then
			table.remove(list, i)
			return
		end
	end
end

function SpacesModel.new()
	local self = setmetatable({}, SpacesModel)
	self._focusedWindows = {}
	self._windowVirtualSpaceMap = {}
	self._virtualSpaceWindowsMap = {}
	self._currentVirtualSpace = 1

	self._groups = {}
	self._windowToGroup = {}
	self._nextGroupId = 1

	return self
end

-- Save the focused window for a given virtual space
-- Maintains a focus history stack where the most recently focused window is at index 1
function SpacesModel:saveFocusedWindowInVirtualSpace(virtualSpace, windowId)
	if not windowId then return end

	if not self._focusedWindows[virtualSpace] then
		self._focusedWindows[virtualSpace] = {}
	end

	local focusHistory = self._focusedWindows[virtualSpace]
	removeValue(focusHistory, windowId)
	table.insert(focusHistory, 1, windowId)
end

-- Get the focused window for a given virtual space
-- Returns the most recently focused window (first in the focus history stack)
function SpacesModel:getFocusedWindowForVirtualSpace(virtualSpace)
	local focusHistory = self._focusedWindows[virtualSpace]
	return focusHistory and focusHistory[1] or nil
end

-- Get the virtual space assigned to a window
function SpacesModel:getVirtualSpaceForWindow(windowId)
	return self._windowVirtualSpaceMap[windowId]
end

-- Get all windows assigned to a virtual space
function SpacesModel:getWindowsInVirtualSpace(virtualSpace)
	return self._virtualSpaceWindowsMap[virtualSpace] or {}
end

function SpacesModel:assignWindowToSpace(window, virtualSpace)
	if not window then return end

	local isNewWindow = not self._windowToGroup[window.id]
	if isNewWindow then
		local existingGroupId = nil

		if window.tabCount and window.tabCount > 1 then
			for groupId, group in pairs(self._groups) do
				if Window.framesEqual(group.frame, window.frame) and group.appName == window.appName then
					existingGroupId = groupId
					break
				end
			end
		end

		if existingGroupId then
			table.insert(self._groups[existingGroupId].windowIds, window.id)
			self._windowToGroup[window.id] = existingGroupId
		else
			local groupId = self._nextGroupId
			self._nextGroupId = self._nextGroupId + 1
			self._groups[groupId] = {frame = window.frame, appName = window.appName, windowIds = {window.id}}
			self._windowToGroup[window.id] = groupId
		end
	end

	self:_assignGroupToVirtualSpace(self._windowToGroup[window.id], virtualSpace)

	self:saveFocusedWindowInVirtualSpace(virtualSpace, window.id)
end

function SpacesModel:moveWindowToVirtualSpace(windowId, virtualSpace)
	if not windowId or not virtualSpace then
		return
	end

	local groupId = self._windowToGroup[windowId]
	if groupId then
		self:_assignGroupToVirtualSpace(groupId, virtualSpace)
	else
		self:assignWindowToVirtualSpace(windowId, virtualSpace)
	end

	self:saveFocusedWindowInVirtualSpace(virtualSpace, windowId)
end

function SpacesModel:unregisterWindowById(windowId)
	local groupId = self._windowToGroup[windowId]
	if groupId then
		removeValue(self._groups[groupId].windowIds, windowId)

		local tabSiblings = self:getTabSiblingsBeforeDestruction(windowId)
		if tabSiblings and #tabSiblings > 0 then
			self:saveFocusedWindowInVirtualSpace(self:getCurrentVirtualSpace(), tabSiblings[1])
		end

		self._windowToGroup[windowId] = nil

		if #self._groups[groupId].windowIds == 0 then
			self._groups[groupId] = nil
		end
	end

	local virtualSpace = self._windowVirtualSpaceMap[windowId]

	if virtualSpace then
		self:_removeWindowFromList(virtualSpace, windowId)
	end

	self:_removeWindowFromFocusHistory(windowId)
	self._windowVirtualSpaceMap[windowId] = nil
end

-- Assign a window to a virtual space
function SpacesModel:assignWindowToVirtualSpace(windowId, virtualSpace)
	if not windowId or not virtualSpace then
		return
	end

	local previousVirtualSpace = self._windowVirtualSpaceMap[windowId]

	if previousVirtualSpace == virtualSpace then
		return
	end

	if previousVirtualSpace then
		self:_removeWindowFromList(previousVirtualSpace, windowId)

		local focusHistory = self._focusedWindows[previousVirtualSpace]
		if focusHistory then
			removeValue(focusHistory, windowId)
		end
	end

	if not self._virtualSpaceWindowsMap[virtualSpace] then
		self._virtualSpaceWindowsMap[virtualSpace] = {}
	end
	table.insert(self._virtualSpaceWindowsMap[virtualSpace], windowId)

	self._windowVirtualSpaceMap[windowId] = virtualSpace
end

-- Categorize windows based on their virtual space assignments for transition
-- between two native spaces.
function SpacesModel:categorizeWindowsForTransition(targetVirtualSpace)
	local toActive, toStorage = {}, {}
	for windowId, virtualSpace in pairs(self._windowVirtualSpaceMap) do
		if virtualSpace == targetVirtualSpace then
			table.insert(toActive, windowId)
		else
			table.insert(toStorage, windowId)
		end
	end

	return {toActive = toActive, toStorage = toStorage}
end

-- Get the current virtual space
function SpacesModel:getCurrentVirtualSpace()
	return self._currentVirtualSpace
end

-- Set the current virtual space
function SpacesModel:setCurrentVirtualSpace(virtualSpace)
	self._currentVirtualSpace = virtualSpace
end

function SpacesModel:getTabGroupForWindow(windowId)
	local groupId = self._windowToGroup[windowId]
	if not groupId then
		return nil
	end

	return self._groups[groupId].windowIds
end

function SpacesModel:getTabSiblingsBeforeDestruction(windowId)
	local groupId = self._windowToGroup[windowId]
	if not groupId then
		return nil
	end

	local siblings = {}
	for _, tabWindowId in ipairs(self._groups[groupId].windowIds) do
		if tabWindowId ~= windowId then
			table.insert(siblings, tabWindowId)
		end
	end

	return #siblings > 0 and siblings or nil
end

function SpacesModel:prepareWindowToBeFocusedOnCurrentVirtualSpace()
	local currentVirtualSpace = self._currentVirtualSpace
	local focusHistory = self._focusedWindows[currentVirtualSpace]

	if focusHistory then
		for _, windowId in ipairs(focusHistory) do
			if self._windowVirtualSpaceMap[windowId] == currentVirtualSpace then
				return windowId
			end
		end
	end

	local windows = self._virtualSpaceWindowsMap[currentVirtualSpace] or {}
	if #windows > 0 then
		self:saveFocusedWindowInVirtualSpace(currentVirtualSpace, windows[1])
		return windows[1]
	end

	return nil
end

function SpacesModel:_assignGroupToVirtualSpace(groupId, virtualSpace)
	for _, tabWindowId in ipairs(self._groups[groupId].windowIds) do
		self:assignWindowToVirtualSpace(tabWindowId, virtualSpace)
	end
end

function SpacesModel:_removeWindowFromList(virtualSpace, windowId)
	local windows = self._virtualSpaceWindowsMap[virtualSpace]
	if not windows then return end

	removeValue(windows, windowId)
end

-- Remove a window from all virtual space focus histories
function SpacesModel:_removeWindowFromFocusHistory(windowId)
	for _, focusHistory in pairs(self._focusedWindows) do
		removeValue(focusHistory, windowId)
	end
end


return SpacesModel
