# rcmm (Right Click Menu Manager)

A macOS Finder context menu manager that allows users to open any directory directly with custom applications in Finder, supporting custom launch commands. Built with Swift 6 + SwiftUI, minimum support for macOS 15+.

## Features

- Custom context menu items in Finder
- Open directories with your preferred applications
- Support for custom launch commands
- Menu bar application for easy configuration

## Development Release Process

This project uses GitHub Actions to produce internal development DMG + ZIP builds and a Sparkle appcast feed.

### Creating a New Development Version

1. Ensure all changes are committed to the branch you want to tag, and that this release will point to a new commit SHA
2. Create and push a version tag:
   ```bash
   git tag v1.0.0-dev.1
   git push origin v1.0.0-dev.1
   ```
3. GitHub Actions will automatically:
   - Build a development version
   - Ad-hoc sign the extracted `.app` bundle
   - Generate a development `.dmg` installer
   - Generate a development `.zip` update archive
   - Sign the ZIP for Sparkle
   - Publish `dev.xml` to GitHub Pages
   - Create a GitHub prerelease

### 开发版发布操作规约

- 当前 GitHub Pages 的 workflow 发布模式下，如果两个 `v*-dev*` tag 指向同一个提交，公开 `dev.xml` 可能继续返回上一个版本。
- 当前操作规约：每个开发版 tag 都必须对应一个新的 commit。不要对同一提交连续发布多个开发版 tag，并期待 appcast 自动前进。
- 如果只是重发或补发、没有代码变化，先创建空提交，再创建新的 tag：
  ```bash
  git commit --allow-empty -m "chore(release): prepare next dev tag"
  git tag v1.0.0-dev.2
  git push origin main
  git push origin v1.0.0-dev.2
  ```

### Development Auto-Update

- Feed URL: `https://sunven.github.io/rcmm/appcasts/dev.xml`
- Manual install artifact: DMG
- In-app update artifact: ZIP

### Testing the Updater

1. Install an older development build into `/Applications`
2. Push a newer `v*-dev*` tag from a newer commit
3. Open rcmm > Settings > 关于 > 检查更新
4. Confirm `立即更新` downloads and relaunches the app

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
xcodebuild -project rcmm.xcodeproj -scheme RCMMShared test
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
