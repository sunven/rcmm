# rcmm (Right Click Menu Manager)

A macOS Finder context menu manager that allows users to open any directory directly with custom applications in Finder, supporting custom launch commands. Built with Swift 6 + SwiftUI, minimum support for macOS 15+.

## Features

- Custom context menu items in Finder
- Open directories with your preferred applications
- Support for custom launch commands
- Menu bar application for easy configuration

## Development Release Process

This project uses GitHub Actions to produce internal development DMG builds.

### Creating a New Development Version

1. Ensure all changes are committed to the main branch
2. Create and push a version tag:
   ```bash
   git tag v1.0.0-dev.1
   git push origin v1.0.0-dev.1
   ```
3. GitHub Actions will automatically:
   - Build a development version
   - Ad-hoc sign the extracted `.app` bundle
   - Generate a development `.dmg` installer
   - Create a GitHub prerelease
   - Upload the DMG as a release asset

### Download

Visit the [Releases page](https://github.com/sunven/rcmm/releases) to download the latest development DMG file.

### Installation

1. Download `rcmm-dev-x.x.x.dmg`
2. Open the DMG file
3. Drag rcmm.app to the Applications folder
4. On first run, right-click the app and select "Open" because this is an ad-hoc signed development build, not a notarized public release
5. If macOS still blocks launch for your local test machine, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/rcmm.app
   ```

### Build a Local Development DMG

Prerequisite:

```bash
brew install create-dmg
```

Run:

```bash
bash scripts/build-dev-dmg.sh
```

Or specify a version explicitly:

```bash
bash scripts/build-dev-dmg.sh 1.0.0-dev.1
```

Fallback to the old ad-hoc mode only when you specifically need it:

```bash
bash scripts/build-dev-dmg.sh --unsigned 1.0.0-dev.1
```

Output files are written to `dist/`.

## Development

### Prerequisites

- macOS 15.0+
- Xcode 15.4+ (for Swift 6 support)

### Building

```bash
# Open the project
open rcmm.xcodeproj

# Command-line build
xcodebuild -project rcmm.xcodeproj -scheme RCMMApp -configuration Debug build
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build

# Run tests (using Swift Testing framework, not XCTest)
xcodebuild -project rcmm.xcodeproj -scheme RCMMSharedTests test
```

### Testing the Finder Extension

In Xcode:
1. Select the `RCMMFinderExtension` scheme
2. In the scheme editor, set Host Application to Finder
3. Run the scheme
4. Right-click in Finder to see the context menu

### Viewing Extension Logs

```bash
log stream --predicate 'subsystem == "com.sunven.rcmm.FinderExtension"'
```

### Checking Extension Registration

```bash
pluginkit -m -i com.sunven.rcmm.FinderExtension
```

## Architecture

The project consists of three targets:

- **RCMMApp**: Menu bar application (non-sandboxed, LSUIElement=YES)
- **RCMMFinderExtension**: Finder Sync extension (sandboxed)
- **RCMMShared**: SPM static library (shared business logic)

For detailed architecture documentation, see `CLAUDE.md`.

## License

[Add your license here]
