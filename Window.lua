local Window = {}

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

function Window.makeKey(frame, appName)
	return string.format("%s|%.1f,%.1f,%.1f,%.1f", appName, frame.x, frame.y, frame.w, frame.h)
end

function Window.framesEqual(frame1, frame2)
	return frame1.x == frame2.x
		and frame1.y == frame2.y
		and frame1.w == frame2.w
		and frame1.h == frame2.h
end

return Window
