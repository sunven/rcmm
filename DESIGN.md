# Design System - rcmm

## Product Context

- **What this is:** rcmm (Right Click Menu Manager) is a macOS Finder context menu manager. It lets users configure built-in Finder actions, app launch items, composite commands, and new-file templates.
- **Who it's for:** Mac users who want reliable Finder right-click workflows; strongest fit is power users, developers, designers, and anyone who repeatedly opens folders in specific tools.
- **Space/industry:** macOS productivity utility, Finder extension, menu bar app, settings-driven system tool.
- **Project type:** Native macOS SwiftUI app with a Finder Sync extension and menu bar status surface.
- **Memorable thing:** It should feel like a reliable system tool.

## Aesthetic Direction

- **Direction:** Industrial / utilitarian system console.
- **Decoration level:** Intentional. Use native controls, crisp separators, status color, real app icons, and restrained surface layering. Avoid decorative cards, large hero treatments, gradients, and illustrative UI.
- **Mood:** Calm, precise, and trustworthy. The user should feel that rcmm is controlling a system-level integration, not styling a web dashboard.
- **Reference sites/products:** Apple macOS HIG, Raycast, Alfred, PopClip, Service Station, Default Folder X.

## Typography

- **Display/Hero:** SF Pro Rounded when available, otherwise SF Pro Text. Use for app titles, section titles, onboarding step titles, and empty-state headings.
- **Body:** SF Pro Text through SwiftUI system fonts. This should remain the default for settings, labels, rows, and help text.
- **UI/Labels:** SF Pro Text, medium or semibold weight for row titles, badges, segmented controls, and compact buttons.
- **Data/Tables:** SF Mono for shell commands, file paths, fingerprints, templates, bundle IDs, and diagnostic output. Use tabular numbers when displaying counts, versions, or status metrics.
- **Code:** SF Mono.
- **Loading:** Native SwiftUI system font strategy. Do not add bundled third-party fonts for the app UI.
- **Scale:**
  - Window title: 13px equivalent, semibold
  - Sidebar / tab label: 13px equivalent, medium
  - Section title: 17-20px equivalent, bold
  - Row title: 13-14px equivalent, semibold
  - Row subtitle: 11-12px equivalent, regular
  - Badge: 11px equivalent, semibold or bold
  - Help / validation text: 11-12px equivalent
  - Code/path text: 11-12px equivalent, monospace

## Color

- **Approach:** Restrained, with status-led color. Blue is for primary actions and selected state. Green, yellow/orange, and red are reserved for operational state.
- **Primary:** `#2563EB` - inherited from the current app icon family; use for primary buttons, selected navigation, and informational status.
- **Primary strong:** `#1D4ED8` - pressed or active state.
- **Primary soft:** `#DBEAFE` - selected row tint, info banners, low-emphasis blue badges.
- **Ink:** `#111827` - primary text in light mode.
- **Ink soft:** `#374151` - secondary headings and row metadata.
- **Muted:** `#6B7280` - secondary text.
- **Faint:** `#9AA3AF` - tertiary text, disabled icon hints, drag handles.
- **Window:** `#F7F8FA` - main settings window surface.
- **Surface:** `#FFFFFF` - content panes and input backgrounds.
- **Surface soft:** `#F2F4F7` - selected rows, inspector subpanels, grouped controls.
- **Line:** `#D8DEE8` - standard separators.
- **Line strong:** `#C7D0DC` - outer window borders and pane dividers.
- **Semantic:**
  - Success: `#2F9E44`
  - Success soft: `#DFF4E5`
  - Warning: `#B7791F`
  - Warning soft: `#FFF4D6`
  - Error: `#D92D20`
  - Error soft: `#FDE3DF`
  - Info: `#2563EB`
- **Dark mode:** Redesign surfaces rather than invert them. Use `#222832` for window, `#2A313C` for surface, `#3B4656` for lines, and reduce saturation of status fills by using translucent backgrounds.

## Spacing

- **Base unit:** 4px.
- **Density:** Compact-to-comfortable. rcmm is a utility, so it should support scanning many menu items without feeling cramped.
- **Scale:** 2xs(2) xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64).
- **Rows:** Main Finder menu rows should land between 36px and 44px high. Rows with subtitles or warning state can grow, but avoid variable heights for ordinary rows.
- **Insets:** Compact row insets: 6px vertical, 8-10px horizontal. Inspector panels: 10-12px inner padding. Window content: 14-18px.
- **Validation messages:** Keep validation text close to the field or row it explains. Do not place operational warnings in a generic footer.

## Layout

- **Approach:** Grid-disciplined settings surface with a menu-order pane and detail inspector.
- **Primary settings window:** Prefer a larger, resizable settings window over the current fixed 480x400 layout. Target initial size: about 720x520 to 820x560.
- **Information architecture:**
  - Top-level surface: Finder menu, New file, General, About.
  - Rename "菜单配置" to "Finder 菜单" in user-facing UI when possible.
  - Main Finder menu page owns ordering, enable/disable, menu presentation mode, and add actions.
  - Dedicated New file page owns template configuration details.
  - Composite command detail can be shown by expanding a row or by an inspector pane, but avoid forcing the main list to carry every editor field.
- **Grid:** Use a sidebar + content + optional inspector on wider windows. Collapse to tabbed or stacked content at narrow widths if needed.
- **Max content width:** Native app window defines the frame; avoid centered web-style max-width sections inside app surfaces.
- **Border radius:** Small and native-feeling.
  - sm: 5px for inputs and tiny icon buttons
  - md: 8px for rows, segmented controls, and inspector panels
  - lg: 12px for popovers and outer grouped panels
  - full: 9999px for pills, toggles, and status badges only
- **Cards:** Do not put cards inside cards. Use panels only for repeated objects, inspector groups, popovers, and modal content.

## Components

### Finder Menu Row

Each row should expose, in order:

1. Drag/order affordance or disclosure slot.
2. Icon: app icon, SF Symbol, or system command icon.
3. Title and optional subtitle.
4. Status badge.
5. Toggle.
6. Destructive or secondary actions only when needed, preferably on hover or in a trailing menu.

Status badges are not decoration. They must map to real operational state:

- **就绪:** enabled and published/current.
- **同步中:** script/template publish state is missing or stale.
- **同步失败:** compile or publish failed.
- **不可用:** no executable step, missing app, missing template, or blocking validation error.
- **部分可用:** at least one executable step exists but validation has non-blocking errors.
- **已停用:** disabled by user.

### New File Templates

- In the Finder menu list, "新建文件" behaves like a system menu row: enable/disable, sort, status.
- Template editing belongs in the dedicated "新建文件" page.
- Template rows should show display name, generated filename pattern, creation mode, enabled state, and validation status.
- Copy-template resources need explicit missing/stale states. Do not hide missing files behind a generic warning.

### Composite Commands

- Show command name, step count, enabled state, publish status, and blocking validation in the collapsed row.
- Show individual steps in a structured detail area. Shell commands and app paths use monospace.
- When a composite includes app launch and shell steps, the UI should make order visible.

### Menu Bar Popover

- Keep it small and status-first.
- First line: Finder extension health.
- Next actions: Open Settings, view sync/error state if relevant, Quit.
- Use row-style menu buttons, not marketing copy.

### Empty States

- Empty states should be direct and action-oriented.
- Good: "暂无菜单项" with a primary "添加应用" action and a secondary "添加自定义命令" action.
- Avoid long explanatory paragraphs inside compact settings panes.

## Motion

- **Approach:** Minimal-functional.
- **Easing:** enter ease-out, exit ease-in, move ease-in-out.
- **Duration:**
  - Micro: 50-100ms for button press and hover feedback.
  - Short: 120-180ms for disclosure expand/collapse and row selection.
  - Medium: 200-300ms for onboarding step transitions.
  - Long: avoid in the app UI.
- **Rules:** Motion should clarify state changes. Do not use expressive animation for a system utility.

## SwiftUI Implementation Rules

- Prefer native SwiftUI controls before custom controls: `Toggle`, `Picker(.segmented)`, `List`, `Form`, `Settings`, `Menu`, `Button`, `Label`.
- Use SF Symbols for actions and system functions. Use real app icons for app-backed menu items.
- Keep status color accessible with shape or icon differences; never rely on color alone.
- Keep row dimensions stable. Hover, validation text, and badges should not cause ordinary rows to jump.
- Use `.controlSize(.small)` intentionally in dense tool surfaces, but avoid making primary decisions feel tiny.
- Use `.monospaced()` or SF Mono for commands, paths, fingerprints, and generated script names.
- Treat Finder extension health, script publish state, and validation as first-class UI state.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-23 | Initial design system created | Created by design consultation for rcmm based on code review, product context, and comparison with macOS productivity utilities. |
| 2026-05-23 | Memorable thing: reliable system tool | User chose "系统工具可靠"; design should prioritize clarity, status trust, and native macOS patterns. |
| 2026-05-23 | New-file configuration stays separate from Finder menu ordering | Prior user preference: Finder-level New File should behave like Copy Path for enable/disable/order, while template editing belongs in its own settings surface. |
| 2026-05-23 | Status badges are required in main rows | rcmm has real publish, validation, and Finder extension state; hiding that state reduces trust. |
| 2026-05-23 | Settings overview should use Split Inspector | Approved in design-shotgun: left navigation, center Finder menu/order list, and right inspector for selected item details, publish state, composite steps, and new-file summary. |
