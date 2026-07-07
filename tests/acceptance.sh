#!/bin/bash

set -e

SCREENSHOT_DIR=".tmp/screenshots"
MARKER_FILE=".tmp/acceptance-marker.txt"
MARKER_FILE_2=".tmp/acceptance-marker-2.txt"

before_all() {
    rm -rf "$SCREENSHOT_DIR"
    mkdir -p "$SCREENSHOT_DIR"
    hs -t 15 -c "hs.loadSpoon('VirtualSpaces')"
}

capture_screen() {
    screencapture -x "$1"
}

open_textedit_window() {
    printf 'VIRTUALSPACES_ACCEPTANCE\n' > "$MARKER_FILE"
    open -a TextEdit "$MARKER_FILE"
    sleep 3
}

open_two_textedit_windows() {
    printf 'VIRTUALSPACES_ACCEPTANCE_A\n' > "$MARKER_FILE"
    printf 'VIRTUALSPACES_ACCEPTANCE_B\n' > "$MARKER_FILE_2"
    open -a TextEdit "$MARKER_FILE"
    open -a TextEdit "$MARKER_FILE_2"
    sleep 3
}

close_textedit_windows() {
    killall TextEdit >/dev/null 2>&1 || true
    rm -f "$MARKER_FILE" "$MARKER_FILE_2"
}

test_init() {
    echo "Test: spoon.VirtualSpaces:init()"

    hs -t 15 -c "
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

test_space_strategy() {
    echo "Test: spoon.VirtualSpaces uses the VirtualSpace strategy"

    hs -t 15 -c "
        spoon.VirtualSpaces:init()

        local activeSpace = spoon.VirtualSpaces.spaceStrategy:getActiveSpace()

        assert(activeSpace == 'active', 'expected VirtualSpace active sentinel, got ' .. tostring(activeSpace))

        print('SUCCESS')
    " || {
        echo "FAILED: space strategy test failed"
        exit 1
    }

    echo "✓ Passed"
    echo
}

test_switch_hides_and_restores_window() {
    echo "Test: switching virtual spaces hides a window and restores its position"

    open_textedit_window

    hs -t 15 -c "
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

    hs -t 15 -c "spoon.VirtualSpaces:switchToVirtualSpace(2); print('SUCCESS')" || {
        echo "FAILED: could not switch to virtual space 2"
        close_textedit_windows
        exit 1
    }
    sleep 1
    capture_screen "$SCREENSHOT_DIR/02-space2-hidden.png"

    hs -t 15 -c "
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

    hs -t 15 -c "spoon.VirtualSpaces:switchToVirtualSpace(1); print('SUCCESS')" || {
        echo "FAILED: could not switch back to virtual space 1"
        close_textedit_windows
        exit 1
    }
    sleep 1
    capture_screen "$SCREENSHOT_DIR/03-space1-restored.png"

    hs -t 15 -c "
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

test_virtual_space_changed_event() {
    echo "Test: switching virtual spaces dispatches virtualSpaceChanged"

    hs -t 15 -c "
        spoon.VirtualSpaces:init()

        _G.__evt = { count = 0 }
        _G.__evtCallback = function() _G.__evt.count = _G.__evt.count + 1 end
        spoon.VirtualSpaces:subscribe('virtualSpaceChanged', _G.__evtCallback)

        assert(spoon.VirtualSpaces:getCurrentVirtualSpace() == 1, 'should start on virtual space 1')

        spoon.VirtualSpaces:switchToVirtualSpace(2)
        assert(_G.__evt.count == 1, 'switching to a new space should dispatch once, got ' .. _G.__evt.count)
        assert(spoon.VirtualSpaces:getCurrentVirtualSpace() == 2, 'should be on virtual space 2')

        spoon.VirtualSpaces:switchToVirtualSpace(2)
        assert(_G.__evt.count == 1, 'switching to the same space should not dispatch, got ' .. _G.__evt.count)

        spoon.VirtualSpaces:switchToVirtualSpace(1)
        assert(_G.__evt.count == 2, 'switching back should dispatch again, got ' .. _G.__evt.count)

        spoon.VirtualSpaces:unsubscribe('virtualSpaceChanged', _G.__evtCallback)
        print('SUCCESS')
    " || {
        echo "FAILED: virtualSpaceChanged event test failed"
        exit 1
    }

    echo "✓ Passed"
    echo
}

test_multi_window_split() {
    echo "Test: only the active virtual space's windows stay in place"

    open_two_textedit_windows

    hs -t 15 -c "
        function findWindow(id)
            for _, w in ipairs(hs.window.allWindows()) do
                if w:id() == id then return w end
            end
            return nil
        end

        spoon.VirtualSpaces:init()

        local a, b
        for _, w in ipairs(hs.window.allWindows()) do
            if w:application():name() == 'TextEdit' and w:isStandard() then
                if w:title():find('2') then b = w else a = w end
            end
        end
        assert(a and b, 'expected two open TextEdit windows')

        local fa, fb = a:frame(), b:frame()
        _G.__multi = {
            a = { id = a:id(), x = fa.x, y = fa.y },
            b = { id = b:id(), x = fb.x, y = fb.y },
        }

        spoon.VirtualSpaces:moveWindowToVirtualSpace(b, 2)
        assert(spoon.VirtualSpaces:getCurrentVirtualSpace() == 1, 'should stay on virtual space 1 after moving a window away')

        print('SUCCESS')
    " || {
        echo "FAILED: could not set up two TextEdit windows"
        close_textedit_windows
        exit 1
    }

    sleep 1
    capture_screen "$SCREENSHOT_DIR/04-multi-b-hidden.png"

    hs -t 15 -c "
        local a = findWindow(_G.__multi.a.id)
        assert(a, 'window A should stay visible on virtual space 1')
        local fa = a:frame()
        assert(math.abs(fa.x - _G.__multi.a.x) < 5 and math.abs(fa.y - _G.__multi.a.y) < 5,
            'window A should stay in place when a sibling moves away')

        local b = findWindow(_G.__multi.b.id)
        if b then
            local fb = b:frame()
            assert(math.abs(fb.x - _G.__multi.b.x) > 5 or math.abs(fb.y - _G.__multi.b.y) > 5,
                'window B should be hidden after moving it to another virtual space')
        end

        print('SUCCESS')
    " || {
        echo "FAILED: window split on virtual space 1 was incorrect"
        close_textedit_windows
        exit 1
    }

    hs -t 15 -c "spoon.VirtualSpaces:switchToVirtualSpace(2); print('SUCCESS')" || {
        echo "FAILED: could not switch to virtual space 2"
        close_textedit_windows
        exit 1
    }
    sleep 1
    capture_screen "$SCREENSHOT_DIR/05-multi-a-hidden.png"

    hs -t 15 -c "
        local b = findWindow(_G.__multi.b.id)
        assert(b, 'window B should be visible on virtual space 2')
        local fb = b:frame()
        assert(math.abs(fb.x - _G.__multi.b.x) < 5 and math.abs(fb.y - _G.__multi.b.y) < 5,
            'window B should be restored on virtual space 2')

        local a = findWindow(_G.__multi.a.id)
        if a then
            local fa = a:frame()
            assert(math.abs(fa.x - _G.__multi.a.x) > 5 or math.abs(fa.y - _G.__multi.a.y) > 5,
                'window A should be hidden on virtual space 2')
        end

        spoon.VirtualSpaces:switchToVirtualSpace(1)
        print('SUCCESS')
    " || {
        echo "FAILED: window split on virtual space 2 was incorrect"
        close_textedit_windows
        exit 1
    }

    close_textedit_windows

    echo "✓ Passed"
    echo
}

test_manual_navigation_auto_switch() {
    echo "Test: focusing a hidden window auto-switches to its virtual space"

    open_textedit_window

    hs -t 15 -c "
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

        _G.__nav = { id = win:id() }

        spoon.VirtualSpaces:moveWindowToVirtualSpace(win, 2)
        assert(spoon.VirtualSpaces:getCurrentVirtualSpace() == 1, 'should stay on virtual space 1 after moving the window away')

        print('SUCCESS')
    " || {
        echo "FAILED: could not move the window to virtual space 2"
        close_textedit_windows
        exit 1
    }

    sleep 1

    hs -t 15 -c "
        local win = findWindow(_G.__nav.id)
        assert(win, 'the hidden window should still exist')
        win:focus()
        print('SUCCESS')
    " || {
        echo "FAILED: could not focus the hidden window"
        close_textedit_windows
        exit 1
    }

    sleep 1
    capture_screen "$SCREENSHOT_DIR/06-manual-nav.png"

    hs -t 15 -c "
        assert(spoon.VirtualSpaces:getCurrentVirtualSpace() == 2,
            'focusing a hidden window should auto-switch to its virtual space, got ' .. spoon.VirtualSpaces:getCurrentVirtualSpace())
        print('SUCCESS')
    " || {
        echo "FAILED: focusing the hidden window did not switch virtual space"
        close_textedit_windows
        exit 1
    }

    close_textedit_windows

    echo "✓ Passed"
    echo
}

before_all
test_init
test_space_strategy
test_switch_hides_and_restores_window
test_virtual_space_changed_event
test_multi_window_split
test_manual_navigation_auto_switch

echo "All acceptance tests passed!"
