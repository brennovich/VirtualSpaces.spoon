_**Note**: on macOS Sequoia and later, `hs.spaces.moveWindowToSpace` is broken ([Hammerspoon issue #3698](https://github.com/Hammerspoon/hammerspoon/issues/3698)), so this Spoon automatically falls back to an emulated strategy there (see "Emulated strategy on Sequoia+" below) instead of moving windows between native Spaces._

--

# VirtualSpaces.spoon

VirtualSpaces implements a virtual workspace system that tries to get rid of the annoying Spaces transitions of macOS Mission Control.

## Overview

<video src="https://github.com/user-attachments/assets/ccabd368-a6ce-47ef-b62b-85a36037694f"></video>

It creates multiple logical workspaces on a single macOS desktop by managing window visibility across two macOS spaces: one active and one for storage. Its goal is to provide a instant switching experience between workspaces without the overhead of managing multiple physical desktops and superfulous macOS transition effects.

## Architecture

- **Active Space:** Where visible workspace windows are displayed
- **Storage Space:** Where hidden workspace windows are kept
- **Virtual Workspaces:** Logical groupings that map to physical spaces

<video src="https://github.com/user-attachments/assets/33ad4f85-efc3-48f6-af51-ec59f1b73156"></video>

When switching workspaces, windows are moved between active and storage spaces to simulate independent desktops. This I found to be quite efficient, and looks better than the strategy used by Aerospace, which relies on hiding windows in the corner of the screen (where you can still see some pixels of it).

This is the strategy used pre-Sequoia. On macOS Sequoia and later, an emulated strategy is used instead — see "Emulated strategy on Sequoia+" below.

### Native focus behavior (pre-Sequoia)

When clicking on a Dock icon, or when and applications brings focus or even when cmd+tab is used, if the window in question is in the storage space, the spoon will switch the roles of the native spaces, making the storage space active and vice versa. This way, the user can still use native macOS focus behavior without breaking the virtual workspace metaphor. The only downside is that upon such switch the transition effect will occur.

<video src="https://github.com/user-attachments/assets/6f29eece-0b35-4a35-aaf2-8af68989ab8a"></video>

For that is recommended to set Reduce Motion in System Preferences > Accessibility > Display.

This behavior does not apply on Sequoia+, since the emulated strategy never uses a second native Space to begin with — there's nothing to switch roles with.

### Emulated strategy on Sequoia+

Since `hs.spaces.moveWindowToSpace` is broken on Sequoia, VirtualSpaces detects the OS version at init time and, on macOS 15+, hides "storage" windows by moving them almost entirely off the right edge of the main screen instead of to a second native Space — the same approach Aerospace uses. This has a few consequences worth knowing about:

- macOS itself refuses to place a window fully outside all screens, so a 1px sliver of each hidden window remains visible at the screen's edge. This is expected, OS-enforced behavior, not a bug.
- Mission Control, Cmd+Tab, and App Exposé can still reveal "hidden" windows, since they technically remain on the same, single native Space.
- The Dock/gesture-based "manually navigate to storage" discovery described above doesn't apply, since there's no second native Space to navigate to.
- If Hammerspoon reloads or crashes while windows are parked at the hidden edge, they're pulled back to a visible position on the next `init()` — not necessarily their exact prior position.

## Features

### Workspace Management

#### Switch to Workspace

Switch to a different virtual workspace.

```lua
spoon.VirtualSpaces:switchToVirtualSpace(virtualSpace)
```

#### Move Window to Workspace

Assign a given window to a different workspace.

```lua
spoon.VirtualSpaces:moveWindowToVirtualSpace(window, virtualSpace)
```

If `window` is `nil`, the currently focused window is used.

### Public API

VirtualSpaces exposes a public API for extensibility and integration with other spoons.

#### Query Current State

Get the current virtual space ID:

```lua
local spaceId = spoon.VirtualSpaces:getCurrentVirtualSpace()
-- Returns: number (1-N)
```

Get detailed metadata for the current virtual space:

```lua
local metadata = spoon.VirtualSpaces:getCurrentVirtualSpaceMetadata()
-- Returns: {
--   id = number,              -- Current virtual space ID (1-N)
--   windowCount = number,     -- Number of windows in this space
--   windows = table,          -- Array of hs.window objects
--   focusedWindow = window    -- Currently focused window (or nil)
-- }
```

Get all windows in the current virtual space:

```lua
local windows = spoon.VirtualSpaces:getWindowsForCurrentVirtualSpace()
-- Returns: array of hs.window objects
```

#### Event Subscription

Subscribe to virtual space events:

```lua
spoon.VirtualSpaces:subscribe("virtualSpaceChanged", function(eventData)
    print("Switched to space " .. eventData.currentSpace.id)
    print("Window count: " .. eventData.currentSpace.windowCount)
end)
```

Event data structure:

```lua
{
    eventType = "virtualSpaceChanged",
    currentSpace = {
        id = number,              -- Current virtual space ID (1-N)
        windowCount = number,     -- Number of windows
        windows = table,          -- Array of hs.window objects
        focusedWindow = window    -- Currently focused window (or nil)
    }
}
```

-- Subscribe
spoon.VirtualSpaces:subscribe("virtualSpaceChanged", callback)

-- Unsubscribe
spoon.VirtualSpaces:unsubscribe("virtualSpaceChanged", callback)
```

Both methods return `self` for chaining.

## Typical Usage

```lua
hs.loadSpoon("VirtualSpaces")
spoon.VirtualSpaces:init()

for i = 1, 4 do
    hs.hotkey.bind({"leftalt"}, tostring(i), function()
        spoon.VirtualSpaces:switchToVirtualSpace(i)
    end)

    hs.hotkey.bind({"leftalt", "shift"}, tostring(i), function()
        spoon.VirtualSpaces:moveWindowToVirtualSpace(nil, i)
    end)
end
```

## Instrumentation and Debugging

VirtualSpaces includes performance instrumentation to measure Hammerspoon API call timings. By default, logging is disabled (warning level).

To enable verbose performance metrics, call the `instrument()` method at any time:

```lua
hs.loadSpoon("VirtualSpaces")

-- Operations logging enabled
spoon.VirtualSpaces:instrument('info')

-- Operations and performance logging enabled
spoon.VirtualSpaces:instrument('debug')
```

You can change the log level dynamically:

```lua
-- Enable debug logging
spoon.VirtualSpaces:instrument('debug')

-- Disable logging
spoon.VirtualSpaces:instrument('warning')
```

With debug logging enabled, you'll see timing information for operations.  Check the Hammerspoon console for timing output. I might publish Telemetry as a dedicated Spoon in the future (I still need to improve its output formatting).

## Limitations

- Supports only one screen (once I get it stable, multi-screen support may be added)
- Pre-Sequoia: you need to give up on macOS native Spaces features, like creating new spaces through Mission Control
- Pre-Sequoia: native focus events (clicking Dock icons, cmd+tabbing) will trigger macOS space transitions
- Sequoia+ (emulated strategy): a 1px sliver of hidden windows remains visible at the screen edge, and Mission Control/Cmd+Tab/Exposé can still reveal them — see "Emulated strategy on Sequoia+" above

## Contribute

### Running Tests

```bash
make test
```

Tests use the LuaUnit framework and follow TDD principles.

### Building and Installing

```bash
# Build the spoon
make build

# Build and install to ~/.hammerspoon/Spoons
make install
```
