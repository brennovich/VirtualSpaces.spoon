local Instrumentation = {}
Instrumentation.__index = Instrumentation

function Instrumentation.new(componentName, logLevel)
	local self = setmetatable({}, Instrumentation)
	self._componentName = componentName
	self._logger = hs and hs.logger and hs.logger.new(componentName, logLevel or 'warning')
	return self
end

function Instrumentation:timed(operationName, fn)
	if not self._logger or self._logger.level < 4 then
		return fn()
	end

	local start = hs.timer.secondsSinceEpoch()
	local results = {fn()}
	local duration = (hs.timer.secondsSinceEpoch() - start) * 1000

	self._logger.df("%s took %.2fms", operationName, duration)

	return table.unpack(results)
end

return Instrumentation
