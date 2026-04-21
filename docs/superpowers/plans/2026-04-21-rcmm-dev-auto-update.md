# RCMM 开发版自动更新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `rcmm` 开发版增加应用内自动更新能力，启动时自动检查，About 页可手动检查，确认更新后由 Sparkle 负责下载、替换和重启，同时保留 GitHub Release + DMG 的手动安装链路。

**Architecture:** 把版本比较、appcast 解析、安装资格判断和启动提示决策放进 `RCMMShared`，让这些规则先有可重复的 Swift Testing 保护。`RCMMApp` 只负责拉取 feed、桥接 Sparkle、维护 `AppState` 状态和展示 SwiftUI/NSWindow UI；发布链路继续沿用 tag workflow，但新增 ZIP、Sparkle 签名和固定 `dev.xml` appcast，并通过 GitHub Pages 提供稳定 feed URL。

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation XMLParser, Sparkle 2, Swift Testing, GitHub Actions, Bash, GitHub Pages

---

## File Map

- Create: `RCMMShared/Sources/Models/DevBuildVersion.swift` — 统一 `1.2.3-dev.4` / `1.2.3.4` 的解析、比较和展示逻辑。
- Create: `RCMMShared/Sources/Models/DevAppcastItem.swift` — appcast 中单个开发版更新项的纯数据模型。
- Create: `RCMMShared/Sources/Models/UpdateInstallEligibility.swift` — 原地安装和人工安装兜底的资格结果。
- Create: `RCMMShared/Sources/Services/DevAppcastParser.swift` — 从 `dev.xml` 提取并选择最新开发版条目。
- Create: `RCMMShared/Sources/Services/UpdatePolicy.swift` — 启动提示抑制、安装路径判断和新版本呈现决策。
- Create: `RCMMShared/Tests/RCMMSharedTests/DevBuildVersionTests.swift` — 锁定版本解析和排序语义。
- Create: `RCMMShared/Tests/RCMMSharedTests/DevAppcastParserTests.swift` — 锁定 appcast 解析和最新项选择。
- Create: `RCMMShared/Tests/RCMMSharedTests/UpdatePolicyTests.swift` — 锁定 `/Applications` 资格判断和“稍后”抑制逻辑。
- Create: `RCMMApp/Config/AutoUpdate.xcconfig` — 存放 feed URL、public EdDSA key、默认 display version 和本阶段的 Sparkle 相关构建设置。
- Create: `RCMMApp/Services/AppBundleUpdateInfo.swift` — 从 `Bundle.main` 读取当前版本、feed URL 和 release 页面 URL。
- Create: `RCMMApp/Services/SparkleUpdaterService.swift` — 对 Sparkle `SPUStandardUpdaterController` 做窄封装。
- Create: `RCMMApp/Services/UpdateFeedClient.swift` — 拉取 `dev.xml` 并交给共享解析器。
- Create: `RCMMApp/Views/UpdatePrompt/UpdatePromptView.swift` — 启动后台发现更新后的轻量提示内容。
- Modify: `RCMMApp/AppState.swift` — 新增更新状态机、手动检查、启动自动检查、提示窗口和安装动作。
- Modify: `RCMMApp/Views/Settings/AboutTab.swift` — 展示当前版本、检查更新按钮、更新状态和主操作按钮。
- Modify: `rcmm.xcodeproj/project.pbxproj` — 给 `rcmm` target 挂 Sparkle 包依赖，并把 `AutoUpdate.xcconfig` 接到 Debug / Release 构建配置。
- Create: `scripts/normalize-dev-version.sh` — 把 tag 归一化为 `SHORT_VERSION`、`BUNDLE_VERSION` 和 `DISPLAY_VERSION`。
- Create: `scripts/render-dev-appcast.sh` — 用 ZIP URL、长度和 Sparkle 签名渲染稳定 `dev.xml`。
- Modify: `.github/workflows/release.yml` — 生成 ZIP、签名、appcast、Pages 部署和新增 release 资产。
- Modify: `README.md` — 更新开发版发布流程、依赖和手动测试说明。

## External Prerequisites

- 在执行 Task 5 之前，仓库的 GitHub Pages 发布源要切到 `GitHub Actions`。
- 在执行 Task 3 时生成一次 Sparkle EdDSA key pair，并把私钥保存到仓库 secret `SPARKLE_PRIVATE_ED_KEY`。
- 本计划默认当前阶段继续服务内部开发版，因此不引入 notarization，也不要求 `Developer ID`。

## Scope Guards

- 不改 `RCMMFinderExtension` 的行为；扩展只随主应用 bundle 一起更新。
- 不把更新入口放进菜单栏 popover；显式入口只在 About 页。
- 不做 delta 更新、多通道切换和“忽略此版本”。
- 不把 updater 错误写入 `SharedErrorQueue`。

### Task 1: 建立开发版版本模型

**Files:**
- Create: `RCMMShared/Sources/Models/DevBuildVersion.swift`
- Test: `RCMMShared/Tests/RCMMSharedTests/DevBuildVersionTests.swift`

- [ ] **Step 1: 写出失败中的版本解析与排序测试**

创建 `RCMMShared/Tests/RCMMSharedTests/DevBuildVersionTests.swift`：

```swift
import Testing
@testable import RCMMShared

@Suite("DevBuildVersion 测试")
struct DevBuildVersionTests {

    @Test("display version 解析 1.2.3-dev.4")
    func parseDisplayVersion() {
        let version = DevBuildVersion.parse(displayVersion: "1.2.3-dev.4")
        #expect(version?.shortVersion == "1.2.3")
        #expect(version?.bundleVersion == "1.2.3.4")
        #expect(version?.displayVersion == "1.2.3-dev.4")
    }

    @Test("display version 缺省 build 序号归一化为 0")
    func parseDisplayVersionWithoutBuildNumber() {
        let version = DevBuildVersion.parse(displayVersion: "1.2.3-dev")
        #expect(version?.bundleVersion == "1.2.3.0")
        #expect(version?.displayVersion == "1.2.3-dev")
    }

    @Test("bundle version 排序按数值比较而不是字符串比较")
    func compareVersions() {
        let older = DevBuildVersion.parse(bundleVersion: "1.2.3.4")
        let newer = DevBuildVersion.parse(bundleVersion: "1.2.3.10")
        #expect(older != nil)
        #expect(newer != nil)
        #expect(older! < newer!)
    }
}
```

- [ ] **Step 2: 运行测试，确认当前缺少实现**

Run:

```bash
cd RCMMShared && swift test --filter DevBuildVersionTests
```

Expected: 编译失败，并出现 `cannot find 'DevBuildVersion' in scope`。

- [ ] **Step 3: 实现最小可用的版本模型**

创建 `RCMMShared/Sources/Models/DevBuildVersion.swift`：

```swift
import Foundation

public struct DevBuildVersion: Comparable, Hashable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let build: Int

    public var shortVersion: String {
        "\(major).\(minor).\(patch)"
    }

    public var bundleVersion: String {
        "\(major).\(minor).\(patch).\(build)"
    }

    public var displayVersion: String {
        build == 0 ? "\(shortVersion)-dev" : "\(shortVersion)-dev.\(build)"
    }

    public init(major: Int, minor: Int, patch: Int, build: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
    }

    public static func parse(displayVersion value: String) -> Self? {
        let pattern = #"^([0-9]+)\.([0-9]+)\.([0-9]+)-dev(?:\.([0-9]+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }

        func component(_ index: Int, default fallback: Int = 0) -> Int? {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else {
                return fallback
            }
            return Int(value[swiftRange])
        }

        guard
            let major = component(1),
            let minor = component(2),
            let patch = component(3),
            let build = component(4, default: 0)
        else { return nil }

        return Self(major: major, minor: minor, patch: patch, build: build)
    }

    public static func parse(bundleVersion value: String) -> Self? {
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return nil }
        guard
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2]),
            let build = Int(parts[3])
        else { return nil }
        return Self(major: major, minor: minor, patch: patch, build: build)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch, lhs.build) < (rhs.major, rhs.minor, rhs.patch, rhs.build)
    }
}
```

- [ ] **Step 4: 重新运行测试，确认版本模型通过**

Run:

```bash
cd RCMMShared && swift test --filter DevBuildVersionTests
```

Expected: `DevBuildVersionTests` 全部通过。

- [ ] **Step 5: 提交 Task 1**

```bash
git add RCMMShared/Sources/Models/DevBuildVersion.swift RCMMShared/Tests/RCMMSharedTests/DevBuildVersionTests.swift
git commit -m "feat(update): add development build version model"
```

### Task 2: 解析 appcast 并生成更新决策

**Files:**
- Create: `RCMMShared/Sources/Models/DevAppcastItem.swift`
- Create: `RCMMShared/Sources/Models/UpdateInstallEligibility.swift`
- Create: `RCMMShared/Sources/Services/DevAppcastParser.swift`
- Create: `RCMMShared/Sources/Services/UpdatePolicy.swift`
- Test: `RCMMShared/Tests/RCMMSharedTests/DevAppcastParserTests.swift`
- Test: `RCMMShared/Tests/RCMMSharedTests/UpdatePolicyTests.swift`

- [ ] **Step 1: 先写失败中的 appcast 与策略测试**

创建 `RCMMShared/Tests/RCMMSharedTests/DevAppcastParserTests.swift`：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("DevAppcastParser 测试")
struct DevAppcastParserTests {

    @Test("从 appcast 中选择最新的开发版条目")
    func parseLatestItem() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 1.2.3-dev.4</title>
              <sparkle:releaseNotesLink>https://github.com/sunven/rcmm/releases/tag/v1.2.3-dev.4</sparkle:releaseNotesLink>
              <enclosure
                url="https://github.com/sunven/rcmm/releases/download/v1.2.3-dev.4/rcmm-dev-1.2.3-dev.4.zip"
                sparkle:version="1.2.3.4"
                sparkle:shortVersionString="1.2.3-dev.4"
                length="12345"
                type="application/octet-stream"
                sparkle:edSignature="sig-4" />
            </item>
            <item>
              <title>Version 1.2.3-dev.10</title>
              <sparkle:releaseNotesLink>https://github.com/sunven/rcmm/releases/tag/v1.2.3-dev.10</sparkle:releaseNotesLink>
              <enclosure
                url="https://github.com/sunven/rcmm/releases/download/v1.2.3-dev.10/rcmm-dev-1.2.3-dev.10.zip"
                sparkle:version="1.2.3.10"
                sparkle:shortVersionString="1.2.3-dev.10"
                length="67890"
                type="application/octet-stream"
                sparkle:edSignature="sig-10" />
            </item>
          </channel>
        </rss>
        """

        let item = try DevAppcastParser.latestItem(from: Data(xml.utf8))

        #expect(item.version.displayVersion == "1.2.3-dev.10")
        #expect(item.archiveURL.absoluteString.contains("1.2.3-dev.10.zip"))
        #expect(item.releaseNotesURL?.absoluteString.contains("v1.2.3-dev.10") == true)
    }
}
```

创建 `RCMMShared/Tests/RCMMSharedTests/UpdatePolicyTests.swift`：

```swift
import Foundation
import Testing
@testable import RCMMShared

@Suite("UpdatePolicy 测试")
struct UpdatePolicyTests {
    let releaseURL = URL(string: "https://github.com/sunven/rcmm/releases")!

    @Test("只有 /Applications/rcmm.app 允许原地安装")
    func applicationsBundleIsEligible() {
        let result = UpdatePolicy.installEligibility(
            bundlePath: "/Applications/rcmm.app",
            releasePageURL: releaseURL
        )
        #expect(result == .inPlaceInstall)
    }

    @Test("挂载卷中的 app 会降级为人工安装")
    func mountedVolumeFallsBackToManualInstall() {
        let result = UpdatePolicy.installEligibility(
            bundlePath: "/Volumes/rcmm/rcmm.app",
            releasePageURL: releaseURL
        )

        switch result {
        case .manualInstall(let reason, let fallbackURL):
            #expect(reason.contains("/Applications/rcmm.app"))
            #expect(fallbackURL == releaseURL)
        default:
            Issue.record("Expected manualInstall")
        }
    }

    @Test("同一次运行中点过稍后，不再重复弹同版本提示")
    func suppressDismissedVersion() {
        let latest = DevAppcastItem(
            version: DevBuildVersion(major: 1, minor: 2, patch: 3, build: 10),
            archiveURL: URL(string: "https://example.com/rcmm.zip")!,
            releaseNotesURL: URL(string: "https://example.com/notes")!,
            archiveLength: 67890,
            signature: "sig-10"
        )

        let decision = UpdatePolicy.startupDecision(
            latestItem: latest,
            currentVersion: DevBuildVersion(major: 1, minor: 2, patch: 3, build: 4),
            bundlePath: "/Applications/rcmm.app",
            dismissedDisplayVersion: "1.2.3-dev.10",
            releasePageURL: releaseURL
        )

        #expect(decision == .none)
    }
}
```

- [ ] **Step 2: 运行测试，确认当前缺少解析器和策略实现**

Run:

```bash
cd RCMMShared && swift test --filter 'DevAppcastParserTests|UpdatePolicyTests'
```

Expected: 编译失败，并出现 `cannot find 'DevAppcastParser' in scope` 或 `cannot find 'UpdatePolicy' in scope`。

- [ ] **Step 3: 实现 appcast 条目、解析器和更新决策**

创建 `RCMMShared/Sources/Models/DevAppcastItem.swift`：

```swift
import Foundation

public struct DevAppcastItem: Equatable, Sendable {
    public let version: DevBuildVersion
    public let archiveURL: URL
    public let releaseNotesURL: URL?
    public let archiveLength: Int
    public let signature: String

    public init(
        version: DevBuildVersion,
        archiveURL: URL,
        releaseNotesURL: URL?,
        archiveLength: Int,
        signature: String
    ) {
        self.version = version
        self.archiveURL = archiveURL
        self.releaseNotesURL = releaseNotesURL
        self.archiveLength = archiveLength
        self.signature = signature
    }
}
```

创建 `RCMMShared/Sources/Models/UpdateInstallEligibility.swift`：

```swift
import Foundation

public enum UpdateInstallEligibility: Equatable, Sendable {
    case inPlaceInstall
    case manualInstall(reason: String, fallbackURL: URL)
}
```

创建 `RCMMShared/Sources/Services/DevAppcastParser.swift`：

```swift
import Foundation

public enum DevAppcastParserError: Error {
    case invalidXML
    case noUsableItems
}

public enum DevAppcastParser {
    public static func latestItem(from data: Data) throws -> DevAppcastItem {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else { throw DevAppcastParserError.invalidXML }
        guard let latest = delegate.items.max(by: { $0.version < $1.version }) else {
            throw DevAppcastParserError.noUsableItems
        }
        return latest
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    private var currentReleaseNotesURL: URL?
    private var currentValue = ""
    private var insideReleaseNotesLink = false

    var items: [DevAppcastItem] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if qName == "sparkle:releaseNotesLink" {
            insideReleaseNotesLink = true
            currentValue = ""
        }

        guard elementName == "enclosure" else { return }

        guard
            let urlString = attributeDict["url"],
            let url = URL(string: urlString),
            let bundleVersion = attributeDict["sparkle:version"],
            let version = DevBuildVersion.parse(bundleVersion: bundleVersion),
            let lengthString = attributeDict["length"],
            let length = Int(lengthString),
            let signature = attributeDict["sparkle:edSignature"]
        else { return }

        items.append(
            DevAppcastItem(
                version: version,
                archiveURL: url,
                releaseNotesURL: currentReleaseNotesURL,
                archiveLength: length,
                signature: signature
            )
        )
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideReleaseNotesLink else { return }
        currentValue += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard qName == "sparkle:releaseNotesLink" else { return }
        insideReleaseNotesLink = false
        currentReleaseNotesURL = URL(string: currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
        currentValue = ""
    }
}
```

创建 `RCMMShared/Sources/Services/UpdatePolicy.swift`：

```swift
import Foundation

public enum UpdateStartupDecision: Equatable, Sendable {
    case none
    case present(DevAppcastItem, UpdateInstallEligibility)
}

public enum UpdatePolicy {
    public static func installEligibility(
        bundlePath: String,
        releasePageURL: URL
    ) -> UpdateInstallEligibility {
        if bundlePath == "/Applications/rcmm.app" {
            return .inPlaceInstall
        }

        return .manualInstall(
            reason: "自动更新仅支持安装在 /Applications/rcmm.app 的开发版，请先重新安装到 Applications 后再更新。",
            fallbackURL: releasePageURL
        )
    }

    public static func startupDecision(
        latestItem: DevAppcastItem?,
        currentVersion: DevBuildVersion,
        bundlePath: String,
        dismissedDisplayVersion: String?,
        releasePageURL: URL
    ) -> UpdateStartupDecision {
        guard let latestItem else { return .none }
        guard latestItem.version > currentVersion else { return .none }
        guard latestItem.version.displayVersion != dismissedDisplayVersion else { return .none }

        return .present(
            latestItem,
            installEligibility(bundlePath: bundlePath, releasePageURL: releasePageURL)
        )
    }
}
```

- [ ] **Step 4: 重新运行共享测试，确认解析器和策略通过**

Run:

```bash
cd RCMMShared && swift test --filter 'DevAppcastParserTests|UpdatePolicyTests'
```

Expected: `DevAppcastParserTests` 和 `UpdatePolicyTests` 全部通过。

- [ ] **Step 5: 提交 Task 2**

```bash
git add \
  RCMMShared/Sources/Models/DevAppcastItem.swift \
  RCMMShared/Sources/Models/UpdateInstallEligibility.swift \
  RCMMShared/Sources/Services/DevAppcastParser.swift \
  RCMMShared/Sources/Services/UpdatePolicy.swift \
  RCMMShared/Tests/RCMMSharedTests/DevAppcastParserTests.swift \
  RCMMShared/Tests/RCMMSharedTests/UpdatePolicyTests.swift
git commit -m "feat(update): add appcast parsing and update policy"
```

### Task 3: 接入 Sparkle 框架和 bundle 更新元数据

**Files:**
- Create: `RCMMApp/Config/AutoUpdate.xcconfig`
- Create: `RCMMApp/Services/AppBundleUpdateInfo.swift`
- Create: `RCMMApp/Services/SparkleUpdaterService.swift`
- Modify: `rcmm.xcodeproj/project.pbxproj`

- [ ] **Step 1: 先确认工程里还没有 Sparkle 和 updater metadata**

Run:

```bash
rg -n "Sparkle|SUPublicEDKey|SUFeedURL|RCMM_DISPLAY_VERSION" rcmm.xcodeproj/project.pbxproj RCMMApp
```

Expected: 没有命中结果。

- [ ] **Step 2: 解析 Swift package 依赖并生成 Sparkle key pair**

Run:

```bash
rm -rf build/SourcePackages build/sparkle
xcodebuild -resolvePackageDependencies \
  -project rcmm.xcodeproj \
  -scheme rcmm \
  -clonedSourcePackagesDirPath build/SourcePackages
mkdir -p build/sparkle
public_key="$(
  build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x build/sparkle/private_key.pem 2>&1 \
    | tee build/sparkle/generate_keys.log \
    | awk -F': ' '/Public EdDSA Key/ {print $2}'
)"
test -n "$public_key"
printf '%s\n' "$public_key" > build/sparkle/public_key.txt
```

Expected: package graph 成功解析，`build/sparkle/private_key.pem` 和 `build/sparkle/public_key.txt` 都被创建。

- [ ] **Step 3: 用刚刚生成的 public key 创建 updater 构建配置文件**

Run:

```bash
public_key="$(cat build/sparkle/public_key.txt)"
cat <<EOF > RCMMApp/Config/AutoUpdate.xcconfig
RCMM_SU_FEED_URL = https://sunven.github.io/rcmm/appcasts/dev.xml
RCMM_DISPLAY_VERSION = \$(MARKETING_VERSION)
INFOPLIST_KEY_SUFeedURL = \$(RCMM_SU_FEED_URL)
INFOPLIST_KEY_SUPublicEDKey = ${public_key}
INFOPLIST_KEY_SUEnableAutomaticChecks = NO
INFOPLIST_KEY_RCMMDisplayVersion = \$(RCMM_DISPLAY_VERSION)
ENABLE_LIBRARY_VALIDATION = NO
EOF
```

- [ ] **Step 4: 给 `rcmm` target 挂 Sparkle 包并把 `AutoUpdate.xcconfig` 接入 Debug / Release**

用 Xcode 打开工程，把 `https://github.com/sparkle-project/Sparkle` 以 `Up to Next Major Version`、`2.7.0` 起步版本加到项目中，并把产品 `Sparkle` 仅链接到 `rcmm` target。Xcode 会生成自己的 UUID；重点是确认 `rcmm.xcodeproj/project.pbxproj` 出现等价结构，而不是照抄下面这些示例 ID：

```pbxproj
/* Begin XCRemoteSwiftPackageReference section */
		B1SPARKLE0001 /* XCRemoteSwiftPackageReference "Sparkle" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/sparkle-project/Sparkle";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 2.7.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		B1SPARKLE0002 /* Sparkle */ = {
			isa = XCSwiftPackageProductDependency;
			package = B1SPARKLE0001 /* XCRemoteSwiftPackageReference "Sparkle" */;
			productName = Sparkle;
		};
/* End XCSwiftPackageProductDependency section */

A1000510 /* Debug */ = {
	isa = XCBuildConfiguration;
	baseConfigurationReference = B1AUTOUPDATE0001 /* AutoUpdate.xcconfig */;
	name = Debug;
};

A1000511 /* Release */ = {
	isa = XCBuildConfiguration;
	baseConfigurationReference = B1AUTOUPDATE0001 /* AutoUpdate.xcconfig */;
	name = Release;
};
```

- [ ] **Step 5: 增加 bundle 读取和 Sparkle 桥接服务**

创建 `RCMMApp/Services/AppBundleUpdateInfo.swift`：

```swift
import Foundation
import RCMMShared

enum AppBundleUpdateInfoError: Error {
    case missingValue(String)
    case invalidValue(String)
}

struct AppBundleUpdateInfo: Sendable {
    let bundlePath: String
    let currentVersion: DevBuildVersion
    let displayVersion: String
    let feedURL: URL
    let releasePageURL: URL

    static func current(bundle: Bundle = .main) throws -> AppBundleUpdateInfo {
        let bundlePath = bundle.bundlePath

        guard
            let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            let currentVersion = DevBuildVersion.parse(bundleVersion: bundleVersion)
        else {
            throw AppBundleUpdateInfoError.missingValue("CFBundleVersion")
        }

        guard let displayVersion = bundle.object(forInfoDictionaryKey: "RCMMDisplayVersion") as? String else {
            throw AppBundleUpdateInfoError.missingValue("RCMMDisplayVersion")
        }

        guard
            let feedURLString = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let feedURL = URL(string: feedURLString)
        else {
            throw AppBundleUpdateInfoError.missingValue("SUFeedURL")
        }

        guard let releasePageURL = URL(string: "https://github.com/sunven/rcmm/releases") else {
            throw AppBundleUpdateInfoError.invalidValue("releasePageURL")
        }

        return AppBundleUpdateInfo(
            bundlePath: bundlePath,
            currentVersion: currentVersion,
            displayVersion: displayVersion,
            feedURL: feedURL,
            releasePageURL: releasePageURL
        )
    }
}
```

创建 `RCMMApp/Services/SparkleUpdaterService.swift`：

```swift
import AppKit
import Sparkle

@MainActor
final class SparkleUpdaterService {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func beginInteractiveUpdate() {
        controller.checkForUpdates(nil)
    }
}
```

- [ ] **Step 6: 构建应用并确认生成的 Info.plist 已包含 updater 元数据**

Run:

```bash
xcodebuild \
  -project rcmm.xcodeproj \
  -scheme rcmm \
  -configuration Debug \
  -clonedSourcePackagesDirPath build/SourcePackages \
  build | rg "BUILD SUCCEEDED|error:"

app_plist="$(find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug/rcmm.app/Contents/Info.plist' -print -quit)"
plutil -p "$app_plist" | rg 'SUFeedURL|SUPublicEDKey|RCMMDisplayVersion'
```

Expected: 第一条命令输出 `BUILD SUCCEEDED`；第二条命令能看到 `SUFeedURL`、`SUPublicEDKey` 和 `RCMMDisplayVersion`。

- [ ] **Step 7: 把私钥写入 GitHub Actions secret**

Run:

```bash
gh secret set SPARKLE_PRIVATE_ED_KEY < build/sparkle/private_key.pem
```

Expected: 命令静默成功；仓库 secret 中出现 `SPARKLE_PRIVATE_ED_KEY`。

- [ ] **Step 8: 提交 Task 3**

```bash
git add \
  RCMMApp/Config/AutoUpdate.xcconfig \
  RCMMApp/Services/AppBundleUpdateInfo.swift \
  RCMMApp/Services/SparkleUpdaterService.swift \
  rcmm.xcodeproj/project.pbxproj
git commit -m "feat(update): integrate Sparkle and updater metadata"
```

### Task 4: 让 About 页先具备手动检查与安装能力

**Files:**
- Create: `RCMMApp/Services/UpdateFeedClient.swift`
- Modify: `RCMMApp/AppState.swift`
- Modify: `RCMMApp/Views/Settings/AboutTab.swift`

- [ ] **Step 1: 先把 About 页改成失败中的 updater 合约**

将 `RCMMApp/Views/Settings/AboutTab.swift` 替换为：

```swift
import AppKit
import SwiftUI
import RCMMShared

struct AboutTab: View {
    @Environment(AppState.self) private var appState

    private var appIcon: NSImage {
        NSApp.applicationIconImage
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("rcmm")
                    .font(.title2.weight(.semibold))

                Text("Right Click Menu Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("版本 \(appState.currentDisplayVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Text(appState.updateStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("检查更新") {
                        appState.checkForUpdatesManually()
                    }

                    if appState.canPerformUpdatePrimaryAction {
                        Button(appState.updatePrimaryActionTitle) {
                            appState.performUpdatePrimaryAction()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
```

- [ ] **Step 2: 运行构建，确认 `AppState` 还没有这些 updater 接口**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "error:|BUILD SUCCEEDED"
```

Expected: 构建失败，并出现类似 `Value of type 'AppState' has no member 'checkForUpdatesManually'` 的错误。

- [ ] **Step 3: 实现 feed 客户端和手动检查状态机**

创建 `RCMMApp/Services/UpdateFeedClient.swift`：

```swift
import Foundation
import RCMMShared

enum UpdateFeedClientError: LocalizedError {
    case badServerResponse(Int)

    var errorDescription: String? {
        switch self {
        case .badServerResponse(let statusCode):
            return "更新 feed 返回了异常状态码：\(statusCode)"
        }
    }
}

struct UpdateFeedClient: Sendable {
    func fetchLatestItem(feedURL: URL) async throws -> DevAppcastItem {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw UpdateFeedClientError.badServerResponse(httpResponse.statusCode)
        }
        return try DevAppcastParser.latestItem(from: data)
    }
}
```

在 `RCMMApp/AppState.swift` 顶部属性区前增加更新状态类型：

```swift
enum AppUpdateState: Equatable {
    case idle
    case checking
    case current(lastCheckedAt: Date)
    case available(DevAppcastItem, UpdateInstallEligibility)
    case failed(String)
    case installing(DevAppcastItem)
}
```

在 `AppState` 的属性区加入：

```swift
    var currentDisplayVersion = "未知版本"
    var updateState: AppUpdateState = .idle

    @ObservationIgnored private var sparkleUpdater: SparkleUpdaterService?
    @ObservationIgnored private let updateFeedClient = UpdateFeedClient()
```

在 `init(forPreview:)` 里的 `guard !forPreview else { return }` 前后改成：

```swift
        guard !forPreview else { return }

        if let bundleInfo = try? AppBundleUpdateInfo.current() {
            currentDisplayVersion = bundleInfo.displayVersion
        }
        sparkleUpdater = SparkleUpdaterService()
```

在 `AppState` 末尾追加这些方法和计算属性：

```swift
    var updateStatusText: String {
        switch updateState {
        case .idle:
            return "启动后会自动检查更新，也可以在这里手动检查。"
        case .checking:
            return "正在检查更新…"
        case .current(let lastCheckedAt):
            return "当前已是最新版本，上次检查时间：\(lastCheckedAt.formatted(date: .numeric, time: .shortened))"
        case .available(let item, let eligibility):
            switch eligibility {
            case .inPlaceInstall:
                return "发现新版本 \(item.version.displayVersion)，可以直接安装。"
            case .manualInstall(let reason, _):
                return "发现新版本 \(item.version.displayVersion)。\(reason)"
            }
        case .failed(let message):
            return message
        case .installing(let item):
            return "正在准备安装 \(item.version.displayVersion)…"
        }
    }

    var canPerformUpdatePrimaryAction: Bool {
        if case .available = updateState { return true }
        return false
    }

    var updatePrimaryActionTitle: String {
        guard case .available(_, let eligibility) = updateState else { return "检查更新" }
        switch eligibility {
        case .inPlaceInstall:
            return "立即更新"
        case .manualInstall:
            return "打开下载页"
        }
    }

    func checkForUpdatesManually() {
        Task { await performUpdateCheck(silent: false) }
    }

    func performUpdatePrimaryAction() {
        guard case .available(let item, let eligibility) = updateState else { return }

        switch eligibility {
        case .inPlaceInstall:
            updateState = .installing(item)
            sparkleUpdater?.beginInteractiveUpdate()
        case .manualInstall(_, let fallbackURL):
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    private func performUpdateCheck(silent: Bool) async {
        updateState = .checking

        do {
            let bundleInfo = try AppBundleUpdateInfo.current()
            currentDisplayVersion = bundleInfo.displayVersion

            let latestItem = try await updateFeedClient.fetchLatestItem(feedURL: bundleInfo.feedURL)
            let eligibility = UpdatePolicy.installEligibility(
                bundlePath: bundleInfo.bundlePath,
                releasePageURL: bundleInfo.releasePageURL
            )

            if latestItem.version > bundleInfo.currentVersion {
                updateState = .available(latestItem, eligibility)
            } else if !silent {
                updateState = .current(lastCheckedAt: Date())
            } else {
                updateState = .idle
            }
        } catch {
            updateState = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }
```

- [ ] **Step 4: 重新构建应用，确认 About 页和手动检查状态机通过编译**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|error:"
```

Expected: 输出 `BUILD SUCCEEDED`。

- [ ] **Step 5: 提交 Task 4**

```bash
git add \
  RCMMApp/Services/UpdateFeedClient.swift \
  RCMMApp/AppState.swift \
  RCMMApp/Views/Settings/AboutTab.swift
git commit -m "feat(update): add manual update check in about tab"
```

### Task 5: 让发布流程产出 ZIP、签名和稳定 appcast

**Files:**
- Create: `scripts/normalize-dev-version.sh`
- Create: `scripts/render-dev-appcast.sh`
- Modify: `.github/workflows/release.yml`
- Modify: `README.md`

- [ ] **Step 1: 先写两个会失败的脚本调用，证明发布辅助脚本尚不存在**

Run:

```bash
set +e
bash scripts/normalize-dev-version.sh v1.2.3-dev.4
normalize_status="$?"
bash scripts/render-dev-appcast.sh 1.2.3-dev.4 1.2.3.4 https://example.com/rcmm.zip 12345 fake-signature https://example.com/release-notes
render_status="$?"
set -e
test "$normalize_status" -ne 0
test "$render_status" -ne 0
```

Expected: 两个命令都失败，因为脚本文件还不存在。

- [ ] **Step 2: 创建版本归一化和 appcast 渲染脚本**

创建 `scripts/normalize-dev-version.sh`：

```bash
#!/usr/bin/env bash

set -euo pipefail

input="${1:-}"
version="${input#v}"

if [[ -z "$version" ]]; then
  echo "Usage: bash scripts/normalize-dev-version.sh v1.2.3-dev.4" >&2
  exit 1
fi

if [[ ! "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-dev(\.([0-9]+))?$ ]]; then
  echo "Error: invalid development version: $input" >&2
  exit 1
fi

short_version="${BASH_REMATCH[1]}"
build_number="${BASH_REMATCH[3]:-0}"
bundle_version="${short_version}.${build_number}"

cat <<EOF
DISPLAY_VERSION=${version}
SHORT_VERSION=${short_version}
BUILD_NUMBER=${build_number}
BUNDLE_VERSION=${bundle_version}
EOF
```

创建 `scripts/render-dev-appcast.sh`：

```bash
#!/usr/bin/env bash

set -euo pipefail

display_version="${1:?missing display version}"
bundle_version="${2:?missing bundle version}"
archive_url="${3:?missing archive url}"
archive_length="${4:?missing archive length}"
signature="${5:?missing sparkle signature}"
release_notes_url="${6:-}"
pub_date="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S %z')"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>rcmm dev updates</title>
    <link>https://github.com/sunven/rcmm/releases</link>
    <description>Development builds for rcmm</description>
    <language>en</language>
    <item>
      <title>Version ${display_version}</title>
      <pubDate>${pub_date}</pubDate>
      <sparkle:releaseNotesLink>${release_notes_url}</sparkle:releaseNotesLink>
      <enclosure
        url="${archive_url}"
        sparkle:version="${bundle_version}"
        sparkle:shortVersionString="${display_version}"
        length="${archive_length}"
        type="application/octet-stream"
        sparkle:edSignature="${signature}" />
    </item>
  </channel>
</rss>
EOF
```

- [ ] **Step 3: 运行脚本冒烟测试，确认版本输出和 XML 渲染正确**

Run:

```bash
eval "$(bash scripts/normalize-dev-version.sh v1.2.3-dev.4)"
test "$DISPLAY_VERSION" = "1.2.3-dev.4"
test "$SHORT_VERSION" = "1.2.3"
test "$BUNDLE_VERSION" = "1.2.3.4"

bash scripts/render-dev-appcast.sh \
  1.2.3-dev.4 \
  1.2.3.4 \
  https://example.com/rcmm-dev-1.2.3-dev.4.zip \
  12345 \
  fake-signature \
  https://example.com/release-notes > /tmp/rcmm-dev.xml

xmllint --noout /tmp/rcmm-dev.xml
rg 'sparkle:edSignature="fake-signature"' /tmp/rcmm-dev.xml
```

Expected: 所有 `test` 成功，`xmllint` 无输出，`rg` 命中 `fake-signature`。

- [ ] **Step 4: 更新 release workflow，让它发布 DMG、ZIP、签名和 appcast**

把 `.github/workflows/release.yml` 的权限块改为：

```yaml
permissions:
  contents: write
  pages: write
  id-token: write
```

在 build job 的开头增加 Pages 配置步骤和版本归一化步骤：

```yaml
      - name: Configure Pages
        uses: actions/configure-pages@v5

      - name: Normalize version strings
        run: |
          eval "$(bash scripts/normalize-dev-version.sh "${GITHUB_REF#refs/tags/}")"
          echo "display_version=$DISPLAY_VERSION" >> "$GITHUB_OUTPUT"
          echo "short_version=$SHORT_VERSION" >> "$GITHUB_OUTPUT"
          echo "bundle_version=$BUNDLE_VERSION" >> "$GITHUB_OUTPUT"
        id: normalized
```

在 build job 的 Xcode 构建前增加 Sparkle key 导入步骤：

```yaml
      - name: Resolve package dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -project rcmm.xcodeproj \
            -scheme rcmm \
            -clonedSourcePackagesDirPath build/SourcePackages

      - name: Import Sparkle private key
        env:
          SPARKLE_PRIVATE_ED_KEY: ${{ secrets.SPARKLE_PRIVATE_ED_KEY }}
        run: |
          mkdir -p build/sparkle
          printf '%s' "$SPARKLE_PRIVATE_ED_KEY" > build/sparkle/private_key.pem
          build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -f build/sparkle/private_key.pem
```

把 `xcodebuild archive` 命令替换为带版本覆盖和固定 package cache 路径的形式：

```yaml
          xcodebuild archive \
            -project rcmm.xcodeproj \
            -scheme rcmm \
            -configuration Release \
            -archivePath build/rcmm.xcarchive \
            -clonedSourcePackagesDirPath build/SourcePackages \
            MARKETING_VERSION=${{ steps.normalized.outputs.short_version }} \
            CURRENT_PROJECT_VERSION=${{ steps.normalized.outputs.bundle_version }} \
            RCMM_DISPLAY_VERSION=${{ steps.normalized.outputs.display_version }} \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            | tee build/xcodebuild.log
```

在 `Create DMG` 之后追加 ZIP、签名、checksums 和 Pages artifact 生成步骤：

```yaml
      - name: Create ZIP update archive
        run: |
          ditto -c -k --sequesterRsrc --keepParent build/rcmm.app rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip

      - name: Sign ZIP update archive
        id: sparkle_signature
        run: |
          signature_output="$(
            build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update \
              rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip
          )"
          signature="$(printf '%s\n' "$signature_output" | awk -F'"' '/sparkle:edSignature/ {print $2}')"
          echo "signature=$signature" >> "$GITHUB_OUTPUT"

      - name: Generate checksums
        run: |
          shasum -a 256 rcmm-dev-${{ steps.normalized.outputs.display_version }}.dmg > checksums.txt
          shasum -a 256 rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip >> checksums.txt

      - name: Build appcast payload
        run: |
          mkdir -p build/pages/appcasts
          archive_url="https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip"
          notes_url="https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}"
          archive_length="$(stat -f%z rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip)"
          bash scripts/render-dev-appcast.sh \
            "${{ steps.normalized.outputs.display_version }}" \
            "${{ steps.normalized.outputs.bundle_version }}" \
            "$archive_url" \
            "$archive_length" \
            "${{ steps.sparkle_signature.outputs.signature }}" \
            "$notes_url" > build/pages/appcasts/dev.xml

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/pages
```

把 GitHub prerelease 上传步骤里的资产改成同时上传 DMG 和 ZIP：

```yaml
            gh release upload ${{ github.ref_name }} \
              rcmm-dev-${{ steps.normalized.outputs.display_version }}.dmg \
              rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip \
              checksums.txt \
              --clobber

            gh release create ${{ github.ref_name }} \
              rcmm-dev-${{ steps.normalized.outputs.display_version }}.dmg \
              rcmm-dev-${{ steps.normalized.outputs.display_version }}.zip \
              checksums.txt \
              --title "rcmm dev ${{ steps.normalized.outputs.display_version }}" \
              --prerelease \
              --generate-notes
```

最后新增 `deploy_pages` job：

```yaml
  deploy_pages:
    name: Deploy Appcast to GitHub Pages
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 5: 更新 README，说明新的发布产物和测试路径**

把 `README.md` 的开发版发布部分改成下面这组内容：

````md
This project uses GitHub Actions to produce internal development DMG + ZIP builds and a Sparkle appcast feed.

### Creating a New Development Version

1. Ensure all changes are committed to the branch you want to tag
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

### Development Auto-Update

- Feed URL: `https://sunven.github.io/rcmm/appcasts/dev.xml`
- Manual install artifact: DMG
- In-app update artifact: ZIP

### Testing the Updater

1. Install an older development build into `/Applications`
2. Push a newer `v*-dev*` tag
3. Open rcmm > Settings > 关于 > 检查更新
4. Confirm `立即更新` downloads and relaunches the app
````

同时把测试命令修正为：

````md
xcodebuild -project rcmm.xcodeproj -scheme RCMMShared test
````

- [ ] **Step 6: 校验 workflow YAML 和文档改动**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'
rg -n "Sparkle|dev.xml|rcmm-dev-.*zip|RCMMShared test" .github/workflows/release.yml README.md
```

Expected: Ruby 命令无输出并退出 0；`rg` 能命中 ZIP、`dev.xml`、Sparkle 和新的测试命令。

- [ ] **Step 7: 提交 Task 5**

```bash
git add \
  scripts/normalize-dev-version.sh \
  scripts/render-dev-appcast.sh \
  .github/workflows/release.yml \
  README.md
git commit -m "feat(update): publish zip updates and appcast feed"
```

### Task 6: 跑一次兼容性 spike，先证明 Sparkle 能完成更新闭环

**Files:**
- Modify: none

- [ ] **Step 1: 在仓库设置里确认 GitHub Pages 的 Source 是 GitHub Actions**

Manual check:

```text
GitHub Repo Settings -> Pages -> Build and deployment -> Source -> GitHub Actions
```

Expected: Source 显示为 `GitHub Actions`。

- [ ] **Step 2: 推一个临时开发版 tag，触发真实发布链路**

Run:

```bash
git tag v1.0.0-dev.9001
git push origin v1.0.0-dev.9001
gh run watch --exit-status
```

Expected: `release.yml` 运行成功，GitHub release 页面出现 `rcmm-dev-1.0.0-dev.9001.dmg` 和 `rcmm-dev-1.0.0-dev.9001.zip`。

- [ ] **Step 3: 验证 appcast 已经发布到固定 URL**

Run:

```bash
curl -fsSL https://sunven.github.io/rcmm/appcasts/dev.xml | xmllint --noout -
curl -fsSL https://sunven.github.io/rcmm/appcasts/dev.xml | rg '1.0.0-dev.9001'
```

Expected: XML 校验通过，且 feed 中能看到 `1.0.0-dev.9001`。

- [ ] **Step 4: 在真实机器上验证手动检查 -> Sparkle 安装 -> 自动重启**

Manual check:

```text
1. 先在 /Applications 安装一个更旧的开发版
2. 打开 rcmm -> 设置 -> 关于 -> 检查更新
3. 确认 About 页显示新版本，并出现“立即更新”
4. 点击“立即更新”
5. 确认 Sparkle 下载 ZIP、替换 rcmm.app、退出并自动重启
6. 重启后再次打开“关于”，确认版本号已变成 1.0.0-dev.9001
```

Expected: 以上 6 项全部成立。如果任意一步失败，先回滚到修复实现，不进入 Task 7。

### Task 7: 增加启动自动检查和轻量提示窗口

**Files:**
- Create: `RCMMApp/Views/UpdatePrompt/UpdatePromptView.swift`
- Modify: `RCMMApp/AppState.swift`

- [ ] **Step 1: 先把启动提示接缝写进 `AppState`，让构建先失败一次**

在 `RCMMApp/AppState.swift` 里追加下面这些属性和方法声明：

```swift
    @ObservationIgnored private var updatePromptWindow: NSWindow?
    @ObservationIgnored private var dismissedUpdateDisplayVersion: String?
    @ObservationIgnored private var hasScheduledStartupUpdateCheck = false

    private func scheduleStartupUpdateCheckIfNeeded() {
        guard !hasScheduledStartupUpdateCheck, isOnboardingCompleted else { return }
        hasScheduledStartupUpdateCheck = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            await self.performStartupUpdateCheck()
        }
    }

    private func performStartupUpdateCheck() async {
        _ = currentDisplayVersion
    }

    private func showUpdatePrompt(for item: DevAppcastItem, eligibility: UpdateInstallEligibility) {
        let contentView = UpdatePromptView(
            version: item.version.displayVersion,
            releaseNotesURL: item.releaseNotesURL,
            primaryButtonTitle: eligibility == .inPlaceInstall ? "立即更新" : "打开下载页",
            onPrimaryAction: { [weak self] in
                self?.performUpdatePrimaryAction()
            },
            onLater: { [weak self] in
                self?.dismissAvailableUpdateForSession()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.title = "发现新版本"
        window.makeKeyAndOrderFront(nil)
        updatePromptWindow = window
    }
```

- [ ] **Step 2: 运行构建，确认它因缺少 `UpdatePromptView` 和完整实现而失败**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "error:|BUILD SUCCEEDED"
```

Expected: 构建失败，并出现 `cannot find 'UpdatePromptView' in scope` 或 `performStartupUpdateCheck` 未完整实现的相关错误。

- [ ] **Step 3: 实现轻提示视图和启动自动检查逻辑**

创建 `RCMMApp/Views/UpdatePrompt/UpdatePromptView.swift`：

```swift
import SwiftUI

struct UpdatePromptView: View {
    let version: String
    let releaseNotesURL: URL?
    let primaryButtonTitle: String
    let onPrimaryAction: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("发现新版本 \(version)")
                .font(.title3.weight(.semibold))

            Text("rcmm 已检测到新的开发版。你可以现在更新，也可以稍后在“关于”页继续操作。")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let releaseNotesURL {
                Link("查看发布说明", destination: releaseNotesURL)
                    .font(.callout)
            }

            Spacer()

            HStack {
                Button("稍后", action: onLater)
                Spacer()
                Button(primaryButtonTitle, action: onPrimaryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380, height: 220)
    }
}
```

把 `RCMMApp/AppState.swift` 中的 `init(forPreview:)`、`closeOnboarding()` 和 Task 4 新增的更新方法补全为：

```swift
        if !isOnboardingCompleted {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                self.showOnboardingIfNeeded()
            }
        } else {
            scheduleStartupUpdateCheckIfNeeded()
        }
```

```swift
    func closeOnboarding() {
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }
        onboardingWindow?.close()
        onboardingWindow = nil
        ActivationPolicyManager.hideToMenuBar()
        scheduleStartupUpdateCheckIfNeeded()
    }
```

```swift
    private func performStartupUpdateCheck() async {
        do {
            let bundleInfo = try AppBundleUpdateInfo.current()
            let latestItem = try await updateFeedClient.fetchLatestItem(feedURL: bundleInfo.feedURL)
            let decision = UpdatePolicy.startupDecision(
                latestItem: latestItem,
                currentVersion: bundleInfo.currentVersion,
                bundlePath: bundleInfo.bundlePath,
                dismissedDisplayVersion: dismissedUpdateDisplayVersion,
                releasePageURL: bundleInfo.releasePageURL
            )

            switch decision {
            case .none:
                updateState = .idle
            case .present(let item, let eligibility):
                updateState = .available(item, eligibility)
                showUpdatePrompt(for: item, eligibility: eligibility)
            }
        } catch {
            updateState = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }

    func dismissAvailableUpdateForSession() {
        if case .available(let item, _) = updateState {
            dismissedUpdateDisplayVersion = item.version.displayVersion
        }
        updatePromptWindow?.close()
        updatePromptWindow = nil
    }

    func performUpdatePrimaryAction() {
        guard case .available(let item, let eligibility) = updateState else { return }

        updatePromptWindow?.close()
        updatePromptWindow = nil

        switch eligibility {
        case .inPlaceInstall:
            updateState = .installing(item)
            sparkleUpdater?.beginInteractiveUpdate()
        case .manualInstall(_, let fallbackURL):
            NSWorkspace.shared.open(fallbackURL)
        }
    }
```

- [ ] **Step 4: 跑共享测试和 app 构建，确认最终自动检查链路通过**

Run:

```bash
cd RCMMShared && swift test
cd ..
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|error:"
```

Expected: `swift test` 全部通过，Debug 构建输出 `BUILD SUCCEEDED`。

- [ ] **Step 5: 提交 Task 7**

```bash
git add \
  RCMMApp/Views/UpdatePrompt/UpdatePromptView.swift \
  RCMMApp/AppState.swift
git commit -m "feat(update): add startup update prompt flow"
```

### Task 8: 全量验证并收尾

**Files:**
- Modify: none

- [ ] **Step 1: 跑一遍共享层回归**

Run:

```bash
cd RCMMShared && swift test
```

Expected: 所有 `RCMMSharedTests` 通过。

- [ ] **Step 2: 跑一遍应用构建回归**

Run:

```bash
xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|error:"
```

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: 再做一次最终人工验收**

Manual check:

```text
1. 在 /Applications 放置旧开发版
2. 启动 rcmm，不打开设置页，等待 3 秒以上
3. 确认轻提示窗口出现
4. 点击“稍后”，确认本次运行不再重复弹出
5. 打开“关于”，确认仍能看到可更新状态
6. 点击“立即更新”，确认 Sparkle 完成安装并自动重启
7. 重启后确认 Finder Extension 仍然可用
```

Expected: 以上 7 项全部成立。

- [ ] **Step 4: 清点工作树，只保留预期文件**

Run:

```bash
git status --short
```

Expected: 只剩本计划特性相关文件，没有意外的临时输出或调试文件。

## 2026-04-21 执行记录

- 自动验证已完成：`cd RCMMShared && swift test` 通过，`xcodebuild -project rcmm.xcodeproj -scheme rcmm -configuration Debug build | rg "BUILD SUCCEEDED|error:"` 输出 `BUILD SUCCEEDED`。
- 真实发布链路已跑通：`v1.0.0-dev.9001`、`v1.0.0-dev.9002`、`v1.0.0-dev.9003`、`v1.0.0-dev.9004` 对应的 `release.yml` 均成功完成，release 页面能拿到 DMG、ZIP 和 `checksums.txt`。
- 最终手工验收以 `/Applications/rcmm.app` 中的 `v1.0.0-dev.9002` 为旧版本基线，以公开 feed 中的 `v1.0.0-dev.9004` 为目标版本完成。
- 启动自动检查链路验证通过：重新启动 `9002` 后，不打开设置页，等待约 3 秒，轻提示窗口成功出现。
- “稍后”抑制逻辑验证通过：点击“稍后”后，同一次运行中没有再次重复弹出同版本提示。
- About 页兜底入口验证通过：关闭轻提示后，About 页仍显示可更新状态，并保留主操作按钮。
- Sparkle 安装闭环验证通过：点击“立即更新”后，应用完成下载、替换、退出和自动重启，重启后版本变为 `1.0.0-dev.9004`。
- Finder Extension 回归验证通过：更新并重启后，Finder Extension 仍能正常工作。
- 工作树清点结果正常：记录本段结果时，`feat/dev-auto-update` 工作树只包含本次文档更新。
- 额外记录一个发布注意事项：当 `v1.0.0-dev.9002` 与 `v1.0.0-dev.9003` 复用同一提交 `d876574` 时，公开 `dev.xml` 持续对外返回旧版本；通过空提交 `c1bae05 chore(release): force pages redeploy for dev appcast` 生成新的 `pages_build_version` 后，`v1.0.0-dev.9004` 的 appcast 发布恢复正常。

## Self-Review Checklist

- Spec coverage:
  - `zip + appcast + GitHub Pages` 由 Task 5 覆盖。
  - `启动自动检查 + About 手动检查` 由 Task 4 和 Task 7 覆盖。
  - `轻提示先于下载` 由 Task 7 覆盖。
  - `只允许 /Applications/rcmm.app 原地替换` 由 Task 2 和 Task 4 覆盖。
  - `兼容性 spike 先验证 Sparkle 可行性` 由 Task 6 覆盖。
- Placeholder scan:
  - 计划中没有 `TODO`、`TBD`、`implement later` 或需要人工回忆的文本占位符。
  - Task 3 改为“Step 2 生成 `public_key.txt`，Step 3 直接用该文件写 `AutoUpdate.xcconfig`”，避免执行时手工复制 public key。
- Type consistency:
  - 共享层统一使用 `DevBuildVersion`、`DevAppcastItem`、`UpdateInstallEligibility`、`UpdatePolicy`。
  - 应用层统一使用 `AppUpdateState`、`SparkleUpdaterService`、`UpdateFeedClient`、`AppBundleUpdateInfo`。
  - 启动提示和 About 页都复用同一个 `performUpdatePrimaryAction()`，避免两个更新入口分叉。
