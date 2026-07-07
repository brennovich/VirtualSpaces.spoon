# CLAUDE.md

VirtualSpaces is a Hammerspoon Spoon for workspace management on macOS. It switches workspaces instantly by keeping the current workspace's windows in place and hiding the rest off-screen (an "active"/"storage" split emulated within a single native Space).

## Commands

```bash
make test                                    # run tests (or: luarocks test)
lua tests/test.lua TestWindowDestroyed       # single test class (LuaUnit name filter)
lua tests/test.lua TestWindowDestroyed.testNonTabbedWindowDestroyedRestoresFocus
make test/acceptance                         # requires Hammerspoon, real hs instance
make dependencies                            # install deps
make build                                   # release/VirtualSpaces.spoon.zip
make install                                 # build + install to ~/.hammerspoon/Spoons
```

Test files live in `tests/test_<module>.lua`, one per module, required from `tests/test.lua`.

## Architecture

- **`SpacesModel.lua`** — pure state, no side effects: window↔virtual-space maps, focused window per space, tab group registry (`_groups`, `_windowToGroup`). `categorizeWindowsForTransition` splits a switch into `toActive`/`toStorage` window lists, which `init.lua`'s `_switchSpaces` moves via the strategy.
- **Space strategy** — swappable abstraction behind `self.spaceStrategy`, implementing the interface (`setupForMainScreen`, `getActiveSpace`, `getStorageSpace`, `moveWindowToSpace`, `windowSpaces`, `startWatchingForManualNavigation`, `forgetWindow`, ...). There is currently one implementation:
  - **`VirtualSpace.lua`** (the only strategy, because `hs.spaces.moveWindowToSpace` is broken on Sequoia — [Hammerspoon #3698](https://github.com/Hammerspoon/hammerspoon/issues/3698)): hides "storage" windows by pushing them into the bottom-right corner of the screen (macOS clamps to a ~1x38px visible nub; full off-screen is impossible) and restores the captured frame when shown. `moveWindowToSpace` is idempotent — hiding an already-hidden window or showing an already-visible one is a no-op. Manual navigation = a hidden window gaining focus (cmd+tab, Dock, clicking the nub); `startWatchingForManualNavigation` fires the callback with the storage sentinel, and `init.lua` switches the virtual space to match. `forgetWindow()` must drop the captured hidden frame on window destruction or a reused window ID is misreported as "storage".
- **`Window.lua`** — window metadata (`id`, `tabCount`, `frame`, `appName`) and frame comparison with `Y_TOLERANCE` (10px, for Terminal.app tabs).
- **`WindowCache.lua`** — caches window objects to avoid the 40-130ms `hs.window.get()` cost; validates via `id()` on retrieval, lazy-populates on miss.
- **`Telemetry.lua`** — `span(name, fn)` logging/timing; `NoOpTelemetry` null object when disabled. Constructors take optional `telemetry`; when `nil` a NoOp is created, so `self._telemetry` never needs nil checks.
- **`init.lua`** — orchestrates everything: picks the strategy, wires window filters, and exposes the public API (`switchToVirtualSpace`, `moveWindowToVirtualSpace`, `getCurrentVirtualSpace`, `getCurrentVirtualSpaceMetadata`, `getWindowsForCurrentVirtualSpace`, `subscribe`/`unsubscribe` for `"virtualSpaceChanged"`, `instrument(logLevel)`).

### Tabbed windows

Windows with `tabCount > 1` sharing the same frame (within `Y_TOLERANCE`) + app name are grouped. The whole group moves between virtual spaces atomically, and closing a tab restores focus to a sibling.

## Testing

LuaUnit; tests follow `TestModuleName:testSomething()` with arrange/act/assert. Mock Hammerspoon by injecting functions into constructors. `tests/test_helpers.lua` provides:

- `createHsGlobal(overrides)` — standard `_G.hs` mock; override keys like `spaces`, `movedWindows`, `mockWindows`, `focusedWindow`, `moveWindowToSpace`, `mainScreen` (mock screen with `getUUID()`/`fullFrame()`/`frame()`, needed by `VirtualSpace`).
- `createHsWindow(id, appName)` — mock hs window object.
- `createWindow(id, tabCount, frame, appName)` — window metadata for SpacesModel.
- `withHsGlobal(hsConfig, fn)` — temporarily sets `_G.hs`.

## Key Constraints

- Only standard windows are managed (fullscreen excluded); main screen only; windows identified by numeric `window:id()`.
- **VirtualSpace**: hidden windows stay on the same native Space, so Mission Control/Cmd+Tab/App Exposé can still reveal them.
