_**Importat**: due to this [issue](https://github.com/Hammerspoon/hammerspoon/issues/3698) from Hammerspoon, this Spoon doesn't support macOS Sequoia as it heavily relies on `hs.spaces.moveWindowToSpace`._

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
- **Window Cache:** Performance optimization that caches window objects

<video src="https://github.com/user-attachments/assets/33ad4f85-efc3-48f6-af51-ec59f1b73156"></video>

When switching workspaces, windows are moved between active and storage spaces to simulate independent desktops. This I found to be quite efficient, and looks better than the strategy used by Aerospace, which relies on hiding windows the the corner of the screen (where you can still see some pixels of it).

### Native focus behavior

When clicking on a Dock icon, or when and applications brings focus or even when cmd+tab is used, if the window in question is in the storage space, the spoon will switch the roles of the native spaces, making the storage space active and vice versa. This way, the user can still use native macOS focus behavior without breaking the virtual workspace metaphor. The only downside is that upon such switch the transition effection will occur.

<video src="https://github.com/user-attachments/assets/6f29eece-0b35-4a35-aaf2-8af68989ab8a"></video>

For that is recommended to set Reduce Motion in System Preferences > Accessibility > Display.

## Features

### Workspace Management

#### Switch to Workspace
Switch to a different virtual workspace.

```lua
spoon.VirtualSpaces:switchToVirtualSpace(virtualSpace)
```

#### Move Window to Workspace
Assign the focused window to a different workspace.

```lua
spoon.VirtualSpaces:moveWindowToVirtualSpace(virtualSpace)
```

Assign a given window to a different workspace.

```lua
spoon.VirtualSpaces:moveWindowToVirtualSpace(window, virtualSpace)
```

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
spoon.VirtualSpaces:instrument('debug')
```

You can change the log level dynamically:

```lua
-- Enable debug logging
spoon.VirtualSpaces:instrument('debug')

-- Disable logging
spoon.VirtualSpaces:instrument('warning')
```

With debug logging enabled, you'll see timing information for operations like:
- Native space management (creation, removal, switching)
- Window movement between spaces
- Focus management

Check the Hammerspoon console for timing output.

## Limitations

- Only works with standard windows (fullscreen windows are excluded)
- Supports only one screen (once I get it stable, multi-screen support may be added)
- You need to give up on macOS native Spaces features, like creating new spaces through Mission Control

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
