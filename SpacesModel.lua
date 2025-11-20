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

function SpacesModel:assignWindowToSpace(hsWindow, virtualSpace)
	local windowData = Window.new(hsWindow)
	if not windowData then
		return
	end

	if not self:isWindowRegistered(windowData.id) then
		self:registerWindowObject(hsWindow)
	end

	self:assignWindowAndTabGroupToVirtualSpace(windowData.id, virtualSpace)
end

function SpacesModel:registerWindowObject(hsWindow)
	local windowData = Window.new(hsWindow)
	if not windowData then
		return
	end

	self:_registerWindow(windowData)

	if windowData.tabCount and windowData.tabCount > 1 then
		local existingGroupId = self:_findGroupByFrameAndApp(windowData.frame, windowData.appName)

		if existingGroupId then
			self:_addWindowToTabGroup(windowData.id, existingGroupId)
		else
			local groupId = self:_createTabGroup(windowData)
			local registeredWindows = self:_findRegisteredWindowsByFrameAndApp(windowData.frame, windowData.appName)
			for _, regWindowId in ipairs(registeredWindows) do
				self:_addWindowToTabGroup(regWindowId, groupId)
			end
		end
	end
end

function SpacesModel:unregisterWindowObject(windowId)
	self:_unregisterWindow(windowId)

	local groupId = self._windowToTabGroup[windowId]
	if groupId then
		self:_removeWindowFromTabGroup(windowId, groupId)

		if #self._tabGroups[groupId].windowIds == 0 then
			self._tabGroups[groupId] = nil
		end
	end
end

-- Assign a window and its tab group to a virtual space
function SpacesModel:assignWindowAndTabGroupToVirtualSpace(windowId, virtualSpace)
	if not windowId or not virtualSpace then
		return
	end

	local tabGroup = self:getTabGroupForWindow(windowId)

	if tabGroup then
		for _, tabWindowId in ipairs(tabGroup) do
			self:assignWindowToVirtualSpace(tabWindowId, virtualSpace)
		end
	else
		self:assignWindowToVirtualSpace(windowId, virtualSpace)
	end

	self:saveFocusedWindowInVirtualSpace(virtualSpace, windowId)
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

function SpacesModel:_registerWindow(windowData)
	self._windows[windowData.id] = windowData
end

function SpacesModel:_unregisterWindow(windowId)
	self._windows[windowId] = nil
end

function SpacesModel:isWindowRegistered(windowId)
	return self._windows[windowId] ~= nil
end

function SpacesModel:_findRegisteredWindowsByFrameAndApp(frame, appName)
	local matches = {}
	for windowId, windowData in pairs(self._windows) do
		if windowData.appName == appName and Window.framesEqual(windowData.frame, frame) then
			table.insert(matches, windowId)
		end
	end
	return matches
end

function SpacesModel:_createTabGroup(windowData)
	local groupId = self._nextGroupId
	self._nextGroupId = self._nextGroupId + 1

	self._tabGroups[groupId] = {
		frame = windowData.frame,
		appName = windowData.appName,
		windowIds = {}
	}

	return groupId
end

function SpacesModel:_addWindowToTabGroup(windowId, groupId)
	table.insert(self._tabGroups[groupId].windowIds, windowId)
	self._windowToTabGroup[windowId] = groupId
end

function SpacesModel:_removeWindowFromTabGroup(windowId, groupId)
	local windowIds = self._tabGroups[groupId].windowIds
	for i, id in ipairs(windowIds) do
		if id == windowId then
			table.remove(windowIds, i)
			break
		end
	end

	self._windowToTabGroup[windowId] = nil
end

function SpacesModel:_findGroupByFrameAndApp(frame, appName)
	for groupId, group in pairs(self._tabGroups) do
		if Window.framesEqual(group.frame, frame) and group.appName == appName then
			return groupId
		end
	end
	return nil
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

return SpacesModel
