# TODOs

## P2: Composite command step-level execution summary

What: Add step-level runtime execution summaries for composite commands.

Why: When a composite command partially fails, users should see which step failed
instead of only observing that one expected app did not open.

Context: v1 keeps runtime execution best-effort and does not define an AppleScript
step-result protocol. After the v1 composite command architecture ships, design how
AppleScript step outcomes flow back into the app and how partial failures appear in
the menu bar error surface or Settings.

Effort: M human / S-M with CC+gstack.

Depends on: v1 composite command architecture.

## P3: Duplicate composite command and step actions

What: Support duplicating a composite command and duplicating an individual step.

Why: Power users can quickly derive similar workflows, such as copying
`VS Code + Terminal` into `Cursor + iTerm`, without rebuilding every command from
scratch.

Context: Duplicates need fresh UUIDs, copied names with a clear suffix, recomputed
fingerprints, and no copied publish state. Add this after the v1 composite editor
and script-backed sync are stable.

Effort: S/M human / S with CC+gstack.

Depends on: v1 composite command editor.

## P3: Composite command template library

What: Add a small built-in library of common composite command templates.

Why: Templates improve discovery and make composite commands feel like selectable
workflows rather than only an advanced blank editor.

Context: v1 should ship one strong smart editor+terminal preset first. After usage
patterns are clearer, add a small template library without creating a long-term
compatibility burden for many apps and tools.

Effort: M human / S-M with CC+gstack.

Depends on: v1 preset creation and validation architecture.

## P2: Composite command debug snapshot

What: Add a debug snapshot or health dump for composite commands.

Why: Cross-process Finder issues are hard to diagnose from symptoms alone. A single
snapshot should show validation results, current fingerprint, publish state,
publish fingerprint, script file status, and Finder visibility decision.

Context: v1 should ship structured logs and deduplicated errors. A later debug
snapshot can live in the Health panel, a log export, or a developer diagnostics
entry point.

Effort: S/M human / S with CC+gstack.

Depends on: v1 publish state, validation, and Finder presenter decisions.

## P2: Project-level design system document

What: Create a project-level `DESIGN.md` for rcmm.

Why: New UI work currently infers design rules from existing SwiftUI code. A shared
design source of truth would make Settings rows, status capsules, sheets, buttons,
spacing, typography, colors, and accessibility behavior consistent across features.

Context: The composite command design review added local design constraints to the
feature plan, but the repo still lacks a durable design system document. After v1
ships, capture the existing app UI vocabulary and the composite command decisions
so future features do not re-derive them from code.

Effort: S/M human / S with CC+gstack.

Depends on: None. Best done after composite command v1 or as a focused design
documentation pass.
