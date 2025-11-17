local lu = require('luaunit')

local Instrumentation = require('Instrumentation')

TestInstrumentation = {}

function TestInstrumentation:testNewCreatesInstance()
	local inst = Instrumentation.new('TestComponent', 'debug')

	lu.assertNotNil(inst)
end

function TestInstrumentation:testTimedReturnsResult()
	local inst = Instrumentation.new('TestComponent', 'debug')

	local result = inst:timed('operation', function()
		return 42
	end)

	lu.assertEquals(result, 42)
end

function TestInstrumentation:testTimedWithMultipleReturnValues()
	local inst = Instrumentation.new('TestComponent', 'debug')

	local a, b, c = inst:timed('operation', function()
		return 1, 2, 3
	end)

	lu.assertEquals(a, 1)
	lu.assertEquals(b, 2)
	lu.assertEquals(c, 3)
end

function TestInstrumentation:testNilInstrumentationReturnsResult()
	local inst = Instrumentation.new('TestComponent', 'warning')

	local result = inst:timed('operation', function()
		return 'result'
	end)

	lu.assertEquals(result, 'result')
end

function TestInstrumentation:testTimedWithNoReturnValue()
	local inst = Instrumentation.new('TestComponent', 'debug')
	local sideEffect = 0

	inst:timed('operation', function()
		sideEffect = 123
	end)

	lu.assertEquals(sideEffect, 123)
end

return TestInstrumentation
