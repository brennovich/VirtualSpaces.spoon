local lu = require('luaunit')

TestSpacesModel = require('tests/test_spaces_model')
TestVirtualSpace = require('tests/test_virtual_space')
TestMoveWindowToVirtualSpace = require('tests/test_move_window_to_virtual_space')
TestTelemetry = require('tests/test_telemetry')
TestWindowCache = require('tests/test_window_cache')
TestGetWindowsApi = require('tests/test_get_windows_api')
TestPublicApi = require('tests/test_public_api')
TestWindowDestroyed = require('tests/test_window_destroyed')

os.exit(lu.LuaUnit.run())
