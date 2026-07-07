local Telemetry = require("Telemetry")

local Pager = {}
Pager.__index = Pager

-- Tab shape: the tab is a custom-drawn overlay in the bottom-right corner of the
-- screen, hiding the native macOS Space nub and showing the current virtual space.
--
-- minimum tab height
local TAB_HEIGHT = 58
-- x-position (as a fraction of frame.w) where the left swoop meets the flat shoulder
local SWOOP_END_FRACTION = 0.50
-- how far the swoop's bezier handles extend from each end; higher = fuller/rounder curve
local SWOOP_HANDLE_FRACTION = 0.75
-- y-position (as a fraction of frame.h) of the flat shoulder, measured from the top
local SHOULDER_HEIGHT_FRACTION = 0.25
-- x-position (as a fraction of frame.w) where the flat shoulder ends and the top-right corner curve begins
local SHOULDER_END_FRACTION = 0.45
-- how far the top-right corner's bezier handles extend; higher = fuller/rounder curve
local CORNER_HANDLE_FRACTION = 0.8

-- Virtual space badge: the white square showing the current space number.
--
-- minimum gap between the badge and the tab's right/bottom edges
local PADDING = 6
-- width/height of the badge square
local BADGE_SIZE = TAB_HEIGHT / 2 - PADDING * 1.5
-- corner radius of the badge square
local BADGE_RADIUS = 4
-- font size of the space number inside the badge
local TEXT_SIZE = 12

-- Colors
local BLACK = {red = 0, green = 0, blue = 0, alpha = 1}
local WHITE = {white = 1, alpha = 1}

function Pager.new(deps)
	deps = deps or {}
	local self = setmetatable({}, Pager)
	self._hsCanvas = deps.hsCanvas or hs.canvas
	self._hsScreen = deps.hsScreen or hs.screen
	self._telemetry = deps.telemetry or Telemetry.NoOp.new()
	self._canvas = nil
	return self
end

function Pager:update(virtualSpace)
	return self._telemetry:span("pagerUpdate", function()
		local frame = self:_tabFrame(self._hsScreen.mainScreen():frame())

		if not self._canvas then
			self._canvas = self._hsCanvas.new(frame)
			self._canvas:level(self._hsCanvas.windowLevels.overlay)
		else
			self._canvas:frame(frame)
		end

		self._canvas:replaceElements(self:_elements(frame, virtualSpace))
		self._canvas:show()
	end)
end

function Pager:delete()
	if not self._canvas then return end
	self._canvas:delete()
	self._canvas = nil
end

function Pager:_tabFrame(screenFrame)
	local width = BADGE_SIZE + 4 * PADDING
	local height = TAB_HEIGHT
	return {
		x = screenFrame.x + screenFrame.w - width,
		y = screenFrame.y + screenFrame.h - height,
		w = width,
		h = height,
	}
end

function Pager:_elements(frame, virtualSpace)
	local swoopEndX = frame.w * SWOOP_END_FRACTION
	local shoulderEndX = frame.w * SHOULDER_END_FRACTION
	local shoulderY = frame.h * SHOULDER_HEIGHT_FRACTION
	local swoopHandleX = swoopEndX * SWOOP_HANDLE_FRACTION
	local cornerHandleX = (frame.w - shoulderEndX) * CORNER_HANDLE_FRACTION
	local cornerHandleY = shoulderY * CORNER_HANDLE_FRACTION

	local badgeX = (swoopEndX - 1) + (frame.w - swoopEndX - BADGE_SIZE) / 2
	local badgeY = (shoulderY + 1) + (frame.h - shoulderY - BADGE_SIZE) / 2

	return {
		{
			type = "segments",
			action = "fill",
			fillColor = BLACK,
			closed = true,
			coordinates = {
				{x = 0, y = frame.h},
				{
					x = swoopEndX, y = shoulderY,
					c1x = swoopHandleX,
					c1y = frame.h,
					c2x = swoopEndX - swoopHandleX,
					c2y = shoulderY,
				},
				{x = shoulderEndX, y = shoulderY},
				{
					x = frame.w, y = 0,
					c1x = shoulderEndX + cornerHandleX,
					c1y = shoulderY,
					c2x = frame.w,
					c2y = cornerHandleY,
				},
				{x = frame.w, y = frame.h},
			},
		},
		{
			type = "rectangle",
			action = "fill",
			fillColor = WHITE,
			roundedRectRadii = {xRadius = BADGE_RADIUS, yRadius = BADGE_RADIUS},
			frame = {x = badgeX, y = badgeY, w = BADGE_SIZE, h = BADGE_SIZE + 1},
		},
		{
			type = "text",
			text = tostring(virtualSpace),
			textColor = BLACK,
			textFont = ".AppleSystemUIFontBold",
			textAlignment = "center",
			textSize = TEXT_SIZE,
			frame = {x = badgeX, y = badgeY + (BADGE_SIZE - TEXT_SIZE) / 2 - 1, w = BADGE_SIZE, h = BADGE_SIZE},
		},
	}
end

return Pager
