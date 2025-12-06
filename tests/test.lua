local lu = require('luaunit')

TestWindowsSort = require('tests/test_windows_sort')
TestSpacesModel = require('tests/test_spaces_model')
TestNativeSpaceManager = require('tests/test_native_space_manager')
TestMoveWindowToVirtualSpace = require('tests/test_move_window_to_virtual_space')
TestTelemetry = require('tests/test_telemetry')
TestWindowCache = require('tests/test_window_cache')
TestSpaceWatcher = require('tests/test_space_watcher')
TestGetWindowsApi = require('tests/test_get_windows_api')

os.exit(lu.LuaUnit.run())
