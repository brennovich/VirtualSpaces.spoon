#!/bin/bash

set -e

test_init() {
    echo "Test: spoon.VirtualSpaces:init()"

    hs -c "
        hs.loadSpoon("VirtualSpaces")

        assert(spoon.VirtualSpaces ~= nil, 'Module should load')
        assert(type(spoon.VirtualSpaces) == 'table', 'Module should be a table')
        assert(type(spoon.VirtualSpaces.init) == 'function', 'Module should have init method')
        assert(spoon.VirtualSpaces.name == 'VirtualSpaces', 'Module name should be VirtualSpaces')

        print('SUCCESS')
    " || {
        echo "FAILED: init() test failed"
        exit 1
    }

    echo "✓ Passed"
    echo
}

test_init

echo "All acceptance tests passed!"
