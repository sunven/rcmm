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

## P2: Settings inspector diagnostic entry points

What: Add contextual diagnostic actions in the Settings inspector for failed or
partially available Finder menu items.

Why: When publish, validation, script generation, or Finder extension state fails,
users should have a visible next step instead of only seeing a badge or error text.

Context: The Split Inspector settings plan says diagnostic actions should appear
only in failed or partially available states. Candidate destinations include viewing
logs, opening a diagnostics view, revealing generated script locations, or linking
to existing Finder extension health recovery flows. Do not show permanent log links
in the normal ready state.

Effort: M human / S-M with CC+gstack.

Depends on: Split Inspector settings implementation and available diagnostics/log
destinations.
