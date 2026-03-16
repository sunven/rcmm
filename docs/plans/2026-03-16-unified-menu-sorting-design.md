# Unified Menu Sorting Design

## Goal

Let built-in features (copy path, etc.) participate in menu ordering alongside custom commands, with a unified sorting model and extensibility for future built-in features.

## Decisions

- **Approach:** Unified `MenuEntry` enum (Option A) — best semantics and extensibility.
- **UI:** Mixed list — built-in and custom items in one list, visually distinguished.
- **Built-in operations:** Toggle + reorder only (no delete, no edit).
- **No migration needed:** Project is in development; replace old persistence directly.

## Data Model (RCMMShared)

### New Types

```swift
public enum BuiltInType: String, Codable, Sendable {
    case copyPath
    // future: openInTerminal, newFile, ...
}

public struct BuiltInMenuItem: Codable, Hashable, Sendable {
    public let type: BuiltInType
    public var isEnabled: Bool

    public var displayName: String {
        switch type {
        case .copyPath: return "拷贝路径"
        }
    }
}

public enum MenuEntry: Codable, Identifiable, Hashable, Sendable {
    case builtIn(BuiltInMenuItem)
    case custom(MenuItemConfig)

    public var id: String {
        switch self {
        case .builtIn(let item): return "builtIn.\(item.type.rawValue)"
        case .custom(let config): return config.id.uuidString
        }
    }

    public var isEnabled: Bool { ... }
    public var displayName: String { ... }
}
```

### MenuItemConfig Changes

- Remove `sortOrder` field — ordering determined by array position in `[MenuEntry]`.
- All other fields unchanged.

## Persistence (SharedConfigService)

- New key: `rcmm.menu.entries` stores `[MenuEntry]` as JSON array.
- Remove old keys: `rcmm.menu.items` and `rcmm.copyPath.enabled`.
- Array index = display order (no `sortOrder` field, no `.sorted(by:)` needed).

### Default Config (First Launch)

```
[.custom(Terminal default), .builtIn(.copyPath, isEnabled: true)]
```

## AppState Changes

### Properties

- `menuItems: [MenuItemConfig]` → `menuEntries: [MenuEntry]`
- `copyPathEnabled: Bool` → removed (embedded in `MenuEntry.builtIn`)

### Methods

| Operation | Method |
|---|---|
| Add custom command | `addEntry(.custom(...))` — appends to end |
| Move | `moveEntry(from:to:)` — unified reorder |
| Remove | `removeEntry(at:)` — blocked for `.builtIn` |
| Toggle | `toggleEntry(id:)` — unified toggle |
| Edit command | `updateCustomCommand(id:command:)` — finds `.custom` entry |

### Save & Sync

`saveAndSync()` persists `[MenuEntry]` via `configService.saveEntries()`, extracts `.custom` items for `scriptInstaller.syncScripts()`, then posts Darwin notification.

## FinderSync Extension

### Menu Building

Single loop over `loadEntries().filter { $0.isEnabled }`:

```swift
for entry in entries {
    switch entry {
    case .builtIn(let item):
        // .copyPath → NSMenuItem(title: "拷贝路径", action: #selector(copyPath(_:)))
    case .custom(let config):
        // NSMenuItem(title: "用 \(config.appName) 打开", ...)
    }
}
```

- Array order = menu order. No `.sorted(by:)`.
- Copy path still uses `NSPasteboard` (no script).
- Custom commands still use `ScriptExecutor`.
- Still re-reads from UserDefaults on every right-click.

## Settings UI (MenuConfigTab)

### Mixed List

All `menuEntries` in one `List` with drag-and-drop reorder.

**Built-in row:**
- SF Symbol icon (e.g., `doc.on.clipboard` for copy path)
- Fixed display name (not editable)
- Toggle for enable/disable
- No delete button, no edit command entry
- Supports drag reorder and up/down buttons

**Custom command row:**
- App icon + name + Toggle + delete + edit command (same as current)
- Supports drag reorder and up/down buttons

**Bottom:** "Add App" button (adds custom commands only; built-in items always present).

## Script Sync (ScriptInstallerService)

Only `.custom` entries need script compilation. Extract with:

```swift
let customItems = menuEntries.compactMap { entry -> MenuItemConfig? in
    if case .custom(let config) = entry { return config }
    return nil
}
scriptInstaller.syncScripts(customItems)
```

Built-in features do not use AppleScript.

## Files Affected

| File | Changes |
|---|---|
| `RCMMShared/Sources/Models/MenuItemConfig.swift` | Remove `sortOrder` |
| `RCMMShared/Sources/Models/BuiltInMenuItem.swift` | New file |
| `RCMMShared/Sources/Models/MenuEntry.swift` | New file |
| `RCMMShared/Sources/Models/BuiltInType.swift` | New file |
| `RCMMShared/Sources/Constants/SharedKeys.swift` | Replace keys |
| `RCMMShared/Sources/Services/SharedConfigService.swift` | Unified `saveEntries`/`loadEntries`, remove `saveCopyPathEnabled`/`loadCopyPathEnabled` |
| `RCMMApp/AppState.swift` | `menuEntries` replaces `menuItems` + `copyPathEnabled` |
| `RCMMApp/Views/Settings/MenuConfigTab.swift` | Mixed list with builtIn row type |
| `RCMMApp/Views/Settings/AppListRow.swift` | Handle builtIn vs custom display |
| `RCMMFinderExtension/FinderSync.swift` | Unified menu building loop |
| `RCMMSharedTests/` | Update tests for new model |
