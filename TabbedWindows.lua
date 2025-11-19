local TabbedWindows = {}
TabbedWindows.__index = TabbedWindows

function TabbedWindows.new(telemetry)
	local self = setmetatable({}, TabbedWindows)
	self._windowToTabGroup = {}
	self._tabGroups = {}
	self._nextGroupId = 1
	self._windowRegistry = {}
	self._telemetry = telemetry or require('Telemetry').NoOp.new()
	return self
end

function TabbedWindows:onWindowCreated(window)
	return self._telemetry:span("TabbedWindows:onWindowCreated", function()
		local windowId = window:id()
		local tabCount = window:tabCount()
		local frame = window:frame()
		local appName = window:application():name()

		self:_registerWindow(windowId, frame, appName)

		if tabCount and tabCount > 1 then
			local existingGroupId = self:_findGroupByFrameAndApp(frame, appName)

			if existingGroupId then
				self._telemetry:span("addWindowToExistingTabGroup", function()
					self:_addWindowToGroup(windowId, existingGroupId)
				end)
			else
				self._telemetry:span("createNewTabGroup", function()
					local groupId = self:_createTabGroup(window)
					local registeredWindows = self:_findRegisteredWindowsByFrameAndApp(frame, appName)
					for _, regWindowId in ipairs(registeredWindows) do
						self:_addWindowToGroup(regWindowId, groupId)
					end
				end)
			end
		end
	end)
end

function TabbedWindows:onWindowDestroyed(windowId)
	return self._telemetry:span("TabbedWindows:onWindowDestroyed", function()
		self:_unregisterWindow(windowId)

		local groupId = self._windowToTabGroup[windowId]
		if not groupId then
			return
		end

		self:_removeWindowFromGroup(windowId, groupId)

		if #self._tabGroups[groupId].windowIds == 0 then
			self._tabGroups[groupId] = nil
		end
	end)
end

function TabbedWindows:getTabGroupForWindow(windowId)
	local groupId = self._windowToTabGroup[windowId]
	if not groupId then
		return nil
	end

	return self._tabGroups[groupId].windowIds
end

function TabbedWindows:getTabSiblingsBeforeDestruction(windowId)
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

function TabbedWindows:_createTabGroup(window)
	local groupId = self._nextGroupId
	self._nextGroupId = self._nextGroupId + 1

	self._tabGroups[groupId] = {
		frame = window:frame(),
		appName = window:application():name(),
		windowIds = {}
	}

	return groupId
end

function TabbedWindows:_addWindowToGroup(windowId, groupId)
	table.insert(self._tabGroups[groupId].windowIds, windowId)
	self._windowToTabGroup[windowId] = groupId
end

function TabbedWindows:_findGroupByFrameAndApp(frame, appName)
	for groupId, group in pairs(self._tabGroups) do
		if self:_framesEqual(group.frame, frame) and group.appName == appName then
			return groupId
		end
	end
	return nil
end

function TabbedWindows:_framesEqual(frame1, frame2)
	return frame1.x == frame2.x
		and frame1.y == frame2.y
		and frame1.w == frame2.w
		and frame1.h == frame2.h
end

function TabbedWindows:_removeWindowFromGroup(windowId, groupId)
	local windowIds = self._tabGroups[groupId].windowIds
	for i, id in ipairs(windowIds) do
		if id == windowId then
			table.remove(windowIds, i)
			break
		end
	end

	self._windowToTabGroup[windowId] = nil
end

function TabbedWindows:_makeRegistryKey(frame, appName)
	return string.format("%s|%.1f,%.1f,%.1f,%.1f", appName, frame.x, frame.y, frame.w, frame.h)
end

function TabbedWindows:_registerWindow(windowId, frame, appName)
	local key = self:_makeRegistryKey(frame, appName)
	if not self._windowRegistry[key] then
		self._windowRegistry[key] = {}
	end
	table.insert(self._windowRegistry[key], windowId)
end

function TabbedWindows:_unregisterWindow(windowId)
	for key, windowIds in pairs(self._windowRegistry) do
		for i, id in ipairs(windowIds) do
			if id == windowId then
				table.remove(windowIds, i)
				if #windowIds == 0 then
					self._windowRegistry[key] = nil
				end
				return
			end
		end
	end
end

function TabbedWindows:_findRegisteredWindowsByFrameAndApp(frame, appName)
	local key = self:_makeRegistryKey(frame, appName)
	return self._windowRegistry[key] or {}
end

return TabbedWindows
