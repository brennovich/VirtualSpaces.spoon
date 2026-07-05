#!/bin/bash

set -e

SCREENSHOT_DIR=".tmp/screenshots"
MARKER_FILE=".tmp/acceptance-marker.txt"

before_all() {
    rm -rf "$SCREENSHOT_DIR"
    mkdir -p "$SCREENSHOT_DIR"
    hs -c "hs.loadSpoon('VirtualSpaces')"
}

capture_screen() {
    screencapture -x "$1"
}

open_textedit_window() {
    printf 'VIRTUALSPACES_ACCEPTANCE\n' > "$MARKER_FILE"
    open -a TextEdit "$MARKER_FILE"
    sleep 3
}

close_textedit_windows() {
    killall TextEdit >/dev/null 2>&1 || true
    rm -f "$MARKER_FILE"
}

test_init() {
    echo "Test: spoon.VirtualSpaces:init()"

    hs -c "
        assert(spoon.VirtualSpaces ~= nil, 'Module should load')
        assert(type(spoon.VirtualSpaces) == 'table', 'Module should be a table')
        assert(type(spoon.VirtualSpaces.init) == 'function', 'Module should have init method')

        spoon.VirtualSpaces:init()

        print('SUCCESS')
    " || {
        echo "FAILED: init() test failed"
        exit 1
    }

    echo "✓ Passed"
    echo
}

test_space_strategy_matches_os() {
    echo "Test: spoon.VirtualSpaces selects the space strategy for the running OS"

    hs -c "
        spoon.VirtualSpaces:init()

        local major = hs.host.operatingSystemVersion().major
        local activeSpace = spoon.VirtualSpaces.spaceStrategy:getActiveSpace()

        if major >= 15 then
            assert(activeSpace == 'emulated-active', 'Sequoia+ should use EmulatedSpace, got ' .. tostring(activeSpace))
        else
            assert(type(activeSpace) == 'number', 'pre-Sequoia should use NativeSpace, got ' .. tostring(activeSpace))
        end

        print('SUCCESS')
    " || {
        echo "FAILED: space strategy selection test failed"
        exit 1
    }

    echo "✓ Passed"
    echo
}

test_switch_hides_and_restores_window() {
    echo "Test: switching virtual spaces hides a window and restores its position"

    open_textedit_window

    hs -c "
        function findWindow(id)
            for _, w in ipairs(hs.window.allWindows()) do
                if w:id() == id then return w end
            end
            return nil
        end

        spoon.VirtualSpaces:init()

        local win
        for _, w in ipairs(hs.window.allWindows()) do
            if w:application():name() == 'TextEdit' and w:isStandard() then win = w end
        end
        assert(win, 'expected an open TextEdit window')

        local frame = win:frame()
        _G.__acc = { id = win:id(), x = frame.x, y = frame.y }

        assert(spoon.VirtualSpaces:getCurrentVirtualSpace() == 1, 'should start on virtual space 1')

        print('SUCCESS')
    " || {
        echo "FAILED: could not set up the TextEdit window"
        close_textedit_windows
        exit 1
    }

    capture_screen "$SCREENSHOT_DIR/01-space1-visible.png"

    hs -c "spoon.VirtualSpaces:switchToVirtualSpace(2); print('SUCCESS')" || {
        echo "FAILED: could not switch to virtual space 2"
        close_textedit_windows
        exit 1
    }
    sleep 1
    capture_screen "$SCREENSHOT_DIR/02-space2-hidden.png"

    hs -c "
        local win = findWindow(_G.__acc.id)
        if win then
            local frame = win:frame()
            assert(math.abs(frame.x - _G.__acc.x) > 5 or math.abs(frame.y - _G.__acc.y) > 5,
                'a window kept on the current space must move away from its original position')
        end

        print('SUCCESS')
    " || {
        echo "FAILED: window was not hidden after switching away"
        close_textedit_windows
        exit 1
    }

    hs -c "spoon.VirtualSpaces:switchToVirtualSpace(1); print('SUCCESS')" || {
        echo "FAILED: could not switch back to virtual space 1"
        close_textedit_windows
        exit 1
    }
    sleep 1
    capture_screen "$SCREENSHOT_DIR/03-space1-restored.png"

    hs -c "
        local win = findWindow(_G.__acc.id)
        assert(win, 'window should be visible again after returning')

        local frame = win:frame()
        assert(math.abs(frame.x - _G.__acc.x) < 5 and math.abs(frame.y - _G.__acc.y) < 5,
            'window should be restored to its previous position')

        print('SUCCESS')
    " || {
        echo "FAILED: window was not restored after returning"
        close_textedit_windows
        exit 1
    }

    close_textedit_windows

    echo "✓ Passed"
    echo
}

before_all
test_init
test_space_strategy_matches_os
test_switch_hides_and_restores_window

echo "All acceptance tests passed!"
