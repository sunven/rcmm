# rcmm (Right Click Menu Manager)

A macOS Finder context menu manager that allows users to open any directory directly with custom applications in Finder, supporting custom launch commands. Built with Swift 6 + SwiftUI, minimum support for macOS 15+.

## Features

- Custom context menu items in Finder
- Open directories with your preferred applications
- Support for custom launch commands
- Menu bar application for easy configuration

## 开发版发布

项目通过 GitHub Actions 生成内部开发版 DMG、ZIP 更新包，以及 Sparkle appcast。

### 创建新的开发版

1. 确保要发布的改动已经提交到目标分支，并且这次发布对应的是一个新的 commit SHA
2. 创建并推送版本 tag：
   ```bash
   git tag v1.0.0-dev.1
   git push origin v1.0.0-dev.1
   ```
3. GitHub Actions 会自动：
   - 构建保留 Finder Sync entitlements 的开发签名版本
   - 生成开发版 `.dmg` 安装包
   - 生成开发版 `.zip` 更新包
   - 为 ZIP 生成 Sparkle 签名
   - 将 `dev.xml` 发布到 GitHub Pages
   - 创建 GitHub prerelease

### 准备签名 secrets

GitHub Actions 需要下面 5 个 secrets 才能产出可继续使用 Finder 扩展的开发版包：

- `APPLE_DEVELOPMENT_CERTIFICATE_P12_BASE64`
- `APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`
- `RCMM_APP_PROVISION_PROFILE_BASE64`
- `RCMM_EXTENSION_PROVISION_PROFILE_BASE64`
- `KEYCHAIN_PASSWORD`

缺少这些 secrets 时，workflow 会直接失败，而不是退回 ad-hoc 签名。因为 ad-hoc 包会让自动更新后的 Finder 扩展失效。

建议按下面方式准备：

1. `APPLE_DEVELOPMENT_CERTIFICATE_P12_BASE64`
   从“钥匙串访问”导出 `Apple Development` 证书为 `.p12`，再执行：
   ```bash
   base64 -i rcmm-dev-cert.p12 | tr -d '\n'
   ```
2. `APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`
   导出 `.p12` 时设置的密码。
3. `RCMM_APP_PROVISION_PROFILE_BASE64`
   主应用 `com.sunven.rcmm` 对应的 provisioning profile 做 base64：
   ```bash
   base64 -i rcmm-app.provisionprofile | tr -d '\n'
   ```
4. `RCMM_EXTENSION_PROVISION_PROFILE_BASE64`
   Finder 扩展 `com.sunven.rcmm.FinderExtension` 对应的 provisioning profile 做 base64：
   ```bash
   base64 -i rcmm-extension.provisionprofile | tr -d '\n'
   ```
5. `KEYCHAIN_PASSWORD`
   workflow 里临时 keychain 使用的任意强密码即可。

证书和两个 provisioning profile 都必须属于 Team ID `K65J6JBW5K`，并且 bundle identifier 要分别匹配主应用和 Finder 扩展。

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

### 开发版自动更新

- Feed URL: `https://sunven.github.io/rcmm/appcasts/dev.xml`
- 手动安装包：DMG
- 应用内更新包：ZIP

### 验证更新流程

1. 先把一个较旧的开发版安装到 `/Applications`
2. 基于更新后的 commit 推送一个新的 `v*-dev*` tag
3. 打开 rcmm > 设置 > 关于 > 检查更新
4. 确认 `立即更新` 能正常下载、安装并重启应用

### 下载

可以在 [Releases 页面](https://github.com/sunven/rcmm/releases) 下载最新的开发版 DMG。

### 安装

1. 下载 `rcmm-dev-x.x.x.dmg`
2. 打开 DMG
3. 把 `rcmm.app` 拖到 `Applications` 目录
4. 首次运行时，如果系统拦截，请右键应用后选择“打开”；这是内部开发签名包，不是已 notarize 的公开发布版
5. 如果当前测试机仍然阻止启动，可执行：
   ```bash
   xattr -dr com.apple.quarantine /Applications/rcmm.app
   ```

### 本地构建开发版 DMG

前置依赖：

```bash
brew install create-dmg
```

直接执行：

```bash
bash scripts/build-dev-dmg.sh
```

也可以显式指定版本号：

```bash
bash scripts/build-dev-dmg.sh 1.0.0-dev.1
```

只有在你明确需要回退时，才使用旧的 ad-hoc 模式：

```bash
bash scripts/build-dev-dmg.sh --unsigned 1.0.0-dev.1
```

输出文件会写到 `dist/` 目录。

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
