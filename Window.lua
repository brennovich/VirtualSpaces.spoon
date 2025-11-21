local Window = {}

-- This is specifically to handle NSDocument's tab system, some application
-- have tabs of the same window have the exact same frame but some others
-- like Terminal.app have not exactly the same y position for each tab's window.
Window.Y_TOLERANCE = 10

function Window.new(hsWindow)
	if not hsWindow then
		return nil
	end

	return {
		id = hsWindow:id(),
		tabCount = hsWindow:tabCount() or 1,
		frame = hsWindow:frame(),
		appName = hsWindow:application():name()
	}
end

function Window.framesEqual(frame1, frame2)
	return frame1.x == frame2.x
		and math.abs(frame1.y - frame2.y) <= Window.Y_TOLERANCE
		and frame1.w == frame2.w
		and frame1.h == frame2.h
end

return Window
