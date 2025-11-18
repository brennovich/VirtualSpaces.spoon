# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

VirtualSpaces is a Hammerspoon Spoon that implements virtual workspace management for macOS, similar to i3/Linux window managers. It provides instant workspace switching by managing window visibility across two physical macOS spaces (active and storage).

## Commands

### Running Tests
```bash
# Recommended: Run tests via make
make test

# Or via luarocks
luarocks test

# Direct invocation (requires luarocks path setup)
eval $(luarocks --local path) && lua tests/test.lua -o TAP

# Without TAP output
lua tests/test.lua
```

### Testing Individual Modules
Tests are organized by module in `tests/`. Each test file can be run independently by requiring it from `tests/test.lua`:
- `tests/test_windows_sort.lua` - WindowsSort logic
- `tests/test_spaces_model.lua` - SpacesModel state management
- `tests/test_native_space_manager.lua` - NativeSpaceManager setup
- `tests/test_virtual_spaces.lua` - Main integration tests
- `tests/test_telemetry.lua` - Telemetry/instrumentation tests
- `tests/test_window_cache.lua` - WindowCache caching logic

### Development
This is a Hammerspoon Spoon. Load it in Hammerspoon with:
```lua
hs.loadSpoon("VirtualSpaces")
spoon.VirtualSpaces:init()

-- Enable telemetry for debugging
spoon.VirtualSpaces:instrument('info')   -- Log operations only
spoon.VirtualSpaces:instrument('debug')  -- Log operations + performance
```

## Architecture

### Three-Layer Design

1. **SpacesModel** (`SpacesModel.lua`): Pure state management
   - Tracks window-to-virtual-space mappings (`_windowVirtualSpaceMap`)
   - Tracks virtual-space-to-windows mappings (`_virtualSpaceWindowsMap`)
   - Tracks focused window per virtual space (`_focusedWindows`)
   - Current virtual space tracking (`_currentVirtualSpace`)
   - No side effects, pure data operations

2. **WindowsSort** (`WindowsSort.lua`): Window movement logic
   - Takes categorized windows and maps them to native spaces
   - Handles space swapping when user navigates to storage space
   - Injects `windowMoverFn` (typically `hs.spaces.moveWindowToSpace`)
   - Injects `windowSpaceGetter` (typically `hs.spaces.windowSpaces`) to check current window location
   - Skips window moves when window is already in target space (performance optimization)

3. **NativeSpaceManager** (`NativeSpaceManager.lua`): macOS Spaces setup
   - Ensures exactly two native spaces exist on main screen
   - Designates first space as "active", second as "storage"
   - Handles space creation/removal on initialization

### Telemetry System (`Telemetry.lua`)

Provides observability for operations and performance:
- `span(operationName, fn)` - Wraps operations with logging and timing
- Log level 'info': logs operation names only
- Log level 'debug': logs operation names + performance timing
- `NoOpTelemetry` - Null object pattern when telemetry disabled
- All components use `self._telemetry:span()` for instrumentation

### Window Cache (`WindowCache.lua`)

Performance optimization that caches window objects:
- Eliminates 40-130ms `hs.window.get()` bottleneck during focus operations
- Validates cached windows on retrieval (checks window object accessibility via `id()`)
- Does not validate window state (`isStandard()`) to avoid expensive checks
- Self-healing: automatically removes stale entries when window objects become inaccessible
- Lazy population: fetches via `window.get()` on cache miss, then caches result
- Populated from window filter events and initialization
- Invalidated on window destruction

### Main Controller (`init.lua`)

Orchestrates all components:
- Initializes native space setup via `NativeSpaceManager`
- Creates `WindowsSort` with space IDs and window mover function
- Creates `SpacesModel` for state tracking
- Creates `WindowCache` for performance optimization
- Creates `Telemetry` for instrumentation
- Sets up window filters for automatic window assignment
- Implements space watcher to detect manual navigation to storage space
- Provides public API: `switchToVirtualSpace()`, `moveWindowToVirtualSpace()`, `instrument()`

### Data Flow

**Window Creation:**
1. `windowFilter` detects new window
2. Assigned to current virtual space in `SpacesModel`
3. Window object added to `WindowCache`
4. Window stays in active native space

**Workspace Switch:**
1. `SpacesModel.categorizeWindowsForTransition()` groups windows: toActive, toStorage, others
2. `WindowsSort.mapWindowsToNativeSpaces()` moves windows to correct native spaces
3. Focus restored to last focused window in target virtual space (retrieved via `WindowCache`)

**Window Destruction:**
1. `windowFilter` detects window destroyed
2. Removed from `SpacesModel`
3. Removed from `WindowCache`
4. Focus restored if needed

**Manual Navigation:**
1. `spaceWatcher` detects user navigated to storage space
2. If focused window belongs to different virtual space, switch to that virtual space
3. This enables discovering "hidden" windows by navigating to storage space

## Testing Strategy

Tests use LuaUnit framework. Test structure follows pattern:
```lua
TestModuleName = {}

function TestModuleName:testSomething()
  -- arrange
  -- act
  -- assert
end
```

Mock Hammerspoon APIs by injecting functions/objects into constructors (see `NativeSpaceManager.new()` parameters).

### Telemetry in Tests

Components accept an optional `telemetry` parameter in their constructors:
- When `nil`, automatically creates `NoOpTelemetry` (null object pattern)
- Tests can inject mock telemetry to verify logging behavior
- No need for nil checks - `self._telemetry` always exists

## Key Constraints

- Only standard windows are managed (fullscreen windows excluded)
- Window identification uses numeric window IDs (`window:id()`)
- Requires exactly two native macOS spaces to function
- All operations target main screen only
