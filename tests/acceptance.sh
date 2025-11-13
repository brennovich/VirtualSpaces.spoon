#!/bin/bash

set -e

before_all() {
    hs -c "hs.loadSpoon('VirtualSpaces')" 
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

before_all
test_init

echo "All acceptance tests passed!"
