# RCMM App Icon Design

## Summary

Add a new app icon for `RCMMApp` that makes the product purpose obvious at a glance: a macOS utility for managing Finder right-click menu actions on directories. The icon should prioritize functional readability over brand abstraction.

## Goal

- Users should quickly read "folder-related Finder context menu tool" from the icon.
- The icon should still feel like a native macOS app icon, not a marketing illustration.
- The work only covers the main app bundle icon in `RCMMApp/Assets.xcassets/AppIcon.appiconset`.

## Confirmed Decisions

- **Primary metaphor:** Finder-style right-click menu
- **Supporting object:** Folder
- **Narrative strength:** Direct and explicit, not abstract
- **Composition:** Stacked layout, with a folder as the base and a menu card floating above it
- **Color direction:** Warm yellow folder palette
- **Right-click expression:** Menu card only; no mouse pointer or hand gesture
- **Rendering style:** Native macOS icon feel with volume, highlights, and soft shadows
- **Priority:** Make the app purpose obvious first, even if the result is somewhat literal

## Visual Direction

### Core Composition

The icon uses a warm yellow folder as the dominant shape. A white menu card sits in the upper-right area, overlapping the folder. The menu card contains three simplified horizontal menu rows, with one row highlighted in blue to communicate an actionable Finder context menu.

The folder remains the largest and clearest shape so the icon still reads as a directory-focused utility. The menu card is the semantic differentiator that turns the folder into a "right-click menu manager" icon rather than a generic file manager.

### Style Rules

- Use rounded, macOS-like volumes rather than flat vector-only blocks.
- Keep highlights soft and controlled; avoid glossy old-style skeuomorphism.
- Use light shadows to separate the menu card from the folder without making the icon noisy.
- Do not include text, tiny separators, cursor glyphs, or extra badges.
- Keep the menu card geometric and simplified so the icon still reads at smaller sizes.

### Semantic Hierarchy

1. Folder shape should read first.
2. Menu card should read second.
3. Blue highlighted row should confirm "menu action" rather than becoming a separate symbol.

## Size Strategy

Design starts from a single 1024x1024 master artwork, then exports the full macOS `AppIcon.appiconset` set required by Xcode.

Small sizes must not rely on a mechanical downscale. The same composition stays in place, but detail density is reduced:

- `16x16` and `32x32`: preserve the folder silhouette, white menu card block, and a single strong highlighted row
- `128x128` and above: restore fuller menu-row layering, highlights, and shadow depth

This keeps the chosen direct metaphor from collapsing into visual clutter at Finder-scale icon sizes.

## Implementation Boundary

In scope:

- Replace the empty `RCMMApp/Assets.xcassets/AppIcon.appiconset` payload with a full icon set
- Keep the existing `AppIcon` asset catalog entry and project wiring
- Update `Contents.json` filenames if needed to match exported assets

Out of scope:

- Menu bar icon redesign
- Finder extension branding changes
- DMG background or installer artwork
- New app naming or logo system work

## Validation

After asset generation, verify the icon by building the main app and checking:

- Finder display of `rcmm.app`
- Dock / app switcher presentation
- Small-size readability, especially whether the folder and menu card remain distinct

If the smallest sizes lose clarity, fix the asset artwork rather than changing app structure or metadata.

## Recommended Execution

Do one direction only: finalize a single 1024x1024 master icon that follows this spec, then generate the full `AppIcon.appiconset` from that approved direction. Do not spend time on parallel visual variants unless the first master fails the clarity goal.
