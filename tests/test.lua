local lu = require('luaunit')

TestWindowsSort = require('tests/test_windows_sort')
TestSpacesModel = require('tests/test_spaces_model')
TestNativeSpaceManager = require('tests/test_native_space_manager')
TestVirtualSpacesWindowDestroyed = require('tests/test_virtual_spaces')
TestMoveWindowToVirtualSpace = require('tests/test_move_window_to_virtual_space')

os.exit(lu.LuaUnit.run())
