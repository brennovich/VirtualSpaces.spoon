local lu = require('luaunit')
local helpers = require('tests/test_helpers')

local Telemetry = require('Telemetry')

TestTelemetry = {}

function TestTelemetry:testNewCreatesInstance()
	local tel = Telemetry.new('TestComponent', 'debug')

	lu.assertNotNil(tel)
end

function TestTelemetry:testSpanReturnsResult()
	local tel = Telemetry.new('TestComponent', 'debug')

	local result = tel:span('operation', function()
		return 42
	end)

	lu.assertEquals(result, 42)
end

function TestTelemetry:testTimedWithMultipleReturnValues()
	local tel = Telemetry.new('TestComponent', 'debug')

	local a, b, c = tel:span('operation', function()
		return 1, 2, 3
	end)

	lu.assertEquals(a, 1)
	lu.assertEquals(b, 2)
	lu.assertEquals(c, 3)
end

function TestTelemetry:testNilTelemetryReturnsResult()
	local tel = Telemetry.new('TestComponent', 'warning')

	local result = tel:span('operation', function()
		return 'result'
	end)

	lu.assertEquals(result, 'result')
end

function TestTelemetry:testTimedWithNoReturnValue()
	local tel = Telemetry.new('TestComponent', 'debug')
	local sideEffect = 0

	tel:span('operation', function()
		sideEffect = 123
	end)

	lu.assertEquals(sideEffect, 123)
end

function TestTelemetry:testInfoLevelLogsOperationOnly()
	local logged = {}
	local mockLogger = {
		i = function(msg) table.insert(logged, {level = 'info', msg = msg}) end,
		d = function(msg) table.insert(logged, {level = 'debug', msg = msg}) end,
		level = 3
	}

	local tel = Telemetry.new('TestComponent', 'info')
	tel._logger = mockLogger

	tel:span('saveWindowFocus', function()
		return 'done'
	end)

	lu.assertEquals(#logged, 1)
	lu.assertEquals(logged[1].level, 'info')
	lu.assertStrContains(logged[1].msg, 'saveWindowFocus')
	lu.assertNotStrContains(logged[1].msg, 'ms')
end

function TestTelemetry:testDebugLevelLogsBothOperationAndTiming()
	local logged = {}
	local mockLogger = {
		i = function(msg) table.insert(logged, {level = 'info', msg = msg}) end,
		df = function(fmt, ...)
			table.insert(logged, {level = 'debug', msg = string.format(fmt, ...)})
		end,
		level = 4
	}

	helpers.withHsGlobal({
		timer = {
			secondsSinceEpoch = function()
				return 0
			end
		}
	}, function()
		local tel = Telemetry.new('TestComponent', 'debug')
		tel._logger = mockLogger

		tel:span('saveWindowFocus', function()
			return 'done'
		end)

		lu.assertEquals(#logged, 2)
		lu.assertEquals(logged[1].level, 'info')
		lu.assertStrContains(logged[1].msg, 'saveWindowFocus')
		lu.assertEquals(logged[2].level, 'debug')
		lu.assertStrContains(logged[2].msg, 'ms')
	end)
end

return TestTelemetry
