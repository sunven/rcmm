# RCMM Logo-Based App Icon Design

## Summary

Use the existing repository-root [`logo.svg`](../../../logo.svg) as the canonical visual source for the RCMM application icon. Rebuild [`RCMMApp/Assets.xcassets/AppIcon.appiconset`](../../../RCMMApp/Assets.xcassets/AppIcon.appiconset) from that logo so the installed app, Finder, Dock, and DMG all present the same brand identity. Keep the logo artwork itself unchanged, and allow a separate small-size simplified source only for icon slots that would become unreadable if the full logo were downscaled mechanically.

This design supersedes [`2026-04-17-rcmm-app-icon-design.md`](./2026-04-17-rcmm-app-icon-design.md). The older design assumed a newly illustrated native-style macOS icon; the approved direction for this work is direct reuse of the existing logo system.

## Goal

- Use `logo.svg` as the source of truth for the app icon system.
- Make the app bundle icon consistent anywhere macOS surfaces `rcmm.app`.
- Preserve readability at small icon sizes without redrawing the product into a different concept.
- Keep the maintenance model obvious: one canonical brand source, one explicit small-size exception.

## Non-Goals

- Do not redesign the menu bar status icon in [`RCMMApp/Views/MenuBar/MenuBarStatusIcon.swift`](../../../RCMMApp/Views/MenuBar/MenuBarStatusIcon.swift).
- Do not introduce a new abstract macOS-style app icon illustration.
- Do not rename the app, change bundle identifiers, or change Finder extension branding separately.
- Do not modify `logo.svg` itself to satisfy icon-production constraints.

## Confirmed Decisions

- `logo.svg` remains the canonical brand source file and stays unchanged.
- The main app icon is the only icon system being redesigned.
- "All icon surfaces" means bundle-derived app icon surfaces such as Finder, Dock, app bundle display, and DMG presentation.
- The menu bar icon remains status-driven SF Symbols and is intentionally out of scope.
- Small icon sizes may use a simplified variant instead of a pure downscale.
- The asset catalog remains the delivery format consumed by Xcode; it is not the design source of truth.

## Current Project Constraints

- [`RCMMApp/Assets.xcassets/AppIcon.appiconset`](../../../RCMMApp/Assets.xcassets/AppIcon.appiconset) already exists and is wired through `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- [`scripts/generate-app-icon-set.sh`](../../../scripts/generate-app-icon-set.sh) currently assumes a master PNG source inside the asset catalog.
- [`scripts/build-dev-dmg.sh`](../../../scripts/build-dev-dmg.sh) packages `rcmm.app` directly, so the DMG window inherits the bundle icon automatically once the asset catalog is updated.
- The repository currently has no separate README-hosted app icon asset to keep in sync, so this work can stay centered on the app bundle icon pipeline.

## Source Model

The icon pipeline should have exactly two human-maintained visual sources:

1. [`logo.svg`](../../../logo.svg)
   - Canonical full-detail brand artwork.
   - Used for normal and large icon sizes.

2. `artwork/app-icon/logo-small.svg`
   - New simplified small-size variant created specifically for icon readability.
   - Must remain visibly derived from `logo.svg`, not a separate concept.
   - Exists outside the asset catalog so the source-vs-output boundary stays clear.

The asset catalog keeps only generated PNG outputs plus [`Contents.json`](../../../RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json). It should not become the place where design intent lives.

## Size Strategy

### Large and Medium Slots

These slots are rendered directly from [`logo.svg`](../../../logo.svg):

- `AppIcon-128.png`
- `AppIcon-128@2x.png`
- `AppIcon-256.png`
- `AppIcon-256@2x.png`
- `AppIcon-512.png`
- `AppIcon-512@2x.png`

The full logo composition stays intact at these sizes.

### Small Slots

These slots are rendered from `artwork/app-icon/logo-small.svg`:

- `AppIcon-16.png`
- `AppIcon-16@2x.png`
- `AppIcon-32.png`
- `AppIcon-32@2x.png`

The simplified variant exists because the current logo includes menu text and fine separators that collapse into noise at small Finder-scale sizes.

## Small-Size Simplification Rules

The small-size variant must preserve the current logo's main identity cues:

- Blue rounded-square base
- White menu-card body
- Blue highlighted menu row
- White pointer/action shape in the upper-left area

The small-size variant should remove or flatten details that do not survive reduction:

- Menu text such as `Open`, `Copy`, and `Move to Trash`
- Thin divider lines
- Subtle shadow work that only reads at larger sizes
- Any detail that turns into visual texture instead of a recognizable shape

This is a readability fold, not a concept redesign.

## Generation Workflow

[`scripts/generate-app-icon-set.sh`](../../../scripts/generate-app-icon-set.sh) should be updated to:

1. Treat [`logo.svg`](../../../logo.svg) as the default source for large and medium slots.
2. Treat `artwork/app-icon/logo-small.svg` as the explicit override source for small slots.
3. Render both SVG sources to the required PNG slot outputs with `sips`, so the workflow stays dependency-light and macOS-native.
4. Continue validating the full [`Contents.json`](../../../RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json) contract.
5. Fail immediately if any required source file or output slot is missing.

The script must not silently preserve stale PNGs from previous runs. If the declared source set is incomplete, regeneration should stop with a clear error.

## Validation

### Automated Validation

- Regenerate the icon set from source files.
- Confirm every expected PNG exists with the correct pixel dimensions.
- Validate [`Contents.json`](../../../RCMMApp/Assets.xcassets/AppIcon.appiconset/Contents.json).
- Build the shared `rcmm` scheme so asset-catalog integration is exercised end to end against the actual packaged app bundle.

### Manual Validation

Check the rebuilt app icon in the places that matter to the approved scope:

- Finder display of the built `rcmm.app`
- Dock icon when the app is launched
- DMG presentation after packaging through [`scripts/build-dev-dmg.sh`](../../../scripts/build-dev-dmg.sh)

The manual review focus is the smallest visible sizes. The icon should still read as the RCMM logo system rather than a blue-and-white blur.

## Scope Boundary for Related Surfaces

- Finder, Dock, and DMG icon presentation are in scope because they derive from the app bundle icon.
- The menu bar status icon is out of scope because it communicates runtime extension status, not brand identity.
- No additional brand rollout work is required unless future documentation adds embedded icon artwork outside the bundle pipeline.

## Recommended Implementation Shape

- Keep source assets explicit and few.
- Keep generated outputs in the asset catalog only.
- Keep rendering scripted and repeatable.
- Keep small-size exceptions visible in the repository structure instead of hidden inside manual one-off PNG edits.

That structure satisfies the approved product direction: use `logo.svg` as the app icon system, while still respecting how macOS icons actually need to read at small sizes.
