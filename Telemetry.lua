local Telemetry = {}
Telemetry.__index = Telemetry

local LOG_LEVEL_INFO = 3
local LOG_LEVEL_DEBUG = 4

local NoOpTelemetry = {}
NoOpTelemetry.__index = NoOpTelemetry

function NoOpTelemetry.new()
	return setmetatable({}, NoOpTelemetry)
end

function NoOpTelemetry:span(operationName, fn)
	return fn()
end

function NoOpTelemetry:setLogLevel(logLevel)
end

function Telemetry.new(componentName, logLevel)
	local self = setmetatable({}, Telemetry)
	self._componentName = componentName
	self._logger = hs and hs.logger and hs.logger.new(componentName, logLevel or 'debug')
	return self
end

function Telemetry:setLogLevel(logLevel)
	self._logger = hs and hs.logger and hs.logger.new(self._componentName, logLevel)
end

function Telemetry:span(operationName, fn)
	if not self._logger then
		return fn()
	end

	local shouldLogOperation = self._logger.level >= LOG_LEVEL_INFO
	local shouldLogPerformance = self._logger.level >= LOG_LEVEL_DEBUG

	if shouldLogOperation then
		self._logger.i(operationName)
	end

	if not shouldLogPerformance then
		return fn()
	end

	local start = hs.timer.secondsSinceEpoch()
	local results = {fn()}
	local duration = (hs.timer.secondsSinceEpoch() - start) * 1000

	self._logger.df("%s took %.2fms", operationName, duration)

	return table.unpack(results)
end

Telemetry.NoOp = NoOpTelemetry

return Telemetry
