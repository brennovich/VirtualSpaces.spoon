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

# Run a single test class or method (LuaUnit filters by name)
lua tests/test.lua TestWindowDestroyed
lua tests/test.lua TestWindowDestroyed.testNonTabbedWindowDestroyedRestoresFocus

# Run acceptance tests (requires Hammerspoon installed, exercises a real hs instance)
make test/acceptance
```

### Building and Installation
```bash
# Install dependencies
make dependencies

# Build the spoon (creates release/VirtualSpaces.spoon.zip)
make build

# Build and install to ~/.hammerspoon/Spoons (sets debug telemetry level)
make install

# Generate documentation JSON
make docs.json
```

### Testing Individual Modules
Tests are organized by module in `tests/`. Each test file can be run independently by requiring it from `tests/test.lua`:
- `tests/test_windows_sort.lua` - WindowsSort logic
- `tests/test_spaces_model.lua` - SpacesModel state management
- `tests/test_native_space.lua` - NativeSpace setup
- `tests/test_move_window_to_virtual_space.lua` - Window movement tests
- `tests/test_space_watcher.lua` - Space watcher behavior
- `tests/test_telemetry.lua` - Telemetry/instrumentation tests
- `tests/test_window_cache.lua` - WindowCache caching logic
- `tests/test_get_windows_api.lua` - Public API for getting windows
- `tests/test_public_api.lua` - Public API tests
- `tests/test_window_destroyed.lua` - Window destruction and focus restoration behavior

### Development
This is a Hammerspoon Spoon. Load it in Hammerspoon with:
```lua
hs.loadSpoon("VirtualSpaces")
spoon.VirtualSpaces:init()

-- Enable telemetry for debugging (default level is 'warning', i.e. disabled)
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
   - Tabbed window management:
     - `_windows` - registry of window metadata (id, tabCount, frame, appName)
     - `_tabGroups` - groups of windows that share the same tabs
     - `_windowToTabGroup` - mapping from window ID to its tab group
   - No side effects, pure data operations

2. **WindowsSort** (`WindowsSort.lua`): Window movement logic
   - Takes categorized windows and maps them to native spaces
   - Handles space swapping when user navigates to storage space
   - Injects `windowMoverFn` (typically `hs.spaces.moveWindowToSpace`)
   - Injects `windowSpaceGetter` (typically `hs.spaces.windowSpaces`) to check current window location
   - Skips window moves when window is already in target space (performance optimization)

3. **NativeSpace** (`NativeSpace.lua`): macOS Spaces setup
   - Ensures exactly two native spaces exist on main screen
   - Designates first space as "active", second as "storage"
   - Handles space creation/removal on initialization

### Window Module (`Window.lua`)

Provides window metadata extraction and comparison utilities:
- `Window.new(hsWindow)` - Creates window metadata object with:
  - `id` - window ID
  - `tabCount` - number of tabs (from `hsWindow:tabCount()`)
  - `frame` - window frame/position
  - `appName` - application name
- `Window.makeKey(frame, appName)` - Creates composite key for indexing windows by position and app
- `Window.framesEqual(frame1, frame2)` - Compares two frames with Y_TOLERANCE for y-coordinate
- `Window.Y_TOLERANCE` - Tolerance (10 pixels) for y-coordinate comparison to handle Terminal.app tabs
- Used by SpacesModel to detect and group tabbed windows (windows with same frame + app)

### Tabbed Windows Support

VirtualSpaces automatically detects and manages tabbed windows (Safari tabs, Terminal tabs, etc.):

**Detection Strategy:**
- Tabbed windows share similar frame positions (with 10-pixel y-coordinate tolerance) and belong to the same application
- Y-coordinate tolerance handles Terminal.app tabs which have slightly different y positions
- Uses `hsWindow:tabCount()` to identify windows with multiple tabs
- Groups windows by matching `frame + appName` combination

**Behavior:**
- When a tabbed window is moved to a virtual space, all tabs in the group move together
- When a tab is closed, focus is restored to a sibling tab if available
- Tab groups are automatically created/updated as windows are created or destroyed
- Maintains tab group consistency across virtual space transitions

**Implementation:**
- SpacesModel maintains tab group registry indexed by frame+appName
- Tab detection occurs during `registerWindowObject()` on window creation
- `_assignWindowAndTabGroupToVirtualSpace()` ensures entire tab groups move atomically

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
- Initializes native space setup via `NativeSpace`
- Creates `WindowsSort` with space IDs and window mover function
- Creates `SpacesModel` for state tracking
- Creates `WindowCache` for performance optimization
- Creates `Telemetry` for instrumentation
- Sets up window filters for automatic window assignment
- Implements space watcher to detect manual navigation to storage space
- Handles tabbed window groups: when moving a window, all tabs in the group move together
- Provides public API:
  - `switchToVirtualSpace(virtualSpace)` - Switch to a virtual workspace
  - `moveWindowToVirtualSpace(window, virtualSpace)` - Move window to workspace
  - `getWindowsForCurrentVirtualSpace()` - Get all windows in current space
  - `getCurrentVirtualSpace()` - Get current virtual space ID
  - `getCurrentVirtualSpaceMetadata()` - Get detailed metadata for current space
  - `subscribe(eventType, callback)` - Subscribe to events
  - `unsubscribe(eventType, callback)` - Unsubscribe from events
  - `instrument(logLevel)` - Set telemetry log level

### Public API and Event System

The spoon exposes a public API for extensibility:

**Query Methods:**
- `getCurrentVirtualSpace()` - Returns current space ID (1-4)
- `getCurrentVirtualSpaceMetadata()` - Returns table with `id`, `windowCount`, `windows`, `focusedWindow`
- `getWindowsForCurrentVirtualSpace()` - Returns array of window objects in current space

**Event Subscription:**
- `subscribe(eventType, callback)` - Register callback for events (returns self for chaining)
- `unsubscribe(eventType, callback)` - Unregister callback (returns self for chaining)
- Event types: `"virtualSpaceChanged"`
- Event data structure: `{eventType, currentSpace: {id, windowCount, windows, focusedWindow}}`

**Error Handling:**
- Subscriber callbacks wrapped in `pcall()` to prevent breaking event dispatch
- Invalid event types log warnings via `hs.logger`
- Invalid callbacks (non-functions) log errors

### Data Flow

**Window Creation:**
1. `windowFilter` detects new window
2. Window registered in `SpacesModel` via `registerWindowObject()`:
   - Extracts metadata (id, tabCount, frame, appName) via `Window.new()`
   - If `tabCount > 1`, checks for existing tab group with same frame+app
   - Creates new tab group or adds to existing group
3. Assigned to current virtual space (entire tab group if tabbed)
4. Window object added to `WindowCache`
5. Window stays in active native space

**Workspace Switch:**
1. `SpacesModel.categorizeWindowsForTransition()` groups windows: toActive, toStorage, others
2. `WindowsSort.mapWindowsToNativeSpaces()` moves windows to correct native spaces
3. Focus restored to last focused window in target virtual space (retrieved via `WindowCache`)

**Window Destruction:**
1. `windowFilter` detects window destroyed
2. Tab siblings retrieved via `getTabSiblingsBeforeDestruction()` (if part of tab group)
3. Window unregistered from `SpacesModel` via `unregisterWindowObject()`:
   - Removed from tab group
   - Tab group deleted if empty
4. Removed from virtual space assignment
5. Removed from `WindowCache`
6. Focus restored to tab sibling if available, otherwise to other windows in virtual space

**Manual Navigation:**
1. `spaceWatcher` detects user navigated to storage space
2. If focused window belongs to different virtual space, switch to that virtual space
3. This enables discovering "hidden" windows by navigating to storage space

**Moving Tabbed Windows:**
1. `moveWindowToVirtualSpace()` called with a window
2. `_assignWindowAndTabGroupToVirtualSpace()` checks if window is part of a tab group
3. If tabbed (via `getTabGroupForWindow()`):
   - All windows in the tab group are assigned to the target virtual space
   - Entire group moves together to maintain tab consistency
4. If not tabbed, single window is assigned normally
5. Window(s) moved to appropriate native space (active or storage based on target)

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

Mock Hammerspoon APIs by injecting functions/objects into constructors (see `NativeSpace.new()` parameters).

### Test Helpers

`tests/test_helpers.lua` provides utilities for test setup:

**`createHsGlobal(overrides)`** - Creates standardized `_G.hs` mock with sensible defaults:
- Accepts `overrides` table to customize specific behaviors
- Provides default implementations for all Hammerspoon APIs
- Key override parameters:
  - `spaces` - Table with `{activeSpace, storageSpace}` IDs
  - `movedWindows` - Array to track window movements
  - `mockWindows` - Table mapping window IDs to mock window objects
  - `focusedWindow` - Function returning currently focused window
  - `windowGet` - Function to get window by ID
  - `moveWindowToSpace` - Custom window mover function
  - `activeSpaceOnScreen` - Function returning current active space
  - `windowSpaces` - Function returning spaces for a window
  - `watcher` - Custom space watcher implementation
  - `loggerNew` - Custom logger factory

**`createHsWindow(id, appName)`** - Creates mock Hammerspoon window object with standard methods

**`createWindow(id, tabCount, frame, appName)`** - Creates window metadata for SpacesModel

**`withHsGlobal(hsConfig, fn)`** - Temporarily sets `_G.hs` for test execution

### Telemetry in Tests

Components accept an optional `telemetry` parameter in their constructors:
- When `nil`, automatically creates `NoOpTelemetry` (null object pattern)
- Tests can inject mock telemetry to verify logging behavior
- No need for nil checks - `self._telemetry` always exists

## Key Constraints

- **Does not support macOS Sequoia** - Due to [Hammerspoon issue #3698](https://github.com/Hammerspoon/hammerspoon/issues/3698), the spoon relies heavily on `hs.spaces.moveWindowToSpace` which is broken on Sequoia
- Only standard windows are managed (fullscreen windows excluded)
- Window identification uses numeric window IDs (`window:id()`)
- Requires exactly two native macOS spaces to function; native Spaces features (e.g. creating new spaces via Mission Control) should not be used alongside it
- All operations target main screen only (multi-screen support may be added in the future)
- Native focus events (Dock clicks, cmd+tab) trigger macOS space transitions - recommend setting Reduce Motion in System Preferences > Accessibility > Display
