# Copy Path Feature Design

## Summary

Add a global toggle in the menu configuration settings. When enabled, a "拷贝路径" (Copy Path) item appears at the bottom of the Finder right-click menu, separated by a divider. Clicking it copies the selected item's full path to the clipboard.

## Approach

Use `NSPasteboard` directly in the FinderSync extension — no AppleScript needed. The toggle state is stored as a boolean in App Group UserDefaults and read by the extension on each right-click.

## Data Layer (RCMMShared)

- `SharedKeys`: add `copyPathEnabled` key (`rcmm.copyPath.enabled`)
- `SharedConfigService`: add `saveCopyPathEnabled(_ enabled: Bool)` and `loadCopyPathEnabled() -> Bool` (defaults to `false`)
- Reuse existing `configChanged` Darwin notification to signal the extension

## Settings UI (RCMMApp)

- `AppState`: add `copyPathEnabled: Bool` property; on change, save to config service and post Darwin notification
- `MenuConfigTab`: add a `Toggle("拷贝路径")` above the app list, bound to `appState.copyPathEnabled`

## Finder Extension (RCMMFinderExtension)

- `FinderSync.menu(for:)`: after building all app menu items, check `configService.loadCopyPathEnabled()`; if true, append `NSMenuItem.separator()` + "拷贝路径" menu item
- New `@objc func copyPath(_:)` action: reuse `resolveTargetPath()` to get the selected path, then `NSPasteboard.general.clearContents()` + `setString(path, forType: .string)`

## Behavior

- Right-click a file → copies the file's full path (e.g., `/Users/foo/bar.txt`)
- Right-click window background → copies the current directory path
- Menu position: after all "用 XX 打开" items, separated by a divider

## Files Changed

| File | Change |
|---|---|
| `RCMMShared/.../SharedKeys.swift` | Add key constant |
| `RCMMShared/.../SharedConfigService.swift` | Add read/write methods |
| `RCMMApp/AppState.swift` | Add property and save logic |
| `RCMMApp/Views/Settings/MenuConfigTab.swift` | Add Toggle |
| `RCMMFinderExtension/FinderSync.swift` | Menu building + new action |
