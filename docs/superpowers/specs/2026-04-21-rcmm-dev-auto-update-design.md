# RCMM Development Auto-Update Design

## Summary

Add a development-only in-app auto-update flow for `rcmm` using Sparkle, while keeping the existing GitHub Release + DMG distribution path for manual installs. The updater path should consume a CI-produced `.zip` archive and a fixed `dev-appcast.xml` feed, detect updates automatically on app launch, show a lightweight RCMM prompt when a newer development build exists, and hand off download, replacement, and relaunch to Sparkle after the user confirms.

This design is intentionally scoped to the current public GitHub development-release workflow. It does not attempt to solve production release channels, notarized distribution, or delta updates.

## Goal

- Let installed internal development builds update themselves from inside the app.
- Preserve the current DMG flow for human-driven installation and recovery.
- Keep update discovery automatic at launch and manual from the About tab.
- Avoid building a custom self-replacement installer when Sparkle already solves download, swap, and relaunch.
- Fit the new behavior into the existing SwiftUI app structure with minimal UI surface area.

## Non-Goals

- Do not add a production or stable update channel.
- Do not implement delta or patch updates; phase 1 is full-package replacement only.
- Do not silently download and install updates without user confirmation.
- Do not add update controls to the menu bar popover.
- Do not route updater failures through the Finder extension health-error surface.
- Do not redesign code signing or move the project to Developer ID / notarization in this phase.

## Confirmed Decisions

- The target surface is the internal development build only.
- The desired outcome is one-click in-app update, not "open the download page."
- Current distribution remains public GitHub Releases.
- The current signing model remains ad-hoc or local development signing; no Developer ID requirement is introduced now.
- The app may quit and relaunch automatically after installation.
- CI may change to emit more release artifacts if it improves the update experience.
- DMG stays for manual installs, and a new `.zip` artifact is added for updater consumption.
- Update checks happen automatically on launch and manually from the About tab.
- When a newer build is found, RCMM first shows a lightweight prompt. Download starts only after explicit user confirmation.

## Current Project Constraints

- [`README.md`](../../../README.md) documents a development release flow based on public GitHub prereleases and a generated development DMG.
- [`scripts/build-dev-dmg.sh`](../../../scripts/build-dev-dmg.sh) already produces a Release archive, extracts `rcmm.app`, verifies the embedded Finder extension, and packages a DMG.
- [`.github/workflows/development-release.yml`](../../../.github/workflows/development-release.yml) currently builds only a prerelease DMG path and explicitly uses ad-hoc signing in CI.
- [`RCMMApp/Views/Settings/SettingsView.swift`](../../../RCMMApp/Views/Settings/SettingsView.swift) already has a dedicated About tab, which is the most natural explicit update entry point.
- [`RCMMApp/Views/Settings/AboutTab.swift`](../../../RCMMApp/Views/Settings/AboutTab.swift) currently shows icon and product identity but no version or update controls.
- [`RCMMApp/AppState.swift`](../../../RCMMApp/AppState.swift) already owns launch-time app behavior and timer-driven system checks, so update orchestration belongs there instead of in ad hoc view logic.
- The repository has an existing automated test target only under [`RCMMShared/Tests/RCMMSharedTests`](../../../RCMMShared/Tests/RCMMSharedTests), so pure update policy logic should stay testable outside Sparkle-bound UI code.
- The Xcode project currently uses static version settings in [`rcmm.xcodeproj/project.pbxproj`](../../../rcmm.xcodeproj/project.pbxproj), so release builds do not yet carry a per-tag comparable bundle version.

## Why Appcast Instead of GitHub "Latest Release"

The current release workflow publishes development builds as GitHub prereleases. GitHub's REST "latest release" endpoint does not select prereleases, so using that endpoint would make update detection miss the active development channel. The updater therefore needs a fixed feed URL that always represents the latest installable development build.

For that reason, the updater should consume a canonical appcast URL rather than querying GitHub for "latest release" at runtime.

## Update Channel Model

The updater should follow a single explicit development channel:

- Feed URL: `https://sunven.github.io/rcmm/appcasts/dev.xml`
- Host: GitHub Pages for this public repository
- Feed ownership: CI updates the feed when a new development tag is released
- Feed scope: only the newest installable development build needs to be exposed to the updater

This keeps the client logic simple:

- The app does not need GitHub API credentials.
- The app does not need to understand GitHub prerelease filtering.
- The app only needs one source of truth for "what can I install next?"

## Version Model

The current git tag format is already close to the required release language, but it is not suitable to pass through unchanged as the only comparable bundle version. The updater needs a deterministic, ordered version pair:

- Git tag input: `vX.Y.Z-dev.N`
- Display version: `X.Y.Z-dev.N`
- `CFBundleShortVersionString`: `X.Y.Z`
- `CFBundleVersion`: `X.Y.Z.N`

If a development tag omits the trailing sequence number, it is normalized as `.0`.

Examples:

- `v1.2.3-dev.4` -> short version `1.2.3`, bundle version `1.2.3.4`, display version `1.2.3-dev.4`
- `v1.2.3-dev` -> short version `1.2.3`, bundle version `1.2.3.0`, display version `1.2.3-dev`

The design also adds a custom display-version field for UI and logging, because the user-facing build label should preserve the `-dev` suffix even though the comparable bundle version is normalized.

Release builds must inject these values during CI archive creation rather than relying on the static project defaults.

## Release Pipeline Design

The existing development-release workflow should expand from "build one DMG" into "build one signed app bundle, package it two ways, and publish one feed."

### Required release outputs

- `rcmm-dev-<display-version>.dmg`
- `rcmm-dev-<display-version>.zip`
- `rcmm-dev-<display-version>.zip.sig` or equivalent Sparkle signature metadata
- `dev.xml` appcast published to GitHub Pages
- SHA-256 checksum files for manual inspection and recovery

### CI behavior

1. Parse the pushed development tag and normalize short version, comparable bundle version, and display version.
2. Archive the `rcmm` scheme with version overrides so the built app advertises the release being published.
3. Extract `rcmm.app` and verify the embedded Finder extension still exists.
4. Keep the existing DMG packaging path for manual installs.
5. Produce a `.zip` package from the same built `rcmm.app` for Sparkle consumption.
6. Generate the Sparkle update signature for the `.zip`.
7. Publish the DMG and ZIP artifacts to the GitHub prerelease.
8. Regenerate the development appcast so it points at the newest public ZIP asset and includes the version metadata Sparkle needs.
9. Publish the updated appcast to GitHub Pages.

### Feed publication rule

The feed should be updated atomically as part of the same tagged release workflow. If the workflow cannot publish a coherent appcast entry for the newly built ZIP, the release job should fail rather than shipping a broken updater state.

This design intentionally prefers correctness over partial success. A release that produces a downloadable DMG but leaves the auto-update channel stale is misleading during internal testing.

## Application Integration Design

Sparkle integration belongs only in the main app target.

### New app responsibilities

- A dedicated updater service wraps Sparkle and hides framework-specific types from the rest of the app.
- [`RCMMApp/AppState.swift`](../../../RCMMApp/AppState.swift) owns a small update state machine and invokes the updater service.
- The About tab reads state from `AppState` and remains the only explicit settings entry for updater controls.
- The Finder extension receives no direct updater logic; it updates only because it is embedded inside the replaced app bundle.

### Proposed service boundaries

- `UpdateService`
  - Owns Sparkle controller setup
  - Starts background checks
  - Triggers manual checks
  - Exposes callbacks or async events for available/no-update/failure/installing states
- `UpdatePolicy`
  - Pure logic for install eligibility, version-display formatting, and user-facing state mapping
  - Lives in testable non-framework code
- `UpdateState`
  - View-facing state held by `AppState`

### Startup behavior

- The app schedules an automatic update check a few seconds after launch.
- The startup check should not race onboarding. If onboarding is active or incomplete, the automatic check is deferred until the main app reaches a stable post-onboarding state.
- The startup check should not display a "no updates" prompt. Silent success is the expected case.

## User Experience

### About tab

[`RCMMApp/Views/Settings/AboutTab.swift`](../../../RCMMApp/Views/Settings/AboutTab.swift) should be extended to show:

- Current display version
- Current update status
- "检查更新" button
- Passive last-check or latest-version text when no update is available

The About tab is also where failures remain inspectable after the transient prompt is dismissed.

### Automatic discovery prompt

When the background launch-time check finds a newer development build, RCMM should show its own lightweight prompt first. The prompt only needs:

- New version label
- Optional short release-notes link
- `立即更新`
- `稍后`

Behavior:

- `立即更新` starts the Sparkle-managed download and install flow.
- `稍后` dismisses the prompt and suppresses repeat prompting for the remainder of the current app session.
- The app does not begin downloading until the user explicitly chooses to update.

### Installation flow

Once the user confirms, Sparkle owns:

- Download
- Signature validation
- App replacement
- Relaunch

RCMM should not add custom installation UI beyond reflecting coarse progress state such as downloading or installing.

## Install Eligibility and Failure Handling

### Install eligibility

In-app replacement should only be attempted when RCMM is running from a supported installed location, with `/Applications/rcmm.app` as the canonical supported path for phase 1.

If the app is running from an unsupported location, such as a mounted DMG or a transient Downloads folder copy, the app may still check for updates but should not attempt in-place replacement. In that case the prompt should downgrade to a manual recovery action such as opening the release page or instructing the user to install RCMM into `/Applications` first.

This protects the updater from the most common internal-dev edge case: launching directly from the installer image or from an ad hoc unpacked copy.

### Failure handling

- Feed fetch failure: store a non-blocking error message and allow manual retry from About.
- Invalid feed or signature: stop installation and present a clear updater-specific error.
- Download failure: allow retry without affecting normal app behavior.
- Replacement or relaunch failure: show recovery guidance and a manual-download fallback.
- Any updater failure must stay isolated from the existing extension health UI and from [`SharedErrorQueue`](../../../RCMMShared/Sources/Services/SharedErrorQueue.swift).

The app should continue operating normally if update checks fail. Auto-update is additive functionality, not a startup dependency.

## Finder Extension Expectations

The Finder Sync extension remains bundled inside the app and is replaced as part of the full application update.

Success for this feature is defined as:

- The main app updates and relaunches into the new build.
- The embedded Finder extension remains present in the updated bundle.
- Finder extension functionality returns after the normal system re-registration window.

This design does not guarantee perfectly seamless extension continuity during the swap. A short recovery window is acceptable for an internal development updater.

## Testing and Validation

### Automated validation

- Unit tests for version normalization and install-eligibility logic
- Unit tests for prompt-suppression and state transitions in `UpdatePolicy`
- Build verification for the `rcmm` scheme after Sparkle is linked into the app
- CI validation that the release workflow emits DMG, ZIP, signature metadata, and an appcast entry together

Pure logic tests should live in the existing shared test surface where possible, rather than making Sparkle integration the first reason to introduce a new app test target.

### Manual validation

1. Install an older development build into `/Applications`.
2. Publish a newer tagged development prerelease.
3. Launch the older app and wait for the startup check.
4. Confirm the lightweight prompt appears.
5. Click `立即更新`.
6. Confirm the app downloads, replaces itself, quits, and relaunches into the newer display version.
7. Confirm the Finder extension is still embedded and returns to healthy operation after relaunch.
8. Confirm the About tab can still perform a manual check and report the app is current.

## Risk and First Implementation Milestone

The largest technical assumption in this design is that Sparkle can complete the in-place replacement flow reliably enough for the project's current development-signing model.

Because of that, the first implementation milestone should be a compatibility spike that proves all of the following together on a real machine:

- A public appcast can be consumed by RCMM.
- A CI-style development ZIP can be installed through Sparkle.
- The replaced app relaunches correctly from `/Applications`.
- The embedded Finder extension survives the replaced bundle structure.

If that spike fails under the current signing model, implementation should stop and reopen design rather than quietly degrading this feature into a manual-download experience.

## Recommended Implementation Shape

- Keep Sparkle-specific code behind a narrow `UpdateService`.
- Keep policy and version logic in pure Swift so it can be tested without updater framework coupling.
- Keep the visible UI limited to the About tab plus a small discovery prompt.
- Keep release automation deterministic: one tag produces one coherent DMG/ZIP/appcast set.
- Keep the updater on a single development channel until there is a real need for multi-channel release management.
