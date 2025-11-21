-- SpacesModel is responsible for managing virtual spaces and their associated
-- windows. It keeps track of which windows belong to which virtual spaces
-- exposing convenient API over the datastructures needed.
local Window = require("Window")

local SpacesModel = {}
SpacesModel.__index = SpacesModel

function SpacesModel.new()
	local self = setmetatable({}, SpacesModel)
	self._focusedWindows = {}
	self._windowVirtualSpaceMap = {}
	self._virtualSpaceWindowsMap = {}
	self._currentVirtualSpace = 1

	self._windows = {}
	self._tabGroups = {}
	self._windowToTabGroup = {}
	self._nextGroupId = 1

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

-- Get the virtual space assigned to a window
function SpacesModel:getVirtualSpaceForWindow(windowId)
	return self._windowVirtualSpaceMap[windowId]
end

-- Get all windows assigned to a virtual space
function SpacesModel:getWindowsInVirtualSpace(virtualSpace)
	return self._virtualSpaceWindowsMap[virtualSpace] or {}
end

function SpacesModel:assignWindowToSpace(window, virtualSpace)
	if not window then
		return
	end

	if self._windows[window.id] == nil then
		self._windows[window.id] = window

		if window.tabCount and window.tabCount > 1 then
			local existingGroupId = nil
			for groupId, group in pairs(self._tabGroups) do
				if Window.framesEqual(group.frame, window.frame) and group.appName == window.appName then
					existingGroupId = groupId
					break
				end
			end

			if existingGroupId then
				table.insert(self._tabGroups[existingGroupId].windowIds, window.id)
				self._windowToTabGroup[window.id] = existingGroupId
			else
				local groupId = self._nextGroupId
				self._nextGroupId = self._nextGroupId + 1
				self._tabGroups[groupId] = {frame = window.frame, appName = window.appName, windowIds = {}}

				for windowId, windowData in pairs(self._windows) do
					if windowData.appName == window.appName and Window.framesEqual(windowData.frame, window.frame) then
						table.insert(self._tabGroups[groupId].windowIds, windowId)
						self._windowToTabGroup[windowId] = groupId
					end
				end
			end
		end
	end

	local groupId = self._windowToTabGroup[window.id]
	if groupId and self._tabGroups[groupId] then
		for _, tabWindowId in ipairs(self._tabGroups[groupId].windowIds) do
			self:assignWindowToVirtualSpace(tabWindowId, virtualSpace)
		end
	else
		self:assignWindowToVirtualSpace(window.id, virtualSpace)
	end

	self:saveFocusedWindowInVirtualSpace(virtualSpace, window.id)
end

function SpacesModel:unregisterWindowById(windowId)
	self._windows[windowId] = nil

	local groupId = self._windowToTabGroup[windowId]
	if groupId then
		local windowIds = self._tabGroups[groupId].windowIds
		for i, id in ipairs(windowIds) do
			if id == windowId then
				table.remove(windowIds, i)
				break
			end
		end

		self._windowToTabGroup[windowId] = nil

		if #self._tabGroups[groupId].windowIds == 0 then
			self._tabGroups[groupId] = nil
		end
	end

	local virtualSpace = self._windowVirtualSpaceMap[windowId]

	if virtualSpace then
		self:_removeWindowFromList(virtualSpace, windowId)

		if self._focusedWindows[virtualSpace] == windowId then
			self._focusedWindows[virtualSpace] = nil
		end
	end

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
	end

	if not self._virtualSpaceWindowsMap[virtualSpace] then
		self._virtualSpaceWindowsMap[virtualSpace] = {}
	end
	table.insert(self._virtualSpaceWindowsMap[virtualSpace], windowId)

	self._windowVirtualSpaceMap[windowId] = virtualSpace
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

function SpacesModel:getTabGroupForWindow(windowId)
	local groupId = self._windowToTabGroup[windowId]
	if not groupId then
		return nil
	end

	return self._tabGroups[groupId].windowIds
end

function SpacesModel:getTabSiblingsBeforeDestruction(windowId)
	local groupId = self._windowToTabGroup[windowId]
	if not groupId then
		return nil
	end

	local siblings = {}
	for _, tabWindowId in ipairs(self._tabGroups[groupId].windowIds) do
		if tabWindowId ~= windowId then
			table.insert(siblings, tabWindowId)
		end
	end

	return #siblings > 0 and siblings or nil
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
