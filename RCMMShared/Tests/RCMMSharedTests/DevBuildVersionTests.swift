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
