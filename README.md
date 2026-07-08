# rcmm (Right Click Menu Manager)

A macOS Finder context menu manager that allows users to open any directory directly with custom applications in Finder, supporting custom launch commands. Built with Swift 6 + SwiftUI, minimum support for macOS 15+.

## Features

- Custom context menu items in Finder
- Open directories with your preferred applications
- Support for custom launch commands
- Menu bar application for easy configuration

## 正式版发布

正式版通过 GitHub Actions workflow 生成 DMG，并创建普通 GitHub Release。

这条链路当前不做 Developer ID 签名，也不做 notarization。CI 会使用 ad-hoc 签名产出 `rcmm-x.y.z.dmg`，应用内更新在正式版中关闭，用户通过 GitHub Releases 下载新版。

### 创建新的正式版

1. 确保要发布的改动已经提交到目标分支
2. 自动生成下一个稳定版本 tag 并推送：
   ```bash
   bash scripts/publish-next-release-tag.sh
   ```
3. GitHub Actions 会自动：
   - 构建正式版 `.dmg`
   - 生成 SHA-256 checksum
   - 创建 GitHub Release
   - 上传 `rcmm-x.y.z.dmg` 和 checksum

正式版 tag 必须是 `vX.Y.Z` 形式，例如 `v1.0.0`。脚本只会读取稳定版 tag，并按 patch 递增；例如当前最大稳定版是 `v0.0.6` 时，下一个 tag 会是 `v0.0.7`。

如果只想查看下一个版本号，不创建或推送 tag：

```bash
bash scripts/publish-next-release-tag.sh --dry-run
```

### 本地构建正式版 DMG

前置依赖：

```bash
brew install create-dmg
```

执行：

```bash
bash scripts/build-release-dmg.sh --unsigned 1.0.0
```

输出文件会写到 `dist/` 目录，例如 `dist/rcmm-1.0.0.dmg`。

### 安装和首次运行

1. 下载 `rcmm-x.y.z.dmg`
2. 打开 DMG
3. 把 `rcmm.app` 拖到 `Applications` 目录
4. 如果 macOS 拦截启动，先尝试右键应用后选择“打开”
5. 如果仍然阻止启动，可执行：
   ```bash
   xattr -rd com.apple.quarantine /Applications/rcmm.app
   ```

这是未 notarize 的分发包。只要不加入 Apple Developer Program 并配置 Developer ID + notarization，用户首次运行时就可能看到 Gatekeeper 拦截，需要手动放行。

## Development

### Prerequisites

- macOS 15.0+
- Xcode 15.4+ (for Swift 6 support)

### 解析 Swift Package 依赖

如果你用代理（如 Clash，`127.0.0.1:7890`）访问 GitHub，这个卡住通常**不是项目问题**，而是环境问题：

- 终端里 `git ls-remote https://github.com/...` 能秒通，因为 shell 有 `http_proxy` / `https_proxy` / `all_proxy`。
- 但从 Dock/Finder 启动的 Xcode 是 GUI 应用，**只继承 launchd 环境，不读 `.zshrc`**，所以 SPM 解析走直连 → 拉 `Sparkle` 被墙 → 一直 `resolving…`。
- 因此每次需要重新解析（清缓存、改依赖、`Package.resolved` 变动）都会再卡一次。

修复方式是让 git 和 GUI 应用都走代理（按需替换端口）：

```bash
# A. 给 git 全局配代理，SPM 调用 git 拉取时也会走代理
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# B. 让 GUI 应用（含 Xcode）继承代理环境变量
launchctl setenv http_proxy http://127.0.0.1:7890
launchctl setenv https_proxy http://127.0.0.1:7890
launchctl setenv all_proxy socks5://127.0.0.1:7890
```

执行后**完全退出并重开 Xcode** 才会生效。注意：

- `launchctl setenv` 重启后失效，需要时重设或放进登录脚本。
- git 全局代理在**代理未开启**时会导致拉取失败，届时用 `git config --global --unset http.proxy`（及 `https.proxy`）取消。
- 更一劳永逸的办法：开启 Clash 的 Tun Mode / 系统级代理，让所有进程（含 Xcode）都走代理。

### Building

```bash
# Open the project
open rcmm.xcodeproj

# Command-line build
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build
xcodebuild -project rcmm.xcodeproj -scheme RCMMFinderExtension -configuration Debug build

# Run tests (using Swift Testing framework, not XCTest)
cd RCMMShared && swift test
```

### Testing the Finder Extension

In Xcode:
1. Select the `RCMMFinderExtension` scheme
2. In the scheme editor, set Host Application to Finder
3. Run the scheme
4. Right-click in Finder to see the context menu

### Debug and Release Coexistence

Release builds keep `com.sunven.rcmm`, `com.sunven.rcmm.FinderExtension`, and `group.com.sunven.rcmm`.

Debug builds use separate identifiers so the installed app and Xcode build can coexist:

- App: `com.sunven.rcmm.debug`
- Finder extension: `com.sunven.rcmm.debug.FinderExtension`
- App Group: `group.com.sunven.rcmm.debug`
- Display name: `rcmm Debug`

The first signed Debug build needs matching Apple Developer App IDs, App Group, and provisioning profiles. Let Xcode manage signing, or run the build with provisioning updates allowed.

### Viewing Extension Logs

```bash
log stream --predicate 'subsystem == "com.sunven.rcmm.FinderExtension"'
log stream --predicate 'subsystem == "com.sunven.rcmm.debug.FinderExtension"'
```

### Checking Extension Registration

```bash
pluginkit -m -i com.sunven.rcmm.FinderExtension
pluginkit -m -i com.sunven.rcmm.debug.FinderExtension
```

## Architecture

The project consists of three targets:

- **RCMMApp**: Menu bar application (non-sandboxed, LSUIElement=YES)
- **RCMMFinderExtension**: Finder Sync extension (sandboxed)
- **RCMMShared**: SPM static library (shared business logic)

For detailed architecture documentation, see `CLAUDE.md`.

## License

[Add your license here]
