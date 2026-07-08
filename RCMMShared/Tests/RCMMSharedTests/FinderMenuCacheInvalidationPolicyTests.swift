import Foundation
import Testing
@testable import RCMMShared

@Suite("FinderMenuCacheInvalidationPolicy 测试")
struct FinderMenuCacheInvalidationPolicyTests {
    @Test("没有缓存 metadata 时必须刷新")
    func reloadsWhenMetadataMissing() {
        #expect(FinderMenuCacheInvalidationPolicy.shouldReload(
            metadata: nil,
            currentPreferencesModificationDate: Date(timeIntervalSince1970: 10),
            now: Date(timeIntervalSince1970: 11)
        ))
    }

    @Test("plist modification date 变化时刷新")
    func reloadsWhenModificationDateChanges() {
        let metadata = FinderMenuCacheMetadata(
            preferencesModificationDate: Date(timeIntervalSince1970: 10),
            loadedAt: Date(timeIntervalSince1970: 11)
        )

        #expect(FinderMenuCacheInvalidationPolicy.shouldReload(
            metadata: metadata,
            currentPreferencesModificationDate: Date(timeIntervalSince1970: 12),
            now: Date(timeIntervalSince1970: 13)
        ))
    }

    @Test("plist modification date 未变化时不刷新")
    func keepsCacheWhenModificationDateMatches() {
        let modificationDate = Date(timeIntervalSince1970: 10)
        let metadata = FinderMenuCacheMetadata(
            preferencesModificationDate: modificationDate,
            loadedAt: Date(timeIntervalSince1970: 11)
        )

        #expect(!FinderMenuCacheInvalidationPolicy.shouldReload(
            metadata: metadata,
            currentPreferencesModificationDate: modificationDate,
            now: Date(timeIntervalSince1970: 120)
        ))
    }

    @Test("无法读取 modification date 时按 TTL 兜底刷新")
    func reloadsByTTLWhenModificationDateUnavailable() {
        let metadata = FinderMenuCacheMetadata(
            preferencesModificationDate: nil,
            loadedAt: Date(timeIntervalSince1970: 10)
        )

        #expect(!FinderMenuCacheInvalidationPolicy.shouldReload(
            metadata: metadata,
            currentPreferencesModificationDate: nil,
            now: Date(timeIntervalSince1970: 11),
            maximumAgeWhenModificationDateUnavailable: 2
        ))
        #expect(FinderMenuCacheInvalidationPolicy.shouldReload(
            metadata: metadata,
            currentPreferencesModificationDate: nil,
            now: Date(timeIntervalSince1970: 12),
            maximumAgeWhenModificationDateUnavailable: 2
        ))
    }
}
